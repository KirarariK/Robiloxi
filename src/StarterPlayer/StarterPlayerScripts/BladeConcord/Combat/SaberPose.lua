--!strict
--[[
	Poses combat Motor6D (fallback) + visuals lame (couleur / trail / light).
	Chemin principal = CombatAnimator (KeyframeSequence / Procedural).
	SaberPose.applyMotorFallback si track manquant.
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

local SoundHooks: any = nil
pcall(function()
	SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))
end)

local SaberPose = {}

local combatListenerEnabled = true
local visualOnlyStarted = false
local remotesBound = false

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

-- Motor6D.C1 — arcs fallback si Animator / Procedural indisponible
local POSES: { [string]: CFrame } = {
	Idle = CFrame.new(),
	Guard = CFrame.Angles(math.rad(-42), math.rad(32), math.rad(-18)) * CFrame.new(0.05, 0.08, 0),
	Startup = CFrame.Angles(math.rad(-88), math.rad(-55), math.rad(28)) * CFrame.new(-0.12, 0.15, 0.08),
	StartupHeavy = CFrame.Angles(math.rad(-105), math.rad(-70), math.rad(35)) * CFrame.new(-0.18, 0.22, 0.12),
	Active = CFrame.Angles(math.rad(38), math.rad(95), math.rad(-18)) * CFrame.new(0.2, -0.1, -0.15),
	ActiveHeavy = CFrame.Angles(math.rad(55), math.rad(120), math.rad(-25)) * CFrame.new(0.28, -0.18, -0.22),
	Recovery = CFrame.Angles(math.rad(-8), math.rad(28), math.rad(8)) * CFrame.new(0.05, -0.05, 0),
	RecoveryHeavy = CFrame.Angles(math.rad(22), math.rad(48), math.rad(-12)) * CFrame.new(0.12, -0.12, -0.08),
	Stagger = CFrame.Angles(math.rad(48), math.rad(-38), math.rad(30)),
	RiposteLock = CFrame.Angles(math.rad(-28), math.rad(14), math.rad(0)),
	Dodge = CFrame.Angles(math.rad(-58), math.rad(72), math.rad(-48)) * CFrame.new(0.1, 0.05, 0),
	Dash = CFrame.Angles(math.rad(14), math.rad(-28), math.rad(8)) * CFrame.new(0, 0, -0.12),
	FocusPush = CFrame.Angles(math.rad(-28), math.rad(0), math.rad(0)) * CFrame.new(0, 0, -0.4),
	FocusDash = CFrame.Angles(math.rad(-14), math.rad(0), math.rad(0)) * CFrame.new(0, 0, -0.2),
	Dead = CFrame.Angles(math.rad(88), 0, math.rad(35)),
}

local lastAction: { [number]: string } = {}
local lastKind: { [number]: string } = {}
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

local function resolvePoseKey(actionId: string, attackKind: string?): string
	local heavy = attackKind == "Heavy"
	if actionId == "Startup" and heavy then
		return "StartupHeavy"
	elseif actionId == "Active" and heavy then
		return "ActiveHeavy"
	elseif actionId == "Recovery" and heavy then
		return "RecoveryHeavy"
	end
	return actionId
end

function SaberPose.applyVisuals(character: Model, actionId: string, attackKind: string?)
	local blade = findBlade(character)
	local color = ACTION_COLOR[actionId] or Theme.BladeIdle
	if not blade then
		return
	end
	if actionId == "Idle" then
		local r = blade:GetAttribute("CosmeticR")
		local g = blade:GetAttribute("CosmeticG")
		local b = blade:GetAttribute("CosmeticB")
		if typeof(r) == "number" and typeof(g) == "number" and typeof(b) == "number" then
			SaberBuilder.setBladeColor(blade, Color3.new(r, g, b))
		else
			SaberBuilder.setBladeColor(blade, color)
		end
	else
		SaberBuilder.setBladeColor(blade, color)
	end
	SaberBuilder.setTrailEnabled(
		blade,
		actionId == "Active" or actionId == "Startup" or actionId == "Dash" or actionId == "FocusDash"
	)
	local light = blade:FindFirstChild("BladeLight")
	if light and light:IsA("PointLight") then
		local bright = 2.0
		if actionId == "Active" then
			bright = if attackKind == "Heavy" then 4.2 else 3.5
		elseif actionId == "FocusPush" then
			bright = 3.8
		elseif actionId == "Startup" then
			bright = 2.8
		end
		light.Brightness = bright
	end
