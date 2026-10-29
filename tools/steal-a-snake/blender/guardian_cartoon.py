"""
Steal A Snake — les 15 gardiens « cartoon » (image de référence « LES 15 GARDIENS SERPENTS »), Blender.

Pour chaque gardien n (= zone n, répartition par thème) on produit :
  GuardianHead_<n> : tête détaillée, groupes Skull (crâne, yeux, cornes, crinière…) et Jaw (mâchoire inférieure,
                     dents, langue — animée par GuardianRenderer : toutes les pièces « jaw »).
  GuardianKit_<n>  : K<n>_Body / K<n>_BodyAlt (anneaux du corps), K<n>_Tail (bout de queue),
                     + K<n>_WingL/R (ailes), K<n>_HoodL/R (capuchon de cobra), K<n>_FinL/R (nageoires) selon le gardien.
Repère : Z haut, la tête regarde -Y ; les anneaux sont centrés à l'origine, allongés selon Y.
"""
import math
import os
import random

from mathutils import Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\devaa\Desktop\robiloxiiiii\tools\steal-a-snake\blender"
__file__ = os.path.join(_HERE, "cartoon_snakes.py")
exec(open(__file__, encoding="utf-8").read())

# zone -> gardien de l'image (répartition par thème)
GUARDIANS = [
    dict(zone=1, num=1, name="Gardien de la Nature", head="dragon", body="5E9E3A", dark="3E7A2A", belly="C8E07A", accent="8A5A30", eye="F0E040", glow=False,
         horns="branch", mane="leaves", ring_deco="leaves", alt_deco="flowers", tail="leaf", flowers=["E070D0", "F0A030", "F0F0F0"]),
    dict(zone=2, num=7, name="Gardien du Voyageur", head="cobra", body="D8B880", dark="A88050", belly="F2E2B8", accent="2E9AA0", eye="F0A030", glow=False,
         mane="fur", mane_col="E8C070", ornament="2EC0C0", ring_deco="tribal", alt_deco="tribal", tail="tuft", whiskers=True),
    dict(zone=3, num=12, name="Gardien du Venin", head="cobra", body="8ACB3A", dark="4E7A1E", belly="D8F08A", accent="7A3AA0", eye="F0F040", glow=True,
         hood=True, hood_col="6A2A90", skulls=True, fangs=True, ring_deco="skulls", alt_deco="skulls", tail="plain", alt_body="6A2A90"),
    dict(zone=4, num=5, name="Gardien des Glaces", head="dragon", body="9AD8F0", dark="5AA8D8", belly="E8F8FF", accent="D8F4FF", eye="60E8FF", glow=True,
         horns="ice", mane="ice", ring_deco="ice", alt_deco="ice", tail="crystal", teeth=True, glassy=True),
    dict(zone=5, num=10, name="Gardien des Jungles", head="tiger", body="E8862A", dark="1E1A18", belly="F8F0E0", accent="3A8A3A", eye="60C040", glow=False,
         ring_deco="stripes", alt_deco="vines", tail="stripes", fangs=True),
    dict(zone=6, num=3, name="Gardien de Pierre", head="rock", body="7A7A72", dark="55554E", belly="9A988C", accent="F0C030", eye="F0C030", glow=True,
         mane="moss_crystal", ring_deco="moss_crystal", alt_deco="moss", tail="crystal_gold"),
    dict(zone=7, num=8, name="Gardien des Runes", head="snake", body="7A4AB8", dark="4E2A88", belly="B08AE0", accent="D8A8FF", eye="F0C0FF", glow=True,
         ring_deco="runes", alt_deco="runes", tail="plain", floating="2A2438"),
    dict(zone=8, num=2, name="Gardien des Océans", head="dragon", body="2EB0D0", dark="1A6A9A", belly="F0E0B8", accent="F06A7A", eye="3A6AD0", glow=False,
         horns="curl", fins=True, mane="fins", ring_deco="dorsal_fin", alt_deco="dorsal_fin", tail="fin"),
    dict(zone=9, num=11, name="Gardien de Magma", head="dragon", body="2A1E1C", dark="1A1210", belly="4A2A20", accent="FF7A20", eye="FFB030", glow=True,
         horns="dragon", mane="spikes", ring_deco="lava", alt_deco="lava", tail="flame", lava=True, fangs=True),
    dict(zone=10, num=14, name="Gardien du Chaos", head="dragon", body="3A3036", dark="1E1A1E", belly="5A2A30", accent="F02040", eye="FF3040", glow=True,
         horns="big", mane="red_crystals", ring_deco="red_crystals", alt_deco="spikes", tail="crystal_red", fangs=True),
    dict(zone=11, num=13, name="Gardien de l'Ombre", head="snake", body="3A1A60", dark="1A0A30", belly="6A3AA0", accent="B060FF", eye="E0A0FF", glow=True,
         ring_deco="smoke", alt_deco="smoke", tail="smoke", aura=True),
    dict(zone=12, num=4, name="Gardien des Cieux", head="beak", body="F4F2EC", dark="D8D4C8", belly="FFF8E8", accent="E8B840", eye="4AA0E0", glow=False,
         horns="gold_crest", wings="feather", ring_deco="gold_scales", alt_deco="gold_band", tail="feather"),
    dict(zone=13, num=9, name="Gardien de Fer", head="mech", body="8A8C94", dark="5A5C64", belly="6A6C74", accent="C08A3A", eye="FF2A2A", glow=True,
         ring_deco="armor", alt_deco="gear", tail="mech", fangs=True),
    dict(zone=14, num=6, name="Gardien de la Tempête", head="dragon", body="243A7A", dark="142250", belly="F0D040", accent="F8E040", eye="F8F060", glow=True,
         horns="lightning", mane="lightning", ring_deco="lightning", alt_deco="lightning", tail="lightning"),
    dict(zone=15, num=15, name="L'Ultime Destructeur", head="dragon", body="2A2220", dark="140E0C", belly="5A2010", accent="FF6A10", eye="FFC040", glow=True,
         horns="big", mane="flames", ring_deco="lava_spikes", alt_deco="flames", tail="flame", lava=True, fangs=True),
]


def gk(g):
    return "g" if g.get("glassy") else "c"


# ───────────────────────── Tête ─────────────────────────

def add_teeth(M, group, a, b, n, down, size=0.12, col="F6F2E6"):
    a, b = Vector(a), Vector(b)
    for k in range(n):
        p = a.lerp(b, (k + 0.5) / n)
        v, f = cone(p, p + Vector((0, 0, -size if down else size)), size * 0.4, 0.0, seg=6)
        M.add(group, v, f, ("c", col), outline=0.008)


