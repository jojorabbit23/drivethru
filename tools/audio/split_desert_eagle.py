"""Extract owner's two Desert Eagle sounds. Usage: python split_desert_eagle.py /path/to/ffmpeg"""
from pathlib import Path
import subprocess
import sys
import tempfile
import wave
import numpy as np
folder = Path(__file__).resolve().parents[2] / "weapons/desert_eagle/audio"
with tempfile.TemporaryDirectory() as temp:
    decoded = Path(temp) / "decoded.wav"
    subprocess.run([sys.argv[1], "-v", "error", "-i", str(folder / "source/videoplayback.mp4"), "-vn", "-acodec", "pcm_s16le", "-y", str(decoded)], check=True)
    with wave.open(str(decoded)) as source:
        rate, channels = source.getframerate(), source.getnchannels()
        data = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2").reshape(-1, channels)
    for name, start, end in [("slide", 1.29, 2.10), ("shot", 3.20, len(data) / rate)]:
        clip = data[int(start * rate):int(end * rate)].astype(float)
        fade = min(int(.004 * rate), len(clip) // 2)
        clip[:fade] *= np.linspace(0, 1, fade)[:, None]
        clip[-fade:] *= np.linspace(1, 0, fade)[:, None]
        with wave.open(str(folder / (name + ".wav")), "wb") as out:
            out.setnchannels(channels)
            out.setsampwidth(2)
            out.setframerate(rate)
            out.writeframes(np.round(clip).astype("<i2").tobytes())
