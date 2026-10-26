--!strict
--[[
	Parade hold, angle, perfect window, chip, guard break.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))

local GuardService = {}

local function getLookFlat(character: Model?): Vector3?
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	return flat.Unit
end

function GuardService.setHolding(fighter: FighterState.Fighter, holding: boolean, seq: number?)
	if fighter.actionId == CombatTypes.ActionId.Dead then
		return
	end
	if seq and seq <= fighter.lastGuardSeq then
		return
	end
	if seq then
		fighter.lastGuardSeq = seq
	end

	local wasHolding = fighter.guardHolding
	-- Ignore hold pendant recovery d'attaque exclusive / stagger / riposte lock
	local now = os.clock()
	local blocked = fighter.actionId == CombatTypes.ActionId.Startup
		or fighter.actionId == CombatTypes.ActionId.Active
		or fighter.actionId == CombatTypes.ActionId.Recovery
		or now < fighter.staggerUntil
		or now < fighter.riposteLockUntil

	if holding and blocked then
		return
	end

	if holding and not wasHolding then
		fighter.guardIntentEdgeClock = os.clock()
	elseif not holding then
		fighter.guardIntentEdgeClock = nil
	end

	StaminaService.setGuarding(fighter, holding)
	if holding and fighter.actionId == CombatTypes.ActionId.Idle then
		fighter.actionId = CombatTypes.ActionId.Guard
	elseif not holding and fighter.actionId == CombatTypes.ActionId.Guard then
		fighter.actionId = CombatTypes.ActionId.Idle
	end
end

function GuardService.isFacingAttack(defender: FighterState.Fighter, attacker: FighterState.Fighter): boolean
	local defLook = getLookFlat(defender.character)
	local atkHrp = attacker.character and attacker.character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local defHrp = defender.character and defender.character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not defLook or not atkHrp or not defHrp then
		return false
	end
	local toAttacker = Vector3.new(atkHrp.Position.X - defHrp.Position.X, 0, atkHrp.Position.Z - defHrp.Position.Z)
	if toAttacker.Magnitude < 1e-3 then
		return true
	end
	local angle = math.deg(math.acos(math.clamp(defLook:Dot(toAttacker.Unit), -1, 1)))
	return angle <= CombatConfig.Guard.MaxAngleDegrees
end

export type IncomingResolution = {
	guardResult: CombatTypes.GuardResult,
	damageMultiplier: number, -- 1 = full, (1-absorb) = chip, 0 = perfect
	applyStaggerToDefender: boolean,
	applyRiposteLockToAttacker: boolean,
	refundStamina: number,
}

function GuardService.resolveIncomingHit(
	defender: FighterState.Fighter,
	attacker: FighterState.Fighter,
	_contactClock: number
): IncomingResolution
	local cfg = CombatConfig.Guard
	local holding = defender.guardHolding
		and defender.actionId ~= CombatTypes.ActionId.Dead
		and os.clock() >= defender.staggerUntil

	if not holding or not GuardService.isFacingAttack(defender, attacker) then
		return {
			guardResult = CombatTypes.GuardResult.None,
			damageMultiplier = 1,
			applyStaggerToDefender = false,
			applyRiposteLockToAttacker = false,
			refundStamina = 0,
		}
	end

	-- Perfect : |t_contact - t_intent_edge| dans ±PerfectWindow
	local edge = defender.guardIntentEdgeClock
	local isPerfect = false
	if edge then
		local delta = math.abs(_contactClock - edge)
		-- Aussi : hold récemment maintenu — fenêtre autour du contact vs edge
		-- TDD : |t_contact - t_intent_edge| dans ±90 ms
		isPerfect = delta <= cfg.PerfectWindow
	end

	if isPerfect then
		StaminaService.add(defender, cfg.PerfectStaminaRefund)
		return {
			guardResult = CombatTypes.GuardResult.Perfect,
			damageMultiplier = 0,
			applyStaggerToDefender = false,
			applyRiposteLockToAttacker = true,
			refundStamina = cfg.PerfectStaminaRefund,
		}
	end

	-- Guard break si stamina < seuil à l'impact
	if defender.stamina < cfg.GuardBreakStaminaThreshold then
		return {
			guardResult = CombatTypes.GuardResult.Break,
			damageMultiplier = 1,
			applyStaggerToDefender = true,
			applyRiposteLockToAttacker = false,
			refundStamina = 0,
		}
	end

	-- Impact stamina cost
	StaminaService.tryConsume(defender, cfg.ImpactStaminaCost)

	return {
		guardResult = CombatTypes.GuardResult.Normal,
		damageMultiplier = 1 - cfg.ChipAbsorbFraction,
		applyStaggerToDefender = false,
		applyRiposteLockToAttacker = false,
		refundStamina = 0,
	}
end

return GuardService
