--!strict
--[[
	Constants.luau
	Constantes globales, tables d'équilibrage, identifiants de monétisation et
	énumérations encodées (u8) pour le réseau.

	Convention monétisation : un identifiant à 0 signifie « pas encore créé sur le
	Creator Hub ». MonetizationService simule alors l'achat en Studio uniquement et
	le refuse en jeu publié.
]]

local Types = require(script.Parent.Types)

type Posture = Types.Posture
type ContractDefinition = Types.ContractDefinition
type ContractId = Types.ContractId
type MaterialKey = Types.MaterialKey

export type EnumCodec = {
	ToId: { [string]: number },
	FromId: { [number]: string },
}

export type MaterialSpec = {
	Color: Color3,
	Material: Enum.Material,
	Reflectance: number,
	Transparency: number,
	Neon: boolean,
}

export type NoiseSpec = {
	Radius: number,
	Intensity: number,
}

local function codec(names: { string }): EnumCodec
	local toId: { [string]: number } = {}
	local fromId: { [number]: string } = {}
	for index, name in names do
		toId[name] = index
		fromId[index] = name
	end
	return table.freeze({
		ToId = table.freeze(toId),
		FromId = table.freeze(fromId),
	})
end

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Constants = {}

Constants.GameName = "Syndicate Black Market"
Constants.DataVersion = 1
Constants.DataStoreName = "SBM_PlayerData_v1"

--// Énumérations réseau (encodées en u8, index 1-based)
Constants.Enums = table.freeze({
	Posture = codec({ "Standing", "Crouching", "Sprinting", "Sliding" }),
	HeistPhase = codec({ "Hub", "Briefing", "Stealth", "Lockdown", "Extraction", "Success", "Failed" }),
	GuardState = codec({ "Patrol", "Investigating", "Alerting", "Combat", "Neutralized", "Disabled" }),
	NotifyKind = codec({ "Info", "Success", "Warning", "Danger", "Reward" }),
	EquipSlot = codec({ "Primary", "Secondary", "CyberDeck", "EMP" }),
})

--// Grille modulaire des salles
Constants.Grid = table.freeze({
	CellSize = 24,
	CeilingHeight = 14,
	VaultCeilingHeight = 18,
	DoorWidth = 8,
	DoorHeight = 10,
	WallThickness = 1,
	BoundingBoxShrink = 0.2,
})

--// Génération procédurale
Constants.MapGen = table.freeze({
	SecurityHubStep = 6,
	MaxAttemptsPerConnector = 6,
	MaxBacktrackDepth = 4,
	ActiveMapName = "ActiveMap",
	SpawnModule = "Mod_Spawn_Extraction",
	SecurityModule = "Mod_Room_SecurityHub",
	VaultModule = "Mod_Room_HighTechVault",
	CapModule = "Mod_Cap_DeadEnd",
	FillerModules = table.freeze({
		"Mod_Hallway_Straight",
		"Mod_Hallway_Corner",
		"Mod_Hallway_TJunction",
		"Mod_Room_ServerFarm",
		"Mod_Room_ExecutiveOffice",
	}),
	FillerWeights = table.freeze({
		Mod_Hallway_Straight = 30,
		Mod_Hallway_Corner = 22,
		Mod_Hallway_TJunction = 18,
		Mod_Room_ServerFarm = 14,
		Mod_Room_ExecutiveOffice = 16,
	} :: { [string]: number }),
})

--// Déplacements
Constants.Movement = table.freeze({
	WalkSpeed = 14,
	SprintSpeed = 22,
	CrouchSpeed = 7,
	SprintThreshold = 20,
	MaxStamina = 100,
	SprintDrainPerSecond = 18,
	StaminaRegenPerSecond = 24,
	StaminaRegenDelay = 1,
	SlideInitialVelocity = 28,
	SlideDuration = 0.85,
	SlideCooldown = 1.5,
	SlideStaminaCost = 15,
	SlideCameraOffset = Vector3.new(0, -2.2, 0),
	SlideTilt = 8,
	CrouchCameraOffset = Vector3.new(0, -1.4, 0),
	StrafeTiltMax = 3.5,
	CrouchHipHeight = 1.2,
	-- Tolérance serveur de l'anti-vitesse (multiplicateur de la vitesse autorisée).
	ServerSpeedTolerance = 1.35,
})

