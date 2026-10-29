# Ether Blades - kit de modelisation (poignees + architecture du Hub + elements d'arenes).
# Execution dans Blender :
#   exec(open(r"C:\Users\devaa\Desktop\robiloxiiiii\blender\eb_kit.py", encoding="utf-8").read())
# Construit une scene dediee "EB_Kit" (les autres scenes ne sont pas touchees) puis exporte
#   C:\Users\devaa\Desktop\robiloxiiiii\exports\EB_Kit.fbx
# 1 unite Blender = 1 stud. Axe Z Blender = haut.
# Convention de nommage (lue par le script Luau d'import) :
#   <Groupe>_<Piece>__<Materiau>_<HEXCOULEUR>   ex. HiltA_Grip__Rubber_1C1E22
#   Groupe = prefixe avant le premier "_". Un suffixe "A" (ex. __Neon_40E0FFA) marque une piece
#   d'accent que le jeu peut teinter a la couleur de la lame / du pod.
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

random.seed(7)
EXPORT_DIR = r"C:\Users\devaa\Desktop\robiloxiiiii\exports"
EXPORT_PATH = os.path.join(EXPORT_DIR, "EB_Kit.fbx")

# ---------------------------------------------------------------- scene dediee
scn = bpy.data.scenes.get("EB_Kit")
if scn is None:
    scn = bpy.data.scenes.new("EB_Kit")
for o in list(scn.objects):
    bpy.data.objects.remove(o, do_unlink=True)
for m in list(bpy.data.meshes):
    if m.users == 0:
        bpy.data.meshes.remove(m)
bpy.context.window.scene = scn

created = []


def finish(bm, name, smooth, offset=(0, 0, 0)):
    if smooth is not None:
        for f in bm.faces:
            f.smooth = smooth
    if offset != (0, 0, 0):
        bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(offset))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scn.collection.objects.link(ob)
    created.append(name)
    return ob


def lathe(name, profile, segs=24, smooth=True, offset=(0, 0, 0), rfunc=None, rot=0.0, sx=1.0, sy=1.0, caps=True):
    """profile = [(r, z), ...]. Chaque segment du profil = bande separee (aretes vives entre bandes)."""
    bm = bmesh.new()
    for i in range(len(profile) - 1):
        (r0, z0), (r1, z1) = profile[i], profile[i + 1]
        ring = []
        for (r, z) in ((r0, z0), (r1, z1)):
            if r < 1e-6:
                ring.append([bm.verts.new((0, 0, z))])
            else:
                pts = []
                for k in range(segs):
                    a = rot + 2 * math.pi * k / segs
                    rr = r * (rfunc(k) if rfunc else 1.0)
                    pts.append(bm.verts.new((rr * math.cos(a) * sx, rr * math.sin(a) * sy, z)))
                ring.append(pts)
        A, B = ring
        if len(A) == 1 and len(B) == 1:
            continue
        for k in range(segs):
            k2 = (k + 1) % segs
            if len(A) == 1:
                f = bm.faces.new((A[0], B[k2], B[k]))
            elif len(B) == 1:
                f = bm.faces.new((A[k], A[k2], B[0]))
            else:
                f = bm.faces.new((A[k], A[k2], B[k2], B[k]))
            f.smooth = smooth
    # bouchons si les extremites ne sont pas fermees
    for (r, z), first in ((profile[0], True), (profile[-1], False)):
        if caps and r > 1e-6:
            pts = [bm.verts.new((r * (rfunc(k) if rfunc else 1.0) * math.cos(rot + 2 * math.pi * k / segs) * sx,
                                 r * (rfunc(k) if rfunc else 1.0) * math.sin(rot + 2 * math.pi * k / segs) * sy, z))
                   for k in range(segs)]
            if first:
                pts.reverse()
            f = bm.faces.new(pts)
            f.smooth = False
    return finish(bm, name, None, offset)


