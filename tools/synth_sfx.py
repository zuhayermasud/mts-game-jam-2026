"""Synthesizes placeholder sound effects into audio/ as 16-bit mono 44.1 kHz WAVs.

Run from the project folder:  python3 -I tools/synth_sfx.py
Stdlib only. The names match what the game calls with Sfx.play(), so a real sound saved
under the same name (any of .ogg / .wav / .mp3) replaces the placeholder.
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")

random.seed(7)  # the same files every run, so git only sees real changes


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def tone(seconds, freq, end_freq=None, attack=0.005, decay=None, partials=((1, 1.0),)):
    """A sine sweep from freq to end_freq with an exponential decay envelope."""
    end_freq = freq if end_freq is None else end_freq
    decay = seconds / 4 if decay is None else decay
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq + (end_freq - freq) * (i / n)
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / attack) * math.exp(-t / decay)
        out.append(env * sum(a * math.sin(phase * k) for k, a in partials))
    return out


def noise(seconds, attack=0.01, decay=None, smooth=0.0, fade_in=False):
    """White noise, low-passed by `smooth` (0 = none, close to 1 = dull)."""
    decay = seconds / 3 if decay is None else decay
    n = int(RATE * seconds)
    out = []
    last = 0.0
    for i in range(n):
        t = i / RATE
        last = last * smooth + random.uniform(-1, 1) * (1 - smooth)
        if fade_in:
            env = math.sin(math.pi * i / n) ** 2
        else:
            env = min(1.0, t / attack) * math.exp(-t / decay)
        out.append(env * last)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def then(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def save(name, samples, peak=0.8):
    top = max(1e-9, max(abs(s) for s in samples))
    gain = peak / top
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print("wrote audio/%s.wav" % name)


def main():
    os.makedirs(OUT, exist_ok=True)
    # The metronome: short and low, so it sits under everything else.
    save("bubble", tone(0.08, 420, 180, attack=0.002, decay=0.025), peak=0.5)
    save("brew_ready", tone(0.35, 1320, attack=0.002, decay=0.09, partials=((1, 1.0), (2.76, 0.4))), peak=0.55)
    save("brew_perfect", mix(
        tone(0.7, 1046.5, attack=0.002, decay=0.18, partials=((1, 1.0), (3, 0.2))),
        then(silence(0.07), tone(0.63, 1568, attack=0.002, decay=0.2, partials=((1, 0.8), (2, 0.15)))),
    ))
    save("pull", mix(tone(0.07, 900, 300, attack=0.001, decay=0.02), noise(0.03, attack=0.001, decay=0.008)), peak=0.6)
    save("boil_start", mix(noise(0.45, smooth=0.85, fade_in=True), tone(0.45, 90, 140, attack=0.05, decay=0.2)), peak=0.6)
    save("boil_warning", [
        s * (0.5 + 0.5 * math.copysign(1, math.sin(2 * math.pi * 28 * i / RATE)))
        for i, s in enumerate(mix(noise(0.4, smooth=0.3, decay=0.25), tone(0.4, 220, 200, decay=0.25)))
    ], peak=0.6)
    save("boil_over", mix(noise(0.8, attack=0.02, decay=0.35, smooth=0.1), tone(0.5, 160, 60, decay=0.15)), peak=0.7)
    save("pour", then(*[tone(0.07, f, f * 0.6, attack=0.003, decay=0.025) for f in (260, 330, 290)]), peak=0.6)
    save("give", noise(0.22, smooth=0.6, fade_in=True), peak=0.5)
    save("splash", mix(noise(0.25, attack=0.002, decay=0.07, smooth=0.5), tone(0.12, 500, 160, attack=0.002, decay=0.04)), peak=0.6)
    save("refuse", [
        (s > 0) - (s < 0)  # squared off into a buzz; the silent gap stays silent
        for i, s in enumerate(then(tone(0.12, 150, 140, decay=10), silence(0.04), tone(0.18, 120, 110, decay=10)))
    ], peak=0.45)
    save("heartbeat", then(
        tone(0.12, 70, 45, attack=0.004, decay=0.04),
        silence(0.08),
        tone(0.14, 60, 40, attack=0.004, decay=0.05),
    ), peak=0.85)
    # Down the drain: a wash of water and three falling glugs.
    save("dump", mix(
        noise(0.5, attack=0.01, decay=0.2, smooth=0.7),
        then(*[then(tone(0.09, f, f * 0.5, attack=0.003, decay=0.03), silence(0.03)) for f in (380, 300, 220)]),
    ), peak=0.6)


if __name__ == "__main__":
    main()
