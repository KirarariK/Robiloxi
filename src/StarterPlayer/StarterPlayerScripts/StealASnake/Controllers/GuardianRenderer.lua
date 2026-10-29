--!strict
--[[
	GuardianRenderer — dessine et anime les Serpents Alpha côté client.

	Le serveur ne bouge qu'une Root invisible ; ici on construit un vrai serpent :
	  tête (modèle GuardianHead « head » + « lower jaw » si importé, sinon Parts) + 22 anneaux.
	Animations procédurales :
	  - Slither : le corps suit la trace de la tête, ondulation sinusoïdale proportionnelle à la vitesse ;
	  - Idle : respiration + balancement de tête ;
	  - Chase : tête dressée, gueule entrouverte ;
	  - Bite (attribut BiteAt) : recul en S (anticipation 0,2 s) puis détente avant, mâchoire grande ouverte.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BiomesConfig = require(ReplicatedStorage.StealASnake.Config.BiomesConfig)

local GuardianRenderer = {}

local SEGMENTS = 28
local SPACING = 1.6 -- distance entre anneaux (× échelle) : anneaux qui se chevauchent = corps continu

type Palette = { Body: Color3, Belly: Color3, Accent: Color3, Eye: Color3, Neon: boolean, Feature: string }

-- Apparence de chaque gardien : définie par zone dans BiomesConfig (15 gardiens différents).
local function palette(order: number): Palette
	local cfg = BiomesConfig[order] or BiomesConfig[1]
	return cfg.Guardian :: any
end

type Visual = {
	Model: Model,
	Root: BasePart,
	Folder: Folder,
	Head: Model,
	HeadPrimary: BasePart,
	Jaw: BasePart?,
	JawBase: CFrame?,
	Segments: { BasePart },
	Trail: { Vector3 },
	HeadPos: Vector3,
	HeadLook: Vector3,
	Scale: number,
	Phase: number,
	LastBite: number,
	Raise: number,
	-- corps voxel Blender (GuardianKit_<n>)
	Kit: boolean,
	Feature: string,
	Rings: { Piece },
	Attach: { Piece },
	Ground: number,
	LastState: string,
	FxAcc: number,
	HeadLight: PointLight?,
	Dust: ParticleEmitter?,
}

type Piece = {
	Parts: { BasePart },
	Offsets: { CFrame },
	Scale: number,
	Ring: number, -- anneau porteur (pièces attachées)
	Kind: string, -- Ring | Tail | Wing | Hood | Fin
	Side: number,
	Base: CFrame, -- position relative à l'anneau porteur
	Neon: { BasePart },
}

local visuals: { [Model]: Visual } = {}
local container: Folder? = nil

local function getContainer(): Folder
	if container and container.Parent then
		return container
	end
	local f = Instance.new("Folder")
	f.Name = "GuardianVisuals"
	f.Parent = Workspace
	container = f
	return f
end

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Tête du gardien : modèle voxel Blender propre à la zone (GuardianHead_<n>), sinon tête générique.
local function headTemplate(order: number): (Model?, boolean)
	local root = ReplicatedStorage:FindFirstChild("StealASnake")
	local assets = root and root:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local own = models and models:FindFirstChild("GuardianHead_" .. order)
	if own and own:IsA("Model") then
		return own, true
	end
	local m = models and models:FindFirstChild("GuardianHead")
	return if m and m:IsA("Model") then m else nil, false
end

-- Tête en Parts (repli) : crâne, museau, mâchoire articulée, yeux néon, crocs.
local function buildPartHead(s: number, pal: Palette): (Model, BasePart, BasePart)
	local head = Instance.new("Model")
	head.Name = "Head"
	local skull = newPart("Skull", Vector3.new(4.2, 2.6, 4.6) * s, pal.Body, Enum.Material.SmoothPlastic)
	skull.Parent = head
	head.PrimaryPart = skull
	local snout = newPart("Snout", Vector3.new(3.4, 1.6, 2.6) * s, pal.Body, Enum.Material.SmoothPlastic)
	snout.CFrame = CFrame.new(0, -0.3 * s, -3.2 * s)
	snout.Parent = head
	for _, x in { -1, 1 } do
		local eye = newPart("Eye", Vector3.new(0.9, 0.9, 0.9) * s, pal.Eye, Enum.Material.Neon, Enum.PartType.Ball)
		eye.CFrame = CFrame.new(x * 1.7 * s, 0.9 * s, -1.4 * s)
		eye.Parent = head
		local pupil = newPart("Pupil", Vector3.new(0.2, 0.75, 0.3) * s, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		pupil.CFrame = CFrame.new(x * 2.05 * s, 0.9 * s, -1.55 * s)
		pupil.Parent = head
		local fang = newPart("Fang", Vector3.new(0.35, 1.2, 0.35) * s, Color3.fromRGB(250, 250, 240), Enum.Material.SmoothPlastic)
		fang.CFrame = CFrame.new(x * 1.1 * s, -1.3 * s, -3.9 * s)
		fang.Parent = head
	end
	local jaw = newPart("Jaw", Vector3.new(3.2, 0.8, 4.4) * s, pal.Belly, Enum.Material.SmoothPlastic)
	jaw.CFrame = CFrame.new(0, -1.5 * s, -1.8 * s)
	jaw.Parent = head
	local tongue = newPart("Tongue", Vector3.new(0.3, 0.15, 2) * s, Color3.fromRGB(230, 40, 70), Enum.Material.SmoothPlastic)
	tongue.CFrame = CFrame.new(0, -1.05 * s, -3.6 * s)
	tongue.Parent = head
	return head, skull, jaw
end

-- Signature visuelle de chaque gardien (pièces ajoutées au modèle de tête : elles suivent la tête).
local function decorateHead(head: Model, primary: BasePart, s: number, pal: Palette)
	local base = primary.CFrame
	local f = pal.Feature
	local function add(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = newPart(name, size * s, color, material, shape)
		p.CFrame = base * cf
		p.Parent = head
		return p
	end
	local mat = if pal.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if f == "Crest" then
		for i = 0, 3 do
			add("Crest", Vector3.new(0.3, 2.4 - i * 0.4, 1.4), CFrame.new(0, (1.8 - i * 0.1) * s, (0.4 + i * 1.1) * s), pal.Accent, mat)
		end
	elseif f == "Hood" then
		local hood = add("Hood", Vector3.new(0.5, 8, 6), CFrame.new(0, -0.6 * s, 2.2 * s) * CFrame.Angles(0, math.rad(90), 0), pal.Body, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local mark = newPart("HoodMark", Vector3.new(0.55, 3.2, 2.4) * s, pal.Accent, mat, Enum.PartType.Cylinder)
		mark.CFrame = hood.CFrame * CFrame.new(-0.05 * s, 0, 0)
		mark.Parent = head
	elseif f == "Horns" or f == "Rattle" then
		for _, x in { -1, 1 } do
			add("Horn", Vector3.new(0.6, 2.6, 0.6), CFrame.new(x * 1.4 * s, 1.9 * s, 0.6 * s) * CFrame.Angles(math.rad(-25), 0, math.rad(x * -20)), pal.Accent, mat)
		end
	elseif f == "Mane" then
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			add("Mane", Vector3.new(1.4, 1.4, 1.4), CFrame.new(math.cos(a) * 2.6 * s, math.sin(a) * 2 * s, 2 * s), pal.Accent, Enum.Material.Fabric, Enum.PartType.Ball)
		end
		for _, x in { -1, 1 } do
			add("Whisker", Vector3.new(0.15, 0.15, 4.5), CFrame.new(x * 1.8 * s, -0.4 * s, -3.2 * s) * CFrame.Angles(0, math.rad(x * 25), 0), pal.Belly, Enum.Material.Neon)
		end
	elseif f == "Fins" then
		for _, x in { -1, 1 } do
			add("Fin", Vector3.new(0.2, 2.6, 2.8), CFrame.new(x * 2.3 * s, 0.4 * s, 0.8 * s) * CFrame.Angles(0, 0, math.rad(x * -60)), pal.Accent, mat)
		end
	elseif f == "Feathers" or f == "Wings" then
		local colors = { pal.Accent, pal.Belly, pal.Body }
		for i = 1, 7 do
			add("Plume", Vector3.new(0.25, 4, 0.7), CFrame.new(0, 1.8 * s, 1.6 * s) * CFrame.Angles(math.rad(-35), 0, math.rad((i - 4) * 16)) * CFrame.new(0, 1.8 * s, 0), colors[(i - 1) % 3 + 1], if f == "Wings" then Enum.Material.Neon else Enum.Material.Fabric)
		end
		if f == "Wings" then
			local halo = add("Halo", Vector3.new(0.3, 4.4, 4.4), CFrame.new(0, 3.6 * s, 0.8 * s) * CFrame.Angles(0, 0, math.rad(90)), pal.Accent, Enum.Material.Neon, Enum.PartType.Cylinder)
			halo.Transparency = 0.2
		end
	elseif f == "Crystal" or f == "Frost" then
		for i = 0, 4 do
			local p = add("Crystal", Vector3.new(0.7, 3 - i * 0.3, 0.7), CFrame.new((i - 2) * 0.8 * s, 2.2 * s, (0.4 + math.abs(i - 2) * 0.5) * s) * CFrame.Angles(math.rad(-15), 0, math.rad((i - 2) * 14)), if f == "Frost" then Color3.fromRGB(220, 245, 255) else pal.Accent, Enum.Material.Glass)
			p.Transparency = 0.15
		end
	elseif f == "Spores" then
		local cap = add("Cap", Vector3.new(4.6, 2, 4.6), CFrame.new(0, 2.1 * s, 0.6 * s), pal.Accent, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local dot = newPart("CapDot", Vector3.new(0.7, 0.4, 0.7) * s, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			dot.CFrame = cap.CFrame * CFrame.new(math.cos(a) * 1.4 * s, 0.75 * s, math.sin(a) * 1.4 * s)
			dot.Parent = head
		end
	elseif f == "Fire" then
		local fire = Instance.new("Fire")
		fire.Size = 6 * s
		fire.Heat = 9
		fire.Color = pal.Accent
		fire.SecondaryColor = Color3.fromRGB(255, 50, 10)
		fire.Parent = primary
	elseif f == "Ghost" then
		for _, d in head:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = math.max(d.Transparency, 0.35)
			end
		end
	elseif f == "Radioactive" or f == "Toxic" then
		for _, x in { -1, 1 } do
			add("Pustule", Vector3.new(1, 1, 1), CFrame.new(x * 1.6 * s, 1.2 * s, 0.8 * s), pal.Accent, Enum.Material.Neon, Enum.PartType.Ball)
		end
	elseif f == "Rainbow" then
		for i = 0, 5 do
			local ring = add("StarRing", Vector3.new(0.25, 6 + i * 0.6, 6 + i * 0.6), CFrame.new(0, 0.5 * s, 1 * s) * CFrame.Angles(math.rad(i * 30), 0, math.rad(90)), Color3.fromHSV(i / 6, 0.8, 1), Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.Transparency = 0.45
		end
	end
	if pal.Neon then
		local l = Instance.new("PointLight")
		l.Color = pal.Accent
		l.Range = 18
		l.Brightness = 2
		l.Parent = primary
	end
end

-- Couleur / matière d'un anneau selon la signature du gardien.
local function segmentLook(pal: Palette, i: number, n: number): (Color3, Enum.Material, number)
	local f = pal.Feature
	if f == "Rainbow" then
		return Color3.fromHSV((i / n) % 1, 0.75, 1), Enum.Material.Neon, 0
	elseif f == "Ghost" then
		return if i % 3 == 0 then pal.Accent else pal.Body, if i % 3 == 0 then Enum.Material.Neon else Enum.Material.Glass, 0.45
	elseif f == "Crystal" or f == "Frost" then
		return if i % 3 == 0 then pal.Accent else pal.Body, Enum.Material.Glass, 0.1
	elseif f == "Radioactive" then
		return if i % 2 == 0 then pal.Accent else pal.Body, if i % 2 == 0 then Enum.Material.Neon else Enum.Material.Slate, 0
	end
	local accent = i % 3 == 0
	return if accent then pal.Accent else pal.Body, if pal.Neon and accent then Enum.Material.Neon else Enum.Material.SmoothPlastic, 0
end

--[[ ───────────── Corps voxel (kit Blender) ───────────── ]]
local KIT_RINGS = 16
local KIT_SPACING = 2.3 -- × échelle : les anneaux (3,5 de long) se chevauchent

local function kitTemplate(order: number): Model?
	local root = ReplicatedStorage:FindFirstChild("StealASnake")
	local assets = root and root:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local kit = models and models:FindFirstChild("GuardianKit_" .. order)
	return if kit and kit:IsA("Model") then kit else nil
end

local function clonePiece(tpl: Model, scale: number, folder: Instance, kind: string, ring: number, base: CFrame): Piece
	local m = tpl:Clone()
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new())
	local parts, offsets, neon = {}, {}, {}
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offsets, d.CFrame)
			if d.Material == Enum.Material.Neon then
				table.insert(neon, d)
			end
			d.Parent = folder
		end
	end
	m:Destroy()
	return {
		Parts = parts,
		Offsets = offsets,
		Scale = scale,
		Ring = ring,
		Kind = kind,
		Side = (tpl:GetAttribute("Side") :: number?) or 1,
		Base = base,
		Neon = neon,
	}
end

-- Effets de zone portés par le corps (particules douces, budget faible)
local FX: { [string]: { Texture: string, Color: Color3, Color2: Color3?, Rate: number, Speed: number, Size: number, Life: number, Light: boolean? } } = {
	Crest = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(140, 230, 90), Rate = 3, Speed = 2, Size = 0.6, Life = 1.6 },
	Hood = { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = Color3.fromRGB(230, 200, 140), Rate = 4, Speed = 1, Size = 2.4, Life = 1.4 },
	Toxic = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(150, 70, 200), Color2 = Color3.fromRGB(150, 255, 60), Rate = 5, Speed = 3, Size = 0.8, Life = 1.2, Light = true },
	Frost = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(220, 245, 255), Rate = 6, Speed = 2, Size = 0.7, Life = 2, Light = true },
	Mane = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(255, 120, 120), Color2 = Color3.fromRGB(255, 220, 80), Rate = 3, Speed = 2, Size = 0.7, Life = 1.6 },
	Rattle = { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = Color3.fromRGB(200, 140, 90), Rate = 4, Speed = 1, Size = 2.4, Life = 1.4 },
	Spores = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(255, 120, 200), Color2 = Color3.fromRGB(120, 255, 200), Rate = 7, Speed = 1.5, Size = 0.9, Life = 2.6, Light = true },
	Fins = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(200, 240, 255), Rate = 5, Speed = 3, Size = 0.6, Life = 1.8 },
	Fire = { Texture = "rbxasset://textures/particles/fire_main.dds", Color = Color3.fromRGB(255, 160, 40), Color2 = Color3.fromRGB(255, 60, 10), Rate = 10, Speed = 4, Size = 1.4, Life = 0.9, Light = true },
	Crystal = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(230, 160, 255), Color2 = Color3.fromRGB(140, 230, 255), Rate = 6, Speed = 2, Size = 0.8, Life = 1.5, Light = true },
	Ghost = { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = Color3.fromRGB(140, 255, 200), Rate = 5, Speed = 1.5, Size = 2.2, Life = 2, Light = true },
	Feathers = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(255, 220, 80), Color2 = Color3.fromRGB(230, 60, 60), Rate = 4, Speed = 2, Size = 0.8, Life = 1.8 },
	Radioactive = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(190, 255, 40), Rate = 8, Speed = 3, Size = 0.9, Life = 1.2, Light = true },
	Wings = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(255, 230, 140), Color2 = Color3.fromRGB(255, 255, 255), Rate = 6, Speed = 1.5, Size = 0.9, Life = 2, Light = true },
	Rainbow = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(170, 110, 255), Color2 = Color3.fromRGB(120, 255, 255), Rate = 8, Speed = 2, Size = 1, Life = 2.2, Light = true },
}

