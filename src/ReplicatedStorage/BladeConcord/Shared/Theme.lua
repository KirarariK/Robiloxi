--!strict
--[[
	Identité visuelle Blade Concord — cathédrale de duel au crépuscule.
	Palette Ink / Or / Focus / Arcane · typos Accanthis / Oswald / Montserrat.
	Pas de lexique Star Wars.
]]

local Theme = {
	Brand = "Blade Concord",
	HallName = "CONCORD HALL",

	-- Palette (spec ui-lobby-direction §3.3)
	Ink900 = Color3.fromRGB(7, 11, 20),
	Ink800 = Color3.fromRGB(13, 20, 36),
	Ink700 = Color3.fromRGB(20, 29, 51),
	Ink600 = Color3.fromRGB(29, 42, 71),
	Ink = Color3.fromRGB(7, 11, 20),
	InkSoft = Color3.fromRGB(13, 20, 36),
	Panel = Color3.fromRGB(20, 29, 51),
	PanelEdge = Color3.fromRGB(184, 137, 43),
	Bone = Color3.fromRGB(242, 245, 250),
	Muted = Color3.fromRGB(154, 167, 189),

	Gold = Color3.fromRGB(232, 196, 104),
	GoldHi = Color3.fromRGB(255, 233, 168),
	GoldDark = Color3.fromRGB(184, 137, 43),

	Accent = Color3.fromRGB(54, 224, 255), -- Focus cyan
	AccentHot = Color3.fromRGB(255, 154, 60),
	Focus = Color3.fromRGB(54, 224, 255),
	FocusDark = Color3.fromRGB(14, 143, 179),
	Arcane = Color3.fromRGB(155, 107, 255),

	Danger = Color3.fromRGB(255, 77, 94),
	Success = Color3.fromRGB(76, 224, 138),
	Stamina = Color3.fromRGB(255, 213, 74),
	Perfect = Color3.fromRGB(255, 226, 110),
	Dawn = Color3.fromRGB(255, 154, 60),
	DawnBg = Color3.fromRGB(59, 30, 10),
	Dusk = Color3.fromRGB(106, 76, 255),
	DuskBg = Color3.fromRGB(21, 15, 59),
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

	-- Raretés
	RarityCommon = Color3.fromRGB(169, 180, 196),
	RarityRare = Color3.fromRGB(61, 165, 255),
	RarityEpic = Color3.fromRGB(178, 107, 255),
	RarityLegendary = Color3.fromRGB(255, 197, 61),
	RarityPrismaticA = Color3.fromRGB(255, 107, 154),
	RarityPrismaticB = Color3.fromRGB(255, 211, 107),
	RarityPrismaticC = Color3.fromRGB(107, 255, 184),
	RarityPrismaticD = Color3.fromRGB(107, 184, 255),
	RarityPrismaticE = Color3.fromRGB(178, 107, 255),

	CosmeticAzure = Color3.fromRGB(90, 190, 255),
	CosmeticEmber = Color3.fromRGB(255, 110, 45),
	AuraEclipse = Color3.fromRGB(140, 90, 255),

	-- Layout
	RadiusCard = 10,
	RadiusButton = 8,
	RadiusPill = 999,
	TouchMin = 44,
	RefW = 1280,
	RefH = 720,
	UiScaleMin = 0.7,
	UiScaleMax = 1.35,

	-- Enum.Font fallbacks (si Font.new échoue)
	FontTitle = Enum.Font.Merriweather,
	FontBody = Enum.Font.GothamMedium,
	FontMono = Enum.Font.RobotoMono,
	FontHud = Enum.Font.GothamBold,
}

-- Polices intégrées (spec §3.4) — Accanthis/Bodoni titres, Oswald HUD, Montserrat corps
local function tryFont(family: string, weight: Enum.FontWeight?, style: Enum.FontStyle?): Font?
	local ok, font = pcall(function()
		return Font.new(
			"rbxasset://fonts/families/" .. family .. ".json",
			weight or Enum.FontWeight.Medium,
			style or Enum.FontStyle.Normal
		)
	end)
	if ok and font then
		return font
	end
	return nil
end

