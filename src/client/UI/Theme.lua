--!strict
-- Thème visuel « éther » : bleu nuit translucide, accents cyan et or, polices et sons d'interface intégrés.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Rarity = require(Shared.Config.Rarity)

local rgb = Color3.fromRGB

local Theme = {}

Theme.Colors = table.freeze({
	Night = rgb(6, 9, 22),
	Bg = rgb(10, 15, 34),
	Panel = rgb(14, 21, 44),
	PanelLight = rgb(22, 32, 64),
	Line = rgb(48, 70, 120),
	Cyan = rgb(70, 220, 255),
	CyanDeep = rgb(20, 120, 200),
	Gold = rgb(255, 204, 96),
	GoldDeep = rgb(200, 130, 30),
	Text = rgb(232, 238, 255),
	TextDim = rgb(146, 162, 196),
	Danger = rgb(255, 82, 104),
	Success = rgb(90, 230, 150),
	Health = rgb(255, 72, 96),
	Posture = rgb(255, 184, 60),
	Stamina = rgb(70, 220, 255),
	Shadow = rgb(0, 0, 0),
})

local function font(enumName: string, fallback: Enum.Font, weight: Enum.FontWeight?): Font
	local ok, f = pcall(function()
		local e = (Enum.Font :: any)[enumName] :: Enum.Font
		return Font.fromEnum(e)
	end)
	local base = if ok then f :: Font else Font.fromEnum(fallback)
	if weight then
		return Font.new(base.Family, weight, Enum.FontStyle.Normal)
	end
	return base
end

-- Michroma (intégrée à Roblox) pour les titres, Gotham pour le texte courant.
Theme.Fonts = table.freeze({
	Display = font("Michroma", Enum.Font.GothamBlack),
	Title = font("GothamBlack", Enum.Font.GothamBold),
	Bold = font("GothamBold", Enum.Font.GothamBold),
	Body = font("GothamMedium", Enum.Font.Gotham),
})

Theme.Sounds = table.freeze({
	Click = "rbxasset://sounds/button.wav",
	Open = "rbxasset://sounds/unsheath.wav",
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/hit.wav",
	Spin = "rbxasset://sounds/button.wav",
	Reveal = "rbxasset://sounds/swordlunge.wav",
	Victory = "rbxasset://sounds/swordslash.wav",
	Metal = "rbxasset://sounds/metal.ogg",
})

Theme.Corner = 12

function Theme.rarityColor(r: string): Color3
	local info = (Rarity :: any)[r]
	return if info then info.Color else Theme.Colors.TextDim
end

function Theme.rarityLabel(r: string): string
	local info = (Rarity :: any)[r]
	return if info then info.Label else r
end

function Theme.rarityOrder(r: string): number
	local info = (Rarity :: any)[r]
	return if info then info.Order else 0
end

-- Prix des cristaux de lame (attributs posés par EquipService, repli identique).
local PRICE_FALLBACK = { Commun = 150, Rare = 400, Epique = 900, Legendaire = 2000, Mythique = 4500 }
function Theme.colorPrice(r: string): number
	local cfg = Shared:FindFirstChild("Config")
	local v = cfg and cfg:GetAttribute("ColorPrice_" .. r)
	if type(v) == "number" then
		return v
	end
	return (PRICE_FALLBACK :: any)[r] or 999999
end

Theme.RerollCost = 100

return Theme