local function addFx(part: BasePart, f: string, s: number, rateMult: number)
	local fx = FX[f]
	if not fx then
		return
	end
	local a = Instance.new("Attachment")
	a.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Texture = fx.Texture
	e.Color = if fx.Color2 then ColorSequence.new(fx.Color, fx.Color2) else ColorSequence.new(fx.Color)
	e.LightEmission = if fx.Light then 0.8 else 0.1
	e.Rate = fx.Rate * rateMult
	e.Speed = NumberRange.new(fx.Speed * 0.5, fx.Speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(fx.Life * 0.6, fx.Life)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, fx.Size * s), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Acceleration = if f == "Fire" or f == "Ghost" or f == "Spores" then Vector3.new(0, 3, 0) else Vector3.new(0, -1, 0)
	e.Parent = a
	if f == "Fire" then
		local fire = Instance.new("Fire")
		fire.Size = 3 * s
		fire.Heat = 6
		fire.Color = fx.Color
		fire.SecondaryColor = fx.Color2 or fx.Color
		fire.Parent = part
	end
end

local function buildKitBody(v: any, kit: Model, folder: Folder, s: number, f: string)
	local rings: { Piece } = {}
	local body = kit:FindFirstChild("Body") :: Model
	local alt = (kit:FindFirstChild("BodyAlt") or body) :: Model
	for i = 1, KIT_RINGS do
		local t = (i - 1) / (KIT_RINGS - 1)
		local rs = s * (1.05 - 0.55 * t ^ 1.25)
		local tpl = if i % 3 == 0 then alt else body
		table.insert(rings, clonePiece(tpl, rs, folder, "Ring", i, CFrame.new()))
	end
	local attach: { Piece } = {}
	local tail = kit:FindFirstChild("Tail")
	if tail and tail:IsA("Model") then
		local last = rings[#rings]
		table.insert(attach, clonePiece(tail, last.Scale, folder, "Tail", #rings, CFrame.new(0, 0, 1.2 * last.Scale)))
	end
	for _, c in kit:GetChildren() do
		if c:IsA("Model") then
			local kind = if string.find(c.Name, "^Wing") then "Wing" elseif string.find(c.Name, "^Hood") then "Hood" elseif string.find(c.Name, "^Fin") then "Fin" else nil
			if kind then
				local side = (c:GetAttribute("Side") :: number?) or 1
				local ringIdx = if kind == "Hood" then 1 elseif kind == "Wing" then 3 else 4
				local r = rings[ringIdx]
				local base = if kind == "Hood" then CFrame.new(side * 0.9 * r.Scale, 0.3 * r.Scale, -0.6 * r.Scale)
					elseif kind == "Wing" then CFrame.new(side * 1.4 * r.Scale, 1.2 * r.Scale, 0)
					else CFrame.new(side * 1.8 * r.Scale, -0.2 * r.Scale, 0)
				local pc = clonePiece(c, if kind == "Wing" then r.Scale * 1.25 else r.Scale, folder, kind, ringIdx, base)
				pc.Side = side
				table.insert(attach, pc)
			end
		end
	end
	-- effets portés : quelques anneaux + queue
	for _, idx in { 2, 7, 12 } do
		local r = rings[idx]
		if r and r.Parts[1] then
			addFx(r.Parts[1], f, s, if idx == 2 then 1 else 0.6)
		end
	end
	-- poussière au sol pendant la poursuite
	local dustA = Instance.new("Attachment")
	dustA.Parent = rings[5].Parts[1]
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(190, 170, 140))
	dust.Rate = 0
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(70, 20)
	dust.Lifetime = NumberRange.new(0.6, 1.1)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * s), NumberSequenceKeypoint.new(1, 4 * s) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Parent = dustA
	v.Rings = rings
	v.Attach = attach
	v.Dust = dust
end

-- Onde de choc au début d'une poursuite (rugissement visuel)
local function roarRing(pos: Vector3, color: Color3, s: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.3, 4 * s, 4 * s)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = getContainer()
	local TweenService = game:GetService("TweenService")
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = Vector3.new(0.3, 46 * s, 46 * s), Transparency = 1 }):Play()
	task.delay(0.75, function()
		ring:Destroy()
	end)
