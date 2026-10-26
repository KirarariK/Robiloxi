--!strict
--[[
	Store d'état combattant — HP / stamina / action / mobilité / Focus canoniques serveur.
]]

local CombatConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("BladeConcord"):WaitForChild("Shared"):WaitForChild("CombatConfig"))
local CombatTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("BladeConcord"):WaitForChild("Shared"):WaitForChild("CombatTypes"))

export type Fighter = {
	player: Player,
	hp: number,
	stamina: number,
	actionId: CombatTypes.ActionId,
	attackKind: CombatTypes.AttackKind?,
	phaseTimer: number,
	guardHolding: boolean,
	guardIntentEdgeClock: number?,
	exhausted: boolean,
	riposteLockUntil: number,
	staggerUntil: number,
	riposteBuffUntil: number,
	iFramesUntil: number,
	dodgeCooldownUntil: number,
	dashCooldownUntil: number,
	doubleJumpCooldownUntil: number,
	airJumpsUsed: number,
	focusPushCooldownUntil: number,
	focusDashCooldownUntil: number,
	lastDodgeClock: number,
	lastAttackSeq: number,
	lastGuardSeq: number,
	lastMobilitySeq: number,
	lastFocusSeq: number,
	lastStaminaConsumeClock: number,
	hitThisSwing: { [number]: boolean },
	character: Model?,
	bladePart: BasePart?,
	hurtboxes: { BasePart },
	walkSpeedBase: number,
	-- Form passives (resolved per match mode)
	formId: string?,
	formRarity: string?,
	formUniqueUsed: boolean, -- Flux / Mur / Rafale once flags
	aegisWallAvailable: boolean,
	zephyrDoubleDodgeAvailable: boolean,
	astraFluxArmed: boolean,
}

local FighterState = {}
local byPlayer: { [Player]: Fighter } = {}

function FighterState.create(player: Player): Fighter
	local fighter: Fighter = {
		player = player,
		hp = CombatConfig.MaxHp,
		stamina = CombatConfig.Stamina.Max,
		actionId = CombatTypes.ActionId.Idle,
		attackKind = nil,
		phaseTimer = 0,
		guardHolding = false,
		guardIntentEdgeClock = nil,
		exhausted = false,
		riposteLockUntil = 0,
		staggerUntil = 0,
		riposteBuffUntil = 0,
		iFramesUntil = 0,
		dodgeCooldownUntil = 0,
		dashCooldownUntil = 0,
		doubleJumpCooldownUntil = 0,
		airJumpsUsed = 0,
		focusPushCooldownUntil = 0,
		focusDashCooldownUntil = 0,
		lastDodgeClock = 0,
		lastAttackSeq = 0,
		lastGuardSeq = 0,
		lastMobilitySeq = 0,
		lastFocusSeq = 0,
		lastStaminaConsumeClock = 0,
		hitThisSwing = {},
		character = nil,
		bladePart = nil,
		hurtboxes = {},
		walkSpeedBase = 16,
		formId = "Astra",
		formRarity = "Common",
		formUniqueUsed = false,
		aegisWallAvailable = true,
		zephyrDoubleDodgeAvailable = true,
		astraFluxArmed = false,
	}
	byPlayer[player] = fighter
	return fighter
end

function FighterState.get(player: Player): Fighter?
	return byPlayer[player]
end

function FighterState.getAll(): { Fighter }
	local list = {}
	for _, f in byPlayer do
		table.insert(list, f)
	end
	return list
end

function FighterState.getOpponent(fighter: Fighter): Fighter?
	for _, f in byPlayer do
		if f.player ~= fighter.player then
			return f
		end
	end
	return nil
end

function FighterState.remove(player: Player)
	byPlayer[player] = nil
end

function FighterState.resetRound(fighter: Fighter)
	fighter.hp = CombatConfig.MaxHp
	fighter.stamina = CombatConfig.Stamina.Max
	fighter.actionId = CombatTypes.ActionId.Idle
	fighter.attackKind = nil
	fighter.phaseTimer = 0
	fighter.guardHolding = false
	fighter.guardIntentEdgeClock = nil
	fighter.exhausted = false
	fighter.riposteLockUntil = 0
	fighter.staggerUntil = 0
	fighter.riposteBuffUntil = 0
	fighter.iFramesUntil = 0
	fighter.airJumpsUsed = 0
	fighter.hitThisSwing = {}
	fighter.formUniqueUsed = false
	fighter.astraFluxArmed = false
	-- Wall / Rafale : 1×/match — reset only on match start via resetMatch
end

function FighterState.resetMatch(fighter: Fighter)
	FighterState.resetRound(fighter)
	fighter.aegisWallAvailable = true
	fighter.zephyrDoubleDodgeAvailable = true
	fighter.focusPushCooldownUntil = 0
	fighter.focusDashCooldownUntil = 0
	fighter.dodgeCooldownUntil = 0
	fighter.dashCooldownUntil = 0
	fighter.doubleJumpCooldownUntil = 0
	fighter.airJumpsUsed = 0
end

function FighterState.hasIFrames(fighter: Fighter): boolean
	return os.clock() < fighter.iFramesUntil
end

function FighterState.snapshot(fighter: Fighter)
	local now = os.clock()
	return {
		userId = fighter.player.UserId,
		hp = fighter.hp,
		stamina = fighter.stamina,
		actionId = fighter.actionId,
		attackKind = fighter.attackKind,
		formId = fighter.formId,
		formRarity = fighter.formRarity,
		cooldowns = {
			dodge = math.max(0, fighter.dodgeCooldownUntil - now),
			dash = math.max(0, fighter.dashCooldownUntil - now),
			focusPush = math.max(0, fighter.focusPushCooldownUntil - now),
			focusDash = math.max(0, fighter.focusDashCooldownUntil - now),
		},
		flags = {
			guarding = fighter.guardHolding and fighter.actionId ~= CombatTypes.ActionId.Dead,
			exhausted = fighter.exhausted,
			riposteLock = now < fighter.riposteLockUntil,
			stagger = now < fighter.staggerUntil,
			riposteBuff = now < fighter.riposteBuffUntil,
			iFrames = now < fighter.iFramesUntil,
		},
	}
end

return FighterState
