--!strict
--[[
	Poussée Focus + Dash Focus — GDD §2.7.
	Push : knockback cône, 0 dmg, renvoyé si parade.
	Dash Focus : 12 studs + i-frames 100 ms ; anti-stack esquive 0,4 s.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))
local GuardService = require(script.Parent:WaitForChild("GuardService"))

local FocusService = {}

local remotes: Remotes.CombatRemotes? = nil

local function getRemotes(): Remotes.CombatRemotes
	if not remotes then
		remotes = Remotes.get()
	end
	return remotes :: Remotes.CombatRemotes
end

local function fireFx(kind: string, payload: { [string]: any })
	getRemotes().FxEvent:FireAllClients({
		kind = kind,
		payload = payload,
	})
end

function FocusService.tryPush(fighter: FighterState.Fighter, seq: number): boolean
	if seq <= fighter.lastFocusSeq then
		return false
	end
	local now = os.clock()
	if fighter.actionId == CombatTypes.ActionId.Dead then
		return false
	end
	if now < fighter.staggerUntil or now < fighter.riposteLockUntil then
		return false
	end
	if now < fighter.focusPushCooldownUntil then
		return false
	end
	if fighter.actionId ~= CombatTypes.ActionId.Idle and fighter.actionId ~= CombatTypes.ActionId.Guard then
		return false
	end

	local cfg = CombatConfig.Focus.Push
	if not StaminaService.tryConsume(fighter, cfg.StaminaCost) then
		return false
	end

	fighter.lastFocusSeq = seq
	fighter.focusPushCooldownUntil = now + cfg.Cooldown
	fighter.guardHolding = false
	fighter.actionId = CombatTypes.ActionId.FocusPush
	fighter.phaseTimer = 0.25

	local opponent = FighterState.getOpponent(fighter)
	if opponent and opponent.character and fighter.character then
		local aHrp = fighter.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local dHrp = opponent.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if aHrp and dHrp then
			local delta = dHrp.Position - aHrp.Position
			local flat = Vector3.new(delta.X, 0, delta.Z)
			local inRange = flat.Magnitude <= cfg.ConeStuds
			local look = Vector3.new(aHrp.CFrame.LookVector.X, 0, aHrp.CFrame.LookVector.Z)
			local facing = look.Magnitude > 1e-3 and flat.Magnitude > 1e-3 and look.Unit:Dot(flat.Unit) > 0.35

			if inRange and facing then
				-- Parade renvoie → self-stagger
				if opponent.guardHolding and GuardService.isFacingAttack(opponent, fighter) then
					fighter.staggerUntil = now + cfg.SelfStaggerOnParry
					fighter.actionId = CombatTypes.ActionId.Stagger
					fireFx("FocusPushParried", {
						attackerUserId = fighter.player.UserId,
						defenderUserId = opponent.player.UserId,
					})
				elseif not FighterState.hasIFrames(opponent) then
					-- Interrompt startup légère
					if opponent.actionId == CombatTypes.ActionId.Startup
						and opponent.attackKind == CombatTypes.AttackKind.Light
					then
						opponent.actionId = CombatTypes.ActionId.Idle
						opponent.attackKind = nil
						opponent.phaseTimer = 0
					end
					if not dHrp.Anchored then
						dHrp.AssemblyLinearVelocity = flat.Unit * cfg.KnockbackForce + Vector3.new(0, 12, 0)
					end
					fireFx("FocusPush", {
						attackerUserId = fighter.player.UserId,
						defenderUserId = opponent.player.UserId,
					})
				end
			end
		end
	end

	return true
end

function FocusService.tryDashFocus(fighter: FighterState.Fighter, direction: Vector3?, seq: number): boolean
	if seq <= fighter.lastFocusSeq then
		return false
	end
	local now = os.clock()
	if fighter.actionId == CombatTypes.ActionId.Dead then
		return false
	end
	if now < fighter.staggerUntil or now < fighter.riposteLockUntil then
		return false
	end

	local cfg = CombatConfig.Focus.DashFocus
	local cd = cfg.Cooldown
	local cdBonus = fighter.player:GetAttribute("BC_FocusDashCdBonus")
	if typeof(cdBonus) == "number" then
		cd += cdBonus
	end
	if now < fighter.focusDashCooldownUntil then
		return false
	end
	-- Anti-stack esquive 0,4 s
	if now - fighter.lastDodgeClock < cfg.StackBlockWithDodge then
		return false
	end
	if fighter.actionId ~= CombatTypes.ActionId.Idle and fighter.actionId ~= CombatTypes.ActionId.Guard then
		return false
	end
	if not StaminaService.tryConsume(fighter, cfg.StaminaCost) then
		return false
	end

	fighter.lastFocusSeq = seq
	fighter.focusDashCooldownUntil = now + cd
	fighter.guardHolding = false
	fighter.actionId = CombatTypes.ActionId.FocusDash
	fighter.phaseTimer = cfg.IFrames + 0.08
	fighter.iFramesUntil = now + cfg.IFrames

	local character = fighter.character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and not hrp.Anchored then
		local flat: Vector3
		if direction and direction.Magnitude > 1e-3 then
			flat = Vector3.new(direction.X, 0, direction.Z)
		else
			local look = hrp.CFrame.LookVector
			flat = Vector3.new(look.X, 0, look.Z)
		end
		if flat.Magnitude > 1e-3 then
			hrp.AssemblyLinearVelocity = flat.Unit * (cfg.Distance * 7) + Vector3.new(0, 6, 0)
		end
	end

	fireFx("FocusDash", { userId = fighter.player.UserId })
	return true
end

function FocusService.step(fighter: FighterState.Fighter, dt: number)
	if fighter.actionId ~= CombatTypes.ActionId.FocusPush and fighter.actionId ~= CombatTypes.ActionId.FocusDash then
		return
	end
	fighter.phaseTimer -= dt
	if fighter.phaseTimer <= 0 then
		fighter.actionId = CombatTypes.ActionId.Idle
		fighter.phaseTimer = 0
	end
end

return FocusService
