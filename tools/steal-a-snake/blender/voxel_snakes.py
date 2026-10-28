"""
Steal A Snake — générateur Blender de serpents et têtes de gardiens en style voxel (façon Steal An Egg).

Usage (dans Blender, via MCP ou la console) :
    exec(open(r"<repo>/tools/steal-a-snake/blender/voxel_snakes.py", encoding="utf-8").read())
    build_species(spec_dict)            # un serpent -> Empty nommé par l'Id
    build_guardian_head(look_dict, n)   # tête de gardien -> Empty "GuardianHead_<n>"
    export_collection(name, path)       # export FBX de tout ce qui est sous l'Empty/collection

Convention pour l'import Roblox : chaque couleur est un objet séparé nommé
    c_RRGGBB (opaque)  ·  n_RRGGBB (néon)  ·  g_RRGGBB (verre / translucide)
Le script Roblox d'import recolore les MeshParts d'après ce nom.
Repère Blender : Z = haut, la tête regarde -Y.
"""
import bpy
import bmesh
import math

VOXEL = 0.25  # taille d'un voxel en mètres (renormalisé côté Roblox)

FACES = (
    ((1, 0, 0), ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1))),
    ((-1, 0, 0), ((0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0))),
    ((0, 1, 0), ((0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0))),
    ((0, -1, 0), ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1))),
    ((0, 0, 1), ((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1))),
    ((0, 0, -1), ((0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0))),
)


def hexrgb(h):
    h = h.strip().lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255


class Grid:
    def __init__(self):
        self.v = {}

    def set(self, x, y, z, col, kind="c"):
        self.v[(int(round(x)), int(round(y)), int(round(z)))] = (tuple(col), kind)

    def sphere(self, cx, cy, cz, r, colorfn, kind="c", only_empty=False):
        ri = int(math.ceil(r))
        for x in range(int(cx) - ri - 1, int(cx) + ri + 2):
            for y in range(int(cy) - ri - 1, int(cy) + ri + 2):
                for z in range(int(cz) - ri - 1, int(cz) + ri + 2):
                    dx, dy, dz = x - cx, y - cy, z - cz
                    if dx * dx + dy * dy + dz * dz <= r * r:
                        if only_empty and (x, y, z) in self.v:
                            continue
                        res = colorfn(x, y, z, dx, dy, dz)
                        if res is not None:
                            col, k = res if isinstance(res, tuple) and len(res) == 2 and isinstance(res[0], tuple) else (res, kind)
                            self.v[(x, y, z)] = (col, k)

    def box(self, x0, x1, y0, y1, z0, z1, col, kind="c"):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.v[(x, y, z)] = (tuple(col), kind)

    def line(self, a, b, col, kind="c", step=0.4):
        n = max(1, int(math.dist(a, b) / step))
        for i in range(n + 1):
            t = i / n
            self.set(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, col, kind)


