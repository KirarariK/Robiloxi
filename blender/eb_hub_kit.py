# Ether Blades - kit detaille du Hub v2 (colonnes ioniques, colonne brisee, arbres, iles flottantes,
# rambarde doree a arceaux, amphore, banniere, muret en ruine, brasero).
# Execution dans Blender :
#   exec(open(r"C:\Users\devaa\Desktop\robiloxiiiii\blender\eb_hub_kit.py", encoding="utf-8").read())
# Reutilise les primitives de eb_kit.py (lathe, sweep, box, sphere, rock...) dans une scene dediee "EB_HubKit",
# puis exporte C:\Users\devaa\Desktop\robiloxiiiii\exports\EB_HubKit.fbx
# Nommage : <Groupe>_<Piece>__<Materiau>_<HEX>  (lu par blender/eb_kit_import.lua, dossier Kit)
import math, os, random
from mathutils import Vector, Matrix, noise

_BASE = r"C:\Users\devaa\Desktop\robiloxiiiii\blender"
_src = open(os.path.join(_BASE, "eb_kit.py"), encoding="utf-8").read()
_src = _src.split("# ================================================================ REFERENCE")[0]
_src = _src.replace('"EB_Kit"', '"EB_HubKit"').replace('EB_Kit.fbx', 'EB_HubKit.fbx')
exec(_src)

random.seed(42)

MARBLE = "Limestone_EDE6D8"
MARBLE2 = "Limestone_D8CCB6"
GOLD = "SmoothPlastic_D69E2C"
BARK = "Wood_5E4532"
LEAF = "LeafyGrass_5E9A4A"
LEAF2 = "LeafyGrass_7DB25E"
ROCK = "Rock_8A7461"
ROCK2 = "Slate_6C5E52"
GRASS = "Grass_6C9A48"
NAVY = "Fabric_1E2E78"
ETHER = "Neon_50E6FFA"
CLAY = "Slate_9A6A4C"
MOSS = "Grass_5E8046"


def place(ob, x, y=0.0, z=0.0, rz=0.0):
    ob.data.transform(Matrix.Rotation(rz, 4, 'Z'))
    ob.data.transform(Matrix.Translation((x, y, z)))
    return ob


def fluted(k, n_flutes, depth):
    # 3 sommets par cannelure : bord, creux, bord
    return 1.0 - depth if k % 3 == 1 else 1.0


