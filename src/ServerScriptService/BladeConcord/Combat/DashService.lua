--!strict
--[[
	Dash combat — courte distance, stamina 30, PAS d'i-frames (GDD §2.2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))

local DashService = {}

local function applyDash(fighter: FighterState.Fighter, direction: Vector3?, distance: number)
	local character = fighter.character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or hrp.Anchored then
		return
	end
	local flat: Vector3
	if direction and direction.Magnitude > 1e-3 then
		flat = Vector3.new(direction.X, 0, direction.Z)
	else
		local look = hrp.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
	end
	if flat.Magnitude < 1e-3 then
		return
	end
	hrp.AssemblyLinearVelocity = flat.Unit * (distance * 7) + Vector3.new(0, 4, 0)
end

function DashService.tryDash(fighter: FighterState.Fighter, direction: Vector3?, seq: number): boolean
	if seq <= fighter.lastMobilitySeq then
		return false
	end
	local now = os.clock()
	if fighter.actionId == CombatTypes.ActionId.Dead then
		return false
	end
	if now < fighter.staggerUntil or now < fighter.riposteLockUntil then
		return false
	end
	if now < fighter.dashCooldownUntil then
		return false
	end
	if fighter.actionId ~= CombatTypes.ActionId.Idle and fighter.actionId ~= CombatTypes.ActionId.Guard then
		return false
	end

	local cfg = CombatConfig.CombatDash
	if not StaminaService.tryConsume(fighter, cfg.StaminaCost) then
		return false
	end

	fighter.lastMobilitySeq = seq
	fighter.guardHolding = false
	fighter.actionId = CombatTypes.ActionId.Dash
	fighter.phaseTimer = 0.22
	fighter.dashCooldownUntil = now + cfg.Cooldown
	-- Explicitement pas d'i-frames
	fighter.iFramesUntil = math.min(fighter.iFramesUntil, now)

	applyDash(fighter, direction, cfg.Distance)
	return true
end

function DashService.step(fighter: FighterState.Fighter, dt: number)
	if fighter.actionId ~= CombatTypes.ActionId.Dash then
		return
	end
	fighter.phaseTimer -= dt
	if fighter.phaseTimer <= 0 then
		fighter.actionId = CombatTypes.ActionId.Idle
		fighter.phaseTimer = 0
	end
end

return DashService
