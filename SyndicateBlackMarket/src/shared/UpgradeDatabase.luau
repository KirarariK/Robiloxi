--!strict
--[[
	UpgradeDatabase.luau
	Prix et valeurs des améliorations de la planque.

	Minage (cartes graphiques, niveaux 1..10) :
		Prix(N)    = round(500 * 1.85 ^ (N - 1))
		Crédits(N) = round(4 * 1.6 ^ (N - 1))  par tick de Constants.Hub.MiningInterval secondes
	Vitesse de piratage (1..5) : multiplicateur de largeur de zone cible = 1 + 0.12 * N
	Endurance (1..5)           : +15 endurance max par niveau
	Blindage (1..3)            : réduction de dégâts = 0.06 * N (plafonnée par Constants.Combat.ArmorCap)
	Armurerie                  : achat unique qui débloque un équipement de WeaponDatabase
]]

local Types = require(script.Parent.Types)
local WeaponDatabase = require(script.Parent.WeaponDatabase)

type UpgradeDefinition = Types.UpgradeDefinition
type UpgradeLevel = Types.UpgradeLevel
type UpgradeCategory = Types.UpgradeCategory

local function buildLevels(count: number, price: (number) -> number, value: (number) -> number): { UpgradeLevel }
	local levels: { UpgradeLevel } = table.create(count)
	for level = 1, count do
		levels[level] = table.freeze({
			Level = level,
			Price = price(level),
			Value = value(level),
		})
	end
	return table.freeze(levels)
end

local function upgrade(
	id: string,
	displayName: string,
	description: string,
	category: UpgradeCategory,
	baseValue: number,
	levels: { UpgradeLevel },
	grantsEquipment: string?
): UpgradeDefinition
	return table.freeze({
		Id = id,
		DisplayName = displayName,
		Description = description,
		Category = category,
		BaseValue = baseValue,
		Levels = levels,
		GrantsEquipment = grantsEquipment,
	})
end

local function armory(equipmentId: string, displayName: string, description: string): UpgradeDefinition
	local maybePrice = WeaponDatabase.priceOf(equipmentId)
	if maybePrice == nil then
		error("UpgradeDatabase : équipement inconnu " .. equipmentId)
	end
	local price: number = maybePrice
	return upgrade(
		"Armory_" .. equipmentId,
		displayName,
		description,
		"Armory",
		0,
		buildLevels(1, function(_level: number): number
			return price
		end, function(_level: number): number
			return 1
		end),
		equipmentId
	)
end

local DEFINITIONS: { UpgradeDefinition } = {
	upgrade(
		"MiningRig",
		"Carte graphique de minage",
		"Génère des Crédits Noirs quand tu es assis sur le fauteuil de minage.",
		"Mining",
		0,
		buildLevels(10, function(level: number): number
			return math.round(500 * 1.85 ^ (level - 1))
		end, function(level: number): number
			return math.round(4 * 1.6 ^ (level - 1))
		end)
	),
	upgrade(
		"HackSpeed",
		"Piratage accéléré",
		"Élargit la zone cible du mini-jeu CyberDeck.",
		"Skill",
		1,
		buildLevels(5, function(level: number): number
			return 1500 * 2 ^ (level - 1)
		end, function(level: number): number
			return 1 + 0.12 * level
		end)
	),
	upgrade(
		"Stamina",
		"Endurance",
		"Augmente l'endurance maximale pour sprinter et glisser plus longtemps.",
		"Skill",
		0,
		buildLevels(5, function(level: number): number
			return 1200 * 2 ^ (level - 1)
		end, function(level: number): number
			return 15 * level
		end)
	),
	upgrade(
		"Armor",
		"Gilet balistique",
		"Réduit les dégâts reçus.",
		"Skill",
		0,
		buildLevels(3, function(level: number): number
			return 4000 * 3 ^ (level - 1)
		end, function(level: number): number
			return 0.06 * level
		end)
	),
	armory("SubmachineGun", "PMG Vector-X", "Arme automatique bruyante pour les assauts."),
	armory("EMP_Jammer", "Brouilleur IEM", "Désactive caméras, lasers et radios autour de lui."),
}

local byId: { [string]: UpgradeDefinition } = {}
for _, definition in DEFINITIONS do
	assert(byId[definition.Id] == nil, "UpgradeDatabase : identifiant dupliqué " .. definition.Id)
	byId[definition.Id] = definition
end

local UpgradeDatabase = {}

UpgradeDatabase.All = table.freeze(DEFINITIONS)

function UpgradeDatabase.get(id: string): UpgradeDefinition?
	return byId[id]
end

function UpgradeDatabase.maxLevel(id: string): number
	local definition = byId[id]
	return if definition then #definition.Levels else 0
end

function UpgradeDatabase.nextLevel(id: string, currentLevel: number): UpgradeLevel?
	local definition = byId[id]
	if definition == nil then
		return nil
	end
	return definition.Levels[currentLevel + 1]
end

-- Valeur effective pour un niveau possédé (0 = valeur de base).
function UpgradeDatabase.valueAt(id: string, level: number): number
	local definition = byId[id]
	if definition == nil then
		return 0
	end
	if level <= 0 then
		return definition.BaseValue
	end
	local clamped = math.min(level, #definition.Levels)
	return definition.Levels[clamped].Value
end

function UpgradeDatabase.byCategory(category: UpgradeCategory): { UpgradeDefinition }
	local result: { UpgradeDefinition } = {}
	for _, definition in DEFINITIONS do
		if definition.Category == category then
			table.insert(result, definition)
		end
	end
	return result
end

return table.freeze(UpgradeDatabase)
