"""Bake the Hollowhead's dry, clustered fungal clicks. NumPy only; deterministic."""
from pathlib import Path
import wave
import numpy as np
rate=22050
rng=np.random.default_rng(712)
audio=np.zeros(int(rate*.66),dtype=np.float64)
for index,start in enumerate([0,.052,.112,.18,.255,.34,.44,.55]):
    t=np.arange(int(rate*.065))/rate
    noise=rng.uniform(-1,1,t.size)
    grit=noise-np.convolve(noise,np.ones(7)/7,mode='same')
    tone=np.sin(2*np.pi*(1900*t-7500*t*t))
    body=np.sin(2*np.pi*210*t)
    pulse=(grit*.5+tone*.35)*np.exp(-t*100)+body*.22*np.exp(-t*65)
    pulse*=min(1,index/2+.65)
    offset=int(start*rate)
    audio[offset:offset+t.size]+=pulse
peak=np.max(np.abs(audio))
audio*=.82/peak
out=Path(__file__).resolve().parents[2]/'enemies/hollowhead/audio/click.wav'
with wave.open(str(out),'wb') as target:
    target.setnchannels(1);target.setsampwidth(2);target.setframerate(rate)
    target.writeframes(np.round(audio*32767).astype('<i2').tobytes())
print('Baked Hollowhead clicks:',out.name,'peak',round(float(np.max(np.abs(audio))),3))
