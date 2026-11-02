"""
sbm_common.py — noyau partagé des générateurs Syndicate Black Market.

Chaque asset est décrit UNE fois en coordonnées Roblox (studs, Y vers le haut,
Nord = -Z) sous forme de primitives (Box, Cyl, Wedge, Ball) et de marqueurs
(connecteurs, spawns, terminaux...). À partir de cette description :
  1. Blender construit des meshes détaillés (chanfreins bmesh, panneaux en inset,
     cylindres octogonaux), fusionnés par matériau, et exporte un FBX par asset ;
  2. un module Luau --!strict est généré dans src/server/Prefabs/Data/ pour que
     ProceduralPrefabBuilder assemble les mêmes modèles en Parts dans Studio.

Conventions :
  * 1 unité Blender = 1 stud ; unit_settings.scale_length = 1.0.
  * Pivot de chaque asset = (0, 0, 0) = centre du sol de la salle (Y/Z = 0).
  * Conversion Roblox -> Blender : (x, y, z) -> (x, -z, y).
  * Rotation (rx, ry, rz) en degrés = CFrame.fromOrientation (ordre Y * X * Z).
  * Cylindres : axe local X (comme Roblox).
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
EXPORT_DIR = os.path.join(PROJECT_DIR, "exports_fbx")
LUAU_DATA_DIR = os.path.join(PROJECT_DIR, "src", "server", "Prefabs", "Data")

# Drapeaux (bitmask) partagés avec PrefabTypes.luau
NO_COLLIDE = 1
LIGHT = 2
BREAKABLE = 4
NO_QUERY = 8
BEAM = 16

# --------------------------------------------------------------------------
# Matériaux : (base sRGB hex, metallic, roughness, emission strength, alpha,
#              matériau Roblox, réflectance Roblox)
# --------------------------------------------------------------------------
MATERIALS = {
    "DarkMetal": ("#1A1D24", 0.85, 0.25, 0.0, 1.0, "DiamondPlate", 0.12),
    "ConcreteFloor": ("#26282E", 0.0, 0.80, 0.0, 1.0, "Concrete", 0.0),
    "CarbonFiber": ("#111215", 0.40, 0.35, 0.0, 1.0, "Metal", 0.05),
    "NeonCyan": ("#00F0FF", 0.0, 0.50, 5.0, 1.0, "Neon", 0.0),
    "NeonCrimson": ("#FF003C", 0.0, 0.50, 6.0, 1.0, "Neon", 0.0),
    "NeonGold": ("#FFD700", 1.00, 0.10, 0.0, 1.0, "Foil", 0.35),
    "NeonGreen": ("#38FF8C", 0.0, 0.50, 4.0, 1.0, "Neon", 0.0),
    "NeonBlue": ("#2E6BFF", 0.0, 0.50, 5.0, 1.0, "Neon", 0.0),
    "ConcreteWall": ("#3A3D44", 0.0, 0.90, 0.0, 1.0, "Concrete", 0.0),
    "SteelPanel": ("#2C313B", 0.80, 0.35, 0.0, 1.0, "Metal", 0.08),
    "Rubber": ("#0A0A0C", 0.0, 0.90, 0.0, 1.0, "SmoothPlastic", 0.0),
    "Glass": ("#9FE8FF", 0.0, 0.05, 0.0, 0.35, "Glass", 0.2),
    "HoloCyan": ("#00F0FF", 0.0, 0.20, 3.0, 0.45, "Neon", 0.0),
    "LaserRed": ("#FF003C", 0.0, 0.20, 8.0, 0.40, "Neon", 0.0),
    "CashGreen": ("#3E7B4A", 0.0, 0.70, 0.0, 1.0, "Fabric", 0.0),
    "Fabric": ("#22262E", 0.0, 0.95, 0.0, 1.0, "Fabric", 0.0),
    "Wood": ("#3B2A20", 0.0, 0.60, 0.0, 1.0, "WoodPlanks", 0.0),
    "VanPaint": ("#1F242C", 0.70, 0.30, 0.0, 1.0, "Metal", 0.1),
    "Grate": ("#4A505C", 0.90, 0.40, 0.0, 1.0, "DiamondPlate", 0.1),
}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# --------------------------------------------------------------------------
# Description d'asset
# --------------------------------------------------------------------------
class Asset:
    def __init__(self, name, category, bounds, attributes=None, folder=None):
        self.name = name
        self.category = category  # Room | Cap | Hub | Prop | Loot | Weapon | Tool
        self.bounds = bounds  # (x, y, z) taille de la boîte englobante en studs
        self.attributes = dict(attributes or {})
        self.folder = folder or {
            "Room": "RoomModules", "Cap": "RoomModules", "Hub": "Hub",
            "Prop": "Props", "Loot": "Loot", "Weapon": "Weapons", "Tool": "Weapons",
        }[category]
        self.parts = []
        self.markers = []
        self._counter = {}

    def _name(self, base):
        n = self._counter.get(base, 0) + 1
        self._counter[base] = n
        return base if n == 1 else f"{base}_{n}"

    # ---- primitives -------------------------------------------------------
    def part(self, kind, name, mat, pos, size, rot=(0, 0, 0), flags=0, bevel=None,
             panels=False, sides=16, group=None):
        assert mat in MATERIALS, mat
        if bevel is None:
            bevel = kind == "Box" and min(size) >= 0.4
        self.parts.append({
            "kind": kind, "name": self._name(name), "mat": mat,
            "pos": tuple(float(v) for v in pos), "size": tuple(float(v) for v in size),
            "rot": tuple(float(v) for v in rot), "flags": flags, "bevel": bevel,
            "panels": panels, "sides": sides, "group": group,
        })

    def box(self, name, mat, pos, size, rot=(0, 0, 0), flags=0, **kw):
        self.part("Box", name, mat, pos, size, rot, flags, **kw)

    def cyl(self, name, mat, pos, length, diameter, rot=(0, 0, 0), flags=0, sides=16, **kw):
        self.part("Cyl", name, mat, pos, (length, diameter, diameter), rot, flags, sides=sides, **kw)

    def vcyl(self, name, mat, pos, height, diameter, flags=0, sides=16, **kw):
        """Cylindre vertical (axe Y) : axe X tourné de 90° autour de Z."""
        self.part("Cyl", name, mat, pos, (height, diameter, diameter), (0, 0, 90), flags, sides=sides, **kw)

    def wedge(self, name, mat, pos, size, rot=(0, 0, 0), flags=0, **kw):
        self.part("Wedge", name, mat, pos, size, rot, flags, **kw)

    def ball(self, name, mat, pos, diameter, flags=0, **kw):
        self.part("Ball", name, mat, pos, (diameter, diameter, diameter), (0, 0, 0), flags, **kw)

    def detail(self, name, mat, pos, size, rot=(0, 0, 0), **kw):
        """Petit élément décoratif sans collision ni requête."""
        self.box(name, mat, pos, size, rot, NO_COLLIDE | NO_QUERY, bevel=False, **kw)

    def neon_strip(self, name, mat, pos, size, rot=(0, 0, 0), light=False):
        self.box(name, mat, pos, size, rot, NO_COLLIDE | NO_QUERY | (LIGHT if light else 0), bevel=False)

    # ---- marqueurs --------------------------------------------------------
    def marker(self, kind, name, pos, rot=(0, 0, 0), size=(1, 1, 1), attrs=None):
        self.markers.append({
            "kind": kind, "name": name, "pos": tuple(float(v) for v in pos),
            "rot": tuple(float(v) for v in rot), "size": tuple(float(v) for v in size),
            "attrs": dict(attrs or {}),
        })


# --------------------------------------------------------------------------
# Géométrie Blender
# --------------------------------------------------------------------------
RBX_TO_BL = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def rbx_rotation(rot):
    rx, ry, rz = (math.radians(a) for a in rot)
    return Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(rz, 3, "Z")


def _wedge(bm, sx, sy, sz):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    v = [bm.verts.new(p) for p in (
        (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
        (-hx, hy, hz), (hx, hy, hz))]
    for f in ((0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)):
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def build_part_bmesh(p):
    bm = bmesh.new()
    sx, sy, sz = p["size"]
    kind = p["kind"]
    if kind == "Box":
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
        if p["panels"]:
            # Panneaux de mur : inset des grandes faces puis léger enfoncement.
            big = [f for f in bm.faces if f.calc_area() > 16.0]
            if big:
                bmesh.ops.inset_individual(bm, faces=big, thickness=0.35, depth=-0.06)
        if p["bevel"]:
            amount = min(0.12, min(sx, sy, sz) * 0.2)
            edges = [e for e in bm.edges if not e.is_wire]
            bmesh.ops.bevel(bm, geom=edges, offset=amount, segments=2, profile=0.5, affect="EDGES",
                            clamp_overlap=True)
    elif kind == "Cyl":
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=p["sides"],
                              radius1=0.5, radius2=0.5, depth=1.0)
        to_x = Matrix.Rotation(math.radians(90), 3, "Y")
        for v in bm.verts:
            c = to_x @ v.co
            v.co = Vector((c.x * sx, c.y * sy, c.z * sz))
        if p["sides"] <= 8 and min(sx, sy) >= 0.6:
            caps = [e for e in bm.edges if len(e.link_faces) == 2
                    and any(len(f.verts) > 4 for f in e.link_faces)]
            bmesh.ops.bevel(bm, geom=caps, offset=min(0.08, sy * 0.08), segments=1, affect="EDGES",
                            clamp_overlap=True)
    elif kind == "Wedge":
        _wedge(bm, sx, sy, sz)
    elif kind == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.5)
        for v in bm.verts:
            v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    else:
        raise ValueError(kind)
    rot = rbx_rotation(p["rot"])
    pos = Vector(p["pos"])
    for v in bm.verts:
        v.co = RBX_TO_BL @ (rot @ v.co + pos)
    return bm


def ensure_material(key):
    name = "Mat_" + key
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    hx, metallic, rough, emission, alpha, _, _ = MATERIALS[key]
    r, g, b = (srgb_to_linear(c) for c in hex_rgb(hx))
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Alpha"].default_value = alpha
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (r, g, b, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    else:
        bsdf.inputs["Emission Strength"].default_value = 0.0
    mat.diffuse_color = (r, g, b, alpha)
    if alpha < 1.0:
        try:
            mat.surface_render_method = "BLENDED"
        except AttributeError:
            pass
    return mat


def get_scene(name):
    scene = bpy.data.scenes.get(name)
    if scene is None:
        scene = bpy.data.scenes.new(name)
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    bpy.context.window.scene = scene
    return scene


def clear_scene(scene):
    for obj in list(scene.collection.all_objects):
        data = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    for coll in list(scene.collection.children):
        bpy.data.collections.remove(coll)


def build_asset_in_blender(scene, asset, offset):
    coll = bpy.data.collections.new(asset.name)
    scene.collection.children.link(coll)
    root = bpy.data.objects.new(asset.name, None)
    root.empty_display_type = "CUBE"
    root.empty_display_size = 0.5
    root.location = offset
    coll.objects.link(root)

    groups = {}
    for p in asset.parts:
        key = (p["group"] or "", p["mat"])
        groups.setdefault(key, []).append(p)

    tmp = bpy.data.meshes.new("_sbm_tmp")
    for (group, mat_key), parts in groups.items():
        bm = bmesh.new()
        for p in parts:
            pb = build_part_bmesh(p)
            pb.to_mesh(tmp)
            pb.free()
            bm.from_mesh(tmp)
        obj_name = f"{asset.name}__{group + '_' if group else ''}{mat_key}"
        mesh = bpy.data.meshes.new(obj_name)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(ensure_material(mat_key))
        for poly in mesh.polygons:
            poly.use_smooth = False
        obj = bpy.data.objects.new(obj_name, mesh)
        obj.parent = root
        coll.objects.link(obj)
    bpy.data.meshes.remove(tmp)

    for m in asset.markers:
        e = bpy.data.objects.new(f"{asset.name}__{m['name']}", None)
        e.empty_display_type = "ARROWS" if m["kind"] in ("Connector", "Grip", "Muzzle") else "PLAIN_AXES"
        e.empty_display_size = 1.0
        mat = RBX_TO_BL @ rbx_rotation(m["rot"])
        e.matrix_basis = Matrix.Translation(RBX_TO_BL @ Vector(m["pos"])) @ mat.to_4x4()
        e["sbm_kind"] = m["kind"]
        e.parent = root
        coll.objects.link(e)
    root["sbm_category"] = asset.category
    root["sbm_bounds"] = [float(v) for v in asset.bounds]
    return root, coll


def export_asset_fbx(root, coll, subdir):
    out_dir = os.path.join(EXPORT_DIR, subdir)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, root.name + ".fbx")
    saved = root.location.copy()
    root.location = (0, 0, 0)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in coll.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"EMPTY", "MESH"},
        global_scale=0.01, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z", axis_up="Y", bake_space_transform=False,
        mesh_smooth_type="FACE", add_leaf_bones=False, use_custom_props=True, path_mode="AUTO")
    root.location = saved
    bpy.ops.object.select_all(action="DESELECT")
    return path


# --------------------------------------------------------------------------
# Émission Luau
# --------------------------------------------------------------------------
def _num(v):
    r = round(v, 3)
    if r == int(r):
        return str(int(r))
    return repr(r)


def _v3(t):
    return f"V({_num(t[0])}, {_num(t[1])}, {_num(t[2])})"


def _lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return _num(v)
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


def _attrs(d):
    if not d:
        return "nil"
    return "{ " + ", ".join(f"{k} = {_lua_value(v)}" for k, v in sorted(d.items())) + " }"


def write_luau_group(module_name, script_name, assets):
    os.makedirs(LUAU_DATA_DIR, exist_ok=True)
    lines = [
        "--!strict",
        f"-- GÉNÉRÉ AUTOMATIQUEMENT par blender_scripts/{script_name} — ne pas modifier à la main.",
        "-- Coordonnées en studs, pivot = centre du sol, rotations = CFrame.fromOrientation (degrés).",
        "",
        "local PrefabTypes = require(script.Parent.Parent.PrefabTypes)",
        "",
        "type AssetDefinition = PrefabTypes.AssetDefinition",
        "",
        "local V = Vector3.new",
        "local P = PrefabTypes.part",
        "local M = PrefabTypes.marker",
        "",
        "local assets: { AssetDefinition } = {",
    ]
    for a in assets:
        lines.append("\t{")
        lines.append(f'\t\tName = "{a.name}",')
        lines.append(f'\t\tCategory = "{a.category}",')
        lines.append(f'\t\tFolder = "{a.folder}",')
        lines.append(f"\t\tBounds = {_v3(a.bounds)},")
        lines.append(f"\t\tAttributes = {_attrs(a.attributes)},")
        lines.append("\t\tParts = {")
        for p in a.parts:
            group = f', "{p["group"]}"' if p["group"] else ""
            lines.append(
                f'\t\t\tP("{p["kind"]}", "{p["name"]}", "{p["mat"]}", {_v3(p["pos"])}, {_v3(p["size"])}, '
                f'{_v3(p["rot"])}, {p["flags"]}{group}),')
        lines.append("\t\t},")
        lines.append("\t\tMarkers = {")
        for m in a.markers:
            lines.append(
                f'\t\t\tM("{m["kind"]}", "{m["name"]}", {_v3(m["pos"])}, {_v3(m["rot"])}, {_v3(m["size"])}, '
                f'{_attrs(m["attrs"])}),')
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    lines.append("return table.freeze(assets)")
    lines.append("")
    path = os.path.join(LUAU_DATA_DIR, module_name + ".luau")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    return path


def write_luau_materials():
    os.makedirs(LUAU_DATA_DIR, exist_ok=True)
    lines = [
        "--!strict",
        "-- GÉNÉRÉ AUTOMATIQUEMENT par blender_scripts/sbm_common.py — ne pas modifier à la main.",
        "-- Équivalents Studio des matériaux PBR Blender.",
        "",
        "local PrefabTypes = require(script.Parent.Parent.PrefabTypes)",
        "",
        "type MaterialDefinition = PrefabTypes.MaterialDefinition",
        "",
        "local materials: { [string]: MaterialDefinition } = {",
    ]
    for key, (hx, _m, _r, emission, alpha, rbx_mat, refl) in sorted(MATERIALS.items()):
        lines.append(
            f'\t{key} = {{ Color = Color3.fromHex("{hx}"), Material = Enum.Material.{rbx_mat}, '
            f"Reflectance = {_num(refl)}, Transparency = {_num(round(1 - alpha, 3))}, "
            f"Emissive = {'true' if emission > 0 else 'false'} }},")
    lines += ["}", "", "return table.freeze(materials)", ""]
    path = os.path.join(LUAU_DATA_DIR, "Materials.luau")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    return path


# --------------------------------------------------------------------------
# Orchestration
# --------------------------------------------------------------------------
def run_group(scene_name, module_name, script_name, export_subdir, assets, spacing=8.0):
    scene = get_scene(scene_name)
    clear_scene(scene)
    for key in MATERIALS:
        ensure_material(key)
    x = 0.0
    exported = []
    stats = {}
    for a in assets:
        offset = (x + a.bounds[0] / 2, 0.0, 0.0)
        root, coll = build_asset_in_blender(scene, a, offset)
        exported.append(export_asset_fbx(root, coll, export_subdir))
        stats[a.name] = {"parts": len(a.parts), "markers": len(a.markers),
                         "tris": sum(len(o.data.polygons) for o in coll.objects if o.type == "MESH")}
        x += a.bounds[0] + spacing
    luau = write_luau_group(module_name, script_name, assets)
    write_luau_materials()
    return {"scene": scene_name, "fbx": exported, "luau": luau, "assets": stats}


# --------------------------------------------------------------------------
# Briques d'architecture réutilisables
# --------------------------------------------------------------------------
GRID = 24
DOOR_W = 8
DOOR_H = 10
WALL_T = 1.0

SIDE_ROT = {"North": 0, "South": 180, "East": -90, "West": 90}


def side_frame(side, w, d):
    """Retourne (centre du mur sur le bord, axe le long du mur, normale sortante) en XZ."""
    if side == "North":
        return (0.0, -d / 2), (1, 0), (0, -1)
    if side == "South":
        return (0.0, d / 2), (1, 0), (0, 1)
    if side == "East":
        return (w / 2, 0.0), (0, 1), (1, 0)
    return (-w / 2, 0.0), (0, 1), (-1, 0)


def wall_with_door(a, side, w, d, h, door, mat="SteelPanel", door_offset=0.0, trim="NeonCyan"):
    (cx, cz), (ax, az), (nx, nz) = side_frame(side, w, d)
    length = w if ax else d
    # Le mur est posé à l'intérieur de l'emprise : son plan extérieur coïncide avec le bord.
    wx, wz = cx - nx * WALL_T / 2, cz - nz * WALL_T / 2

    def seg(name, t0, t1, y0, y1):
        if t1 - t0 <= 0.01 or y1 - y0 <= 0.01:
            return
        mid = (t0 + t1) / 2
        px, pz = wx + ax * mid, wz + az * mid
        size = (t1 - t0, y1 - y0, WALL_T) if ax else (WALL_T, y1 - y0, t1 - t0)
        a.box(name, mat, (px, (y0 + y1) / 2, pz), size, panels=(t1 - t0) * (y1 - y0) > 40)

    half = length / 2
    if door:
        d0, d1 = door_offset - DOOR_W / 2, door_offset + DOOR_W / 2
        seg(f"Wall{side}", -half, d0, 0, h)
        seg(f"Wall{side}", d1, half, 0, h)
        seg(f"Lintel{side}", d0, d1, DOOR_H, h)
        # Encadrement métallique + liseré néon
        for t in (d0, d1):
            px, pz = wx + ax * t, wz + az * t
            size = (0.6, DOOR_H, WALL_T + 0.5) if ax else (WALL_T + 0.5, DOOR_H, 0.6)
            a.box(f"DoorJamb{side}", "DarkMetal", (px, DOOR_H / 2, pz), size)
            nsize = (0.15, DOOR_H - 0.4, WALL_T + 0.6) if ax else (WALL_T + 0.6, DOOR_H - 0.4, 0.15)
            a.neon_strip(f"DoorTrim{side}", trim, (px - ax * 0.38 * (1 if t > door_offset else -1),
                                                   DOOR_H / 2, pz - az * 0.38 * (1 if t > door_offset else -1)), nsize)
        mx, mz = wx + ax * door_offset, wz + az * door_offset
        hsize = (DOOR_W + 1.2, 0.6, WALL_T + 0.5) if ax else (WALL_T + 0.5, 0.6, DOOR_W + 1.2)
        a.box(f"DoorHead{side}", "DarkMetal", (mx, DOOR_H + 0.3, mz), hsize)
        a.neon_strip(f"DoorHeadTrim{side}", trim, (mx, DOOR_H - 0.1, mz),
                     (DOOR_W - 0.4, 0.12, WALL_T + 0.6) if ax else (WALL_T + 0.6, 0.12, DOOR_W - 0.4))
        # Connecteur : sur le bord, centré sur l'ouverture, regardant vers l'extérieur
        a.marker("Connector", f"Connector_{side}", (cx + ax * door_offset, DOOR_H / 2, cz + az * door_offset),
                 (0, SIDE_ROT[side], 0), (DOOR_W, DOOR_H, 0.2), {"Side": side})
    else:
        seg(f"Wall{side}", -half, half, 0, h)


def room_shell(a, w, d, h, doors, wall_mat="SteelPanel", floor_mat="ConcreteFloor", ceiling=True,
               plinth=True, pillars=True, beams=True, grooves=True, trim="NeonCyan", door_offsets=None,
               floor=True):
    door_offsets = door_offsets or {}
    if floor:
        a.box("Floor", floor_mat, (0, -0.5, 0), (w, 1, d), bevel=False)
    if ceiling:
        a.box("Ceiling", "DarkMetal", (0, h + 0.5, 0), (w, 1, d), bevel=False)
    for side in ("North", "South", "East", "West"):
        wall_with_door(a, side, w, d, h, side in doors, wall_mat, door_offsets.get(side, 0.0), trim)
    iw, idp = w - 2 * WALL_T, d - 2 * WALL_T
    if plinth:
        for side in ("North", "South", "East", "West"):
            (cx, cz), (ax, az), (nx, nz) = side_frame(side, w, d)
            length = (iw if ax else idp)
            px, pz = cx - nx * (WALL_T + 0.2), cz - nz * (WALL_T + 0.2)
            off = door_offsets.get(side, 0.0)
            segs = [(-length / 2, length / 2)]
            if side in doors:
                segs = [(-length / 2, off - DOOR_W / 2 - 0.6), (off + DOOR_W / 2 + 0.6, length / 2)]
            for t0, t1 in segs:
                if t1 - t0 < 0.5:
                    continue
                mid = (t0 + t1) / 2
                size = (t1 - t0, 0.6, 0.4) if ax else (0.4, 0.6, t1 - t0)
                a.box(f"Plinth{side}", "DarkMetal", (px + ax * mid, 0.3, pz + az * mid), size, bevel=False)
                if grooves:
                    gsize = (t1 - t0, 0.12, 0.1) if ax else (0.1, 0.12, t1 - t0)
                    a.neon_strip(f"Groove{side}", trim, (cx - nx * (WALL_T + 0.04) + ax * mid, 3.2,
                                                         cz - nz * (WALL_T + 0.04) + az * mid), gsize)
    if pillars:
        for sx in (-1, 1):
            for sz in (-1, 1):
                p = (sx * (w / 2 - WALL_T - 0.9), h / 2, sz * (d / 2 - WALL_T - 0.9))
                a.vcyl("CornerPillar", "DarkMetal", p, h, 1.8, sides=8)
                a.neon_strip("PillarLight", trim, (p[0], h / 2, p[2]), (0.15, h - 2, 2.0),
                             (0, 45 * sx * sz, 0))
    if ceiling and beams:
        n = max(1, int(d // 8))
        for i in range(n):
            z = -d / 2 + (i + 0.5) * d / n
            a.box("CeilingBeam", "DarkMetal", (0, h - 0.4, z), (iw, 0.8, 0.9))
        for x in (-iw / 4, iw / 4):
            a.neon_strip("CeilingLight", trim, (x, h - 0.05, 0), (0.5, 0.1, idp - 2), light=True)
    a.marker("BoundingBox", "BoundingBox", (0, h / 2, 0), (0, 0, 0), (w - 0.4, h - 0.4, d - 0.4))


def pipe_run(a, start, end, diameter, mat="SteelPanel", brackets=True):
    sx, sy, sz = start
    ex, ey, ez = end
    dx, dy, dz = ex - sx, ey - sy, ez - sz
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    mid = ((sx + ex) / 2, (sy + ey) / 2, (sz + ez) / 2)
    yaw = math.degrees(math.atan2(-dz, dx))
    pitch = math.degrees(math.atan2(dy, math.sqrt(dx * dx + dz * dz)))
    a.cyl("Pipe", mat, mid, length, diameter, (0, yaw, pitch), NO_COLLIDE, sides=12)
    if brackets:
        steps = max(1, int(length // 6))
        for i in range(steps + 1):
            t = i / steps
            p = (sx + dx * t, sy + dy * t, sz + dz * t)
            a.cyl("PipeClamp", "DarkMetal", p, 0.3, diameter + 0.25, (0, yaw, pitch), NO_COLLIDE, sides=12)
