--!strict
-- Types partagés client / serveur d'Ether Blades.

export type Rarity = "Commun" | "Rare" | "Epique" | "Legendaire" | "Mythique"

export type WeaponType = "Single" | "Dual" | "Staff"

export type FormId = "Origine" | "Duelliste" | "Rempart" | "Faucon" | "Riposte" | "Equilibre" | "Tempete"

export type FormStats = {
	-- multiplicateurs appliqués aux valeurs de base de l'arme (1 = neutre)
	PostureDamage: number,
	BlockPostureCost: number,
	ParryWindow: number,
	DodgeSpeed: number,
	StaminaCost: number,
	JumpPower: number,
	AttackSpeed: number,
	-- effets spéciaux (0 = absent)
	CounterWindow: number, -- s : fenêtre de contre-attaque rapide après une parade
	ParryReflect: number, -- fraction des dégâts de posture renvoyée sur parade parfaite
	KineticPush: number, -- studs de poussée intégrée aux combos
	AerialBonus: number, -- multiplicateur des attaques aériennes
}

export type FormDef = {
	Id: FormId,
	Order: number,
	Name: string,
	Roman: string,
	Rarity: Rarity,
	Weight: number,
	Description: string,
	Passive: string,
	AnimSet: string,
	Stats: FormStats,
}

export type WeaponDef = {
	Id: WeaponType,
	Name: string,
	Description: string,
	ComboLength: number,
	LightDamage: number,
	HeavyDamage: number,
	HeavyPostureDamage: number,
	AttackSpeed: number,
	MaxPosture: number,
	PostureRegen: number,
	BlockCostMultiplier: number,
	HeavyRecovery: number,
	Reach: number,
	Arc: number, -- degrés couverts par un coup (360 = circulaire)
	StaminaCost: number,
}

export type BladeEffect = "None" | "DarkCore" | "Unstable" | "InkCore" | "Prism" | "Nebula"

export type SaberColorDef = {
	Id: string,
	Name: string,
	Category: "Classique" | "Speciale" | "Mythique",
	Rarity: Rarity,
	Core: Color3,
	Glow: Color3,
	Effect: BladeEffect,
	HumPitch: number,
	LightBrightness: number,
}

export type RankTier = {
	Id: string,
	Name: string,
	MinElo: number,
	Color: Color3,
	TopOnly: number?, -- réservé au top N mondial
}

export type ArenaDef = {
	Id: string,
	Name: string,
	Description: string,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ClockTime: number,
	FogColor: Color3,
	FogEnd: number,
	Hazard: "None" | "Lava" | "Void",
}

export type TitleDef = {
	Id: string,
	Text: string,
	Rarity: Rarity,
	Source: "Default" | "Rank" | "Wins" | "Mastery" | "Reroll" | "Streak",
	Requirement: number, -- valeur requise (Elo, victoires, maîtrise…) ; 0 si non chiffré
	FormId: FormId?,
	Gradient: { Color3 },
}

export type EmoteDef = {
	Id: string,
	Name: string,
	Category: "Salut" | "Meditation" | "Flourish" | "Provocation" | "Victoire",
	Duration: number,
	Looped: boolean,
}

export type Profile = {
	Version: number,
	Elo: number,
	PeakElo: number,
	Wins: number,
	Losses: number,
	WinStreak: number,
	BestStreak: number,
	RankedPlayed: number,
	Rerolls: number,
	RerollPity: number, -- tirages consécutifs sans Voie Épique+ (le 50e est garanti Épique+)
	Crystals: number, -- monnaie gagnée en duel, dépensée en relances
	EquippedForm: FormId,
	OwnedForms: { [FormId]: boolean },
	FormMastery: { [FormId]: number },
	EquippedWeapon: WeaponType,
	EquippedColor: string,
	OwnedColors: { [string]: boolean },
	EquippedTitle: string,
	OwnedTitles: { [string]: boolean },
	EquippedEmotes: { string },
	LeavePenaltyUntil: number,
	FirstJoin: number,
	LastJoin: number,
}

return {}
