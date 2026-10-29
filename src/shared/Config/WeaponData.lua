--!strict
-- Les 3 types d'armes. Valeurs de base ; les Voies appliquent leurs multiplicateurs par-dessus.
local Types = require(script.Parent.Parent.Types)

type WeaponDef = Types.WeaponDef

local WEAPONS: { [Types.WeaponType]: WeaponDef } = {
	Single = {
		Id = "Single",
		Name = "Lame d'Éther",
		Description = "Équilibrée entre vitesse, défense et endurance.",
		ComboLength = 4,
		LightDamage = 9,
		HeavyDamage = 18,
		HeavyPostureDamage = 34,
		AttackSpeed = 1,
		MaxPosture = 100,
		PostureRegen = 14,
		BlockCostMultiplier = 1,
		HeavyRecovery = 0.55,
		Reach = 6.5,
		Arc = 110,
		StaminaCost = 1,
	},
	Dual = {
		Id = "Dual",
		Name = "Lames Jumelles",
		Description = "Cadence très élevée et combos longs, mais garde plus fragile.",
		ComboLength = 5,
		LightDamage = 7,
		HeavyDamage = 15,
		HeavyPostureDamage = 28,
		AttackSpeed = 1.3,
		MaxPosture = 82,
		PostureRegen = 12,
		BlockCostMultiplier = 1.25,
		HeavyRecovery = 0.5,
		Reach = 5.8,
		Arc = 130,
		StaminaCost = 1.1,
	},
	Staff = {
		Id = "Staff",
		Name = "Bâton-Lame",
		Description = "Défense de zone, coups circulaires à 360°, récupération lente après un coup lourd.",
		ComboLength = 4,
		LightDamage = 8,
		HeavyDamage = 20,
		HeavyPostureDamage = 36,
		AttackSpeed = 0.92,
		MaxPosture = 110,
		PostureRegen = 20,
		BlockCostMultiplier = 0.9,
		HeavyRecovery = 0.85,
		Reach = 7,
		Arc = 360,
		StaminaCost = 1.05,
	},
}

local ORDER: { Types.WeaponType } = { "Single", "Dual", "Staff" }

local WeaponData = {}
WeaponData.Order = table.freeze(ORDER)
WeaponData.Default = "Single" :: Types.WeaponType

for _, w in WEAPONS do
	table.freeze(w)
end

function WeaponData.get(id: string): WeaponDef?
	return WEAPONS[id :: Types.WeaponType]
end

function WeaponData.isValid(id: unknown): boolean
	return type(id) == "string" and WEAPONS[id :: Types.WeaponType] ~= nil
end

return table.freeze(WeaponData)
