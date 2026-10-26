--!strict
--[[
	Orchestrateur duel P1–P2 : register, mobilité, Focus, tick, Match BO3.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Visual = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Visual")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local RemotesMod = require(Shared:WaitForChild("Remotes"))
local SaberBuilder = require(Visual:WaitForChild("SaberBuilder"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))
local AttackService = require(script.Parent:WaitForChild("AttackService"))
local GuardService = require(script.Parent:WaitForChild("GuardService"))
local HitService = require(script.Parent:WaitForChild("HitService"))
local ArenaService = require(script.Parent:WaitForChild("ArenaService"))
local DodgeService = require(script.Parent:WaitForChild("DodgeService"))
local DashService = require(script.Parent:WaitForChild("DashService"))
local FocusService = require(script.Parent:WaitForChild("FocusService"))
local BotStub = require(script.Parent:WaitForChild("BotStub"))
local MatchService = require(script.Parent.Parent.Match:WaitForChild("MatchService"))
local PlayerDataService = require(script.Parent.Parent.Data:WaitForChild("PlayerDataService"))

local CombatService = {}

local remotes: RemotesMod.CombatRemotes
local attackRate: { [Player]: { count: number, windowStart: number } } = {}
local mobilityRate: { [Player]: { count: number, windowStart: number } } = {}
local roundEndReported = false

local function ensureBlade(character: Model, player: Player?): BasePart
	local profile = if player then PlayerDataService.get(player) else nil
	for _, inst in CollectionService:GetTagged(CombatConfig.Tags.SaberBlade) do
		if inst:IsDescendantOf(character) and inst:IsA("BasePart") then
			if profile then
				SaberBuilder.applyCosmeticsFromModel(character, profile.equippedCosmetics)
			end
			return inst
		end
	end
	local build = SaberBuilder.attach(character)
	if profile then
		SaberBuilder.applyCosmetics(build, profile.equippedCosmetics)
	end
	return build.blade
end

local function ensureHurtboxes(character: Model): { BasePart }
	local boxes = {}
	local torso = character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	for _, part in { torso, head } do
		if part and part:IsA("BasePart") then
			if not CollectionService:HasTag(part, CombatConfig.Tags.Hurtbox) then
				CollectionService:AddTag(part, CombatConfig.Tags.Hurtbox)
			end
			table.insert(boxes, part)
		end
	end
	return boxes
end

function CombatService.bindCharacter(fighter: FighterState.Fighter, character: Model)
	fighter.character = character
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	fighter.walkSpeedBase = humanoid.WalkSpeed
	humanoid.MaxHealth = CombatConfig.MaxHp
	humanoid.Health = fighter.hp
	humanoid.BreakJointsOnDeath = false

	task.defer(function()
		if character.Parent then
			fighter.bladePart = ensureBlade(character, fighter.player)
			fighter.hurtboxes = ensureHurtboxes(character)
		end
	end)
end

function CombatService.register(player: Player): FighterState.Fighter
	local fighter = FighterState.get(player) or FighterState.create(player)
	if player.Character then
		CombatService.bindCharacter(fighter, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		CombatService.bindCharacter(fighter, character)
		local a, b = ArenaService.getSpawnCFrames()
		local index = 1
		for i, f in FighterState.getAll() do
			if f.player == player then
				index = i
				break
			end
		end
		local cf = if index % 2 == 1 then a else b
		task.defer(function()
			local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
			if hrp then
				hrp.CFrame = cf
			end
		end)
	end)
	return fighter
end

function CombatService.broadcastState()
	local snapshots = {}
	for _, f in FighterState.getAll() do
		table.insert(snapshots, FighterState.snapshot(f))
	end
	remotes.CombatState:FireAllClients({ fighters = snapshots, t = os.clock() })
end

local function rateOk(bucketMap: { [Player]: { count: number, windowStart: number } }, player: Player, limit: number): boolean
	local now = os.clock()
	local bucket = bucketMap[player]
	if not bucket or now - bucket.windowStart >= 1 then
		bucketMap[player] = { count = 1, windowStart = now }
		return true
	end
	bucket.count += 1
	return bucket.count <= limit
end

function CombatService.onAttackIntent(player: Player, payload: any)
	if not MatchService.isFighting() then
		return
	end
	local fighter = FighterState.get(player)
	if not fighter then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	local seq = payload.seq
	if typeof(seq) ~= "number" then
		return
	end
	if not rateOk(attackRate, player, CombatConfig.AntiCheat.AttackRateLimitPerSecond) then
		return
	end
	AttackService.tryStart(fighter, kind, seq)
	CombatService.broadcastState()
end

function CombatService.onGuardIntent(player: Player, payload: any)
	if not MatchService.isFighting() then
		return
	end
	local fighter = FighterState.get(player)
	if not fighter then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	local holding = payload.holding == true
	local seq = payload.seq
	-- Feinte : pendant Startup Light, GuardIntent = feinte
	if holding and fighter.actionId == CombatTypes.ActionId.Startup and fighter.attackKind == CombatTypes.AttackKind.Light then
		if typeof(seq) == "number" then
			AttackService.tryFeint(fighter, seq)
		end
		CombatService.broadcastState()
		return
	end
	if typeof(seq) == "number" then
		GuardService.setHolding(fighter, holding, seq)
	else
		GuardService.setHolding(fighter, holding, nil)
	end
	CombatService.broadcastState()
end

function CombatService.onMobilityIntent(player: Player, payload: any)
	if not MatchService.isFighting() then
		return
	end
	local fighter = FighterState.get(player)
	if not fighter or typeof(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	local seq = payload.seq
	if typeof(seq) ~= "number" or typeof(kind) ~= "string" then
		return
	end
	if not rateOk(mobilityRate, player, CombatConfig.AntiCheat.MobilityRateLimitPerSecond) then
		return
	end

	local dir: Vector3? = nil
	if typeof(payload.dir) == "Vector3" then
		dir = payload.dir
	elseif typeof(payload.dir) == "table" and typeof(payload.dir.X) == "number" then
		dir = Vector3.new(payload.dir.X, payload.dir.Y or 0, payload.dir.Z)
	end

	if kind == "Dodge" then
		DodgeService.tryDodge(fighter, dir, seq)
	elseif kind == "Dash" then
		DashService.tryDash(fighter, dir, seq)
	elseif kind == "Feint" then
		AttackService.tryFeint(fighter, seq)
	end
	CombatService.broadcastState()
end

function CombatService.onFocusIntent(player: Player, payload: any)
	if not MatchService.isFighting() then
		return
	end
	local fighter = FighterState.get(player)
	if not fighter or typeof(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	local seq = payload.seq
	if typeof(seq) ~= "number" or typeof(kind) ~= "string" then
		return
	end
	local dir: Vector3? = nil
	if typeof(payload.dir) == "Vector3" then
		dir = payload.dir
	elseif typeof(payload.dir) == "table" and typeof(payload.dir.X) == "number" then
		dir = Vector3.new(payload.dir.X, payload.dir.Y or 0, payload.dir.Z)
	end
	if kind == "Push" then
		FocusService.tryPush(fighter, seq)
	elseif kind == "DashFocus" then
		FocusService.tryDashFocus(fighter, dir, seq)
	end
	CombatService.broadcastState()
end

function CombatService.step(dt: number)
	MatchService.step(dt)

	-- Enable bot once for solo practice (ne pas reset chaque frame — bug QA)
	if MatchService.isSoloPractice() then
		local _, spawnB = ArenaService.getSpawnCFrames()
		if MatchService.getPhase() == "Countdown" or MatchService.getPhase() == "Fighting" then
			if not BotStub.isEnabled() then
				BotStub.enable(spawnB)
			end
		end
	elseif BotStub.isEnabled() and #Players:GetPlayers() >= 2 then
		BotStub.disable()
	end

	if MatchService.getPhase() == "Fighting" and roundEndReported then
		-- stay locked until phase leaves Fighting (handled below)
	elseif MatchService.getPhase() ~= "Fighting" then
		roundEndReported = false
	end

	if not MatchService.isFighting() then
		BotStub.step(dt, false)
		return
	end

	for _, fighter in FighterState.getAll() do
		-- QoL : re-attacher sabre si nil / détruit (respawn mid, race CharacterAdded)
		if fighter.character and fighter.character.Parent then
			if not fighter.bladePart or not fighter.bladePart.Parent then
				local isBot = BotStub.isEnabled() and fighter == BotStub.getFighter()
				fighter.bladePart = ensureBlade(fighter.character, if isBot then nil else fighter.player)
			end
		end
		if fighter.actionId ~= CombatTypes.ActionId.Dead then
			-- Bot AI stepped separately; still run stamina/mobility for all
			if not BotStub.isEnabled() or fighter ~= BotStub.getFighter() then
				AttackService.step(fighter, dt)
			end
			DodgeService.step(fighter, dt)
			DashService.step(fighter, dt)
			FocusService.step(fighter, dt)
			StaminaService.step(fighter, dt)
		end
	end
	BotStub.step(dt, true)
	HitService.step(dt)
	ArenaService.stepHazards(dt)

	local alive = {}
	for _, f in FighterState.getAll() do
		if f.hp > 0 and f.actionId ~= CombatTypes.ActionId.Dead then
			table.insert(alive, f)
		end
	end
	if #FighterState.getAll() >= 2 and #alive <= 1 and not roundEndReported then
		roundEndReported = true
		if #alive == 1 then
			local winnerFighter = alive[1]
			if MatchService.isSoloPractice() and winnerFighter == BotStub.getFighter() then
				MatchService.onRoundWinner(nil, -9001)
			elseif typeof(winnerFighter.player) == "Instance" and (winnerFighter.player :: any):IsA("Player") then
				MatchService.onRoundWinner(winnerFighter.player :: Player)
			else
				MatchService.onRoundWinner(nil)
			end
		else
			MatchService.onRoundWinner(nil)
		end
	end

	CombatService.broadcastState()
end

function CombatService.start()
	remotes = RemotesMod.get()
	ArenaService.ensureAll()
	MatchService.start()

	remotes.AttackIntent.OnServerEvent:Connect(function(player, payload)
		CombatService.onAttackIntent(player, payload)
	end)
	remotes.GuardIntent.OnServerEvent:Connect(function(player, payload)
		CombatService.onGuardIntent(player, payload)
	end)
	remotes.MobilityIntent.OnServerEvent:Connect(function(player, payload)
		CombatService.onMobilityIntent(player, payload)
	end)
	remotes.FocusIntent.OnServerEvent:Connect(function(player, payload)
		CombatService.onFocusIntent(player, payload)
	end)

	workspace:GetAttributeChangedSignal("BC_RoundStart"):Connect(function()
		if BotStub.isEnabled() then
			local _, spawnB = ArenaService.getSpawnCFrames()
			BotStub.reset(spawnB)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		CombatService.register(player)
		MatchService.enqueue(player, "Casual")
	end)
	for _, player in Players:GetPlayers() do
		CombatService.register(player)
		MatchService.enqueue(player, "Casual")
	end
	Players.PlayerRemoving:Connect(function(player)
		FighterState.remove(player)
		attackRate[player] = nil
		mobilityRate[player] = nil
	end)
end

return CombatService
