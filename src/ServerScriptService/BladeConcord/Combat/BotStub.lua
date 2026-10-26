--!strict
--[[
	Bot stub Studio — NPC pour Play Solo (attaques légères périodiques).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local AttackService = require(script.Parent:WaitForChild("AttackService"))
local GuardService = require(script.Parent:WaitForChild("GuardService"))

local BotStub = {}

local botFighter: FighterState.Fighter? = nil
local botModel: Model? = nil
local accum = 0
local seq = 1000
local enabled = false
local attrs: { [string]: any } = {}

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
	local blade = weldedPart(
		"SaberBlade",
		Vector3.new(0.3, 0.3, CombatConfig.Light.BladeLength),
		CFrame.new(1.2, 0.5, -1.2),
		Color3.fromRGB(255, 100, 100)
	)
	blade.Material = Enum.Material.Neon
	CollectionService:AddTag(blade, CombatConfig.Tags.SaberBlade)
	CollectionService:AddTag(torso, CombatConfig.Tags.Hurtbox)
	CollectionService:AddTag(head, CombatConfig.Tags.Hurtbox)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = CombatConfig.MaxHp
	humanoid.Health = CombatConfig.MaxHp
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.Parent = workspace
	botModel = model
	return model
end

function BotStub.enable(spawnCf: CFrame)
	if enabled and botFighter then
		BotStub.reset(spawnCf)
		return
	end
	enabled = true
	local model = ensureBotModel(spawnCf)
	botPlayer.Character = model
	if not botFighter then
		botFighter = FighterState.create(botPlayer :: any)
	end
	botFighter.character = model
	botFighter.bladePart = model:FindFirstChild("SaberBlade") :: BasePart
	botFighter.hurtboxes = {}
	for _, name in { "UpperTorso", "Head" } do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(botFighter.hurtboxes, p)
		end
	end
	FighterState.resetMatch(botFighter)
	print("[BladeConcord] BotStub enabled (Play Solo)")
end

function BotStub.disable()
	enabled = false
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
	if botModel then
		botModel:PivotTo(spawnCf or CFrame.new(18, 4, 0) * CFrame.Angles(0, math.rad(-90), 0))
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
	accum += dt
	if accum < 1.35 then
		return
	end
	accum = 0
	seq += 1
	if botFighter.actionId == CombatTypes.ActionId.Idle or botFighter.actionId == CombatTypes.ActionId.Guard then
		if math.random() < 0.3 then
			GuardService.setHolding(botFighter, true, seq)
			local holdSeq = seq
			task.delay(0.4, function()
				if botFighter then
					GuardService.setHolding(botFighter, false, holdSeq + 1)
				end
			end)
		else
			GuardService.setHolding(botFighter, false, seq)
			AttackService.tryStart(botFighter, CombatTypes.AttackKind.Light, seq + 1)
		end
	end
end

return BotStub
