# Deterministic, short glass break for decorative bottles. Requires NumPy.
from pathlib import Path
import wave
import numpy as np
out=Path(__file__).resolve().parents[2]/'props/empty_bottle/glass_break.wav'
sr=22050
t=np.arange(int(sr*.42))/sr
rng=np.random.default_rng(6)
noise=rng.normal(0,1,len(t))
signal=.15*(noise-np.roll(noise,1))*np.exp(-t*23)
for frequency in [1900,2700,3600,4900,6300]:
 signal+=.09*np.sin(2*np.pi*frequency*t)*np.exp(-t*16)
with wave.open(str(out),'wb') as stream:
 stream.setnchannels(1)
 stream.setsampwidth(2)
 stream.setframerate(sr)
 stream.writeframes((np.clip(signal,-.9,.9)*32767).astype('<i2').tobytes())
