--!strict
--[[
	Prediction visuelle + stubs VFX clash / hit sparks / trails.
	Aucun crédit de dégâts local.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CombatPredict = {}

local lastAction: { [number]: string } = {}

local ACTION_COLOR = {
	Idle = Color3.fromRGB(120, 200, 255),
	Guard = Color3.fromRGB(80, 160, 255),
	Startup = Color3.fromRGB(255, 220, 100),
	Active = Color3.fromRGB(255, 80, 80),
	Recovery = Color3.fromRGB(180, 180, 180),
	Stagger = Color3.fromRGB(255, 140, 40),
	RiposteLock = Color3.fromRGB(200, 100, 255),
	Dodge = Color3.fromRGB(100, 255, 200),
	Dash = Color3.fromRGB(255, 180, 80),
	FocusPush = Color3.fromRGB(180, 120, 255),
	FocusDash = Color3.fromRGB(140, 255, 220),
	Dead = Color3.fromRGB(40, 40, 40),
}

local function findBlade(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	if not player or not player.Character then
		return nil
	end
	for _, inst in CollectionService:GetTagged(CombatConfig.Tags.SaberBlade) do
		if inst:IsDescendantOf(player.Character) and inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

local function setTrail(blade: BasePart, on: boolean)
	local trail = blade:FindFirstChild("SaberTrailStub")
	if trail and trail:IsA("Trail") then
		trail.Enabled = on
	end
end

local function sparkBurst(position: Vector3, color: Color3)
	-- TODO: ParticleEmitter art — stub Part flash
	local p = Instance.new("Part")
	p.Name = "FxSparkStub"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.6, 0.6, 0.6)
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.CFrame = CFrame.new(position)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.35), {
		Transparency = 1,
		Size = Vector3.new(2, 2, 2),
	}):Play()
	task.delay(0.4, function()
		p:Destroy()
	end)
end

function CombatPredict.start()
	local remotes = Remotes.get()

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			local actionId = snap.actionId
			local userId = snap.userId
			if lastAction[userId] ~= actionId then
				lastAction[userId] = actionId
				local blade = findBlade(userId)
				if blade then
					blade.Color = ACTION_COLOR[actionId] or ACTION_COLOR.Idle
					setTrail(blade, actionId == "Active" or actionId == "Startup")
				end
			end
		end
	end)

	remotes.HitResolved.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local def = Players:GetPlayerByUserId(payload.defenderUserId or 0)
		local pos = Vector3.new(0, 4, 0)
		if def and def.Character then
			local hrp = def.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				pos = hrp.Position + Vector3.new(0, 2, 0)
			end
		end
		if payload.clash then
			sparkBurst(pos, Color3.fromRGB(220, 240, 255))
		elseif payload.perfect then
			sparkBurst(pos, Color3.fromRGB(255, 230, 120))
		elseif payload.dodged then
			sparkBurst(pos, Color3.fromRGB(120, 255, 200))
		elseif (payload.damage or 0) > 0 then
			sparkBurst(pos, Color3.fromRGB(255, 100, 80))
		end
	end)

	remotes.FxEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		-- Stubs nommés : ClashSparks / PerfectFlash / FocusPush / FocusDash
		if payload.kind == "FocusPush" or payload.kind == "FocusDash" then
			local localPlayer = Players.LocalPlayer
			local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				sparkBurst(hrp.Position + Vector3.new(0, 2, 0), Color3.fromRGB(180, 140, 255))
			end
		end
	end)
end

return CombatPredict