# ================================================================ COLONNE IONIQUE (20 studs)
def ionic_column(grp, X, H=20.0, R=1.0, broken_at=None):
    O = (X, 0, 0)
    box("%s_Plinth__%s" % (grp, MARBLE2), (2.9 * R, 2.9 * R, 0.6), center=(X, 0, 0.3), bevel=0.05)
    lathe("%s_Base__%s" % (grp, MARBLE), [(1.32 * R, 0.6), (1.38 * R, 0.75), (1.34 * R, 0.95), (1.18 * R, 1.05),
                                           (1.2 * R, 1.2), (1.24 * R, 1.35), (1.1 * R, 1.5), (1.02 * R, 1.6)], 40, offset=O)
    top = H - 3.0 if broken_at is None else broken_at
    segs = 60
    # fut cannele avec entasis (renflement leger)
    prof = []
    steps = 10
    for i in range(steps + 1):
        t = i / steps
        z = 1.6 + (top - 1.6) * t
        r = R * (1.0 + 0.04 * math.sin(math.pi * t * 0.8) - 0.08 * t)
        prof.append((r, z))
    lathe("%s_Shaft__%s" % (grp, MARBLE), prof, segs, rfunc=lambda k: fluted(k, 20, 0.07), offset=O, caps=broken_at is not None)
    if broken_at is not None:
        # cassure : eclats irreguliers et mousse
        for i in range(5):
            a = 2 * math.pi * i / 5 + random.uniform(-0.3, 0.3)
            ob = rock("%s_Shard%d__%s" % (grp, i, MARBLE), 0.45 * R, (X + math.cos(a) * 0.45 * R, math.sin(a) * 0.45 * R, top - 0.1), i + 3,
                      stretch=(1.0, 1.0, random.uniform(0.8, 1.6)))
        lathe("%s_Moss__%s" % (grp, MOSS), [(0, top + 0.02), (0.95 * R, top + 0.02), (0.9 * R, top + 0.15), (0, top + 0.18)], 18,
              rfunc=lambda k: 1.0 + 0.12 * math.sin(k * 1.7), offset=O)
        for i in range(3):
            a = random.uniform(0, 2 * math.pi)
            d = random.uniform(2.2, 3.6) * R
            rock("%s_Debris%d__%s" % (grp, i, MARBLE2), 0.7 * R, (X + math.cos(a) * d, math.sin(a) * d, 0), i + 11, stretch=(1.4, 1.0, 0.8))
        return
    # chapiteau ionique : astragale, filet dore, echine, abaque, volutes en spirale
    lathe("%s_Astragal__%s" % (grp, MARBLE2), [(0.95 * R, top), (1.02 * R, top + 0.1), (1.02 * R, top + 0.25), (0.95 * R, top + 0.35)], 40, offset=O, caps=False)
    lathe("%s_Neck__%s" % (grp, GOLD), [(0.96 * R, top + 0.35), (0.98 * R, top + 0.4), (0.98 * R, top + 0.55), (0.96 * R, top + 0.6)], 40, offset=O, caps=False)
    lathe("%s_Echinus__%s" % (grp, MARBLE), [(0.96 * R, top + 0.6), (1.25 * R, top + 0.9), (1.42 * R, top + 1.3), (1.38 * R, top + 1.5), (0, top + 1.5)], 40, offset=O)
    box("%s_Abacus__%s" % (grp, MARBLE2), (3.0 * R, 2.3 * R, 0.5), center=(X, 0, top + 1.75), bevel=0.06)
    box("%s_Cushion__%s" % (grp, MARBLE), (3.2 * R, 1.6 * R, 0.6), center=(X, 0, top + 1.25), bevel=0.15)
    for side in (-1, 1):
        # spirale d'Archimede dans le plan XZ, de chaque cote
        pts = []
        turns = 2.2
        for i in range(48):
            t = i / 47
            a = turns * 2 * math.pi * t
            r = 0.75 * R * (1 - t * 0.85)
            pts.append((X + side * (1.55 * R - r * math.cos(a) * 0.9), 0, top + 1.05 - r * math.sin(a)))
        for y in (-0.7 * R, 0.7 * R):
            sweep("%s_Volute%s%s__%s" % (grp, "L" if side < 0 else "R", "F" if y < 0 else "B", MARBLE),
                  [(p[0], y, p[2]) for p in pts], circ_section(0.12 * R, 6), up=(0, 1, 0), shared=True)
        ob = lathe("%s_Eye%s__%s" % (grp, "L" if side < 0 else "R", GOLD), [(0, -0.75 * R), (0.16 * R, -0.75 * R), (0.16 * R, 0.75 * R), (0, 0.75 * R)], 12)
        ob.data.transform(Matrix.Rotation(math.pi / 2, 4, 'X'))
        ob.data.transform(Matrix.Translation((X + side * 1.55 * R, 0, top + 1.05)))
    # lierre grimpant
    for i in range(3):
        a = random.uniform(0, 2 * math.pi)
        z0 = random.uniform(2.5, top * 0.5)
        path = [(X + math.cos(a + 0.25 * j) * 1.03 * R, math.sin(a + 0.25 * j) * 1.03 * R, z0 + j * 0.9) for j in range(6)]
        sweep("%s_Ivy%d__%s" % (grp, i, MOSS), path, rect_section(0.22, 0.05), up=(0, 0, 1))
        for j in range(5):
            p = path[j]
            sphere("%s_IvyLeaf%d_%d__%s" % (grp, i, j, LEAF), 0.22, (p[0], p[1], p[2] + 0.4), segs=6, rings=4)


ionic_column("HColumn", 0.0)
ionic_column("HColBroken", 12.0, broken_at=7.0)


