--!strict
--[[
	Store d'état combattant — HP / stamina / action canoniques serveur.
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
	lastAttackSeq: number,
	lastGuardSeq: number,
	lastStaminaConsumeClock: number,
	hitThisSwing: { [number]: boolean }, -- userId déjà touché ce swing
	character: Model?,
	bladePart: BasePart?,
	hurtboxes: { BasePart },
	walkSpeedBase: number,
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
		lastAttackSeq = 0,
		lastGuardSeq = 0,
		lastStaminaConsumeClock = 0,
		hitThisSwing = {},
		character = nil,
		bladePart = nil,
		hurtboxes = {},
		walkSpeedBase = 16,
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
	fighter.hitThisSwing = {}
end

function FighterState.snapshot(fighter: Fighter)
	local now = os.clock()
	return {
		userId = fighter.player.UserId,
		hp = fighter.hp,
		stamina = fighter.stamina,
		actionId = fighter.actionId,
		attackKind = fighter.attackKind,
		flags = {
			guarding = fighter.guardHolding and fighter.actionId ~= CombatTypes.ActionId.Dead,
			exhausted = fighter.exhausted,
			riposteLock = now < fighter.riposteLockUntil,
			stagger = now < fighter.staggerUntil,
			riposteBuff = now < fighter.riposteBuffUntil,
		},
	}
end

return FighterState
