"""Renders a level's arrow tune to a WAV so it can be auditioned outside the app.

Mirrors lib/core/audio/level_tunes.dart exactly, then mixes the sampled piano
notes at a steady tap interval, optionally over the background track.

    python3 tool/preview_level_tune.py 1 7 42 137
"""

import os
import struct
import sys
import wave

SAMPLE_RATE = 22050
NOTE_DIR = os.path.join("assets", "audio", "piano")
BGM = os.path.join("assets", "audio", "bgm_chill.wav")
OUT_DIR = os.path.join("build", "audio_preview")

TAP_INTERVAL = 0.42
NOTE_VOLUME = 0.55
BGM_VOLUME = 0.28

SCALE = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84]
TOP_DEGREE = 14
DEGREES_PER_OCTAVE = 7
CENTRE_COUNT = 7

CONTOURS = [
    [0, 2, 4, 5, 7, 5, 4, 2],
    [0, 4, 7, 4, 0, 4, 7, 11],
    [7, 4, 2, 0, 2, 4, 7, 9],
    [0, 1, 2, 4, 2, 1, 0, -2],
    [0, 2, 1, 4, 3, 5, 4, 7],
    [4, 4, 2, 0, 4, 4, 2, 0, 7, 5, 4, 2],
    [0, 7, 6, 5, 4, 3, 2, 1, 0],
    [0, 3, 2, 5, 4, 7, 6, 9],
    [2, 4, 6, 4, 2, 0, 2, 4],
    [0, 5, 4, 3, 2, 4, 3, 2, 1, 0],
    [7, 7, 5, 4, 5, 7, 4, 2, 0],
    [0, 2, 4, 6, 8, 6, 4, 2],
    [0, -1, 0, 2, 4, 2, 0, -1, 0],
    [4, 7, 4, 2, 4, 7, 9, 7, 4],
    [0, 4, 5, 7, 5, 4, 0, -3],
    [5, 4, 2, 4, 5, 7, 9, 7, 5, 4],
    [0, 2, 4, 7, 9, 7, 4, 2, 0],
    [9, 7, 5, 4, 2, 4, 5, 7],
    [0, 3, 5, 7, 5, 3, 0, 3, 5],
    [2, 0, 2, 4, 5, 4, 2, 0, -2, 0],
    [7, 9, 11, 9, 7, 5, 4, 2],
    [0, 4, 2, 6, 4, 8, 6, 4, 2, 0],
    [0, 0, 4, 4, 5, 5, 4, 2, 2, 1, 1, 0],
    [4, 2, 4, 5, 7, 7, 5, 4, 2, 0],
    [0, 5, 3, 1, 2, 4, 6, 7],
    [7, 5, 7, 9, 7, 5, 4, 5, 4, 2],
    [0, 2, 0, 4, 2, 5, 4, 7],
    [3, 5, 7, 5, 3, 1, 0, 1, 3],
    [0, 7, 5, 4, 7, 5, 4, 2, 0],
    [1, 2, 4, 5, 4, 2, 1, -1],
    [0, 4, 7, 9, 11, 9, 7, 4],
    [6, 4, 2, 0, 1, 3, 5, 7],
    [0, 2, 5, 4, 7, 9, 7, 5, 4, 2, 0],
    [4, 5, 4, 2, 0, 2, 4, 5, 7],
    [0, -2, 0, 3, 5, 3, 0, -2],
    [2, 5, 4, 7, 6, 9, 7, 4, 2],
]


def into_range(degrees):
    lowest, highest = min(degrees), max(degrees)
    shift = 0
    while highest + shift > TOP_DEGREE and lowest + shift - DEGREES_PER_OCTAVE >= 0:
        shift -= DEGREES_PER_OCTAVE
    while lowest + shift < 0:
        shift += DEGREES_PER_OCTAVE
    return [max(0, min(TOP_DEGREE, d + shift)) for d in degrees]


def tune_for(level_id):
    index = max(0, level_id - 1)
    contour = CONTOURS[index % len(CONTOURS)]
    centre = (index // len(CONTOURS)) % CENTRE_COUNT
    variant = (index // (len(CONTOURS) * CENTRE_COUNT)) % 4

    pivot = contour[0]
    inverted = variant in (1, 3)
    backwards = variant >= 2

    degrees = [centre + (pivot * 2 - d if inverted else d) for d in contour]
    if backwards:
        degrees = list(reversed(degrees))
    return [SCALE[d] for d in into_range(degrees)]


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getsampwidth() == 2
        n_ch = w.getnchannels()
        raw = w.readframes(w.getnframes())
    data = struct.unpack("<%dh" % (len(raw) // 2), raw)
    if n_ch > 1:
        data = [sum(data[i : i + n_ch]) / n_ch for i in range(0, len(data), n_ch)]
    return [v / 32768.0 for v in data]


def render(level_id, taps, with_bgm=True):
    tune = tune_for(level_id)
    notes = {midi: read_wav(os.path.join(NOTE_DIR, "p%d.wav" % midi)) for midi in set(tune)}

    step = int(TAP_INTERVAL * SAMPLE_RATE)
    tail = max(len(s) for s in notes.values())
    total = step * taps + tail
    mix = [0.0] * total

    for i in range(taps):
        sample = notes[tune[i % len(tune)]]
        start = i * step
        for j, v in enumerate(sample):
            mix[start + j] += v * NOTE_VOLUME

    if with_bgm and os.path.exists(BGM):
        bgm = read_wav(BGM)
        for i in range(total):
            mix[i] += bgm[i % len(bgm)] * BGM_VOLUME

    peak = max(abs(v) for v in mix) or 1.0
    if peak > 0.95:
        mix = [v * (0.95 / peak) for v in mix]

    return [int(max(-32768, min(32767, round(v * 32767)))) for v in mix], tune


def main():
    ids = [int(a) for a in sys.argv[1:]] or [1, 7, 42, 137]
    os.makedirs(OUT_DIR, exist_ok=True)
    for level_id in ids:
        samples, tune = render(level_id, taps=16)
        path = os.path.join(OUT_DIR, "level_%04d.wav" % level_id)
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SAMPLE_RATE)
            w.writeframes(struct.pack("<%dh" % len(samples), *samples))
        print("level %-4d -> %s  (%d notes: %s)" % (level_id, path, len(tune), tune))

    seen = {tuple(tune_for(i)) for i in range(1, 1001)}
    print("\nDistinct tunes across levels 1-1000: %d" % len(seen))


if __name__ == "__main__":
    main()
