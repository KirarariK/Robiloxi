"""
Steal A Snake — générateur Blender des 98 serpents « cartoon » de l'encyclopédie (catalog.py).

Style : formes lisses, gros yeux brillants, ventre clair à écailles, contour noir (coque inversée, rendue
par le backface culling des MeshParts Roblox), accessoires détaillés (couronnes, chapeaux, ailes, flammes…).

Pièces animables (chacune = un Empty « <Id>__<Pièce> » contenant un repère « Hinge » = pivot) :
  Body  : corps enroulé + cou (fixe)          Head : tête + yeux + accessoires (regarde le joueur, hoche)
  Tail  : bout de queue (frétille)            WingL / WingR : ailes (battent)
  Prop  : hélice de casquette (tourne)        Tongue : objet couleur E62846 (sort par à-coups)
Chaque objet maillage est nommé <c|n|g>_RRGGBB (opaque / néon / verre) → recoloré à l'import Roblox.
Repère : Z = haut, la tête regarde -Y.

Usage dans Blender :
    exec(open(r"<repo>/tools/steal-a-snake/blender/cartoon_snakes.py", encoding="utf-8").read())
    build_one(CATALOG[0])                 # un serpent
    build_all(out_fbx=r"...\\snakes.fbx")  # tous + export
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\devaa\Desktop\robiloxiiiii\tools\steal-a-snake\blender"
_ns = {}
exec(open(os.path.join(_HERE, "catalog.py"), encoding="utf-8").read(), _ns)
CATALOG = _ns["CATALOG"]

INK = "1A1020"
WHITE = "FAFAFA"
BLACK = "141018"
TONGUE = "E62846"
GOLD = "F0C040"
GOLD_D = "B8862E"


def hx(h):
    h = h.strip().lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def tohex(c):
    return "%02X%02X%02X" % tuple(max(0, min(255, int(round(v)))) for v in c)


def mix(a, b, t):
    a, b = hx(a), hx(b)
    return tohex(tuple(a[i] + (b[i] - a[i]) * t for i in range(3)))


def shade(a, k):
    c = hx(a)
    return tohex(tuple(v * k for v in c))


def h32(*a):
    h = 2166136261
    for v in a:
        h = ((h ^ (int(v) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return h


# ───────────────────────── Accumulateur de maillages ─────────────────────────

class Model:
    """Faces colorées regroupées par pièce animable ; contours noirs en coque inversée."""

    def __init__(self, ident):
        self.id = ident
        self.groups = {}  # group -> {(kind, hex): [verts, faces]}
        self.hinges = {}  # group -> Vector
        self.ink = ("c", INK)  # couleur du contour (néon pour les serpents à aura)
        self.inkw = 1.0

    def add(self, group, verts, faces, colors, outline=0.0):
        """colors : (kind, hex) commun, ou liste par face."""
        g = self.groups.setdefault(group, {})
        if isinstance(colors, tuple):
            colors = [colors] * len(faces)
        for f, col in zip(faces, colors):
            bucket = g.setdefault(col, [[], [], {}])
            vs, fs, remap = bucket
            nf = []
            for vi in f:
                k = remap.get(vi)
                if k is None:
                    k = len(vs)
                    vs.append(verts[vi])
                    remap[vi] = k
                nf.append(k)
            fs.append(nf)
        # le remap est propre à cet appel
        for col in set(colors):
            g[col][2] = {}
        if outline > 0:
            self.outline(group, verts, faces, outline * self.inkw)

    def outline(self, group, verts, faces, w):
        normals = [Vector((0, 0, 0)) for _ in verts]
        for f in faces:
            a, b, c = Vector(verts[f[0]]), Vector(verts[f[1]]), Vector(verts[f[2]])
            n = (b - a).cross(c - a)
            for vi in f:
                normals[vi] += n
        nv = []
        for v, n in zip(verts, normals):
            if n.length > 1e-9:
                n.normalize()
            nv.append(tuple(Vector(v) + n * w))
        nf = [list(reversed(f)) for f in faces]
        g = self.groups.setdefault(group, {})
        bucket = g.setdefault(self.ink, [[], [], {}])
        base = len(bucket[0])
        bucket[0].extend(nv)
        bucket[1].extend([[base + i for i in f] for f in nf])

    def hinge(self, group, pos):
        self.hinges[group] = Vector(pos)


# ───────────────────────── Primitives ─────────────────────────

def ellipsoid(c, r, rot=None, seg=18, rings=10):
    verts, faces = [], []
    rot = rot or Matrix.Identity(3)
    verts.append(tuple(Vector(c) + rot @ Vector((0, 0, -r[2]))))
    for i in range(1, rings):
        th = math.pi * i / rings - math.pi / 2
        for j in range(seg):
            ph = 2 * math.pi * j / seg
            p = Vector((math.cos(th) * math.cos(ph) * r[0], math.cos(th) * math.sin(ph) * r[1], math.sin(th) * r[2]))
            verts.append(tuple(Vector(c) + rot @ p))
    verts.append(tuple(Vector(c) + rot @ Vector((0, 0, r[2]))))
    top = len(verts) - 1
    for j in range(seg):
        faces.append([0, 1 + (j + 1) % seg, 1 + j])
    for i in range(rings - 2):
        for j in range(seg):
            a = 1 + i * seg + j
            b = 1 + i * seg + (j + 1) % seg
            faces.append([a, b, b + seg, a + seg])
    base = 1 + (rings - 2) * seg
    for j in range(seg):
        faces.append([base + j, base + (j + 1) % seg, top])
    return verts, faces


def frame_from(direction):
    d = Vector(direction).normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
    x = up.cross(d).normalized()
    y = d.cross(x).normalized()
    return Matrix((x, y, d)).transposed()  # colonnes x, y, d


def cone(base, tip, r0, r1=0.0, seg=12):
    base, tip = Vector(base), Vector(tip)
    m = frame_from(tip - base)
    verts, faces = [], []
    for k, (p, r) in enumerate(((base, r0), (tip, r1))):
        for j in range(seg):
            a = 2 * math.pi * j / seg
            verts.append(tuple(p + m @ Vector((math.cos(a) * r, math.sin(a) * r, 0))))
    for j in range(seg):
        a, b = j, (j + 1) % seg
        faces.append([a, b, seg + b, seg + a])
    cb = len(verts)
    verts.append(tuple(base))
    ct = len(verts)
    verts.append(tuple(tip))
    for j in range(seg):
        faces.append([cb, (j + 1) % seg, j])
        faces.append([ct, seg + j, seg + (j + 1) % seg])
    return verts, faces


def box(c, s, rot=None):
    rot = rot or Matrix.Identity(3)
    verts = []
    for x in (-1, 1):
        for y in (-1, 1):
            for z in (-1, 1):
                verts.append(tuple(Vector(c) + rot @ Vector((x * s[0] / 2, y * s[1] / 2, z * s[2] / 2))))
    faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return verts, faces


def torus(c, R, r, axis=(0, 0, 1), seg=20, tseg=8, arc=2 * math.pi):
    m = frame_from(axis)
    verts, faces = [], []
    n = seg if arc >= 2 * math.pi - 1e-6 else seg + 1
    for i in range(n):
        u = arc * i / seg
        for j in range(tseg):
            v = 2 * math.pi * j / tseg
            p = Vector(((R + r * math.cos(v)) * math.cos(u), (R + r * math.cos(v)) * math.sin(u), r * math.sin(v)))
            verts.append(tuple(Vector(c) + m @ p))
    for i in range(seg):
        i2 = (i + 1) % n if n == seg else i + 1
        for j in range(tseg):
            j2 = (j + 1) % tseg
            faces.append([i2 * tseg + j, i2 * tseg + j2, i * tseg + j2, i * tseg + j])
    return verts, faces


def flat_shape(c, outline2d, normal, up, thick=0.02):
    """Forme plate extrudée (feuille, plume, pétale…) : contour 2D (u, v) dans le plan (droite, haut)."""
    n = Vector(normal).normalized()
    u = Vector(up).normalized()
    rgt = u.cross(n).normalized()
    u = n.cross(rgt).normalized()
    verts = []
    k = len(outline2d)
    for side in (-1, 1):
        for (a, b) in outline2d:
            verts.append(tuple(Vector(c) + rgt * a + u * b + n * side * thick / 2))
    faces = [list(range(k - 1, -1, -1)), list(range(k, 2 * k))]
    for i in range(k):
        j = (i + 1) % k
        faces.append([i, j, k + j, k + i])
    # triangule les grandes faces (éventail) pour Roblox
    tri = []
    for f in faces:
        if len(f) > 4:
            for i in range(1, len(f) - 1):
                tri.append([f[0], f[i], f[i + 1]])
        else:
            tri.append(f)
    return verts, tri


def leaf2d(length, width, n=10):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((math.sin(math.pi * t) * width * (1 - 0.3 * t), t * length))
    for i in range(n - 1, 0, -1):
        t = i / n
        pts.append((-math.sin(math.pi * t) * width * (1 - 0.3 * t), t * length))
    return pts


def star2d(r_out, r_in, points=4):
    pts = []
    for i in range(points * 2):
        a = math.pi * i / points + math.pi / 2
        r = r_out if i % 2 == 0 else r_in
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


# ───────────────────────── Spline & tube ─────────────────────────

def catmull(pts, samples):
    P = [Vector(p) for p in pts]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    dense = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(20):
            t = k / 20
            dense.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    dense.append(P[-2])
    acc = [0.0]
    for i in range(1, len(dense)):
        acc.append(acc[-1] + (dense[i] - dense[i - 1]).length)
    total = acc[-1]
    out = []
    j = 0
    for s in range(samples):
        target = total * s / (samples - 1)
        while j < len(acc) - 2 and acc[j + 1] < target:
            j += 1
        seg = acc[j + 1] - acc[j]
        f = 0 if seg < 1e-9 else (target - acc[j]) / seg
        out.append(dense[j].lerp(dense[j + 1], f))
    return out


def tube(path, radii, belly_fn, seg=14, cap_start=True, cap_end=True):
    """Tube le long de path ; renvoie verts, faces, info par face (i anneau, j autour, angle depuis le ventre)."""
    n = len(path)
    tangents = []
    for i in range(n):
        a = path[max(0, i - 1)]
        b = path[min(n - 1, i + 1)]
        tangents.append((b - a).normalized())
    verts, faces, info = [], [], []
    frames = []
    for i in range(n):
        t = tangents[i]
        bd = Vector(belly_fn(i / (n - 1), path[i]))
        nrm = (bd - t * bd.dot(t))
        if nrm.length < 1e-4:
            nrm = Vector((0, 0, -1)) - t * t.z
        nrm.normalize()
        side = t.cross(nrm).normalized()
        frames.append((nrm, side))
        for j in range(seg):
            a = 2 * math.pi * j / seg
            d = nrm * math.cos(a) + side * math.sin(a)
            verts.append(tuple(path[i] + d * radii[i]))
    for i in range(n - 1):
        for j in range(seg):
            j2 = (j + 1) % seg
            faces.append([i * seg + j, i * seg + j2, (i + 1) * seg + j2, (i + 1) * seg + j])
            ang = (2 * math.pi * (j + 0.5) / seg)
            ang = min(ang, 2 * math.pi - ang)
            info.append((i, j, ang))
    if cap_start:
        c = len(verts)
        verts.append(tuple(path[0] - tangents[0] * radii[0] * 0.6))
        for j in range(seg):
            faces.append([c, (j + 1) % seg, j])
            info.append((0, j, math.pi))
    if cap_end:
        c = len(verts)
        verts.append(tuple(path[-1] + tangents[-1] * radii[-1] * 0.6))
        base = (n - 1) * seg
        for j in range(seg):
            faces.append([c, base + j, base + (j + 1) % seg])
            info.append((n - 1, j, math.pi))
    return verts, faces, info, frames


# ───────────────────────── Silhouette commune ─────────────────────────

CTRL = [
    (0.00, -0.05, 2.30),
    (-0.20, 0.00, 1.90),
    (-0.15, 0.05, 1.45),
    (0.15, 0.00, 1.05),
    (0.35, -0.10, 0.65),
    (0.15, -0.28, 0.38),
    (-0.28, -0.05, 0.36),
    (-0.05, 0.38, 0.36),
    (0.55, 0.42, 0.36),
    (1.08, 0.12, 0.36),
    (1.18, -0.30, 0.40),
    (1.48, -0.15, 0.72),
    (1.78, 0.00, 1.07),
    (1.88, 0.05, 1.42),
    (1.70, 0.00, 1.66),
]
N_SAMPLES = 80
SEG = 16
TAIL_SPLIT = 0.80


def radius_at(t):
    return 1.22 * _radius_at(t)


def _radius_at(t):
    if t < 0.06:
        return 0.26 + 0.6 * t
    if t < 0.40:
        return 0.30 + 0.2 * (t - 0.06)
    if t < 0.58:
        return 0.37
    return max(0.05, 0.37 * (1 - (t - 0.58) / 0.44) ** 0.85)


def belly_dir(t, p):
    k = max(0.0, min(1.0, (p.z - 0.45) / 0.55))
    return Vector((0, -k * 1.0, -(1 - k))).normalized() if k < 1 else Vector((0, -1, -0.15)).normalized()


_FR = None


def body_frames():
    """Chemin, rayons et repères (dessus / côté) du corps commun — pour poser les accessoires en surface."""
    global _FR
    if _FR is None:
        path = path_points()
        n = len(path)
        radii = [radius_at(i / (n - 1)) for i in range(n)]
        ups, sides = [], []
        for i in range(n):
            t = (path[min(n - 1, i + 1)] - path[max(0, i - 1)]).normalized()
            bd = belly_dir(i / (n - 1), path[i])
            nrm = (bd - t * bd.dot(t)).normalized()
            ups.append(-nrm)
            sides.append(t.cross(nrm).normalized())
        _FR = (path, radii, ups, sides)
    return _FR


def surf(i, ang=0.0, extra=0.0):
    path, radii, ups, sides = body_frames()
    i = max(0, min(len(path) - 1, int(i)))
    d = ups[i] * math.cos(ang) + sides[i] * math.sin(ang)
    return path[i] + d * (radii[i] + extra), d


def grp_of(i):
    return "Tail" if i >= int(N_SAMPLES * TAIL_SPLIT) else "Body"


def keep_faces(verts, faces, fn):
    out = []
    for f in faces:
        c = sum((Vector(verts[k]) for k in f), Vector((0, 0, 0))) / len(f)
        if fn(c):
            out.append(f)
    return out


# ───────────────────────── Motifs de peau ─────────────────────────

_spots = {}


def spot_centers(s, seg):
    key = (s["id"], seg)
    if key not in _spots:
        rnd = random.Random(h32(len(s["id"]), ord(s["id"][1]), 77))
        out = []
        for k in range(46):
            out.append((rnd.uniform(0, N_SAMPLES), rnd.uniform(0, seg), rnd.uniform(1.0, 1.9), k))
        _spots[key] = out
    return _spots[key]


def body_kind(s):
    m = s.get("mat", "smooth")
    return "n" if m == "neon" else ("g" if m == "glass" and s.get("head") == "blob" and s.get("pattern") == "solid" else "c")


def skin_color(s, t, i, j, ang, p, seg):
    """Couleur (kind, hex) d'une face du corps."""
    kind = body_kind(s)
    body, belly, acc = s["body"], s["belly"], s["accent"]
    pal = s.get("pal", [acc])
    pat = s.get("pattern", "solid")
    narrow = pat in ("rainbow", "patch", "candy", "galaxy", "robot", "flame", "water", "ice", "slime", "gold")
    is_belly = ang < math.radians(26 if narrow else 44)
    if is_belly and pat not in ("pixel",):
        if s.get("belly_rainbow"):
            rb = ["F08080", "F8C080", "F8F090", "A0E0A0", "A0C8F0", "C8A8F0"]
            return (kind if kind != "n" else "c", rb[int(t * 18) % 6])
        col = belly if i % 3 else shade(belly, 0.93)
        if pat == "lava":
            th0 = 2 * math.pi * j / seg
            nzb = math.sin(i * 0.37 + th0 * 2.0) + math.sin(i * 0.13 - th0 * 3.0) * 0.8
            if abs(nzb) < 0.2:
                return ("n", pal[0])
            return ("c", shade(body, 1.3))
        if pat in ("galaxy",):
            return (kind, belly)
        return ("c" if kind == "n" and pat != "flame" else kind, col)
    top = ang > math.radians(130)
    hsh = h32(i, j, len(body))
    th = 2 * math.pi * j / seg
    nz = math.sin(i * 0.37 + th * 2.0 + len(body)) + math.sin(i * 0.13 - th * 3.0) * 0.8 + math.sin(i * 0.71 + th) * 0.5
    if pat == "solid":
        return (kind, body)
    if pat == "bands":
        band = (i // 3) % (len(pal) + 1)
        return (kind, body if band == 0 else pal[(band - 1) % len(pal)])
    if pat == "stripes":
        return (kind, pal[0] if top else body)
    if pat == "spots":
        for (si, sj, sr, sc) in spot_centers(s, seg):
            dj = min(abs(j - sj), seg - abs(j - sj))
            if ((i - si) / 1.6) ** 2 + dj ** 2 <= sr * sr:
                return (kind, pal[sc % len(pal)])
        return (kind, body)
    if pat == "speckle":
        if hsh % 7 == 0:
            return (kind, pal[hsh % len(pal)])
        return (kind, body)
    if pat == "rainbow":
        return (kind, pal[int(t * 16) % len(pal)])
    if pat == "patch":
        cell = h32(i // 4, j // 3, 3)
        return (kind, pal[cell % len(pal)] if cell % 3 else body)
    if pat == "galaxy":
        if hsh % 23 == 0:
            return ("n", "FFFFFF")
        if nz > 1.1:
            return (kind, pal[0])
        if nz < -1.6:
            return (kind, pal[1 % len(pal)])
        return (kind, body)
    if pat == "lava":
        if abs(nz) < 0.16 or abs(nz - 1.2) < 0.1:
            return ("n", pal[0] if nz < 0.6 else pal[1 % len(pal)])
        return (kind, body)
    if pat == "flame":
        if nz > 1.0:
            return ("n", pal[0])
        if nz < -1.2:
            return (kind, pal[1 % len(pal)])
        return (kind, body)
    if pat == "scales":
        if ang > math.radians(80) and (i + j) % 3 == 0:
            return (kind, pal[0])
        return (kind, body)
    if pat == "candy":
        k = ((i + j * 2) // 3) % 4
        return (kind, body if k in (0, 2) else (pal[0] if k == 1 else pal[1 % len(pal)]))
    if pat == "ice":
        if nz > 1.0:
            return (kind, pal[0])
        if nz < -1.3:
            return (kind, pal[1 % len(pal)])
        return (kind, body)
    if pat == "water":
        if abs(nz - 0.6) < 0.18:
            return (kind, pal[0])
        if nz < -1.2:
            return (kind, pal[1 % len(pal)])
        return (kind, body)
    if pat == "stone":
        if nz > 1.0:
            return (kind, pal[0])
        if nz < -1.2:
            return (kind, pal[1 % len(pal)])
        return (kind, body if hsh % 9 else pal[0])
    if pat == "slime":
        return (kind, pal[0] if hsh % 6 == 0 else body)
    if pat == "bandage":
        return (kind, body if (i + (j // 4)) % 4 else pal[0])
    if pat == "robot":
        if i % 5 == 0:
            return ("n", pal[1])
        return (kind, pal[0] if i % 5 == 4 else body)
    if pat == "gold":
        return ("c", pal[0] if hsh % 4 == 0 else body)
    return (kind, body)


# ───────────────────────── Yeux, bouche, langue ─────────────────────────

def add_eye(M, group, c, out, r, s, side):
    style = s.get("eye_style", "cute")
    if style == "none":
        return
    iris = s.get("eye", "2A2A3A")
    c, out = Vector(c), Vector(out).normalized()
    if s.get("big_eyes"):
        r *= 1.35
    v, f = ellipsoid(c, (r, r, r * 1.05), seg=14, rings=8)
    M.add(group, v, f, ("c", WHITE), outline=0.012)
    if style == "glow":
        v, f = ellipsoid(c + out * r * 0.55, (r * 0.62, r * 0.62, r * 0.66), seg=12, rings=6)
        M.add(group, v, f, ("n", iris))
        return
    ir = r * 0.68
    v, f = ellipsoid(c + out * r * 0.5, (ir, ir, ir * 1.05), seg=12, rings=6)
    M.add(group, v, f, ("c", iris))
    if style == "cat":
        rot = frame_from(out)
        v, f = ellipsoid(c + out * r * 0.86, (ir * 0.18, ir * 0.18, ir * 0.85), seg=8, rings=5)
        M.add(group, v, f, ("c", BLACK))
    else:
        v, f = ellipsoid(c + out * r * 0.78, (ir * 0.55, ir * 0.55, ir * 0.58), seg=10, rings=6)
        M.add(group, v, f, ("c", BLACK))
    hl = c + out * r * 0.95 + Vector((side * 0.0, 0, 0)) + Vector((0, 0, r * 0.35)) + out.cross(Vector((0, 0, 1))).normalized() * r * 0.25 * side
    v, f = ellipsoid(hl, (r * 0.18, r * 0.18, r * 0.18), seg=8, rings=5)
    M.add(group, v, f, ("c", "FFFFFF"))
    if style == "sleepy":
        v, f = ellipsoid(c + Vector((0, 0, r * 0.25)), (r * 1.08, r * 1.08, r * 0.62), seg=14, rings=6)
        M.add(group, v, f, ("c", s.get("head_col", s["body"])), outline=0.01)
    if style == "angry":
        brow_c = c + Vector((0, 0, r * 1.05)) + out * r * 0.2
        rot = Matrix.Rotation(-side * 0.45, 3, "Y")
        v, f = box(brow_c, (r * 1.9, r * 0.5, r * 0.32), rot)
        M.add(group, v, f, ("c", shade(s.get("head_col", s["body"]), 0.45)))


def add_tongue(M, group, mouth, fwd):
    mouth, fwd = Vector(mouth), Vector(fwd).normalized()
    tip = mouth + fwd * 0.28 + Vector((0, 0, -0.08))
    v, f = cone(mouth, tip, 0.035, 0.03, seg=6)
    M.add(group, v, f, ("c", TONGUE))
    side = fwd.cross(Vector((0, 0, 1))).normalized()
    for sd in (-1, 1):
        v, f = cone(tip, tip + fwd * 0.1 + side * sd * 0.06 + Vector((0, 0, -0.03)), 0.028, 0.008, seg=6)
        M.add(group, v, f, ("c", TONGUE))


def add_smile(M, group, center, fwd, width, col=BLACK):
    center, fwd = Vector(center), Vector(fwd).normalized()
    side = fwd.cross(Vector((0, 0, 1))).normalized()
    pts = []
    for k in range(9):
        u = (k / 8) * 2 - 1
        pts.append(center + side * u * width + Vector((0, 0, 0.05 * (u * u))))
    for a, b in zip(pts[:-1], pts[1:]):
        v, f = cone(a, b, 0.016, 0.016, seg=5)
        M.add(group, v, f, ("c", col))


# ───────────────────────── Têtes ─────────────────────────

HEAD_SCALE = 1.62


def head_frame(neck_top):
    c = Vector(neck_top) + Vector((0.0, -0.26, 0.44))
    return c


def build_head(M, s, c, group="Head", scale=1.0, primary=True):
    """Construit une tête complète centrée en c (regard -Y). Renvoie des points d'ancrage."""
    kind = s.get("head", "cute")
    col = s.get("skin", s.get("head_col", s["body"])) if not s.get("mummy") else s["body"]
    hk = "n" if s.get("mat") == "neon" else ("g" if s.get("mat") == "glass" else "c")
    c = Vector(c)
    S = scale
    fwd = Vector((0, -1, 0))
    anchors = {"top": c + Vector((0, 0.05, 0.34 * S)), "back": c + Vector((0, 0.32 * S, 0.12 * S)), "c": c}
    if kind in ("cute", "blob", "clown", "toad"):
        rr = {"cute": (0.44, 0.48, 0.37), "blob": (0.5, 0.5, 0.45), "clown": (0.46, 0.46, 0.42), "toad": (0.52, 0.46, 0.32)}[kind]
        v, f = ellipsoid(c, tuple(x * S for x in rr), seg=20, rings=12)
        M.add(group, v, f, (hk, col if kind != "clown" else "F8F4EA"), outline=0.022 * S)
        sn = c + Vector((0, -0.30 * S, -0.08 * S))
        v, f = ellipsoid(sn, (0.33 * S, 0.30 * S, 0.24 * S), seg=18, rings=10)
        M.add(group, v, f, (hk, col if kind != "clown" else "F8F4EA"), outline=0.02 * S)
        if kind == "toad":
            for k in range(7):
                a = k / 7 * math.pi * 2
                p = c + Vector((math.cos(a) * 0.32 * S, math.sin(a) * 0.3 * S + 0.05, 0.25 * S))
                v, f = ellipsoid(p, (0.07 * S,) * 3, seg=8, rings=5)
                M.add(group, v, f, (hk, shade(col, 0.82)))
        ey = c + Vector((0, -0.30 * S, 0.12 * S))
        if s.get("mummy"):
            v, f = ellipsoid(ey + Vector((0, -0.02, 0)), (0.42 * S, 0.22 * S, 0.12 * S), seg=18, rings=8)
            M.add(group, v, f, ("c", s.get("skin", "3A4A3A")))
        for sd in (-1, 1):
            add_eye(M, group, ey + Vector((sd * 0.24 * S, 0, 0)), Vector((sd * 0.45, -1, 0.15)), 0.13 * S, s, sd)
        mouth = sn + Vector((0, -0.25 * S, -0.08 * S))
        if kind == "clown":
            v, f = ellipsoid(sn + Vector((0, -0.28 * S, 0.04 * S)), (0.11 * S,) * 3, seg=12, rings=8)
            M.add(group, v, f, ("c", "E03030"), outline=0.01)
            add_smile(M, group, mouth + Vector((0, -0.02, -0.02)), fwd, 0.18 * S, "D02020")
            for sd in (-1, 1):
                for k in range(3):
                    p = c + Vector((sd * (0.42 + 0.05 * k) * S, 0.12 * S - 0.1 * k * S, (0.15 - 0.12 * k) * S))
                    v, f = ellipsoid(p, (0.13 * S,) * 3, seg=10, rings=7)
                    M.add(group, v, f, ("c", "F07A20"), outline=0.01)
            for k in range(10):
                a = k / 10 * math.pi * 2
                p = c + Vector((math.cos(a) * 0.36 * S, math.sin(a) * 0.36 * S + 0.12 * S, -0.42 * S))
                colr = ["E04030", "F0B030", "40A060", "3A8AC0"][k % 4]
                v, f = ellipsoid(p, (0.13 * S, 0.13 * S, 0.09 * S), seg=10, rings=6)
                M.add(group, v, f, ("c", colr), outline=0.008)
        else:
            add_smile(M, group, mouth, fwd, 0.16 * S)
            for sd in (-1, 1):
                v, f = ellipsoid(sn + Vector((sd * 0.08 * S, -0.27 * S, 0.08 * S)), (0.025 * S,) * 3, seg=6, rings=4)
                M.add(group, v, f, ("c", BLACK))
        anchors["mouth"] = mouth
        anchors["top"] = c + Vector((0, 0.04 * S, rr[2] * S))
    elif kind in ("viper", "dragon", "beak"):
        v, f = ellipsoid(c, (0.44 * S, 0.50 * S, 0.33 * S), seg=20, rings=12)
        M.add(group, v, f, (hk, col), outline=0.022 * S)
        snl = 0.40 if kind == "dragon" else 0.34
        sn = c + Vector((0, -snl * S, -0.07 * S))
        v, f = ellipsoid(sn, (0.27 * S, 0.34 * S, 0.20 * S), seg=18, rings=10)
        M.add(group, v, f, (hk, col), outline=0.02 * S)
        # mâchoire claire
        v, f = ellipsoid(sn + Vector((0, 0.05 * S, -0.10 * S)), (0.24 * S, 0.32 * S, 0.10 * S), seg=14, rings=7)
        M.add(group, v, f, (hk, s["belly"]))
        ey = c + Vector((0, -0.22 * S, 0.14 * S))
        for sd in (-1, 1):
            add_eye(M, group, ey + Vector((sd * 0.25 * S, 0, 0)), Vector((sd * 0.6, -1, 0.15)), 0.12 * S, s, sd)
            v, f = ellipsoid(sn + Vector((sd * 0.08 * S, -0.30 * S, 0.08 * S)), (0.025 * S,) * 3, seg=6, rings=4)
            M.add(group, v, f, ("c", BLACK))
        mouth = sn + Vector((0, -0.30 * S, -0.06 * S))
        add_smile(M, group, mouth + Vector((0, 0.08 * S, 0)), fwd, 0.18 * S)
        if s.get("fangs"):
            for sd in (-1, 1):
                v, f = cone(mouth + Vector((sd * 0.09 * S, 0.06 * S, -0.02)), mouth + Vector((sd * 0.09 * S, 0.04 * S, -0.2 * S)), 0.05 * S, 0.0, seg=8)
                M.add(group, v, f, ("c", "F2EEE2"), outline=0.008)
        if kind == "beak":
            v, f = cone(sn + Vector((0, -0.15 * S, 0.02)), sn + Vector((0, -0.52 * S, -0.12 * S)), 0.15 * S, 0.01, seg=12)
            M.add(group, v, f, ("c", "F0B030"), outline=0.012)
        if kind == "dragon":
            for sd in (-1, 1):
                # moustaches / barbillons
                a = sn + Vector((sd * 0.18 * S, -0.22 * S, 0.0))
                v, f = cone(a, a + Vector((sd * 0.35 * S, 0.1 * S, -0.22 * S)), 0.025 * S, 0.008, seg=6)
                M.add(group, v, f, ("c", s["accent"]))
                # crêtes de joue
                v, f = cone(c + Vector((sd * 0.38 * S, 0.15 * S, -0.05 * S)), c + Vector((sd * 0.62 * S, 0.38 * S, 0.02 * S)), 0.08 * S, 0.0, seg=8)
                M.add(group, v, f, ("c", s["accent"]), outline=0.008)
        anchors["mouth"] = mouth
        anchors["top"] = c + Vector((0, 0.06 * S, 0.32 * S))
    elif kind == "skull":
        bone = s["body"]
        v, f = ellipsoid(c + Vector((0, 0.05, 0.03)), (0.46 * S, 0.46 * S, 0.40 * S), seg=20, rings=12)
        M.add(group, v, f, ("c", bone), outline=0.022 * S)
        v, f = ellipsoid(c + Vector((0, -0.28 * S, -0.12 * S)), (0.30 * S, 0.24 * S, 0.20 * S), seg=16, rings=8)
        M.add(group, v, f, ("c", bone), outline=0.015 * S)
        for sd in (-1, 1):
            e = c + Vector((sd * 0.19 * S, -0.34 * S, 0.06 * S))
            v, f = ellipsoid(e, (0.13 * S, 0.08 * S, 0.14 * S), seg=12, rings=7)
            M.add(group, v, f, ("c", "2A2420"))
            v, f = ellipsoid(e + Vector((0, -0.05 * S, 0)), (0.075 * S, 0.06 * S, 0.08 * S), seg=10, rings=6)
            M.add(group, v, f, ("n", s.get("eye", "40E060")))
        v, f = ellipsoid(c + Vector((0, -0.48 * S, -0.05 * S)), (0.05 * S, 0.03 * S, 0.06 * S), seg=8, rings=5)
        M.add(group, v, f, ("c", "2A2420"))
        for k in range(-3, 4):
            v, f = box(c + Vector((k * 0.065 * S, -0.48 * S, -0.22 * S)), (0.05 * S, 0.04 * S, 0.08 * S))
            M.add(group, v, f, ("c", "F8F4E8"))
        anchors["mouth"] = None
    elif kind == "pumpkin":
        orange = "E87A1E"
        for k in range(8):
            a = k / 8 * math.pi * 2
            p = c + Vector((math.cos(a) * 0.17 * S, math.sin(a) * 0.17 * S, 0))
            v, f = ellipsoid(p, (0.34 * S, 0.34 * S, 0.40 * S), Matrix.Rotation(a, 3, "Z"), seg=16, rings=10)
            M.add(group, v, f, ("c", orange if k % 2 else "D86A14"), outline=0.016 * S)
        v, f = cone(c + Vector((0, 0, 0.36 * S)), c + Vector((0.05, 0.03, 0.62 * S)), 0.06 * S, 0.04 * S, seg=8)
        M.add(group, v, f, ("c", "4A7A2A"), outline=0.01)
        face_c = c + Vector((0, -0.49 * S, 0))
        for sd in (-1, 1):
            tri = [(sd * 0.10, 0.20), (sd * 0.24, 0.02), (sd * 0.0, 0.04)]
            v, f = flat_shape(face_c + Vector((sd * 0.14 * S, 0, 0.0)), [(x * S, y * S) for x, y in [(0, 0.1), (0.1, -0.06), (-0.1, -0.06)]], (0, -1, 0), (0, 0, 1), 0.03)
            M.add(group, v, f, ("n", "F8C030"))
        mouth = [(-0.26, 0.0), (-0.15, -0.05), (-0.08, 0.02), (0.0, -0.06), (0.08, 0.02), (0.15, -0.05), (0.26, 0.0), (0.12, -0.16), (-0.12, -0.16)]
        v, f = flat_shape(face_c + Vector((0, 0, -0.14 * S)), [(x * S, y * S) for x, y in mouth], (0, -1, 0), (0, 0, 1), 0.03)
        M.add(group, v, f, ("n", "F8C030"))
        anchors["mouth"] = None
    elif kind == "robot":
        metal = s["body"]
        rot = Matrix.Identity(3)
        v, f = ellipsoid(c, (0.46 * S, 0.44 * S, 0.40 * S), seg=20, rings=10)
        M.add(group, v, f, ("c", metal), outline=0.02 * S)
        v, f = ellipsoid(c + Vector((0, -0.24 * S, 0.0)), (0.36 * S, 0.24 * S, 0.27 * S), seg=18, rings=8)
        M.add(group, v, f, ("c", "1E2430"), outline=0.01)
        for sd in (-1, 1):
            v, f = ellipsoid(c + Vector((sd * 0.14 * S, -0.46 * S, 0.03 * S)), (0.07 * S, 0.04 * S, 0.08 * S), seg=10, rings=6)
            M.add(group, v, f, ("n", s.get("eye", "40E0F0")))
            v, f = ellipsoid(c + Vector((sd * 0.45 * S, 0, 0)), (0.06 * S, 0.1 * S, 0.1 * S), seg=10, rings=6)
            M.add(group, v, f, ("c", s["accent"]))
        v, f = cone(c + Vector((0.1, 0.05, 0.36 * S)), c + Vector((0.16, 0.08, 0.62 * S)), 0.02 * S, 0.02 * S, seg=6)
        M.add(group, v, f, ("c", "6A7480"))
        v, f = ellipsoid(c + Vector((0.16, 0.08, 0.66 * S)), (0.05 * S,) * 3, seg=8, rings=6)
        M.add(group, v, f, ("n", "F04040"))
        anchors["mouth"] = None
    elif kind == "pixel":
        g = s["body"]
        for (x, y, z, w) in [(0, 0, 0, 0.5), (0, -0.3, -0.05, 0.4), (0, 0.18, 0.08, 0.42)]:
            v, f = box(c + Vector((x, y * S, z * S)), (0.62 * S, w * S + 0.2, 0.5 * S))
            M.add(group, v, f, ("c", g), outline=0.018)
        for sd in (-1, 1):
            v, f = box(c + Vector((sd * 0.16 * S, -0.46 * S, 0.1 * S)), (0.12 * S, 0.04 * S, 0.12 * S))
            M.add(group, v, f, ("c", BLACK))
        v, f = box(c + Vector((0, -0.62 * S, -0.18 * S)), (0.05 * S, 0.24 * S, 0.04 * S))
        M.add(group, v, f, ("c", "D84030"))
        anchors["mouth"] = None
    elif kind == "octopus":
        anchors["mouth"] = None
    if primary and anchors.get("mouth") is not None and kind not in ("skull", "robot", "pumpkin", "pixel", "octopus") and not s.get("mummy"):
        add_tongue(M, "Head", anchors["mouth"], fwd)
    return anchors


# ───────────────────────── Accessoires de tête ─────────────────────────

def add_crown(M, top, S, col, gem=None):
    top = Vector(top)
    v, f = torus(top + Vector((0, 0, 0.05 * S)), 0.2 * S, 0.05 * S, seg=18, tseg=6)
    M.add("Head", v, f, ("c", col), outline=0.01)
    for k in range(5):
        a = k / 5 * math.pi * 2 - math.pi / 2
        b = top + Vector((math.cos(a) * 0.2 * S, math.sin(a) * 0.2 * S, 0.06 * S))
        v, f = cone(b, b + Vector((0, 0, 0.2 * S)), 0.07 * S, 0.0, seg=8)
        M.add("Head", v, f, ("c", col), outline=0.008)
        v, f = ellipsoid(b + Vector((0, 0, 0.22 * S)), (0.035 * S,) * 3, seg=8, rings=5)
        M.add("Head", v, f, ("c", col))
    if gem:
        v, f = ellipsoid(top + Vector((0, -0.24 * S, 0.12 * S)), (0.07 * S, 0.04 * S, 0.08 * S), seg=10, rings=6)
        M.add("Head", v, f, ("n", gem))


def add_hat(M, s, a, S):
    hat = s.get("hat")
    if not hat:
        return
    cols = s.get("hat_col", [GOLD])
    top = Vector(a["top"])
    if hat in ("crown", "crown_gem"):
        add_crown(M, top, S, cols[0], cols[1] if hat == "crown_gem" and len(cols) > 1 else ("E04040" if hat == "crown_gem" else None))
    elif hat == "party":
        stripes = cols
        base = top + Vector((0.04, 0.05, 0.0))
        for k in range(4):
            z0 = base + Vector((0, 0, k * 0.13 * S))
            z1 = base + Vector((0, 0, (k + 1) * 0.13 * S))
            v, f = cone(z0, z1, 0.26 * S * (1 - k / 4), 0.26 * S * (1 - (k + 1) / 4), seg=14)
            M.add("Head", v, f, ("c", stripes[k % len(stripes)]), outline=0.01)
        v, f = ellipsoid(base + Vector((0, 0, 0.55 * S)), (0.07 * S,) * 3, seg=10, rings=6)
        M.add("Head", v, f, ("c", stripes[-1]), outline=0.006)
    elif hat == "wizard":
        base = top + Vector((0, 0.04, -0.02))
        v, f = cone(base, base + Vector((0, 0, 0.02)), 0.46 * S, 0.44 * S, seg=20)
        M.add("Head", v, f, ("c", cols[0]), outline=0.012)
        pts = [base, base + Vector((0, 0.02, 0.28 * S)), base + Vector((0.03, 0.08, 0.5 * S)), base + Vector((0.1, 0.22, 0.62 * S))]
        rads = [0.26 * S, 0.18 * S, 0.1 * S, 0.02 * S]
        for k in range(3):
            v, f = cone(pts[k], pts[k + 1], rads[k], rads[k + 1], seg=14)
            M.add("Head", v, f, ("c", cols[0]), outline=0.01)
        v, f = torus(base + Vector((0, 0, 0.06 * S)), 0.25 * S, 0.035 * S, seg=18, tseg=6)
        M.add("Head", v, f, ("c", cols[1]))
        for k in range(3):
            p = base + Vector((math.cos(k * 2.1) * 0.2 * S, -0.12 * S - 0.05 * k, (0.18 + 0.12 * k) * S))
            v, f = flat_shape(p, star2d(0.06 * S, 0.025 * S, 5), (0, -1, 0.2), (0, 0, 1), 0.02)
            M.add("Head", v, f, ("n", cols[1]))
    elif hat in ("bowler", "fedora"):
        base = top + Vector((0, 0.03, -0.03))
        v, f = cone(base, base + Vector((0, 0, 0.03)), 0.42 * S, 0.40 * S, seg=20)
        M.add("Head", v, f, ("c", cols[0]), outline=0.012)
        v, f = ellipsoid(base + Vector((0, 0, 0.12 * S)), (0.26 * S, 0.26 * S, 0.2 * S), seg=18, rings=8)
        M.add("Head", v, f, ("c", cols[0]), outline=0.012)
        v, f = torus(base + Vector((0, 0, 0.07 * S)), 0.25 * S, 0.035 * S, seg=18, tseg=6)
        M.add("Head", v, f, ("c", cols[1] if len(cols) > 1 else BLACK))
        if hat == "bowler" and s["id"] == "Dapper_Snake":
            fl = base + Vector((0.2 * S, -0.12 * S, 0.12 * S))
            for k in range(5):
                a = k / 5 * math.pi * 2
                v, f = ellipsoid(fl + Vector((math.cos(a) * 0.05, 0, math.sin(a) * 0.05)), (0.045,) * 3, seg=8, rings=5)
                M.add("Head", v, f, ("c", cols[1]))
    elif hat in ("safari", "explorer"):
        base = top + Vector((0, 0.02, -0.05))
        v, f = cone(base, base + Vector((0, 0, 0.03)), 0.5 * S, 0.48 * S, seg=22)
        M.add("Head", v, f, ("c", cols[0]), outline=0.012)
        v, f = ellipsoid(base + Vector((0, 0, 0.06 * S)), (0.32 * S, 0.32 * S, 0.24 * S), seg=18, rings=8)
        M.add("Head", v, f, ("c", cols[0]), outline=0.012)
        v, f = torus(base + Vector((0, 0, 0.08 * S)), 0.31 * S, 0.035 * S, seg=18, tseg=6)
        M.add("Head", v, f, ("c", cols[1] if len(cols) > 1 else shade(cols[0], 0.6)))
    elif hat == "propeller":
        base = top + Vector((0, 0.03, -0.05))
        for k in range(4):
            a0 = k / 4 * math.pi * 2
            v, f = ellipsoid(base + Vector((math.cos(a0 + 0.78) * 0.08, math.sin(a0 + 0.78) * 0.08, 0.04)), (0.24 * S, 0.24 * S, 0.18 * S), seg=14, rings=7)
            M.add("Head", v, f, ("c", cols[k % len(cols)]), outline=0.01)
        v, f = ellipsoid(base + Vector((0, -0.24 * S, -0.02)), (0.22 * S, 0.14 * S, 0.03 * S), seg=12, rings=5)
        M.add("Head", v, f, ("c", cols[2 % len(cols)]), outline=0.008)
        pc = base + Vector((0, 0, 0.26 * S))
        v, f = cone(base + Vector((0, 0, 0.16 * S)), pc, 0.015 * S, 0.015 * S, seg=6)
        M.add("Head", v, f, ("c", "D0D0D0"))
        for sd in (-1, 1):
            v, f = ellipsoid(pc + Vector((sd * 0.16 * S, 0, 0)), (0.16 * S, 0.05 * S, 0.012 * S), seg=10, rings=5)
            M.add("Prop", v, f, ("c", cols[1] if sd > 0 else cols[0]), outline=0.006)
        M.hinge("Prop", pc)
    elif hat == "knight":
        v, f = ellipsoid(top + Vector((0, 0.02, -0.18 * S)), (0.48 * S, 0.52 * S, 0.40 * S), seg=20, rings=10)
        M.add("Head", v, f, ("c", cols[0]), outline=0.016)
        for k in range(3):
            v, f = box(top + Vector((0, -0.48 * S, (-0.18 + k * 0.08) * S)), (0.38 * S, 0.06 * S, 0.025 * S))
            M.add("Head", v, f, ("c", "1E1E24"))
        v, f = box(top + Vector((0, 0.05, 0.18 * S)), (0.05 * S, 0.7 * S, 0.12 * S))
        M.add("Head", v, f, ("c", cols[1]), outline=0.008)
    elif hat == "nemes":
        a0, a1 = cols[0], cols[1]
        c = Vector(a["c"])
        R = (0.50 * S, 0.53 * S, 0.45 * S)
        v, f = ellipsoid(c + Vector((0, 0.04 * S, 0.03 * S)), R, seg=26, rings=16)

        def outside_face(p):
            rel = p - c
            return not (rel.y < -0.10 * S and -0.42 * S < rel.z < 0.27 * S)

        f = keep_faces(v, f, outside_face)
        cols_f = []
        for face in f:
            ctr = sum((Vector(v[k]) for k in face), Vector((0, 0, 0))) / len(face)
            band = int((ctr.z - c.z + 0.6 * S) / (0.085 * S))
            cols_f.append(("c", a0 if band % 2 == 0 else a1))
        M.add("Head", v, f, cols_f, outline=0.014)
        for sd in (-1, 1):
            for k in range(7):
                p = c + Vector((sd * 0.38 * S, -0.10 * S, (-0.30 - k * 0.09) * S))
                v, f = box(p, (0.17 * S, 0.12 * S, 0.09 * S))
                M.add("Head", v, f, ("c", a0 if k % 2 == 0 else a1), outline=0.006)
        v, f = box(c + Vector((0, -0.44 * S, 0.27 * S)), (0.56 * S, 0.08 * S, 0.07 * S))
        M.add("Head", v, f, ("c", GOLD), outline=0.006)
        v, f = cone(c + Vector((0, -0.48 * S, 0.28 * S)), c + Vector((0, -0.52 * S, 0.46 * S)), 0.06 * S, 0.015, seg=8)
        M.add("Head", v, f, ("c", GOLD), outline=0.006)
        v, f = ellipsoid(c + Vector((0, -0.53 * S, 0.47 * S)), (0.035 * S,) * 3, seg=8, rings=5)
        M.add("Head", v, f, ("c", "D04030"))
        if s.get("beard"):
            for k in range(4):
                v, f = cone(c + Vector((0, -0.52 * S, (-0.30 - k * 0.09) * S)), c + Vector((0, -0.53 * S, (-0.39 - k * 0.09) * S)), (0.075 - k * 0.008) * S, (0.07 - k * 0.008) * S, seg=10)
                M.add("Head", v, f, ("c", a1 if k % 2 == 0 else a0), outline=0.006)
    elif hat == "flowers":
        for k in range(5):
            ang = -math.pi / 2 + (k - 2) * 0.5
            p = Vector(a["top"]) + Vector((math.cos(ang) * 0.24 * S, math.sin(ang) * 0.18 * S + 0.08, 0.02))
            add_flower(M, "Head", p, 0.1 * S, cols[k % len(cols)], "F8E060")
    elif hat == "mosaic":
        base = top + Vector((0, 0.03, -0.06))
        for k in range(8):
            a0 = k / 8 * math.pi * 2
            v, f = ellipsoid(base + Vector((math.cos(a0) * 0.1, math.sin(a0) * 0.1, 0.03)), (0.22 * S, 0.22 * S, 0.16 * S), seg=12, rings=6)
            M.add("Head", v, f, ("c", cols[k % len(cols)]), outline=0.008)


def add_flower(M, group, p, r, petal, center, normal=(0, 0, 1)):
    p = Vector(p)
    m = frame_from(normal)
    for k in range(5):
        a = k / 5 * math.pi * 2
        v, f = ellipsoid(p + m @ Vector((math.cos(a) * r * 0.7, math.sin(a) * r * 0.7, 0)), (r * 0.55, r * 0.55, r * 0.3), m, seg=10, rings=5)
        M.add(group, v, f, ("c", petal), outline=0.006)
    v, f = ellipsoid(p + m @ Vector((0, 0, r * 0.15)), (r * 0.35,) * 3, seg=8, rings=5)
    M.add(group, v, f, ("c", center))


def add_horns(M, s, a, S):
    h = s.get("horns")
    if not h:
        return
    top = Vector(a["top"])
    col = s["accent"] if h != "unicorn" else "F8E8A0"
    for sd in (-1, 1):
        if h == "nub":
            v, f = cone(top + Vector((sd * 0.16 * S, 0.06, -0.04)), top + Vector((sd * 0.2 * S, 0.14 * S, 0.16 * S)), 0.07 * S, 0.01, seg=8)
            M.add("Head", v, f, ("c", mix(col, "FFFFFF", 0.3)), outline=0.008)
        elif h == "dragon":
            pts = [top + Vector((sd * 0.16 * S, 0.05, -0.05)), top + Vector((sd * 0.24 * S, 0.24 * S, 0.12 * S)), top + Vector((sd * 0.28 * S, 0.5 * S, 0.2 * S)), top + Vector((sd * 0.26 * S, 0.68 * S, 0.34 * S))]
            rads = [0.08 * S, 0.06 * S, 0.035 * S, 0.0]
            for k in range(3):
                v, f = cone(pts[k], pts[k + 1], rads[k], rads[k + 1], seg=8)
                M.add("Head", v, f, ("c", mix(col, "F0E0C0", 0.4)), outline=0.008)
        elif h == "long":
            v, f = cone(top + Vector((sd * 0.18 * S, 0.1, -0.05)), top + Vector((sd * 0.34 * S, 0.5 * S, 0.3 * S)), 0.08 * S, 0.0, seg=8)
            M.add("Head", v, f, ("c", mix(col, "C8A070", 0.5)), outline=0.008)
        elif h == "flame":
            add_flame(M, "Head", top + Vector((sd * 0.18 * S, 0.0, -0.02)), 0.12 * S, 0.34 * S, ("F06A2A", "F8C040"))
        elif h == "unicorn" and sd == 1:
            base = top + Vector((0, -0.1 * S, -0.02))
            v, f = cone(base, base + Vector((0, -0.12 * S, 0.5 * S)), 0.08 * S, 0.0, seg=10)
            M.add("Head", v, f, ("c", "F8E8A0"), outline=0.008)
            for k in range(4):
                v, f = torus(base + Vector((0, -0.03 * k * S, (0.08 + k * 0.1) * S)), (0.07 - k * 0.015) * S, 0.012 * S, seg=12, tseg=4)
                M.add("Head", v, f, ("c", "E0B860"))


def add_flame(M, group, base, r, h, cols=("F06A2A", "F8C040")):
    base = Vector(base)
    v, f = cone(base, base + Vector((0, 0.05, h)), r, 0.0, seg=10)
    M.add(group, v, f, ("n", cols[0]), outline=0.006)
    v, f = cone(base + Vector((0, -0.01, 0.02)), base + Vector((0, 0.03, h * 0.6)), r * 0.55, 0.0, seg=8)
    M.add(group, v, f, ("n", cols[1]))


def add_crest(M, s, a, S, path):
    cr = s.get("crest")
    if not cr:
        return
    top = Vector(a["top"])
    back = Vector(a["back"])
    acc = s["accent"]
    if cr == "flame":
        for k in range(5):
            p = top + Vector(((k - 2) * 0.09 * S, 0.05 + abs(k - 2) * 0.05, -0.04))
            add_flame(M, "Head", p, 0.1 * S, (0.42 - abs(k - 2) * 0.08) * S)
    elif cr == "wave":
        for k in range(9):
            u = k / 8
            p = top + Vector((0, 0.35 * S - u * 0.55 * S, 0.05 + math.sin(u * math.pi) * 0.32 * S))
            v, f = ellipsoid(p, (0.16 * S * (1 - 0.4 * u), 0.12 * S, 0.08 * S), seg=10, rings=6)
            M.add("Head", v, f, ("g", s["accent"] if k % 2 else s["body"]), outline=0.008)
        for k in range(4):
            v, f = ellipsoid(top + Vector(((k - 1.5) * 0.08, -0.2 * S, 0.3 * S)), (0.07 * S,) * 3, seg=8, rings=5)
            M.add("Head", v, f, ("c", "F4FCFF"))
    elif cr == "leaf":
        for k in range(7):
            ang = math.pi * (0.15 + 0.7 * k / 6)
            d = Vector((math.cos(ang), 0.5, math.sin(ang) * 0.7 + 0.5)).normalized()
            p = top + Vector((math.cos(ang) * 0.3 * S, 0.1, 0))
            v, f = flat_shape(p, leaf2d(0.34 * S, 0.11 * S), (0, -0.3, 1) if False else Vector((math.cos(ang + math.pi / 2), 0, 0)) + Vector((0, 0.2, 0)), d, 0.02)
            M.add("Head", v, f, ("c", "5AB040" if k % 2 else "3E8A30"), outline=0.006)
    elif cr == "spikes":
        for k in range(4):
            p = top + Vector((0, 0.08 + k * 0.12 * S, -0.02 - k * 0.06 * S))
            v, f = cone(p, p + Vector((0, 0.1 * S, 0.24 * S)), 0.09 * S, 0.0, seg=8)
            M.add("Head", v, f, ("c", acc), outline=0.008)
        # crête dorsale le long du corps
        for i in range(5, int(len(path) * 0.92), 5):
            p, d = surf(i, 0.0, -0.04)
            rr = body_frames()[1][i]
            v, f = cone(p, p + d * (0.2 + rr * 0.35), 0.06 + rr * 0.12, 0.0, seg=8)
            M.add(grp_of(i), v, f, ("c", acc), outline=0.008)
    elif cr == "mohawk":
        for k in range(7):
            p = top + Vector((0, -0.12 * S + k * 0.07 * S, -0.03))
            v, f = cone(p, p + Vector(((k % 3 - 1) * 0.05, 0.05, (0.3 - abs(k - 3) * 0.03) * S)), 0.05 * S, 0.0, seg=6)
            M.add("Head", v, f, ("c", acc), outline=0.006)
    elif cr == "frill":
        for sd in (-1, 1):
            for k in range(4):
                p = back + Vector((sd * 0.3 * S, -0.05 * k, 0.15 * S - k * 0.08 * S))
                v, f = cone(p, p + Vector((sd * 0.28 * S, 0.22 * S, 0.12 * S - k * 0.06 * S)), 0.07 * S, 0.0, seg=8)
                M.add("Head", v, f, ("c", acc), outline=0.006)
    elif cr == "feather":
        colors = [s["accent"], "F8D060", s["body"]]
        for k in range(5):
            ang = (k - 2) * 0.32
            d = Vector((math.sin(ang), 0.5, 1)).normalized()
            v, f = flat_shape(top + Vector((0, 0.05, -0.03)), leaf2d(0.45 * S, 0.08 * S), Vector((math.cos(ang), 0, -math.sin(ang))), d, 0.025)
            M.add("Head", v, f, ("c", colors[k % 3]), outline=0.006)
    elif cr == "mane":
        rb = ["E07070", "F0B040", "F0E060", "70D090", "70B0E0", "A070D0"]
        for k in range(12):
            i = 1 + k * 2
            p, d = surf(i, 0.0, 0.02)
            v, f = ellipsoid(p, (0.14, 0.14, 0.14), seg=8, rings=5)
            M.add("Body", v, f, ("c", rb[k % 6]), outline=0.006)
        for k in range(6):
            v, f = ellipsoid(top + Vector(((k % 3 - 1) * 0.12, 0.15 + 0.08 * k, -0.02 - 0.05 * k)), (0.13, 0.13, 0.13), seg=8, rings=5)
            M.add("Head", v, f, ("c", rb[k % 6]), outline=0.006)
    elif cr == "flower_tuft":
        for k in range(3):
            add_flower(M, "Head", top + Vector(((k - 1) * 0.15 * S, 0.06, 0.06 + (k % 2) * 0.06)), 0.1 * S, "F08A40", "F8E060")


# ───────────────────────── Ailes ─────────────────────────

def add_wings(M, s, path):
    w = s.get("wings")
    if not w:
        return
    anchor = path[int(len(path) * 0.18)]
    for side, sd in (("WingR", 1), ("WingL", -1)):
        h = anchor + Vector((sd * 0.32, 0.2, 0.15))
        M.hinge(side, h)
        if w == "feather":
            colors = [s["body"], s["accent"], "F8D060"]
            for k in range(11):
                ang = math.radians(22 + k * 9)
                d = Vector((sd * math.cos(ang), 0.25, math.sin(ang))).normalized()
                L = 1.5 - abs(k - 6) * 0.09
                v, f = flat_shape(h + Vector((0, 0.01 * k, 0)), leaf2d(L, 0.3), Vector((0, -1, 0.1)), d, 0.035)
                M.add(side, v, f, ("c", colors[k % 3]), outline=0.008)
        else:
            pts = [(0, 0)]
            for k in range(6):
                ang = math.radians(15 + k * 22)
                r = 1.3 if k % 2 == 0 else 0.95
                pts.append((math.cos(ang) * r, math.sin(ang) * r * 0.9))
            poly = [(sd * x, y) for x, y in pts]
            if sd < 0:
                poly = list(reversed(poly))
            v, f = flat_shape(h, poly, (0, -1, 0), (0, 0, 1), 0.035)
            M.add(side, v, f, ("c", mix(s["body"], s["accent"], 0.35)), outline=0.008)
            for k in (0, 2, 4, 6):
                if k < len(pts):
                    x, y = pts[k] if k else (0.0, 0.0)
            for k in range(0, 7, 2):
                ang = math.radians(15 + k * 22)
                v, f = cone(h, h + Vector((sd * math.cos(ang) * 1.3, 0.0, math.sin(ang) * 1.17)), 0.04, 0.012, seg=6)
                M.add(side, v, f, ("c", shade(s["body"], 0.7)))


# ───────────────────────── Queue ─────────────────────────

def add_tail_tip(M, s, tip, direction):
    t = s.get("tail")
    if not t:
        return
    tip, d = Vector(tip), Vector(direction).normalized()
    if t == "flame":
        add_flame(M, "Tail", tip - d * 0.05, 0.13, 0.42)
    elif t == "leaf":
        for k in range(3):
            v, f = flat_shape(tip, leaf2d(0.35, 0.12), Vector((math.cos(k * 2.1), 0, math.sin(k * 2.1))), d + Vector((0, 0, 0.3 * (k - 1))), 0.02)
            M.add("Tail", v, f, ("c", "4CA03A"), outline=0.006)
    elif t == "tuft":
        rb = ["F070B0", "F0A0D0", "E05090"]
        for k in range(5):
            v, f = ellipsoid(tip + d * 0.08 + Vector(((k % 3 - 1) * 0.06, 0, (k // 3) * 0.08)), (0.09,) * 3, seg=8, rings=5)
            M.add("Tail", v, f, ("c", rb[k % 3]), outline=0.006)
    elif t == "spike":
        v, f = cone(tip - d * 0.05, tip + d * 0.3, 0.1, 0.0, seg=8)
        M.add("Tail", v, f, ("c", s["accent"]), outline=0.008)
    elif t == "feather":
        colors = [s["accent"], "F8D060", s["body"]]
        for k in range(5):
            ang = (k - 2) * 0.35
            dd = (d + Vector((math.sin(ang), 0, math.cos(ang) * 0.3))).normalized()
            v, f = flat_shape(tip - d * 0.05, leaf2d(0.5, 0.09), Vector((0, 1, 0)), dd, 0.025)
            M.add("Tail", v, f, ("c", colors[k % 3]), outline=0.006)
    elif t == "flower":
        add_flower(M, "Tail", tip + d * 0.05, 0.12, "F08A40", "F8E060")
    elif t == "gold":
        v, f = ellipsoid(tip + d * 0.05, (0.08,) * 3, seg=8, rings=5)
        M.add("Tail", v, f, ("n", "F8E070"))


# ───────────────────────── Effets modélisés ─────────────────────────

def add_fx(M, s, path):
    fx = s.get("fx", [])
    rnd = random.Random(h32(len(s["id"]), ord(s["id"][0])))
    if "leaves" in fx:
        for k in range(8):
            i = 6 + k * 11
            p, d = surf(i, (1.1 if k % 2 else -1.1), -0.05)
            v, f = flat_shape(p, leaf2d(0.85, 0.3), d.cross(Vector((0, 0, 1))) + Vector((0, 0.01, 0)), d + Vector((0, 0, 0.8)), 0.03)
            M.add(grp_of(i), v, f, ("c", "5AB040" if k % 2 else "3E8A30"), outline=0.006)
    if "flowers" in fx:
        petal = s.get("hat_col", ["F08AB8"])[0] if s.get("hat") == "flowers" else "F08AB8"
        for k in range(7):
            i = 12 + k * 11
            p, d = surf(i, rnd.uniform(-1.2, 1.2), 0.0)
            add_flower(M, grp_of(i), p, 0.12, petal, "F8E060", d)
    if "flames" in fx or s.get("pattern") == "flame":
        for k in range(8):
            i = 4 + k * 10
            if i >= len(path) - 2:
                break
            p, d = surf(i, 0.0, -0.04)
            add_flame(M, grp_of(i), p, 0.14, 0.46)
            if s.get("pattern") == "flame":
                for sd in (-1, 1):
                    p2, _ = surf(i + 4, sd * 1.3, -0.04)
                    add_flame(M, grp_of(i + 4), p2, 0.1, 0.32)
    if "drips_ice" in fx:
        for k in range(6):
            i = 2 + k * 3
            p, d = surf(i, math.pi + rnd.uniform(-0.6, 0.6), -0.02)
            v, f = cone(p, p + Vector((0, 0, -0.26)), 0.07, 0.0, seg=8)
            M.add("Body", v, f, ("g", "D8F6FF"), outline=0.005)
    if "slime" in fx:
        for k in range(8):
            i = 2 + k * 9
            p, d = surf(i, rnd.choice((-1.9, 1.9, 2.4, -2.4)), -0.03)
            v, f = ellipsoid(p + Vector((0, 0, -0.08)), (0.07, 0.07, 0.15), seg=8, rings=5)
            M.add(grp_of(i), v, f, ("c", s["accent"] if k % 2 else s["body"]), outline=0.006)
    if "splash" in fx or "foam" in fx:
        for k in range(12):
            a = k / 12 * math.pi * 2
            p = Vector((0.6 + math.cos(a) * 1.15, math.sin(a) * 0.85, 0.12))
            v, f = ellipsoid(p, (0.14, 0.14, 0.12), seg=8, rings=5)
            M.add("Body", v, f, ("c", "D8F6FF" if k % 2 else s["accent"]), outline=0.005)
    if "lightning" in fx:
        for k in range(3):
            base = Vector((rnd.uniform(-0.8, 1.8), rnd.uniform(-0.3, 0.6), rnd.uniform(0.9, 2.2)))
            pts = [base]
            for z in range(4):
                pts.append(pts[-1] + Vector(((0.12 if z % 2 else -0.12), 0, -0.18)))
            for a0, b0 in zip(pts[:-1], pts[1:]):
                v, f = cone(a0, b0, 0.04, 0.03, seg=5)
                M.add("Body", v, f, ("n", "F8F080"))
    if "sparkles" in fx or "stars" in fx:
        for k in range(6):
            p = Vector((rnd.uniform(-0.8, 2.0), rnd.uniform(-0.6, 0.5), rnd.uniform(0.5, 2.6)))
            v, f = flat_shape(p, star2d(0.1, 0.03, 4), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.02)
            M.add("Body", v, f, ("n", "FFF4A0" if "sparkles" in fx else "FFFFFF"))
    if "coins" in fx:
        for k in range(7):
            p = Vector((rnd.uniform(-0.6, 1.9), rnd.uniform(-0.8, 0.6), 0.05))
            v, f = cone(p, p + Vector((0, 0, 0.05)), 0.12, 0.12, seg=14)
            M.add("Body", v, f, ("c", "F8D040"), outline=0.006)


# ───────────────────────── Corps (variantes) ─────────────────────────

_PATH = None


def path_points():
    global _PATH
    if _PATH is None:
        _PATH = catmull(CTRL, N_SAMPLES)
    return [p.copy() for p in _PATH]


def build_body(M, s):
    path = path_points()
    n = len(path)
    radii = [radius_at(i / (n - 1)) for i in range(n)]
    pat = s.get("pattern", "solid")
    split = int(n * TAIL_SPLIT)
    M.hinge("Tail", path[split])
    if pat == "ribs":
        bone = s["body"]
        # colonne
        v, f, _, _ = tube(path, [r * 0.32 for r in radii], belly_dir, seg=10)
        M.add("Body", v, f, ("c", shade(bone, 0.8)))
        _, _, ups, sides = body_frames()
        for i in range(2, n - 1, 3):
            r = radii[i]
            grp = grp_of(i)
            tan = (path[min(n - 1, i + 1)] - path[max(0, i - 1)]).normalized()
            # vertèbre
            v, f = ellipsoid(path[i], (r * 0.62, r * 0.62, r * 0.62), seg=10, rings=6)
            M.add(grp, v, f, ("c", bone), outline=0.012)
            # côtes (arc ouvert côté ventre)
            v, f = torus(path[i], r * 0.92, max(0.05, r * 0.2), axis=tan, seg=16, tseg=6, arc=math.pi * 1.45)
            rotm = Matrix.Rotation(math.atan2(ups[i].dot(sides[i].cross(tan)), ups[i].dot(sides[i])) + math.pi * 0.27, 3, tan)
            v = [tuple(rotm @ (Vector(p) - path[i]) + path[i]) for p in v]
            M.add(grp, v, f, ("c", bone), outline=0.012)
        return path, radii
    if pat == "pixel":
        for i in range(0, n, 2):
            grp = "Tail" if i >= split else "Body"
            r = radii[i]
            v, f = box(path[i], (r * 1.7, r * 1.7, r * 1.7))
            M.add(grp, v, f, ("c", s["body"] if (i // 2) % 3 else s["accent"]), outline=0.012)
        return path, radii
    if s.get("head") == "octopus":
        return path, radii
    for part, lo, hi in (("Body", 0, split + 1), ("Tail", split - 1, n)):
        sub = path[lo:hi]
        sr = radii[lo:hi]
        v, f, info, _ = tube(sub, sr, belly_dir, seg=SEG, cap_start=(part == "Body"), cap_end=True)
        cols = []
        for (i, j, ang) in info:
            gi = lo + i
            cols.append(skin_color(s, gi / (n - 1), gi, j, ang, sub[min(i, len(sub) - 1)], SEG))
        M.add(part, v, f, cols, outline=0.028)
    if s.get("mummy"):
        for i in range(2, n - 3, 3):
            tan = (path[min(n - 1, i + 1)] - path[max(0, i - 1)]).normalized()
            tilt = Matrix.Rotation(0.3 * (1 if (i // 3) % 2 else -1), 3, "X") @ tan
            v, f = torus(path[i], radii[i] * 1.0, 0.06, axis=tilt, seg=18, tseg=6)
            M.add("Tail" if i >= split else "Body", v, f, ("c", s["accent"] if (i // 4) % 2 else "F2E6C8"))
    return path, radii


def build_octopus(M, s):
    c = Vector((0.4, 0.0, 1.35))
    v, f = ellipsoid(c, (0.62, 0.6, 0.72), seg=22, rings=12)
    M.add("Head", v, f, ("c", s["body"]), outline=0.025)
    for k in range(9):
        a = k / 9 * math.pi * 2
        v, f = ellipsoid(c + Vector((math.cos(a) * 0.45, math.sin(a) * 0.4, 0.3)), (0.09, 0.09, 0.06), seg=8, rings=5)
        M.add("Head", v, f, ("c", s["belly"]))
    for sd in (-1, 1):
        add_eye(M, "Head", c + Vector((sd * 0.26, -0.5, 0.05)), Vector((sd * 0.4, -1, 0)), 0.16, s, sd)
    add_smile(M, "Head", c + Vector((0, -0.62, -0.18)), Vector((0, -1, 0)), 0.12)
    M.hinge("Head", c + Vector((0, 0, -0.6)))
    for k in range(8):
        a = k / 8 * math.pi * 2 + 0.2
        pts = [c + Vector((math.cos(a) * 0.35, math.sin(a) * 0.3, -0.5))]
        for m in range(1, 6):
            r = 0.35 + m * 0.22
            curl = math.sin(m * 0.9 + k) * 0.25
            pts.append(c + Vector((math.cos(a + curl) * r, math.sin(a + curl) * r * 0.85, -0.55 - m * 0.16 + (0.18 if m == 5 else 0))))
        path = catmull(pts, 18)
        radii = [0.16 * (1 - i / 18) + 0.03 for i in range(18)]
        v, f, info, _ = tube(path, radii, lambda t, p: Vector((0, 0, -1)), seg=10)
        cols = [("c", s["belly"] if ang < 1.0 else s["body"]) for (_, _, ang) in info]
        M.add("Body", v, f, cols, outline=0.018)
        for m in range(2, 17, 3):
            v, f = ellipsoid(path[m] + Vector((0, 0, -radii[m] * 0.8)), (0.04,) * 3, seg=6, rings=4)
            M.add("Body", v, f, ("c", s["belly"]))


def build_snake(s):
    M = Model(s["id"])
    if "aura" in s.get("fx", []) or s.get("pattern") == "galaxy":
        M.ink = ("n", s["accent"])
        M.inkw = 1.7
    if s.get("head") == "octopus":
        build_octopus(M, s)
        return M
    path, radii = build_body(M, s)
    neck_top = path[0]
    hc = head_frame(neck_top)
    M.hinge("Head", neck_top + Vector((0, 0, 0.05)))
    S = HEAD_SCALE if s.get("head") != "pixel" else HEAD_SCALE * 0.78
    anchors = build_head(M, s, hc, "Head", S)
    # cou supérieur dans la pièce Tête (évite un trou quand la tête bouge)
    v, f = ellipsoid(neck_top + Vector((0, -0.04, 0.08)), (0.28, 0.28, 0.24), seg=14, rings=8)
    M.add("Head", v, f, (body_kind(s) if s.get("pattern") not in ("ribs", "pixel") else "c", s["body"] if s.get("pattern") not in ("ribs",) else shade(s["body"], 0.85)))
    if s.get("mummy"):
        for k in range(7):
            z = -0.48 + k * 0.17
            if abs(z - 0.2) < 0.13:
                continue
            v, f = torus(hc + Vector((0, -0.08, z)), 0.68 - abs(z + 0.02) * 0.45, 0.065, axis=(0.18 * (1 if k % 2 else -1), 0.12, 1), seg=22, tseg=6)
            M.add("Head", v, f, ("c", "F2E6C8" if k % 2 else s["accent"]), outline=0.006)
    heads = s.get("heads", 1)
    if heads > 1:
        base = path[int(len(path) * 0.12)]
        offsets = [(-0.75, 0.15, 0.25), (0.75, 0.15, 0.25), (-0.5, 0.35, 0.75), (0.5, 0.35, 0.75)][: heads - 1]
        for k, off in enumerate(offsets):
            end = neck_top + Vector(off) + Vector((0, 0, -0.25))
            mid = (base + end) / 2 + Vector((off[0] * 0.2, 0.1, 0.1))
            npath = catmull([base, mid, end], 20)
            v, f, info, _ = tube(npath, [0.26] * 20, belly_dir, seg=12)
            cols = [skin_color(s, 0.2, i, j, ang, npath[0], 12) for (i, j, ang) in info]
            M.add("Head", v, f, cols, outline=0.022)
            build_head(M, s, end + Vector((0, -0.15, 0.22)), "Head", 0.82, primary=False)
            add_horns(M, s, {"top": end + Vector((0, -0.12, 0.5))}, 0.82)
    add_hat(M, s, anchors, S)
    add_horns(M, s, anchors, S)
    add_crest(M, s, anchors, S, path)
    add_wings(M, s, path)
    tip = path[-1]
    add_tail_tip(M, s, tip, (path[-1] - path[-3]))
    add_fx(M, s, path)
    return M


# ───────────────────────── Matériaux & objets Blender ─────────────────────────

_mats = {}


def material(kind, hexc):
    key = (kind, hexc)
    if key in _mats:
        return _mats[key]
    name = "%s_%s" % (kind, hexc)
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    col = hx(hexc)
    lin = tuple(((c / 255) ** 2.2) for c in col) + (1.0,)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Roughness"].default_value = 0.45
        if kind == "n":
            bsdf.inputs["Emission Color"].default_value = lin
            bsdf.inputs["Emission Strength"].default_value = 2.0
        if kind == "g":
            bsdf.inputs["Alpha"].default_value = 0.7
    m.diffuse_color = lin
    _mats[key] = m
    return m


def realize(M, location=(0, 0, 0)):
    root = bpy.data.objects.new(M.id, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = location
    for gname, buckets in M.groups.items():
        ge = bpy.data.objects.new("%s__%s" % (M.id, gname), None)
        bpy.context.scene.collection.objects.link(ge)
        ge.parent = root
        for (kind, hexc), (vs, fs, _) in buckets.items():
            if not fs:
                continue
            me = bpy.data.meshes.new("%s_%s_%s%s" % (M.id, gname, kind, hexc))
            me.from_pydata([tuple(v) for v in vs], [], fs)
            me.validate(clean_customdata=False)
            for p in me.polygons:
                p.use_smooth = True
            me.materials.append(material(kind, hexc))
            ob = bpy.data.objects.new("%s_%s" % (kind, hexc), me)
            bpy.context.scene.collection.objects.link(ob)
            ob.parent = ge
        h = M.hinges.get(gname)
        if h is not None:
            hv, hf = box(h, (0.04, 0.04, 0.04))
            me = bpy.data.meshes.new("%s_%s_hinge" % (M.id, gname))
            me.from_pydata(hv, [], hf)
            me.materials.append(material("c", "FF00FF"))
            ob = bpy.data.objects.new("Hinge", me)
            bpy.context.scene.collection.objects.link(ob)
            ob.parent = ge
    return root


def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    _mats.clear()


def build_one(spec, location=(0, 0, 0)):
    return realize(build_snake(spec), location)


def tri_count(root):
    n = 0
    for ob in root.children_recursive:
        if ob.type == "MESH":
            n += sum(len(p.vertices) - 2 for p in ob.data.polygons)
    return n


def export_roots(roots, path):
    bpy.ops.object.select_all(action="DESELECT")
    wanted = set(r.name for r in roots)
    for ob in bpy.context.view_layer.objects:
        p = ob
        while p is not None and p.name not in wanted:
            p = p.parent
        if p is not None:
            ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"EMPTY", "MESH"}, apply_unit_scale=True,
                             bake_space_transform=False, mesh_smooth_type="FACE", add_leaf_bones=False, path_mode="AUTO")


def build_all(specs=None, out_fbx=None, spacing=4.0, per_row=14):
    clear_scene()
    roots = []
    for k, s in enumerate(specs or CATALOG):
        roots.append(build_one(s, ((k % per_row) * spacing, (k // per_row) * spacing * 1.2, 0)))
    if out_fbx:
        export_roots(roots, out_fbx)
    return roots
