"""Synthesizes the piano note samples used for the per-level arrow tunes.

Writes one mono 16-bit 22.05 kHz WAV per white key from C4 to C6 into
assets/audio/piano/. Pure stdlib so it runs anywhere without numpy.

Run from the project root:  python3 tool/generate_piano_notes.py

The model is additive: inharmonic partials whose upper harmonics decay faster
than the fundamental (the main thing that makes a tone read as "piano"), a
two-stage amplitude envelope, and a short filtered noise burst for the hammer.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
DURATION = 0.9
OUT_DIR = os.path.join("assets", "audio", "piano")

# White keys, C4 (MIDI 60) through C6 (MIDI 84).
WHITE_OFFSETS = (0, 2, 4, 5, 7, 9, 11)
MIDI_NOTES = [
    60 + octave * 12 + offset
    for octave in range(2)
    for offset in WHITE_OFFSETS
] + [84]

MAX_PARTIALS = 16
INHARMONICITY = 0.00035


def freq_of(midi):
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def envelope(t, tau_fast, tau_slow):
    return 0.72 * math.exp(-t / tau_fast) + 0.28 * math.exp(-t / tau_slow)


def synth(midi):
    rng = random.Random(midi * 7919)
    f0 = freq_of(midi)
    n_samples = int(SAMPLE_RATE * DURATION)
    nyquist = SAMPLE_RATE * 0.45

    # Bright, short-ringing at the top; darker and longer at the bottom.
    pitch_factor = 2.0 ** ((69 - midi) / 26.0)
    tau_fast = max(0.10, min(0.30, 0.18 * pitch_factor))
    tau_slow = max(0.32, min(1.10, 0.62 * pitch_factor))

    partials = []
    for n in range(1, MAX_PARTIALS + 1):
        freq = f0 * n * math.sqrt(1.0 + INHARMONICITY * n * n)
        if freq >= nyquist:
            break
        amp = (1.0 / (n ** 1.45)) * (0.85 + 0.3 * rng.random())
        # Upper partials die away first.
        decay = 1.0 + 0.62 * (n - 1)
        partials.append(
            (
                2.0 * math.pi * freq / SAMPLE_RATE,
                amp,
                rng.uniform(0, 2.0 * math.pi),
                tau_fast / decay,
                tau_slow / decay,
            )
        )

    attack = int(0.004 * SAMPLE_RATE)
    hammer_len = int(0.014 * SAMPLE_RATE)
    fade = int(0.012 * SAMPLE_RATE)

    samples = [0.0] * n_samples
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        value = 0.0
        for omega, amp, phase, tf, ts in partials:
            value += amp * envelope(t, tf, ts) * math.sin(omega * i + phase)
        samples[i] = value

    # Hammer thump: noise burst low-passed with a one-pole filter.
    noise_state = 0.0
    for i in range(hammer_len):
        noise_state += 0.35 * (rng.uniform(-1.0, 1.0) - noise_state)
        samples[i] += noise_state * 0.10 * (1.0 - i / hammer_len)

    for i in range(min(attack, n_samples)):
        samples[i] *= 0.5 - 0.5 * math.cos(math.pi * i / attack)
    for i in range(min(fade, n_samples)):
        samples[n_samples - 1 - i] *= i / fade

    peak = max(abs(v) for v in samples) or 1.0
    scale = 0.86 / peak
    return [int(max(-32768, min(32767, round(v * scale * 32767)))) for v in samples]


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack("<%dh" % len(samples), *samples))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for midi in MIDI_NOTES:
        path = os.path.join(OUT_DIR, "p%d.wav" % midi)
        write_wav(path, synth(midi))
        size = os.path.getsize(path)
        total += size
        print("%s  %7.1f Hz  %6.1f KB" % (os.path.basename(path), freq_of(midi), size / 1024))
    print("\n%d notes, %.2f MB total" % (len(MIDI_NOTES), total / 1024 / 1024))


if __name__ == "__main__":
    main()