Theme.Fonts = {
	Display = tryFont("AccanthisADFStd", Enum.FontWeight.Bold) or tryFont("Merriweather", Enum.FontWeight.Bold),
	Title = tryFont("Merriweather", Enum.FontWeight.Bold) or tryFont("AccanthisADFStd", Enum.FontWeight.Bold),
	Hud = tryFont("Oswald", Enum.FontWeight.Bold) or tryFont("Oswald", Enum.FontWeight.SemiBold),
	HudSemi = tryFont("Oswald", Enum.FontWeight.SemiBold) or tryFont("Oswald", Enum.FontWeight.Medium),
	Body = tryFont("Montserrat", Enum.FontWeight.Medium) or tryFont("Montserrat", Enum.FontWeight.Regular),
	BodyBold = tryFont("Montserrat", Enum.FontWeight.Bold),
	Mono = tryFont("RobotoMono", Enum.FontWeight.Medium),
}

function Theme.applyFont(label: TextLabel | TextButton | TextBox, kind: string)
	local map = Theme.Fonts
	local fontObj: Font? = nil
	if kind == "Display" then
		fontObj = map.Display or map.Title
	elseif kind == "Title" then
		fontObj = map.Title or map.Display
	elseif kind == "Hud" or kind == "HudSemi" then
		fontObj = if kind == "HudSemi" then (map.HudSemi or map.Hud) else map.Hud
	elseif kind == "BodyBold" then
		fontObj = map.BodyBold or map.Body
	elseif kind == "Mono" then
		fontObj = map.Mono
	else
		fontObj = map.Body
	end
	if fontObj then
		(label :: any).FontFace = fontObj
	else
		if kind == "Display" or kind == "Title" then
			label.Font = Theme.FontTitle
		elseif kind == "Hud" or kind == "HudSemi" then
			label.Font = Theme.FontHud
		elseif kind == "Mono" then
			label.Font = Theme.FontMono
		else
			label.Font = Theme.FontBody
		end
	end
end

function Theme.rarityColor(rarity: string): Color3
	local r = string.lower(rarity)
	if r == "legendary" or r == "légendaire" then
		return Theme.RarityLegendary
	elseif r == "epic" or r == "épique" or r == "epique" then
		return Theme.RarityEpic
	elseif r == "rare" then
		return Theme.RarityRare
	elseif r == "prismatic" or r == "prismatique" then
		return Theme.RarityPrismaticA
	end
	return Theme.RarityCommon
end

function Theme.rarityLabelFr(rarity: string): string
	local r = string.lower(rarity)
	if r == "legendary" then
		return "Légendaire"
	elseif r == "epic" then
		return "Épique"
	elseif r == "rare" then
		return "Rare"
	elseif r == "prismatic" then
		return "Prismatique"
	end
	return "Commun"
end

function Theme.rankLabelFr(rank: string): string
	local map: { [string]: string } = {
		Bronze = "Bronze",
		Silver = "Argent",
		Gold = "Or",
		Platinum = "Platine",
		Diamond = "Diamant",
		Master = "Maître",
		Grandmaster = "Grand Maître",
	}
	return map[rank] or rank
end

function Theme.categoryColor(category: string): Color3
	if category == "Boutique" or category == "Forge" then
		return Theme.Gold
	elseif category == "Formes" then
		return Theme.Arcane
	elseif category == "Quêtes" then
		return Theme.Focus
	elseif category == "Codes" then
		return Theme.Success
	elseif category == "Classé" or category == "Ranked" then
		return Theme.Arcane
	elseif category == "Factions" then
		return Theme.Dawn
	elseif category == "Serveurs" then
		return Theme.Success
	elseif category == "Échange" then
		return Theme.FocusDark
	end
	return Theme.Gold
end

function Theme.goldGradient(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.GoldHi),
		ColorSequenceKeypoint.new(0.45, Theme.Gold),
		ColorSequenceKeypoint.new(1, Theme.GoldDark),
	})
end

function Theme.prismaticGradient(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.RarityPrismaticA),
		ColorSequenceKeypoint.new(0.25, Theme.RarityPrismaticB),
		ColorSequenceKeypoint.new(0.5, Theme.RarityPrismaticC),
		ColorSequenceKeypoint.new(0.75, Theme.RarityPrismaticD),
		ColorSequenceKeypoint.new(1, Theme.RarityPrismaticE),
	})
end

function Theme.uiScale(viewport: Vector2): number
	local sx = viewport.X / Theme.RefW
	local sy = viewport.Y / Theme.RefH
	return math.clamp(math.min(sx, sy), Theme.UiScaleMin, Theme.UiScaleMax)
end

return Theme