def sweep(name, path, section, closed=False, up=(0, 1, 0), smooth_along=True, shared=False, offset=(0, 0, 0)):
    """Balaye une section 2D [(u, v)] le long d'un chemin 3D. u = normale dans le plan, v = binormale."""
    bm = bmesh.new()
    upv = Vector(up)
    n = len(path)
    frames = []
    for i in range(n):
        p = Vector(path[i])
        if closed:
            t = Vector(path[(i + 1) % n]) - Vector(path[(i - 1) % n])
        else:
            t = Vector(path[min(i + 1, n - 1)]) - Vector(path[max(i - 1, 0)])
        t.normalize()
        nn = t.cross(upv)
        if nn.length < 1e-6:
            nn = t.cross(Vector((1, 0, 0)))
        nn.normalize()
        b = nn.cross(t)
        b.normalize()
        frames.append((p, nn, b))
    m = len(section)
    if shared:
        rings = [[bm.verts.new(p + nn * u + b * v) for (u, v) in section] for (p, nn, b) in frames]
        segN = n if closed else n - 1
        for i in range(segN):
            R0, R1 = rings[i], rings[(i + 1) % n]
            for k in range(m):
                k2 = (k + 1) % m
                f = bm.faces.new((R0[k], R1[k], R1[k2], R0[k2]))
                f.smooth = True
        ends = []
    else:
        segN = n if closed else n - 1
        for k in range(m):
            k2 = (k + 1) % m
            col = [(bm.verts.new(p + nn * section[k][0] + b * section[k][1]),
                    bm.verts.new(p + nn * section[k2][0] + b * section[k2][1])) for (p, nn, b) in frames]
            for i in range(segN):
                a0, a1 = col[i]
                c0, c1 = col[(i + 1) % n]
                f = bm.faces.new((a0, c0, c1, a1))
                f.smooth = smooth_along
        ends = []
        if not closed:
            for (p, nn, b) in (frames[0], frames[-1]):
                ends.append([bm.verts.new(p + nn * u + b * v) for (u, v) in section])
    if not closed and shared:
        ends = [list(rings[0]), list(rings[-1])]
    for idx, e in enumerate(ends):
        if idx == 1:
            e = list(reversed(e))
        f = bm.faces.new(e)
        f.smooth = False
    return finish(bm, name, None, offset)


def box(name, size, center=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect='EDGES')
    return finish(bm, name, False)


def sphere(name, r, center, segs=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(center))
    return finish(bm, name, True)


def rock(name, radius, center, seed, flat_bottom=True, stretch=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=radius)
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in bm.verts:
        d = noise.noise(v.co * (1.3 / radius) + off)
        v.co *= 1.0 + 0.28 * d
        v.co = Vector((v.co.x * stretch[0], v.co.y * stretch[1], v.co.z * stretch[2]))
        if flat_bottom and v.co.z < -radius * 0.35:
            v.co.z = -radius * 0.35
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(center) + Vector((0, 0, radius * 0.35 * stretch[2])))
    return finish(bm, name, False)


def circle_path(R, n, z=0.0, mat=None, center=(0, 0, 0)):
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        p = Vector((R * math.cos(a), R * math.sin(a), z))
        if mat is not None:
            p = mat @ p
        pts.append(tuple(Vector(center) + p))
    return pts


