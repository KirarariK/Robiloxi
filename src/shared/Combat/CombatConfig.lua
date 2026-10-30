--!strict
-- Ether Blades — réglages d'équilibrage du combat, centralisés et commentés.
-- Temps en secondes, distances en studs, vitesses en studs/s.
-- Les stats d'arme (Config/WeaponData) puis de Voie (Config/FormData .Stats) s'appliquent PAR-DESSUS ces bases.

export type CombatState = "Idle" | "Attacking" | "Blocking" | "Parrying" | "Dodging" | "Stunned" | "GuardBroken" | "Dead"
export type Action = "Light" | "Heavy" | "BlockStart" | "BlockEnd" | "Parry" | "Dodge"
export type Variant = "Neutral" | "Forward" | "Side" | "Back"

export type VariantMods = {
	Suffix: string, -- suffixe du clip d'animation (« M1_2_F »…)
	DamageMult: number,
	WindupMult: number,
	ArcBonus: number, -- degrés ajoutés à l'arc de l'arme
}

local Config = {}

-- Tag CollectionService posé par le serveur sur chaque combattant (joueurs + mannequins).
Config.FighterTag = "EtherBladesFighter"

-- Noms des attributs répliqués sur le Character (les 8 premiers font partie du contrat UI).
Config.Attr = table.freeze({
	Posture = "Posture",
	MaxPosture = "MaxPosture",
	Stamina = "Stamina",
	MaxStamina = "MaxStamina",
	HealthPct = "HealthPct",
	State = "CombatState",
	InDuel = "InDuel",
	-- attributs propres au combat (lus par les clients pour les visuels)
	Weapon = "CombatWeapon", -- WeaponType
	Form = "CombatForm", -- FormId (= AnimSet)
	Color = "SaberColor", -- Id de SaberColors
	SaberOn = "SaberOn", -- lame allumée
	Frozen = "CombatFrozen", -- gel (intro, Saber Lock, exécution)
	SaberLock = "SaberLock", -- en blocage de lames
	Dummy = "CombatDummy", -- mannequin d'entraînement
	Combo = "ComboIndex", -- dernier coup du combo
})

Config.States = table.freeze({ "Idle", "Attacking", "Blocking", "Parrying", "Dodging", "Stunned", "GuardBroken", "Dead" })
Config.ActionSet = table.freeze({
	Light = true,
	Heavy = true,
	BlockStart = true,
	BlockEnd = true,
	Parry = true,
	Dodge = true,
} :: { [string]: boolean })

-- Réseau / validation des intentions client
Config.Net = table.freeze({
	InputRate = 18, -- intentions par seconde (seau à jetons)
	InputBurst = 10,
	MaxDirMagnitude = 1.05, -- la direction doit être normalisée (tolérance d'arrondi)
	MaxClientSkew = 1, -- s : un horodatage client plus éloigné que ça de l'heure serveur est ignoré
	AttrRate = 10, -- Hz : fréquence d'écriture des attributs Posture / Stamina pendant les régénérations
})

-- Vitalité
Config.Health = table.freeze({
	Max = 100, -- PV par round
})

Config.Stamina = table.freeze({
	Max = 100,
	RegenPerSec = 24,
	RegenDelay = 0.75, -- après une dépense
	BlockRegenFactor = 0.5, -- régénération réduite en garde
})

Config.Posture = table.freeze({
	RegenDelay = 1.6, -- après une perte de posture ; débit = WeaponData.PostureRegen /s
	BlockHoldDrainPerSec = 2.5, -- drain continu en garde (× BlockCostMultiplier × BlockPostureCost)
	DrainFloor = 0.15, -- le drain seul ne descend jamais sous 15 % (seuls les coups brisent la garde)
	BrokenRecoverFraction = 0.5, -- posture rendue à la fin de GuardBroken
})

-- Coups légers (M1)
Config.Light = table.freeze({
	Windup = 0.17, -- avant l'impact (÷ vitesse d'attaque) — snappy sans casser la lecture
	Recovery = 0.24, -- après l'impact (÷ vitesse d'attaque)
	ComboResetTime = 0.8, -- au-delà, le combo repart au coup 1
	FinisherExtraRecovery = 0.2, -- dernier coup du combo : récupération plus longue
	FinisherDamageMult = 1.25,
	FinisherPostureMult = 1.6,
	PostureDamage = 7, -- × FormStats.PostureDamage
	StaminaCost = 6, -- × WeaponData.StaminaCost × FormStats.StaminaCost
	ComboPushFraction = 0.35, -- Équilibre : fraction de KineticPush appliquée à chaque coup (100 % au dernier)
	HitStun = 0.24, -- vacillement de la cible touchée (sans armure)
	MaxTargets = 3, -- cibles par coup (Bâton-Lame à 360°)
})

