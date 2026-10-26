--!strict
--[[
	Enums et types partagés — Blade Concord P0–P3
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
	| "Dodge"
	| "Dash"
	| "FocusPush"
	| "FocusDash"
	| "Dead"

export type HitResult =
	"Full"
	| "Chip"
	| "Perfect"
	| "GuardBreak"
	| "Clash"
	| "Blocked"
	| "Miss"
	| "Dodged"

export type GuardResult = "None" | "Normal" | "Perfect" | "Break"

export type MobilityKind = "Dodge" | "Dash" | "Feint"

export type FocusKind = "Push" | "DashFocus"

export type MatchMode = "Casual" | "Ranked"

export type CombatFlags = {
	guarding: boolean,
	exhausted: boolean,
	riposteLock: boolean,
	stagger: boolean,
	riposteBuff: boolean,
	iFrames: boolean,
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
		Dodge = "Dodge" :: ActionId,
		Dash = "Dash" :: ActionId,
		FocusPush = "FocusPush" :: ActionId,
		FocusDash = "FocusDash" :: ActionId,
		Dead = "Dead" :: ActionId,
	},
	HitResult = {
		Full = "Full" :: HitResult,
		Chip = "Chip" :: HitResult,
		Perfect = "Perfect" :: HitResult,
		GuardBreak = "GuardBreak" :: HitResult,
		Clash = "Clash" :: HitResult,
		Miss = "Miss" :: HitResult,
		Dodged = "Dodged" :: HitResult,
	},
	GuardResult = {
		None = "None" :: GuardResult,
		Normal = "Normal" :: GuardResult,
		Perfect = "Perfect" :: GuardResult,
		Break = "Break" :: GuardResult,
	},
	MobilityKind = {
		Dodge = "Dodge" :: MobilityKind,
		Dash = "Dash" :: MobilityKind,
		Feint = "Feint" :: MobilityKind,
	},
	FocusKind = {
		Push = "Push" :: FocusKind,
		DashFocus = "DashFocus" :: FocusKind,
	},
	MatchMode = {
		Casual = "Casual" :: MatchMode,
		Ranked = "Ranked" :: MatchMode,
	},
}

return CombatTypes