def circ_section(r, n=8):
    return [(r * math.cos(2 * math.pi * k / n), r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def rect_section(w, d):
    return [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]


def pointed_arch_path(w, h, R_factor=1.6, steps=14, x0=0.0, z0=0.0):
    """Arc brise dans le plan XZ : pieds en (+-w, 0), naissance a h."""
    R = R_factor * w
    cx = R - w
    th = math.acos(-cx / R) if R > 0 else math.pi / 2
    left = [(-w, 0.0), (-w, h * 0.5)]
    for i in range(steps + 1):
        a = math.pi - (math.pi - th) * i / steps
        left.append((cx + R * math.cos(a), h + R * math.sin(a)))
    right = [(-x, z) for (x, z) in reversed(left[:-1])]
    pts = left + right
    return [(x0 + x, 0.0, z0 + z) for (x, z) in pts]


def offset_path(path, d, up=(0, 1, 0)):
    """Decale un chemin plan vers l'interieur (d > 0) de sa courbure (arc : vers l'ouverture)."""
    out = []
    n = len(path)
    for i in range(n):
        t = Vector(path[min(i + 1, n - 1)]) - Vector(path[max(i - 1, 0)])
        t.normalize()
        nn = t.cross(Vector(up))
        nn.normalize()
        out.append(tuple(Vector(path[i]) - nn * d))
    return out


def ridged(z0, z1, r_hi, r_lo, count):
    prof = []
    step = (z1 - z0) / count
    for i in range(count):
        za = z0 + i * step
        prof += [(r_lo, za), (r_hi, za + step * 0.2), (r_hi, za + step * 0.8)]
    prof.append((r_lo, z1))
    return prof


# ================================================================ REFERENCE (echelle / orientation)
box("REF_Tall__SmoothPlastic_FF00FF", (2, 2, 10), center=(-30, 0, 5))

# ================================================================ POIGNEE A "Aube" (Hilt_Single, 1.1 stud)
X = -14.0
O = (X, 0, 0)
lathe("HiltA_Pommel__Metal_33363D", [(0, 0), (0.07, 0), (0.115, 0.025), (0.12, 0.07), (0.1, 0.1)], 24, offset=O)
lathe("HiltA_PommelRing__Neon_40E0FFA", [(0.1, 0.1), (0.104, 0.105), (0.104, 0.115), (0.098, 0.12)], 24, offset=O, caps=False)
lathe("HiltA_Grip__Rubber_1C1E22", ridged(0.12, 0.6, 0.094, 0.086, 10), 24, offset=O)
lathe("HiltA_Collar__Metal_C9CDD4", [(0.098, 0.6), (0.108, 0.61), (0.108, 0.68), (0.1, 0.7), (0.096, 0.7), (0.096, 0.95),
                                       (0.104, 0.95), (0.12, 1.0), (0.13, 1.06), (0.118, 1.1), (0.072, 1.1), (0.072, 1.05), (0, 1.05)], 24, offset=O)
lathe("HiltA_Core__Neon_40E0FFA", [(0.0, 1.052), (0.06, 1.052), (0.05, 1.07), (0, 1.075)], 16, offset=O)
# fentes emissives verticales (3) + bouton d'activation
for i in range(3):
    a = 2 * math.pi * i / 3 + 0.3
    c = (X + 0.095 * math.cos(a), 0.095 * math.sin(a), 0.82)
    ob = box("HiltA_Slot%d__Neon_40E0FFA" % i, (0.018, 0.018, 0.2), center=(0, 0, 0))
    ob.data.transform(Matrix.Rotation(a, 4, 'Z'))
    ob.data.transform(Matrix.Translation(c))
box("HiltA_Button__Metal_D4A64A", (0.05, 0.03, 0.04), center=(X, -0.11, 0.645))
# trois ailettes asymetriques autour de l'emetteur
for i, (a, hgt) in enumerate(((0.0, 0.16), (2.3, 0.12), (4.1, 0.1))):
    pts = [(0.12, 0.92), (0.15, 1.0), (0.155, 0.92 + hgt)]
    ob = sweep("HiltA_Fin%d__Metal_D4A64A" % i, [(p[0], 0, p[1]) for p in pts], rect_section(0.02, 0.025), up=(0, 1, 0))
    ob.data.transform(Matrix.Rotation(a, 4, 'Z'))
    ob.data.transform(Matrix.Translation((X, 0, 0)))

# ================================================================ POIGNEE B "Couronne" (Hilt_Staff, 2.4 studs)
X = -11.0
O = (X, 0, 0)


def emitter_profile(z_base, sign):
    p = [(0.1, 0.0), (0.108, 0.06), (0.125, 0.12), (0.135, 0.17), (0.12, 0.2), (0.075, 0.2), (0.075, 0.15), (0, 0.15)]
    return [(r, z_base + sign * z) for (r, z) in p]


lathe("HiltB_EmitTop__Metal_C9CDD4", emitter_profile(2.2, 1), 24, offset=O)
lathe("HiltB_EmitBot__Metal_C9CDD4", emitter_profile(0.2, -1)[::-1], 24, offset=O)
lathe("HiltB_CoreTop__Neon_FFC850A", [(0, 2.352), (0.06, 2.352), (0.05, 2.37), (0, 2.375)], 16, offset=O)
lathe("HiltB_CoreBot__Neon_FFC850A", [(0, 0.025), (0.05, 0.03), (0.06, 0.048), (0, 0.048)], 16, offset=O)
lathe("HiltB_GripTop__Rubber_1C1E22", ridged(1.36, 1.86, 0.096, 0.088, 9), 24, offset=O)
lathe("HiltB_GripBot__Rubber_1C1E22", ridged(0.54, 1.04, 0.096, 0.088, 9), 24, offset=O)
lathe("HiltB_ShaftTop__Metal_33363D", [(0.1, 1.86), (0.1, 2.2)], 24, offset=O)
lathe("HiltB_ShaftBot__Metal_33363D", [(0.1, 0.2), (0.1, 0.54)], 24, offset=O)
lathe("HiltB_Center__Metal_D4A64A", [(0.1, 1.04), (0.118, 1.06), (0.118, 1.12), (0.108, 1.14), (0.108, 1.26), (0.118, 1.28), (0.118, 1.34), (0.1, 1.36)], 24, offset=O)
lathe("HiltB_CenterRing__Neon_FFC850A", [(0.106, 1.16), (0.112, 1.165), (0.112, 1.235), (0.106, 1.24)], 24, offset=O, caps=False)
for s, zc in ((1, 1.98), (-1, 0.42)):
    for i in range(2):
        a = math.pi * i
        ob = box("HiltB_Plate%s%d__Metal_C9CDD4" % ("T" if s > 0 else "B", i), (0.03, 0.07, 0.22), center=(0, 0, 0))
        ob.data.transform(Matrix.Translation((0.1, 0, 0)))
        ob.data.transform(Matrix.Rotation(a + 0.6, 4, 'Z'))
        ob.data.transform(Matrix.Translation((X, 0, zc)))

# ================================================================ POIGNEE C "Faucon" (variante Hilt_Single, 1.15 stud, hexagonale)
X = -8.0
O = (X, 0, 0)
lathe("HiltC_Pommel__Metal_2A2C33", [(0, 0), (0.06, 0), (0.11, 0.04), (0.11, 0.1), (0.095, 0.12)], 6, smooth=False, offset=O, rot=math.pi / 6)
lathe("HiltC_Grip__Rubber_2B1E1A", ridged(0.12, 0.62, 0.097, 0.09, 7), 6, smooth=False, offset=O, rot=math.pi / 6)
lathe("HiltC_Body__Metal_2A2C33", [(0.1, 0.62), (0.112, 0.64), (0.112, 0.7), (0.1, 0.72), (0.1, 1.0), (0.115, 1.02), (0.115, 1.15), (0.07, 1.15), (0.07, 1.1), (0, 1.1)], 6, smooth=False, offset=O, rot=math.pi / 6)
lathe("HiltC_Trim__Metal_D4A64A", [(0.113, 0.66), (0.118, 0.67), (0.118, 0.69), (0.113, 0.7)], 6, smooth=False, offset=O, rot=math.pi / 6, caps=False)
lathe("HiltC_Core__Neon_FF6A3CA", [(0, 1.102), (0.06, 1.102), (0.05, 1.12), (0, 1.125)], 6, smooth=False, offset=O)
# garde recourbee en crochet (signature du design)
hook = []
for i in range(9):
    t = i / 8
    a = math.pi * 0.5 * t
    hook.append((0.11 + 0.12 * math.sin(a), 0, 0.98 - 0.22 * (1 - math.cos(a)) + 0.12 * t))
sweep("HiltC_Hook__Metal_D4A64A", [(X + p[0], p[1], p[2]) for p in hook], rect_section(0.03, 0.035), up=(0, 1, 0))
for i in range(3):
    z = 0.78 + i * 0.07
    lathe("HiltC_Line%d__Neon_FF6A3CA" % i, [(0.101, z), (0.104, z + 0.005), (0.104, z + 0.025), (0.101, z + 0.03)], 6, smooth=False, offset=O, rot=math.pi / 6, caps=False)

# ================================================================ COLONNE (marbre cannele, chapiteau or) h=20
X = 0.0
O = (X, 0, 0)
lathe("Column_Base__Marble_E8E2D6", [(2.2, 0), (2.2, 0.6), (1.9, 0.7), (1.9, 1.1), (1.6, 1.3), (1.5, 1.5)], 4, smooth=False, offset=O, rot=math.pi / 4)
lathe("Column_Shaft__Marble_EFEAE0", [(1.35, 1.5), (1.33, 6.0), (1.27, 12.0), (1.18, 17.6)], 32, offset=O, rfunc=lambda k: 1.0 if k % 2 == 0 else 0.92)
lathe("Column_Capital__Metal_D4A64A", [(1.22, 17.6), (1.32, 17.7), (1.32, 18.0), (1.25, 18.1), (1.6, 18.6), (1.75, 18.9)], 24, offset=O)
lathe("Column_Abacus__Marble_E8E2D6", [(2.1, 18.9), (2.1, 19.6), (2.0, 20.0)], 4, smooth=False, offset=O, rot=math.pi / 4)
lathe("Column_Glow__Neon_5FE8FFA", [(1.3, 17.25), (1.34, 17.3), (1.34, 17.5), (1.3, 17.55)], 24, offset=O, caps=False)

# ================================================================ COLONNE BRISEE (ruines) h~9
X = 8.0
bm_prof = [(1.35, 0.0), (1.33, 5.0)]
ob = lathe("ColBroken_Shaft__Slate_7C8478", [(1.4, 0.0), (1.36, 4.0), (1.33, 8.0)], 20, offset=(X, 0, 0), rfunc=lambda k: 1.0 if k % 2 == 0 else 0.92)
for v in ob.data.vertices:
    if v.co.z > 7.9:
        v.co.z = 7.2 + random.uniform(0.0, 1.8)
lathe("ColBroken_Base__Slate_6A7268", [(2.0, 0), (2.0, 0.7), (1.7, 0.9), (1.5, 1.1)], 4, smooth=False, offset=(X, 0, 0), rot=math.pi / 4)

# ================================================================ ARCHE (arc brise, 16 large, ~24 haut)
X = 20.0
path = pointed_arch_path(7.0, 13.0, 1.6, 16, x0=X)
sweep("Arch_Body__Marble_E2DCCF", path, rect_section(2.4, 3.0), up=(0, 1, 0))
inner = offset_path(path, 1.26)
sweep("Arch_Glow__Neon_5FE8FFA", [(p[0], -1.0, p[2]) for p in inner], rect_section(0.2, 0.5), up=(0, 1, 0))
sweep("Arch_GlowBack__Neon_5FE8FFA", [(p[0], 1.0, p[2]) for p in inner], rect_section(0.2, 0.5), up=(0, 1, 0))
outer = offset_path(path, -1.32)
sweep("Arch_Trim__Metal_D4A64A", [(p[0], 0, p[2]) for p in outer], rect_section(0.3, 2.2), up=(0, 1, 0))
box("Arch_FootL__Marble_D6CFC0", (3.6, 4.0, 2.0), center=(X - 7.0, 0, 1.0), bevel=0.15)
box("Arch_FootR__Marble_D6CFC0", (3.6, 4.0, 2.0), center=(X + 7.0, 0, 1.0), bevel=0.15)
apex_z = path[len(path) // 2][2]
box("Arch_Key__Metal_D4A64A", (1.6, 3.4, 2.0), center=(X, 0, apex_z - 0.2), bevel=0.1)

# ================================================================ STATUE abstraite "Veilleur d'Ether"
X = 40.0
O = (X, 0, 0)
lathe("Statue_Plinth__Marble_2A2E3A", [(4.0, 0), (4.0, 0.8), (3.4, 1.0), (3.4, 2.4), (3.7, 2.6), (3.7, 3.0)], 8, smooth=False, offset=O, rot=math.pi / 8)
lathe("Statue_Spire__Basalt_1E2230", [(1.4, 3.0), (1.2, 4.0), (0.7, 8.0), (0.9, 10.0), (0.4, 13.0), (0.0, 15.5)], 6, smooth=False, offset=O)
lathe("Statue_Band__Metal_D4A64A", [(3.72, 2.62), (3.78, 2.66), (3.78, 2.94), (3.72, 2.98)], 8, smooth=False, offset=O, rot=math.pi / 8, caps=False)
for i, (ax, ang, R, zc) in enumerate((("X", 0.5, 4.2, 9.0), ("Y", -0.7, 3.4, 10.5), ("X", -1.1, 2.6, 12.0))):
    M = Matrix.Rotation(ang, 3, ax) @ Matrix.Rotation(i * 1.1, 3, 'Z')
    sweep("Statue_Ring%d__Metal_D4A64A" % i, circle_path(R, 40, 0.0, M, (X, 0, zc)), circ_section(0.16, 8), closed=True,
          up=tuple(M @ Vector((0, 0, 1))), shared=True)
sphere("Statue_Orb__Neon_7FF4FFA", 0.9, (X, 0, 16.6), 16, 10)

# ================================================================ POD de matchmaking (plateforme hexagonale + cage d'arceaux)
X = 62.0
O = (X, 0, 0)
lathe("Pod_Base__Metal_2B303A", [(7.0, 0), (7.0, 0.5), (6.6, 0.8), (6.0, 1.0), (0, 1.0)], 6, smooth=False, offset=O)
lathe("Pod_Inlay__Metal_C9CDD4", [(6.6, 0.8), (6.0, 1.0), (6.0, 1.04), (6.62, 0.84)], 6, smooth=False, offset=O, caps=False)
lathe("Pod_FloorRing__Neon_FFFFFFA", [(4.6, 1.02), (5.2, 1.02), (5.2, 1.08), (4.6, 1.08), (4.6, 1.02)], 36, smooth=False, offset=O, caps=False)
lathe("Pod_Disc__Glass_9AB8D8", [(0, 1.05), (4.5, 1.05), (4.5, 1.1), (0, 1.1)], 36, smooth=False, offset=O)
for i in range(3):
    a = 2 * math.pi * i / 3 + math.pi / 6
    pts = []
    for k in range(13):
        t = k / 12
        rr = 6.2 * math.cos(t * math.pi * 0.5) ** 0.7 + 0.8 * t
        zz = 1.0 + 11.0 * math.sin(t * math.pi * 0.5)
        pts.append((rr * math.cos(a), rr * math.sin(a), zz))
    sweep("Pod_Rib%d__Metal_C9CDD4" % i, [(X + p[0], p[1], p[2]) for p in pts], rect_section(0.6, 0.45),
          up=(-math.sin(a), math.cos(a), 0))
    pts2 = [(p[0] * 0.96, p[1] * 0.96, p[2]) for p in pts[:-1]]
    sweep("Pod_RibGlow%d__Neon_FFFFFFA" % i, [(X + p[0], p[1], p[2] - 0.05) for p in pts2], rect_section(0.2, 0.5),
          up=(-math.sin(a), math.cos(a), 0))
sweep("Pod_Crown__Metal_C9CDD4", circle_path(1.6, 24, 12.0, None, (X, 0, 0)), rect_section(0.5, 0.7), closed=True, up=(0, 0, 1))
sweep("Pod_CrownGlow__Neon_FFFFFFA", circle_path(1.6, 24, 11.5, None, (X, 0, 0)), circ_section(0.18, 6), closed=True, up=(0, 0, 1), shared=True)
lathe("Pod_Emitter__Metal_2B303A", [(0, 12.4), (0.8, 12.4), (0.6, 11.8), (0.3, 11.2), (0, 11.2)], 12, smooth=False, offset=O)

# ================================================================ AUTEL de relance (RerollShrine)
X = 82.0
O = (X, 0, 0)
lathe("Altar_Steps__Marble_E8E2D6", [(6.0, 0), (6.0, 0.6), (4.8, 0.6), (4.8, 1.2), (3.6, 1.2), (3.6, 1.8), (2.4, 1.8)], 8, smooth=False, offset=O, rot=math.pi / 8)
lathe("Altar_Pedestal__Basalt_1E2230", [(1.4, 1.8), (1.0, 2.2), (0.8, 3.6), (1.2, 4.0), (1.6, 4.3)], 8, smooth=False, offset=O, rot=math.pi / 8)
lathe("Altar_Bowl__Metal_D4A64A", [(1.6, 4.3), (1.9, 4.5), (2.0, 4.7), (1.75, 4.75), (1.5, 4.5), (0, 4.45)], 24, offset=O)
lathe("Altar_Trim__Neon_FFC850A", [(6.02, 0.5), (6.05, 0.52), (6.05, 0.58), (6.02, 0.6)], 8, smooth=False, offset=O, rot=math.pi / 8, caps=False)
for i in range(4):
    a = math.pi / 4 + i * math.pi / 2
    px, py = 4.2 * math.cos(a), 4.2 * math.sin(a)
    lathe("Altar_Post%d__Marble_D6CFC0" % i, [(0.45, 1.2), (0.35, 1.4), (0.3, 5.0), (0.45, 5.3), (0.2, 5.6)], 8, smooth=False, offset=(X + px, py, 0))
    lathe("Altar_PostTip%d__Neon_7FF4FFA" % i, [(0, 5.6), (0.2, 5.6), (0, 6.3)], 8, smooth=False, offset=(X + px, py, 0))

# ================================================================ CRISTAL unitaire (h=4), FRAGMENT de roche (r~2)
lathe("Crystal_Body__Glass_7FF4FF", [(0.0, 0.0), (0.42, 0.45), (0.6, 0.8), (0.55, 2.9), (0.0, 4.0)], 6, smooth=False, offset=(96, 0, 0))
lathe("Crystal2_Body__Glass_C88CFF", [(0.0, 0.0), (0.5, 0.3), (0.62, 1.8), (0.38, 3.2), (0.0, 3.6)], 5, smooth=False, offset=(100, 0, 0), sx=1.0, sy=0.8)
rock("Rock_A__Rock_6E6A66", 2.0, (106, 0, 0), 1)
rock("Rock2_A__Rock_6E6A66", 2.0, (112, 0, 0), 4, stretch=(1.4, 0.9, 0.7))

# ================================================================ OBELISQUE brise + eclat
X = 120.0
ob = lathe("Obelisk_Body__Slate_5E665E", [(1.6, 0.0), (1.6, 0.9), (1.3, 1.2), (1.1, 14.0)], 4, smooth=False, offset=(X, 0, 0), rot=math.pi / 4)
for v in ob.data.vertices:
    if v.co.z > 13.9:
        v.co.z = 11.5 + random.uniform(0.0, 2.6)
box("Obelisk_Rune__Neon_7FF4FFA", (0.45, 0.12, 3.6), center=(X, -0.84, 6.2))
ob = lathe("Shard_Body__Slate_5E665E", [(1.0, 0.0), (0.9, 4.5)], 4, smooth=False, offset=(X + 6, 0, 0), rot=math.pi / 4)
for v in ob.data.vertices:
    if v.co.z > 4.4:
        v.co.z = 3.0 + random.uniform(0.0, 1.8)
    elif v.co.z < 0.1:
        v.co.z = random.uniform(0.0, 0.6)

# ================================================================ ANNEAU generique (R=5, section 0.4)
sweep("Ring_Body__Metal_C9CDD4", circle_path(5.0, 48, 0.4, None, (136, 0, 0)), circ_section(0.4, 10), closed=True, up=(0, 0, 1), shared=True)

# ================================================================ ETABLI de lame (SaberBench)
X = 150.0
lathe("Bench_Top__Metal_2B303A", [(0, 3.0), (3.2, 3.0), (3.4, 3.2), (3.4, 3.5), (3.2, 3.6), (0, 3.6)], 4, smooth=False, offset=(X, 0, 0), rot=math.pi / 4, sx=1.0, sy=0.55)
lathe("Bench_Edge__Neon_7FF4FFA", [(3.41, 3.28), (3.42, 3.3), (3.42, 3.4), (3.41, 3.42)], 4, smooth=False, offset=(X, 0, 0), rot=math.pi / 4, sx=1.0, sy=0.55, caps=False)
lathe("Bench_Stand__Basalt_1E2230", [(1.6, 0), (1.6, 0.3), (0.9, 0.6), (0.7, 2.8), (1.4, 3.0)], 6, smooth=False, offset=(X, 0, 0), sx=1.4, sy=0.8)
lathe("Bench_Projector__Metal_D4A64A", [(0, 3.6), (0.9, 3.6), (0.9, 3.75), (0.6, 3.85), (0.5, 3.85), (0.5, 3.8), (0, 3.8)], 24, offset=(X, 0, 0))
lathe("Bench_Lens__Neon_7FF4FFA", [(0, 3.86), (0.48, 3.86), (0.45, 3.9), (0, 3.92)], 24, offset=(X, 0, 0))
for i in range(3):
    xx = X - 1.6 + i * 1.6
    ob = sweep("Bench_Cradle%d__Metal_C9CDD4" % i,
               [(xx - 0.25, 1.1, 3.6), (xx - 0.25, 1.1, 3.9), (xx + 0.25, 1.1, 3.9), (xx + 0.25, 1.1, 3.6)],
               rect_section(0.08, 0.12), up=(0, 1, 0))

# ================================================================ COUSSIN de meditation (lotus)
X = 162.0
lathe("Lotus_Pad__Marble_2A2E3A", [(2.6, 0), (2.6, 0.25), (2.2, 0.45), (0, 0.45)], 16, smooth=False, offset=(X, 0, 0))
lathe("Lotus_Ring__Neon_7FF4FFA", [(2.0, 0.46), (2.2, 0.46), (2.2, 0.5), (2.0, 0.5), (2.0, 0.46)], 32, smooth=False, offset=(X, 0, 0), caps=False)
for i in range(8):
    a = 2 * math.pi * i / 8
    pts = [(2.3, 0, 0.3), (2.9, 0, 0.9), (3.0, 0, 1.6)]
    ob = sweep("Lotus_Petal%d__Metal_D4A64A" % i, pts, rect_section(0.12, 0.7), up=(0, 1, 0))
    ob.data.transform(Matrix.Rotation(a, 4, 'Z'))
    ob.data.transform(Matrix.Translation((X, 0, 0)))

# ================================================================ BRASERO
X = 172.0
lathe("Brazier_Body__Metal_D4A64A", [(0.9, 0), (0.9, 0.2), (0.35, 0.4), (0.25, 2.8), (0.5, 3.0), (1.3, 3.4), (1.5, 3.8), (1.35, 3.85), (1.1, 3.5), (0, 3.4)], 12, smooth=False, offset=(X, 0, 0))
lathe("Brazier_Coals__Neon_FF8C3C", [(0, 3.5), (1.1, 3.5), (0.9, 3.65), (0, 3.7)], 12, smooth=False, offset=(X, 0, 0))

# ================================================================ FENETRE gothique (cadre + meneaux + rosace) 10 x ~18
X = 186.0
wpath = pointed_arch_path(5.0, 10.0, 1.6, 14, x0=X)
sweep("Window_Frame__Marble_E2DCCF", wpath, rect_section(0.9, 1.2), up=(0, 1, 0))
for xx in (-1.7, 1.7):
    sweep("Window_Mull%s__Marble_E2DCCF" % ("L" if xx < 0 else "R"), [(X + xx, 0, 0.0), (X + xx, 0, 10.0)], rect_section(0.45, 0.8), up=(0, 1, 0))
sweep("Window_Rose__Marble_E2DCCF", [(X + 1.7 * math.cos(a), 0, 13.2 + 1.7 * math.sin(a)) for a in [2 * math.pi * k / 24 for k in range(24)]],
      rect_section(0.4, 0.8), closed=True, up=(0, 1, 0))
sweep("Window_Transom__Marble_E2DCCF", [(X - 5.0, 0, 10.0), (X + 5.0, 0, 10.0)], rect_section(0.45, 0.8), up=(0, 1, 0))

# ================================================================ PYLONE de reacteur (bobine)
X = 200.0
lathe("Pylon_Base__Metal_3A4250", [(4.0, 0), (4.0, 1.0), (3.2, 1.6), (2.2, 2.0), (2.0, 8.0), (2.6, 8.6), (2.6, 9.4), (1.8, 9.8), (0, 9.8)], 12, smooth=False, offset=(X, 0, 0))
for i in range(4):
    sweep("Pylon_Coil%d__Metal_C9CDD4" % i, circle_path(2.35, 24, 2.9 + i * 1.35, None, (X, 0, 0)), rect_section(0.5, 0.7), closed=True, up=(0, 0, 1))
    sweep("Pylon_CoilGlow%d__Neon_5FE8FFA" % i, circle_path(2.05, 24, 3.5 + i * 1.35, None, (X, 0, 0)), circ_section(0.12, 6), closed=True, up=(0, 0, 1), shared=True)

# ================================================================ EXPORT
os.makedirs(EXPORT_DIR, exist_ok=True)
vl = scn.view_layers[0]
for o in scn.objects:
    o.select_set(o.name in created, view_layer=vl)
win = bpy.context.window_manager.windows[0]
with bpy.context.temp_override(window=win, scene=scn, view_layer=vl):
    bpy.ops.export_scene.fbx(filepath=EXPORT_PATH, use_selection=True, apply_scale_options='FBX_SCALE_ALL',
                             axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', use_mesh_modifiers=True,
                             object_types={'MESH'}, bake_space_transform=True)
tris = 0
for n in created:
    me = bpy.data.objects[n].data
    me.calc_loop_triangles()
    tris += len(me.loop_triangles)
result = {"objects": len(created), "tris": tris, "path": EXPORT_PATH}
