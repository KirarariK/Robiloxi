--!strict
--[[
	Constantes combat — GDD §2.2 / §2.5 / §2.7 + P1 mobilité.
	Readonly conceptuel : ne pas muter à runtime hors tuning debug.
]]

local CombatConfig = {
	MaxHp = 100,

	Light = {
		Startup = 0.18,
		Active = 0.12,
		Recovery = 0.28,
		StaminaCost = 12,
		Damage = 12,
		HeadMultiplier = 1.15,
		BladeLength = 3.2,
		BladeRadius = 0.32,
		FlinchDuration = 0.12,
	},

	Heavy = {
		Startup = 0.38,
		Active = 0.16,
		Recovery = 0.48,
		StaminaCost = 28,
		Damage = 28,
		HeadMultiplier = 1.15,
		BladeLength = 3.2,
		BladeRadius = 0.40,
		StaggerOnHit = true,
		KnockdownHpThreshold = 30,
	},

	Guard = {
		MaxAngleDegrees = 55,
		PerfectWindow = 0.090, -- ±90 ms autour du contact serveur
		DrainPerSecond = 8,
		ImpactStaminaCost = 15,
		PerfectStaminaRefund = 10,
		ChipAbsorbFraction = 0.35, -- 35 % absorbés → 65 % passent
		GuardBreakStaminaThreshold = 15,
		GuardBreakStagger = 0.55,
		RiposteLockDuration = 0.25,
		RiposteBuffDuration = 1.2,
		RiposteLightDamageBonus = 0.30,
	},

	-- P1 mobilité (GDD §2.2)
	Dodge = {
		StaminaCost = 22,
		IFrames = 0.160, -- 160 ms
		Cooldown = 0.55,
		Distance = 8,
		StumbleNoIFrames = true, -- exhaustion → stumble sans i-frames
	},

	CombatDash = {
		StaminaCost = 30,
		Distance = 10,
		Cooldown = 0.70,
		IFrames = 0, -- pas d'i-frames
	},

	-- Double saut (Space en l’air) — server-auth
	DoubleJump = {
		MaxAirJumps = 1,
		UpVelocity = 52,
		Cooldown = 0.35,
	},

	Feint = {
		StaminaCost = 8,
		-- Cancel légère avant Active uniquement
	},

	Focus = {
		Push = {
			Cooldown = 14,
			StaminaCost = 20,
			ConeStuds = 8,
			KnockbackForce = 55,
			SelfStaggerOnParry = 0.3,
		},
		DashFocus = {
			Cooldown = 11,
			StaminaCost = 25,
			Distance = 12,
			IFrames = 0.100,
			StackBlockWithDodge = 0.4, -- pas de stack esquive dans 0,4 s
		},
	},

	Stamina = {
		Max = 100,
		RegenPerSecond = 18,
		RegenDelay = 0.35,
		ExhaustionThreshold = 15,
		ExhaustionWalkSpeedPenalty = 0.15, -- −15 % walkspeed
	},

	Clash = {
		StaminaPenalty = 8,
		MicroKnockbackStuds = 2.5,
	},

	Camera = {
		SoftLockMaxDistance = 80,
		SoftLockLerp = 0.12,
		Offset = Vector3.new(2.5, 3.5, 10),
		-- Soft spectate (mort) jusqu'au reset manche
		SpectatorLerp = 0.07,
		SpectatorOffset = Vector3.new(0, 6.5, 14),
		SpectatorHeightBias = 1.2,
	},

	AntiCheat = {
		AttackRateLimitPerSecond = 8,
		GuardIntentThrottleHz = 20,
		MobilityRateLimitPerSecond = 6,
		MaxHitDistanceMargin = 2, -- studs au-delà lame + hurtbox
		RecoveryFailsafe = 2.5, -- timeout softlock Idle
	},

	-- Caps VFX / Heartbeat (perf pass légère — anti-spam particles)
	Fx = {
		SparkBurstMax = 36,
		ClashEmitMax = 28,
		SparkBurstsPerSecond = 14,
		ArenaAshRateMax = 10,
		ArenaDriftRateMax = 8,
	},

	Match = {
		BestOf = 3, -- FT2
		FirstTo = 2,
		InterRoundDelay = 2.5,
		LobbyCountdown = 3,
		MatchEndDelay = 8, -- REVANCHE ou retour salon (auto → lobby)
		RematchClientCooldown = 1.4,
		RematchServerCooldown = 2.0,
		SoloMatchmakingDelay = 1.6, -- après Jouer Amical solo → bot
		SlotSoloBotDelay = 2.5, -- claim slot seul en Studio → ConcordBot
		-- Croiseur : 2 pads devant baie (BC_DuelSlot 1–2) → pool 8 arènes L/R
		MaxDuelSlots = 2,
		MatchArenaCount = 8,
	},

	Arena = {
		Default = "ObsidianPit",
		LavaDps = 8,
		WindForce = 18, -- Sanctum vents
		ThronePressureDps = 4, -- anti-camp estrade
		MiragePanelLifetime = 8,
		MinLethalFullHpSeconds = 3, -- règle GDD §6
	},

	Tags = {
		Hurtbox = "Hurtbox",
		SaberBlade = "SaberBlade",
		ArenaSpawnA = "ArenaSpawnA",
		ArenaSpawnB = "ArenaSpawnB",
		KillPlane = "KillPlane",
		Hazard = "Hazard",
		-- World lobby — Combat lit / écrit attrs, ne pose pas la géométrie
		-- Tag pads = BC_DuelSlotPad ; Attribute BC_DuelSlot = 1|2 (croiseur)
		DuelSlotPad = "BC_DuelSlotPad",
		LobbySpawn = "BC_LobbySpawn",
		-- 8 arènes L/R : tag BC_MatchArena + Attribute BC_ArenaIndex = 1..8
		MatchArena = "BC_MatchArena",
	},
}

return CombatConfig
