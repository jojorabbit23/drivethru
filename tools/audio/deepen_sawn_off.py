"""Rebuild the owner's sawn-off blast. Requires NumPy; source WAV stays untouched."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "weapons/crop_duster/audio"
with wave.open(str(FOLDER / "source/explosive_shotgun_ear_ringing.wav"), "rb") as source:
    assert source.getnchannels() == 1 and source.getsampwidth() == 2
    rate = source.getframerate()
    original = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2").astype(np.float64) / 32768.0

time = np.arange(len(original)) / rate
# Remove inaudible infrasonic energy to make room for audible bass weight.
padding = rate
count = 1 << (len(original) + 2 * padding - 1).bit_length()
padded = np.zeros(count)
padded[padding:padding + len(original)] = original
frequencies = np.fft.rfftfreq(count, 1 / rate)
highpass = frequencies**4 / (frequencies**4 + 28.0**4)
bass = 1 + 2.6 * np.exp(-0.5 * ((frequencies - 72) / 46)**2)
body = 1 + 0.6 * np.exp(-0.5 * ((frequencies - 160) / 75)**2)
filtered = np.fft.irfft(np.fft.rfft(padded) * highpass * bass * body, n=count)[padding:padding + len(original)]
# Short low-frequency reflections add depth without washing out the attack.
low_response = highpass / (1 + (frequencies / 190)**6)
low = np.fft.irfft(np.fft.rfft(padded) * low_response, n=count)[padding:padding + len(original)]
for seconds, gain in [(0.037, 0.17), (0.071, 0.10)]:
    delay = round(seconds * rate)
    filtered[delay:] += low[:-delay] * gain
# An audible descending low thump supports the front of the supplied explosion.
phase = 2 * np.pi * (44 * time + 38 * (1 - np.exp(-time * 20)) / 20)
filtered += 0.35 * np.sin(phase) * (1 - np.exp(-time * 1700)) * np.exp(-time * 12)
filtered *= 0.90 / max(0.90, np.max(np.abs(filtered[:round(0.8 * rate)])))
# Soft amplifier-style limiting spends the recovered headroom on audible bass.
filtered = 0.90 * np.tanh(filtered * 6.0)
# Only process the opening blast. Beyond 0.85s the original ringing is bit-identical.
blend = 1 - np.clip((time - 0.55) / 0.30, 0, 1)
blend = blend * blend * (3 - 2 * blend)
result = original * (1 - blend) + filtered * blend
result[:88] *= np.linspace(0, 1, 88)
pcm = np.rint(np.clip(result, -0.999, 0.999) * 32768).astype("<i2")
output = FOLDER / "sawn_off_deep_blast.wav"
with wave.open(str(output), "wb") as stream:
    stream.setparams((1, 2, rate, 0, "NONE", "not compressed"))
    stream.writeframes(pcm.tobytes())

def band_rms(samples):
    samples = samples[:round(0.4 * rate)]
    spectrum = np.fft.rfft(samples)
    frequency = np.fft.rfftfreq(len(samples), 1 / rate)
    spectrum[(frequency < 35) | (frequency > 180)] = 0
    return float(np.sqrt(np.mean(np.fft.irfft(spectrum, n=len(samples))**2)))

original_pcm = np.rint(original * 32768).astype("<i2")
checks = {
    "duration_seconds": len(result) / rate,
    "peak_dbfs": float(20 * np.log10(np.max(np.abs(pcm.astype(float) / 32768)))),
    "bass_35_180hz_gain_db_first_400ms": float(20 * np.log10(band_rms(result) / band_rms(original))),
    "ringing_tail_bit_identical_after_seconds": 0.85,
    "tail_matches": bool(np.array_equal(pcm[round(0.85 * rate):], original_pcm[round(0.85 * rate):])),
    "clipped_samples": int(np.count_nonzero(np.abs(pcm.astype(np.int32)) >= 32767)),
}
assert checks["tail_matches"] and checks["clipped_samples"] == 0
assert checks["bass_35_180hz_gain_db_first_400ms"] > 2.0
(FOLDER / "processing_checks.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
print(json.dumps(checks, indent=2))
