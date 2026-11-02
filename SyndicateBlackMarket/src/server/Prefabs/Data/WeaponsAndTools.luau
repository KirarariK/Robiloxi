--!strict
-- GÉNÉRÉ AUTOMATIQUEMENT par blender_scripts/generate_weapons_and_tools.py — ne pas modifier à la main.
-- Coordonnées en studs, pivot = centre du sol, rotations = CFrame.fromOrientation (degrés).

local PrefabTypes = require(script.Parent.Parent.PrefabTypes)

type AssetDefinition = PrefabTypes.AssetDefinition

local V = Vector3.new
local P = PrefabTypes.part
local M = PrefabTypes.marker

local assets: { AssetDefinition } = {
	{
		Name = "Weapon_USP_Tactical",
		Category = "Weapon",
		Folder = "Weapons",
		Bounds = V(0.3, 0.75, 2.1),
		Attributes = { WeaponId = "USP_Tactical" },
		Parts = {
			P("Box", "Handle", "CarbonFiber", V(0, -0.3, 0.28), V(0.2, 0.62, 0.3), V(-14, 0, 0), 1),
			P("Box", "Frame", "CarbonFiber", V(0, 0.02, -0.12), V(0.2, 0.16, 0.95), V(0, 0, 0), 9),
			P("Box", "Slide", "DarkMetal", V(0, 0.15, -0.1), V(0.21, 0.17, 1.05), V(0, 0, 0), 9),
			P("Box", "SlideSerration", "CarbonFiber", V(0, 0.16, 0.3), V(0.215, 0.12, 0.02), V(0, 0, 0), 9),
			P("Box", "SlideSerration_2", "CarbonFiber", V(0, 0.16, 0.24), V(0.215, 0.12, 0.02), V(0, 0, 0), 9),
			P("Box", "SlideSerration_3", "CarbonFiber", V(0, 0.16, 0.18), V(0.215, 0.12, 0.02), V(0, 0, 0), 9),
			P("Box", "SlideSerration_4", "CarbonFiber", V(0, 0.16, 0.12), V(0.215, 0.12, 0.02), V(0, 0, 0), 9),
			P("Box", "SlideSerration_5", "CarbonFiber", V(0, 0.16, 0.06), V(0.215, 0.12, 0.02), V(0, 0, 0), 9),
			P("Box", "TriggerGuard", "CarbonFiber", V(0, -0.12, -0.02), V(0.06, 0.04, 0.3), V(0, 0, 0), 9),
			P("Box", "Trigger", "SteelPanel", V(0, -0.08, 0.02), V(0.04, 0.12, 0.04), V(0, 0, 0), 9),
			P("Box", "Magazine", "SteelPanel", V(0, -0.62, 0.34), V(0.16, 0.12, 0.24), V(-14, 0, 0), 9),
			P("Cyl", "Suppressor", "DarkMetal", V(0, 0.13, -1.12), V(0.95, 0.24, 0.24), V(0, 90, 0), 9),
			P("Cyl", "SuppressorRing", "SteelPanel", V(0, 0.13, -0.72), V(0.05, 0.26, 0.26), V(0, 90, 0), 9),
			P("Cyl", "SuppressorRing_2", "SteelPanel", V(0, 0.13, -1.52), V(0.05, 0.26, 0.26), V(0, 90, 0), 9),
			P("Box", "RearSight", "NeonGreen", V(0, 0.25, 0.38), V(0.12, 0.04, 0.04), V(0, 0, 0), 9),
			P("Box", "FrontSight", "NeonGreen", V(0, 0.25, -0.58), V(0.04, 0.05, 0.04), V(0, 0, 0), 9),
			P("Box", "RailNeon", "NeonCyan", V(0.106, 0.02, -0.25), V(0.01, 0.03, 0.5), V(0, 0, 0), 9),
		},
		Markers = {
			M("Grip", "Grip", V(0, -0.25, 0.27), V(-14, 0, 0), V(1, 1, 1), nil),
			M("Muzzle", "Muzzle", V(0, 0.13, -1.62), V(0, 0, 0), V(1, 1, 1), nil),
			M("Sight", "Sight", V(0, 0.27, 0.38), V(0, 0, 0), V(1, 1, 1), nil),
		},
	},
	{
		Name = "Weapon_SubmachineGun",
		Category = "Weapon",
		Folder = "Weapons",
		Bounds = V(0.45, 1.2, 2.8),
		Attributes = { WeaponId = "SubmachineGun" },
		Parts = {
			P("Box", "Handle", "CarbonFiber", V(0, -0.32, 0.25), V(0.22, 0.6, 0.3), V(-12, 0, 0), 1),
			P("Box", "Receiver", "CarbonFiber", V(0, 0.05, -0.15), V(0.3, 0.4, 1.3), V(0, 0, 0), 9),
			P("Wedge", "LowerHousing", "DarkMetal", V(0, -0.3, -0.45), V(0.28, 0.5, 0.7), V(0, 0, 0), 9),
			P("Box", "TopRail", "DarkMetal", V(0, 0.3, -0.2), V(0.16, 0.08, 1.1), V(0, 0, 0), 9),
			P("Cyl", "Barrel", "DarkMetal", V(0, 0.05, -1.05), V(0.5, 0.14, 0.14), V(0, 90, 0), 9),
			P("Cyl", "Compensator", "SteelPanel", V(0, 0.05, -1.35), V(0.14, 0.2, 0.2), V(0, 90, 0), 9),
			P("Box", "Magazine", "SteelPanel", V(0, -0.55, -0.55), V(0.18, 0.7, 0.26), V(12, 0, 0), 9),
			P("Box", "StockArm", "DarkMetal", V(0.18, 0.02, 0.65), V(0.05, 0.1, 0.8), V(0, 0, 0), 9),
			P("Box", "StockPad", "Rubber", V(0.18, -0.02, 1.08), V(0.12, 0.35, 0.1), V(0, 0, 0), 9),
			P("Box", "HoloSightFrame", "DarkMetal", V(0, 0.48, 0.05), V(0.2, 0.26, 0.06), V(0, 0, 0), 9),
			P("Box", "HoloSightGlass", "HoloCyan", V(0, 0.47, 0.05), V(0.15, 0.18, 0.02), V(0, 0, 0), 11),
			P("Box", "HoloSightBase", "DarkMetal", V(0, 0.36, 0.05), V(0.18, 0.06, 0.3), V(0, 0, 0), 9),
			P("Box", "SideNeon", "NeonCrimson", V(0.155, 0.08, -0.2), V(0.01, 0.05, 0.9), V(0, 0, 0), 9),
			P("Box", "Trigger", "SteelPanel", V(0, -0.12, 0.05), V(0.04, 0.14, 0.04), V(0, 0, 0), 9),
		},
		Markers = {
			M("Grip", "Grip", V(0, -0.27, 0.24), V(-12, 0, 0), V(1, 1, 1), nil),
			M("Muzzle", "Muzzle", V(0, 0.05, -1.43), V(0, 0, 0), V(1, 1, 1), nil),
			M("Sight", "Sight", V(0, 0.47, 0.05), V(0, 0, 0), V(1, 1, 1), nil),
		},
	},
	{
		Name = "Tool_CyberDeck",
		Category = "Tool",
		Folder = "Weapons",
		Bounds = V(1.5, 1.1, 1.2),
		Attributes = { ToolId = "CyberDeck" },
		Parts = {
			P("Box", "Handle", "CarbonFiber", V(0, 0, 0), V(1.4, 0.18, 0.9), V(0, 0, 0), 1),
			P("Box", "KeyboardGlow", "NeonCyan", V(0, 0.095, 0.08), V(1.1, 0.02, 0.55), V(0, 0, 0), 9),
			P("Box", "KeyRow", "CarbonFiber", V(0, 0.11, -0.12), V(1.05, 0.02, 0.05), V(0, 0, 0), 9),
			P("Box", "KeyRow_2", "CarbonFiber", V(0, 0.11, 0.01), V(1.05, 0.02, 0.05), V(0, 0, 0), 9),
			P("Box", "KeyRow_3", "CarbonFiber", V(0, 0.11, 0.14), V(1.05, 0.02, 0.05), V(0, 0, 0), 9),
			P("Box", "KeyRow_4", "CarbonFiber", V(0, 0.11, 0.27), V(1.05, 0.02, 0.05), V(0, 0, 0), 9),
			P("Cyl", "Hinge", "DarkMetal", V(0, 0.1, -0.45), V(1.3, 0.12, 0.12), V(0, 0, 0), 9),
			P("Box", "ScreenShell", "DarkMetal", V(0, 0.5, -0.6), V(1.4, 0.8, 0.08), V(20, 0, 0), 9),
			P("Box", "Screen", "HoloCyan", V(0, 0.5, -0.55), V(1.25, 0.68, 0.02), V(20, 0, 0), 11),
			P("Cyl", "Antenna", "SteelPanel", V(-0.72, 0.45, -0.25), V(0.8, 0.05, 0.05), V(0, 0, 75), 9),
			P("Ball", "AntennaTip", "NeonCrimson", V(-0.82, 0.84, -0.25), V(0.1, 0.1, 0.1), V(0, 0, 0), 9),
			P("Cyl", "Antenna_2", "SteelPanel", V(0.72, 0.45, -0.25), V(0.8, 0.05, 0.05), V(0, 0, 75), 9),
			P("Ball", "AntennaTip_2", "NeonCrimson", V(0.82, 0.84, -0.25), V(0.1, 0.1, 0.1), V(0, 0, 0), 9),
		},
		Markers = {
			M("Grip", "Grip", V(0, -0.05, 0.3), V(0, 0, 0), V(1, 1, 1), nil),
		},
	},
	{
		Name = "Tool_EMP_Jammer",
		Category = "Tool",
		Folder = "Weapons",
		Bounds = V(1.4, 0.7, 1.4),
		Attributes = { ToolId = "EMP_Jammer" },
		Parts = {
			P("Cyl", "Handle", "DarkMetal", V(0, 0.12, 0), V(0.24, 1.3, 1.3), V(0, 0, 90), 1),
			P("Cyl", "Body", "CarbonFiber", V(0, 0.3, 0), V(0.2, 1.05, 1.05), V(0, 0, 90), 9),
			P("Cyl", "PulseRing", "NeonBlue", V(0, 0.27, 0), V(0.06, 1.36, 1.36), V(0, 0, 90), 11),
			P("Ball", "Dome", "HoloCyan", V(0, 0.42, 0), V(0.6, 0.6, 0.6), V(0, 0, 0), 9),
			P("Box", "Leg", "SteelPanel", V(0.6, 0.04, 0), V(0.35, 0.08, 0.15), V(0, 0, 0), 9),
			P("Box", "Leg_2", "SteelPanel", V(-0.3, 0.04, 0.52), V(0.35, 0.08, 0.15), V(0, -120, 0), 9),
			P("Box", "Leg_3", "SteelPanel", V(-0.3, 0.04, -0.52), V(0.35, 0.08, 0.15), V(0, -240, 0), 9),
			P("Box", "ArmLED", "NeonCrimson", V(0.5, 0.33, 0), V(0.06, 0.04, 0.06), V(0, 0, 0), 9),
		},
		Markers = {
			M("Grip", "Grip", V(0, 0.1, 0), V(0, 0, 0), V(1, 1, 1), nil),
		},
	},
}

return table.freeze(assets)
