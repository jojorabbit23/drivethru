#!/usr/bin/env python3
# Cuts the game trailer together: docs/video/trailer.mp4
#
#   python3 tools/make_trailer.py            # films every shot, then edits
#   python3 tools/make_trailer.py --edit     # re-edit already-filmed shots
#
# Needs godot, xvfb-run, ffmpeg, numpy. Each shot is filmed by
# tools/film_trailer.gd into a work folder, trimmed, cut together with a fade
# in and out, and scored with a soundtrack synthesised here: a drone under the
# title, a beat that drops on the first zombie shot, shotgun booms on the
# blasts, a last hit on the end card. The game's own sounds sit underneath.
import os, subprocess, sys, wave
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WORK = os.environ.get("TRAILER_WORK", "/tmp/drivethru_trailer")
OUT = os.path.join(ROOT, "docs/video/trailer.mp4")
FPS = 30
SR = 44100

# shot, first frame, last frame (trim away the set-up frames and anything messy)
EDIT = [
    ("opening", 6, 148),
    ("horde", 6, 64),
    ("boards", 6, 120),
    ("shotgun", 6, 117),
    ("harvest", 24, 128),
    ("grill", 6, 103),
    ("build", 28, 90),
    ("customer", 6, 123),
    ("serve", 6, 83),
    ("upgrade", 6, 93),
    ("lancer", 20, 143),
    ("finale", 6, 123),
]
# shotgun blasts, frames into the shotgun shot as filmed (film_trailer.gd)
BLASTS = [43, 77]


def film(shot):
    avi = os.path.join(WORK, shot + ".avi")
    subprocess.run(["xvfb-run", "-a", "godot", "--path", ROOT, "--rendering-method", "gl_compatibility",
                    "--fixed-fps", str(FPS), "--write-movie", avi, "--script", "res://tools/film_trailer.gd", "--", shot],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)


# --------------------------------------------------------------- music ----
def tone(f, t, kind="square", duty=0.5):
    ph = (f * t) % 1.0
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "saw":
        return 2.0 * ph - 1.0
    if kind == "tri":
        return 4.0 * np.abs(ph - 0.5) - 1.0
    return np.sin(2 * np.pi * f * t)


def note(n):  # MIDI note -> Hz
    return 440.0 * 2 ** ((n - 69) / 12.0)


def add(buf, at, sig):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def env(n, a=0.005, d=0.2, s=0.0, length=None):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4))
    return e * (s + (1 - s) * np.exp(-t / max(d, 1e-4)))


def kick():
    n = int(0.35 * SR); t = np.arange(n) / SR
    f = 50 + 110 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.9


def snare(rng):
    n = int(0.22 * SR); t = np.arange(n) / SR
    return (rng.uniform(-1, 1, n) * 0.6 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 18) * 0.55


def hat(rng):
    n = int(0.05 * SR)
    x = rng.uniform(-1, 1, n)
    x = np.diff(np.concatenate([[0], x]))       # brighter
    return x * np.exp(-np.arange(n) / SR * 80) * 0.18


def boom(rng):
    n = int(0.9 * SR); t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    low = np.convolve(noise, np.ones(30) / 30, mode="same")
    body = np.sin(2 * np.pi * np.cumsum(70 + 160 * np.exp(-t * 25)) / SR)
    return (noise * np.exp(-t * 30) * 0.7 + low * np.exp(-t * 6) * 1.6 + body * np.exp(-t * 7) * 0.8) * 0.8


