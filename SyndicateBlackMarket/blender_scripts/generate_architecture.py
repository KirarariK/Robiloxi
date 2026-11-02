"""
generate_architecture.py — modules de salles procéduraux + planque du hub.

Grille 24 x 24 studs (ou multiples), plafond 14 studs (18 pour le coffre),
ouvertures de porte 8 x 10 centrées sur les murs. Pivot = centre du sol (Y = 0).
Exécution dans Blender :
    exec(open(r"<...>/blender_scripts/generate_architecture.py").read(),
         {"__file__": r"<...>/blender_scripts/generate_architecture.py", "__name__": "__main__"})
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402

import sbm_common  # noqa: E402

importlib.reload(sbm_common)
from sbm_common import (BEAM, BREAKABLE, LIGHT, NO_COLLIDE, NO_QUERY, Asset,  # noqa: E402,F401
                        pipe_run, room_shell)

H = 14


# ---------------------------------------------------------------------------
# Marqueurs de gameplay communs
# ---------------------------------------------------------------------------
def patrol(a, points):
    for i, (x, z) in enumerate(points, 1):
        a.marker("PatrolPoint", f"Patrol_{i}", (x, 0.5, z), attrs={"Order": i})


def loot(a, name, pos, tier="Standard"):
    a.marker("LootSpawn", name, pos, attrs={"Tier": tier})


def camera_mount(a, name, pos, yaw, pitch=-25):
    a.marker("CameraMount", name, pos, (pitch, yaw, 0))


# ---------------------------------------------------------------------------
# Mod_Spawn_Extraction (24 x 36) : ruelle + fourgon blindé
# ---------------------------------------------------------------------------
def spawn_extraction():
    w, d = 24, 36
    a = Asset("Mod_Spawn_Extraction", "Room", (w, H, d), {"RoomCategory": "Spawn"})
    room_shell(a, w, d, H, {"North"}, wall_mat="ConcreteWall", ceiling=False, pillars=False,
               trim="NeonCrimson")
    # Tuyaux apparents le long des murs est/ouest
    for sx in (-1, 1):
        x = sx * 10.6
        pipe_run(a, (x, 8.2, -16), (x, 8.2, 16), 0.9)
        pipe_run(a, (x - sx * 0.2, 9.6, -16), (x - sx * 0.2, 9.6, 16), 0.6, mat="DarkMetal")
        for z in (-12, 2, 14):
            pipe_run(a, (x + sx * 0.1, 0.2, z), (x + sx * 0.1, 8.2, z), 0.7)
        a.box("Dumpster", "DarkMetal", (x - sx * 1.6, 1.4, -6), (2.6, 2.8, 4.5))
        a.wedge("DumpsterLid", "Rubber", (x - sx * 1.6, 3.05, -6), (2.6, 0.5, 4.5), (0, 90 * sx, 0))
    # Enseignes néon sur les murs
    for x, y, z, mat in ((-11.2, 11, -9, "NeonCyan"), (11.2, 10.5, 6, "NeonCrimson"), (-11.2, 6.5, 10, "NeonGold")):
        a.box("SignBack", "CarbonFiber", (x, y, z), (0.4, 2.4, 5), bevel=False)
        for i in range(3):
            a.neon_strip("SignNeon", mat, (x + (0.25 if x < 0 else -0.25), y - 0.7 + i * 0.7, z),
                         (0.1, 0.25, 4.4 - i * 0.9), light=(i == 1))
    # ---- Fourgon blindé (avant = +Z, portes arrière ouvertes vers le nord) ----
    vz = 5.0
    a.box("VanChassis", "DarkMetal", (0, 1.6, vz), (6.6, 1.0, 15))
    a.neon_strip("VanUnderglow", "NeonCrimson", (0, 1.05, vz), (6.4, 0.1, 13.6), light=True)
    for sx in (-1, 1):
        a.box("VanCargoWall", "VanPaint", (sx * 3.3, 4.85, vz - 2.5), (0.4, 5.5, 10), panels=True)
        a.box("VanArmorPlate", "SteelPanel", (sx * 3.55, 3.4, vz - 2.5), (0.15, 1.6, 9.4))
        a.neon_strip("VanSideNeon", "NeonCyan", (sx * 3.62, 5.6, vz - 2.5), (0.05, 0.15, 9.6))
    a.box("VanRoof", "VanPaint", (0, 7.8, vz - 2.5), (7.0, 0.4, 10.4))
    a.box("VanBulkhead", "VanPaint", (0, 4.85, vz + 2.3), (6.2, 5.5, 0.4))
    a.box("VanCargoFloor", "Grate", (0, 2.25, vz - 2.5), (6.2, 0.3, 10), bevel=False)
    a.neon_strip("VanCargoLight", "NeonCyan", (0, 7.55, vz - 2.5), (0.6, 0.1, 9), light=True)
    for sx in (-1, 1):  # racks intérieurs
        for y in (3.6, 5.3):
            a.box("VanRackShelf", "DarkMetal", (sx * 2.45, y, vz - 2.5), (1.2, 0.15, 9))
        for z in (-6.5, -2.5, 1.5):
            a.box("VanRackPost", "DarkMetal", (sx * 1.9, 4.3, vz + z), (0.15, 4.0, 0.15), bevel=False)
    # Cabine, pare-brise, capot
    a.box("VanCab", "VanPaint", (0, 4.0, vz + 4.5), (7.0, 3.6, 4.0), panels=True)
    a.wedge("VanWindshieldFrame", "VanPaint", (0, 6.8, vz + 4.5), (7.0, 2.0, 4.0), (0, 180, 0))
    a.wedge("VanWindshield", "Glass", (0, 6.85, vz + 4.35), (6.4, 1.8, 3.6), (0, 180, 0), NO_COLLIDE)
    a.box("VanHood", "VanPaint", (0, 3.4, vz + 7.6), (7.0, 2.4, 2.4))
    a.box("VanBumper", "DarkMetal", (0, 2.2, vz + 8.9), (7.4, 0.8, 0.6))
    for sx in (-1, 1):
        a.neon_strip("VanHeadlight", "NeonCyan", (sx * 2.6, 3.6, vz + 8.82), (1.2, 0.35, 0.1), light=True)
        a.neon_strip("VanTaillight", "NeonCrimson", (sx * 3.2, 4.0, vz - 7.52), (0.4, 1.4, 0.1))
    # Roues octogonales
    for sx in (-1, 1):
        for z in (vz - 5.5, vz + 5.0):
            a.cyl("VanWheel", "Rubber", (sx * 3.55, 1.5, z), 1.4, 3.0, sides=8)
            a.cyl("VanHub", "DarkMetal", (sx * 4.2, 1.5, z), 0.2, 1.6, flags=NO_COLLIDE, sides=8)
            a.cyl("VanHubNeon", "NeonCyan", (sx * 4.32, 1.5, z), 0.05, 0.6, flags=NO_COLLIDE | NO_QUERY, sides=8)
    # Portes arrière ouvertes à 90°
    for sx in (-1, 1):
        a.box("VanRearDoor", "VanPaint", (sx * 3.75, 4.85, vz - 9.3), (0.3, 5.3, 3.5), panels=True)
        a.box("VanDoorHinge", "DarkMetal", (sx * 3.5, 4.85, vz - 7.55), (0.4, 5.0, 0.3), bevel=False)
    a.marker("SecureZone", "SecureZone", (0, 4.6, vz - 2.5), size=(6.0, 4.6, 9.6))
    a.marker("ExtractionArea", "ExtractionArea", (0, 4.6, vz - 4.0), size=(8.0, 6.0, 13.0))
    for i, (x, z) in enumerate(((-6, -10), (6, -10), (-6, -14), (6, -14)), 1):
        a.marker("PlayerSpawn", f"PlayerSpawn_{i}", (x, 0.5, z), (0, 0, 0))
    for i, x in enumerate((-8, 8), 1):
        a.marker("SwatSpawn", f"SwatSpawn_{i}", (x, 0.5, 15.5), (0, 0, 0))
    return a


# ---------------------------------------------------------------------------
# Mod_Hallway_Straight (24 x 24) : grilles au sol, câbles, tuyaux au plafond
# ---------------------------------------------------------------------------
def hallway_straight():
    w = d = 24
    a = Asset("Mod_Hallway_Straight", "Room", (w, H, d), {"RoomCategory": "Hallway"})
    room_shell(a, w, d, H, {"North", "South"}, floor=False)
    for sx in (-1, 1):
        a.box("FloorSlab", "ConcreteFloor", (sx * 7.5, -0.5, 0), (9, 1, d), bevel=False)
    a.box("TrenchBottom", "ConcreteFloor", (0, -2.0, 0), (6, 1, d), bevel=False)
    for sx in (-1, 1):
        a.box("TrenchWall", "DarkMetal", (sx * 3.05, -1.0, 0), (0.1, 2, d), bevel=False)
    for i, (x, mat) in enumerate(((-1.8, "Rubber"), (-0.9, "NeonCyan"), (0.2, "Rubber"), (1.2, "NeonCrimson"), (2.1, "Rubber"))):
        a.cyl("Cable", mat, (x, -1.25, 0), d, 0.45 if mat == "Rubber" else 0.25, (0, 90, 0),
              NO_COLLIDE | NO_QUERY | (LIGHT if i == 1 else 0), sides=10)
    z = -d / 2 + 0.4
    while z < d / 2:
        a.box("GrateBar", "Grate", (0, -0.12, z), (6, 0.24, 0.3), bevel=False)
        z += 0.75
    for sx in (-1, 1):
        a.box("GrateRail", "Grate", (sx * 2.9, -0.12, 0), (0.3, 0.24, d), bevel=False)
    # Côtes métalliques biseautées sur les murs latéraux
    for sx in (-1, 1):
        for zz in (-8, -2.7, 2.7, 8):
            a.box("WallRib", "DarkMetal", (sx * 10.7, H / 2, zz), (0.6, H, 0.9))
            a.neon_strip("RibLight", "NeonCyan", (sx * 10.38, 6.5, zz), (0.06, 4.0, 0.25))
    for x, y, dia in ((-6, 12.6, 0.9), (-4.6, 12.9, 0.55), (6, 12.6, 0.9), (4.4, 12.95, 0.5)):
        pipe_run(a, (x, y, -d / 2 + 1.1), (x, y, d / 2 - 1.1), dia)
    a.box("VentBox", "SteelPanel", (0, 12.8, 0), (3, 1.6, 6))
    a.detail("VentGrille", "Grate", (0, 11.98, 0), (2.6, 0.05, 5.6))
    patrol(a, ((-5, -8), (5, -8), (5, 8), (-5, 8)))
    a.marker("GuardSpawn", "GuardSpawn_1", (5, 0.5, 0), (0, 90, 0))
    loot(a, "Loot_1", (-9.5, 0.6, 4))
    camera_mount(a, "Camera_1", (10.2, 11.5, -10.2), 135)
    return a


# ---------------------------------------------------------------------------
# Mod_Hallway_Corner (24 x 24) : virage sud -> est, vitre blindée sur puits néon
# ---------------------------------------------------------------------------
def hallway_corner():
    w = d = 24
    a = Asset("Mod_Hallway_Corner", "Room", (w, H, d), {"RoomCategory": "Hallway"})
    room_shell(a, w, d, H, {"South", "East"})
    # Pan coupé vitré à 45° dans l'angle extérieur (nord-ouest)
    a.box("ShaftGlass", "Glass", (-7.2, 7, -7.2), (8.6, 13.6, 0.5), (0, -45, 0), BREAKABLE)
    for t in (-1, 1):
        a.box("ShaftMullion", "DarkMetal", (-7.2 + t * 3.04, 7, -7.2 - t * 3.04), (0.8, H, 0.9), (0, -45, 0))
    a.box("ShaftSill", "DarkMetal", (-7.2, 0.4, -7.2), (8.8, 0.8, 1.0), (0, -45, 0))
    a.box("ShaftHead", "DarkMetal", (-7.2, 13.6, -7.2), (8.8, 0.8, 1.0), (0, -45, 0))
    for i, (x, z) in enumerate(((-9.6, -8.2), (-8.2, -9.6), (-10.2, -10.2))):
        a.vcyl("ShaftNeon", "NeonCyan" if i != 2 else "NeonCrimson", (x, 7, z), H, 0.35,
               NO_COLLIDE | NO_QUERY | (LIGHT if i == 2 else 0), sides=8)
    for i in range(4):
        a.detail("FanBlade", "DarkMetal", (-9.4, 12.6, -9.4), (3.0, 0.08, 0.5), (0, i * 45, 0))
    # Pilier holographique devant la vitre
    a.vcyl("HoloBase", "DarkMetal", (-4.2, 0.4, -4.2), 0.8, 2.2, sides=8)
    a.vcyl("HoloColumn", "HoloCyan", (-4.2, 4.0, -4.2), 6.4, 1.4, NO_COLLIDE | NO_QUERY | LIGHT, sides=16)
    a.vcyl("HoloCap", "DarkMetal", (-4.2, 7.4, -4.2), 0.4, 2.0, sides=8)
    pipe_run(a, (-10, 12.7, 11), (-10, 12.7, -10), 0.8)
    pipe_run(a, (-10, 12.7, -10), (11, 12.7, -10), 0.8)
    patrol(a, ((0, 8), (0, 0), (8, 0)))
    a.marker("GuardSpawn", "GuardSpawn_1", (2, 0.5, 2), (0, -45, 0))
    loot(a, "Loot_1", (8, 0.6, 9))
    camera_mount(a, "Camera_1", (10.2, 11.5, 10.2), -135)
    return a


# ---------------------------------------------------------------------------
# Mod_Hallway_TJunction (24 x 24) : pilier octogonal central servant de couverture
# ---------------------------------------------------------------------------
def hallway_tjunction():
    w = d = 24
    a = Asset("Mod_Hallway_TJunction", "Room", (w, H, d), {"RoomCategory": "Hallway"})
    room_shell(a, w, d, H, {"South", "East", "West"})
    a.vcyl("CoverPillar", "DarkMetal", (0, H / 2, -3), H, 5.0, sides=8)
    a.vcyl("CoverPillarBase", "SteelPanel", (0, 0.6, -3), 1.2, 6.0, sides=8)
    for y in (2.5, 9.0):
        a.vcyl("CoverBand", "NeonCyan", (0, y, -3), 0.3, 5.15, NO_COLLIDE | NO_QUERY | LIGHT, sides=8)
    for i in range(4):
        ang = math.radians(i * 90 + 22.5)
        a.box("PillarArmor", "SteelPanel", (math.cos(ang) * 2.5, 5.6, -3 - math.sin(ang) * 2.5),
              (0.3, 4.0, 1.6), (0, i * 90 + 22.5, 0))
    for sx in (-1, 1):
        a.box("Barrier", "DarkMetal", (sx * 6.5, 1.1, 6.5), (3.0, 2.2, 0.8))
        a.neon_strip("BarrierStripe", "NeonCrimson", (sx * 6.5, 1.6, 6.08), (2.6, 0.2, 0.05))
    pipe_run(a, (-11, 12.7, -9), (11, 12.7, -9), 0.9)
    pipe_run(a, (-11, 12.95, -7.6), (11, 12.95, -7.6), 0.5)
    patrol(a, ((-9, 0), (0, 6), (9, 0)))
    a.marker("GuardSpawn", "GuardSpawn_1", (0, 0.5, 4), (0, 180, 0))
    loot(a, "Loot_1", (-8, 0.6, -9))
    loot(a, "Loot_2", (8, 0.6, -9))
    camera_mount(a, "Camera_1", (0, 12.0, -10.2), 0)
    return a


# ---------------------------------------------------------------------------
# Mod_Room_ServerFarm (48 x 48) : 12 baies + conduit de ventilation périphérique
# ---------------------------------------------------------------------------
def server_farm():
    w = d = 48
    a = Asset("Mod_Room_ServerFarm", "Room", (w, H, d), {"RoomCategory": "Room"})
    room_shell(a, w, d, H, {"South", "North", "East"}, pillars=False)
    # Conduit : 4.5 x 4.5 libres, collé aux murs, interrompu aux portes
    inner = 23.0  # face intérieure des murs
    duct_w, duct_h, t = 4.5, 4.5, 0.5
    doors = {"North", "South", "East"}
    for side in ("North", "South", "East", "West"):
        horizontal = side in ("North", "South")
        sign = -1 if side in ("North", "West") else 1
        spans = [(-inner, -4.6), (4.6, inner)] if side in doors else [(-inner, inner)]
        for t0, t1 in spans:
            mid, length = (t0 + t1) / 2, t1 - t0
            off = sign * (inner - duct_w - t / 2)
            cover_off = sign * (inner - (duct_w + t) / 2)
            if horizontal:
                a.box("DuctWall", "SteelPanel", (mid, duct_h / 2, off), (length, duct_h, t), panels=True)
                a.box("DuctCover", "DarkMetal", (mid, duct_h + t / 2, cover_off), (length, t, duct_w + t))
            else:
                a.box("DuctWall", "SteelPanel", (off, duct_h / 2, mid), (t, duct_h, length), panels=True)
                a.box("DuctCover", "DarkMetal", (cover_off, duct_h + t / 2, mid), (duct_w + t, t, length))
            k = t0 + 3
            while k < t1 - 2:
                gpos = (k, 2.2, off - sign * 0.28) if horizontal else (off - sign * 0.28, 2.2, k)
                gsize = (2.0, 1.4, 0.06) if horizontal else (0.06, 1.4, 2.0)
                a.detail("DuctGrille", "Grate", gpos, gsize)
                k += 7
            a.neon_strip("DuctEdge", "NeonCyan", (mid, duct_h + t + 0.03, cover_off) if horizontal
                         else (cover_off, duct_h + t + 0.03, mid),
                         (length, 0.06, 0.2) if horizontal else (0.2, 0.06, length))
            for end in (t0, t1):
                if abs(abs(end) - inner) < 0.1:
                    continue
                a.marker("VentEntrance", f"Vent_{side}_{len(a.markers)}",
                         (end, duct_h / 2, sign * (inner - duct_w / 2)) if horizontal
                         else (sign * (inner - duct_w / 2), duct_h / 2, end))
    # 12 baies de serveurs : 3 rangées x 4
    idx = 0
    for z in (-9, 0, 9):
        for x in (-12, -4, 4, 12):
            idx += 1
            a.box("RackBody", "CarbonFiber", (x, 4.0, z), (6, 8, 2.2))
            for face in (-1, 1):
                fz = z + face * 1.12
                a.detail("RackGrille", "Grate", (x, 4.3, fz), (5.2, 6.4, 0.06))
                for row in range(5):
                    mat = "NeonGreen" if (row + idx) % 3 else "NeonCyan"
                    a.neon_strip("RackLED", mat, (x - 2.2 + (row % 2) * 0.4, 1.6 + row * 1.3, fz + face * 0.04),
                                 (0.5, 0.08, 0.04), light=(row == 2 and face == 1))
            a.box("RackTop", "DarkMetal", (x, 8.15, z), (6.2, 0.3, 2.4), bevel=False)
            a.cyl("RackFan", "Grate", (x, 8.4, z), 0.25, 1.6, (0, 0, 90), NO_COLLIDE, sides=12)
            if idx % 2 == 0:
                loot(a, f"Loot_{idx // 2}", (x, 0.6, z + 1.9))
    # Chemins de câbles au plafond
    for z in (-9, 0, 9):
        a.box("CableTray", "Grate", (0, 12.2, z), (32, 0.25, 1.6), bevel=False)
        a.cyl("TrayCable", "Rubber", (0, 12.45, z), 32, 0.35, flags=NO_COLLIDE | NO_QUERY, sides=8)
    patrol(a, ((-16, -14), (16, -14), (16, 14), (-16, 14)))
    a.marker("GuardSpawn", "GuardSpawn_1", (0, 0.5, -4.5), (0, 90, 0))
    a.marker("GuardSpawn", "GuardSpawn_2", (0, 0.5, 4.5), (0, -90, 0))
    camera_mount(a, "Camera_1", (-17.5, 11.5, -17.5), -45)
    camera_mount(a, "Camera_2", (17.5, 11.5, 17.5), 135)
    a.marker("LaserEmitter", "Laser_1", (-8, 2.0, -4.5), (0, -90, 0), attrs={"Length": 16})
    a.marker("LaserEmitter", "Laser_2", (-8, 2.0, 4.5), (0, -90, 0), attrs={"Length": 16})
    return a


# ---------------------------------------------------------------------------
# Mod_Room_SecurityHub (24 x 24) : bureau en U, 6 écrans, baie vitrée, générateur
# ---------------------------------------------------------------------------
def security_hub():
    w = d = 24
    a = Asset("Mod_Room_SecurityHub", "Room", (w, H, d), {"RoomCategory": "SecurityHub"})
    room_shell(a, w, d, H, {"South"})
    # Bureau en U
    a.box("DeskBack", "CarbonFiber", (0, 1.4, -3.5), (12, 2.8, 2.2))
    for sx in (-1, 1):
        a.box("DeskSide", "CarbonFiber", (sx * 6.9, 1.4, 0.2), (2.2, 2.8, 9.6))
        a.neon_strip("DeskEdge", "NeonCyan", (sx * 6.9, 2.82, 0.2), (2.25, 0.05, 9.6))
    a.neon_strip("DeskEdgeBack", "NeonCyan", (0, 2.82, -3.5), (12, 0.05, 2.25))
    for i, (x, z, yaw) in enumerate(((-3.6, -3.9, 0), (0, -3.9, 0), (3.6, -3.9, 0),
                                     (-6.9, -0.6, 70), (6.9, -0.6, -70), (6.9, 2.8, -90))):
        a.box("MonitorStand", "DarkMetal", (x, 3.1, z), (0.3, 0.6, 0.3), bevel=False)
        a.box("Monitor", "CarbonFiber", (x, 4.3, z), (3.2, 1.9, 0.25), (-15, yaw, 0))
        a.box("MonitorScreen", "HoloCyan", (x + math.sin(math.radians(yaw)) * 0.14, 4.3,
                                            z + math.cos(math.radians(yaw)) * 0.14),
              (2.9, 1.6, 0.05), (-15, yaw, 0), NO_COLLIDE | NO_QUERY | (LIGHT if i == 1 else 0), bevel=False)
    a.box("Chair", "Fabric", (0, 1.2, 0.5), (1.8, 0.6, 1.8))
    a.box("ChairBack", "Fabric", (0, 2.6, 1.3), (1.8, 2.4, 0.4))
    # Baie vitrée sur la ville (mur nord)
    a.box("WindowBacking", "CarbonFiber", (0, 7.5, -10.95), (16, 7, 0.1), bevel=False)
    for i in range(14):
        hgt = 1.2 + ((i * 37) % 9) * 0.55
        mat = ("NeonCyan", "NeonCrimson", "NeonGold")[i % 3]
        a.neon_strip("CityLight", mat, (-7.4 + i * 1.14, 4.2 + hgt / 2, -10.88), (0.6, hgt, 0.05))
    a.box("PanoramicGlass", "Glass", (0, 7.5, -10.6), (16, 7, 0.4), flags=BREAKABLE, bevel=False)
    for x in (-8.2, -2.7, 2.7, 8.2):
        a.box("WindowMullion", "DarkMetal", (x, 7.5, -10.5), (0.5, 7.4, 0.7))
    for y in (3.8, 11.2):
        a.box("WindowFrame", "DarkMetal", (0, y, -10.5), (16.9, 0.5, 0.8))
    # Générateur principal (angle nord-est) + levier/terminal
    gx, gz = 8.0, -7.5
    a.box("GeneratorBase", "DarkMetal", (gx, 0.5, gz), (5, 1, 4))
    for ox in (-1.2, 1.2):
        a.vcyl("GeneratorCell", "SteelPanel", (gx + ox, 3.6, gz), 5.2, 2.0, sides=8)
        for y in (2.0, 3.6, 5.2):
            a.vcyl("GeneratorBand", "NeonCrimson", (gx + ox, y, gz), 0.2, 2.1, NO_COLLIDE | NO_QUERY,
                   sides=8)
    a.box("GeneratorPanel", "CarbonFiber", (gx, 3.0, gz + 2.2), (3.6, 2.4, 0.4))
    a.box("LeverHousing", "DarkMetal", (gx + 2.9, 2.6, gz + 1.2), (0.6, 1.6, 0.8))
    a.cyl("LeverHandle", "NeonGold", (gx + 3.3, 3.0, gz + 1.2), 1.4, 0.25, (0, 0, 55), NO_COLLIDE, sides=8)
    a.marker("HackTerminal", "SecurityGenerator", (gx, 3.0, gz + 2.6), (0, 180, 0),
             attrs={"TerminalKind": "SecurityGenerator"})
    patrol(a, ((-8, 6), (8, 6), (0, 8)))
    a.marker("GuardSpawn", "GuardSpawn_1", (0, 0.5, 1.5), (0, 180, 0))
    loot(a, "Loot_1", (-9, 0.6, -8))
    camera_mount(a, "Camera_1", (-10.2, 11.5, 10.2), -135)
    return a


# ---------------------------------------------------------------------------
# Mod_Room_ExecutiveOffice (24 x 24) : bureau néo-noir, coffre mural, vitrines
# ---------------------------------------------------------------------------
def executive_office():
    w = d = 24
    a = Asset("Mod_Room_ExecutiveOffice", "Room", (w, H, d), {"RoomCategory": "Room"})
    room_shell(a, w, d, H, {"South", "West"}, floor_mat="Wood", trim="NeonGold")
    a.box("Rug", "CarbonFiber", (0, 0.03, -2), (10, 0.06, 7), bevel=False, flags=NO_COLLIDE)
    # Bureau minimaliste métal/verre
    for sx in (-1, 1):
        a.box("DeskLeg", "DarkMetal", (sx * 3.6, 1.5, -4), (0.4, 3.0, 2.6))
    a.box("DeskTop", "Glass", (0, 3.1, -4), (8.4, 0.25, 3.2), bevel=False)
    a.neon_strip("DeskGlow", "NeonGold", (0, 2.95, -4), (8.0, 0.05, 2.8))
    a.box("DeskTerminal", "CarbonFiber", (1.8, 3.9, -4.8), (2.4, 1.4, 0.15), (-10, 0, 0))
    a.box("ExecChair", "Fabric", (0, 1.3, -6.4), (2.2, 0.7, 2.0))
    a.box("ExecChairBack", "Fabric", (0, 3.4, -7.3), (2.2, 3.4, 0.4))
    # Bibliothèque cybernétique (mur est)
    a.box("ShelfFrame", "DarkMetal", (10.6, 5.5, 0), (1.4, 11, 10))
    for y in (1.8, 4.4, 7.0, 9.6):
        a.box("Shelf", "Wood", (10.1, y, 0), (1.2, 0.2, 9.4), bevel=False)
        for k in range(9):
            hgt = 1.4 + (k % 3) * 0.35
            mat = ("NeonCyan", "Fabric", "NeonGold", "Fabric")[(k + int(y)) % 4]
            a.detail("Book", mat, (10.1, y + 0.1 + hgt / 2, -4.2 + k * 1.05), (0.9, hgt, 0.6))
    # Coffre mural derrière un cadre (mur nord)
    a.box("SafeDoor", "DarkMetal", (-5, 7, -10.8), (3.6, 3.6, 0.4))
    a.cyl("SafeDial", "NeonGold", (-5, 7, -10.5), 0.3, 1.2, (0, 90, 0), NO_COLLIDE, sides=12)
    a.box("PaintingFrame", "NeonGold", (-7.6, 7, -10.55), (0.3, 5, 4.2), (0, 70, 0))
    a.box("Painting", "CarbonFiber", (-7.55, 7, -10.45), (0.08, 4.4, 3.6), (0, 70, 0), NO_COLLIDE, bevel=False)
    a.marker("HackTerminal", "WallSafe", (-5, 7, -10.3), (0, 0, 0), attrs={"TerminalKind": "WallSafe"})
    loot(a, "Loot_Safe", (-5, 6.0, -10.3), "Safe")
    # Vitrines d'exposition
    for i, (x, z) in enumerate(((5, 6), (-5, 6)), 1):
        a.box("DisplayPlinth", "DarkMetal", (x, 1.5, z), (2.6, 3.0, 2.6))
        a.neon_strip("DisplayGlow", "NeonGold", (x, 3.02, z), (2.2, 0.05, 2.2), light=True)
        a.box("DisplayCase", "Glass", (x, 4.6, z), (2.4, 3.1, 2.4), flags=BREAKABLE, bevel=False)
        loot(a, f"Loot_Display_{i}", (x, 3.6, z), "Display")
    patrol(a, ((-8, 8), (8, 8), (8, -8), (-8, -2)))
    a.marker("GuardSpawn", "GuardSpawn_1", (-6, 0.5, 0), (0, 90, 0))
    camera_mount(a, "Camera_1", (10.2, 11.5, -10.2), 135)
    return a


# ---------------------------------------------------------------------------
# Mod_Room_HighTechVault (48 x 48 x 18) : porte circulaire, lasers, piédestal sous dôme
# ---------------------------------------------------------------------------
def high_tech_vault():
    w = d = 48
    hv = 18
    a = Asset("Mod_Room_HighTechVault", "Room", (w, hv, d), {"RoomCategory": "Vault"})
    room_shell(a, w, d, hv, {"South"}, wall_mat="DarkMetal", trim="NeonGold")
    # Cadre de porte blindée circulaire (côté intérieur du mur sud)
    cz = 22.2
    for i in range(20):
        ang = math.radians(i * 18)
        x, y = math.cos(ang) * 7.2, 5.5 + math.sin(ang) * 7.2
        if y < 0.6:
            continue
        a.box("VaultRing", "SteelPanel", (x, y, cz), (2.4, 1.6, 2.0), (0, 0, i * 18 + 90))
        if i % 2 == 0:
            a.vcyl("RingBolt", "NeonGold", (x * 1.12, 5.5 + (y - 5.5) * 1.12, cz - 1.05), 0.3, 0.5,
                   NO_COLLIDE | NO_QUERY, sides=8)
    # Disque de porte ouvert à 90° + vérins hydrauliques
    a.cyl("VaultDoorDisc", "SteelPanel", (-9.0, 6.4, cz - 4.0), 1.8, 12.4, sides=24)
    a.cyl("VaultDoorCore", "DarkMetal", (-8.0, 6.4, cz - 4.0), 0.4, 5.0, sides=16)
    for i in range(8):
        a.box("VaultDoorSpoke", "NeonGold", (-7.95, 6.4, cz - 4.0), (0.12, 0.35, 9.0), (i * 22.5, 0, 0))
    for y in (2.2, 10.6):
        pipe_run(a, (-5.2, y, cz - 0.8), (-8.4, y, cz - 4.0), 0.7, mat="DarkMetal", brackets=False)
        pipe_run(a, (-5.0, y, cz - 0.6), (-6.6, y, cz - 2.3), 1.0, mat="NeonGold", brackets=False)
    # Piliers de sécurité + émetteurs laser horizontaux
    for z in (8, 0):
        for sx in (-1, 1):
            a.vcyl("SecurityPillar", "DarkMetal", (sx * 9, hv / 2, z), hv, 2.4, sides=8)
            for y in (1.5, 3.5, 5.5):
                a.cyl("LaserEmitterHead", "NeonCrimson", (sx * 7.75, y, z), 0.3, 0.5,
                      flags=NO_COLLIDE | NO_QUERY, sides=12)
        for y in (1.5, 3.5, 5.5):
            a.marker("LaserEmitter", f"Laser_{z}_{y}", (-7.6, y, z), (0, -90, 0), attrs={"Length": 15.2})
    # Coffres de banque sur les murs latéraux
    li = 0
    for sx in (-1, 1):
        a.box("DepositWall", "SteelPanel", (sx * 22.1, 5.5, -2), (0.8, 10, 26))
        for row in range(4):
            for col in range(7):
                z = -13 + col * 3.6 + 1.6
                y = 1.7 + row * 2.4
                a.box("DepositBox", "DarkMetal", (sx * 21.6, y, z), (0.3, 2.1, 3.3))
                a.detail("DepositHandle", "NeonGold", (sx * 21.4, y, z + 1.1), (0.15, 0.5, 0.15))
                if (row + col) % 5 == 0:
                    li += 1
                    loot(a, f"Loot_Vault_{li}", (sx * 20.6, y - 0.6, z), "Vault")
    # Piédestal octogonal sous dôme de verre rétractable
    pz = -10
    a.vcyl("PedestalStep", "SteelPanel", (0, 0.3, pz), 0.6, 10, sides=8)
    a.vcyl("Pedestal", "DarkMetal", (0, 1.6, pz), 2.6, 7, sides=8)
    a.vcyl("PedestalGlow", "NeonGold", (0, 2.95, pz), 0.12, 7.1, NO_COLLIDE | NO_QUERY | LIGHT, sides=8)
    a.ball("VaultDome", "Glass", (0, 3.0, pz), 6.0, flags=BREAKABLE)
    a.vcyl("DomeRail", "NeonCyan", (0, 3.05, pz), 0.2, 6.2, NO_COLLIDE | NO_QUERY, sides=24)
    a.marker("Objective", "Objective", (0, 4.0, pz), attrs={"LootId": "QuantumCore"})
    a.box("DomeConsole", "CarbonFiber", (0, 1.8, pz + 6.5), (3, 3.6, 1.2))
    a.box("DomeConsoleScreen", "HoloCyan", (0, 3.0, pz + 5.85), (2.6, 1.2, 0.05), (-20, 0, 0),
          NO_COLLIDE | NO_QUERY, bevel=False)
    a.marker("HackTerminal", "VaultDome", (0, 3.0, pz + 5.8), (0, 180, 0), attrs={"TerminalKind": "VaultDome"})
    patrol(a, ((-14, 14), (14, 14), (14, -16), (-14, -16)))
    a.marker("GuardSpawn", "GuardSpawn_1", (-12, 0.5, 12), (0, 0, 0))
    a.marker("GuardSpawn", "GuardSpawn_2", (12, 0.5, -16), (0, 180, 0))
    camera_mount(a, "Camera_1", (-17.5, 15.5, -17.5), -45)
    camera_mount(a, "Camera_2", (17.5, 15.5, -17.5), 45)
    return a


# ---------------------------------------------------------------------------
# Mod_Cap_DeadEnd (8 x 2 x 10) : porte blindée verrouillée
# ---------------------------------------------------------------------------
def cap_dead_end():
    a = Asset("Mod_Cap_DeadEnd", "Cap", (8, 10, 2), {"RoomCategory": "Cap"})
    a.box("BlastDoor", "SteelPanel", (0, 5, 0), (8.2, 10.2, 1.2), panels=True)
    for i in range(5):
        a.neon_strip("Chevron", "NeonCrimson" if i % 2 == 0 else "NeonGold",
                     (-2.4 + i * 1.2, 1.4, -0.62), (0.35, 2.2, 0.05), (0, 0, 35))
    a.cyl("LockWheel", "DarkMetal", (0, 5.6, -0.75), 0.4, 3.0, (0, 90, 0), sides=8)
    a.cyl("LockCore", "NeonCrimson", (0, 5.6, -0.98), 0.1, 0.9, (0, 90, 0), NO_COLLIDE | NO_QUERY | LIGHT, sides=12)
    for sx in (-1, 1):
        a.box("CapFrame", "DarkMetal", (sx * 4.3, 5, 0), (0.6, 10.4, 1.6))
    a.box("CapHeader", "DarkMetal", (0, 10.2, 0), (9.2, 0.6, 1.6))
    a.marker("Connector", "Connector_Entry", (0, 5, 0), (0, 0, 0), (8, 10, 0.2), {"Side": "Entry"})
    a.marker("BoundingBox", "BoundingBox", (0, 5, 0), size=(7.6, 9.6, 1.6))
    return a


# ---------------------------------------------------------------------------
# Hub_Safehouse (48 x 48 x 16) : planque du joueur
# ---------------------------------------------------------------------------
def hub_safehouse():
    w = d = 48
    hh = 16
    a = Asset("Hub_Safehouse", "Hub", (w, hh, d), {"RoomCategory": "Hub"})
    room_shell(a, w, d, hh, set(), wall_mat="ConcreteWall", trim="NeonCrimson")
    # Terminal de contrats (nord) : console + carte holographique
    a.box("ContractDesk", "CarbonFiber", (0, 1.6, -18), (10, 3.2, 3))
    a.neon_strip("ContractDeskEdge", "NeonCrimson", (0, 3.22, -18), (10, 0.05, 3))
    a.vcyl("HoloProjector", "DarkMetal", (0, 3.5, -18), 0.6, 2.4, sides=8)
    a.vcyl("HoloCity", "HoloCyan", (0, 6.0, -18), 4.4, 6.0, NO_COLLIDE | NO_QUERY | LIGHT, sides=16)
    a.box("ContractScreen", "HoloCyan", (0, 9.5, -22.4), (14, 5, 0.1), flags=NO_COLLIDE | NO_QUERY, bevel=False)
    a.marker("ContractTerminal", "ContractTerminal", (0, 3.2, -16.3), (0, 180, 0))
    # Zone de minage AFK (ouest) : racks GPU + fauteuil
    for i, z in enumerate((-8, -2, 4)):
        a.box("MiningRack", "CarbonFiber", (-20, 4, z), (3, 8, 4.5))
        for k in range(6):
            a.neon_strip("GPUFan", "NeonGreen" if k % 2 else "NeonCyan", (-18.45, 1.5 + k * 1.15, z),
                         (0.05, 0.7, 3.6), light=(k == 3 and i == 1))
        a.marker("GPUSlot", f"GPUSlot_{i + 1}", (-18.2, 4, z), (0, -90, 0), attrs={"Index": i + 1})
    a.box("MiningChairBase", "DarkMetal", (-13, 0.8, -2), (2.4, 1.6, 2.4))
    a.box("MiningChairSeat", "Fabric", (-13, 2.0, -2), (2.6, 0.6, 2.6))
    a.box("MiningChairBack", "Fabric", (-14.1, 3.8, -2), (0.5, 3.4, 2.6))
    a.neon_strip("MiningChairTrim", "NeonGreen", (-13, 2.32, -2), (2.65, 0.05, 2.65))
    a.marker("MiningSeat", "MiningSeat", (-13, 2.3, -2), (0, -90, 0))
    a.box("MiningDesk", "CarbonFiber", (-10.4, 1.8, -2), (1.8, 3.6, 6))
    for k, z in enumerate((-4, -2, 0)):
        a.box("MiningScreen", "HoloCyan", (-10.4, 4.6, z), (0.1, 1.6, 1.8), (0, 0, 0),
              NO_COLLIDE | NO_QUERY, bevel=False)
    # Armurerie (est) : casiers + râtelier
    for k in range(5):
        a.box("Locker", "SteelPanel", (21.4, 4, -10 + k * 3.2), (2.2, 8, 3.0), panels=True)
        a.neon_strip("LockerLight", "NeonCyan", (20.28, 7.2, -10 + k * 3.2), (0.05, 0.25, 2.4))
    a.box("WeaponRack", "DarkMetal", (21.6, 5, 8), (1.4, 6, 8))
    for k in range(3):
        a.box("RackPeg", "NeonGold", (20.8, 3.6 + k * 1.6, 8), (0.3, 0.15, 7.2), bevel=False, flags=NO_COLLIDE)
    a.marker("Armory", "Armory", (19.0, 3, 0), (0, 90, 0))
    # Terminal d'améliorations (sud-est)
    a.box("UpgradeKiosk", "CarbonFiber", (14, 2.4, 17), (3, 4.8, 2))
    a.box("UpgradeScreen", "HoloCyan", (14, 3.4, 15.95), (2.6, 2.4, 0.05), flags=NO_COLLIDE | NO_QUERY | LIGHT, bevel=False)
    a.marker("UpgradeTerminal", "UpgradeTerminal", (14, 3, 15.6), (0, 0, 0))
    # Salon
    a.box("Couch", "Fabric", (-8, 1.0, 16), (8, 2.0, 3))
    a.box("CouchBack", "Fabric", (-8, 2.6, 17.4), (8, 3.2, 0.8))
    a.box("CoffeeTable", "Glass", (-8, 1.0, 12.5), (4, 0.2, 2.2), bevel=False)
    a.box("CoffeeTableBase", "DarkMetal", (-8, 0.45, 12.5), (3, 0.9, 1.4))
    a.box("NeonSignBack", "CarbonFiber", (0, 11, 22.9), (16, 3, 0.2), bevel=False)
    for k in range(4):
        a.neon_strip("NeonSign", ("NeonCrimson", "NeonCyan")[k % 2], (-5.5 + k * 3.7, 11, 22.75),
                     (3.0, 0.5 + (k % 2) * 0.4, 0.05), light=(k == 1))
    a.marker("PlayerSpawn", "PlayerSpawn_1", (0, 0.5, 8), (0, 180, 0))
    a.marker("PartyTerminal", "PartyTerminal", (6, 3, -16.3), (0, 180, 0))
    return a


ASSETS = [
    spawn_extraction(),
    hallway_straight(),
    hallway_corner(),
    hallway_tjunction(),
    server_farm(),
    security_hub(),
    executive_office(),
    high_tech_vault(),
    cap_dead_end(),
    hub_safehouse(),
]

if __name__ == "__main__":
    result = sbm_common.run_group("SBM_Architecture", "Architecture", "generate_architecture.py", "architecture",
                                  ASSETS)
