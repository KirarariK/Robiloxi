"""
generate_weapons_and_tools.py — armes et outils (échelle personnage R15 : ~1 stud = 0,36 m).

Chaque arme contient une pièce « Handle » (poignée) : ProceduralPrefabBuilder en fait un
Tool dont toutes les pièces sont soudées au Handle. Marqueurs :
  * Grip   : point de prise en main (Tool.Grip calculé depuis ce marqueur) ;
  * Muzzle : bouche du canon, LookVector = direction de tir (-Z) ;
  * Sight  : point de visée (ADS).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402

import sbm_common  # noqa: E402

importlib.reload(sbm_common)
from sbm_common import LIGHT, NO_COLLIDE, NO_QUERY, Asset  # noqa: E402

DETAIL = NO_COLLIDE | NO_QUERY


def usp_tactical():
    a = Asset("Weapon_USP_Tactical", "Weapon", (0.3, 0.75, 2.1), {"WeaponId": "USP_Tactical"})
    a.box("Handle", "CarbonFiber", (0, -0.3, 0.28), (0.2, 0.62, 0.3), (-14, 0, 0), NO_COLLIDE)
    a.box("Frame", "CarbonFiber", (0, 0.02, -0.12), (0.2, 0.16, 0.95), flags=DETAIL)
    a.box("Slide", "DarkMetal", (0, 0.15, -0.1), (0.21, 0.17, 1.05), flags=DETAIL)
    for i in range(5):
        a.detail("SlideSerration", "CarbonFiber", (0, 0.16, 0.3 - i * 0.06), (0.215, 0.12, 0.02))
    a.box("TriggerGuard", "CarbonFiber", (0, -0.12, -0.02), (0.06, 0.04, 0.3), flags=DETAIL, bevel=False)
    a.detail("Trigger", "SteelPanel", (0, -0.08, 0.02), (0.04, 0.12, 0.04))
    a.box("Magazine", "SteelPanel", (0, -0.62, 0.34), (0.16, 0.12, 0.24), (-14, 0, 0), DETAIL, bevel=False)
    a.cyl("Suppressor", "DarkMetal", (0, 0.13, -1.12), 0.95, 0.24, (0, 90, 0), DETAIL, sides=16)
    for z in (-0.72, -1.52):
        a.cyl("SuppressorRing", "SteelPanel", (0, 0.13, z), 0.05, 0.26, (0, 90, 0), DETAIL, sides=16)
    a.detail("RearSight", "NeonGreen", (0, 0.25, 0.38), (0.12, 0.04, 0.04))
    a.detail("FrontSight", "NeonGreen", (0, 0.25, -0.58), (0.04, 0.05, 0.04))
    a.detail("RailNeon", "NeonCyan", (0.106, 0.02, -0.25), (0.01, 0.03, 0.5))
    a.marker("Grip", "Grip", (0, -0.25, 0.27), (-14, 0, 0))
    a.marker("Muzzle", "Muzzle", (0, 0.13, -1.62))
    a.marker("Sight", "Sight", (0, 0.27, 0.38))
    return a


def submachine_gun():
    a = Asset("Weapon_SubmachineGun", "Weapon", (0.45, 1.2, 2.8), {"WeaponId": "SubmachineGun"})
    a.box("Handle", "CarbonFiber", (0, -0.32, 0.25), (0.22, 0.6, 0.3), (-12, 0, 0), NO_COLLIDE)
    a.box("Receiver", "CarbonFiber", (0, 0.05, -0.15), (0.3, 0.4, 1.3), flags=DETAIL)
    a.wedge("LowerHousing", "DarkMetal", (0, -0.3, -0.45), (0.28, 0.5, 0.7), (0, 0, 0), DETAIL)
    a.box("TopRail", "DarkMetal", (0, 0.3, -0.2), (0.16, 0.08, 1.1), flags=DETAIL, bevel=False)
    a.cyl("Barrel", "DarkMetal", (0, 0.05, -1.05), 0.5, 0.14, (0, 90, 0), DETAIL, sides=12)
    a.cyl("Compensator", "SteelPanel", (0, 0.05, -1.35), 0.14, 0.2, (0, 90, 0), DETAIL, sides=8)
    a.box("Magazine", "SteelPanel", (0, -0.55, -0.55), (0.18, 0.7, 0.26), (12, 0, 0), DETAIL, bevel=False)
    a.box("StockArm", "DarkMetal", (0.18, 0.02, 0.65), (0.05, 0.1, 0.8), flags=DETAIL, bevel=False)
    a.box("StockPad", "Rubber", (0.18, -0.02, 1.08), (0.12, 0.35, 0.1), flags=DETAIL, bevel=False)
    a.box("HoloSightFrame", "DarkMetal", (0, 0.48, 0.05), (0.2, 0.26, 0.06), flags=DETAIL, bevel=False)
    a.box("HoloSightGlass", "HoloCyan", (0, 0.47, 0.05), (0.15, 0.18, 0.02), flags=DETAIL | LIGHT, bevel=False)
    a.detail("HoloSightBase", "DarkMetal", (0, 0.36, 0.05), (0.18, 0.06, 0.3))
    a.detail("SideNeon", "NeonCrimson", (0.155, 0.08, -0.2), (0.01, 0.05, 0.9))
    a.detail("Trigger", "SteelPanel", (0, -0.12, 0.05), (0.04, 0.14, 0.04))
    a.marker("Grip", "Grip", (0, -0.27, 0.24), (-12, 0, 0))
    a.marker("Muzzle", "Muzzle", (0, 0.05, -1.43))
    a.marker("Sight", "Sight", (0, 0.47, 0.05))
    return a


def cyber_deck():
    a = Asset("Tool_CyberDeck", "Tool", (1.5, 1.1, 1.2), {"ToolId": "CyberDeck"})
    a.box("Handle", "CarbonFiber", (0, 0, 0), (1.4, 0.18, 0.9), flags=NO_COLLIDE)
    a.detail("KeyboardGlow", "NeonCyan", (0, 0.095, 0.08), (1.1, 0.02, 0.55))
    for r in range(4):
        a.detail("KeyRow", "CarbonFiber", (0, 0.11, -0.12 + r * 0.13), (1.05, 0.02, 0.05))
    # Écran rabattable (ouvert à ~110°) avec charnière
    a.cyl("Hinge", "DarkMetal", (0, 0.1, -0.45), 1.3, 0.12, (0, 0, 0), DETAIL, sides=10)
    a.box("ScreenShell", "DarkMetal", (0, 0.5, -0.6), (1.4, 0.8, 0.08), (20, 0, 0), DETAIL)
    a.box("Screen", "HoloCyan", (0, 0.5, -0.55), (1.25, 0.68, 0.02), (20, 0, 0), DETAIL | LIGHT, bevel=False)
    for sx in (-1, 1):
        a.cyl("Antenna", "SteelPanel", (sx * 0.72, 0.45, -0.25), 0.8, 0.05, (0, 0, 75), DETAIL, sides=6)
        a.ball("AntennaTip", "NeonCrimson", (sx * 0.82, 0.84, -0.25), 0.1, flags=DETAIL)
    a.marker("Grip", "Grip", (0, -0.05, 0.3))
    return a


def emp_jammer():
    a = Asset("Tool_EMP_Jammer", "Tool", (1.4, 0.7, 1.4), {"ToolId": "EMP_Jammer"})
    a.vcyl("Handle", "DarkMetal", (0, 0.12, 0), 0.24, 1.3, flags=NO_COLLIDE, sides=12)
    a.vcyl("Body", "CarbonFiber", (0, 0.3, 0), 0.2, 1.05, flags=DETAIL, sides=12)
    a.vcyl("PulseRing", "NeonBlue", (0, 0.27, 0), 0.06, 1.36, flags=DETAIL | LIGHT, sides=24)
    a.ball("Dome", "HoloCyan", (0, 0.42, 0), 0.6, flags=DETAIL)
    for i in range(3):
        ang = math.radians(i * 120)
        a.box("Leg", "SteelPanel", (math.cos(ang) * 0.6, 0.04, math.sin(ang) * 0.6), (0.35, 0.08, 0.15),
              (0, -i * 120, 0), DETAIL, bevel=False)
    a.detail("ArmLED", "NeonCrimson", (0.5, 0.33, 0), (0.06, 0.04, 0.06))
    a.marker("Grip", "Grip", (0, 0.1, 0))
    return a


ASSETS = [usp_tactical(), submachine_gun(), cyber_deck(), emp_jammer()]

if __name__ == "__main__":
    result = sbm_common.run_group("SBM_WeaponsTools", "WeaponsAndTools", "generate_weapons_and_tools.py",
                                  "weapons_tools", ASSETS, spacing=1.0)
