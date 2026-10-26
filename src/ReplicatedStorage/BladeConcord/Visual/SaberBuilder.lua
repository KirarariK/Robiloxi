--!strict
--[[
	Sabre d'énergie Constructible 100 % Studio-native.
	Hitbox = Part "SaberBlade" (taguée) — LookVector = axe lame.
	Visuel = hilt détaillé + Beam Neon + Trail + PointLight + particles clash.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Theme = require(Shared:WaitForChild("Theme"))

local SaberBuilder = {}

export type SaberBuild = {
	model: Model,
	blade: BasePart,
	motor: Motor6D,
	grip: BasePart,
	trail: Trail,
	light: PointLight,
	beam: Beam,
	clashEmitter: ParticleEmitter,
}

local function weldPart(
	name: string,
	size: Vector3,
	relative: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	anchor: BasePart,
	shape: Enum.PartType?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.CFrame = anchor.CFrame * relative
	p.Parent = parent
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = p
	w.Parent = p
	return p
end

local function stubSound(parent: Instance, name: string, volume: number)
	local s = Instance.new("Sound")
	s.Name = name
	s.Volume = volume
	s.RollOffMaxDistance = 60
	s.PlaybackSpeed = 1
	-- SoundId vide = stub silencieux jusqu'à asset Studio
	s.SoundId = ""
	s.Parent = parent
	return s
end

--[[
	Construit et attache un sabre à la main droite (Motor6D).
	Retourne le Part hitbox tagué SaberBlade.
]]
function SaberBuilder.attach(character: Model, bladeColor: Color3?): SaberBuild
	-- Nettoyage éventuel
	local existing = character:FindFirstChild("EnergySaber")
	if existing then
		existing:Destroy()
	end

	local rightHand = character:FindFirstChild("RightHand")
		or character:FindFirstChild("Right Arm")
		or character:FindFirstChild("HumanoidRootPart")
	assert(rightHand and rightHand:IsA("BasePart"), "SaberBuilder: no hand/root")

	local length = CombatConfig.Light.BladeLength
	local color = bladeColor or Theme.BladeIdle

	local model = Instance.new("Model")
	model.Name = "EnergySaber"
	model.Parent = character

	-- Grip invisible = ancre Motor6D
	local grip = Instance.new("Part")
	grip.Name = "HiltGrip"
	grip.Size = Vector3.new(0.28, 0.28, 0.9)
	grip.Transparency = 1
	grip.CanCollide = false
	grip.Massless = true
	grip.CastShadow = false
	grip.Parent = model

	local motor = Instance.new("Motor6D")
	motor.Name = "SaberMotor"
	motor.Part0 = rightHand
	motor.Part1 = grip
	-- Pose idle : lame vers l'avant-bas depuis la main
	motor.C0 = CFrame.new(0, -0.15, -0.2) * CFrame.Angles(math.rad(-20), math.rad(90), math.rad(10))
	motor.C1 = CFrame.new()
	motor.Parent = grip

	-- === Hilt détaillé ===
	local metal = Color3.fromRGB(48, 52, 62)
	local metalBright = Color3.fromRGB(90, 98, 112)
	local wrap = Color3.fromRGB(28, 30, 38)
	local gold = Color3.fromRGB(210, 170, 90)
	local crystal = Color3.fromRGB(140, 210, 255)

	local pommel = weldPart(
		"Pommel",
		Vector3.new(0.34, 0.34, 0.34),
		CFrame.new(0, 0, 0.48),
		metalBright,
		Enum.Material.Metal,
		model,
		grip,
		Enum.PartType.Ball
	)
	pommel.Reflectance = 0.25

	weldPart("GripWrap", Vector3.new(0.26, 0.26, 0.55), CFrame.new(0, 0, 0.05), wrap, Enum.Material.Leather, model, grip)
	weldPart(
		"GripRingA",
		Vector3.new(0.32, 0.32, 0.06),
		CFrame.new(0, 0, -0.18),
		gold,
		Enum.Material.Metal,
		model,
		grip
	)
	weldPart(
		"GripRingB",
		Vector3.new(0.32, 0.32, 0.06),
		CFrame.new(0, 0, 0.28),
		gold,
		Enum.Material.Metal,
		model,
		grip
	)

	local emitter = weldPart(
		"EmitterCollar",
		Vector3.new(0.42, 0.42, 0.22),
		CFrame.new(0, 0, -0.42),
		metal,
		Enum.Material.Metal,
		model,
		grip
	)
	emitter.Reflectance = 0.35

	local chamber = weldPart(
		"CrystalChamber",
		Vector3.new(0.22, 0.22, 0.28),
		CFrame.new(0, 0, -0.22),
		crystal,
		Enum.Material.Glass,
		model,
		grip
	)
	chamber.Transparency = 0.35
	local chamberLight = Instance.new("PointLight")
	chamberLight.Name = "ChamberGlow"
	chamberLight.Color = color
	chamberLight.Brightness = 0.6
	chamberLight.Range = 4
	chamberLight.Parent = chamber

	local guardL = weldPart(
		"GuardFinL",
		Vector3.new(0.08, 0.55, 0.12),
		CFrame.new(-0.28, 0, -0.38) * CFrame.Angles(0, 0, math.rad(18)),
		metalBright,
		Enum.Material.Metal,
		model,
		grip
	)
	local guardR = weldPart(
		"GuardFinR",
		Vector3.new(0.08, 0.55, 0.12),
		CFrame.new(0.28, 0, -0.38) * CFrame.Angles(0, 0, math.rad(-18)),
		metalBright,
		Enum.Material.Metal,
		model,
		grip
	)
	guardL.Reflectance = 0.2
	guardR.Reflectance = 0.2

	-- === Hitbox lame (autorité serveur) — LookVector = +Z local = axe lame ===
	local blade = Instance.new("Part")
	blade.Name = "SaberBlade"
	blade.Size = Vector3.new(0.22, 0.22, length)
	blade.Transparency = 1 -- hitbox invisible ; Beam = visuel
	blade.CanCollide = false
	blade.Massless = true
	blade.CastShadow = false
	blade.Color = color
	blade.Material = Enum.Material.Neon
	blade.CFrame = grip.CFrame * CFrame.new(0, 0, -(0.55 + length * 0.5))
	blade.Parent = model
	local bladeWeld = Instance.new("WeldConstraint")
	bladeWeld.Part0 = grip
	bladeWeld.Part1 = blade
	bladeWeld.Parent = blade
	CollectionService:AddTag(blade, CombatConfig.Tags.SaberBlade)

	-- Core neon fin (lisible de loin)
	local core = weldPart(
		"BladeCore",
		Vector3.new(0.12, 0.12, length * 0.98),
		CFrame.new(0, 0, -(0.55 + length * 0.5)),
		color,
		Enum.Material.Neon,
		model,
		grip
	)
	core.Transparency = 0.15

	local glow = weldPart(
		"BladeGlow",
		Vector3.new(0.28, 0.28, length * 0.96),
		CFrame.new(0, 0, -(0.55 + length * 0.5)),
		color,
		Enum.Material.Neon,
		model,
		grip
	)
	glow.Transparency = 0.72

	-- Beam énergie
	local attBase = Instance.new("Attachment")
	attBase.Name = "BeamBase"
	attBase.Position = Vector3.new(0, 0, -0.55)
	attBase.Parent = grip

	local attTip = Instance.new("Attachment")
	attTip.Name = "BeamTip"
	attTip.Position = Vector3.new(0, 0, -(0.55 + length))
	attTip.Parent = grip

	local beam = Instance.new("Beam")
	beam.Name = "EnergyBeam"
	beam.Attachment0 = attBase
	beam.Attachment1 = attTip
	beam.Width0 = 0.55
	beam.Width1 = 0.22
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	beam.Parent = grip

	-- Trail combat
	local trailA = Instance.new("Attachment")
	trailA.Name = "TrailA"
	trailA.Position = Vector3.new(0, 0.08, length * 0.35)
	trailA.Parent = blade
	local trailB = Instance.new("Attachment")
	trailB.Name = "TrailB"
	trailB.Position = Vector3.new(0, -0.08, -length * 0.35)
	trailB.Parent = blade

	local trail = Instance.new("Trail")
	trail.Name = "SaberTrail"
	trail.Attachment0 = trailA
	trail.Attachment1 = trailB
	trail.Lifetime = 0.18
	trail.MinLength = 0.05
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Enabled = false
	trail.Parent = blade

	-- PointLight lame
	local light = Instance.new("PointLight")
	light.Name = "BladeLight"
	light.Color = color
	light.Brightness = 2.2
	light.Range = 14
	light.Parent = blade

	-- Clash sparks (tip)
	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "ClashTip"
	tipAtt.Position = Vector3.new(0, 0, -length * 0.48)
	tipAtt.Parent = blade

	local clash = Instance.new("ParticleEmitter")
	clash.Name = "ClashSparks"
	clash.Enabled = false
	clash.Rate = 0
	clash.Lifetime = NumberRange.new(0.15, 0.35)
	clash.Speed = NumberRange.new(8, 22)
	clash.SpreadAngle = Vector2.new(180, 180)
	clash.Drag = 4
	clash.Acceleration = Vector3.new(0, -20, 0)
	clash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	clash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	clash.Color = ColorSequence.new(Theme.Clash, Theme.Perfect)
	clash.LightEmission = 1
	clash.LightInfluence = 0
	clash.Parent = tipAtt

	stubSound(grip, "SaberHum", 0.15)
	stubSound(blade, "SaberSwing", 0.4)
	stubSound(blade, "SaberClash", 0.55)
	stubSound(blade, "SaberHit", 0.5)

	model.PrimaryPart = grip

	return {
		model = model,
		blade = blade,
		motor = motor,
		grip = grip,
		trail = trail,
		light = light,
		beam = beam,
		clashEmitter = clash,
	}
end

function SaberBuilder.setBladeColor(blade: BasePart, color: Color3)
	blade.Color = color
	local model = blade.Parent
	if not model then
		return
	end
	local core = model:FindFirstChild("BladeCore")
	if core and core:IsA("BasePart") then
		core.Color = color
	end
	local glow = model:FindFirstChild("BladeGlow")
	if glow and glow:IsA("BasePart") then
		glow.Color = color
	end
	local grip = model:FindFirstChild("HiltGrip")
	if grip then
		local beam = grip:FindFirstChild("EnergyBeam")
		if beam and beam:IsA("Beam") then
			beam.Color = ColorSequence.new(color)
		end
	end
	local light = blade:FindFirstChild("BladeLight")
	if light and light:IsA("PointLight") then
		light.Color = color
	end
	local chamber = model:FindFirstChild("CrystalChamber")
	if chamber then
		local cg = chamber:FindFirstChild("ChamberGlow")
		if cg and cg:IsA("PointLight") then
			cg.Color = color
		end
	end
	local trail = blade:FindFirstChild("SaberTrail") or blade:FindFirstChild("SaberTrailStub")
	if trail and trail:IsA("Trail") then
		trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	end
end

function SaberBuilder.setTrailEnabled(blade: BasePart, on: boolean)
	local trail = blade:FindFirstChild("SaberTrail") or blade:FindFirstChild("SaberTrailStub")
	if trail and trail:IsA("Trail") then
		trail.Enabled = on
	end
end

function SaberBuilder.burstClash(blade: BasePart, count: number?)
	local tip = blade:FindFirstChild("ClashTip")
	if not tip then
		return
	end
	local emitter = tip:FindFirstChild("ClashSparks")
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(count or 28)
	end
end

return SaberBuilder
