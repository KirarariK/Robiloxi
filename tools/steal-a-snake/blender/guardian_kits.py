"""
Steal A Snake — kits 3D complets des 15 gardiens (Blender, style voxel).

Chaque gardien = un Empty « GuardianKit_<n> » contenant des pièces animées côté Roblox :
    K<n>_Body      anneau du corps (motif + ornements dorsaux propres au gardien)
    K<n>_BodyAlt   anneau alterné (bande d'accent) → motif régulier le long du corps
    K<n>_Tail      bout de queue (sonnette, flamme, cristal, nageoire, étoile…)
    K<n>_WingL/R   ailes (Ciel, Temple)             — battement
    K<n>_HoodL/R   capuchon de cobra (Désert)       — se déploie en chasse
    K<n>_FinL/R    nageoires latérales (Récif)      — ondulation
La tête (avec mâchoire « lower jaw ») reste GuardianHead_<n> (voxel_snakes.build_guardian_head).

Repère : Z = haut, l'avant (la tête) est vers -Y. Les ailes / capuchons / nageoires droits
s'étendent vers +X depuis leur charnière (x = 0), les gauches vers -X.

Usage :
    exec(open(r"<repo>/tools/steal-a-snake/blender/guardian_kits.py", encoding="utf-8").read())
    build_all_kits(json.load(open(r"<repo>/tools/steal-a-snake/blender/guardians.json")))
"""
import json
import math
import os

import bpy

_here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\devaa\Desktop\robiloxiiiii\tools\steal-a-snake\blender"
exec(open(os.path.join(_here, "voxel_snakes.py"), encoding="utf-8").read())

R = 7.0  # rayon d'un anneau (voxels)
L = 5.0  # demi-longueur d'un anneau

ICE = (220, 245, 255)
LAVA = (255, 120, 30)
LAVA2 = (255, 220, 80)
LEAF = (60, 160, 60)
LEAF2 = (120, 200, 70)
FUR = (200, 40, 40)
BONE2 = (215, 205, 185)


