--!strict
-- Les 7 Voies de combat (équivalent original des « formes »). Poids = probabilités de relance en %.
local Types = require(script.Parent.Parent.Types)

type FormDef = Types.FormDef
type FormStats = Types.FormStats

local function stats(overrides: { [string]: number }): FormStats
	local s: FormStats = {
		PostureDamage = 1,
		BlockPostureCost = 1,
		ParryWindow = 1,
		DodgeSpeed = 1,
		StaminaCost = 1,
		JumpPower = 1,
		AttackSpeed = 1,
		CounterWindow = 0,
		ParryReflect = 0,
		KineticPush = 0,
		AerialBonus = 1,
	}
	for k, v in overrides do
		assert((s :: any)[k] ~= nil, "Stat de Voie inconnue : " .. k)
		;(s :: any)[k] = v
	end
	return table.freeze(s)
end

local LIST: { FormDef } = {
	{
		Id = "Origine",
		Order = 1,
		Roman = "I",
		Name = "Voie de l'Origine",
		Rarity = "Commun",
		Weight = 40,
		Description = "Le socle de tout duelliste : gestes amples, coupes franches.",
		Passive = "Fenêtre de parade élargie (+20 %).",
		AnimSet = "Origine",
		Stats = stats({ ParryWindow = 1.2 }),
	},
	{
		Id = "Duelliste",
		Order = 2,
		Roman = "II",
		Name = "Voie du Duelliste",
		Rarity = "Rare",
		Weight = 25,
		Description = "Escrime élégante à une main, toute en précision.",
		Passive = "+15 % de dégâts de posture, esquives 15 % plus rapides.",
		AnimSet = "Duelliste",
		Stats = stats({ PostureDamage = 1.15, DodgeSpeed = 1.15 }),
	},
	{
		Id = "Rempart",
		Order = 3,
		Roman = "III",
		Name = "Voie du Rempart",
		Rarity = "Rare",
		Weight = 20,
		Description = "Défense absolue : rien ne passe la garde.",
		Passive = "Blocage 40 % moins coûteux en posture, contre-attaque rapide 0,6 s après une parade.",
		AnimSet = "Rempart",
		Stats = stats({ BlockPostureCost = 0.6, CounterWindow = 0.6, AttackSpeed = 0.95 }),
	},
	{
		Id = "Faucon",
		Order = 4,
		Roman = "IV",
		Name = "Voie du Faucon",
		Rarity = "Epique",
		Weight = 8,
		Description = "Acrobaties, bonds et frappes plongeantes.",
		Passive = "Sauts +35 %, attaques aériennes +40 %, endurance +20 % consommée.",
		AnimSet = "Faucon",
		Stats = stats({ JumpPower = 1.35, AerialBonus = 1.4, StaminaCost = 1.2, DodgeSpeed = 1.1 }),
	},
	{
		Id = "Riposte",
		Order = 5,
		Roman = "V",
		Name = "Voie de la Riposte",
		Rarity = "Epique",
		Weight = 5,
		Description = "Encaisser pour mieux frapper : la puissance retournée contre l'agresseur.",
		Passive = "Parade parfaite : renvoie 35 % des dégâts de posture à l'attaquant. Coups lourds +10 %.",
		AnimSet = "Riposte",
		Stats = stats({ ParryReflect = 0.35, PostureDamage = 1.1 }),
	},
	{
		Id = "Equilibre",
		Order = 6,
		Roman = "VI",
		Name = "Voie de l'Équilibre",
		Rarity = "Legendaire",
		Weight = 1.5,
		Description = "Lame et onde de choc ne font qu'un.",
		Passive = "Les combos intègrent des poussées cinétiques (4 studs) ; tout est légèrement amélioré.",
		AnimSet = "Equilibre",
		Stats = stats({ KineticPush = 4, PostureDamage = 1.05, ParryWindow = 1.05, AttackSpeed = 1.05 }),
	},
	{
		Id = "Tempete",
		Order = 7,
		Roman = "VII",
		Name = "Voie de la Tempête",
		Rarity = "Mythique",
		Weight = 0.5,
		Description = "Frénésie imprévisible : la rage canalisée dans la lame.",
		Passive = "Vitesse +20 %, dégâts de posture +30 %, blocage 15 % plus coûteux.",
		AnimSet = "Tempete",
		Stats = stats({ AttackSpeed = 1.2, PostureDamage = 1.3, BlockPostureCost = 1.15, StaminaCost = 1.1 }),
	},
}

local byId: { [Types.FormId]: FormDef } = {}
local totalWeight = 0
for _, f in LIST do
	byId[f.Id] = table.freeze(f)
	totalWeight += f.Weight
end
assert(math.abs(totalWeight - 100) < 1e-6, "La somme des poids des Voies doit faire 100")

local FormData = {}

FormData.List = table.freeze(LIST)
FormData.TotalWeight = totalWeight
FormData.Default = "Origine" :: Types.FormId

function FormData.get(id: string): FormDef?
	return byId[id :: Types.FormId]
end

function FormData.isValid(id: unknown): boolean
	return type(id) == "string" and byId[id :: Types.FormId] ~= nil
end

-- Tirage pondéré ; `roll` dans [0, totalWeight[ (injectable pour les tests).
function FormData.pick(roll: number): FormDef
	local acc = 0
	for _, f in LIST do
		acc += f.Weight
		if roll < acc then
			return f
		end
	end
	return LIST[#LIST]
end

return table.freeze(FormData)
