"""One-off helper: estimate the musical key of assets/audio/bgm_chill.wav.

Pure stdlib (no numpy). Uses a Goertzel filter per pitch class across several
frames, then correlates the resulting chroma vector against major/minor
key profiles (Krumhansl-Schmuckler).
"""

import math
import struct
import wave

WAV = "assets/audio/bgm_chill.wav"
NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

MAJOR_PROFILE = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MINOR_PROFILE = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]


def read_mono(path):
    with wave.open(path, "rb") as w:
        n_ch = w.getnchannels()
        width = w.getsampwidth()
        rate = w.getframerate()
        frames = w.readframes(w.getnframes())
    assert width == 2, f"expected 16-bit, got {width * 8}-bit"
    data = struct.unpack("<%dh" % (len(frames) // 2), frames)
    if n_ch > 1:
        data = [sum(data[i : i + n_ch]) / n_ch for i in range(0, len(data), n_ch)]
    return list(data), rate


def goertzel(samples, rate, freq):
    k = int(0.5 + (len(samples) * freq) / rate)
    omega = (2.0 * math.pi * k) / len(samples)
    coeff = 2.0 * math.cos(omega)
    s1 = s2 = 0.0
    for x in samples:
        s0 = x + coeff * s1 - s2
        s2, s1 = s1, s0
    return s1 * s1 + s2 * s2 - coeff * s1 * s2


def main():
    samples, rate = read_mono(WAV)
    frame = 8192
    hop = max(frame, len(samples) // 24)

    chroma = [0.0] * 12
    starts = range(0, len(samples) - frame, hop)
    for start in starts:
        block = samples[start : start + frame]
        peak = max(abs(v) for v in block) or 1
        block = [v / peak for v in block]
        for pc in range(12):
            energy = 0.0
            # MIDI 48 (C3) .. 83 (B5) for this pitch class.
            for midi in range(48 + pc, 84, 12):
                freq = 440.0 * (2.0 ** ((midi - 69) / 12.0))
                if freq * 2 >= rate:
                    continue
                energy += math.sqrt(goertzel(block, rate, freq))
            chroma[pc] += energy

    total = sum(chroma) or 1.0
    chroma = [c / total for c in chroma]

    print("Chroma:")
    for pc in sorted(range(12), key=lambda i: -chroma[i]):
        print(f"  {NOTE_NAMES[pc]:<2} {chroma[pc]:.4f}  {'#' * int(chroma[pc] * 200)}")

    def correlate(profile, shift):
        rotated = [profile[(i - shift) % 12] for i in range(12)]
        mp = sum(rotated) / 12
        mc = sum(chroma) / 12
        num = sum((rotated[i] - mp) * (chroma[i] - mc) for i in range(12))
        den = math.sqrt(
            sum((rotated[i] - mp) ** 2 for i in range(12))
            * sum((chroma[i] - mc) ** 2 for i in range(12))
        )
        return num / den if den else 0.0

    scores = []
    for shift in range(12):
        scores.append((correlate(MAJOR_PROFILE, shift), f"{NOTE_NAMES[shift]} major", shift, "major"))
        scores.append((correlate(MINOR_PROFILE, shift), f"{NOTE_NAMES[shift]} minor", shift, "minor"))
    scores.sort(reverse=True)

    print("\nTop key candidates:")
    for score, name, _, _ in scores[:6]:
        print(f"  {name:<10} {score:+.3f}")


if __name__ == "__main__":
    main()
