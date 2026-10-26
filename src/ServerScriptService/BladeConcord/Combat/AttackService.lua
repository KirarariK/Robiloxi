--!strict
--[[
	State machine Idle → Startup → Active → Recovery ; reject inputs illégaux.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))

local AttackService = {}

local function moveConfig(kind: CombatTypes.AttackKind)
	if kind == CombatTypes.AttackKind.Heavy then
		return CombatConfig.Heavy
	end
	return CombatConfig.Light
end

function AttackService.canStart(fighter: FighterState.Fighter, kind: CombatTypes.AttackKind): boolean
	local now = os.clock()
	if fighter.actionId == CombatTypes.ActionId.Dead then
		return false
	end
	if now < fighter.staggerUntil or now < fighter.riposteLockUntil then
		return false
	end
	-- Max 1 AttackIntent accepté par transition Idle→Startup (ou Guard→Startup)
	if fighter.actionId ~= CombatTypes.ActionId.Idle and fighter.actionId ~= CombatTypes.ActionId.Guard then
		return false
	end
	if kind == CombatTypes.AttackKind.Heavy and fighter.exhausted then
		return false
	end
	local cfg = moveConfig(kind)
	return fighter.stamina >= cfg.StaminaCost
end

function AttackService.tryStart(fighter: FighterState.Fighter, kind: CombatTypes.AttackKind, seq: number): boolean
	if typeof(kind) ~= "string" or (kind ~= "Light" and kind ~= "Heavy") then
		return false
	end
	if seq <= fighter.lastAttackSeq then
		return false
	end
	if not AttackService.canStart(fighter, kind :: CombatTypes.AttackKind) then
		return false
	end

	local cfg = moveConfig(kind :: CombatTypes.AttackKind)
	if not StaminaService.tryConsume(fighter, cfg.StaminaCost) then
		return false
	end

	fighter.lastAttackSeq = seq
	fighter.guardHolding = false
	fighter.attackKind = kind :: CombatTypes.AttackKind
	fighter.actionId = CombatTypes.ActionId.Startup
	fighter.phaseTimer = cfg.Startup
	fighter.hitThisSwing = {}
	return true
end

function AttackService.step(fighter: FighterState.Fighter, dt: number)
	local now = os.clock()

	-- Failsafe softlock
	if fighter.actionId ~= CombatTypes.ActionId.Idle
		and fighter.actionId ~= CombatTypes.ActionId.Guard
		and fighter.actionId ~= CombatTypes.ActionId.Dead
	then
		-- handled via phaseTimer
	end

	if now < fighter.staggerUntil then
		fighter.actionId = CombatTypes.ActionId.Stagger
		return
	elseif fighter.actionId == CombatTypes.ActionId.Stagger then
		fighter.actionId = CombatTypes.ActionId.Idle
	end

	if now < fighter.riposteLockUntil and fighter.actionId ~= CombatTypes.ActionId.Startup
		and fighter.actionId ~= CombatTypes.ActionId.Active
		and fighter.actionId ~= CombatTypes.ActionId.Recovery
	then
		fighter.actionId = CombatTypes.ActionId.RiposteLock
		return
	elseif fighter.actionId == CombatTypes.ActionId.RiposteLock and now >= fighter.riposteLockUntil then
		fighter.actionId = CombatTypes.ActionId.Idle
	end

	if fighter.actionId == CombatTypes.ActionId.Startup
		or fighter.actionId == CombatTypes.ActionId.Active
		or fighter.actionId == CombatTypes.ActionId.Recovery
	then
		fighter.phaseTimer -= dt
		if fighter.phaseTimer > 0 then
			return
		end

		local kind = fighter.attackKind or CombatTypes.AttackKind.Light
		local cfg = moveConfig(kind)

		if fighter.actionId == CombatTypes.ActionId.Startup then
			fighter.actionId = CombatTypes.ActionId.Active
			fighter.phaseTimer = cfg.Active
		elseif fighter.actionId == CombatTypes.ActionId.Active then
			fighter.actionId = CombatTypes.ActionId.Recovery
			fighter.phaseTimer = cfg.Recovery
			fighter.hitThisSwing = {}
		elseif fighter.actionId == CombatTypes.ActionId.Recovery then
			fighter.actionId = CombatTypes.ActionId.Idle
			fighter.attackKind = nil
			fighter.phaseTimer = 0
		end
	end
end

return AttackService
