--!strict
--[[
	Types.luau
	Définitions de types partagées entre le serveur et le client.
	Ce module ne contient que des types : il ne retourne qu'une table vide figée.
]]

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type Posture = "Standing" | "Crouching" | "Sprinting" | "Sliding"
export type HeistPhase = "Hub" | "Briefing" | "Stealth" | "Lockdown" | "Extraction" | "Success" | "Failed"
export type GuardState = "Patrol" | "Investigating" | "Alerting" | "Combat" | "Neutralized" | "Disabled"
export type Difficulty = "Easy" | "Medium" | "Extreme"
export type ContractId = "CorporateStore" | "DataCenter" | "SyndicateBank" | "Classified"
export type RoomCategory = "Spawn" | "Hallway" | "Room" | "SecurityHub" | "Vault" | "Cap"
export type NotifyKind = "Info" | "Success" | "Warning" | "Danger" | "Reward"
export type UpgradeCategory = "Mining" | "Skill" | "Armory"
export type EquipmentKind = "Weapon" | "Tool"
export type MaterialKey = "DarkMetal" | "ConcreteFloor" | "CarbonFiber" | "NeonCyan" | "NeonCrimson" | "NeonGold" | "Glass"

export type LootDefinition = {
	Id: string,
	DisplayName: string,
	Rarity: Rarity,
	Value: number,
	Weight: number,
	ModelName: string,
	-- Les objets lourds vont dans le sac (jetable avec G), les légers dans les poches.
	IsHeavy: boolean,
	-- Objectif principal du casse (placé par le générateur sur le piédestal du coffre).
	IsObjective: boolean,
	-- Poids de tirage de base avant application de la proximité au coffre.
	SpawnWeight: number,
	-- Proximité minimale au coffre (0 = spawn, 1 = coffre) pour que l'objet puisse apparaître.
	MinVaultProximity: number,
}

export type RecoilProfile = {
	Vertical: number, -- degrés de montée par tir
	Horizontal: number, -- amplitude aléatoire latérale en degrés
	Recovery: number, -- vitesse de retour (degrés/s)
	Kick: number, -- recul du viewmodel en studs
}

export type WeaponDefinition = {
	Id: string,
	DisplayName: string,
	ModelName: string,
	Automatic: boolean,
	Damage: number,
	HeadshotMultiplier: number,
	FireRate: number, -- coups par minute
	MagazineSize: number,
	ReserveAmmo: number,
	ReloadTime: number,
	MaxRange: number,
	FalloffStart: number,
	MinDamageMultiplier: number,
	HipSpread: number, -- degrés
	AimSpread: number, -- degrés
	Recoil: RecoilProfile,
	NoiseRadius: number,
	NoiseIntensity: number,
	Suppressed: boolean,
	Price: number,
	AimFov: number,
}

export type ToolDefinition = {
	Id: string,
	DisplayName: string,
	ModelName: string,
	Price: number,
	Cooldown: number,
	Radius: number,
	Duration: number,
	Charges: number,
	NoiseRadius: number,
}

export type UpgradeLevel = {
	Level: number,
	Price: number,
	Value: number,
}

export type UpgradeDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	Category: UpgradeCategory,
	BaseValue: number,
	Levels: { UpgradeLevel },
	GrantsEquipment: string?,
}

export type ContractDefinition = {
	Id: ContractId,
	DisplayName: string,
	Description: string,
	Difficulty: Difficulty,
	MinRooms: number,
	MaxRooms: number,
	GuardCount: number,
	CameraCount: number,
	LaserCount: number,
	RarityBias: number,
	RewardMultiplier: number,
	ObjectiveValue: number,
	GuaranteedGoldVault: boolean,
	RequiresProduct: boolean,
}

export type PlayerStats = {
	HeistsCompleted: number,
	HeistsFailed: number,
	TotalLootValue: number,
	GuardsNeutralized: number,
	GhostRuns: number,
}

export type PlayerData = {
	Version: number,
	Credits: number,
	LifetimeCredits: number,
	Xp: number,
	Level: number,
	Upgrades: { [string]: number },
	OwnedEquipment: { [string]: boolean },
	Insurance: number,
	ClassifiedContracts: number,
	Stats: PlayerStats,
	ProcessedReceipts: { [string]: number },
	LastJoin: number,
}

export type CarriedLoot = {
	Uid: number,
	Id: string,
	Value: number,
	Weight: number,
}

export type NoiseEvent = {
	Position: Vector3,
	Radius: number,
	Intensity: number,
	Source: Player?,
}

export type PlacedRoom = {
	Model: Model,
	Name: string,
	Category: RoomCategory,
	Depth: number,
	BoundingBox: BasePart,
	Connectors: { BasePart },
	EntryConnector: BasePart?,
	Parent: PlacedRoom?,
}

export type OpenConnector = {
	Part: BasePart,
	Room: PlacedRoom,
}

return table.freeze({})