end

function SaberPose.applyMotorFallback(character: Model, actionId: string, attackKind: string?)
	local motor = findMotor(character)
	if not motor then
		return
	end
	local poseKey = resolvePoseKey(actionId, attackKind)
	local target = POSES[poseKey] or POSES[actionId] or POSES.Idle

	local prev = activeTweens[motor]
	if prev then
		prev:Cancel()
	end

	local heavy = attackKind == "Heavy"
	local duration = 0.12
	local easing = Enum.EasingStyle.Quad
	local dir = Enum.EasingDirection.Out

	if actionId == "Active" then
		duration = if heavy then 0.1 else 0.065
		easing = Enum.EasingStyle.Back
		dir = Enum.EasingDirection.Out
		if SoundHooks and character == Players.LocalPlayer.Character then
			SoundHooks.play("Swing")
		end
	elseif actionId == "Startup" then
		duration = if heavy then 0.2 else 0.13
		easing = Enum.EasingStyle.Quad
		dir = Enum.EasingDirection.In
	elseif actionId == "Recovery" then
		duration = if heavy then 0.22 else 0.11
		easing = Enum.EasingStyle.Sine
		dir = Enum.EasingDirection.Out
	elseif actionId == "Guard" then
		duration = 0.09
	elseif actionId == "Dodge" then
		duration = 0.07
		easing = Enum.EasingStyle.Back
	elseif actionId == "Dash" or actionId == "FocusDash" then
		duration = 0.06
	end

	local tw = TweenService:Create(motor, TweenInfo.new(duration, easing, dir), {
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

local function poseCharacter(character: Model, actionId: string, attackKind: string?)
	SaberPose.applyVisuals(character, actionId, attackKind)
	SaberPose.applyMotorFallback(character, actionId, attackKind)
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

function SaberPose.setCombatListenerEnabled(enabled: boolean)
	combatListenerEnabled = enabled
end

function SaberPose.startVisualOnly()
	if visualOnlyStarted then
		return
	end
	visualOnlyStarted = true
	-- Micro-bob idle si aucun tween Motor C1 actif (fallback path)
	RunService.RenderStepped:Connect(function()
		if not combatListenerEnabled then
			-- CombatAnimator / Procedural gère Transform — pas de bob C1
			return
		end
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
				motor.C1 = CFrame.Angles(math.sin(t * 2.2) * 0.045, math.cos(t * 1.6) * 0.035, math.sin(t * 1.1) * 0.015)
			end
		end
	end)
end

function SaberPose.start()
	SaberPose.startVisualOnly()
	if remotesBound then
		return
	end
	remotesBound = true
	local remotes = Remotes.get()

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if not combatListenerEnabled then
			return
		end
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			local actionId = tostring(snap.actionId or "Idle")
			local userId = snap.userId
			local attackKind = if typeof(snap.attackKind) == "string" then snap.attackKind else nil
			if typeof(userId) ~= "number" then
				continue
			end
			local kindKey = attackKind or ""
			if lastAction[userId] == actionId and lastKind[userId] == kindKey then
				continue
			end
			lastAction[userId] = actionId
			lastKind[userId] = kindKey
			local character = resolveCharacter(userId)
			if character then
				poseCharacter(character, actionId, attackKind)
			end
		end
	end)
end

return SaberPose
