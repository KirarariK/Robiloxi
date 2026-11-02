"""
generate_props_and_loot.py — props de sécurité, sac de butin et 5 tiers de butin.

Pivot = point de pose au sol (Y = 0) sauf mention contraire :
  * Prop_SecurityCamera : pivot = point de fixation murale, groupes Cam_Mount / Cam_Body
    (Cam_Body pivote autour de l'attache « Pivot »).
  * Prop_LaserBarrier   : pivot = centre de l'émetteur, faisceau le long de -Z (LookVector).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402

import sbm_common  # noqa: E402

importlib.reload(sbm_common)
from sbm_common import BEAM, LIGHT, NO_COLLIDE, NO_QUERY, Asset  # noqa: E402

DETAIL = NO_COLLIDE | NO_QUERY


def security_camera():
    a = Asset("Prop_SecurityCamera", "Prop", (1.6, 1.6, 2.6), {"PropKind": "SecurityCamera"})
    # Cam_Mount : platine murale + bras
    a.box("MountPlate", "DarkMetal", (0, 0, 0.05), (1.2, 1.2, 0.2), group="Cam_Mount")
    a.cyl("MountArm", "SteelPanel", (0, 0, -0.55), 1.0, 0.3, (0, 90, 0), group="Cam_Mount", sides=10)
    a.vcyl("MountJoint", "DarkMetal", (0, 0, -1.05), 0.5, 0.45, group="Cam_Mount", sides=10)
    # Cam_Body : boîtier pivotant + lentille émissive
    a.box("Housing", "CarbonFiber", (0, 0, -1.6), (0.8, 0.7, 1.4), group="Cam_Body")
    a.wedge("Visor", "DarkMetal", (0, 0.45, -1.75), (0.85, 0.2, 1.3), (0, 180, 0), DETAIL, group="Cam_Body")
    a.cyl("LensRing", "DarkMetal", (0, 0, -2.33), 0.12, 0.6, (0, 90, 0), DETAIL, group="Cam_Body", sides=16)
    a.cyl("Lens", "NeonCrimson", (0, 0, -2.4), 0.05, 0.42, (0, 90, 0), DETAIL | LIGHT, group="Cam_Body", sides=16)
    a.detail("StatusLED", "NeonGreen", (0.28, -0.2, -2.31), (0.08, 0.08, 0.02), group="Cam_Body")
    a.marker("Pivot", "Pivot", (0, 0, -1.05))
    a.marker("Eye", "Eye", (0, 0, -2.45))
    return a


def laser_barrier():
    a = Asset("Prop_LaserBarrier", "Prop", (0.8, 0.8, 12), {"PropKind": "LaserBarrier", "BeamLength": 12})
    a.cyl("Emitter", "DarkMetal", (0, 0, 0.25), 0.5, 0.7, (0, 90, 0), sides=12)
    a.cyl("EmitterRing", "NeonCrimson", (0, 0, -0.03), 0.06, 0.55, (0, 90, 0), DETAIL, sides=12)
    a.box("WallBracket", "SteelPanel", (0, 0, 0.55), (0.9, 0.9, 0.1), bevel=False)
    a.box("Beam", "LaserRed", (0, 0, -6.0), (0.12, 0.12, 12.0), flags=NO_COLLIDE | BEAM | LIGHT, bevel=False)
    a.marker("BeamOrigin", "BeamOrigin", (0, 0, -0.05))
    return a


def hack_terminal():
    a = Asset("Prop_HackTerminal", "Prop", (1.8, 4.8, 1.4), {"PropKind": "HackTerminal"})
    a.box("Foot", "DarkMetal", (0, 0.15, 0), (1.6, 0.3, 1.2))
    a.box("Post", "SteelPanel", (0, 1.6, 0.2), (0.6, 2.6, 0.5))
    a.box("Console", "CarbonFiber", (0, 3.0, -0.1), (1.6, 0.3, 1.1), (-25, 0, 0))
    a.detail("Keyboard", "NeonCyan", (0, 3.17, -0.14), (1.2, 0.04, 0.6), (-25, 0, 0))
    for i in range(4):
        a.detail("KeyRow", "CarbonFiber", (0, 3.2, -0.38 + i * 0.16), (1.1, 0.03, 0.04), (-25, 0, 0))
    a.box("ScreenFrame", "DarkMetal", (0, 4.0, 0.25), (1.6, 1.1, 0.12), (10, 0, 0))
    a.box("HoloScreen", "HoloCyan", (0, 4.05, 0.18), (1.4, 0.9, 0.04), (10, 0, 0), DETAIL | LIGHT, bevel=False)
    a.marker("Interact", "Interact", (0, 3.2, -0.7))
    return a


def loot_bag():
    a = Asset("Prop_LootBag", "Prop", (2.6, 1.4, 1.4), {"PropKind": "LootBag"})
    a.cyl("BagBody", "Fabric", (0, 0.7, 0), 2.4, 1.3, sides=12)
    for x in (-1.15, 1.15):
        a.cyl("BagEnd", "DarkMetal", (x, 0.7, 0), 0.12, 1.32, flags=DETAIL, sides=12)
    for x in (-0.6, 0.6):
        a.cyl("Strap", "Rubber", (x, 0.7, 0), 0.18, 1.36, flags=DETAIL, sides=12)
        a.detail("Buckle", "NeonGold", (x, 0.7, -0.68), (0.22, 0.18, 0.04))
    a.box("Zipper", "SteelPanel", (0, 1.37, 0), (2.0, 0.06, 0.12), flags=DETAIL, bevel=False)
    a.box("Handle", "Rubber", (0, 1.55, 0), (1.0, 0.12, 0.2), flags=NO_COLLIDE, bevel=False)
    for x in (-0.45, 0.45):
        a.box("HandleLoop", "Rubber", (x, 1.45, 0), (0.12, 0.25, 0.2), flags=DETAIL, bevel=False)
    a.detail("ReflectiveTag", "NeonCyan", (0.8, 0.95, -0.66), (0.3, 0.18, 0.02))
    a.marker("BackAttach", "BackAttach", (0, 0.7, 0.7), (0, 0, 90))
    return a


def cash_bundle():
    a = Asset("Loot_CashBundle", "Loot", (1.3, 0.7, 0.7), {"LootId": "CashBundle"})
    for i in range(4):
        a.box("Bills", "CashGreen", (0, 0.08 + i * 0.16, 0), (1.2, 0.15, 0.6), (0, (i % 2) * 4 - 2, 0), bevel=False)
    a.box("Band", "NeonGold", (0, 0.33, 0), (0.18, 0.66, 0.64), bevel=False)
    a.detail("BandSeal", "NeonCrimson", (0, 0.4, -0.33), (0.12, 0.12, 0.02))
    return a


def encrypted_drive():
    a = Asset("Loot_EncryptedDrive", "Loot", (1.0, 0.4, 0.7), {"LootId": "EncryptedDrive"})
    a.box("Shell", "CarbonFiber", (0, 0.18, 0), (1.0, 0.36, 0.7))
    for sx in (-1, 1):
        a.box("Bumper", "Rubber", (sx * 0.47, 0.18, 0), (0.12, 0.42, 0.74), bevel=False)
    a.detail("Label", "SteelPanel", (0, 0.365, 0.05), (0.6, 0.01, 0.4))
    a.box("LED", "NeonBlue", (0.3, 0.37, -0.25), (0.08, 0.02, 0.08), flags=DETAIL | LIGHT, bevel=False)
    a.detail("Port", "DarkMetal", (0, 0.18, -0.36), (0.3, 0.1, 0.02))
    return a


def gold_bullion():
    a = Asset("Loot_GoldBullion", "Loot", (1.6, 0.8, 0.8), {"LootId": "GoldBullion"})
    for x, y in ((-0.38, 0.18), (0.38, 0.18), (0, 0.54)):
        a.box("Bar", "NeonGold", (x, y, 0), (0.7, 0.34, 0.75))
        a.wedge("BarBevelL", "NeonGold", (x, y + 0.2, -0.3), (0.62, 0.06, 0.12), (0, 180, 0), DETAIL)
        a.detail("Engraving", "NeonCyan", (x, y + 0.172, 0.05), (0.4, 0.01, 0.06))
    return a


def prototype_case():
    a = Asset("Loot_PrototypeWeaponCase", "Loot", (3.2, 0.8, 1.2), {"LootId": "PrototypeWeaponCase"})
    a.box("CaseBody", "CarbonFiber", (0, 0.35, 0), (3.2, 0.7, 1.1))
    a.box("CaseLid", "CarbonFiber", (0, 0.72, 0), (3.1, 0.08, 1.0), flags=DETAIL, bevel=False)
    for x in (-1.0, 1.0):
        a.box("Latch", "DarkMetal", (x, 0.45, -0.57), (0.35, 0.25, 0.08), flags=DETAIL, bevel=False)
        a.detail("LatchNeon", "NeonCyan", (x, 0.45, -0.62), (0.22, 0.06, 0.02))
    a.box("CaseHandle", "Rubber", (0, 0.45, -0.66), (0.8, 0.12, 0.12), flags=DETAIL, bevel=False)
    a.detail("Stripe", "NeonCrimson", (0, 0.765, 0), (2.8, 0.01, 0.08))
    return a


def quantum_core():
    a = Asset("Loot_QuantumCore", "Loot", (1.8, 2.2, 1.8), {"LootId": "QuantumCore"})
    a.vcyl("CageBase", "DarkMetal", (0, 0.15, 0), 0.3, 1.8, sides=8)
    a.vcyl("CageTop", "DarkMetal", (0, 2.05, 0), 0.3, 1.8, sides=8)
    for i in range(8):
        ang = math.radians(i * 45 + 22.5)
        a.vcyl("CageBar", "SteelPanel", (math.cos(ang) * 0.78, 1.1, math.sin(ang) * 0.78), 1.6, 0.12,
               flags=DETAIL, sides=6)
    for y in (0.32, 1.88):
        a.vcyl("MagRing", "NeonBlue", (0, y, 0), 0.06, 1.7, flags=DETAIL, sides=8)
    a.ball("Core", "HoloCyan", (0, 1.1, 0), 0.9, flags=DETAIL | LIGHT)
    a.ball("CoreInner", "NeonCyan", (0, 1.1, 0), 0.45, flags=DETAIL)
    return a


ASSETS = [
    security_camera(),
    laser_barrier(),
    hack_terminal(),
    loot_bag(),
    cash_bundle(),
    encrypted_drive(),
    gold_bullion(),
    prototype_case(),
    quantum_core(),
]

if __name__ == "__main__":
    result = sbm_common.run_group("SBM_PropsLoot", "PropsAndLoot", "generate_props_and_loot.py", "props_loot",
                                  ASSETS, spacing=2.0)