# ================================================================ ARBRES (2 variantes)
def tree(grp, X, h=12.0, seed=1):
    random.seed(seed)
    # tronc en segments coniques legerement tordus
    pts = [(X, 0, 0)]
    for i in range(1, 6):
        pts.append((X + math.sin(i * 0.9 + seed) * 0.5, math.cos(i * 0.7 + seed) * 0.4, h * i / 5))
    radii = [1.0, 0.85, 0.7, 0.55, 0.45, 0.35]
    for i in range(5):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        prof = [(radii[i], 0), (radii[i + 1], (b - a).length)]
        ob = lathe("%s_Trunk%d__%s" % (grp, i, BARK), prof, 10, rfunc=lambda k: 1.0 + 0.08 * math.sin(k * 2.3))
        d = (b - a).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        ob.data.transform(rot)
        ob.data.transform(Matrix.Translation(a))
    # racines
    for i in range(4):
        a = i * math.pi / 2 + seed
        sweep("%s_Root%d__%s" % (grp, i, BARK), [(X, 0, 1.2), (X + math.cos(a) * 1.4, math.sin(a) * 1.4, 0.3), (X + math.cos(a) * 2.2, math.sin(a) * 2.2, -0.1)],
              circ_section(0.3, 6), up=(0, 0, 1), shared=True)
    # branches + feuillage en masses irregulieres
    blobs = []
    for i in range(5):
        a = i * 2 * math.pi / 5 + random.uniform(-0.3, 0.3)
        z = h * random.uniform(0.55, 0.85)
        L = random.uniform(3.0, 4.5)
        tip = (X + math.cos(a) * L, math.sin(a) * L, z + random.uniform(1.0, 2.5))
        sweep("%s_Branch%d__%s" % (grp, i, BARK), [(X, 0, z - 1), (X + math.cos(a) * L * 0.5, math.sin(a) * L * 0.5, z + 0.3), tip],
              circ_section(0.22, 6), up=(0, 0, 1), shared=True)
        blobs.append((tip, random.uniform(2.2, 3.0)))
    blobs.append(((X, 0, h + 1.5), 3.6))
    blobs.append(((X + 1.5, 1.2, h + 0.5), 2.8))
    blobs.append(((X - 1.4, -1.0, h + 0.8), 3.0))
    for i, (c, r) in enumerate(blobs):
        rock("%s_Leaves%d__%s" % (grp, i, LEAF if i % 2 == 0 else LEAF2), r, (c[0], c[1], c[2] - r * 0.35), seed * 10 + i, flat_bottom=False, stretch=(1.15, 1.15, 0.9))


tree("HTree", 30.0, 12.0, 1)
tree("HTree2", 46.0, 10.0, 7)


# ================================================================ ILE FLOTTANTE (dessus plat herbeux, dessous effile)
def island(grp, X, R=10.0, seed=3):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=R)
    off = Vector((seed * 2.1, seed * 1.3, seed * 0.7))
    for v in bm.verts:
        n = noise.noise(v.co * (1.4 / R) + off)
        n2 = noise.noise(v.co * (3.5 / R) + off * 2)
        if v.co.z > 0:
            v.co.z = R * 0.05 * n2
            v.co.x *= 1.0 + 0.12 * n
            v.co.y *= 1.0 + 0.12 * n
        else:
            k = -v.co.z / R
            v.co.x *= (1.0 - 0.55 * k) * (1 + 0.25 * n)
            v.co.y *= (1.0 - 0.55 * k) * (1 + 0.25 * n)
            v.co.z *= 1.9 + 0.5 * n2
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((X, 0, 0)))
    finish(bm, "%s_Rock__%s" % (grp, ROCK), False)
    # bandes de strates sous le rebord
    lathe("%s_Strata__%s" % (grp, ROCK2), [(R * 0.98, -0.6), (R * 1.0, -1.2), (R * 0.9, -2.4)], 36,
          rfunc=lambda k: 1.0 + 0.1 * math.sin(k * 1.3 + seed), offset=(X, 0, 0), caps=False)
    # tapis d'herbe au bord irregulier
    lathe("%s_Grass__%s" % (grp, GRASS), [(0, 0.35), (R * 0.97, 0.35), (R * 1.02, 0.0), (R * 0.98, -0.45)], 36,
          rfunc=lambda k: 1.0 + 0.07 * math.sin(k * 2.7 + seed) + 0.04 * math.sin(k * 5.1), offset=(X, 0, 0))
    # rochers moussus poses dessus
    for i in range(4):
        a = random.uniform(0, 2 * math.pi)
        d = random.uniform(0.4, 0.8) * R
        rock("%s_Boulder%d__%s" % (grp, i, ROCK), random.uniform(0.6, 1.2), (X + math.cos(a) * d, math.sin(a) * d, 0.35), seed + i)
    # cristaux d'ether pendants
    for i in range(3):
        a = random.uniform(0, 2 * math.pi)
        d = random.uniform(0.1, 0.35) * R
        z = -R * random.uniform(1.0, 1.5)
        lathe("%s_Hang%d__%s" % (grp, i, ETHER), [(0, z - 2.5), (0.45, z - 0.8), (0.35, z), (0, z + 0.1)], 6, smooth=False,
              offset=(X + math.cos(a) * d, math.sin(a) * d, 0))


island("HIsland", 80.0, 10.0, 3)
island("HIsland2", 110.0, 7.0, 9)


