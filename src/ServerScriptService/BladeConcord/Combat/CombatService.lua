--!strict
--[[
	Orchestrateur duel : register, tick, broadcast CombatState, RoundEnded.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local RemotesMod = require(Shared:WaitForChild("Remotes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))
local AttackService = require(script.Parent:WaitForChild("AttackService"))
local GuardService = require(script.Parent:WaitForChild("GuardService"))
local HitService = require(script.Parent:WaitForChild("HitService"))
local ArenaService = require(script.Parent:WaitForChild("ArenaService"))

local CombatService = {}

local remotes: RemotesMod.CombatRemotes
local attackRate: { [Player]: { count: number, windowStart: number } } = {}
local roundEnded = false

local function ensureBlade(character: Model): BasePart
	local existing = nil
	for _, inst in CollectionService:GetTagged(CombatConfig.Tags.SaberBlade) do
		if inst:IsDescendantOf(character) and inst:IsA("BasePart") then
			return inst
		end
	end
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local handle = Instance.new("Part")
	handle.Name = "SaberBlade"
	handle.Size = Vector3.new(0.3, 0.3, CombatConfig.Light.BladeLength)
	handle.Massless = true
	handle.CanCollide = false
	handle.Color = Color3.fromRGB(120, 200, 255)
	handle.Material = Enum.Material.Neon
	handle.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = if rightHand and rightHand:IsA("BasePart") then rightHand else character:FindFirstChild("HumanoidRootPart") :: BasePart
	weld.Part1 = handle
	weld.Parent = handle
	if rightHand and rightHand:IsA("BasePart") then
		handle.CFrame = rightHand.CFrame * CFrame.new(0, 0, -CombatConfig.Light.BladeLength * 0.5)
	end
	CollectionService:AddTag(handle, CombatConfig.Tags.SaberBlade)
	return handle
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
	-- Empêche le client de décider la mort hors FighterState
	humanoid.BreakJointsOnDeath = false

	task.defer(function()
		if character.Parent then
			fighter.bladePart = ensureBlade(character)
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
		-- Respawn sur arène
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

function CombatService.endRound(winner: Player?)
	if roundEnded then
		return
	end
	roundEnded = true
	remotes.RoundEnded:FireAllClients({
		winnerUserId = if winner then winner.UserId else nil,
	})
end

function CombatService.resetRound()
	roundEnded = false
	local a, b = ArenaService.getSpawnCFrames()
	local fighters = FighterState.getAll()
	for i, f in fighters do
		FighterState.resetRound(f)
		local character = f.character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if hrp then
				hrp.CFrame = if i % 2 == 1 then a else b
			end
			if humanoid then
				humanoid.Health = CombatConfig.MaxHp
			end
		end
	end
	CombatService.broadcastState()
end

function CombatService.onAttackIntent(player: Player, payload: any)
	local fighter = FighterState.get(player)
	if not fighter or roundEnded then
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

	-- Rate limit ~8/s
	local now = os.clock()
	local bucket = attackRate[player]
	if not bucket or now - bucket.windowStart >= 1 then
		attackRate[player] = { count = 1, windowStart = now }
	else
		bucket.count += 1
		if bucket.count > CombatConfig.AntiCheat.AttackRateLimitPerSecond then
			return
		end
	end

	AttackService.tryStart(fighter, kind, seq)
	CombatService.broadcastState()
end

function CombatService.onGuardIntent(player: Player, payload: any)
	local fighter = FighterState.get(player)
	if not fighter or roundEnded then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	local holding = payload.holding == true
	local seq = payload.seq
	if typeof(seq) == "number" then
		GuardService.setHolding(fighter, holding, seq)
	else
		GuardService.setHolding(fighter, holding, nil)
	end
	CombatService.broadcastState()
end

function CombatService.step(dt: number)
	if roundEnded then
		return
	end
	for _, fighter in FighterState.getAll() do
		if fighter.actionId ~= CombatTypes.ActionId.Dead then
			AttackService.step(fighter, dt)
			StaminaService.step(fighter, dt)
		end
	end
	HitService.step(dt)

	-- KO check
	local alive = {}
	for _, f in FighterState.getAll() do
		if f.hp > 0 and f.actionId ~= CombatTypes.ActionId.Dead then
			table.insert(alive, f)
		end
	end
	if #FighterState.getAll() >= 2 and #alive <= 1 then
		CombatService.endRound(if #alive == 1 then alive[1].player else nil)
	end

	CombatService.broadcastState()
end

function CombatService.start()
	remotes = RemotesMod.get()
	ArenaService.ensureObsidianPit()

	remotes.AttackIntent.OnServerEvent:Connect(function(player, payload)
		CombatService.onAttackIntent(player, payload)
	end)
	remotes.GuardIntent.OnServerEvent:Connect(function(player, payload)
		CombatService.onGuardIntent(player, payload)
	end)

	Players.PlayerAdded:Connect(function(player)
		CombatService.register(player)
	end)
	for _, player in Players:GetPlayers() do
		CombatService.register(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		FighterState.remove(player)
		attackRate[player] = nil
	end)

	-- Place spawns initiaux
	task.defer(function()
		CombatService.resetRound()
	end)
end

return CombatService