def guardian_eye(M, g, c, out, r, side):
    c, out = Vector(c), Vector(out).normalized()
    v, f = ellipsoid(c, (r, r * 0.8, r * 0.75), seg=14, rings=8)
    M.add("Skull", v, f, ("c", "F8F4E8" if not g["glow"] else "1A1418"), outline=0.02)
    if g["glow"]:
        v, f = ellipsoid(c + out * r * 0.45, (r * 0.75, r * 0.6, r * 0.55), seg=12, rings=7)
        M.add("Skull", v, f, ("n", g["eye"]))
        v, f = ellipsoid(c + out * r * 0.8, (r * 0.18, r * 0.2, r * 0.45), seg=8, rings=5)
        M.add("Skull", v, f, ("c", "1A1012"))
    else:
        v, f = ellipsoid(c + out * r * 0.5, (r * 0.6, r * 0.5, r * 0.55), seg=12, rings=7)
        M.add("Skull", v, f, ("c", g["eye"]))
        v, f = ellipsoid(c + out * r * 0.82, (r * 0.2, r * 0.2, r * 0.42), seg=8, rings=5)
        M.add("Skull", v, f, ("c", "141018"))
        v, f = ellipsoid(c + out * r * 0.9 + Vector((side * 0.06, 0, r * 0.25)), (r * 0.14,) * 3, seg=6, rings=4)
        M.add("Skull", v, f, ("c", "FFFFFF"))
    # sourcil menaçant
    v, f = box(c + Vector((0, -0.05, r * 0.85)), (r * 2.2, r * 0.9, r * 0.35), Matrix.Rotation(-side * 0.38, 3, "Y"))
    M.add("Skull", v, f, ("c", g["dark"]), outline=0.012)


