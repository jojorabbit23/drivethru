#!/usr/bin/env python3
"""Films the advert blockout and cuts it up for a video generator.

    python3 tools/make_advert.py            # film (tools/film_advert.gd) + process
    python3 tools/make_advert.py --process  # re-process an existing take

Writes docs/video/advert/:
  advert_blockout.mp4      the whole take, 1080p30 with the game's audio
  keyframes/NN_beat_start.png / NN_beat_end.png   first and last frame of each beat
  contact_sheet.png        every beat's start frame, labelled
  SHOT_LIST.md             beats with timecodes, frame numbers and script lines
Needs godot, xvfb-run, ffmpeg, Pillow.
"""
import json, os, shutil, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
WORK = os.environ.get("ADVERT_WORK", "/tmp/drivethru_advert")
OUT = os.path.join(ROOT, "docs/video/advert")
TAKE = os.path.join(WORK, "take.avi")
BEATS = os.path.join(WORK, "beats.json")


def film():
    os.makedirs(WORK, exist_ok=True)
    subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24", "godot", "--path", ROOT,
                    "--rendering-method", "gl_compatibility", "--fixed-fps", "30", "--resolution", "1920x1080",
                    "--write-movie", TAKE, "--script", "res://tools/film_advert.gd", "--", BEATS], check=True)


def tc(frame, fps):
    s = frame / fps
    return "%d:%05.2f" % (int(s // 60), s % 60)


def process():
    meta = json.load(open(BEATS))
    fps, total, beats = meta["fps"], meta["frames"], meta["beats"]
    os.makedirs(os.path.join(OUT, "keyframes"), exist_ok=True)
    mp4 = os.path.join(OUT, "advert_blockout.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", TAKE, "-c:v", "libx264", "-preset", "slow", "-crf", "18",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", mp4], check=True)
    frames_dir = os.path.join(WORK, "frames")
    shutil.rmtree(frames_dir, ignore_errors=True)
    os.makedirs(frames_dir)
    # every frame we need, in one decode
    want = set()
    for i, b in enumerate(beats):
        end = (beats[i + 1]["frame"] if i + 1 < len(beats) else total) - 1
        want.update([b["frame"] + 2, max(b["frame"] + 2, end)])
    sel = "+".join("eq(n\\,%d)" % f for f in sorted(want))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", TAKE, "-vf", "select='%s'" % sel, "-vsync", "0",
                    os.path.join(frames_dir, "f%04d.png")], check=True)
    got = sorted(os.listdir(frames_dir))
    mapping = dict(zip(sorted(want), got))
    lines = ["# Advert blockout: shot list", "",
             "In-game take of the owner's script, first person, 1920x1080 at %d fps, %s long." % (fps, tc(total, fps)),
             "Keyframes are the first and last frame of each beat (keyframes/), for image-to-video.", "",
             "| # | Beat | Start | End | Frames | Script |", "|---|---|---|---|---|---|"]
    thumbs = []
    for i, b in enumerate(beats):
        end = (beats[i + 1]["frame"] if i + 1 < len(beats) else total) - 1
        name = "%02d_%s" % (i + 1, b["name"])
        a = mapping[b["frame"] + 2]
        z = mapping[max(b["frame"] + 2, end)]
        shutil.copy(os.path.join(frames_dir, a), os.path.join(OUT, "keyframes", name + "_start.png"))
        shutil.copy(os.path.join(frames_dir, z), os.path.join(OUT, "keyframes", name + "_end.png"))
        thumbs.append((name, os.path.join(frames_dir, a)))
        lines.append("| %d | %s | %s | %s | %d-%d | %s |" % (i + 1, b["name"], tc(b["frame"], fps), tc(end + 1, fps), b["frame"], end, b["note"]))
    open(os.path.join(OUT, "SHOT_LIST.md"), "w").write("\n".join(lines) + "\n")
    cols, tw, th = 5, 384, 216
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows * (th + 24)), (16, 28, 44))
    draw = ImageDraw.Draw(sheet)
    for i, (name, path) in enumerate(thumbs):
        x, y = (i % cols) * tw, (i // cols) * (th + 24)
        sheet.paste(Image.open(path).convert("RGB").resize((tw, th)), (x, y))
        draw.text((x + 6, y + th + 5), name, fill=(233, 225, 209))
    sheet.save(os.path.join(OUT, "contact_sheet.png"))
    print("wrote", OUT, len(beats), "beats", tc(total, fps))


if __name__ == "__main__":
    if "--process" not in sys.argv:
        film()
    process()