--// Poids et encombrement
-- Vitesse = base * max(MinSpeedMultiplier, 1 - MaxPenalty * (poids / capacité) ^ PenaltyExponent)
Constants.Weight = table.freeze({
	BaseMaxWeight = 20,
	MagneticBagMaxWeight = 25,
	MaxPenalty = 0.55,
	PenaltyExponent = 1.25,
	MinSpeedMultiplier = 0.45,
	HeavyThreshold = 5,
})

--// Lancer de sac
Constants.Throw = table.freeze({
	ForwardVelocity = 35,
	UpwardVelocity = 15,
	SpawnDistance = 3,
	Cooldown = 0.6,
	PickupRange = 8,
	BagLifetime = 600,
})

--// Détection (gardes et caméras)
-- Gain/s = BaseDetectionPerSecond * posture * lerp(NearFactor, FarFactor, distance / portée)
Constants.Detection = table.freeze({
	TickRate = 0.1,
	BaseDetectionPerSecond = 55,
	NearFactor = 1.6,
	FarFactor = 0.4,
	InstantDetectDistance = 6,
	DecayPerSecond = 12,
	InvestigateThreshold = 35,
	AlertThreshold = 100,
	RadioDuration = 2.5,
	GuardFov = 100,
	GuardViewDistance = 60,
	CameraFov = 70,
	CameraViewDistance = 45,
	CameraSweepAngle = 70,
	CameraSweepSpeed = 0.35,
	PostureMultipliers = table.freeze({
		Standing = 1,
		Crouching = 0.5,
		Sprinting = 1.8,
		Sliding = 1.2,
	} :: { [Posture]: number }),
})

--// Bruits émis (rayon en studs, intensité 0..1)
Constants.Noise = table.freeze({
	Sprint = table.freeze({ Radius = 22, Intensity = 0.4 } :: NoiseSpec),
	Slide = table.freeze({ Radius = 18, Intensity = 0.35 } :: NoiseSpec),
	GlassBreak = table.freeze({ Radius = 40, Intensity = 0.8 } :: NoiseSpec),
	BagLanding = table.freeze({ Radius = 16, Intensity = 0.35 } :: NoiseSpec),
	HackFailure = table.freeze({ Radius = 35, Intensity = 0.9 } :: NoiseSpec),
	Explosion = table.freeze({ Radius = 120, Intensity = 1 } :: NoiseSpec),
})

--// IA
Constants.AI = table.freeze({
	GuardHealth = 120,
	GuardWalkSpeed = 9,
	GuardRunSpeed = 16,
	GuardDamage = 9,
	GuardShotsPerSecond = 2.5,
	GuardAccuracy = 0.55,
	GuardInvestigateTime = 8,
	FlashlightRange = 40,
	SwatHealth = 220,
	SwatWalkSpeed = 15,
	SwatDamage = 12,
	SwatShotsPerSecond = 4,
	SwatAccuracy = 0.62,
	SwatSquadSize = 4,
	SwatWaveInterval = 40,
	MaxActiveSwat = 16,
	PathRecomputeInterval = 0.75,
	AgentRadius = 2,
	AgentHeight = 5,
})

--// Combat (validation serveur)
Constants.Combat = table.freeze({
	PlayerMaxHealth = 100,
	MaxShotOriginDistance = 6,
	MaxShotLatency = 0.6,
	HitboxPadding = 1,
	ArmorCap = 0.4,
})

--// Piratage CyberDeck (mini-jeu de timing, vérifié côté serveur)
Constants.Hacking = table.freeze({
	Stages = 3,
	CursorCyclesPerSecond = 0.75,
	TargetZoneWidth = 0.14,
	StageSpeedGrowth = 1.25,
	LatencyTolerance = 0.03,
	SessionTimeout = 20,
	FailureDamage = 15,
	SuccessXp = 50,
	InteractRange = 10,
})

--// EMP
Constants.EMP = table.freeze({
	PlaceRange = 12,
})

--// Phase d'extraction
Constants.Extraction = table.freeze({
	Countdown = 20,
	ObjectiveValue = 5000,
	ObjectiveLootId = "QuantumCore",
})