def loft(sections, seg=20, squash=0.45, color_fn=None):
    """Maillage lissé passant par des sections elliptiques (y, demi-largeur, demi-hauteur, z centre).
    Le dessous est aplati (squash) pour un museau en coin façon dragon."""
    verts, faces, info = [], [], []
    for (y, w, h, zc) in sections:
        for k in range(seg):
            a = 2 * math.pi * k / seg
            sz = math.sin(a)
            verts.append((math.cos(a) * w, y, zc + sz * h * (1.0 if sz > 0 else squash)))
    n = len(sections)
    for i in range(n - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            faces.append([i * seg + k, i * seg + k2, (i + 1) * seg + k2, (i + 1) * seg + k])
            info.append((i, k))
    # bouchons
    for idx, rev in ((0, False), (n - 1, True)):
        y, w, h, zc = sections[idx]
        c = len(verts)
        verts.append((0, y + (0.08 if not rev else -0.08), zc))
        for k in range(seg):
            k2 = (k + 1) % seg
            faces.append([c, idx * seg + k, idx * seg + k2] if not rev else [c, idx * seg + k2, idx * seg + k])
            info.append((idx, k))
    return verts, faces, info


DRAGON_TOP = [(0.70, 0.50, 0.50, 0.20), (0.40, 0.84, 0.74, 0.18), (0.05, 0.96, 0.74, 0.14), (-0.35, 0.90, 0.62, 0.08),
              (-0.80, 0.72, 0.46, -0.02), (-1.25, 0.60, 0.38, -0.08), (-1.70, 0.52, 0.32, -0.12), (-2.05, 0.40, 0.25, -0.15),
              (-2.25, 0.22, 0.15, -0.16)]
SNAKE_TOP = [(0.60, 0.55, 0.45, 0.10), (0.30, 0.88, 0.62, 0.10), (-0.05, 0.98, 0.62, 0.06), (-0.50, 0.88, 0.50, 0.00),
             (-0.95, 0.70, 0.40, -0.06), (-1.35, 0.52, 0.30, -0.10), (-1.60, 0.30, 0.18, -0.12)]
JAW = [(0.25, 0.70, 0.22, -0.42), (-0.20, 0.74, 0.22, -0.46), (-0.70, 0.62, 0.20, -0.50), (-1.20, 0.52, 0.17, -0.52),
       (-1.65, 0.42, 0.14, -0.53), (-1.95, 0.24, 0.10, -0.53)]


def rot_about(v, pivot, axis, ang):
    m = Matrix.Rotation(ang, 3, axis)
    pv = Vector(pivot)
    return [tuple(m @ (Vector(p) - pv) + pv) for p in v]


def build_guardian_head(g):
    n = g["zone"]
    M = Model("GuardianHead_%d" % n)
    if g.get("aura"):
        M.ink = ("n", g["accent"])
        M.inkw = 1.6
    kind = g["head"]
    body, dark, belly, acc = g["body"], g["dark"], g["belly"], g["accent"]
    hk = gk(g)
    open_ang = {"dragon": 0.38, "beak": 0.22, "snake": 0.08, "cobra": 0.42, "tiger": 0.5, "rock": 0.25, "mech": 0.35}[kind]
    hinge = Vector((0, 0.35, -0.30))
    M.hinge("Jaw", hinge)
    if kind in ("dragon", "beak", "snake", "cobra", "rock", "mech"):
        secs = DRAGON_TOP if kind in ("dragon", "beak", "rock", "mech") else SNAKE_TOP
        if kind == "beak":
            secs = secs[:-2]
        v, f, info = loft(secs, seg=24, squash=0.35)
        cols = []
        for (i, k), face in zip(info, f):
            ctr = sum((Vector(v[q]) for q in face), Vector((0, 0, 0))) / len(face)
            n0 = math.sin(ctr.x * 3.1 + ctr.y * 2.7) + math.sin(ctr.y * 4.3 - ctr.x * 1.7)
            if kind == "mech":
                cols.append(("c", dark if (int((ctr.y + 3) * 2) % 2 == 0 and ctr.z > 0.2) else body))
            elif kind == "rock":
                cols.append(("c", dark if n0 > 0.6 else body))
            elif ctr.z < -0.18:
                cols.append((hk, belly))
            elif ctr.z > 0.35 and n0 > 0.8:
                cols.append((hk, dark))
            else:
                cols.append((hk, body))
        M.add("Skull", v, f, cols, outline=0.045)
        tip_y = secs[-1][0]
        # intérieur de gueule
        v, f = ellipsoid((0, -0.9, -0.36), (0.62, 1.15, 0.16), seg=16, rings=8)
        M.add("Skull", v, f, ("c", "7A1A28"))
        if kind == "beak":
            v, f = cone(Vector((0, tip_y + 0.2, -0.05)), Vector((0, tip_y - 0.75, -0.32)), 0.36, 0.02, seg=14)
            M.add("Skull", v, f, ("c", acc), outline=0.02)
        # narines
        for sd in (-1, 1):
            v, f = ellipsoid((sd * 0.2, tip_y + 0.18, secs[-1][3] + secs[-1][2] * 0.9), (0.07, 0.05, 0.04), seg=8, rings=5)
            M.add("Skull", v, f, ("c", "1A1012"))
        # yeux en amande + arcades
        for sd in (-1, 1):
            ec = Vector((sd * 0.80, -0.42 if kind not in ("snake", "cobra") else -0.35, 0.36))
            r = 0.25
            v, f = ellipsoid(ec, (r * 0.75, r * 1.25, r * 0.7), Matrix.Rotation(sd * 0.35, 3, "Z"), seg=14, rings=8)
            M.add("Skull", v, f, ("c", "1A1418") if g["glow"] else ("c", "F8F4E8"), outline=0.02)
            iris_c = ec + Vector((sd * 0.07, -0.04, 0.0))
            if g["glow"]:
                v, f = ellipsoid(iris_c, (r * 0.55, r * 1.0, r * 0.55), Matrix.Rotation(sd * 0.35, 3, "Z"), seg=12, rings=7)
                M.add("Skull", v, f, ("n", g["eye"]))
            else:
                v, f = ellipsoid(iris_c, (r * 0.55, r * 0.75, r * 0.55), Matrix.Rotation(sd * 0.35, 3, "Z"), seg=12, rings=7)
                M.add("Skull", v, f, ("c", g["eye"]))
            v, f = ellipsoid(iris_c + Vector((sd * 0.07, 0, 0)), (0.03, 0.06, 0.12), seg=8, rings=5)
            M.add("Skull", v, f, ("c", "141018"))
            v, f = ellipsoid(iris_c + Vector((sd * 0.09, -0.06, 0.07)), (0.03,) * 3, seg=6, rings=4)
            M.add("Skull", v, f, ("c", "FFFFFF"))
            # arcade sourcilière inclinée (regard féroce)
            bc = ec + Vector((-sd * 0.02, -0.02, 0.2))
            v, f = ellipsoid(bc, (0.16, 0.3, 0.07), Matrix.Rotation(-sd * 0.5, 3, "Y") @ Matrix.Rotation(sd * 0.35, 3, "Z"), seg=12, rings=6)
            M.add("Skull", v, f, ("c", dark), outline=0.015)
            # joues / épines
            if kind in ("dragon", "rock"):
                v, f = cone(Vector((sd * 0.85, 0.15, -0.05)), Vector((sd * 1.35, 0.55, 0.05)), 0.16, 0.0, seg=8)
                M.add("Skull", v, f, ("c", dark), outline=0.012)
        # dents supérieures
        if kind not in ("beak",):
            for sd in (-1, 1):
                add_teeth(M, "Skull", Vector((sd * 0.62, -0.25, -0.22)), Vector((sd * 0.3, tip_y + 0.25, -0.24)), 6, True, 0.16, "F6F2E6" if kind != "mech" else "D8D8E0")
            if g.get("fangs"):
                for sd in (-1, 1):
                    v, f = cone(Vector((sd * 0.34, tip_y + 0.45, -0.2)), Vector((sd * 0.32, tip_y + 0.4, -0.72)), 0.08, 0.0, seg=8)
                    M.add("Skull", v, f, ("c", "F8F4EA"), outline=0.012)
        # mâchoire inférieure ouverte
        v, f, info = loft(JAW if kind != "beak" else JAW[:-2], seg=20, squash=1.0)
        v = rot_about(v, hinge, "X", open_ang)
        cols = [((hk if kind not in ("mech", "rock") else "c"), belly if kind not in ("mech", "rock") else dark) for _ in f]
        M.add("Jaw", v, f, cols, outline=0.035)
        v, f = ellipsoid((0, -0.8, -0.34), (0.5, 0.95, 0.07), seg=14, rings=6)
        M.add("Jaw", rot_about(v, hinge, "X", open_ang), f, ("c", "B83A4A"))
        v, f = ellipsoid((0, -1.0, -0.28), (0.18, 0.6, 0.06), seg=10, rings=5)
        M.add("Jaw", rot_about(v, hinge, "X", open_ang), f, ("c", "E05A70"))
        if kind != "beak":
            for sd in (-1, 1):
                pts = []
                a0, b0 = Vector((sd * 0.55, -0.15, -0.28)), Vector((sd * 0.3, -1.75, -0.36))
                for k in range(5):
                    p = a0.lerp(b0, (k + 0.5) / 5)
                    v, f = cone(p, p + Vector((0, 0, 0.15)), 0.06, 0.0, seg=6)
                    M.add("Jaw", rot_about(v, hinge, "X", open_ang), f, ("c", "F6F2E6" if kind != "mech" else "D8D8E0"), outline=0.008)
        if kind == "mech":
            for sd in (-1, 1):
                for k in range(3):
                    v, f = ellipsoid((sd * 0.9, -0.2 - k * 0.5, 0.2), (0.07, 0.08, 0.08), seg=8, rings=5)
                    M.add("Skull", v, f, ("c", acc))
            v, f = torus((1.0, 0.25, 0.15), 0.32, 0.08, axis=(1, 0, 0), seg=16, tseg=6)
            M.add("Skull", v, f, ("c", acc), outline=0.01)
            for k in range(8):
                a = k / 8 * math.pi * 2
                v, f = box((1.0, 0.25 + math.cos(a) * 0.42, 0.15 + math.sin(a) * 0.42), (0.1, 0.12, 0.12))
                M.add("Skull", v, f, ("c", acc))
            v, f = box((0, 0.0, 0.66), (0.9, 1.2, 0.12))
            M.add("Skull", v, f, ("c", dark), outline=0.015)
        if kind == "rock":
            for k in range(6):
                p = Vector((((k % 3) - 1) * 0.4, 0.3 - (k // 3) * 0.6, 0.7))
                v, f = ellipsoid(p, (0.32, 0.36, 0.14), seg=8, rings=5)
                M.add("Skull", v, f, ("c", "5A8A2A"), outline=0.01)
    elif kind == "tiger":
        v, f = ellipsoid((0, 0, 0.05), (1.1, 1.0, 0.95), seg=26, rings=16)
        cols = []
        for face in f:
            ctr = sum((Vector(v[q]) for q in face), Vector((0, 0, 0))) / len(face)
            stripe = math.sin(ctr.x * 6.5 + abs(ctr.x) * 2 + ctr.y * 1.5) > 0.7 and ctr.z > 0.0 and abs(ctr.x) > 0.15
            white = ctr.y < -0.55 and ctr.z < 0.25
            cols.append(("c", "1E1A18" if stripe else ("F8F0E0" if white else body)))
        M.add("Skull", v, f, cols, outline=0.045)
        v, f = ellipsoid((0, -0.85, -0.18), (0.7, 0.55, 0.42), seg=20, rings=12)
        M.add("Skull", v, f, ("c", "F8F0E0"), outline=0.035)
        v, f = ellipsoid((0, -1.32, 0.05), (0.2, 0.12, 0.13), seg=10, rings=6)
        M.add("Skull", v, f, ("c", "D86A7A"), outline=0.01)
        for sd in (-1, 1):
            v, f = cone(Vector((sd * 0.72, 0.25, 0.72)), Vector((sd * 0.95, 0.35, 1.28)), 0.32, 0.05, seg=10)
            M.add("Skull", v, f, ("c", body), outline=0.02)
            v, f = cone(Vector((sd * 0.72, 0.18, 0.76)), Vector((sd * 0.9, 0.26, 1.16)), 0.18, 0.03, seg=8)
            M.add("Skull", v, f, ("c", "F8F0E0"))
            ec = Vector((sd * 0.5, -0.72, 0.42))
            v, f = ellipsoid(ec, (0.2, 0.12, 0.16), Matrix.Rotation(sd * 0.3, 3, "Y"), seg=12, rings=7)
            M.add("Skull", v, f, ("c", "F8F4E8"), outline=0.015)
            v, f = ellipsoid(ec + Vector((0, -0.06, 0)), (0.12, 0.08, 0.12), seg=10, rings=6)
            M.add("Skull", v, f, ("c", g["eye"]))
            v, f = ellipsoid(ec + Vector((0, -0.11, 0)), (0.03, 0.04, 0.1), seg=6, rings=4)
            M.add("Skull", v, f, ("c", "141018"))
            v, f = ellipsoid(ec + Vector((0, -0.02, 0.17)), (0.26, 0.12, 0.06), Matrix.Rotation(-sd * 0.45, 3, "Y"), seg=10, rings=5)
            M.add("Skull", v, f, ("c", "1E1A18"))
            for k in range(3):
                a0 = Vector((sd * 0.5, -1.0, -0.05 - k * 0.08))
                v, f = cone(a0, a0 + Vector((sd * 0.95, -0.1, 0.12 - k * 0.12)), 0.015, 0.005, seg=5)
                M.add("Skull", v, f, ("c", "F8F8F8"))
            # crocs
            v, f = cone(Vector((sd * 0.3, -1.15, -0.45)), Vector((sd * 0.28, -1.18, -0.9)), 0.08, 0.0, seg=8)
            M.add("Skull", v, f, ("c", "F8F4EA"), outline=0.012)
        v, f = ellipsoid((0, -0.95, -0.4), (0.55, 0.45, 0.14), seg=14, rings=6)
        M.add("Skull", v, f, ("c", "7A1A28"))
        v, f = ellipsoid((0, -0.75, -0.62), (0.62, 0.55, 0.2), seg=16, rings=8)
        M.add("Jaw", rot_about(v, hinge, "X", open_ang), f, ("c", "F8F0E0"), outline=0.03)
        v, f = ellipsoid((0, -0.85, -0.5), (0.4, 0.42, 0.06), seg=12, rings=5)
        M.add("Jaw", rot_about(v, hinge, "X", open_ang), f, ("c", "E05A70"))
    decorate_head(M, g)
    return M


def decorate_head(M, g):
    acc, dark, body = g["accent"], g["dark"], g["body"]
    horns = g.get("horns")
    mane = g.get("mane")
    rnd = random.Random(g["zone"] * 31)
    for sd in (-1, 1):
        if horns in ("dragon", "big", "curl", "ice", "lightning", "branch", "gold_crest"):
            L = {"dragon": 1.4, "big": 2.1, "curl": 1.3, "ice": 1.5, "lightning": 1.4, "branch": 1.6, "gold_crest": 1.3}[horns]
            col = {"dragon": "3A2A24", "big": "2A2228", "curl": "1A6A9A", "ice": "D8F4FF", "lightning": "F8E040", "branch": "8A5A30", "gold_crest": "E8B840"}[horns]
            kind = "g" if horns == "ice" else ("n" if horns == "lightning" else "c")
            pts = [Vector((sd * 0.5, 0.35, 0.65))]
            for k in range(1, 5):
                u = k / 4
                curl = (math.sin(u * 2.2) * 0.6) if horns in ("big", "curl") else 0.2 * u
                pts.append(pts[0] + Vector((sd * (0.35 * u + (0.3 * u if horns == "big" else 0)), L * u * 0.85, L * u * 0.55 + curl * 0.4 - (0.6 * u * u if horns == "big" else 0))))
            for k in range(4):
                r0 = 0.24 * (1 - k / 4) + 0.02
                r1 = 0.24 * (1 - (k + 1) / 4) + 0.01
                v, f = cone(pts[k], pts[k + 1], r0, r1, seg=10)
                M.add("Skull", v, f, (kind, col), outline=0.014)
            if horns == "branch":
                for k in (1, 2, 3):
                    b = pts[k]
                    v, f = cone(b, b + Vector((sd * 0.35, -0.1, 0.45)), 0.08, 0.02, seg=8)
                    M.add("Skull", v, f, ("c", col), outline=0.01)
    if mane == "leaves":
        for k in range(14):
            ang = math.pi * (0.05 + 0.9 * k / 13)
            p = Vector((math.cos(ang) * 0.95, 0.55 + 0.1 * math.sin(k), math.sin(ang) * 0.7 + 0.2))
            d = Vector((math.cos(ang) * 0.6, 0.8, math.sin(ang) * 0.6)).normalized()
            v, f = flat_shape(p, leaf2d(0.9, 0.3), Vector((-math.sin(ang), 0.2, math.cos(ang))), d, 0.04)
            M.add("Skull", v, f, ("c", "4CA03A" if k % 2 else "2E7A2A"), outline=0.012)
        for k, col in enumerate(g.get("flowers", [])):
            add_flower(M, "Skull", Vector(((k - 1) * 0.5, 0.2 + 0.2 * k, 0.85)), 0.2, col, "F8E060")
    elif mane == "fur":
        for k in range(26):
            ang = math.pi * (-0.15 + 1.3 * k / 25)
            base = Vector((math.cos(ang) * 0.85, 0.5, math.sin(ang) * 0.75 + 0.15))
            tip = base + Vector((math.cos(ang) * 0.9, 1.3 + rnd.uniform(0, 0.4), math.sin(ang) * 0.7 - 0.2))
            v, f = cone(base, tip, 0.22, 0.02, seg=8)
            M.add("Skull", v, f, ("c", g.get("mane_col", "E8C070") if k % 3 else "C89A50"), outline=0.012)
        if g.get("ornament"):
            v, f = ellipsoid((0, -0.55, 0.78), (0.24, 0.1, 0.16), seg=12, rings=6)
            M.add("Skull", v, f, ("n", g["ornament"]), outline=0.01)
    elif mane == "ice":
        for k in range(9):
            ang = math.pi * (0.1 + 0.8 * k / 8)
            base = Vector((math.cos(ang) * 0.7, 0.4 + 0.05 * k, math.sin(ang) * 0.7))
            v, f = cone(base, base + Vector((math.cos(ang) * 0.8, 1.1, math.sin(ang) * 0.9)), 0.22, 0.0, seg=6)
            M.add("Skull", v, f, ("g", "D8F4FF" if k % 2 else "9AD8F0"), outline=0.012)
    elif mane == "fins":
        for sd in (-1, 1):
            for k in range(4):
                base = Vector((sd * 0.85, 0.2 + k * 0.22, 0.3 - k * 0.1))
                v, f = flat_shape(base, leaf2d(1.0 - k * 0.12, 0.25), Vector((0, 0, 1)), Vector((sd * 0.8, 0.6, 0.3)), 0.04)
                M.add("Skull", v, f, ("c", acc), outline=0.012)
        for k in range(5):
            base = Vector((0, 0.3 + k * 0.3, 0.75 - k * 0.05))
            v, f = flat_shape(base, leaf2d(0.7 - k * 0.08, 0.22), Vector((1, 0, 0)), Vector((0, 0.4, 1)), 0.04)
            M.add("Skull", v, f, ("c", acc), outline=0.012)
    elif mane in ("spikes", "red_crystals", "lightning", "flames", "moss_crystal"):
        for k in range(7):
            base = Vector(((k % 2 - 0.5) * 0.25, 0.4 + k * 0.25, 0.8 - k * 0.12))
            tip = base + Vector((0, 0.45, 0.7 - k * 0.04))
            if mane == "flames":
                add_flame(M, "Skull", base, 0.25, 0.9)
            elif mane == "lightning":
                pts = [base, base + Vector((0.15, 0.2, 0.35)), base + Vector((-0.1, 0.35, 0.6)), base + Vector((0.1, 0.5, 0.95))]
                for a, b in zip(pts[:-1], pts[1:]):
                    v, f = cone(a, b, 0.09, 0.06, seg=6)
                    M.add("Skull", v, f, ("n", acc))
            elif mane == "red_crystals":
                v, f = cone(base, tip, 0.18, 0.0, seg=5)
                M.add("Skull", v, f, ("n", acc), outline=0.01)
            elif mane == "moss_crystal":
                v, f = ellipsoid(base + Vector((0, 0, -0.1)), (0.35, 0.3, 0.15), seg=10, rings=5)
                M.add("Skull", v, f, ("c", "5A8A2A"), outline=0.01)
                if k % 2 == 0:
                    v, f = cone(base, tip, 0.16, 0.0, seg=5)
                    M.add("Skull", v, f, ("n", acc), outline=0.01)
            else:
                v, f = cone(base, tip, 0.18, 0.0, seg=8)
                M.add("Skull", v, f, ("c", dark), outline=0.01)
    if g.get("whiskers"):
        for sd in (-1, 1):
            a = Vector((sd * 0.5, -1.6, -0.15))
            v, f = cone(a, a + Vector((sd * 0.8, 0.3, -0.9)), 0.04, 0.01, seg=6)
            M.add("Skull", v, f, ("c", "E8D8B0"))
    if g.get("lava"):
        for k in range(10):
            p = Vector((rnd.uniform(-0.7, 0.7), rnd.uniform(-1.4, 0.6), 0.55 + rnd.uniform(-0.1, 0.2)))
            v, f = ellipsoid(p, (0.22, 0.05, 0.03), Matrix.Rotation(rnd.uniform(0, 3), 3, "Z"), seg=8, rings=4)
            M.add("Skull", v, f, ("n", acc))
    if g.get("skulls"):
        pass


# ───────────────────────── Anneaux du corps ─────────────────────────

R_RING = 1.0


def ring_mesh(M, group, g, deco, alt=False):
    body = g.get("alt_body", g["body"]) if alt and g.get("alt_body") else g["body"]
    dark, belly, acc = g["dark"], g["belly"], g["accent"]
    hk = gk(g)
    v, f = ellipsoid((0, 0, 0), (R_RING, 0.95, 0.9), seg=22, rings=14)
    cols = []
    for face in f:
        ctr = sum((Vector(v[k]) for k in face), Vector((0, 0, 0))) / len(face)
        if ctr.z < -0.45:
            cols.append(("c", belly if int((ctr.y + 1) * 3.5) % 2 == 0 else shade(belly, 0.9)))
        elif deco == "stripes" and math.sin(ctr.y * 5 + ctr.x * 1.5) > 0.55:
            cols.append(("c", dark))
        elif deco in ("lava", "lava_spikes") and abs(math.sin(ctr.x * 6 + ctr.y * 4) + math.sin(ctr.y * 7 - ctr.z * 3)) < 0.25:
            cols.append(("n", acc))
        elif deco == "tribal" and abs(ctr.y) < 0.18:
            cols.append(("c", dark))
        elif deco == "runes" and False:
            cols.append(("n", acc))
        elif deco == "gold_scales" and ctr.z > 0.2 and (int(ctr.x * 6) + int(ctr.y * 6)) % 3 == 0:
            cols.append(("c", acc))
        elif deco == "armor":
            cols.append(("c", body if abs(ctr.y) < 0.6 else dark))
        elif ctr.z > 0.25 and (math.sin(ctr.x * 4.1 + ctr.y * 3.3) + math.sin(ctr.y * 5.2 - ctr.x * 2.0)) > 1.15:
            cols.append((hk, dark))
        elif ctr.z > 0.7:
            cols.append((hk, dark))
        else:
            cols.append((hk, body))
    M.add(group, v, f, cols, outline=0.045)
    top = Vector((0, 0, 0.88))
    rnd = random.Random(g["zone"] * 7 + (1 if alt else 0))
    if deco == "leaves":
        for k in range(3):
            v, f = flat_shape(top + Vector(((k - 1) * 0.3, (k - 1) * 0.25, -0.05)), leaf2d(0.8, 0.28), Vector((1, 0.2, 0)), Vector(((k - 1) * 0.4, 0.4, 1)), 0.04)
            M.add(group, v, f, ("c", "4CA03A" if k % 2 else "2E7A2A"), outline=0.012)
        v, f = torus((0, 0, 0), 1.02, 0.07, axis=(0.3, 1, 0.1), seg=24, tseg=6)
        M.add(group, v, f, ("c", "6A4A28"), outline=0.008)
    elif deco == "flowers":
        for k, col in enumerate(g.get("flowers", ["F070D0"])):
            ang = -0.9 + k * 0.9
            p = Vector((math.sin(ang) * 0.9, (k - 1) * 0.3, math.cos(ang) * 0.85))
            add_flower(M, group, p, 0.22, col, "F8E060", (math.sin(ang), 0, math.cos(ang)))
    elif deco == "tribal":
        for k in range(6):
            a = k / 6 * math.pi * 2
            v, f = box((math.cos(a) * 0.98, 0.45, math.sin(a) * 0.9 + 0.05), (0.12, 0.08, 0.3), Matrix.Rotation(a, 3, "Y"))
            M.add(group, v, f, ("c", acc))
    elif deco == "skulls":
        for sd in (-1, 1):
            p = Vector((sd * 0.75, 0.0, 0.45))
            v, f = ellipsoid(p, (0.24, 0.2, 0.22), seg=10, rings=6)
            M.add(group, v, f, ("c", "B8F060"), outline=0.008)
            for e in (-1, 1):
                v, f = ellipsoid(p + Vector((sd * 0.12, e * 0.08, 0.02)), (0.05, 0.05, 0.06), seg=6, rings=4)
                M.add(group, v, f, ("c", "1A2A0A"))
    elif deco == "ice":
        for k in range(4):
            base = Vector(((k % 2 - 0.5) * 0.4, (k - 1.5) * 0.35, 0.8))
            v, f = cone(base, base + Vector((0, 0.15, 0.75 + 0.15 * (k % 2))), 0.2, 0.0, seg=6)
            M.add(group, v, f, ("g", "D8F4FF" if k % 2 else "9AD8F0"), outline=0.01)
    elif deco == "vines":
        v, f = torus((0, 0, 0), 1.0, 0.08, axis=(0.4, 1, 0.2), seg=24, tseg=6)
        M.add(group, v, f, ("c", "3A8A3A"), outline=0.008)
        for k in range(3):
            v, f = flat_shape(Vector((0.6, (k - 1) * 0.3, 0.75)), leaf2d(0.45, 0.16), Vector((0, 1, 0)), Vector((0.5, 0, 1)), 0.03)
            M.add(group, v, f, ("c", "4CA03A"), outline=0.008)
    elif deco == "stripes":
        pass
    elif deco in ("moss_crystal", "moss"):
        v, f = ellipsoid(top + Vector((0, 0, -0.12)), (0.75, 0.8, 0.22), seg=12, rings=6)
        M.add(group, v, f, ("c", "5A8A2A"), outline=0.01)
        if deco == "moss_crystal":
            for k in range(3):
                base = top + Vector(((k - 1) * 0.3, (k % 2) * 0.2 - 0.1, 0.0))
                v, f = cone(base, base + Vector((0, 0.1, 0.65 - abs(k - 1) * 0.15)), 0.18, 0.0, seg=5)
                M.add(group, v, f, ("n", acc), outline=0.01)
    elif deco == "runes":
        for k in range(5):
            a = k / 5 * math.pi * 1.4 - 0.2
            p = Vector((math.cos(a) * 0.98, rnd.uniform(-0.35, 0.35), math.sin(a) * 0.9))
            nrm = Vector((math.cos(a), 0, math.sin(a)))
            # glyphe : barre + chevrons
            v, f = flat_shape(p, [(-0.03, -0.22), (0.03, -0.22), (0.03, 0.22), (-0.03, 0.22)], nrm, Vector((0, 1, 0)), 0.03)
            M.add(group, v, f, ("n", acc))
            for sgn in (-1, 1):
                v, f = flat_shape(p + Vector((0, 0.08 * sgn, 0)), [(0, -0.03), (0.15, 0.08), (0.15, 0.14), (0, 0.03)], nrm, Vector((0, sgn, 0)), 0.03)
                M.add(group, v, f, ("n", acc))
    elif deco == "dorsal_fin":
        v, f = flat_shape(top + Vector((0, -0.2, -0.05)), [(0, -0.6), (0.0, 0.6), (0.7, 0.2)], Vector((1, 0, 0)), Vector((0, 0, 1)), 0.05)
        vv = [tuple(Matrix.Rotation(math.pi / 2, 3, "X") @ (Vector(p) - top) + top) for p in v]
        M.add(group, vv, f, ("c", acc), outline=0.01)
    elif deco in ("spikes", "lava_spikes"):
        for k in range(2):
            base = top + Vector((0, (k - 0.5) * 0.6, -0.05))
            v, f = cone(base, base + Vector((0, 0.3, 0.7)), 0.22, 0.0, seg=8)
            M.add(group, v, f, ("c", "1A1214"), outline=0.01)
    elif deco == "red_crystals":
        for k in range(3):
            base = top + Vector(((k - 1) * 0.35, (k % 2) * 0.2, -0.05))
            v, f = cone(base, base + Vector(((k - 1) * 0.2, 0.1, 0.8)), 0.2, 0.0, seg=4)
            M.add(group, v, f, ("n", acc), outline=0.01)
    elif deco == "smoke":
        for k in range(4):
            p = Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.5, 0.5), rnd.uniform(0.5, 0.95)))
            v, f = ellipsoid(p, (0.35, 0.35, 0.3), seg=10, rings=6)
            M.add(group, v, f, ("c", shade(g["body"], 0.8)), outline=0.01)
    elif deco == "gold_band":
        v, f = torus((0, 0, 0), 1.0, 0.09, axis=(0, 1, 0), seg=24, tseg=6)
        M.add(group, v, f, ("c", acc), outline=0.008)
    elif deco == "armor":
        for sd in (-1, 1):
            v, f = torus((0, sd * 0.62, 0), 0.92, 0.08, axis=(0, 1, 0), seg=24, tseg=6)
            M.add(group, v, f, ("c", g["dark"]), outline=0.008)
        for k in range(6):
            a = k / 6 * math.pi * 2
            v, f = ellipsoid((math.cos(a) * 0.98, 0.0, math.sin(a) * 0.9), (0.07,) * 3, seg=6, rings=4)
            M.add(group, v, f, ("c", "B8BAC2"))
    elif deco == "gear":
        v, f = torus((1.0, 0, 0.1), 0.45, 0.12, axis=(1, 0, 0), seg=18, tseg=6)
        M.add(group, v, f, ("c", acc), outline=0.01)
        for k in range(8):
            a = k / 8 * math.pi * 2
            v, f = box((1.0, math.cos(a) * 0.6, math.sin(a) * 0.6 + 0.1), (0.16, 0.16, 0.16))
            M.add(group, v, f, ("c", acc))
    elif deco == "lightning":
        pts = [top + Vector((-0.4, -0.3, 0.0)), top + Vector((0.2, -0.1, 0.35)), top + Vector((-0.1, 0.1, 0.55)), top + Vector((0.35, 0.3, 0.9))]
        for a, b in zip(pts[:-1], pts[1:]):
            v, f = cone(a, b, 0.1, 0.07, seg=6)
            M.add(group, v, f, ("n", acc))
    elif deco == "flames":
        add_flame(M, group, top + Vector((0, 0, -0.1)), 0.3, 1.0)
    if deco in ("lava", "lava_spikes", "flames"):
        add_flame(M, group, top + Vector((0.3, 0.1, -0.1)), 0.18, 0.55)


def tail_mesh(M, group, g):
    deco = g.get("tail", "plain")
    dark, body = g["dark"], g["body"]
    pts = [Vector((0, 0, 0))]
    for k in range(1, 7):
        u = k / 6
        pts.append(Vector((math.sin(u * 2.4) * 0.5, u * 3.6, math.sin(u * math.pi) * 0.5)))
    path = catmull(pts, 26)
    radii = [0.95 * (1 - i / 25) ** 1.1 + 0.05 for i in range(26)]
    v, f, info, _ = tube(path, radii, lambda t, p: Vector((0, 0, -1)), seg=16)
    cols = []
    for (i, j, ang) in info:
        if ang < 0.9:
            cols.append(("c", g["belly"]))
        elif deco == "stripes" and (i // 2) % 2 == 0:
            cols.append(("c", dark))
        elif g.get("lava") and h32(i, j) % 7 == 0:
            cols.append(("n", g["accent"]))
        else:
            cols.append((gk(g), body))
    M.add(group, v, f, cols, outline=0.04)
    tip = path[-1]
    d = (path[-1] - path[-3]).normalized()
    if deco == "leaf":
        for k in range(3):
            v, f = flat_shape(tip, leaf2d(1.0, 0.35), Vector((math.cos(k * 2.1), 0, math.sin(k * 2.1))), d + Vector((0, 0, 0.3 * (k - 1))), 0.04)
            M.add(group, v, f, ("c", "4CA03A"), outline=0.012)
    elif deco == "tuft":
        for k in range(8):
            v, f = cone(tip, tip + d * 0.9 + Vector(((k % 3 - 1) * 0.3, 0, (k // 3 - 1) * 0.3)), 0.18, 0.02, seg=8)
            M.add(group, v, f, ("c", g.get("mane_col", "E8C070")), outline=0.01)
    elif deco in ("crystal", "crystal_gold", "crystal_red"):
        col = {"crystal": ("g", "D8F4FF"), "crystal_gold": ("n", g["accent"]), "crystal_red": ("n", g["accent"])}[deco]
        for k in range(4):
            v, f = cone(tip - d * 0.2, tip + d * (0.9 - 0.15 * k) + Vector(((k - 1.5) * 0.25, 0, 0.3 * (k % 2))), 0.2, 0.0, seg=5)
            M.add(group, v, f, col, outline=0.01)
    elif deco == "fin":
        v, f = flat_shape(tip, [(0, 0), (-0.9, 0.9), (0, 0.5), (0.9, 0.9)], Vector((0, 0, 1)), d, 0.05)
        M.add(group, v, f, ("c", g["accent"]), outline=0.012)
    elif deco == "flame":
        add_flame(M, group, tip, 0.4, 1.4)
    elif deco == "feather":
        for k in range(5):
            ang = (k - 2) * 0.35
            dd = (d + Vector((math.sin(ang), 0, math.cos(ang) * 0.3))).normalized()
            v, f = flat_shape(tip, leaf2d(1.3, 0.25), Vector((0, 0, 1)), dd, 0.04)
            M.add(group, v, f, ("c", "F8F4EC" if k % 2 else g["accent"]), outline=0.01)
    elif deco == "mech":
        v, f = cone(tip - d * 0.2, tip + d * 0.8, 0.3, 0.0, seg=6)
        M.add(group, v, f, ("c", g["accent"]), outline=0.01)
    elif deco == "lightning":
        pts2 = [tip, tip + d * 0.4 + Vector((0.3, 0, 0.2)), tip + d * 0.7 + Vector((-0.2, 0, 0.4)), tip + d * 1.1 + Vector((0.2, 0, 0.6))]
        for a, b in zip(pts2[:-1], pts2[1:]):
            v, f = cone(a, b, 0.12, 0.08, seg=6)
            M.add(group, v, f, ("n", g["accent"]))
    elif deco == "smoke":
        for k in range(4):
            v, f = ellipsoid(tip + d * (0.3 * k), (0.4 - k * 0.07,) * 3, seg=10, rings=6)
            M.add(group, v, f, ("c", shade(body, 0.8)), outline=0.01)


def wing_mesh(M, group, g, sd):
    for k in range(13):
        ang = math.radians(15 + k * 8)
        d = Vector((sd * math.cos(ang), 0.25, math.sin(ang))).normalized()
        L = 4.2 - abs(k - 7) * 0.22
        v, f = flat_shape(Vector((0, 0.02 * k, 0)), leaf2d(L, 0.55), Vector((0, -1, 0.05)), d, 0.08)
        M.add(group, v, f, ("c", "F8F6F0" if k % 3 else g["accent"]), outline=0.02)


def hood_mesh(M, group, g, sd):
    pts = []
    for k in range(13):
        a = math.pi * (-0.5 + k / 12)
        pts.append((sd * (math.cos(a) * 1.6), math.sin(a) * 1.9))
    pts.append((0, -1.9))
    v, f = flat_shape(Vector((0, 0, 0)), pts if sd > 0 else list(reversed(pts)), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.12)
    M.add(group, v, f, ("c", g.get("hood_col", g["body"])), outline=0.03)
    for k in range(2):
        p = Vector((sd * (0.7 + 0.4 * k), -0.08, 0.5 - 0.9 * k))
        v, f = ellipsoid(p, (0.32, 0.06, 0.3), seg=12, rings=6)
        M.add(group, v, f, ("c", "B8F060"), outline=0.01)
        for e in (-1, 1):
            v, f = ellipsoid(p + Vector((e * 0.1, -0.05, 0.05)), (0.07, 0.03, 0.08), seg=6, rings=4)
            M.add(group, v, f, ("c", "1A2A0A"))


def fin_mesh(M, group, g, sd):
    v, f = flat_shape(Vector((0, 0, 0)), [(0, 0), (sd * 1.6, 0.6), (sd * 1.4, -0.3), (sd * 1.8, -0.9), (sd * 0.3, -0.6)] if sd > 0 else list(reversed([(0, 0), (sd * 1.6, 0.6), (sd * 1.4, -0.3), (sd * 1.8, -0.9), (sd * 0.3, -0.6)])), Vector((0, 0, 1)), Vector((0, 1, 0)), 0.06)
    M.add(group, v, f, ("c", g["accent"]), outline=0.015)


def build_guardian_kit(g):
    n = g["zone"]
    M = Model("GuardianKit_%d" % n)
    if g.get("aura"):
        M.ink = ("n", g["accent"])
        M.inkw = 1.6
    ring_mesh(M, "K%d_Body" % n, g, g.get("ring_deco"), False)
    ring_mesh(M, "K%d_BodyAlt" % n, g, g.get("alt_deco"), True)
    tail_mesh(M, "K%d_Tail" % n, g)
    if g.get("wings"):
        wing_mesh(M, "K%d_WingR" % n, g, 1)
        wing_mesh(M, "K%d_WingL" % n, g, -1)
    if g.get("hood"):
        hood_mesh(M, "K%d_HoodR" % n, g, 1)
        hood_mesh(M, "K%d_HoodL" % n, g, -1)
    if g.get("fins"):
        fin_mesh(M, "K%d_FinR" % n, g, 1)
        fin_mesh(M, "K%d_FinL" % n, g, -1)
    return M


def realize_kit(M, location=(0, 0, 0)):
    """Comme realize() mais chaque groupe est décalé pour ne pas se superposer (Studio recalcule les pivots)."""
    root = realize(M, location)
    off = 0
    for ch in root.children:
        ch.location = (0, off, 0)
        off += 5.0
    return root


def build_all_guardians(out_heads=None, out_kits=None):
    clear_scene()
    heads, kits = [], []
    for k, g in enumerate(GUARDIANS):
        heads.append(realize(build_guardian_head(g), ((k % 5) * 6.0, (k // 5) * 7.0, 0)))
        kits.append(realize_kit(build_guardian_kit(g), ((k % 5) * 6.0 + 40, (k // 5) * 30.0, 0)))
    if out_heads:
        export_roots(heads, out_heads)
    if out_kits:
        export_roots(kits, out_kits)
    return heads, kits


def compose_preview(g, location=(0, 0, 0)):
    """Assemble tête + anneaux + queue le long d'un S (aperçu Blender uniquement, comme le rendu en jeu)."""
    import bpy
    from mathutils import Quaternion
    loc = Vector(location)
    pts = [Vector((0, -0.5, 7.2)), Vector((0.2, 0.4, 5.4)), Vector((-0.4, 0.8, 3.6)), Vector((0.4, 0.2, 1.6)), Vector((2.6, 1.6, 1.1)),
           Vector((4.8, 0.6, 1.0)), Vector((4.6, -1.6, 1.0)), Vector((2.4, -2.4, 1.0)), Vector((0.6, -1.4, 1.0))]
    path = catmull(pts, 15)
    head = realize(build_guardian_head(g))
    head.location = loc + path[0] + Vector((0, -1.2, 1.3))
    ringM = build_guardian_kit(g)
    created = [head]
    for i in range(1, 14):
        t = i / 13
        s = 1.05 - 0.55 * t
        sub = Model("prev_%d_%d" % (g["zone"], i))
        key = "K%d_BodyAlt" % g["zone"] if i % 3 == 0 else "K%d_Body" % g["zone"]
        sub.groups = {"Ring": ringM.groups[key]}
        ob = realize(sub)
        tan = (path[min(14, i + 1)] - path[i - 1]).normalized()
        q = (-tan).to_track_quat("Y", "Z")
        ob.matrix_world = Matrix.Translation(loc + path[i]) @ q.to_matrix().to_4x4() @ Matrix.Scale(s * 1.25, 4)
        created.append(ob)
    for side in ("WingL", "WingR", "HoodL", "HoodR", "FinL", "FinR"):
        key = "K%d_%s" % (g["zone"], side)
        if key in ringM.groups:
            sub = Model("prevw_%d_%s" % (g["zone"], side))
            sub.groups = {"W": ringM.groups[key]}
            ob = realize(sub)
            sd = 1 if side.endswith("R") else -1
            anchor = path[2] if side.startswith("Wing") else path[1]
            ob.matrix_world = Matrix.Translation(loc + anchor + Vector((sd * 0.9, 0.3, 0.6))) @ Matrix.Scale(1.2, 4)
            created.append(ob)
    sub = Model("prevt_%d" % g["zone"])
    sub.groups = {"T": ringM.groups["K%d_Tail" % g["zone"]]}
    ob = realize(sub)
    tan = (path[-1] - path[-2]).normalized()
    ob.matrix_world = Matrix.Translation(loc + path[-1]) @ (-tan).to_track_quat("-Y", "Z").to_matrix().to_4x4() @ Matrix.Scale(0.6, 4)
    created.append(ob)
    root = bpy.data.objects.new("preview_%d" % g["zone"], None)
    bpy.context.scene.collection.objects.link(root)
    for o in created:
        mw = o.matrix_world.copy()
        o.parent = root
        o.matrix_world = mw
    return root