-- Variantes de combo selon la direction de déplacement
Config.Variants = table.freeze({
	Neutral = table.freeze({ Suffix = "", DamageMult = 1, WindupMult = 1, ArcBonus = 0 }),
	Forward = table.freeze({ Suffix = "_F", DamageMult = 1.08, WindupMult = 1.06, ArcBonus = -10 }), -- fente
	Side = table.freeze({ Suffix = "_S", DamageMult = 0.95, WindupMult = 1, ArcBonus = 35 }), -- coupe large
	Back = table.freeze({ Suffix = "_B", DamageMult = 0.85, WindupMult = 0.85, ArcBonus = 0 }), -- retrait rapide
} :: { [string]: VariantMods })
Config.VariantThreshold = 0.5 -- produit scalaire minimal pour classer une direction

-- Coup lourd (M2) : appui = début de charge, relâchement = frappe (ou frappe automatique à MaxCharge)
Config.Heavy = table.freeze({
	MinCharge = 0.3,
	MaxCharge = 1.0,
	AutoReleaseSlack = 0.15, -- marge serveur avant la frappe automatique (latence du relâchement)
	StaleReleaseGrace = 0.35, -- un « Heavy » reçu juste après une frappe auto est un relâchement tardif, ignoré
	MinChargeFactor = 0.7, -- puissance à charge minimale (1 à charge maximale)
	StrikeWindup = 0.18, -- entre relâchement et impact (÷ vitesse) ; récupération = WeaponData.HeavyRecovery
	StaminaCost = 16,
	HitPostureFraction = 0.5, -- posture infligée sur un coup lourd non bloqué
	BasePush = 1.5, -- studs de recul sur un lourd (+ KineticPush)
})

-- Garde
Config.Block = table.freeze({
	ArcDeg = 160, -- la garde protège un cône frontal
	LightMult = 1, -- coût posture d'un léger bloqué (× posture du coup)
	HeavyMult = 1, -- coût posture d'un lourd bloqué (brise-garde : HeavyPostureDamage est déjà élevé)
	HeavyChip = 0.15, -- fraction des dégâts d'un lourd qui traverse la garde
	AttackerRecoil = 0.12, -- l'attaquant bloqué récupère plus lentement
	PushFraction = 0.5, -- recul subi en garde (fraction de la poussée)
})

-- Parade parfaite
Config.Parry = table.freeze({
	BaseWindow = 0.18, -- × FormStats.ParryWindow
	MaxLatencyGrace = 0.06, -- fin de fenêtre prolongée par le ping (plafonné)
	WhiffRecovery = 0.3, -- parade dans le vide : impossible d'agir
	WhiffCooldown = 0.45, -- parade dans le vide : impossible de reparer
	StaminaCost = 4,
	AttackerStun = 0.85, -- étourdissement de l'attaquant paré
	AttackerStunHeavy = 1.1,
	PostureDamageToAttacker = 14, -- + FormStats.ParryReflect × posture du coup paré (Riposte)
	PostureRefund = 6, -- le défenseur regagne un peu de posture
})

-- Contre-attaque (Rempart : FormStats.CounterWindow après une parade)
Config.Counter = table.freeze({
	WindupMult = 0.45,
	DamageMult = 1.5,
	Unblockable = true, -- ne peut être que paré ou esquivé
})

Config.Stunned = table.freeze({
	DamageMult = 1.2, -- dégâts subis étourdi
})

Config.GuardBroken = table.freeze({
	Duration = 1.4,
	DamageMult = 1.6, -- « gros dégâts » sur garde brisée
})

-- Esquive
Config.Dodge = table.freeze({
	Duration = 0.34, -- ÷ FormStats.DodgeSpeed
	IFrames = 0.24, -- invulnérabilité depuis le début de l'esquive
	Distance = 11.5,
	StaminaCost = 22,
	Cooldown = 0.42, -- après la fin de l'esquive
})

-- Saber Lock / Clash : deux lourds relâchés presque en même temps à portée
Config.Clash = table.freeze({
	Window = 0.25, -- écart maximal entre les deux relâchements
	ExtraRange = 1.5, -- portée max (la plus grande des deux) + marge
	Duration = 1.5, -- gel des deux combattants (ralenti côté client)
	PostureDamage = 16, -- subi par les deux à la sortie
	PushSpeed = 38, -- séparation
	PushDuration = 0.22,
	RecoveryAfter = 0.2,
})

-- Poussées (KineticPush, recul des lourds)
Config.Push = table.freeze({
	Duration = 0.2,
	MaxStuds = 8,
})

