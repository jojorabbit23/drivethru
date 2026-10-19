#!/usr/bin/env python3
# Covers (thumbnails) for the YouTube Shorts: docs/marketing/shorts/*.png (1080x1920)
#
#   python3 tools/make_short_covers.py <frames dir>
# The frames are clean portrait frames from tools/film_shorts.gd (no hook or
# caption), e.g. filmed with:  -- kill "" ""  and picked with ffmpeg:
#   kill_33.png (the shotgun hit), g_95.png (grill_long), lancer_stab_70.png
# Text is the game's pixel font via tools/make_thumbnail.py.
import os, sys
from PIL import Image, ImageDraw, ImageEnhance
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_thumbnail as M

OUT = os.path.join(M.ROOT, "docs/marketing/shorts")
W, H = 1080, 1920


def base(path):
    im = Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(1.2)
    im = ImageEnhance.Contrast(im).enhance(1.08).convert("RGBA")
    # darken the top for the words
    shade = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(shade)
    for y in range(H):
        top = 200 * (1 - abs(y - 520) / 560)
        bottom = 235 * (y - 1560) / 360          # and fade out the game HUD at the bottom
        d.line([(0, y), (W, y)], fill=int(max(0, top, bottom)))
    dark = Image.new("RGBA", (W, H), M.NAVY + (255,))
    dark.putalpha(shade)
    im.alpha_composite(dark)
    return im


def centred(im, text, y, scale, colour):
    M.draw_text(im, text, (W - M.text_width(text, scale)) // 2, y, scale, colour)


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name)
    im.convert("RGB").save(p, optimize=True)
    print("wrote", p)


def main(frames):
    im = base(os.path.join(frames, "kill_33.png"))
    centred(im, "HOW", 250, 6, M.TEAL)
    centred(im, "ZOMBIE", 350, 11, M.CHALK)
    centred(im, "BURGERS", 530, 10, M.AMBER)
    centred(im, "ARE MADE", 710, 6, M.TEAL)
    b = M.burger(14).rotate(12, resample=Image.NEAREST, expand=True)
    im.alpha_composite(b, (W - b.width - 40, 1180))
    save(im, "zombie_burgers_cover.png")

    im = base(os.path.join(frames, "g_95.png"))
    centred(im, "SMASH", 300, 15, M.CHALK)
    centred(im, "BURGERS", 530, 10, M.AMBER)
    centred(im, "FROM ZOMBIES", 710, 5, M.TEAL)
    save(im, "smash_burgers_cover.png")

    im = base(os.path.join(frames, "lancer_stab_70.png"))
    centred(im, "IT STABS", 300, 9, M.CHALK)
    centred(im, "THROUGH", 460, 10, M.AMBER)
    centred(im, "YOUR BARRICADES", 640, 4, M.TEAL)
    save(im, "the_lancer_cover.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/drivethru_covers")