end

local function build(model: Model)
	local root = model:WaitForChild("Root", 5)
	if not root or not root:IsA("BasePart") then
		return
	end
	local order = (model:GetAttribute("Order") :: number?) or 1
	local s = (model:GetAttribute("Scale") :: number?) or 1
	local pal = palette(order)

	local folder = Instance.new("Folder")
	folder.Name = model.Name
	folder.Parent = getContainer()

	-- Tête
	local head: Model
	local primary: BasePart
	local jaw: BasePart? = nil
	local tpl, ownHead = headTemplate(order)
	if tpl then
		head = tpl:Clone()
		head:ScaleTo(head:GetScale() * s * 1.15)
		for _, d in head:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				if string.find(string.lower(d.Name), "jaw") then
					jaw = d
				end
			end
		end
		primary = head.PrimaryPart or head:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		if not ownHead or not head.PrimaryPart then
			for _, d in head:GetDescendants() do
				if d:IsA("BasePart") and d ~= jaw then
					primary = d
					break
				end
			end
			head.PrimaryPart = primary
		end
		-- Le modèle est vert : on le teinte aux couleurs de la zone (garde les détails de texture)
		if order > 1 and not ownHead then
			local tint = Instance.new("Highlight")
			tint.FillColor = pal.Body
			tint.FillTransparency = 0.4
			tint.OutlineColor = pal.Accent
			tint.OutlineTransparency = 0.3
			tint.DepthMode = Enum.HighlightDepthMode.Occluded
			tint.Parent = head
		end
	else
		local skull
		head, skull, jaw = buildPartHead(s, pal)
		primary = skull
	end
	if ownHead then
		-- la tête voxel porte déjà sa signature : on n'ajoute que lumière / feu
		if pal.Neon then
			local l = Instance.new("PointLight")
			l.Color = pal.Accent
			l.Range = 18
			l.Brightness = 2
			l.Parent = primary
		end
		if pal.Feature == "Fire" then
			local fire = Instance.new("Fire")
			fire.Size = 6 * s
			fire.Heat = 9
			fire.Color = pal.Accent
			fire.SecondaryColor = Color3.fromRGB(255, 50, 10)
			fire.Parent = primary
		end
	else
		decorateHead(head, primary, s, pal)
	end
	head.Parent = folder
	-- jaw relatif au crâne (pour l'ouvrir autour de la charnière)
	local jawBase: CFrame? = if jaw then primary.CFrame:ToObjectSpace(jaw.CFrame) else nil

	-- Corps : kit voxel Blender si présent, sinon anneaux en Parts
	local kitTpl = kitTemplate(order)
	local kitData: any = {}
	if kitTpl then
		buildKitBody(kitData, kitTpl, folder, s, pal.Feature)
	end
	local segments: { BasePart } = {}
	for i = 1, if kitTpl then 0 else SEGMENTS do
		local t = i / SEGMENTS
		local r = (3.6 - 2.6 * t ^ 1.3) * s
		local color, material, transparency = segmentLook(pal, i, SEGMENTS)
		local seg = newPart("Seg" .. i, Vector3.new(r, r * 0.9, r * 1.25), color, material, Enum.PartType.Ball)
		seg.Transparency = transparency
		seg.Parent = folder
		table.insert(segments, seg)
		local f = pal.Feature
		if i % 4 == 2 then
			local spikeMat = if f == "Crystal" or f == "Frost" then Enum.Material.Glass elseif pal.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local spikeSize = if f == "Crystal" then Vector3.new(0.9, 2.4, 0.9) elseif f == "Fins" or f == "Crest" then Vector3.new(0.25, 1.8, 1.6) else Vector3.new(0.5, 1.2, 0.5)
			local spike = newPart("Spike", spikeSize * s * (1 - t * 0.6), if f == "Frost" then Color3.fromRGB(220, 245, 255) else pal.Accent, spikeMat)
			spike:SetAttribute("Follow", i)
			spike.Parent = folder
			if f == "Fire" and i % 8 == 2 then
				local fire = Instance.new("Fire")
				fire.Size = 3 * s
				fire.Heat = 5
				fire.Color = pal.Accent
				fire.SecondaryColor = Color3.fromRGB(255, 50, 10)
				fire.Parent = spike
			elseif f == "Spores" then
				spike.Shape = Enum.PartType.Ball
				spike.Size = Vector3.new(1.6, 0.8, 1.6) * s * (1 - t * 0.5)
				spike.Color = if i % 8 == 2 then pal.Accent else Color3.new(1, 1, 1)
			end
		end
		if f == "Rattle" and i == SEGMENTS then
			for k = 1, 3 do
				local rattle = newPart("Rattle", Vector3.new(1.1, 0.9, 0.8) * s, Color3.fromRGB(225, 200, 150), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
				rattle:SetAttribute("Follow", i)
				rattle:SetAttribute("FollowOffset", CFrame.new(0, 0, (0.4 + k * 0.55) * s))
				rattle.Parent = folder
			end
		end
	end

	local start = root.Position
	local trail = {}
	for i = 0, SEGMENTS + 2 do
		table.insert(trail, start + Vector3.new(0, 0, i * SPACING * s))
	end
	local headLight: PointLight? = primary:FindFirstChildOfClass("PointLight")
	if not headLight then
		local l = Instance.new("PointLight")
		l.Color = pal.Eye
		l.Range = 14 * s
		l.Brightness = 1
		l.Parent = primary
		headLight = l
	end

	visuals[model] = {
		Model = model,
		Root = root,
		Folder = folder,
		Head = head,
		HeadPrimary = primary,
		Jaw = jaw,
		JawBase = jawBase,
		Segments = segments,
		Trail = trail,
		HeadPos = start,
		HeadLook = Vector3.new(0, 0, -1),
		Scale = s,
		Phase = math.random() * 10,
		LastBite = (model:GetAttribute("BiteAt") :: number?) or 0,
		Raise = 0,
		Kit = kitTpl ~= nil,
		Feature = pal.Feature,
		Rings = kitData.Rings or {},
		Attach = kitData.Attach or {},
		Ground = root.Position.Y - 3,
		LastState = "PATROL",
		FxAcc = 0,
		HeadLight = headLight,
		Dust = kitData.Dust,
	}
end

local function destroy(model: Model)
	local v = visuals[model]
	if v then
		v.Folder:Destroy()
		visuals[model] = nil
	end
end

-- Point à la distance `d` le long de la trace (polyline), depuis la tête.
local function sampleTrail(trail: { Vector3 }, d: number): (Vector3, Vector3)
	local acc = 0
	for i = 1, #trail - 1 do
		local a, b = trail[i], trail[i + 1]
		local seg = (b - a).Magnitude
		if acc + seg >= d and seg > 1e-4 then
			local p = a:Lerp(b, (d - acc) / seg)
			return p, (a - b).Unit
		end
		acc += seg
	end
	local last = trail[#trail]
	local prev = trail[#trail - 1] or last + Vector3.new(0, 0, 1)
	local dir = last - prev
	return last, if dir.Magnitude > 1e-4 then -dir.Unit else Vector3.new(0, 0, -1)
end

local function step(v: Visual, dt: number, now: number)
	local model = v.Model
	local s = v.Scale
	local state = model:GetAttribute("State")
	local speed = (model:GetAttribute("Speed") :: number?) or 0
	v.Phase += dt * (2 + speed * 0.25)

	-- Lissage de la tête vers la Root serveur
	local target = v.Root.Position
	local alpha = 1 - math.exp(-12 * dt)
	local newPos = v.HeadPos:Lerp(target, alpha)
	local moved = newPos - v.HeadPos
	if Vector3.new(moved.X, 0, moved.Z).Magnitude > 0.02 then
		v.HeadLook = v.HeadLook:Lerp(Vector3.new(moved.X, 0, moved.Z).Unit, 1 - math.exp(-8 * dt))
	else
		local rl = v.Root.CFrame.LookVector
		v.HeadLook = v.HeadLook:Lerp(Vector3.new(rl.X, 0, rl.Z), 1 - math.exp(-3 * dt))
	end
	if v.HeadLook.Magnitude < 1e-3 then
		v.HeadLook = Vector3.new(0, 0, -1)
	end
	v.HeadLook = v.HeadLook.Unit
	v.HeadPos = newPos

	-- Trace : Trail[1] suit la tête en direct ; on fige un point dès qu'elle s'est assez éloignée de Trail[2]
	v.Trail[1] = newPos
	if (v.Trail[1] - v.Trail[2]).Magnitude > SPACING * s * 0.35 then
		table.insert(v.Trail, 1, newPos)
		local maxPts = SEGMENTS * 3 + 6
		while #v.Trail > maxPts do
			table.remove(v.Trail)
		end
	end

	-- Posture : tête dressée en chasse / attaque
	local raiseTarget = if state == "CHASE" or state == "ATTACK" then 3.2 else 1.2 + math.sin(now * 1.3 + v.Phase) * 0.3
	v.Raise += (raiseTarget - v.Raise) * (1 - math.exp(-5 * dt))

	-- Morsure : anticipation (recul) puis détente
	local biteAt = (model:GetAttribute("BiteAt") :: number?) or 0
	local serverNow = Workspace:GetServerTimeNow()
	local bt = serverNow - biteAt
	local lunge = 0
	local jawOpen = if state == "CHASE" then 0.35 + math.sin(now * 6) * 0.08 else 0.05
	if biteAt > 0 and bt >= 0 and bt < 0.9 then
		if bt < 0.22 then
			lunge = -2.2 * (bt / 0.22) -- recul en S
			jawOpen = 0.6 + 0.4 * (bt / 0.22)
		elseif bt < 0.4 then
			local k = (bt - 0.22) / 0.18
			lunge = -2.2 + 7 * k -- détente brutale
			jawOpen = 1
		else
			local k = math.clamp((bt - 0.4) / 0.5, 0, 1)
			lunge = 4.8 * (1 - k)
			jawOpen = 1 - k * 0.9
		end
	end

	local headPos = v.HeadPos + v.HeadLook * lunge * s + Vector3.new(0, v.Raise * s + 1.5 * s, 0)
	if v.Kit then
		headPos = Vector3.new(headPos.X, v.Ground + (2.6 + v.Raise) * s, headPos.Z)
	end
	local sway = math.sin(v.Phase * 1.2) * 0.12
	local headCf = CFrame.lookAt(headPos, headPos + v.HeadLook) * CFrame.Angles(0, sway, 0)
	v.Head:PivotTo(headCf)
	if v.Jaw and v.JawBase then
		-- charnière à l'arrière de la mâchoire
		local hinge = CFrame.new(0, 0, (v.Jaw.Size.Z * 0.45))
		v.Jaw.CFrame = v.HeadPrimary.CFrame * v.JawBase * hinge * CFrame.Angles(math.rad(-38 * jawOpen), 0, 0) * hinge:Inverse()
	end

	-- Corps voxel (kit Blender) : anneaux qui suivent la trace + pièces animées, déplacés en un seul BulkMoveTo
	if v.Kit then
		local chase = state == "CHASE" or state == "ATTACK"
		if chase and v.LastState ~= "CHASE" and v.LastState ~= "ATTACK" then
			roarRing(Vector3.new(headPos.X, v.Ground + 0.4, headPos.Z), if v.HeadLight then v.HeadLight.Color else Color3.new(1, 0.3, 0.3), s)
		end
		v.LastState = state :: string
		local av = v :: any
		av.HoodOpen = (av.HoodOpen or 0) + ((if chase then 1 else 0) - (av.HoodOpen or 0)) * (1 - math.exp(-6 * dt))
		local kamp = math.clamp(speed / 20, 0.15, 1) * 1.3 * s
		local parts: { BasePart } = {}
		local cfs: { CFrame } = {}
		local ringCf: { CFrame } = {}
		local prevPos = headPos
		for i, r in v.Rings do
			local d = (i - 0.3) * KIT_SPACING * s
			local p, back = sampleTrail(v.Trail, d)
			local lateral = back:Cross(Vector3.yAxis)
			local wave = math.sin(v.Phase * 2.2 - i * 0.7) * kamp * math.clamp(i / 3, 0.2, 1)
			local neckLift = math.max(0, 1 - i / 4) * (v.Raise + 0.8) * s
			local breathe = math.sin(now * 2 + i * 0.5) * 0.06 * r.Scale
			local pos = Vector3.new(p.X, v.Ground + 1.76 * r.Scale + neckLift + breathe, p.Z) + lateral * wave
			local dir = prevPos - pos
			local cf = if dir.Magnitude > 1e-3 then CFrame.lookAt(pos, prevPos) else CFrame.new(pos)
			ringCf[i] = cf
			prevPos = pos
			for k, part in r.Parts do
				table.insert(parts, part)
				table.insert(cfs, cf * r.Offsets[k])
			end
		end
		for _, a in v.Attach do
			local rc = ringCf[a.Ring]
			if rc then
				local anim = CFrame.identity
				if a.Kind == "Tail" then
					local shake = if v.Feature == "Rattle" then (if chase then 0.35 else 0.12) else 0.15
					anim = CFrame.Angles(0, math.sin(now * (if chase and v.Feature == "Rattle" then 22 else 2.5)) * shake, 0)
				elseif a.Kind == "Wing" then
					local amp = if chase then 34 else 20
					local freq = if chase then 9 else 2.6
					anim = CFrame.Angles(0, 0, a.Side * math.rad(12 + math.sin(now * freq) * amp))
				elseif a.Kind == "Hood" then
					local k = av.HoodOpen
					anim = CFrame.Angles(0, -a.Side * math.rad(80) * (1 - k), 0) * CFrame.Angles(0, 0, a.Side * math.rad(10 * k))
				elseif a.Kind == "Fin" then
					anim = CFrame.Angles(0, 0, a.Side * math.sin(now * 4 + a.Side) * 0.45)
				end
				local cf = rc * a.Base * anim
				for k, part in a.Parts do
					table.insert(parts, part)
					table.insert(cfs, cf * a.Offsets[k])
				end
			end
		end
		Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		-- effets : lueur des yeux qui pulse en chasse, poussière au sol, néons arc-en-ciel
		if v.HeadLight then
			v.HeadLight.Brightness = if chase then 2.5 + math.sin(now * 10) else 0.8 + math.sin(now * 2) * 0.2
		end
		if v.Dust then
			v.Dust.Rate = if chase and speed > 4 then 26 else 0
		end
		v.FxAcc += dt
		if v.FxAcc > 0.08 then
			v.FxAcc = 0
			if v.Feature == "Rainbow" then
				for i, r in v.Rings do
					for _, n in r.Neon do
						n.Color = Color3.fromHSV((now * 0.15 + i / #v.Rings) % 1, 0.7, 1)
					end
				end
			elseif v.Feature == "Ghost" then
				for i, r in v.Rings do
					for _, part in r.Parts do
						if part.Material == Enum.Material.Glass then
							part.Transparency = 0.35 + math.sin(now * 3 + i * 0.6) * 0.2
						end
					end
				end
			end
		end
		return
	end

	-- Corps : suit la trace, ondule latéralement (plus fort quand il avance), le cou remonte vers la tête
	local amp = math.clamp(speed / 20, 0.15, 1) * 1.6 * s
	for i, seg in v.Segments do
		local d = i * SPACING * s
		local p, back = sampleTrail(v.Trail, d)
		local lateral = back:Cross(Vector3.yAxis)
		local wave = math.sin(v.Phase * 2.2 - i * 0.55) * amp * math.clamp(i / 4, 0.2, 1)
		local neckLift = math.max(0, 1 - i / 5) * (v.Raise * s + 1.5 * s)
		local breathe = math.sin(now * 2 + i * 0.4) * 0.08 * s
		local pos = p + lateral * wave + Vector3.new(0, seg.Size.Y * 0.45 + neckLift + breathe, 0)
		seg.CFrame = CFrame.lookAt(pos, pos - back)
	end
	for _, c in v.Folder:GetChildren() do
		local idx = c:GetAttribute("Follow")
		if typeof(idx) == "number" and c:IsA("BasePart") then
			local seg = v.Segments[idx]
			if seg then
				local off = c:GetAttribute("FollowOffset")
				c.CFrame = if typeof(off) == "CFrame" then seg.CFrame * off else seg.CFrame * CFrame.new(0, seg.Size.Y * 0.5, 0) * CFrame.Angles(math.rad(-20), 0, 0)
			end
		end
	end
end

function GuardianRenderer.start()
	local function watch(folder: Instance)
		for _, m in folder:GetChildren() do
			if m:IsA("Model") then
				task.spawn(build, m)
			end
		end
		folder.ChildAdded:Connect(function(m)
			if m:IsA("Model") then
				task.spawn(build, m)
			end
		end)
		folder.ChildRemoved:Connect(function(m)
			if m:IsA("Model") then
				destroy(m)
			end
		end)
	end
	local existing = Workspace:FindFirstChild("Guardians")
	if existing then
		watch(existing)
	else
		task.spawn(function()
			watch(Workspace:WaitForChild("Guardians"))
		end)
	end

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local cam = Workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		for model, v in visuals do
			if not model.Parent or not v.Root.Parent then
				destroy(model)
			elseif (v.Root.Position - camPos).Magnitude < 420 then
				step(v, math.min(dt, 0.1), now)
			end
		end
	end)
end

return GuardianRenderer
