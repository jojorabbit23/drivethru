"""Deterministic, quiet fungal breaths, stem snap and landing sounds. NumPy only."""
from pathlib import Path
import wave
import numpy as np
rate=22050
rng=np.random.default_rng(603)
out=Path(__file__).resolve().parents[2]/'enemies/scientist/audio'
out.mkdir(parents=True,exist_ok=True)
for name,duration in [('breath',.85),('snap',.23),('landing',.16)]:
 t=np.arange(int(rate*duration))/rate
 noise=rng.uniform(-1,1,t.size)
 low=np.convolve(noise,np.ones(21)/21,mode='same')
 if name=='breath':
  env=np.sin(np.pi*t/duration)**1.5
  audio=env*(low*.8+np.sin(2*np.pi*(75*t+5*np.sin(t*4)))*.09+np.sin(2*np.pi*151*t)*.035)
 elif name=='snap':audio=(noise*.20+low*.75)*np.exp(-t*30)+np.sin(2*np.pi*(130*t-100*t*t))*.25*np.exp(-t*19)
 else:audio=(low*.9+np.sin(2*np.pi*90*t)*.25)*np.exp(-t*30)
 audio*=.65/max(np.max(np.abs(audio)),.001)
 with wave.open(str(out/(name+'.wav')),'wb') as target:
  target.setnchannels(1);target.setsampwidth(2);target.setframerate(rate)
  target.writeframes(np.round(audio*32767).astype('<i2').tobytes())
 print('Baked scientist',name)
