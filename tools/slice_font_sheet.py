#!/usr/bin/env python3
# One-off importer: turns the owner's lettering sheet (fonts/pixel/source/lettering_sheet.png)
# into fonts/pixel/glyphs.txt, the editable pixel source that tools/build_font.gd
# turns into the game font.
#
#   python3 tools/slice_font_sheet.py      (needs numpy, scipy, Pillow)
#
# Re-running it OVERWRITES glyphs.txt, so hand edits there would be lost.
#
# The sheet is pixel lettering drawn at about 10 screen px per pixel (not quite
# even). Each glyph is cut out, its own pixel grid is fitted to its bounding box,
# and every cell is classified as clear, outline or fill. The colon and
# semicolon dots touch at that scale, so those two are drawn here by hand. The
# characters the sheet lacks but the game uses (space % · [ ] | ' " = _) are drawn as fill shapes; their 1-pixel outline is added automatically
# so they match the sheet.
import numpy as np
from PIL import Image
from scipy import ndimage
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SHEET = os.path.join(ROOT, "fonts/pixel/source/lettering_sheet.png")
OUT = os.path.join(ROOT, "fonts/pixel/glyphs.txt")
U = 10.07          # sheet px per font pixel (cap height 141 px = 14 pixels)
CAP = 14
ORDER = ["ABCDEFGH", "IJKLMNOP", "QRSTUVWX", "YZ012345", "6789.,!?", ":;-+/()$"]

HAND = {  # [bottom, rows] with outline drawn in (# outline, o fill, . clear)
    ":": [0, ["#####", "#ooo#", "#ooo#", "#ooo#", "#####", ".....", ".....",
              "#####", "#ooo#", "#ooo#", "#ooo#", "#####"]],
    ";": [-1, [".#####", ".#ooo#", ".#ooo#", ".#ooo#", ".#####", "......", "......",
               "######", "#oooo#", "#oooo#", "##ooo#", "##oo##", "#####."]],
}
FILLS = {  # [bottom of the FILL, fill rows]; outline is added around it
    " ": [0, ["...."]],
    "·": [6, ["ooo", "ooo", "ooo"]],
    "'": [9, ["ooo", "ooo", "ooo", "oo."]],
    '"': [9, ["ooo.ooo", "ooo.ooo", "ooo.ooo", "oo..oo."]],
    "%": [1, ["ooo.....oo", "ooo....ooo", "ooo...ooo.", ".....ooo..", "....ooo...",
              "...ooo....", "..ooo.....", ".ooo...ooo", "ooo....ooo", "oo.....ooo"]],
    "[": [1, ["ooooo", "ooooo"] + ["ooo.."] * 8 + ["ooooo", "ooooo"]],
    "]": [1, ["ooooo", "ooooo"] + ["..ooo"] * 8 + ["ooooo", "ooooo"]],
    "|": [0, ["ooo"] * 14],
    "=": [4, ["oooooooo", "oooooooo", "........", "oooooooo", "oooooooo"]],
    "_": [-2, ["oooooooooo", "oooooooooo"]],
}

def outline(fill_rows):
    if fill_rows == ["...."]:
        return fill_rows
    f = np.array([[c == "o" for c in r] for r in fill_rows])
    f = np.pad(f, 1)
    d = ndimage.binary_dilation(f, structure=np.ones((3, 3), bool))
    return ["".join("o" if f[j, i] else ("#" if d[j, i] else ".") for i in range(f.shape[1]))
            for j in range(f.shape[0])]

def slice_sheet():
    a = np.array(Image.open(SHEET).convert("RGBA")).astype(float)
    alpha = a[..., 3] / 255
    lum = (a[..., 0] * .3 + a[..., 1] * .59 + a[..., 2] * .11) / 255
    lab, _ = ndimage.label(alpha > 0.5)
    comps = []
    for i, s in enumerate(ndimage.find_objects(lab)):
        if (lab[s] == i + 1).sum() > 200:
            comps.append([s[0].start, s[0].stop, s[1].start, s[1].stop])
    rows = {}
    for c in comps:
        rows.setdefault(min(5, int(((c[0] + c[1]) / 2 - 60) // 175)), []).append(c)
    boxes = {}
    for r, cs in rows.items():
        cs.sort(key=lambda c: c[2])
        merged = []
        for c in cs:   # the colon / semicolon come in two pieces
            if merged and c[2] < merged[-1][3] - 5:
                p = merged[-1]
                merged[-1] = [min(p[0], c[0]), max(p[1], c[1]), min(p[2], c[2]), max(p[3], c[3])]
            else:
                merged.append(c)
        assert len(merged) == 8, (r, len(merged))
        for ch, c in zip(ORDER[r], merged):
            boxes[ch] = c
    out = {}
    for r in range(6):
        base = int(np.median([boxes[ch][1] for ch in ORDER[r] if ch != ","]))
        for ch in ORDER[r]:
            y0, y1, x0, x1 = boxes[ch]
            w = max(1, round((x1 - x0) / U)); h = max(1, round((y1 - y0) / U))
            ux = (x1 - x0) / w; uy = (y1 - y0) / h
            grid = []
            for j in range(h):
                row = ""
                for i in range(w):
                    ya, yb = int(y0 + (j + .2) * uy), int(y0 + (j + .8) * uy)
                    xa, xb = int(x0 + (i + .2) * ux), int(x0 + (i + .8) * ux)
                    al = alpha[ya:yb, xa:xb]
                    lu = (lum[ya:yb, xa:xb] * al).sum() / max(1e-6, al.sum())
                    row += "." if al.mean() < 0.5 else ("#" if lu < 0.45 else "o")
                grid.append(row)
            # the last row has no letters to set a baseline: centre it on the caps
            bottom = round((base - y1) / U) if r < 5 else round(CAP / 2 - h / 2)
            out[ch] = [bottom, grid]
    return out

glyphs = slice_sheet()
glyphs.update(HAND)
for ch, (b, rows) in FILLS.items():
    glyphs[ch] = [b - 1 if ch != " " else 0, outline(rows)]
with open(OUT, "w") as f:
    f.write("# The Drive Thru pixel font. Built into the game font by tools/build_font.gd.\n"
            "# Each glyph: 'glyph <char> <bottom>' (rows of its lowest line above the\n"
            "# baseline; negative descends), then its rows: # outline, o fill, . clear.\n"
            "# Cap height is 14. Lowercase uses the capitals. 'space' is the space.\n\n")
    for ch, (b, rows) in glyphs.items():
        f.write("glyph %s %d\n%s\n\n" % ("space" if ch == " " else ch, b, "\n".join(rows)))
print("wrote", OUT, len(glyphs), "glyphs")