def _ring(g, body, belly, accent, f, alt, glow):
    """Anneau ellipsoïdal centré à l'origine, allongé selon Y."""
    akind = "n" if glow else "c"
    bkind = "g" if f == "Ghost" else "c"
    rng = int(R) + 1
    for x in range(-rng, rng + 1):
        for y in range(-int(L) - 1, int(L) + 2):
            for z in range(-rng, rng + 1):
                dx, dy, dz = x / R, y / (L + 0.6), z / (R * 0.88)
                if dx * dx + dy * dy * 0.55 + dz * dz > 1:
                    continue
                top = z / (R * 0.88)
                col, kind = body, bkind
                if top < -0.5:
                    col = belly
                    if f == "Ghost":
                        kind = "g"
                elif alt and abs(y) <= 2:
                    col, kind = accent, akind
                elif f in ("Hood", "Rattle") and top > 0.25 and (abs(x) + abs(y)) % 6 in (0, 1):
                    col = accent  # losanges
                elif f == "Crest" and top > 0.2 and (x + y) % 4 == 0:
                    col = mix(body, (0, 0, 0), 0.25)  # écailles sombres
                elif f == "Fire" and top > 0.0 and hsh(x, y, z) % 5 == 0:
                    col, kind = (LAVA if hsh(z, x) % 2 else LAVA2), "n"
                elif f == "Toxic" and top > 0.3 and hsh(x // 2, y // 2) % 6 == 0:
                    col, kind = accent, "n"
                elif f == "Radioactive" and abs(y) == 4:
                    col, kind = accent, "n"
                elif f == "Rainbow" and top > 0.2 and hsh(x, y, z) % 11 == 0:
                    col, kind = (255, 245, 180), "n"
                elif f == "Mane" and top > 0.35 and y % 3 == 0:
                    col = mix(body, (255, 255, 255), 0.2)
                g.set(x, y, z, col, kind)
    ztop = int(R * 0.88)
    # ornements dorsaux
    if f == "Crest":
        for y in range(-3, 4):
            h = 4 - abs(y)
            for z in range(h):
                g.set(0, y, ztop + 1 + z, accent if z < h - 1 else LEAF2)
    elif f == "Hood":
        pass
    elif f == "Toxic":
        for (px, py) in ((-3, -2), (2, 1), (0, 3)):
            g.box(px, px + 1, py, py + 1, ztop - 1, ztop, accent, "n")
    elif f == "Frost":
        for y in (-3, 0, 3):
            for z in range(4 + (y == 0) * 2):
                g.set(0, y, ztop + 1 + z, ICE, "g")
                if z < 2:
                    g.set(1, y, ztop + 1 + z, ICE, "g")
    elif f == "Mane":
        for y in range(-4, 5, 2):
            for z in range(3):
                g.set(0, y, ztop + 1 + z, FUR)
                g.set(-1 if z % 2 else 1, y + 1, ztop + 1 + z, FUR)
    elif f == "Rattle":
        for y in (-3, 3):
            g.box(-1, 1, y, y, ztop + 1, ztop + 1, accent)
    elif f == "Spores":
        cap = accent
        for (px, py) in ((0, 0), (-4, 3), (4, -3)):
            g.set(px, py, ztop + 1, BONE)
            g.set(px, py, ztop + 2, BONE)
            for x in range(px - 2, px + 3):
                for y in range(py - 2, py + 3):
                    if abs(x - px) + abs(y - py) <= 3:
                        g.set(x, y, ztop + 3, WHITE if hsh(x, y) % 4 == 0 else cap, "n" if glow and hsh(x, y) % 4 else "c")
    elif f == "Fins":
        for y in range(-4, 5):
            h = 4 - abs(y) // 2
            for z in range(h):
                g.set(0, y, ztop + 1 + z, accent, akind)
    elif f == "Fire":
        for y in (-3, 1, 4):
            for z in range(5):
                g.set(0, y - z * 0.3, ztop + 1 + z, LAVA if z < 3 else LAVA2, "n")
    elif f == "Crystal":
        for (px, py, h) in ((0, 0, 6), (-2, -2, 4), (2, 2, 4)):
            for z in range(h):
                g.set(px, py, ztop + 1 + z, accent if z % 2 else ICE, "g")
                g.set(px + 1, py, ztop + 1 + z, accent, "g")
    elif f == "Ghost":
        for x in range(-int(R) - 1, int(R) + 2):  # côte d'os
            z = int(math.sqrt(max(0, (R + 1) ** 2 - x * x)) * 0.88)
            if z > 0:
                g.set(x, 0, z, BONE2)
    elif f == "Feathers":
        plume = [accent, belly, (60, 120, 230), (255, 210, 60)]
        for k, y in enumerate((-4, -1, 2)):
            g.line((0, y, ztop), (0, y + 3, ztop + 6), plume[k % 4])
            g.line((1, y, ztop), (2, y + 3, ztop + 5), plume[(k + 1) % 4])
    elif f == "Radioactive":
        g.box(-1, 1, -1, 1, ztop + 1, ztop + 2, accent, "n")
    elif f == "Wings":
        for y in (-2, 2):
            g.set(0, y, ztop + 1, GOLD, "n")
    elif f == "Rainbow":
        for k in range(3):
            g.set(hsh(k, 5) % 5 - 2, hsh(k, 6) % 7 - 3, ztop + 2 + k, (255, 240, 140), "n")


def _tail(g, body, belly, accent, f, glow):
    """Bout de queue : cône vers +Y (vers l'arrière), avant à y = 0."""
    akind = "n" if glow else "c"
    for y in range(0, 16):
        r = (R - 0.5) * (1 - y / 17) ** 1.2
        for x in range(-int(R), int(R) + 1):
            for z in range(-int(R), int(R) + 1):
                if x * x + (z / 0.88) ** 2 <= r * r:
                    g.set(x, y, z, belly if z < -r * 0.5 else body, "g" if f == "Ghost" else "c")
    tip = 16
    if f == "Rattle":
        for k in range(5):
            w = 3 - k // 2
            g.box(-w, w, tip + k * 2, tip + k * 2 + 1, -w, w, (225, 200, 150) if k % 2 == 0 else (190, 160, 110))
    elif f == "Fire":
        for k in range(8):
            for z in range(-2, 3 + k // 2):
                g.set((hsh(k) % 5) - 2, tip + k, z, LAVA if k < 4 else LAVA2, "n")
    elif f in ("Crystal", "Frost"):
        for k in range(8):
            w = max(0, 2 - k // 3)
            g.box(-w, w, tip + k, tip + k, -w, w, ICE if f == "Frost" else accent, "g")
    elif f == "Fins":
        for k in range(7):
            g.line((0, tip - 2 + k * 0.5, 0), (0, tip + 5, -6 + k * 2), accent, akind)
    elif f == "Rainbow":
        for k in range(5):
            a = k / 5 * math.pi * 2
            g.line((0, tip + 2, 0), (math.cos(a) * 4, tip + 3, math.sin(a) * 4), (255, 240, 140), "n")
        g.set(0, tip + 2, 0, (255, 255, 255), "n")
    elif f == "Spores":
        g.box(-2, 2, tip, tip + 2, -2, 2, accent, "n" if glow else "c")
    elif f == "Mane":
        for k in range(6):
            g.line((0, tip - 2, 0), (math.cos(k) * 4, tip + 4, math.sin(k) * 4), FUR)
    elif f == "Feathers":
        for k in range(5):
            g.line((0, tip - 1, 0), ((k - 2) * 2, tip + 7, 2 - abs(k - 2)), [accent, (60, 120, 230), (255, 210, 60)][k % 3])
    elif f == "Toxic" or f == "Radioactive":
        g.box(-1, 1, tip, tip + 2, -1, 1, accent, "n")
    elif f == "Wings":
        g.box(-1, 1, tip, tip + 1, -1, 1, GOLD, "n")


def _wing(g, accent, body, feathered):
    """Aile droite : charnière en x = 0, s'étend vers +X ; plumes en éventail."""
    for k in range(13):
        span = 2 + k
        h0 = int(-1 + k * 0.25)
        h1 = int(5 + k * 0.9 - (k / 13) ** 2 * 6)
        for z in range(h0, max(h0 + 1, h1)):
            col = accent if (k % 4 == 0 or z == h1 - 1) else body
            for y in range(-2, 2 + (k < 6)):
                g.set(span, y, z, col, "n" if (col == accent and not feathered) else "c")
    if feathered:  # pointes de rémiges
        for k in range(4):
            g.line((8 + k * 2, 0, 1), (11 + k * 2, 0, -4 - k), accent)


def _hood(g, body, accent):
    """Demi-capuchon droit : plaque arrondie (marque en lunettes)."""
    for x in range(0, 11):
        for z in range(-9, 8):
            dx, dz = x / 10.5, (z + 0.5) / 8.5
            if dx * dx + dz * dz <= 1:
                mark = (x - 5) ** 2 + (z - 2) ** 2 <= 6
                for y in (0, 1):
                    g.set(x, y, z, accent if mark else body)


def _fin(g, accent, glow):
    for k in range(9):
        for z in range(-1, 6 - k // 2):
            g.set(k, z * 0.3, z - k * 0.4, accent, "n" if glow else "c")


def _piece(name, parent, grid):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    grid_to_objects(grid, name, e)
    return e


def build_guardian_kit(look, order, location=(0, 0, 0)):
    body = hexrgb(look["body"])
    accent = hexrgb(look["accent"])
    belly = hexrgb(look["belly"])
    glow = look.get("neon", False)
    f = look["feature"]
    root = bpy.data.objects.new("GuardianKit_%d" % order, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = location
    p = "K%d_" % order

    g = Grid()
    _ring(g, body, belly, accent, f, False, glow)
    _piece(p + "Body", root, g).location = (0, 0, 0)
    g = Grid()
    _ring(g, body, belly, accent, f, True, glow)
    _piece(p + "BodyAlt", root, g).location = (0, 5, 0)
    g = Grid()
    _tail(g, body, belly, accent, f, glow)
    _piece(p + "Tail", root, g).location = (0, 10, 0)

    if f in ("Wings", "Feathers"):
        for side, sx in (("R", 1), ("L", -1)):
            g = Grid()
            wg = Grid()
            _wing(wg, GOLD if f == "Wings" else accent, WHITE if f == "Wings" else body, f == "Feathers")
            for (x, y, z), v in wg.v.items():
                g.v[(x * sx, y, z)] = v
            _piece(p + "Wing" + side, root, g).location = (sx * 4, -4, 4)
    if f == "Hood":
        for side, sx in (("R", 1), ("L", -1)):
            g = Grid()
            hg = Grid()
            _hood(hg, body, accent)
            for (x, y, z), v in hg.v.items():
                g.v[(x * sx, y, z)] = v
            _piece(p + "Hood" + side, root, g).location = (sx * 3, -8, 0)
    if f == "Fins":
        for side, sx in (("R", 1), ("L", -1)):
            g = Grid()
            fg = Grid()
            _fin(fg, accent, glow)
            for (x, y, z), v in fg.v.items():
                g.v[(x * sx, y, z)] = v
            _piece(p + "Fin" + side, root, g).location = (sx * 3, -12, 0)
    return root


def build_all_kits(looks, out_path=None):
    clear_scene()
    roots = []
    for look in looks:
        n = look["order"]
        roots.append(build_guardian_kit(look, n, location=(((n - 1) % 5) * 12, ((n - 1) // 5) * 14, 0)))
    if out_path:
        export_roots(roots, out_path)
    return roots
