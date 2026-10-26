--!strict
--[[
	Double saut server-authoritative (Space en l’air).
	Client envoie MobilityIntent kind="DoubleJump" ; serveur valide :
	  - en combat (Fighting)
	  - pas au sol (FloorMaterial Air / raycast)
	  - ≤1 air-jump par cycle (reset à l’atterrissage)
	  - cooldown + seq anti-replay
	  - pas Dead / Stagger / RiposteLock
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))

local DoubleJumpService = {}

local remotes: Remotes.CombatRemotes? = nil
local groundedHooks: { [Player]: { RBXScriptConnection } } = {}

local function getRemotes(): Remotes.CombatRemotes
	if not remotes then
		remotes = Remotes.get()
	end
	return remotes :: Remotes.CombatRemotes
end

local function isAirborne(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		return true
	end
	-- FloorMaterial Air = pas au sol
	if humanoid.FloorMaterial == Enum.Material.Air then
		return true
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -3.4, 0), params)
	return hit == nil
end

function DoubleJumpService.bindCharacter(fighter: FighterState.Fighter, character: Model)
	local player = fighter.player
	local prev = groundedHooks[player]
	if prev then
		for _, c in prev do
			c:Disconnect()
		end
	end
	groundedHooks[player] = {}

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	fighter.airJumpsUsed = 0
	table.insert(
		groundedHooks[player],
		humanoid.StateChanged:Connect(function(_old, new)
			if
				new == Enum.HumanoidStateType.Landed
				or new == Enum.HumanoidStateType.Running
				or new == Enum.HumanoidStateType.RunningNoPhysics
				or new == Enum.HumanoidStateType.Climbing
				or new == Enum.HumanoidStateType.Swimming
			then
				fighter.airJumpsUsed = 0
			end
		end)
	)
end

function DoubleJumpService.unbind(player: Player)
	local prev = groundedHooks[player]
	if prev then
		for _, c in prev do
			c:Disconnect()
		end
	end
	groundedHooks[player] = nil
end

function DoubleJumpService.tryDoubleJump(fighter: FighterState.Fighter, seq: number): boolean
	if seq <= fighter.lastMobilitySeq then
		return false
	end
	local now = os.clock()
	local cfg = CombatConfig.DoubleJump
	if fighter.actionId == CombatTypes.ActionId.Dead then
		return false
	end
	if now < fighter.staggerUntil or now < fighter.riposteLockUntil then
		return false
	end
	if now < fighter.doubleJumpCooldownUntil then
		return false
	end
	if fighter.airJumpsUsed >= (cfg.MaxAirJumps or 1) then
		return false
	end
	-- Autorisé pendant Idle / Guard / Dodge recovery légère / Dash / FocusDash mid-air
	local aid = fighter.actionId
	if
		aid ~= CombatTypes.ActionId.Idle
		and aid ~= CombatTypes.ActionId.Guard
		and aid ~= CombatTypes.ActionId.Dodge
		and aid ~= CombatTypes.ActionId.Dash
		and aid ~= CombatTypes.ActionId.FocusDash
	then
		return false
	end

	local character = fighter.character
	if not character or not character.Parent then
		return false
	end
	if not isAirborne(character) then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or hrp.Anchored then
		return false
	end

	fighter.lastMobilitySeq = seq
	fighter.airJumpsUsed += 1
	fighter.doubleJumpCooldownUntil = now + (cfg.Cooldown or 0.35)

	local vel = hrp.AssemblyLinearVelocity
	local boost = cfg.UpVelocity or 52
	-- Remplace la composante Y (anti-stack vertical exploit)
	hrp.AssemblyLinearVelocity = Vector3.new(vel.X, boost, vel.Z)

	getRemotes().FxEvent:FireAllClients({
		kind = "DoubleJump",
		payload = { userId = fighter.player.UserId },
	})
	return true
end

return DoubleJumpService
