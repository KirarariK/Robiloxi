"""Planche de comparaison : case de référence (haut) / rendu Blender (bas). python3 montage.py <prefix> <cells,...>"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from catalog import CATALOG  # noqa: E402

REF = os.path.join(HERE, "..", "reference", "encyclopedie_serpents.jpg")
PREV = os.path.join(HERE, "..", "exports", "preview")
im = Image.open(REF).convert("RGB")
cw, ch = 73.1, 68.0
prefix = sys.argv[1]
cells = sys.argv[2].split(",")
bycell = {c["cell"]: c for c in CATALOG}
T = 200
per = 7
rows = (len(cells) + per - 1) // per
sheet = Image.new("RGB", (per * T, rows * (2 * T + 20)), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for k, cell in enumerate(cells):
    s = bycell[cell]
    r = int(cell[1:cell.index("C")])
    c = int(cell[cell.index("C") + 1:])
    box = (int(0.5 + (c - 1) * cw) + 2, int(96.5 + (r - 1) * ch) + 2, int(0.5 + (c - 1) * cw) + 72, int(96.5 + (r - 1) * ch) + 68)
    x = (k % per) * T
    y = (k // per) * (2 * T + 20)
    sheet.paste(im.crop(box).resize((T, T)), (x, y + 20))
    p = os.path.join(PREV, "%s_%s.png" % (prefix, s["id"]))
    if os.path.exists(p):
        sheet.paste(Image.open(p).convert("RGB").resize((T, T)), (x, y + 20 + T))
    d.text((x + 4, y + 4), "%s %s" % (cell, s["id"]), fill=(255, 255, 0))
out = os.path.join(PREV, "cmp_%s.png" % prefix)
sheet.save(out)
print(out)