-- Déplacements selon l'état (WalkSpeed serveur)
Config.Movement = table.freeze({
	Base = 16,
	Attacking = 11,
	Charging = 8,
	Blocking = 9,
	Stunned = 5,
	JumpHeight = 7.2, -- × FormStats.JumpPower
	AirProbe = 3.6, -- studs sous la racine : au-delà, le coup est aérien (× FormStats.AerialBonus)
})

-- Entrées tamponnées : un léger envoyé un peu avant la fin de la récupération est exécuté à temps
Config.Input = table.freeze({
	Buffer = 0.16,
})

-- Hub : allumage implicite, extinction auto
Config.Hub = table.freeze({
	IgniteLock = 0.45, -- la première intention allume la lame (et est consommée)
	AutoExtinguish = 25, -- s sans intention de combat → lame éteinte
	LoadoutPoll = 1, -- s : relit l'équipement du profil (changement à l'atelier)
})

-- Mannequins d'entraînement (Workspace.Hub.Dummy_1..3)
Config.Dummy = table.freeze({
	Health = 150,
	RespawnDelay = 3,
	IdleReset = 8, -- s sans être touché → soin complet
	ParryChance = 0.22,
	BlockChance = 0.3,
	ReactRange = 4, -- studs au-delà de la portée de l'attaquant
	BlockHold = 1.1,
	FaceRange = 22,
	TurnSpeed = 6, -- lissage de l'orientation
	PushReturn = 3, -- vitesse de retour à l'emplacement après une poussée
	Loadouts = table.freeze({
		table.freeze({ Weapon = "Single", Form = "Origine", Color = "Ambre" }),
		table.freeze({ Weapon = "Dual", Form = "Rempart", Color = "Emeraude" }),
		table.freeze({ Weapon = "Staff", Form = "Equilibre", Color = "Ecarlate" }),
	}),
})

-- Cinématiques (le serveur attend ces durées)
Config.Intro = table.freeze({
	Duration = 3.6,
	IgniteAt = 1.35, -- allumage synchronisé des deux lames
	ReturnTime = 0.6, -- retour fluide à la caméra de jeu (inclus dans Duration)
})

Config.Finisher = table.freeze({
	Duration = 2.6,
	StrikeAt = 1.55, -- coup final (extinction de la lame du perdant)
	Distance = 4.2, -- le perdant est placé face au vainqueur
})

-- Visuels de lame (client)
Config.Blade = table.freeze({
	Length = table.freeze({ Single = 3.7, Dual = 3.1, Staff = 3.2 } :: { [string]: number }),
	CoreWidth = 0.15,
	GlowWidth = 0.34,
	GlowTransparency = 0.55,
	IgniteTime = 0.22,
	RetractTime = 0.3,
	LightRange = 9,
	TrailSpeed = 22, -- vitesse de pointe (studs/s) au-delà de laquelle la traînée s'active
	SwingSpeed = 38, -- vitesse de pointe déclenchant le son de swing
	SwingCooldown = 0.16,
	HumVolume = 0.12,
	EffectRate = 20, -- Hz : mise à jour des effets animés (Prisme, Nébuleuse, Instable…)
})

-- VFX (client)
Config.Vfx = table.freeze({
	BurnMaxMarks = 40,
	BurnLifetime = 4.5,
	BurnSpacing = 0.45,
	BurnLights = 4,
	BurnRate = 20, -- Hz : raycasts le long des lames
	BurnRaysPerTick = 6, -- budget de raycasts par tick
	BurnMaxDistance = 140, -- lames plus loin de la caméra ignorées
	HeatRadius = 28, -- flou / correction de couleur seulement si l'impact est proche de la caméra
})

-- Caméra (client)
Config.Camera = table.freeze({
	ShakeLight = 0.18,
	ShakeHeavy = 0.55,
	ShakeParry = 0.45,
	ShakeGuardBreak = 0.7,
	HitStopLight = 0.048,
	HitStopHeavy = 0.1,
	HitStopParry = 0.12,
	LockFov = 48,
	LockTimeScale = 0.3,
	LockRange = 70, -- un Saber Lock plus loin ne déclenche pas le zoom
})

-- Sons intégrés (rbxasset) — aucun upload
Config.Sounds = table.freeze({
	Hum = "rbxasset://sounds/electronicpingshort.wav",
	Swing = "rbxasset://sounds/swordslash.wav",
	Lunge = "rbxasset://sounds/swordlunge.wav",
	Ignite = "rbxasset://sounds/unsheath.wav",
	Clash = "rbxasset://sounds/metal.ogg",
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Hit = "rbxasset://sounds/hit.wav",
	Click = "rbxasset://sounds/button.wav",
})

Config.Textures = table.freeze({
	Sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
})

return table.freeze(Config)
