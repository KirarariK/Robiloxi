--!strict
-- GÉNÉRÉ AUTOMATIQUEMENT par blender_scripts/generate_props_and_loot.py — ne pas modifier à la main.
-- Coordonnées en studs, pivot = centre du sol, rotations = CFrame.fromOrientation (degrés).

local PrefabTypes = require(script.Parent.Parent.PrefabTypes)

type AssetDefinition = PrefabTypes.AssetDefinition

local V = Vector3.new
local P = PrefabTypes.part
local M = PrefabTypes.marker

local assets: { AssetDefinition } = {
	{
		Name = "Prop_SecurityCamera",
		Category = "Prop",
		Folder = "Props",
		Bounds = V(1.6, 1.6, 2.6),
		Attributes = { PropKind = "SecurityCamera" },
		Parts = {
			P("Box", "MountPlate", "DarkMetal", V(0, 0, 0.05), V(1.2, 1.2, 0.2), V(0, 0, 0), 0, "Cam_Mount"),
			P("Cyl", "MountArm", "SteelPanel", V(0, 0, -0.55), V(1, 0.3, 0.3), V(0, 90, 0), 0, "Cam_Mount"),
			P("Cyl", "MountJoint", "DarkMetal", V(0, 0, -1.05), V(0.5, 0.45, 0.45), V(0, 0, 90), 0, "Cam_Mount"),
			P("Box", "Housing", "CarbonFiber", V(0, 0, -1.6), V(0.8, 0.7, 1.4), V(0, 0, 0), 0, "Cam_Body"),
			P("Wedge", "Visor", "DarkMetal", V(0, 0.45, -1.75), V(0.85, 0.2, 1.3), V(0, 180, 0), 9, "Cam_Body"),
			P("Cyl", "LensRing", "DarkMetal", V(0, 0, -2.33), V(0.12, 0.6, 0.6), V(0, 90, 0), 9, "Cam_Body"),
			P("Cyl", "Lens", "NeonCrimson", V(0, 0, -2.4), V(0.05, 0.42, 0.42), V(0, 90, 0), 11, "Cam_Body"),
			P("Box", "StatusLED", "NeonGreen", V(0.28, -0.2, -2.31), V(0.08, 0.08, 0.02), V(0, 0, 0), 9, "Cam_Body"),
		},
		Markers = {
			M("Pivot", "Pivot", V(0, 0, -1.05), V(0, 0, 0), V(1, 1, 1), nil),
			M("Eye", "Eye", V(0, 0, -2.45), V(0, 0, 0), V(1, 1, 1), nil),
		},
	},
	{
		Name = "Prop_LaserBarrier",
		Category = "Prop",
		Folder = "Props",
		Bounds = V(0.8, 0.8, 12),
		Attributes = { BeamLength = 12, PropKind = "LaserBarrier" },
		Parts = {
			P("Cyl", "Emitter", "DarkMetal", V(0, 0, 0.25), V(0.5, 0.7, 0.7), V(0, 90, 0), 0),
			P("Cyl", "EmitterRing", "NeonCrimson", V(0, 0, -0.03), V(0.06, 0.55, 0.55), V(0, 90, 0), 9),
			P("Box", "WallBracket", "SteelPanel", V(0, 0, 0.55), V(0.9, 0.9, 0.1), V(0, 0, 0), 0),
			P("Box", "Beam", "LaserRed", V(0, 0, -6), V(0.12, 0.12, 12), V(0, 0, 0), 19),
		},
		Markers = {
			M("BeamOrigin", "BeamOrigin", V(0, 0, -0.05), V(0, 0, 0), V(1, 1, 1), nil),
		},
	},
	{
		Name = "Prop_HackTerminal",
		Category = "Prop",
		Folder = "Props",
		Bounds = V(1.8, 4.8, 1.4),
		Attributes = { PropKind = "HackTerminal" },
		Parts = {
			P("Box", "Foot", "DarkMetal", V(0, 0.15, 0), V(1.6, 0.3, 1.2), V(0, 0, 0), 0),
			P("Box", "Post", "SteelPanel", V(0, 1.6, 0.2), V(0.6, 2.6, 0.5), V(0, 0, 0), 0),
			P("Box", "Console", "CarbonFiber", V(0, 3, -0.1), V(1.6, 0.3, 1.1), V(-25, 0, 0), 0),
			P("Box", "Keyboard", "NeonCyan", V(0, 3.17, -0.14), V(1.2, 0.04, 0.6), V(-25, 0, 0), 9),
			P("Box", "KeyRow", "CarbonFiber", V(0, 3.2, -0.38), V(1.1, 0.03, 0.04), V(-25, 0, 0), 9),
			P("Box", "KeyRow_2", "CarbonFiber", V(0, 3.2, -0.22), V(1.1, 0.03, 0.04), V(-25, 0, 0), 9),
			P("Box", "KeyRow_3", "CarbonFiber", V(0, 3.2, -0.06), V(1.1, 0.03, 0.04), V(-25, 0, 0), 9),
			P("Box", "KeyRow_4", "CarbonFiber", V(0, 3.2, 0.1), V(1.1, 0.03, 0.04), V(-25, 0, 0), 9),
			P("Box", "ScreenFrame", "DarkMetal", V(0, 4, 0.25), V(1.6, 1.1, 0.12), V(10, 0, 0), 0),
			P("Box", "HoloScreen", "HoloCyan", V(0, 4.05, 0.18), V(1.4, 0.9, 0.04), V(10, 0, 0), 11),
		},
		Markers = {
			M("Interact", "Interact", V(0, 3.2, -0.7), V(0, 0, 0), V(1, 1, 1), nil),
		},
	},
	{
		Name = "Prop_LootBag",
		Category = "Prop",
		Folder = "Props",
		Bounds = V(2.6, 1.4, 1.4),
		Attributes = { PropKind = "LootBag" },
		Parts = {
			P("Cyl", "BagBody", "Fabric", V(0, 0.7, 0), V(2.4, 1.3, 1.3), V(0, 0, 0), 0),
			P("Cyl", "BagEnd", "DarkMetal", V(-1.15, 0.7, 0), V(0.12, 1.32, 1.32), V(0, 0, 0), 9),
			P("Cyl", "BagEnd_2", "DarkMetal", V(1.15, 0.7, 0), V(0.12, 1.32, 1.32), V(0, 0, 0), 9),
			P("Cyl", "Strap", "Rubber", V(-0.6, 0.7, 0), V(0.18, 1.36, 1.36), V(0, 0, 0), 9),
			P("Box", "Buckle", "NeonGold", V(-0.6, 0.7, -0.68), V(0.22, 0.18, 0.04), V(0, 0, 0), 9),
			P("Cyl", "Strap_2", "Rubber", V(0.6, 0.7, 0), V(0.18, 1.36, 1.36), V(0, 0, 0), 9),
			P("Box", "Buckle_2", "NeonGold", V(0.6, 0.7, -0.68), V(0.22, 0.18, 0.04), V(0, 0, 0), 9),
			P("Box", "Zipper", "SteelPanel", V(0, 1.37, 0), V(2, 0.06, 0.12), V(0, 0, 0), 9),
			P("Box", "Handle", "Rubber", V(0, 1.55, 0), V(1, 0.12, 0.2), V(0, 0, 0), 1),
			P("Box", "HandleLoop", "Rubber", V(-0.45, 1.45, 0), V(0.12, 0.25, 0.2), V(0, 0, 0), 9),
			P("Box", "HandleLoop_2", "Rubber", V(0.45, 1.45, 0), V(0.12, 0.25, 0.2), V(0, 0, 0), 9),
			P("Box", "ReflectiveTag", "NeonCyan", V(0.8, 0.95, -0.66), V(0.3, 0.18, 0.02), V(0, 0, 0), 9),
		},
		Markers = {
			M("BackAttach", "BackAttach", V(0, 0.7, 0.7), V(0, 0, 90), V(1, 1, 1), nil),
		},
	},
	{
		Name = "Loot_CashBundle",
		Category = "Loot",
		Folder = "Loot",
		Bounds = V(1.3, 0.7, 0.7),
		Attributes = { LootId = "CashBundle" },
		Parts = {
			P("Box", "Bills", "CashGreen", V(0, 0.08, 0), V(1.2, 0.15, 0.6), V(0, -2, 0), 0),
			P("Box", "Bills_2", "CashGreen", V(0, 0.24, 0), V(1.2, 0.15, 0.6), V(0, 2, 0), 0),
			P("Box", "Bills_3", "CashGreen", V(0, 0.4, 0), V(1.2, 0.15, 0.6), V(0, -2, 0), 0),
			P("Box", "Bills_4", "CashGreen", V(0, 0.56, 0), V(1.2, 0.15, 0.6), V(0, 2, 0), 0),
			P("Box", "Band", "NeonGold", V(0, 0.33, 0), V(0.18, 0.66, 0.64), V(0, 0, 0), 0),
			P("Box", "BandSeal", "NeonCrimson", V(0, 0.4, -0.33), V(0.12, 0.12, 0.02), V(0, 0, 0), 9),
		},
		Markers = {
		},
	},
	{
		Name = "Loot_EncryptedDrive",
		Category = "Loot",
		Folder = "Loot",
		Bounds = V(1, 0.4, 0.7),
		Attributes = { LootId = "EncryptedDrive" },
		Parts = {
			P("Box", "Shell", "CarbonFiber", V(0, 0.18, 0), V(1, 0.36, 0.7), V(0, 0, 0), 0),
			P("Box", "Bumper", "Rubber", V(-0.47, 0.18, 0), V(0.12, 0.42, 0.74), V(0, 0, 0), 0),
			P("Box", "Bumper_2", "Rubber", V(0.47, 0.18, 0), V(0.12, 0.42, 0.74), V(0, 0, 0), 0),
			P("Box", "Label", "SteelPanel", V(0, 0.365, 0.05), V(0.6, 0.01, 0.4), V(0, 0, 0), 9),
			P("Box", "LED", "NeonBlue", V(0.3, 0.37, -0.25), V(0.08, 0.02, 0.08), V(0, 0, 0), 11),
			P("Box", "Port", "DarkMetal", V(0, 0.18, -0.36), V(0.3, 0.1, 0.02), V(0, 0, 0), 9),
		},
		Markers = {
		},
	},
	{
		Name = "Loot_GoldBullion",
		Category = "Loot",
		Folder = "Loot",
		Bounds = V(1.6, 0.8, 0.8),
		Attributes = { LootId = "GoldBullion" },
		Parts = {
			P("Box", "Bar", "NeonGold", V(-0.38, 0.18, 0), V(0.7, 0.34, 0.75), V(0, 0, 0), 0),
			P("Wedge", "BarBevelL", "NeonGold", V(-0.38, 0.38, -0.3), V(0.62, 0.06, 0.12), V(0, 180, 0), 9),
			P("Box", "Engraving", "NeonCyan", V(-0.38, 0.352, 0.05), V(0.4, 0.01, 0.06), V(0, 0, 0), 9),
			P("Box", "Bar_2", "NeonGold", V(0.38, 0.18, 0), V(0.7, 0.34, 0.75), V(0, 0, 0), 0),
			P("Wedge", "BarBevelL_2", "NeonGold", V(0.38, 0.38, -0.3), V(0.62, 0.06, 0.12), V(0, 180, 0), 9),
			P("Box", "Engraving_2", "NeonCyan", V(0.38, 0.352, 0.05), V(0.4, 0.01, 0.06), V(0, 0, 0), 9),
			P("Box", "Bar_3", "NeonGold", V(0, 0.54, 0), V(0.7, 0.34, 0.75), V(0, 0, 0), 0),
			P("Wedge", "BarBevelL_3", "NeonGold", V(0, 0.74, -0.3), V(0.62, 0.06, 0.12), V(0, 180, 0), 9),
			P("Box", "Engraving_3", "NeonCyan", V(0, 0.712, 0.05), V(0.4, 0.01, 0.06), V(0, 0, 0), 9),
		},
		Markers = {
		},
	},
	{
		Name = "Loot_PrototypeWeaponCase",
		Category = "Loot",
		Folder = "Loot",
		Bounds = V(3.2, 0.8, 1.2),
		Attributes = { LootId = "PrototypeWeaponCase" },
		Parts = {
			P("Box", "CaseBody", "CarbonFiber", V(0, 0.35, 0), V(3.2, 0.7, 1.1), V(0, 0, 0), 0),
			P("Box", "CaseLid", "CarbonFiber", V(0, 0.72, 0), V(3.1, 0.08, 1), V(0, 0, 0), 9),
			P("Box", "Latch", "DarkMetal", V(-1, 0.45, -0.57), V(0.35, 0.25, 0.08), V(0, 0, 0), 9),
			P("Box", "LatchNeon", "NeonCyan", V(-1, 0.45, -0.62), V(0.22, 0.06, 0.02), V(0, 0, 0), 9),
			P("Box", "Latch_2", "DarkMetal", V(1, 0.45, -0.57), V(0.35, 0.25, 0.08), V(0, 0, 0), 9),
			P("Box", "LatchNeon_2", "NeonCyan", V(1, 0.45, -0.62), V(0.22, 0.06, 0.02), V(0, 0, 0), 9),
			P("Box", "CaseHandle", "Rubber", V(0, 0.45, -0.66), V(0.8, 0.12, 0.12), V(0, 0, 0), 9),
			P("Box", "Stripe", "NeonCrimson", V(0, 0.765, 0), V(2.8, 0.01, 0.08), V(0, 0, 0), 9),
		},
		Markers = {
		},
	},
	{
		Name = "Loot_QuantumCore",
		Category = "Loot",
		Folder = "Loot",
		Bounds = V(1.8, 2.2, 1.8),
		Attributes = { LootId = "QuantumCore" },
		Parts = {
			P("Cyl", "CageBase", "DarkMetal", V(0, 0.15, 0), V(0.3, 1.8, 1.8), V(0, 0, 90), 0),
			P("Cyl", "CageTop", "DarkMetal", V(0, 2.05, 0), V(0.3, 1.8, 1.8), V(0, 0, 90), 0),
			P("Cyl", "CageBar", "SteelPanel", V(0.721, 1.1, 0.298), V(1.6, 0.12, 0.12), V(0, 0, 90), 9),
			P("Cyl", "CageBar_2", "SteelPanel", V(0.298, 1.1, 0.721), V(1.6, 0.12, 0.12), V(0, 0, 90), 9),
			P("Cyl", "CageBar_3", "SteelPanel", V(-0.298, 1.1, 0.721), V(1.6, 0.12, 0.12), V(0, 0, 90), 9),
			P("Cyl", "CageBar_4", "SteelPanel", V(-0.721, 1.1, 0.298), V(1.6, 0.12, 0.12), V(0, 0, 90), 9),
			P("Cyl", "CageBar_5", "SteelPanel", V(-0.721, 1.1, -0.298), V(1.6, 0.12, 0.12), V(0, 0, 90), 9),
			P("Cyl", "CageBar_6", "SteelPanel", V(-0.298, 1.1, -0.721), V(1.6, 0.12, 0.12), V(0, 0, 90), 9),
			P("Cyl", "CageBar_7", "SteelPanel", V(0.298, 1.1, -0.721), V(1.6, 0.12, 0.12), V(0, 0, 90), 9),
			P("Cyl", "CageBar_8", "SteelPanel", V(0.721, 1.1, -0.298), V(1.6, 0.12, 0.12), V(0, 0, 90), 9),
			P("Cyl", "MagRing", "NeonBlue", V(0, 0.32, 0), V(0.06, 1.7, 1.7), V(0, 0, 90), 9),
			P("Cyl", "MagRing_2", "NeonBlue", V(0, 1.88, 0), V(0.06, 1.7, 1.7), V(0, 0, 90), 9),
			P("Ball", "Core", "HoloCyan", V(0, 1.1, 0), V(0.9, 0.9, 0.9), V(0, 0, 0), 11),
			P("Ball", "CoreInner", "NeonCyan", V(0, 1.1, 0), V(0.45, 0.45, 0.45), V(0, 0, 0), 9),
		},
		Markers = {
		},
	},
}

return table.freeze(assets)
