--!strict
--[[
	RarityConfig — source unique des raretés (couleurs, noms FR, rang, poids d'apparition, multiplicateurs).
	Secret : 1 par zone, très rare, annoncé à tout le serveur.
]]
export type RarityDef = {
	Id: string,
	Rank: number,
	DisplayName: string,
	Color: Color3,
	SpawnWeight: number,
	RarityMult: number,
	BaseIncome: number, -- revenu de base en zone 1 (multiplié par 2.6^(zone-1))
	BaseWeight: number, -- poids de base en zone 1 (kg)
	Announce: boolean, -- annonce serveur à l'apparition
}

local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local DEFS: { [string]: RarityDef } = {
	Common = { Id = "Common", Rank = 1, DisplayName = "Commun", Color = Color3.fromRGB(190, 195, 205), SpawnWeight = 100, RarityMult = 1, BaseIncome = 2, BaseWeight = 10, Announce = false },
	Uncommon = { Id = "Uncommon", Rank = 2, DisplayName = "Peu commun", Color = Color3.fromRGB(90, 220, 110), SpawnWeight = 55, RarityMult = 1.6, BaseIncome = 4, BaseWeight = 14, Announce = false },
	Rare = { Id = "Rare", Rank = 3, DisplayName = "Rare", Color = Color3.fromRGB(70, 160, 255), SpawnWeight = 25, RarityMult = 2.4, BaseIncome = 9, BaseWeight = 20, Announce = false },
	Epic = { Id = "Epic", Rank = 4, DisplayName = "Épique", Color = Color3.fromRGB(180, 90, 255), SpawnWeight = 10, RarityMult = 4, BaseIncome = 20, BaseWeight = 28, Announce = false },
	Legendary = { Id = "Legendary", Rank = 5, DisplayName = "Légendaire", Color = Color3.fromRGB(255, 190, 40), SpawnWeight = 3, RarityMult = 7, BaseIncome = 45, BaseWeight = 38, Announce = true },
	Mythic = { Id = "Mythic", Rank = 6, DisplayName = "Mythique", Color = Color3.fromRGB(255, 70, 90), SpawnWeight = 1, RarityMult = 12, BaseIncome = 100, BaseWeight = 50, Announce = true },
	Secret = { Id = "Secret", Rank = 7, DisplayName = "Secret", Color = Color3.fromRGB(235, 235, 255), SpawnWeight = 0.25, RarityMult = 25, BaseIncome = 250, BaseWeight = 65, Announce = true },
}

local RarityConfig = {}

RarityConfig.Order = ORDER

function RarityConfig.get(id: string): RarityDef
	return DEFS[id] or DEFS.Common
end

function RarityConfig.color(id: string): Color3
	return RarityConfig.get(id).Color
end

function RarityConfig.name(id: string): string
	return RarityConfig.get(id).DisplayName
end

function RarityConfig.rank(id: string): number
	return RarityConfig.get(id).Rank
end

return RarityConfig
