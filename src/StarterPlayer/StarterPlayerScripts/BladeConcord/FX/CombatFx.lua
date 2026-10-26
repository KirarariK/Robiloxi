--!strict
--[[
	VFX combat showcase : perfect flash, hit sparks, Focus wave, dash trail, KO cinématique courte.
	100 % Studio-native (Parts / Beams / Particles / Billboard).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SaberBuilder = require(ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Visual"):WaitForChild("SaberBuilder"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CollectionService = game:GetService("CollectionService")

local CombatFx = {}

local CameraShake: any = nil
local SoundHooks: any = nil

local function getFolder(): Folder
	local f = Workspace:FindFirstChild("BC_Fx")
	if f and f:IsA("Folder") then
		return f
	end
	local folder = Instance.new("Folder")
	folder.Name = "BC_Fx"
	folder.Parent = Workspace
	return folder
end

local function findBlade(userId: number): BasePart?
	local character: Model? = nil
	if userId == -9001 then
		local bot = Workspace:FindFirstChild("ConcordBot")
		if bot and bot:IsA("Model") then
			character = bot
		end
	else
		local p = Players:GetPlayerByUserId(userId)
		character = p and p.Character
	end
	if not character then
		return nil
	end
	for _, inst in CollectionService:GetTagged(CombatConfig.Tags.SaberBlade) do
		if inst:IsDescendantOf(character) and inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

local function characterRoot(userId: number): BasePart?
	if userId == -9001 then
		local bot = Workspace:FindFirstChild("ConcordBot")
		if bot and bot:IsA("Model") then
			return bot:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
		return nil
	end
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character and (p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

local function sparkBurst(position: Vector3, color: Color3, count: number?)
	local attPart = Instance.new("Part")
	attPart.Name = "SparkHost"
	attPart.Anchored = true
	attPart.CanCollide = false
	attPart.Transparency = 1
	attPart.Size = Vector3.new(0.2, 0.2, 0.2)
	attPart.CFrame = CFrame.new(position)
	attPart.Parent = getFolder()

	local att = Instance.new("Attachment")
	att.Parent = attPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.2, 0.45)
	emitter.Speed = NumberRange.new(10, 28)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = 0
	emitter.Parent = att
	emitter:Emit(count or 24)

	-- Flash ball
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.4, 0.4, 0.4)
	flash.Anchored = true
	flash.CanCollide = false
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.CFrame = CFrame.new(position)
	flash.Parent = getFolder()
	TweenService:Create(flash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(2.4, 2.4, 2.4),
		Transparency = 1,
	}):Play()

	Debris:AddItem(attPart, 0.8)
	Debris:AddItem(flash, 0.4)
end

local function ringWave(position: Vector3, color: Color3, maxSize: number)
	local ring = Instance.new("Part")
	ring.Name = "FocusWave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.4, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = getFolder()

	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, maxSize, maxSize),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)

	-- Secondary shock disk
	local disk = Instance.new("Part")
	disk.Name = "FocusDisk"
	disk.Anchored = true
	disk.CanCollide = false
	disk.Material = Enum.Material.ForceField
	disk.Color = color
	disk.Size = Vector3.new(2, 0.2, 2)
	disk.CFrame = CFrame.new(position)
	disk.Parent = getFolder()
	TweenService:Create(disk, TweenInfo.new(0.4), {
		Size = Vector3.new(maxSize * 1.2, 0.15, maxSize * 1.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(disk, 0.45)
end

local function dashTrail(root: BasePart, color: Color3)
	local ghost = Instance.new("Part")
	ghost.Name = "DashGhost"
	ghost.Size = Vector3.new(2, 3, 1)
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.Material = Enum.Material.ForceField
	ghost.Color = color
	ghost.Transparency = 0.35
	ghost.CFrame = root.CFrame
	ghost.Parent = getFolder()
	TweenService:Create(ghost, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	Debris:AddItem(ghost, 0.4)

	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 1, 0)
	att0.Parent = root
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -1, 0)
	att1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root
	task.delay(0.35, function()
		trail:Destroy()
		att0:Destroy()
		att1:Destroy()
	end)
end

local function perfectFlash(position: Vector3)
	sparkBurst(position, Theme.Perfect, 40)
	ringWave(position, Theme.Perfect, 10)

	-- Screen white flash léger
	local cc = Lighting:FindFirstChild("BC_ImpactCC")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BC_ImpactCC"
		cc.Parent = Lighting
	end
	local effect = cc :: ColorCorrectionEffect
	effect.Brightness = 0.35
	effect.Contrast = 0.15
	TweenService:Create(effect, TweenInfo.new(0.25), { Brightness = 0, Contrast = 0 }):Play()
end

local function impactFrame(seconds: number)
	-- Freeze visuelle courte via ColorCorrection + cam shake
	local cc = Lighting:FindFirstChild("BC_ImpactCC")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BC_ImpactCC"
		cc.Parent = Lighting
	end
	local effect = cc :: ColorCorrectionEffect
	effect.Contrast = 0.35
	effect.Saturation = -0.2
	task.delay(seconds, function()
		TweenService:Create(effect, TweenInfo.new(0.12), { Contrast = 0, Saturation = 0 }):Play()
	end)
end

local function koCinematic(winnerId: number?, loserId: number?)
	local loserRoot = if loserId then characterRoot(loserId) else nil
	local winnerRoot = if winnerId then characterRoot(winnerId) else nil
	local pos = if loserRoot then loserRoot.Position else (if winnerRoot then winnerRoot.Position else Vector3.new())
	pos += Vector3.new(0, 2, 0)

	sparkBurst(pos, Theme.AccentHot, 50)
	ringWave(pos, Theme.Danger, 16)

	local billboardHost = Instance.new("Part")
	billboardHost.Anchored = true
	billboardHost.CanCollide = false
	billboardHost.Transparency = 1
	billboardHost.Size = Vector3.new(1, 1, 1)
	billboardHost.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	billboardHost.Parent = getFolder()

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(280, 60)
	gui.AlwaysOnTop = true
	gui.Parent = billboardHost
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontTitle
	label.TextSize = 36
	label.TextColor3 = Theme.Bone
	label.TextStrokeTransparency = 0.4
	label.Text = "CONCORDANCE"
	label.Parent = gui

	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(billboardHost, 1.4)

	if CameraShake then
		CameraShake.shake(0.55, 0.45)
	end
	impactFrame(0.08)
	if SoundHooks then
		SoundHooks.play("Ko")
	end
end

function CombatFx.bind(deps: { CameraShake: any?, SoundHooks: any? })
	CameraShake = deps.CameraShake
	SoundHooks = deps.SoundHooks
end

function CombatFx.start()
	local remotes = Remotes.get()
	local localPlayer = Players.LocalPlayer

	remotes.HitResolved.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local involvesMe = payload.attackerUserId == localPlayer.UserId or payload.defenderUserId == localPlayer.UserId
		local defRoot = characterRoot(payload.defenderUserId or 0)
		local pos = if defRoot then defRoot.Position + Vector3.new(0, 2, 0) else Vector3.new(0, 4, 0)

		if payload.perfect then
			perfectFlash(pos)
			local blade = findBlade(payload.defenderUserId or 0) or findBlade(payload.attackerUserId or 0)
			if blade then
				SaberBuilder.burstClash(blade, 36)
			end
			if involvesMe and CameraShake then
				CameraShake.shake(0.35, 0.25)
			end
			impactFrame(0.05)
			if SoundHooks then
				SoundHooks.play("Perfect")
			end
		elseif payload.clash then
			sparkBurst(pos, Theme.Clash, 32)
			local blade = findBlade(payload.attackerUserId or 0)
			if blade then
				SaberBuilder.burstClash(blade, 28)
			end
			if involvesMe and CameraShake then
				CameraShake.shake(0.28, 0.2)
			end
			impactFrame(0.04)
			if SoundHooks then
				SoundHooks.play("Clash")
			end
		elseif payload.guardBreak then
			sparkBurst(pos, Theme.AccentHot, 22)
			if involvesMe and CameraShake then
				CameraShake.shake(0.4, 0.3)
			end
			if SoundHooks then
				SoundHooks.play("GuardBreak")
			end
		elseif payload.dodged then
			sparkBurst(pos, Theme.BladeDodge, 12)
			if SoundHooks then
				SoundHooks.play("Dodge")
			end
		elseif (payload.damage or 0) > 0 then
			sparkBurst(pos, Theme.Danger, 20)
			if involvesMe and CameraShake then
				CameraShake.shake(0.22, 0.18)
			end
			if (payload.damage or 0) >= 20 then
				impactFrame(0.035)
			end
			if SoundHooks then
				SoundHooks.play("Hit")
			end
		end
	end)

	remotes.FxEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local kind = payload.kind
		local data = if typeof(payload.payload) == "table" then payload.payload else payload

		if kind == "FocusPush" or kind == "FocusPushParried" then
			local uid = data.userId or data.attackerUserId or localPlayer.UserId
			local root = characterRoot(uid)
			if root then
				ringWave(root.Position + Vector3.new(0, 1.5, 0), Theme.Focus, 14)
				sparkBurst(root.Position + Vector3.new(0, 1.5, 0), Theme.Focus, 18)
			end
			if CameraShake then
				CameraShake.shake(0.3, 0.22)
			end
			if SoundHooks then
				SoundHooks.play("FocusPush")
			end
		elseif kind == "FocusDash" or kind == "Dash" then
			local uid = data.userId or localPlayer.UserId
			local root = characterRoot(uid)
			if root then
				dashTrail(root, if kind == "FocusDash" then Theme.BladeFocus else Theme.BladeDash)
			end
			if SoundHooks then
				SoundHooks.play("Dash")
			end
		elseif kind == "ClashSparks" then
			-- déjà géré via HitResolved ; bonus tip burst
		elseif kind == "PerfectFlash" then
			-- déjà géré
		elseif kind == "HitSparks" then
			-- déjà géré
		elseif kind == "KoFinisher" then
			koCinematic(data.winnerUserId, data.loserUserId)
		end
	end)

	-- KO / finisher via FxEvent "KoFinisher" uniquement (évite double flash)
end

return CombatFx