# ================================================================ RAMBARDE DOREE A ARCEAUX (segment courbe, rayon 20.4, 1/14 de tour)
def rail(grp, X, R=20.4, frac=1 / 14):
    a0, a1 = -math.pi * frac, math.pi * frac
    n = 12
    arc = lambda r, z: [(X + r * math.sin(a0 + (a1 - a0) * i / n), R - r * math.cos(a0 + (a1 - a0) * i / n), z) for i in range(n + 1)]
    sweep("%s_Base__%s" % (grp, MARBLE2), arc(R, 0.3), rect_section(1.0, 0.6), up=(0, 0, 1))
    sweep("%s_Top__%s" % (grp, GOLD), arc(R, 3.7), circ_section(0.16, 8), up=(0, 0, 1), shared=True)
    sweep("%s_Mid__%s" % (grp, GOLD), arc(R, 1.0), circ_section(0.09, 6), up=(0, 0, 1), shared=True)
    for s in (a0, a1):
        x, y = X + R * math.sin(s), R - R * math.cos(s)
        lathe("%s_Post%s__%s" % (grp, "L" if s < 0 else "R", GOLD), [(0.2, 0.6), (0.2, 3.6), (0.3, 3.75), (0.3, 4.0), (0, 4.2)], 10, offset=(x, y, 0))
    # arceaux (demi-cercles) et petites volutes
    for j in range(2):
        b0 = a0 + (a1 - a0) * j / 2
        b1 = a0 + (a1 - a0) * (j + 1) / 2
        pts = []
        for i in range(13):
            t = i / 12
            b = b0 + (b1 - b0) * t
            z = 1.0 + math.sin(math.pi * t) * 2.4
            pts.append((X + R * math.sin(b), R - R * math.cos(b), z))
        sweep("%s_Arc%d__%s" % (grp, j, GOLD), pts, circ_section(0.08, 6), up=(0, 0, 1), shared=True)


rail("HRail", 140.0)


# ================================================================ AMPHORE
lathe("HUrn_Body__%s" % CLAY, [(0, 0), (0.55, 0), (0.6, 0.15), (0.5, 0.35), (0.9, 0.9), (1.2, 1.6), (1.15, 2.2), (0.85, 2.7),
                               (0.5, 3.0), (0.42, 3.5), (0.62, 3.7), (0.6, 3.85), (0.4, 3.8), (0, 3.6)], 28, offset=(160, 0, 0))
lathe("HUrn_Band__%s" % GOLD, [(1.17, 1.75), (1.22, 1.8), (1.22, 1.95), (1.17, 2.0)], 28, offset=(160, 0, 0), caps=False)
for s in (-1, 1):
    sweep("HUrn_Handle%s__%s" % ("L" if s < 0 else "R", CLAY), [(160 + s * 0.45, 0, 3.35), (160 + s * 1.05, 0, 3.4), (160 + s * 1.15, 0, 2.8), (160 + s * 0.95, 0, 2.4)],
          circ_section(0.1, 6), up=(0, 1, 0), shared=True)


