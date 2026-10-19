#!/usr/bin/env python3
# The YouTube thumbnail: docs/marketing/youtube_thumbnail.png (1280x720)
#
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 \
#       --script res://tools/capture_thumbnail.gd -- /tmp/drivethru_thumb
#   python3 tools/make_thumbnail.py /tmp/drivethru_thumb/thumb_a.png
#
# Text is drawn from the game's own pixel font (fonts/pixel/glyphs.txt), so it
# matches the lettering in the game; the burger is the game's pixel icon.
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "docs/marketing/youtube_thumbnail.png")
CHALK = (233, 225, 209)
AMBER = (243, 163, 77)
TEAL = (101, 201, 194)
ORANGE = (201, 107, 53)
NAVY = (16, 28, 44)


def load_glyphs():
    g, cur = {}, None
    for line in open(os.path.join(ROOT, "fonts/pixel/glyphs.txt")).read().split("\n"):
        if line.startswith("glyph "):
            p = line.split(" ")
            cur = " " if p[1] == "space" else p[1]
            g[cur] = (int(p[2]), [])
        elif line.strip() and cur is not None:
            g[cur][1].append(line.strip())
        elif not line.strip():
            cur = None
    return g


G = load_glyphs()


def text_width(s, scale):
    return sum((len(G[c][1][0]) + 1) * scale for c in s.upper()) - scale


def draw_text(img, s, x, y, scale, fill, shadow=True):
    """x, y: top-left of the cap height (14 units)."""
    d = ImageDraw.Draw(img)
    for pass_i in ([0, 1] if shadow else [1]):
        cx = x
        for c in s.upper():
            bottom, rows = G[c]
            top = y + (14 - bottom - len(rows)) * scale
            for j, row in enumerate(rows):
                for i, p in enumerate(row):
                    if p == ".":
                        continue
                    if pass_i == 0:          # hard drop shadow, a little down-right
                        col = (0, 0, 0)
                        ox, oy = scale, scale
                    else:
                        col = fill if p == "o" else NAVY
                        ox = oy = 0
                    x0 = cx + i * scale + ox
                    y0 = top + j * scale + oy
                    d.rectangle([x0, y0, x0 + scale - 1, y0 + scale - 1], fill=col)
            cx += (len(rows[0]) + 1) * scale


BURGER = [  # game/icons.gd "burger_special"
    ".......a........",
    ".....aaaaaa.....",
    "...aawaaawaaa...",
    "..aaaaaaaaawaa..",
    "..oooooooooooo..",
    ".oooooooooooooo.",
    ".oaaaaooooaaaao.",
    "..tetetetetete..",
    ".ssssssssssssss.",
    ".seeeesssseeees.",
    ".ssssssssssssss.",
    "..aaaaaaaaaaaa..",
    "..oaaaaaaaaaao..",
    "...oooooooooo...",
    "................",
    "................"]
KEY = {"a": AMBER, "o": ORANGE, "w": CHALK, "t": (40, 126, 131), "e": TEAL, "s": (36, 56, 75), "c": (39, 45, 50), "n": NAVY}


def burger(scale):
    im = Image.new("RGBA", (16 * scale, 16 * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for j, row in enumerate(BURGER):
        for i, p in enumerate(row):
            if p in KEY:
                d.rectangle([i * scale, j * scale, (i + 1) * scale - 1, (j + 1) * scale - 1], fill=KEY[p])
    # a dark pixel outline so it pops off anything
    a = im.split()[3].point(lambda v: 255 if v else 0)
    grown = a.filter(ImageFilter.MaxFilter(scale // 2 * 2 + 1))
    out = Image.new("RGBA", im.size, NAVY + (0,))
    out.putalpha(grown)
    out.alpha_composite(im)
    return out


def main(bg_path):
    bg = Image.open(bg_path).convert("RGB").resize((1280, 720))
    bg = ImageEnhance.Color(bg).enhance(1.25)
    bg = ImageEnhance.Contrast(bg).enhance(1.1).convert("RGBA")
    # darken the left for the words, and vignette the edges
    shade = Image.new("L", (1280, 720), 0)
    sd = ImageDraw.Draw(shade)
    for x in range(1280):
        a = int(max(0, 170 * (1 - x / 820)))
        sd.line([(x, 0), (x, 720)], fill=a)
    dark = Image.new("RGBA", (1280, 720), NAVY + (255,))
    dark.putalpha(shade)
    bg.alpha_composite(dark)
    vig = Image.new("L", (1280, 720), 0)
    ImageDraw.Draw(vig).ellipse([-200, -160, 1480, 880], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(120))
    black = Image.new("RGBA", (1280, 720), (0, 0, 0, 255))
    black.putalpha(vig.point(lambda v: int((255 - v) * 0.75)))
    bg.alpha_composite(black)
    # the burger skewered on the Lancer's left lance, with a warm glow
    glow = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([570, 410, 850, 650], fill=AMBER + (150,))
    glow = glow.filter(ImageFilter.GaussianBlur(45))
    bg.alpha_composite(glow)
    b = burger(12).rotate(-14, resample=Image.NEAREST, expand=True)
    bg.alpha_composite(b, (706 - b.width // 2, 534 - b.height // 2))
    # the words
    draw_text(bg, "THE DRIVE THRU", 44, 40, 3, AMBER)
    draw_text(bg, "ZOMBIE", 40, 100, 8, CHALK)
    draw_text(bg, "BURGERS", 40, 228, 8, AMBER)
    draw_text(bg, "KILL  COOK  SERVE", 46, 358, 3, TEAL)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bg.convert("RGB").save(OUT, optimize=True)
    print("wrote", OUT, "width of BURGERS:", text_width("BURGERS", 10))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/drivethru_thumb/thumb_a.png")