def hsh(*a):
    h = 2166136261
    for v in a:
        h = ((h ^ (int(v) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return h


# ───────────────────────── Matériaux ─────────────────────────

_mats = {}


def material(col, kind):
    key = (col, kind)
    if key in _mats:
        return _mats[key]
    name = "%s_%02X%02X%02X" % (kind, col[0], col[1], col[2])
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    lin = tuple(((c / 255) ** 2.2) for c in col) + (1.0,)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Roughness"].default_value = 0.6
        if kind == "n":
            bsdf.inputs["Emission Color"].default_value = lin
            bsdf.inputs["Emission Strength"].default_value = 2.0
        if kind == "g":
            bsdf.inputs["Alpha"].default_value = 0.6
    m.diffuse_color = lin
    _mats[key] = m
    return m


# ───────────────────────── Maillage (faces visibles + fusion coplanaire) ─────────────────────────

def grid_to_objects(grid, root_name, parent, offset=(0, 0, 0)):
    groups = {}
    for p, (col, kind) in grid.v.items():
        groups.setdefault((col, kind), []).append(p)
    occ = grid.v
    objs = []
    for (col, kind), pts in groups.items():
        bm = bmesh.new()
        vcache = {}

        def vert(x, y, z):
            k = (x, y, z)
            v = vcache.get(k)
            if v is None:
                v = bm.verts.new(((x + offset[0]) * VOXEL, (y + offset[1]) * VOXEL, (z + offset[2]) * VOXEL))
                vcache[k] = v
            return v

        for (x, y, z) in pts:
            for (n, quad) in FACES:
                nb = (x + n[0], y + n[1], z + n[2])
                other = occ.get(nb)
                # face visible si le voisin est vide, ou s'il est d'une autre « nature » translucide
                if other is not None and not (other[1] == "g" and kind != "g"):
                    continue
                vs = [vert(x + q[0], y + q[1], z + q[2]) for q in quad]
                try:
                    bm.faces.new(vs)
                except ValueError:
                    pass
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.dissolve_limit(bm, angle_limit=0.001, verts=bm.verts, edges=bm.edges, delimit={"NORMAL"})
        name = "%s_%02X%02X%02X" % (kind, col[0], col[1], col[2])
        me = bpy.data.meshes.new(root_name + "_" + name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        me.materials.append(material(col, kind))
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = parent
        objs.append(ob)
    return objs


# ───────────────────────── Tête ─────────────────────────

BONE = (240, 232, 214)
GOLD = (255, 205, 60)
BLACK = (25, 22, 28)
WHITE = (250, 250, 250)
TONGUE = (230, 40, 70)


def head(g, hx, hy, hz, kind, body, accent, belly, glow, scale=1.0, jaw_grid=None):
    """Tête voxel centrée en (hx, hy, hz), regard vers -Y."""
    s = scale
    hc = BONE if kind == "Skull" else body
    W, D, H = 3.6 * s, 4.8 * s, 2.7 * s
    # crâne
    for x in range(int(hx - W - 1), int(hx + W + 2)):
        for y in range(int(hy - D - 1), int(hy + D + 2)):
            for z in range(int(hz - H - 1), int(hz + H + 2)):
                dx, dy, dz = (x - hx) / W, (y - hy) / D, (z - hz) / H
                if kind in ("Viper", "Horned"):
                    # triangulaire : plus large à l'arrière, museau pointu
                    front = max(0.0, -(y - hy) / D)
                    dx = (x - hx) / (W * (1.0 - 0.35 * front))
                    inside = abs(dx) <= 1 and abs(dy) <= 1 and dz * dz + dx * dx * 0.3 <= 1
                else:
                    inside = dx * dx + dy * dy + dz * dz <= 1
                if inside:
                    col = hc
                    if z < hz - H * 0.45 and kind != "Skull":
                        col = belly
                    g.set(x, y, z, col)
    # mâchoire inférieure
    jg = jaw_grid if jaw_grid is not None else g
    for x in range(int(hx - W * 0.8), int(hx + W * 0.8) + 1):
        for y in range(int(hy - D * 0.95), int(hy + D * 0.4) + 1):
            z = int(hz - H - 0.5)
            jg.set(x, y, z, belly if kind != "Skull" else BONE)
    # yeux (gros yeux mignons façon Steal An Egg)
    ey = hy - D * 0.35
    ez = hz + H * 0.35
    for sx in (-1, 1):
        ex = hx + sx * (W + 0.3)
        if kind == "Skull":
            g.box(int(ex - 1), int(ex + 1), int(ey - 1), int(ey + 1), int(ez - 1), int(ez + 1), BLACK)
            g.set(ex, ey - 1, ez, accent, "n")
            continue
        g.box(int(ex - 1), int(ex + 1), int(ey - 1), int(ey + 1), int(ez - 1), int(ez + 1), WHITE)
        g.set(ex + sx, ey - 1, ez, accent if glow else BLACK, "n" if glow else "c")
        g.set(ex + sx, ey - 1, ez + 1, accent if glow else BLACK, "n" if glow else "c")
    # narines + langue fourchue
    ny = hy - D
    for sx in (-1, 1):
        g.set(hx + sx, ny - 1, hz + 0.5, BLACK)
    for k in range(3):
        jg.set(hx, ny - 1 - k, hz - H + 0.5, TONGUE)
    jg.set(hx - 1, ny - 4, hz - H + 0.5, TONGUE)
    jg.set(hx + 1, ny - 4, hz - H + 0.5, TONGUE)
    if kind == "Skull":
        for k in range(-2, 3):
            g.set(hx + k, ny + 1, hz - H, WHITE)
    top = hz + H + 1
    # variantes de tête
    if kind == "Cobra":
        for x in range(int(hx - 7 * s), int(hx + 7 * s) + 1):
            for z in range(int(hz - 7 * s), int(hz + 3 * s) + 1):
                dx, dz = (x - hx) / (7 * s), (z - (hz - 2 * s)) / (5.5 * s)
                if dx * dx + dz * dz <= 1:
                    inner = dx * dx * 2.4 + (dz - 0.1) ** 2 * 2.4 <= 1
                    for yy in (int(hy + D * 0.6), int(hy + D * 0.6) + 1):
                        g.set(x, yy, z, accent if inner else body)
    elif kind == "Horned":
        for sx in (-1, 1):
            for k in range(int(4 * s)):
                g.set(hx + sx * (2 * s + k * 0.35), hy + D * 0.2 + k * 0.2, top + k, accent)
    elif kind == "Crest":
        for k in range(int(D * 1.6)):
            hgt = max(1, int((3.5 - k * 0.35) * s))
            for z in range(hgt):
                g.set(hx, hy - D * 0.4 + k, top + z, accent)
    elif kind == "Mane":
        for a in range(0, 360, 12):
            r = 6 * s
            for rr in (r, r + 1):
                g.set(hx + math.cos(math.radians(a)) * rr, hy + D * 0.55, hz + math.sin(math.radians(a)) * rr, accent)
        for sx in (-1, 1):
            g.line((hx + sx * W, ny, hz - 0.5), (hx + sx * (W + 5 * s), ny - 3 * s, hz - 1.5), accent, "n")
    elif kind == "Crown":
        cz = int(top)
        r = int(2.6 * s)
        for x in range(int(hx) - r, int(hx) + r + 1):
            for y in range(int(hy) - r, int(hy) + r + 1):
                if abs(x - hx) >= r - 0.5 or abs(y - hy) >= r - 0.5:
                    g.set(x, y, cz, GOLD)
                    if (abs(x - hx) >= r - 0.5 and abs(y - hy) >= r - 0.5) or (x == int(hx)):
                        g.set(x, y, cz + 1, GOLD)
                        g.set(x, y, cz + 2, GOLD)
        g.set(hx, hy - r, cz + 1, accent, "n")
    return top


# ───────────────────────── Serpent enroulé ─────────────────────────

def coil_point(t):
    a = t * math.pi * 2 * 2.1
    R = 9.0 - 5.0 * t
    return (math.cos(a) * R, math.sin(a) * R, 1.8 + t * 5.0)


def build_snake_grid(spec):
    g = Grid()
    body = hexrgb(spec["body"])
    accent = hexrgb(spec["accent"])
    belly = mix(body, (255, 255, 255), 0.55)
    pattern = spec["pattern"]
    mat = spec["material"]
    extras = set(spec.get("extras", []))
    glow = pattern == "Glow" or mat == "Neon"
    body_kind = "g" if (mat in ("Glass", "Ice") or "Ghost" in extras) else "c"
    accent_kind = "n" if glow else body_kind

    steps = 140
    for i in range(steps + 1):
        t = i / steps
        cx, cy, cz = coil_point(t)
        r = 1.5 + 2.3 * t

        def colorfn(x, y, z, dx, dy, dz, t=t, r=r):
            topness = dz / r
            if topness < -0.45:
                return (belly, body_kind)
            col, kind = body, body_kind
            if pattern == "Bands" and int(t * 26) % 3 == 0:
                col, kind = accent, accent_kind
            elif pattern == "Rings" and int(t * 34) % 2 == 0:
                col, kind = accent, accent_kind
            elif pattern == "Stripes" and topness > 0.55:
                col, kind = accent, accent_kind
            elif pattern == "Spots" and topness > -0.1 and hsh(x // 2, y // 2, z // 2) % 5 == 0:
                col, kind = accent, accent_kind
            elif pattern == "Diamonds" and topness > 0.35 and int(t * 44) % 4 in (1, 2):
                col, kind = accent, accent_kind
            elif pattern == "Glow" and topness > 0.5 and int(t * 22) % 2 == 0:
                col, kind = accent, "n"
            if "Lava" in extras and topness > 0.6 and hsh(x, y, z) % 4 == 0:
                col, kind = (255, 120, 30), "n"
            return (col, kind)

        g.sphere(cx, cy, cz, r, colorfn, only_empty=True)
        if i % 9 == 4:
            tx, ty, tz = cx, cy, cz + r
            if "Spikes" in extras:
                for k in range(3):
                    g.set(tx, ty, tz + k, accent, accent_kind)
            if "Bones" in extras:
                for k in range(-int(r), int(r) + 1):
                    g.set(tx + k * 0.7, ty + k * 0.7, tz, BONE)
            if "Frost" in extras:
                for k in range(3):
                    g.set(tx, ty, tz + k, (220, 245, 255), "g")
        if i % 17 == 8:
            tx, ty, tz = cx, cy, cz + r
            if "Crystals" in extras:
                for k in range(5):
                    g.set(tx + k * 0.25, ty, tz + k, accent, "g")
                    g.set(tx + 1 + k * 0.25, ty, tz + k * 0.8, accent, "g")
            if "Leaves" in extras:
                g.box(int(tx) - 1, int(tx) + 1, int(ty), int(ty) + 2, int(tz), int(tz), (70, 170, 60))
            if "Mushrooms" in extras:
                g.set(tx, ty, tz, BONE)
                g.box(int(tx) - 1, int(tx) + 1, int(ty) - 1, int(ty) + 1, int(tz) + 1, int(tz) + 1, (230, 40, 50))
                g.set(tx, ty, tz + 2, WHITE)
            if "Flowers" in extras:
                g.box(int(tx) - 1, int(tx) + 1, int(ty) - 1, int(ty) + 1, int(tz), int(tz), (255, 130, 190))
                g.set(tx, ty, tz + 1, (255, 220, 60))
    # queue
    tx, ty, tz = coil_point(0)
    if "Rattle" in extras:
        for k in range(4):
            g.box(int(tx) - 1, int(tx) + 1, int(ty) - 1, int(ty) + 1, int(tz + 2 + k * 1.2), int(tz + 2 + k * 1.2), (225, 200, 150) if k % 2 == 0 else (190, 160, 110))
    # cou dressé
    nx, ny, nz = coil_point(1.0)
    hx, hy, hz = 0.0, -2.0, 15.5
    for i in range(14):
        t = i / 13
        px = nx + (hx - nx) * t
        py = ny + (hy + 3 - ny) * t
        pz = nz + (hz - 3 - nz) * t + math.sin(t * math.pi) * 1.2
        g.sphere(px, py, pz, 3.2, lambda x, y, z, dx, dy, dz: (belly, body_kind) if dy < -1.2 else (body, body_kind), only_empty=True)
    top = head(g, hx, hy, hz, spec["head"], body, accent, belly, glow)
    if spec["head"] == "Hydra":
        for sx in (-1, 1):
            bx, by, bz = sx * 9.0, 1.0, 12.0
            for i in range(10):
                t = i / 9
                g.sphere(nx + (bx - nx) * t, ny + (by - ny) * t, nz + (bz - 2 - nz) * t, 2.2, lambda x, y, z, dx, dy, dz: (body, body_kind), only_empty=True)
            head(g, bx, by, bz, "Viper", body, accent, belly, glow, scale=0.7)
    # accessoires de tête / corps
    if "Halo" in extras:
        for a in range(0, 360, 8):
            g.set(hx + math.cos(math.radians(a)) * 4, hy + math.sin(math.radians(a)) * 4, top + 3, GOLD, "n")
    if "Wings" in extras:
        for sx in (-1, 1):
            for k in range(11):
                span = 4 + k
                for z in range(int(hz - 6 + k * 0.3), int(hz - 1 + k * 0.6)):
                    g.set(sx * span, hy + 5, z, accent if k % 3 == 0 else body, accent_kind if k % 3 == 0 else body_kind)
    if "Feathers" in extras:
        plume = [(230, 50, 50), (40, 180, 120), (255, 210, 60), (60, 120, 230)]
        for k in range(5):
            g.line((hx + (k - 2) * 1.2, hy + 2, top), (hx + (k - 2) * 2.2, hy + 4, top + 6), plume[k % 4])
    if "Fins" in extras:
        for sx in (-1, 1):
            for k in range(4):
                g.line((hx + sx * 4, hy + 1, hz - 1 + k), (hx + sx * (8 - k), hy + 3, hz - 2 + k), accent, accent_kind)
        mx, my, mz = coil_point(0.45)
        for k in range(5):
            g.line((mx, my - 2 + k, mz + 3), (mx, my - 1 + k * 0.6, mz + 7 - k), accent, accent_kind)
    if "Antlers" in extras:
        for sx in (-1, 1):
            g.line((hx + sx * 2, hy + 1, top), (hx + sx * 4, hy + 2, top + 5), accent)
            g.line((hx + sx * 3, hy + 1.5, top + 2), (hx + sx * 6, hy + 1, top + 4), accent)
    if "Tusks" in extras:
        for sx in (-1, 1):
            g.line((hx + sx * 2, hy - 4, hz - 3), (hx + sx * 2.5, hy - 6, hz - 6), WHITE)
    if "Flames" in extras:
        for k in range(16):
            x = hx + (hsh(k, 1) % 7) - 3
            y = hy + (hsh(k, 2) % 7) - 3
            for z in range(int(top), int(top + 2 + hsh(k, 3) % 5)):
                g.set(x, y, z, (255, 150, 30) if z < top + 2 else (255, 230, 80), "n")
    if "Stars" in extras or "Sparkle" in extras:
        for k in range(6):
            a = k / 6 * math.pi * 2
            g.set(math.cos(a) * 11, math.sin(a) * 11, 6 + (k % 3) * 3, (255, 240, 140), "n")
    return g


# ───────────────────────── API ─────────────────────────

def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    _mats.clear()


def build_species(spec, location=(0, 0, 0)):
    g = build_snake_grid(spec)
    root = bpy.data.objects.new(spec["id"], None)
    bpy.context.scene.collection.objects.link(root)
    root.location = location
    grid_to_objects(g, spec["id"], root)
    return root


GUARDIAN_HEAD_KIND = {
    "Crest": "Crest", "Hood": "Cobra", "Toxic": "Horned", "Frost": "Crest", "Mane": "Mane", "Rattle": "Horned",
    "Spores": "Round", "Fins": "Round", "Fire": "Horned", "Crystal": "Crest", "Ghost": "Skull", "Feathers": "Crest",
    "Radioactive": "Horned", "Wings": "Crown", "Rainbow": "Crown",
}


def build_guardian_head(look, order, location=(0, 0, 0)):
    """Grosse tête de gardien : crâne (plusieurs couleurs) + mâchoire séparée « lower jaw »."""
    g = Grid()
    jaw = Grid()
    body = hexrgb(look["body"])
    accent = hexrgb(look["accent"])
    belly = hexrgb(look["belly"])
    glow = look.get("neon", False)
    kind = GUARDIAN_HEAD_KIND.get(look["feature"], "Viper")
    top = head(g, 0, 0, 0, kind, body, accent, belly, glow, scale=2.2, jaw_grid=jaw)
    f = look["feature"]
    # crocs
    for sx in (-1, 1):
        for k in range(3):
            g.set(sx * 3, -9.5, -5 - k, WHITE)
    if f in ("Frost", "Crystal"):
        for k in range(6):
            x = (k - 2.5) * 2.2
            g.line((x, 2, top), (x * 1.3, 4, top + 5 + (k % 3) * 2), (220, 245, 255) if f == "Frost" else accent, "g")
    elif f == "Fire":
        for k in range(30):
            x = (hsh(k, 1) % 13) - 6
            y = (hsh(k, 2) % 13) - 6
            for z in range(int(top), int(top + 2 + hsh(k, 3) % 7)):
                g.set(x, y, z, (255, 150, 30) if z < top + 3 else (255, 230, 80), "n")
    elif f == "Spores":
        cap = (255, 90, 160) if accent == (0, 0, 0) else accent
        for x in range(-10, 11):
            for y in range(-10, 11):
                for z in range(0, 6):
                    if x * x / 100 + y * y / 100 + z * z / 30 <= 1:
                        g.set(x, y, top + z, WHITE if hsh(x // 3, y // 3, z // 3) % 4 == 0 else cap)
    elif f == "Fins":
        for sx in (-1, 1):
            for k in range(8):
                g.line((sx * 8, 2, -2 + k), (sx * (16 - k), 6, -3 + k), accent, "n" if glow else "c")
    elif f in ("Wings", "Feathers"):
        plume = [accent, belly, body]
        for k in range(7):
            g.line(((k - 3) * 2, 4, top), ((k - 3) * 4, 9, top + 12 - abs(k - 3) * 2), plume[k % 3], "n" if f == "Wings" else "c")
        if f == "Wings":
            for a in range(0, 360, 6):
                g.set(math.cos(math.radians(a)) * 9, math.sin(math.radians(a)) * 9, top + 9, GOLD, "n")
    elif f in ("Toxic", "Radioactive"):
        for k in range(10):
            x = (hsh(k, 7) % 15) - 7
            y = (hsh(k, 8) % 15) - 7
            g.box(x, x + 1, y, y + 1, int(top) - 1, int(top), accent, "n")
    elif f == "Rainbow":
        for ring in range(6):
            hue = ring / 6
            col = tuple(int(c * 255) for c in __import__("colorsys").hsv_to_rgb(hue, 0.8, 1.0))
            for a in range(0, 360, 5):
                r = 12 + ring * 1.2
                g.set(math.cos(math.radians(a)) * r, 6, math.sin(math.radians(a)) * r, col, "n")
    elif f == "Ghost":
        pass
    root = bpy.data.objects.new("GuardianHead_%d" % order, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = location
    grid_to_objects(g, root.name, root)
    jaw_objs = grid_to_objects(jaw, root.name + "_jaw", root)
    # une seule pièce de mâchoire : on fusionne et on nomme « lower jaw »
    if jaw_objs:
        bpy.ops.object.select_all(action="DESELECT")
        for o in jaw_objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = jaw_objs[0]
        if len(jaw_objs) > 1:
            bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name = "lower jaw"
    return root


def export_roots(roots, path):
    bpy.ops.object.select_all(action="DESELECT")
    wanted = set(r.name for r in roots)
    for ob in bpy.context.view_layer.objects:
        p = ob
        while p is not None and p.name not in wanted:
            p = p.parent
        if p is not None:
            ob.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"EMPTY", "MESH"},
        apply_unit_scale=True,
        bake_space_transform=False,
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        path_mode="AUTO",
    )
