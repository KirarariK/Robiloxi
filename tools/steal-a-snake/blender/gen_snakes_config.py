"""Génère le bloc SPECIES + LEGACY de SnakesConfig.lua depuis catalog.py (source unique)."""
import re
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from catalog import CATALOG  # noqa: E402

LUA = os.path.join(HERE, "..", "..", "..", "src", "ReplicatedStorage", "StealASnake", "Config", "SnakesConfig.lua")
src = open(LUA, encoding="utf-8").read()

# anciennes espèces (pour migrer les sauvegardes)
old = re.findall(r'\{ "([A-Za-z_]+)", "[^"]*", (\d+), (\d+),', src)

PAT = {"solid": "Solid", "bands": "Bands", "stripes": "Stripes", "spots": "Spots", "speckle": "Spots", "rainbow": "Bands",
       "patch": "Spots", "galaxy": "Glow", "lava": "Glow", "flame": "Glow", "scales": "Diamonds", "candy": "Stripes",
       "ice": "Solid", "water": "Solid", "stone": "Spots", "slime": "Glow", "bandage": "Rings", "ribs": "Rings",
       "pixel": "Solid", "robot": "Rings", "gold": "Solid"}
HEAD = {"cute": "Round", "viper": "Viper", "dragon": "Horned", "beak": "Crest", "skull": "Skull", "pumpkin": "Round",
        "robot": "Round", "pixel": "Round", "clown": "Round", "octopus": "Round", "blob": "Round", "toad": "Round"}
EXTRA = {"Fire": "Flames", "Sparkle": "Sparkle", "Stars": "Stars", "Bubbles": "Bubbles", "Ghost": "Ghost"}

lines = []
for z in range(1, 16):
    specs = sorted([c for c in CATALOG if c["zone"] == z], key=lambda c: c["rar"])
    lines.append("\t-- zone %d" % z)
    for c in specs:
        extras = ",".join(EXTRA[r] for r in c.get("rbx", []))
        mat = "Neon" if c.get("mat") == "neon" else "Smooth"
        lines.append('\t{ "%s", "%s", %d, %d, "%s", "%s", "%s", "%s", "%s", "%s" },' % (
            c["id"], c["name"], z, c["rar"], c["body"], c["accent"], PAT.get(c.get("pattern", "solid"), "Solid"),
            HEAD.get(c.get("head", "cute"), "Round"), extras, mat))

new_by = {}
for c in CATALOG:
    new_by.setdefault(c["zone"], []).append(c)
legacy = []
new_ids = {c["id"] for c in CATALOG}
for oid, z, r in old:
    if oid in new_ids:
        continue
    z, r = int(z), int(r)
    cands = sorted(new_by[z], key=lambda c: (abs(c["rar"] - r), -c["rar"]))
    legacy.append('\t%s = "%s",' % (oid, cands[0]["id"]))

if "local LEGACY" in src:
    m = re.search(r"local LEGACY: \{ \[string\]: string \} = \{\n(.*?)\n\}", src, re.S)
    if m:
        legacy = m.group(1).split("\n")
block = "local SPECIES = {\n" + "\n".join(lines) + "\n}\n\n-- Anciennes espèces (avant l'encyclopédie) → nouvelle espèce de même zone et rareté (migration des sauvegardes)\nlocal LEGACY: { [string]: string } = {\n" + "\n".join(legacy) + "\n}\n"
start = src.index("local SPECIES = {")
end = src.index("local function hex(")
if "local LEGACY" in src[:end]:
    pass
src = src[:start] + block + "\n" + src[end:]
open(LUA, "w", encoding="utf-8").write(src)
print(len(lines), "lines,", len(legacy), "legacy")
