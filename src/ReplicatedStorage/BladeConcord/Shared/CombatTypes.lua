--!strict
--[[
	Enums et types partagés — Blade Concord P0
	Pas de logique ; source de vérité des noms d'états / résultats.
]]

export type AttackKind = "Light" | "Heavy"

export type ActionId =
	"Idle"
	| "Startup"
	| "Active"
	| "Recovery"
	| "Guard"
	| "Stagger"
	| "RiposteLock"
	| "Dead"

export type HitResult =
	"Full"
	| "Chip"
	| "Perfect"
	| "GuardBreak"
	| "Clash"
	| "Blocked" -- alias lisible côté UI pour Chip/Perfect si besoin
	| "Miss"

export type GuardResult = "None" | "Normal" | "Perfect" | "Break"

export type CombatFlags = {
	guarding: boolean,
	exhausted: boolean,
	riposteLock: boolean,
	stagger: boolean,
	riposteBuff: boolean,
}

local CombatTypes = {
	AttackKind = {
		Light = "Light" :: AttackKind,
		Heavy = "Heavy" :: AttackKind,
	},
	ActionId = {
		Idle = "Idle" :: ActionId,
		Startup = "Startup" :: ActionId,
		Active = "Active" :: ActionId,
		Recovery = "Recovery" :: ActionId,
		Guard = "Guard" :: ActionId,
		Stagger = "Stagger" :: ActionId,
		RiposteLock = "RiposteLock" :: ActionId,
		Dead = "Dead" :: ActionId,
	},
	HitResult = {
		Full = "Full" :: HitResult,
		Chip = "Chip" :: HitResult,
		Perfect = "Perfect" :: HitResult,
		GuardBreak = "GuardBreak" :: HitResult,
		Clash = "Clash" :: HitResult,
		Miss = "Miss" :: HitResult,
	},
	GuardResult = {
		None = "None" :: GuardResult,
		Normal = "Normal" :: GuardResult,
		Perfect = "Perfect" :: GuardResult,
		Break = "Break" :: GuardResult,
	},
}

return CombatTypes
