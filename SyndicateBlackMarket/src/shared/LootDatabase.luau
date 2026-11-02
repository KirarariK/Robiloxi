--!strict
--[[
	LootDatabase.luau
	Métadonnées du butin : valeur, poids, rareté, modèle et tirage pondéré.

	Pondération d'apparition (proximité p ∈ [0, 1], 0 = spawn, 1 = coffre ; biais b du contrat) :
		poids = SpawnWeight * (1 + p * b) ^ (rangDeRareté - 1)
	Plus on approche du coffre, plus les raretés élevées sont favorisées.
]]

local Types = require(script.Parent.Types)
local Constants = require(script.Parent.Constants)

type LootDefinition = Types.LootDefinition
type Rarity = Types.Rarity

local RARITY_ORDER: { Rarity } = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

local RARITY_RANK: { [Rarity]: number } = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythic = 5,
}

local RARITY_COLORS: { [Rarity]: Color3 } = {
	Common = Color3.fromHex("#B8C4D6"),
	Rare = Color3.fromHex("#00F0FF"),
	Epic = Color3.fromHex("#B44DFF"),
	Legendary = Color3.fromHex("#FFD700"),
	Mythic = Color3.fromHex("#FF003C"),
}

local RARITY_LABELS: { [Rarity]: string } = {
	Common = "Commun",
	Rare = "Rare",
	Epic = "Épique",
	Legendary = "Légendaire",
	Mythic = "Mythique",
}

local function make(
	id: string,
	displayName: string,
	rarity: Rarity,
	value: number,
	weight: number,
	spawnWeight: number,
	minVaultProximity: number,
	isObjective: boolean
): LootDefinition
	return table.freeze({
		Id = id,
		DisplayName = displayName,
		Rarity = rarity,
		Value = value,
		Weight = weight,
		ModelName = "Loot_" .. id,
		IsHeavy = weight >= Constants.Weight.HeavyThreshold,
		IsObjective = isObjective,
		SpawnWeight = spawnWeight,
		MinVaultProximity = minVaultProximity,
	})
end

local DEFINITIONS: { LootDefinition } = {
	make("CashBundle", "Liasse de billets", "Common", 1500, 0.8, 60, 0, false),
	make("EncryptedDrive", "Disque chiffré", "Rare", 3200, 1.5, 30, 0.15, false),
	make("GoldBullion", "Lingots cybernétiques", "Epic", 8500, 6, 14, 0.35, false),
	make("PrototypeWeaponCase", "Mallette prototype", "Legendary", 14000, 8.5, 6, 0.55, false),
	make("QuantumCore", "Noyau quantique", "Mythic", 50000, 12, 0, 1, true),
}

local byId: { [string]: LootDefinition } = {}
for _, definition in DEFINITIONS do
	assert(byId[definition.Id] == nil, "LootDatabase : identifiant dupliqué " .. definition.Id)
	byId[definition.Id] = definition
end

local FALLBACK_ID = "CashBundle"

local LootDatabase = {}

LootDatabase.All = table.freeze(DEFINITIONS)
LootDatabase.Rarities = table.freeze(RARITY_ORDER)
LootDatabase.RarityColors = table.freeze(RARITY_COLORS)
LootDatabase.RarityLabels = table.freeze(RARITY_LABELS)

function LootDatabase.get(id: string): LootDefinition?
	return byId[id]
end

function LootDatabase.require(id: string): LootDefinition
	local definition = byId[id]
	if definition == nil then
		error(`LootDatabase : objet inconnu « {id} »`, 2)
	end
	return definition
end

function LootDatabase.rarityRank(rarity: Rarity): number
	return RARITY_RANK[rarity]
end

function LootDatabase.isValidId(id: unknown): boolean
	return typeof(id) == "string" and byId[id] ~= nil
end

function LootDatabase.spawnWeight(definition: LootDefinition, vaultProximity: number, rarityBias: number): number
	if definition.IsObjective then
		return 0
	end
	local proximity = math.clamp(vaultProximity, 0, 1)
	if proximity < definition.MinVaultProximity then
		return 0
	end
	local rank = RARITY_RANK[definition.Rarity]
	return definition.SpawnWeight * (1 + proximity * math.max(rarityBias, 0)) ^ (rank - 1)
end

function LootDatabase.roll(vaultProximity: number, rarityBias: number, rng: Random): LootDefinition
	local total = 0
	local weights: { number } = table.create(#DEFINITIONS, 0)
	for index, definition in DEFINITIONS do
		local weight = LootDatabase.spawnWeight(definition, vaultProximity, rarityBias)
		weights[index] = weight
		total += weight
	end
	if total <= 0 then
		return byId[FALLBACK_ID]
	end
	local pick = rng:NextNumber() * total
	for index, definition in DEFINITIONS do
		pick -= weights[index]
		if pick <= 0 and weights[index] > 0 then
			return definition
		end
	end
	return byId[FALLBACK_ID]
end

-- Tirage garanti d'une rareté minimale (coffre doré des contrats classifiés).
function LootDatabase.rollAtLeast(minRarity: Rarity, vaultProximity: number, rarityBias: number, rng: Random): LootDefinition
	local minRank = RARITY_RANK[minRarity]
	local total = 0
	local candidates: { LootDefinition } = {}
	local weights: { number } = {}
	for _, definition in DEFINITIONS do
		if not definition.IsObjective and RARITY_RANK[definition.Rarity] >= minRank then
			local weight = math.max(LootDatabase.spawnWeight(definition, math.max(vaultProximity, definition.MinVaultProximity), rarityBias), 0.001)
			table.insert(candidates, definition)
			table.insert(weights, weight)
			total += weight
		end
	end
	if #candidates == 0 then
		return byId[FALLBACK_ID]
	end
	local pick = rng:NextNumber() * total
	for index, definition in candidates do
		pick -= weights[index]
		if pick <= 0 then
			return definition
		end
	end
	return candidates[#candidates]
end

return table.freeze(LootDatabase)
