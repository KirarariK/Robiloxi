--!strict
--[[
	Poses combat procédurales (CFrame tween sur Motor6D) —
	attaque / parade / esquive / dash / Focus.
	Pas d'AnimationClip requis ; chaque client pose tous les fighters via CombatState.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))
local SaberBuilder = require(ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Visual"):WaitForChild("SaberBuilder"))

local SaberPose = {}

local ACTION_COLOR: { [string]: Color3 } = {
	Idle = Theme.BladeIdle,
	Guard = Theme.BladeGuard,
	Startup = Theme.BladeStartup,
	Active = Theme.BladeActive,
	Recovery = Theme.BladeRecovery,
	Stagger = Theme.AccentHot,
	RiposteLock = Theme.Focus,
	Dodge = Theme.BladeDodge,
	Dash = Theme.BladeDash,
	FocusPush = Theme.BladeFocus,
	FocusDash = Theme.BladeFocus,
	Dead = Theme.BladeDead,
}

-- Motor6D.C1 offsets (rad) — relative grip
local POSES: { [string]: CFrame } = {
	Idle = CFrame.new(),
	Guard = CFrame.Angles(math.rad(-35), math.rad(25), math.rad(-15)),
	Startup = CFrame.Angles(math.rad(-70), math.rad(-40), math.rad(20)),
	Active = CFrame.Angles(math.rad(25), math.rad(70), math.rad(-10)),
	Recovery = CFrame.Angles(math.rad(-15), math.rad(20), math.rad(5)),
	Stagger = CFrame.Angles(math.rad(40), math.rad(-30), math.rad(25)),
	RiposteLock = CFrame.Angles(math.rad(-20), math.rad(10), math.rad(0)),
	Dodge = CFrame.Angles(math.rad(-50), math.rad(60), math.rad(-40)),
	Dash = CFrame.Angles(math.rad(10), math.rad(-20), math.rad(5)),
	FocusPush = CFrame.Angles(math.rad(-20), math.rad(0), math.rad(0)) * CFrame.new(0, 0, -0.3),
	FocusDash = CFrame.Angles(math.rad(-10), math.rad(0), math.rad(0)),
	Dead = CFrame.Angles(math.rad(80), 0, math.rad(30)),
}

local lastAction: { [number]: string } = {}
local activeTweens: { [Motor6D]: Tween } = {}

local function findMotor(character: Model): Motor6D?
	local saber = character:FindFirstChild("EnergySaber")
	if not saber then
		return nil
	end
	local grip = saber:FindFirstChild("HiltGrip")
	if not grip then
		return nil
	end
	local motor = grip:FindFirstChild("SaberMotor")
	if motor and motor:IsA("Motor6D") then
		return motor
	end
	return nil
end

local function findBlade(character: Model): BasePart?
	for _, inst in CollectionService:GetTagged(CombatConfig.Tags.SaberBlade) do
		if inst:IsDescendantOf(character) and inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

local function poseCharacter(character: Model, actionId: string)
	local motor = findMotor(character)
	local blade = findBlade(character)
	local target = POSES[actionId] or POSES.Idle
	local color = ACTION_COLOR[actionId] or Theme.BladeIdle

	if blade then
		SaberBuilder.setBladeColor(blade, color)
		SaberBuilder.setTrailEnabled(blade, actionId == "Active" or actionId == "Startup" or actionId == "Dash" or actionId == "FocusDash")
		local light = blade:FindFirstChild("BladeLight")
		if light and light:IsA("PointLight") then
			light.Brightness = if actionId == "Active" or actionId == "FocusPush" then 3.5 else 2.0
		end
	end

	if not motor then
		return
	end

	local prev = activeTweens[motor]
	if prev then
		prev:Cancel()
	end

	local duration = 0.12
	if actionId == "Active" then
		duration = 0.07
	elseif actionId == "Startup" then
		duration = 0.14
	elseif actionId == "Guard" then
		duration = 0.1
	elseif actionId == "Dodge" then
		duration = 0.08
	end

	local tw = TweenService:Create(motor, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		C1 = target,
	})
	activeTweens[motor] = tw
	tw.Completed:Connect(function()
		if activeTweens[motor] == tw then
			activeTweens[motor] = nil
		end
	end)
	tw:Play()
end

local function resolveCharacter(userId: number): Model?
	if userId == -9001 then
		local bot = workspace:FindFirstChild("ConcordBot")
		if bot and bot:IsA("Model") then
			return bot
		end
		return nil
	end
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character or nil
end

function SaberPose.start()
	local remotes = Remotes.get()

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			local actionId = tostring(snap.actionId or "Idle")
			local userId = snap.userId
			if typeof(userId) ~= "number" then
				continue
			end
			if lastAction[userId] == actionId then
				continue
			end
			lastAction[userId] = actionId
			local character = resolveCharacter(userId)
			if character then
				poseCharacter(character, actionId)
			end
		end
	end)

	-- Micro-bob idle léger pour présence
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end
			local uid = player.UserId
			if lastAction[uid] and lastAction[uid] ~= "Idle" then
				continue
			end
			local motor = findMotor(character)
			if motor and not activeTweens[motor] then
				motor.C1 = CFrame.Angles(math.sin(t * 2.2) * 0.04, math.cos(t * 1.6) * 0.03, 0)
			end
		end
	end)
end

return SaberPose