def score(length, drop, finale_at, blasts):
    rng = np.random.default_rng(7)
    buf = np.zeros(int(length * SR) + SR)
    beat = 0.5                                       # 120 bpm
    # drone under the intro: E1 + B1 saw, slowly swelling, plus a riser
    n = int(drop * SR); t = np.arange(n) / SR
    drone = (tone(note(28), t, "saw") * 0.5 + tone(note(35), t, "saw") * 0.3) * np.convolve(np.ones(1), [1])[0]
    drone = np.convolve(drone, np.ones(60) / 60, mode="same") * np.minimum(1, t / 1.5) * 0.35
    riser = rng.uniform(-1, 1, n) * (t / drop) ** 3 * 0.25
    add(buf, 0, drone + riser)
    # the groove: E minor, bass riff per bar, square-wave lead, drums
    bass_riff = [40, 40, 43, 40, 45, 40, 43, 38]     # eighths over one bar
    lead = [64, 67, 71, 67, 69, 67, 64, 62, 64, 67, 71, 74, 72, 71, 67, 69]
    t0 = drop
    bar = 0
    while t0 < finale_at - 0.01:
        for k in range(8):                           # eighth notes
            at = t0 + k * beat / 2
            if at >= finale_at:
                break
            if k % 2 == 0:
                add(buf, at, kick() * (1.0 if k in (0, 4) else 0.6))
            if k in (2, 6):
                add(buf, at, snare(rng))
            add(buf, at, hat(rng))
            nb = int(0.22 * SR); tb = np.arange(nb) / SR
            add(buf, at, tone(note(bass_riff[k] - 12), tb, "tri") * env(nb, d=0.15, s=0.3) * 0.45)
            ln = int(0.24 * SR); tl = np.arange(ln) / SR
            li = lead[(bar * 8 + k) % len(lead)]
            if bar % 2 == 1 or k % 2 == 0:
                add(buf, at, tone(note(li), tl, "square", 0.25) * env(ln, d=0.12, s=0.2) * 0.13)
        t0 += 4 * beat
        bar += 1
    # end card: one big hit and a ringing E minor chord
    add(buf, finale_at, kick() * 1.2)
    add(buf, finale_at, boom(rng) * 0.6)
    cn = int(4.0 * SR); tc = np.arange(cn) / SR
    chord = sum(tone(note(m), tc, "saw") * w for m, w in [(40, 0.4), (52, 0.3), (55, 0.25), (59, 0.25), (64, 0.2)])
    chord = np.convolve(chord, np.ones(25) / 25, mode="same") * np.exp(-tc * 0.8) * 0.35
    add(buf, finale_at, chord)
    for b in blasts:
        add(buf, b, boom(rng))
    buf = buf[: int(length * SR)]
    buf /= max(1.0, np.max(np.abs(buf)) / 0.89)
    return buf


def write_wav(path, x):
    data = (np.clip(x, -1, 1) * 32000).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------- edit ----
def main():
    os.makedirs(WORK, exist_ok=True)
    if "--edit" not in sys.argv:
        for shot, _, _ in EDIT:
            print("filming", shot, flush=True)
            film(shot)
    parts = []
    t = 0.0
    starts = {}
    for shot, a, b in EDIT:
        src = os.path.join(WORK, shot + ".avi")
        dst = os.path.join(WORK, shot + "_cut.mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src,
                        "-vf", "select='between(n,%d,%d)',setpts=N/FRAME_RATE/TB" % (a, b),
                        "-af", "aselect='between(t,%f,%f)',asetpts=N/SR/TB,aresample=%d,pan=mono|c0=0.5*c0+0.5*c1" % (a / FPS, (b + 1) / FPS, SR),
                        "-r", str(FPS), "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p",
                        "-c:a", "pcm_s16le", "-ar", str(SR), "-ac", "1", dst.replace(".mp4", ".mkv")], check=True)
        starts[shot] = t
        t += (b - a + 1) / FPS
        parts.append(dst.replace(".mp4", ".mkv"))
    length = t
    lst = os.path.join(WORK, "list.txt")
    with open(lst, "w") as f:
        for p in parts:
            f.write("file '%s'\n" % p)
    joined = os.path.join(WORK, "joined.mkv")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined], check=True)
    drop = starts["horde"]
    sg = starts["shotgun"] - 6 / FPS
    music = score(length, drop, starts["finale"], [sg + f / FPS for f in BLASTS])
    mwav = os.path.join(WORK, "music.wav")
    write_wav(mwav, music)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", joined, "-i", mwav,
                    "-filter_complex",
                    "[0:v]fade=t=in:st=0:d=0.8,fade=t=out:st=%f:d=1.2[v];"
                    "[0:a]volume=0.55[g];[1:a]volume=1.0[m];[g][m]amix=inputs=2:normalize=0,afade=t=out:st=%f:d=1.2,alimiter=limit=0.95[a]" % (length - 1.2, length - 1.2),
                    "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-crf", "19", "-preset", "slow", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", OUT], check=True)
    print("wrote %s (%.1f s)" % (OUT, length))


if __name__ == "__main__":
    main()