--// Réanimation d'escouade
Constants.SquadRevive = table.freeze({
	Countdown = 10,
	RevivedHealthFraction = 0.6,
	InvulnerabilityAfterRevive = 3,
})

--// Assurance butin
Constants.Insurance = table.freeze({
	Coverage = 0.5,
})

--// Planque / Hub
Constants.Hub = table.freeze({
	MiningInterval = 10,
	PremiumMiningBonus = 0.15,
	DoubleMiningMultiplier = 2,
	MiningSeatRange = 6,
	SafehouseSpacing = 96,
	MaxSafehouses = 8,
})

--// Escouades
Constants.Party = table.freeze({
	MinSize = 1,
	MaxSize = 4,
	InviteTimeout = 30,
	LaunchCountdown = 5,
})

--// Progression (XP requise pour passer le niveau N : round(XpBase * N ^ XpExponent))
Constants.Progression = table.freeze({
	XpBase = 250,
	XpExponent = 1.5,
	XpPerThousandLoot = 20,
	GhostBonusMultiplier = 1.25,
})

--// Monétisation
Constants.Monetization = table.freeze({
	GamePasses = table.freeze({
		MagneticBag = 0,
		DoubleMining = 0,
	} :: { [string]: number }),
	Products = table.freeze({
		SquadRevive = 0,
		ClassifiedContract = 0,
		LootInsurance = 0,
	} :: { [string]: number }),
	DisplayPrices = table.freeze({
		MagneticBag = 199,
		DoubleMining = 299,
		SquadRevive = 49,
		ClassifiedContract = 99,
		LootInsurance = 25,
	} :: { [string]: number }),
})

--// Contrats
local contracts: { [ContractId]: ContractDefinition } = {
	CorporateStore = table.freeze({
		Id = "CorporateStore",
		DisplayName = "Supérette Corporative",
		Description = "Peu de gardes, caméras basiques. Idéal pour se faire la main.",
		Difficulty = "Easy",
		MinRooms = 14,
		MaxRooms = 15,
		GuardCount = 4,
		CameraCount = 3,
		LaserCount = 2,
		RarityBias = 0.6,
		RewardMultiplier = 1,
		ObjectiveValue = 5000,
		GuaranteedGoldVault = false,
		RequiresProduct = false,
	} :: ContractDefinition),
	DataCenter = table.freeze({
		Id = "DataCenter",
		DisplayName = "Centre de Données",
		Description = "Fermes de serveurs, patrouilles serrées et lasers.",
		Difficulty = "Medium",
		MinRooms = 15,
		MaxRooms = 16,
		GuardCount = 7,
		CameraCount = 5,
		LaserCount = 4,
		RarityBias = 1.2,
		RewardMultiplier = 1.6,
		ObjectiveValue = 5000,
		GuaranteedGoldVault = false,
		RequiresProduct = false,
	} :: ContractDefinition),
	SyndicateBank = table.freeze({
		Id = "SyndicateBank",
		DisplayName = "Banque Centrale du Syndicat",
		Description = "Sécurité maximale. Le coffre regorge de lingots.",
		Difficulty = "Extreme",
		MinRooms = 17,
		MaxRooms = 18,
		GuardCount = 10,
		CameraCount = 7,
		LaserCount = 7,
		RarityBias = 2,
		RewardMultiplier = 2.5,
		ObjectiveValue = 5000,
		GuaranteedGoldVault = false,
		RequiresProduct = false,
	} :: ContractDefinition),
	Classified = table.freeze({
		Id = "Classified",
		DisplayName = "Contrat Classifié",
		Description = "Coffre doré garanti. Réservé aux contrats achetés.",
		Difficulty = "Extreme",
		MinRooms = 16,
		MaxRooms = 18,
		GuardCount = 9,
		CameraCount = 6,
		LaserCount = 6,
		RarityBias = 2.4,
		RewardMultiplier = 2.2,
		ObjectiveValue = 5000,
		GuaranteedGoldVault = true,
		RequiresProduct = true,
	} :: ContractDefinition),
}
Constants.Contracts = table.freeze(contracts)
Constants.ContractOrder = table.freeze({ "CorporateStore", "DataCenter", "SyndicateBank", "Classified" } :: { ContractId })

