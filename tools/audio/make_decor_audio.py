import numpy as np, wave
from pathlib import Path
out=Path(__file__).resolve().parents[2]/'art/building_decor/audio'
def save(name,x,loop=False):
    x=np.clip(x,-1,1); p=out/(name+'.wav')
    with wave.open(str(p),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(22050);w.writeframes((x*32767).astype('<i2').tobytes())
    # Godot WAV loop is set by the runtime, not the importer.
sr=22050
t=np.arange(sr*4)/sr
save('hum',.25*np.sin(2*np.pi*55*t)+.08*np.sin(2*np.pi*110*t))
t=np.arange(sr*8)/sr;x=np.zeros(len(t));notes=[261.63,329.63,392,329.63,293.66,349.23,440,392,329.63,392,523.25,392,293.66,349.23,392,293.66]
for i,f in enumerate(notes):
    j=int(i*.5*sr);u=np.arange(sr//2)/sr
    x[j:j+len(u)]+=.25*np.sin(2*np.pi*f*u)*np.minimum(1,u/.015)*np.exp(-u*6)
save('hold',x)
t=np.arange(int(sr*.4))/sr;rng=np.random.default_rng(12)
save('clunk',(.5*np.sin(2*np.pi*(160*t-100*t*t))+.15*rng.normal(size=len(t)))*np.exp(-t*20))
