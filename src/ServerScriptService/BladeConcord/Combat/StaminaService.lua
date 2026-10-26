--!strict
--[[
	Stamina : tryConsume, setGuarding (drain), step regen, exhaustion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))

local StaminaService = {}

function StaminaService.tryConsume(fighter: FighterState.Fighter, amount: number): boolean
	if amount <= 0 then
		return true
	end
	if fighter.stamina < amount then
		return false
	end
	fighter.stamina -= amount
	fighter.lastStaminaConsumeClock = os.clock()
	StaminaService._refreshExhaustion(fighter)
	return true
end

function StaminaService.add(fighter: FighterState.Fighter, amount: number)
	fighter.stamina = math.clamp(fighter.stamina + amount, 0, CombatConfig.Stamina.Max)
	StaminaService._refreshExhaustion(fighter)
end

function StaminaService.setGuarding(fighter: FighterState.Fighter, holding: boolean)
	fighter.guardHolding = holding
end

function StaminaService._refreshExhaustion(fighter: FighterState.Fighter)
	fighter.exhausted = fighter.stamina < CombatConfig.Stamina.ExhaustionThreshold
	local character = fighter.character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local penalty = if fighter.exhausted then (1 - CombatConfig.Stamina.ExhaustionWalkSpeedPenalty) else 1
			humanoid.WalkSpeed = fighter.walkSpeedBase * penalty
		end
	end
end

function StaminaService.step(fighter: FighterState.Fighter, dt: number)
	local cfg = CombatConfig.Stamina
	local now = os.clock()

	-- Drain guard hold
	if fighter.guardHolding and fighter.actionId ~= "Dead" and fighter.actionId ~= "Stagger" then
		local drain = CombatConfig.Guard.DrainPerSecond * dt
		fighter.stamina = math.max(0, fighter.stamina - drain)
		fighter.lastStaminaConsumeClock = now
		StaminaService._refreshExhaustion(fighter)
		return
	end

	-- Regen après délai idle
	if now - fighter.lastStaminaConsumeClock >= cfg.RegenDelay then
		fighter.stamina = math.min(cfg.Max, fighter.stamina + cfg.RegenPerSecond * dt)
		StaminaService._refreshExhaustion(fighter)
	end
end

return StaminaService