--// Groupes de collision
Constants.CollisionGroups = table.freeze({
	Players = "Players",
	Doors = "Doors",
	LootBags = "LootBags",
	RaycastIgnore = "RaycastIgnore",
	NPCs = "NPCs",
})

--// Tags CollectionService
Constants.Tags = table.freeze({
	Connector = "SBM_Connector",
	BoundingBox = "SBM_BoundingBox",
	LootSpawn = "SBM_LootSpawn",
	GuardSpawn = "SBM_GuardSpawn",
	PatrolPoint = "SBM_PatrolPoint",
	CameraMount = "SBM_CameraMount",
	LaserEmitter = "SBM_LaserEmitter",
	HackTerminal = "SBM_HackTerminal",
	SecureZone = "SBM_SecureZone",
	MiningSeat = "SBM_MiningSeat",
	Breakable = "SBM_Breakable",
	LightFixture = "SBM_LightFixture",
	LootBag = "SBM_LootBag",
	Objective = "SBM_Objective",
	SwatSpawn = "SBM_SwatSpawn",
})

--// Attributs
Constants.Attributes = table.freeze({
	LootId = "LootId",
	LootValue = "LootValue",
	LootWeight = "LootWeight",
	RoomName = "RoomName",
	RoomCategory = "RoomCategory",
	RoomDepth = "RoomDepth",
	Posture = "Posture",
	CarryWeight = "CarryWeight",
	CarryValue = "CarryValue",
	Stamina = "Stamina",
	Downed = "Downed",
	PartyId = "PartyId",
	Disabled = "Disabled",
	TerminalKind = "TerminalKind",
	Owner = "Owner",
})

--// Palette (cahier des charges)
Constants.Colors = table.freeze({
	DarkMetal = hex("#1A1D24"),
	Concrete = hex("#26282E"),
	Carbon = hex("#111215"),
	NeonCyan = hex("#00F0FF"),
	NeonCrimson = hex("#FF003C"),
	NeonGold = hex("#FFD700"),
	UIBackground = hex("#0B0E14"),
	UIText = hex("#E6F7FF"),
	UIMuted = hex("#7A8699"),
	Warning = hex("#FFC400"),
	Success = hex("#38FF8C"),
	White = Color3.new(1, 1, 1),
})

--// Matériaux Studio équivalents aux matériaux PBR Blender
local materials: { [MaterialKey]: MaterialSpec } = {
	DarkMetal = table.freeze({ Color = hex("#1A1D24"), Material = Enum.Material.DiamondPlate, Reflectance = 0.15, Transparency = 0, Neon = false } :: MaterialSpec),
	ConcreteFloor = table.freeze({ Color = hex("#26282E"), Material = Enum.Material.Concrete, Reflectance = 0, Transparency = 0, Neon = false } :: MaterialSpec),
	CarbonFiber = table.freeze({ Color = hex("#111215"), Material = Enum.Material.Metal, Reflectance = 0.05, Transparency = 0, Neon = false } :: MaterialSpec),
	NeonCyan = table.freeze({ Color = hex("#00F0FF"), Material = Enum.Material.Neon, Reflectance = 0, Transparency = 0, Neon = true } :: MaterialSpec),
	NeonCrimson = table.freeze({ Color = hex("#FF003C"), Material = Enum.Material.Neon, Reflectance = 0, Transparency = 0, Neon = true } :: MaterialSpec),
	NeonGold = table.freeze({ Color = hex("#FFD700"), Material = Enum.Material.Foil, Reflectance = 0.35, Transparency = 0, Neon = false } :: MaterialSpec),
	Glass = table.freeze({ Color = hex("#9FE8FF"), Material = Enum.Material.Glass, Reflectance = 0.2, Transparency = 0.6, Neon = false } :: MaterialSpec),
}
Constants.Materials = table.freeze(materials)

--// Interface
Constants.UI = table.freeze({
	Font = Enum.Font.RobotoMono,
	HeaderFont = Enum.Font.GothamBlack,
	BackgroundTransparency = 0.2,
	StrokeThickness = 1,
	CornerRadius = UDim.new(0, 6),
	TweenFast = 0.12,
	TweenMedium = 0.25,
})

return table.freeze(Constants)
