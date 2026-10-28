--!strict
export type SnakeDef = {
	Id: string,
	DisplayName: string,
	Biome: number,
	Rarity: string,
	RarityMult: number,
	BaseWeight: number,
	WeightMin: number,
	WeightMax: number,
	BaseIncome: number,
	ModelName: string,
}

local SnakesConfig: { [string]: SnakeDef } = {
	Viper_Green = {
		Id = "Viper_Green",
		DisplayName = "Vipère Verte",
		Biome = 1,
		Rarity = "Common",
		RarityMult = 1,
		BaseWeight = 12,
		WeightMin = 8,
		WeightMax = 22,
		BaseIncome = 2,
		ModelName = "Viper_Green",
	},
	Python_Royal = {
		Id = "Python_Royal",
		DisplayName = "Python Royal",
		Biome = 1,
		Rarity = "Uncommon",
		RarityMult = 1.6,
		BaseWeight = 28,
		WeightMin = 18,
		WeightMax = 45,
		BaseIncome = 5,
		ModelName = "Python_Royal",
	},
	Cobra_Royal = {
		Id = "Cobra_Royal",
		DisplayName = "Cobra Royal",
		Biome = 2,
		Rarity = "Rare",
		RarityMult = 2.4,
		BaseWeight = 35,
		WeightMin = 22,
		WeightMax = 60,
		BaseIncome = 14,
		ModelName = "Cobra_Royal",
	},
	Horned_Rattler = {
		Id = "Horned_Rattler",
		DisplayName = "Crotale Cornu",
		Biome = 2,
		Rarity = "Rare",
		RarityMult = 2.2,
		BaseWeight = 30,
		WeightMin = 20,
		WeightMax = 55,
		BaseIncome = 12,
		ModelName = "Horned_Rattler",
	},
	Anaconda_Spiked = {
		Id = "Anaconda_Spiked",
		DisplayName = "Anaconda Épineux",
		Biome = 3,
		Rarity = "Epic",
		RarityMult = 4,
		BaseWeight = 85,
		WeightMin = 55,
		WeightMax = 140,
		BaseIncome = 55,
		ModelName = "Anaconda_Spiked",
	},
	Magma_Serpent = {
		Id = "Magma_Serpent",
		DisplayName = "Serpent de Magma",
		Biome = 4,
		Rarity = "Legendary",
		RarityMult = 7,
		BaseWeight = 120,
		WeightMin = 80,
		WeightMax = 200,
		BaseIncome = 180,
		ModelName = "Magma_Serpent",
	},
	Celestial_Ouroboros = {
		Id = "Celestial_Ouroboros",
		DisplayName = "Serpent Céleste",
		Biome = 5,
		Rarity = "Mythic",
		RarityMult = 12,
		BaseWeight = 160,
		WeightMin = 100,
		WeightMax = 260,
		BaseIncome = 650,
		ModelName = "Celestial_Ouroboros",
	},
}

-- Fill to ~25 entries via variants
local extras = {
	{ "Emerald_Boa", "Boa Émeraude", 1, "Common", 1.1, 15, 10, 28, 3 },
	{ "Leaf_Viper", "Vipère Feuille", 1, "Common", 1, 10, 6, 18, 2 },
	{ "Jungle_Krait", "Krait Jungle", 1, "Uncommon", 1.5, 20, 12, 35, 4 },
	{ "Sand_Asp", "Aspic des Sables", 2, "Common", 1.2, 14, 9, 26, 6 },
	{ "Dune_Sidewinder", "Sidewinder", 2, "Uncommon", 1.7, 22, 14, 40, 9 },
	{ "Pharaoh_Asp", "Aspic Pharaon", 2, "Rare", 2.5, 40, 25, 70, 18 },
	{ "Bog_Adder", "Vipère du Marais", 3, "Uncommon", 1.8, 32, 20, 55, 22 },
	{ "Toxic_Mamba", "Mamba Toxique", 3, "Rare", 2.8, 38, 24, 68, 35 },
	{ "Swamp_Hydra", "Hydre Marécage", 3, "Epic", 4.2, 95, 60, 150, 70 },
	{ "Ash_Cobra", "Cobra de Cendre", 4, "Rare", 3, 50, 30, 90, 90 },
	{ "Lava_Python", "Python de Lave", 4, "Epic", 4.5, 110, 70, 180, 140 },
	{ "Obsidian_Asp", "Aspic Obsidienne", 4, "Legendary", 6.5, 130, 85, 210, 220 },
	{ "Nebula_Viper", "Vipère Nébuleuse", 5, "Epic", 5, 90, 55, 150, 280 },
	{ "Void_Krait", "Krait du Vide", 5, "Legendary", 8, 140, 90, 220, 420 },
	{ "Star_Naga", "Naga Stellaire", 5, "Mythic", 11, 170, 110, 270, 700 },
	{ "Rainbow_Ouro", "Ouro Arc-en-ciel", 5, "Mythic", 13, 190, 120, 300, 900 },
	{ "Crystal_Serpent", "Serpent Cristal", 5, "Legendary", 7.5, 125, 80, 200, 380 },
	{ "Moss_Python", "Python Mousse", 1, "Uncommon", 1.4, 26, 16, 42, 4 },
}

local modelFallback = {
	[1] = "Viper_Green",
	[2] = "Cobra_Royal",
	[3] = "Anaconda_Spiked",
	[4] = "Magma_Serpent",
	[5] = "Celestial_Ouroboros",
}

for _, e in extras do
	local id = e[1] :: string
	SnakesConfig[id] = {
		Id = id,
		DisplayName = e[2] :: string,
		Biome = e[3] :: number,
		Rarity = e[4] :: string,
		RarityMult = e[5] :: number,
		BaseWeight = e[6] :: number,
		WeightMin = e[7] :: number,
		WeightMax = e[8] :: number,
		BaseIncome = e[9] :: number,
		ModelName = modelFallback[e[3] :: number],
	}
end

function SnakesConfig.get(id: string): SnakeDef?
	return SnakesConfig[id]
end

function SnakesConfig.listForBiome(biomeOrder: number): { SnakeDef }
	local out = {}
	for key, def in SnakesConfig do
		if typeof(key) == "string" and typeof(def) == "table" and (def :: any).Biome == biomeOrder and (def :: any).Id then
			table.insert(out, def :: SnakeDef)
		end
	end
	return out
end

return SnakesConfig
