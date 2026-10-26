--!strict
--[[
	Bot Studio — NPC Play Solo (démo footage).
	AI : Light/Heavy, parade, esquive, dash, feinte, Focus Push.
	Ne pas appeler enable() en boucle (reset réservé au début de round).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Visual = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Visual")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local Theme = require(Shared:WaitForChild("Theme"))
local SaberBuilder = require(Visual:WaitForChild("SaberBuilder"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local AttackService = require(script.Parent:WaitForChild("AttackService"))
local GuardService = require(script.Parent:WaitForChild("GuardService"))
local DodgeService = require(script.Parent:WaitForChild("DodgeService"))
local DashService = require(script.Parent:WaitForChild("DashService"))
local FocusService = require(script.Parent:WaitForChild("FocusService"))

local BotStub = {}

local botFighter: FighterState.Fighter? = nil
local botModel: Model? = nil
local accum = 0
local seq = 1000
local enabled = false
local attrs: { [string]: any } = {}
local comboStep = 0

local botPlayer = {
	UserId = -9001,
	Name = "ConcordBot",
	Character = nil :: Model?,
	GetAttribute = function(_self: any, name: string): any
		return attrs[name]
	end,
	SetAttribute = function(_self: any, name: string, value: any)
		attrs[name] = value
	end,
}

function BotStub.isEnabled(): boolean
	return enabled
end

function BotStub.getFighter(): FighterState.Fighter?
	return botFighter
end

function BotStub.getProxyPlayer(): any
	return botPlayer
end

local function ensureBotModel(spawnCf: CFrame): Model
	if botModel and botModel.Parent then
		botModel:PivotTo(spawnCf)
		return botModel
	end
	local model = Instance.new("Model")
	model.Name = "ConcordBot"

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Anchored = false
	hrp.CanCollide = true
	hrp.Color = Color3.fromRGB(80, 80, 100)
	hrp.CFrame = spawnCf
	hrp.Parent = model
	model.PrimaryPart = hrp

	local function weldedPart(name: string, size: Vector3, offset: CFrame, color: Color3): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CanCollide = false
		p.Massless = true
		p.Color = color
		p.CFrame = spawnCf * offset
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = p
		w.Parent = p
		return p
	end

	local head = weldedPart("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0), Color3.fromRGB(200, 180, 160))
	local torso = weldedPart("UpperTorso", Vector3.new(2, 2, 1), CFrame.new(), Color3.fromRGB(60, 60, 80))
	-- Accents démo (lisible en footage, pas R15 complet)
	weldedPart("LowerTorso", Vector3.new(1.8, 0.8, 0.9), CFrame.new(0, -1.2, 0), Color3.fromRGB(50, 50, 70))
	weldedPart("RightUpperArm", Vector3.new(0.7, 1.4, 0.7), CFrame.new(1.35, 0.5, 0), Color3.fromRGB(70, 70, 95))
	local rightHand = weldedPart("RightHand", Vector3.new(0.4, 0.4, 0.8), CFrame.new(1.2, 0.4, -0.6), Color3.fromRGB(200, 180, 160))
	CollectionService:AddTag(torso, CombatConfig.Tags.Hurtbox)
	CollectionService:AddTag(head, CombatConfig.Tags.Hurtbox)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = CombatConfig.MaxHp
	humanoid.Health = CombatConfig.MaxHp
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	-- Billboard nom démo
	local bill = Instance.new("BillboardGui")
	bill.Name = "BotLabel"
	bill.Size = UDim2.fromOffset(140, 28)
	bill.StudsOffset = Vector3.new(0, 2.8, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = head
	bill.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.TextColor3 = Theme.Danger
	lbl.Text = "CONCORD BOT"
	lbl.Parent = bill

	model.Parent = workspace
	local build = SaberBuilder.attach(model, Theme.Danger)
	model:SetAttribute("BC_HasSaber", build.blade ~= nil)
	botModel = model
	return model
end

function BotStub.enable(spawnCf: CFrame)
	-- Idempotent : pas de reset ici (sinon CombatService.step reset chaque frame)
	if enabled and botFighter then
		return
	end
	enabled = true
	local model = ensureBotModel(spawnCf)
	botPlayer.Character = model
	if not botFighter then
		botFighter = FighterState.create(botPlayer :: any)
	end
	botFighter.character = model
	local blade: BasePart? = nil
	for _, inst in CollectionService:GetTagged(CombatConfig.Tags.SaberBlade) do
		if inst:IsDescendantOf(model) and inst:IsA("BasePart") then
			blade = inst
			break
		end
	end
	if not blade then
		local rebuild = SaberBuilder.attach(model, Theme.Danger)
		blade = rebuild.blade
	end
	botFighter.bladePart = blade
	botFighter.hurtboxes = {}
	for _, name in { "UpperTorso", "Head" } do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(botFighter.hurtboxes, p)
		end
	end
	FighterState.resetMatch(botFighter)
	botFighter.formId = "Duelant"
	botFighter.formRarity = "Rare"
	comboStep = 0
	accum = 0
	print("[BladeConcord] BotStub enabled (Play Solo) — sabre + anim set Duelant_Rare_PerfectEdge · AI démo")
end

function BotStub.disable()
	enabled = false
	comboStep = 0
	if botFighter then
		FighterState.remove(botPlayer :: any)
		botFighter = nil
	end
	if botModel then
		botModel:Destroy()
		botModel = nil
	end
end

function BotStub.reset(spawnCf: CFrame?)
	if not botFighter then
		return
	end
	FighterState.resetRound(botFighter)
	comboStep = 0
	accum = 0.4 -- petit délai avant première action post-round
	if botModel then
		botModel:PivotTo(spawnCf or CFrame.new(18, 4, 0) * CFrame.Angles(0, math.rad(-90), 0))
	end
end

local function findPlayerRoot(): BasePart?
	for _, p in Players:GetPlayers() do
		local ch = p.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return hrp
		end
	end
	return nil
end

local function faceOpponent()
	if not botModel then
		return
	end
	local hrp = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = findPlayerRoot()
	if not hrp or not target then
		return
	end
	local pos = hrp.Position
	local look = Vector3.new(target.Position.X, pos.Y, target.Position.Z)
	hrp.CFrame = CFrame.lookAt(pos, look)
end

local function towardPlayer(): Vector3
	if not botModel then
		return Vector3.new(0, 0, -1)
	end
	local hrp = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = findPlayerRoot()
	if not hrp or not target then
		return Vector3.new(0, 0, -1)
	end
	local flat = Vector3.new(target.Position.X - hrp.Position.X, 0, target.Position.Z - hrp.Position.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	end
	return flat.Unit
end

local function lateralDir(sign: number): Vector3
	local forward = towardPlayer()
	return Vector3.new(-forward.Z * sign, 0, forward.X * sign)
end

local function distanceToPlayer(): number
	if not botModel then
		return 99
	end
	local hrp = botModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = findPlayerRoot()
	if not hrp or not target then
		return 99
	end
	return (Vector3.new(target.Position.X, 0, target.Position.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
end

--[[
	Script démo cyclique (footage) — pas un vrai skill AI.
	0 Light · 1 Light · 2 Guard · 3 Heavy · 4 Dodge · 5 Dash in · 6 Light · 7 Focus · 8 Feint setup
]]
local function pickAndAct()
	if not botFighter then
		return
	end
	seq += 1
	local dist = distanceToPlayer()
	local step = comboStep % 9
	comboStep += 1

	-- Trop loin → dash / approche avant combo
	if dist > 14 and step ~= 5 then
		DashService.tryDash(botFighter, towardPlayer(), seq)
		return
	end

	if step == 0 or step == 1 or step == 6 then
		GuardService.setHolding(botFighter, false, seq)
		AttackService.tryStart(botFighter, CombatTypes.AttackKind.Light, seq + 1)
	elseif step == 2 then
		GuardService.setHolding(botFighter, true, seq)
		local holdSeq = seq
		task.delay(0.55, function()
			if botFighter and enabled then
				GuardService.setHolding(botFighter, false, holdSeq + 50)
			end
		end)
	elseif step == 3 then
		GuardService.setHolding(botFighter, false, seq)
		AttackService.tryStart(botFighter, CombatTypes.AttackKind.Heavy, seq + 1)
	elseif step == 4 then
		local side = if math.random() < 0.5 then 1 else -1
		DodgeService.tryDodge(botFighter, lateralDir(side), seq)
	elseif step == 5 then
		DashService.tryDash(botFighter, towardPlayer(), seq)
	elseif step == 7 then
		FocusService.tryPush(botFighter, seq)
	else
		-- Feinte : Light startup puis cancel Guard
		GuardService.setHolding(botFighter, false, seq)
		if AttackService.tryStart(botFighter, CombatTypes.AttackKind.Light, seq + 1) then
			local feintSeq = seq + 2
			task.delay(0.1, function()
				if botFighter and enabled then
					AttackService.tryFeint(botFighter, feintSeq)
				end
			end)
		end
	end
end

function BotStub.step(dt: number, fighting: boolean)
	if not enabled or not botFighter or not fighting then
		return
	end
	if botFighter.actionId == CombatTypes.ActionId.Dead then
		return
	end
	AttackService.step(botFighter, dt)
	faceOpponent()

	-- Cadence démo ~0.85 s entre décisions (Idle/Guard seulement)
	accum += dt
	if accum < 0.85 then
		return
	end
	if botFighter.actionId ~= CombatTypes.ActionId.Idle and botFighter.actionId ~= CombatTypes.ActionId.Guard then
		return
	end
	accum = 0
	pickAndAct()
end

return BotStub
