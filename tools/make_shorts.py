#!/usr/bin/env python3
# Films and edits the YouTube Shorts (1080x1920) into docs/video/shorts/:
#
#   python3 tools/make_shorts.py             # film every shot, then edit
#   python3 tools/make_shorts.py --edit      # re-edit already-filmed shots
#
# Each shot is filmed in portrait by tools/film_shorts.gd with the short's hook
# and that shot's caption drawn in the pixel font; the music comes from
# tools/make_trailer.py's synthesiser. Page copy: docs/marketing/youtube_shorts.md
import os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_trailer as T

ROOT = T.ROOT
WORK = os.environ.get("SHORTS_WORK", "/tmp/drivethru_shorts")
OUT_DIR = os.path.join(ROOT, "docs/video/shorts")
FPS = 30

# name: (hook, music level, game-audio level, [(shot, caption, first, last, [blast frames])])
SHORTS = {
    "zombie_burgers": ("HOW ZOMBIE BURGERS ARE MADE", 0.8, 0.6, [
        ("kill", "1. KILL THE ZOMBIE", 8, 118, [30, 64]),
        ("drop", "2. TAKE ITS GLOWING MUSHROOM", 6, 100, []),
        ("grill", "3. SMASH IT ON THE GRILL", 6, 112, []),
        ("build", "4. BUILD THE BURGER", 26, 86, []),
        ("truck", "5. A SURVIVOR PULLS UP", 6, 96, []),
        ("serve", "6. GET PAID", 8, 86, []),
        ("endcard", "", 6, 79, []),
    ]),
    "smash_burgers": ("MUSHROOM SMASH BURGERS", 0.35, 1.0, [
        ("grill_long", "", 6, 200, []),
        ("build", "DOUBLE BLUE. ORDER UP.", 26, 86, []),
        ("endcard", "", 6, 79, []),
    ]),
    "the_lancer": ("THIS ZOMBIE STABS THROUGH YOUR BARRICADES", 0.8, 0.6, [
        ("lancer_lane", "MEET THE LANCER", 8, 100, []),
        ("lancer_pry", "IT PRIES YOUR BOARDS OFF", 20, 112, []),
        ("lancer_stab", "ANY GAP? IT STABS THROUGH", 30, 122, []),
        ("lancer_kill", "AIM FOR THE CAP", 8, 100, [22, 52]),
        ("endcard", "", 6, 79, []),
    ]),
}


def film(key, shot, hook, caption):
    avi = os.path.join(WORK, "%s_%s.avi" % (key, shot))
    subprocess.run(["xvfb-run", "-a", "godot", "--path", ROOT, "--rendering-method", "gl_compatibility",
                    "--fixed-fps", str(FPS), "--write-movie", avi, "--script", "res://tools/film_shorts.gd", "--",
                    shot, hook, caption], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)
    return avi


def main():
    os.makedirs(WORK, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    for key, (hook, music_vol, game_vol, shots) in SHORTS.items():
        if only and key not in only:
            continue
        parts, t, blasts = [], 0.0, []
        for i, (shot, caption, a, b, bl) in enumerate(shots):
            avi = os.path.join(WORK, "%s_%s.avi" % (key, shot))
            if "--edit" not in sys.argv:
                print("filming", key, shot, flush=True)
                film(key, shot, hook, caption)
            cut = os.path.join(WORK, "%s_%02d.mkv" % (key, i))
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", avi,
                            "-vf", "select='between(n,%d,%d)',setpts=N/FRAME_RATE/TB,scale=1080:1920:flags=lanczos" % (a, b),
                            "-af", "aselect='between(t,%f,%f)',asetpts=N/SR/TB,aresample=%d,pan=mono|c0=0.5*c0+0.5*c1" % (a / FPS, (b + 1) / FPS, T.SR),
                            "-r", str(FPS), "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p",
                            "-c:a", "pcm_s16le", "-ar", str(T.SR), "-ac", "1", cut], check=True)
            blasts += [t + (f - a) / FPS for f in bl]
            t += (b - a + 1) / FPS
            parts.append(cut)
        length = t
        lst = os.path.join(WORK, key + "_list.txt")
        with open(lst, "w") as f:
            f.writelines("file '%s'\n" % p for p in parts)
        joined = os.path.join(WORK, key + "_joined.mkv")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined], check=True)
        end_at = length - (shots[-1][3] - shots[-1][2] + 1) / FPS
        music = T.score(length, 0.4, end_at, blasts)
        mwav = os.path.join(WORK, key + "_music.wav")
        T.write_wav(mwav, music)
        out = os.path.join(OUT_DIR, key + ".mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", joined, "-i", mwav, "-filter_complex",
                        "[0:v]fade=t=in:st=0:d=0.3,fade=t=out:st=%f:d=0.6[v];"
                        "[0:a]volume=%f[g];[1:a]volume=%f[m];[g][m]amix=inputs=2:normalize=0,afade=t=out:st=%f:d=0.6,alimiter=limit=0.95[a]"
                        % (length - 0.6, game_vol, music_vol, length - 0.6),
                        "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-crf", "19", "-preset", "slow", "-pix_fmt", "yuv420p",
                        "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", out], check=True)
        print("wrote %s (%.1f s)" % (out, length), flush=True)


if __name__ == "__main__":
    main()
