--!strict
-- GÉNÉRÉ AUTOMATIQUEMENT par blender_scripts/sbm_common.py — ne pas modifier à la main.
-- Équivalents Studio des matériaux PBR Blender.

local PrefabTypes = require(script.Parent.Parent.PrefabTypes)

type MaterialDefinition = PrefabTypes.MaterialDefinition

local materials: { [string]: MaterialDefinition } = {
	CarbonFiber = { Color = Color3.fromHex("#111215"), Material = Enum.Material.Metal, Reflectance = 0.05, Transparency = 0, Emissive = false },
	CashGreen = { Color = Color3.fromHex("#3E7B4A"), Material = Enum.Material.Fabric, Reflectance = 0, Transparency = 0, Emissive = false },
	ConcreteFloor = { Color = Color3.fromHex("#26282E"), Material = Enum.Material.Concrete, Reflectance = 0, Transparency = 0, Emissive = false },
	ConcreteWall = { Color = Color3.fromHex("#3A3D44"), Material = Enum.Material.Concrete, Reflectance = 0, Transparency = 0, Emissive = false },
	DarkMetal = { Color = Color3.fromHex("#1A1D24"), Material = Enum.Material.DiamondPlate, Reflectance = 0.12, Transparency = 0, Emissive = false },
	Fabric = { Color = Color3.fromHex("#22262E"), Material = Enum.Material.Fabric, Reflectance = 0, Transparency = 0, Emissive = false },
	Glass = { Color = Color3.fromHex("#9FE8FF"), Material = Enum.Material.Glass, Reflectance = 0.2, Transparency = 0.65, Emissive = false },
	Grate = { Color = Color3.fromHex("#4A505C"), Material = Enum.Material.DiamondPlate, Reflectance = 0.1, Transparency = 0, Emissive = false },
	HoloCyan = { Color = Color3.fromHex("#00F0FF"), Material = Enum.Material.Neon, Reflectance = 0, Transparency = 0.55, Emissive = true },
	LaserRed = { Color = Color3.fromHex("#FF003C"), Material = Enum.Material.Neon, Reflectance = 0, Transparency = 0.6, Emissive = true },
	NeonBlue = { Color = Color3.fromHex("#2E6BFF"), Material = Enum.Material.Neon, Reflectance = 0, Transparency = 0, Emissive = true },
	NeonCrimson = { Color = Color3.fromHex("#FF003C"), Material = Enum.Material.Neon, Reflectance = 0, Transparency = 0, Emissive = true },
	NeonCyan = { Color = Color3.fromHex("#00F0FF"), Material = Enum.Material.Neon, Reflectance = 0, Transparency = 0, Emissive = true },
	NeonGold = { Color = Color3.fromHex("#FFD700"), Material = Enum.Material.Foil, Reflectance = 0.35, Transparency = 0, Emissive = false },
	NeonGreen = { Color = Color3.fromHex("#38FF8C"), Material = Enum.Material.Neon, Reflectance = 0, Transparency = 0, Emissive = true },
	Rubber = { Color = Color3.fromHex("#0A0A0C"), Material = Enum.Material.SmoothPlastic, Reflectance = 0, Transparency = 0, Emissive = false },
	SteelPanel = { Color = Color3.fromHex("#2C313B"), Material = Enum.Material.Metal, Reflectance = 0.08, Transparency = 0, Emissive = false },
	VanPaint = { Color = Color3.fromHex("#1F242C"), Material = Enum.Material.Metal, Reflectance = 0.1, Transparency = 0, Emissive = false },
	Wood = { Color = Color3.fromHex("#3B2A20"), Material = Enum.Material.WoodPlanks, Reflectance = 0, Transparency = 0, Emissive = false },
}

return table.freeze(materials)
