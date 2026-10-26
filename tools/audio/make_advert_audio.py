#!/usr/bin/env python3
"""Synthesise the advert's phone caller: frantic, squeaky, unintelligible
chatter through a cheap handset ("SKRRT! CHK-CHK! EEEE! HRRRRK!").
Writes tools/advert/phone_squirl.wav (mono 22.05 kHz). NumPy only.
    python3 tools/audio/make_advert_audio.py
"""
import os, wave
import numpy as np

SR = 22050
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "advert", "phone_squirl.wav")


def chirp(dur, f0, f1, wobble=0.0, wob_rate=30.0):
    t = np.arange(int(dur * SR)) / SR
    f = np.linspace(f0, f1, t.size) * (1 + wobble * np.sin(2 * np.pi * wob_rate * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sign(np.sin(ph)) * 0.35 + np.sin(ph) * 0.65          # squeaky, a bit buzzy
    env = np.minimum(1, t / 0.01) * np.minimum(1, (t[-1] - t + 1e-4) / 0.03)
    return s * env


def noise(dur, gate_rate=0.0):
    n = rng.uniform(-1, 1, int(dur * SR))
    if gate_rate:
        t = np.arange(n.size) / SR
        n *= (np.sin(2 * np.pi * gate_rate * t) > 0)
    return n * np.minimum(1, np.linspace(0, dur / 0.01, n.size))


def gap(d):
    return np.zeros(int(d * SR))


parts = [
    noise(0.28, 38) * 0.5 + chirp(0.28, 900, 2400, 0.2),          # SKRRT
    gap(0.08),
    noise(0.07) * 0.8, gap(0.05), noise(0.07) * 0.8,               # CHK-CHK
    gap(0.12),
    chirp(0.6, 2600, 3100, 0.06, 9),                               # EEEE
    gap(0.1),
    chirp(0.45, 420, 260, 0.35, 45) + noise(0.45, 60) * 0.3,       # HRRRRK
    gap(0.15),
]
for i in range(9):                                                 # rambling
    f = rng.uniform(700, 2600)
    parts += [chirp(rng.uniform(0.06, 0.18), f, f * rng.uniform(0.7, 1.5), 0.15, rng.uniform(15, 40)), gap(rng.uniform(0.02, 0.09))]
parts += [chirp(0.35, 1800, 3400, 0.1), gap(0.1), noise(0.2, 45) * 0.5 + chirp(0.2, 1200, 600, 0.3)]
s = np.concatenate(parts)
# handset: band-pass ~400-3400 Hz (one-pole pairs) and a little line hiss
def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR); y = np.zeros_like(x); p = 0.0
    for i, v in enumerate(x):
        p = (1 - a) * v + a * p; y[i] = p
    return y
s = onepole_lp(s, 3400) - onepole_lp(onepole_lp(s, 3400), 400)
s += rng.normal(0, 0.01, s.size)
s = np.tanh(s * 3.0) / np.tanh(3.0)
s = (s / np.abs(s).max() * 0.8 * 32767).astype(np.int16)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with wave.open(OUT, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(s.tobytes())
print("wrote", OUT, "%.2f s" % (s.size / SR))