# ================================================================ BANNIERE (mat, traverse, etoffe ondulee, embleme)
def banner(grp, X, h=18.0):
    lathe("%s_Pole__%s" % (grp, BARK), [(0.25, 0), (0.25, h), (0, h)], 10, offset=(X, 0, 0))
    lathe("%s_Tip__%s" % (grp, GOLD), [(0.3, h), (0.35, h + 0.3), (0, h + 1.6)], 8, offset=(X, 0, 0))
    sweep("%s_Bar__%s" % (grp, GOLD), [(X - 2.8, -0.35, h - 0.8), (X + 2.8, -0.35, h - 0.8)], circ_section(0.13, 8), up=(0, 1, 0), shared=True)
    # etoffe : grille ondulee avec pointe basse
    bm = bmesh.new()
    W, Hc, nx, nz = 5.0, 9.0, 10, 18
    grid = []
    for j in range(nz + 1):
        row = []
        for i in range(nx + 1):
            u = i / nx
            v = j / nz
            x = (u - 0.5) * W
            z = h - 1.0 - v * Hc
            if v > 0.82:
                z -= (1 - abs(u - 0.5) * 2) * (v - 0.82) / 0.18 * 1.6
            y = -0.45 - 0.18 * math.sin(u * 4.5 + v * 2) * v
            row.append(bm.verts.new((X + x, y, z)))
        grid.append(row)
    for j in range(nz):
        for i in range(nx):
            f = bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]))
            f.smooth = True
    # face arriere (double face) : on duplique en inversant
    for j in range(nz):
        for i in range(nx):
            vs = [grid[j][i + 1].co.copy(), grid[j + 1][i + 1].co.copy(), grid[j + 1][i].co.copy(), grid[j][i].co.copy()]
            f = bm.faces.new([bm.verts.new(c + Vector((0, 0.04, 0))) for c in vs])
            f.smooth = True
    finish(bm, "%s_Cloth__%s" % (grp, NAVY), None)
    sweep("%s_Trim__%s" % (grp, GOLD), [(X - 2.5, -0.5, h - 1.25), (X + 2.5, -0.5, h - 1.25)], rect_section(0.25, 0.06), up=(0, 1, 0))
    for s in (-1, 1):
        ob = box("%s_Blade%s__%s" % (grp, "L" if s < 0 else "R", ETHER), (0.22, 0.06, 4.6), center=(0, 0, 0))
        ob.data.transform(Matrix.Rotation(s * math.radians(32), 4, 'Y'))
        ob.data.transform(Matrix.Translation((X, -0.62, h - 5.4)))
        ob = box("%s_Guard%s__%s" % (grp, "L" if s < 0 else "R", GOLD), (0.8, 0.07, 0.18), center=(0, 0, 0))
        ob.data.transform(Matrix.Translation((0, 0, -2.0)))
        ob.data.transform(Matrix.Rotation(s * math.radians(32), 4, 'Y'))
        ob.data.transform(Matrix.Translation((X, -0.63, h - 5.4)))
    ob = box("%s_Gem__%s" % (grp, GOLD), (0.8, 0.08, 0.8), center=(0, 0, 0))
    ob.data.transform(Matrix.Rotation(math.radians(45), 4, 'Y'))
    ob.data.transform(Matrix.Translation((X, -0.64, h - 2.9)))


banner("HBanner", 175.0)


# ================================================================ MURET EN RUINE (12 studs)
def ruin_wall(grp, X, L=12.0, seed=5):
    random.seed(seed)
    x = -L / 2
    i = 0
    while x < L / 2:
        w = random.uniform(2.2, 3.4)
        rows = random.randint(1, 3)
        for r in range(rows):
            if r > 0 and random.random() < 0.2:
                continue
            bh = random.uniform(1.5, 2.0)
            ob = box("%s_Block%d__%s" % (grp, i, "Limestone_A89E88" if (i % 3) else "Limestone_BFB49C"), (w - 0.15, random.uniform(2.0, 2.6), bh),
                     center=(0, 0, 0), bevel=0.12)
            ob.data.transform(Matrix.Rotation(random.uniform(-0.05, 0.05), 4, 'Z'))
            ob.data.transform(Matrix.Translation((X + x + w / 2, random.uniform(-0.2, 0.2), bh / 2 + r * 1.85)))
            if r == rows - 1 and random.random() < 0.75:
                rock("%s_Moss%d__%s" % (grp, i, MOSS), w * 0.35, (X + x + w / 2, 0, bh + r * 1.85 - 0.25), i, stretch=(1.2, 0.8, 0.25))
            i += 1
        x += w


ruin_wall("HWall", 195.0)


# ================================================================ BRASERO D'ETHER
lathe("HBrazier_Stand__%s" % GOLD, [(1.4, 0), (1.4, 0.3), (0.9, 0.5), (0.35, 0.8), (0.3, 3.0), (0.5, 3.2), (0.4, 3.4)], 24, offset=(215, 0, 0))
lathe("HBrazier_Bowl__%s" % GOLD, [(0.4, 3.4), (1.2, 3.6), (1.7, 4.1), (1.8, 4.5), (1.65, 4.55), (1.2, 4.2), (0, 4.15)], 28, offset=(215, 0, 0))
for i in range(4):
    a = i * math.pi / 2
    sweep("HBrazier_Leg%d__%s" % (i, GOLD), [(215 + math.cos(a) * 0.35, math.sin(a) * 0.35, 1.2), (215 + math.cos(a) * 1.1, math.sin(a) * 1.1, 2.6),
                                              (215 + math.cos(a) * 1.6, math.sin(a) * 1.6, 4.2)], circ_section(0.08, 6), up=(0, 0, 1), shared=True)
lathe("HBrazier_Flame__%s" % ETHER, [(0, 4.2), (1.3, 4.2), (0.9, 4.9), (0.4, 5.8), (0, 6.6)], 10, smooth=True, offset=(215, 0, 0),
      rfunc=lambda k: 1.0 + 0.25 * math.sin(k * 2.0))

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
