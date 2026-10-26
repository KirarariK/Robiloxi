--!strict
--[[
	Identité visuelle Blade Concord — couleurs, typos, accents factions.
	Pas de lexique Star Wars ; palette énergie / aube / crépuscule.
]]

local Theme = {
	Brand = "Blade Concord",

	-- Palette
	Ink = Color3.fromRGB(12, 14, 22),
	InkSoft = Color3.fromRGB(22, 26, 38),
	Panel = Color3.fromRGB(18, 22, 34),
	PanelEdge = Color3.fromRGB(70, 90, 120),
	Bone = Color3.fromRGB(236, 240, 248),
	Muted = Color3.fromRGB(150, 162, 184),
	Accent = Color3.fromRGB(88, 196, 255), -- lame aube / énergie
	AccentHot = Color3.fromRGB(255, 168, 72),
	Danger = Color3.fromRGB(232, 72, 86),
	Stamina = Color3.fromRGB(56, 176, 220),
	Focus = Color3.fromRGB(168, 120, 255),
	Perfect = Color3.fromRGB(255, 226, 110),
	Success = Color3.fromRGB(96, 230, 168),
	Dawn = Color3.fromRGB(255, 196, 120),
	Dusk = Color3.fromRGB(140, 100, 220),
	Clash = Color3.fromRGB(210, 230, 255),

	BladeIdle = Color3.fromRGB(120, 210, 255),
	BladeGuard = Color3.fromRGB(90, 170, 255),
	BladeStartup = Color3.fromRGB(255, 220, 110),
	BladeActive = Color3.fromRGB(255, 90, 90),
	BladeRecovery = Color3.fromRGB(170, 180, 190),
	BladeDodge = Color3.fromRGB(100, 255, 210),
	BladeDash = Color3.fromRGB(255, 180, 90),
	BladeFocus = Color3.fromRGB(180, 130, 255),
	BladeDead = Color3.fromRGB(40, 44, 52),

	FontTitle = Enum.Font.GothamBlack,
	FontBody = Enum.Font.GothamMedium,
	FontMono = Enum.Font.Gotham,
}

return Theme
