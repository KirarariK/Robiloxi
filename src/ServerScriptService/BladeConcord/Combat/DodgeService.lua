--!strict
--[[
	Esquive / sidestep — i-frames 160 ms, CD 0,55 s, stamina 22.
	Exhaustion → stumble (pas d'i-frames).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))

local DodgeService = {}

local function applyImpulse(fighter: FighterState.Fighter, direction: Vector3, distance: number)
	local character = fighter.character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or hrp.Anchored then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		local look = hrp.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
	end
	if flat.Magnitude < 1e-3 then
		return
	end
	-- Impulse approx : velocity burst
	hrp.AssemblyLinearVelocity = flat.Unit * (distance * 6) + Vector3.new(0, 8, 0)
end

function DodgeService.tryDodge(fighter: FighterState.Fighter, direction: Vector3?, seq: number): boolean
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
	if fighter.actionId == CombatTypes.ActionId.Startup
		or fighter.actionId == CombatTypes.ActionId.Active
		or fighter.actionId == CombatTypes.ActionId.Recovery
		or fighter.actionId == CombatTypes.ActionId.Dodge
		or fighter.actionId == CombatTypes.ActionId.Dash
		or fighter.actionId == CombatTypes.ActionId.FocusDash
	then
		return false
	end

	local cfg = CombatConfig.Dodge
	local cost = cfg.StaminaCost
	-- Zephyr dodge cost mult applied via FormService hook if present
	local formMods = fighter.player:GetAttribute("BC_DodgeCostMult")
	if typeof(formMods) == "number" then
		cost = cost * formMods
	end

	local onCooldown = now < fighter.dodgeCooldownUntil
	-- Rafale (Zephyr Légendaire) : 1 free double sidestep / round if available
	if onCooldown then
		if fighter.zephyrDoubleDodgeAvailable and fighter.formId == "Zephyr" and fighter.formRarity == "Legendary" then
			fighter.zephyrDoubleDodgeAvailable = false
		else
			return false
		end
	end

	if not StaminaService.tryConsume(fighter, cost) then
		return false
	end

	fighter.lastMobilitySeq = seq
	fighter.guardHolding = false
	fighter.actionId = CombatTypes.ActionId.Dodge
	fighter.phaseTimer = cfg.IFrames + 0.05
	fighter.dodgeCooldownUntil = now + cfg.Cooldown
	fighter.lastDodgeClock = now

	local iFrames = cfg.IFrames
	local rareBonus = fighter.player:GetAttribute("BC_DodgeIFramesBonus")
	if typeof(rareBonus) == "number" then
		iFrames += rareBonus
	end

	if fighter.exhausted and cfg.StumbleNoIFrames then
		-- Stumble : pas d'i-frames
		fighter.iFramesUntil = 0
	else
		fighter.iFramesUntil = now + iFrames
	end

	applyImpulse(fighter, direction or Vector3.new(1, 0, 0), cfg.Distance)
	return true
end

function DodgeService.step(fighter: FighterState.Fighter, dt: number)
	if fighter.actionId ~= CombatTypes.ActionId.Dodge then
		return
	end
	fighter.phaseTimer -= dt
	if fighter.phaseTimer <= 0 then
		fighter.actionId = CombatTypes.ActionId.Idle
		fighter.phaseTimer = 0
	end
end

return DodgeService
