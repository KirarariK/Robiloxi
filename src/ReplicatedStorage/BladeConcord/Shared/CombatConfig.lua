--!strict
--[[
	Constantes combat MVP — alignées GDD §2.2 / §2.5 et TDD §3.
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

	AntiCheat = {
		AttackRateLimitPerSecond = 8,
		GuardIntentThrottleHz = 20,
		MaxHitDistanceMargin = 2, -- studs au-delà lame + hurtbox
		RecoveryFailsafe = 2.5, -- timeout softlock Idle
	},

	Arena = {
		Name = "ObsidianPit",
		PlatformSize = Vector3.new(64, 2, 64),
		WallHeight = 12,
		LavaDps = 8, -- soft placeholder
	},

	Tags = {
		Hurtbox = "Hurtbox",
		SaberBlade = "SaberBlade",
		ArenaSpawnA = "ArenaSpawnA",
		ArenaSpawnB = "ArenaSpawnB",
		KillPlane = "KillPlane",
	},
}

return CombatConfig
