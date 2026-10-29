--!strict
-- Cristaux de lame : couleur du cœur, du halo, effet spécial et hauteur du bourdonnement.
local Types = require(script.Parent.Parent.Types)

type SaberColorDef = Types.SaberColorDef

local rgb = Color3.fromRGB

local LIST: { SaberColorDef } = {
	-- Classiques
	{ Id = "Azur", Name = "Azur Gardien", Category = "Classique", Rarity = "Commun", Core = rgb(225, 240, 255), Glow = rgb(40, 120, 255), Effect = "None", HumPitch = 1.0, LightBrightness = 2.2 },
	{ Id = "Emeraude", Name = "Émeraude", Category = "Classique", Rarity = "Commun", Core = rgb(230, 255, 230), Glow = rgb(40, 220, 70), Effect = "None", HumPitch = 0.97, LightBrightness = 2.2 },
	{ Id = "Ecarlate", Name = "Écarlate", Category = "Classique", Rarity = "Commun", Core = rgb(255, 228, 228), Glow = rgb(255, 30, 40), Effect = "None", HumPitch = 0.9, LightBrightness = 2.4 },
	{ Id = "Amethyste", Name = "Améthyste", Category = "Classique", Rarity = "Commun", Core = rgb(245, 230, 255), Glow = rgb(160, 60, 255), Effect = "None", HumPitch = 1.03, LightBrightness = 2.2 },
	{ Id = "Ambre", Name = "Ambre Sentinelle", Category = "Classique", Rarity = "Commun", Core = rgb(255, 252, 225), Glow = rgb(255, 210, 40), Effect = "None", HumPitch = 1.05, LightBrightness = 2.2 },
	{ Id = "Orange", Name = "Orange Braise", Category = "Classique", Rarity = "Commun", Core = rgb(255, 238, 220), Glow = rgb(255, 120, 20), Effect = "None", HumPitch = 0.95, LightBrightness = 2.3 },
	-- Spéciales
	{ Id = "Cyan", Name = "Cyan", Category = "Speciale", Rarity = "Rare", Core = rgb(225, 255, 255), Glow = rgb(30, 230, 255), Effect = "None", HumPitch = 1.08, LightBrightness = 2.3 },
	{ Id = "Indigo", Name = "Indigo", Category = "Speciale", Rarity = "Rare", Core = rgb(230, 230, 255), Glow = rgb(75, 60, 230), Effect = "None", HumPitch = 0.98, LightBrightness = 2.3 },
	{ Id = "Magenta", Name = "Magenta", Category = "Speciale", Rarity = "Rare", Core = rgb(255, 228, 250), Glow = rgb(255, 40, 200), Effect = "None", HumPitch = 1.06, LightBrightness = 2.3 },
	{ Id = "BlancPur", Name = "Blanc Pur", Category = "Speciale", Rarity = "Epique", Core = rgb(255, 255, 255), Glow = rgb(225, 235, 255), Effect = "None", HumPitch = 1.12, LightBrightness = 2.6 },
	{ Id = "Argent", Name = "Argenté", Category = "Speciale", Rarity = "Epique", Core = rgb(245, 248, 252), Glow = rgb(170, 185, 205), Effect = "None", HumPitch = 1.1, LightBrightness = 2.4 },
	{ Id = "Viridien", Name = "Viridien", Category = "Speciale", Rarity = "Rare", Core = rgb(225, 255, 245), Glow = rgb(40, 190, 140), Effect = "None", HumPitch = 0.99, LightBrightness = 2.3 },
	{ Id = "Bronze", Name = "Bronze", Category = "Speciale", Rarity = "Epique", Core = rgb(255, 240, 220), Glow = rgb(205, 130, 60), Effect = "None", HumPitch = 0.92, LightBrightness = 2.3 },
	{ Id = "Or", Name = "Or Éclatant", Category = "Speciale", Rarity = "Legendaire", Core = rgb(255, 250, 225), Glow = rgb(255, 196, 30), Effect = "None", HumPitch = 1.15, LightBrightness = 2.8 },
	-- Mythiques
	{ Id = "LameOmbre", Name = "Lame d'Ombre", Category = "Mythique", Rarity = "Mythique", Core = rgb(8, 8, 12), Glow = rgb(235, 240, 255), Effect = "DarkCore", HumPitch = 0.78, LightBrightness = 1.4 },
	{ Id = "EcarlateInstable", Name = "Écarlate Instable", Category = "Mythique", Rarity = "Mythique", Core = rgb(255, 210, 200), Glow = rgb(230, 20, 20), Effect = "Unstable", HumPitch = 0.82, LightBrightness = 2.9 },
	{ Id = "EncreRouge", Name = "Cœur d'Encre · Rouge", Category = "Mythique", Rarity = "Legendaire", Core = rgb(10, 6, 8), Glow = rgb(255, 30, 40), Effect = "InkCore", HumPitch = 0.86, LightBrightness = 2.0 },
	{ Id = "EncreBleu", Name = "Cœur d'Encre · Bleu", Category = "Mythique", Rarity = "Legendaire", Core = rgb(6, 8, 12), Glow = rgb(40, 120, 255), Effect = "InkCore", HumPitch = 0.88, LightBrightness = 2.0 },
	{ Id = "EncreViolet", Name = "Cœur d'Encre · Violet", Category = "Mythique", Rarity = "Legendaire", Core = rgb(8, 6, 12), Glow = rgb(160, 60, 255), Effect = "InkCore", HumPitch = 0.87, LightBrightness = 2.0 },
	{ Id = "EncreVert", Name = "Cœur d'Encre · Vert", Category = "Mythique", Rarity = "Legendaire", Core = rgb(6, 10, 6), Glow = rgb(40, 220, 70), Effect = "InkCore", HumPitch = 0.87, LightBrightness = 2.0 },
	{ Id = "Prisme", Name = "Prisme", Category = "Mythique", Rarity = "Mythique", Core = rgb(255, 255, 255), Glow = rgb(255, 80, 80), Effect = "Prism", HumPitch = 1.1, LightBrightness = 2.6 },
	{ Id = "Nebuleuse", Name = "Nébuleuse", Category = "Mythique", Rarity = "Mythique", Core = rgb(240, 225, 255), Glow = rgb(120, 60, 230), Effect = "Nebula", HumPitch = 1.0, LightBrightness = 2.4 },
}

local byId: { [string]: SaberColorDef } = {}
for _, c in LIST do
	assert(byId[c.Id] == nil, "Couleur en double : " .. c.Id)
	byId[c.Id] = table.freeze(c)
end

local SaberColors = {}
SaberColors.List = table.freeze(LIST)
SaberColors.Default = "Azur"
-- couleurs offertes à la création du profil
SaberColors.Starter = table.freeze({ "Azur", "Emeraude", "Ecarlate" })

function SaberColors.get(id: string): SaberColorDef?
	return byId[id]
end

function SaberColors.isValid(id: unknown): boolean
	return type(id) == "string" and byId[id] ~= nil
end

-- Couleur du halo à l'instant t (gère Prisme / Nébuleuse, qui varient dans le temps).
function SaberColors.glowAt(def: SaberColorDef, t: number): Color3
	if def.Effect == "Prism" then
		return Color3.fromHSV((t * 0.25) % 1, 0.85, 1)
	elseif def.Effect == "Nebula" then
		local k = (math.sin(t * 1.3) + 1) / 2
		return Color3.fromRGB(120, 60, 230):Lerp(Color3.fromRGB(255, 70, 190), k)
	end
	return def.Glow
end

return table.freeze(SaberColors)
