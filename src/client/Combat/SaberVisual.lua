--!strict
-- SaberVisual : construction et animation des lames d'Éther (côté client uniquement, rien n'est répliqué).
--   build(weapon, colorId) -> Model : poignée(s) + lame(s) allumées (aperçu de l'Atelier, UI).
--   attach(character, weapon, colorId) -> Saber : lames soudées aux mains R15 / R6 d'un combattant,
--     allumage / extinction animés, halo, PointLight, traînée, faisceau, bourdonnement et sons de swing,
--     effets des cristaux mythiques (DarkCore, Unstable, InkCore, Prism, Nebula via SaberColors.glowAt).
-- Poignées : ReplicatedStorage.EtherBladesAssets.Hilts.Hilt_Single / Hilt_Staff si présentes
-- (PrimaryPart « Grip », axe +Y = lame, Attachments BladeStart / BladeStart2), sinon poignée procédurale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local SaberColors = require(Shared.Config.SaberColors)
local Config = require(Shared.Combat.CombatConfig)
local Maid = require(Shared.Util.Maid)

type SaberColorDef = Types.SaberColorDef

local BC = Config.Blade

export type Blade = {
	Grip: BasePart,
	Core: BasePart,
	Glow: BasePart,
	Weld: Weld,
	GlowWeld: Weld,
	Base: Attachment,
	Tip: Attachment,
	Trail: Trail,
	Beam: Beam,
	Light: PointLight,
	Particles: ParticleEmitter?,
	Emit: CFrame, -- émetteur dans le repère de la poignée (+Y = direction de la lame)
	Length: number,
	GlowTransparency: number,
	LastTip: Vector3,
	TrailOn: boolean,
}

export type Saber = {
	Model: Model,
	Weapon: string,
	ColorId: string,
	Def: SaberColorDef,
	Blades: { Blade },
	Grips: { BasePart },
	Rings: { BasePart }, -- anneaux lumineux des émetteurs
	Extend: number,
	Target: number,
	Hum: Sound,
	Swing: Sound,
	Ignite: Sound,
	LastSwing: number,
	EffectClock: number,
	Destroyed: boolean,
	Maid: Maid.Maid,
	setOn: (self: Saber, on: boolean, instant: boolean?) -> (),
	isOn: (self: Saber) -> boolean,
	destroy: (self: Saber) -> (),
}

local SaberVisual = {}

local HALF_PI = math.pi / 2
local CYL = CFrame.Angles(0, 0, HALF_PI) -- l'axe d'un cylindre Roblox est X : on le couche sur Y
local FLIP = CFrame.Angles(math.pi, 0, 0)
local TO_HAND = CFrame.Angles(-HALF_PI, 0, 0) -- +Y de la poignée → -Z de la main (vers l'avant)

local METAL_DARK = Color3.fromRGB(58, 60, 68)
local METAL_LIGHT = Color3.fromRGB(176, 180, 190)
local WRAP = Color3.fromRGB(22, 22, 26)
local ACCENT = Color3.fromRGB(150, 40, 40)

local active: { Saber } = {}
local rng = Random.new()

--------------------------------------------------------------------------------
-- Pièces

local function decorate(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function part(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material
	decorate(p)
	p.Parent = parent
	return p
end

local function weld(p0: BasePart, p1: BasePart, c0: CFrame): Weld
	local w = Instance.new("Weld")
	w.Part0 = p0
	w.Part1 = p1
	w.C0 = c0
	w.C1 = CFrame.identity
	w.Parent = p1
	return w
end

-- Cylindre décoratif le long de l'axe Y de la poignée, centré en `y`.
local function ring(grip: BasePart, model: Model, name: string, y: number, len: number, diam: number, color: Color3, material: Enum.Material)
	local p = part(name, Enum.PartType.Cylinder, Vector3.new(len, diam, diam), color, material, model)
	p.CFrame = grip.CFrame * CFrame.new(0, y, 0) * CYL
	weld(grip, p, CFrame.new(0, y, 0) * CYL)
end

--------------------------------------------------------------------------------
-- Poignées

type Hilt = { Model: Model, Grip: BasePart, Emitters: { CFrame } }

local function assetHilt(name: string): Hilt?
	local assets = ReplicatedStorage:FindFirstChild("EtherBladesAssets")
	local hilts = assets and assets:FindFirstChild("Hilts")
	local src = hilts and hilts:FindFirstChild(name)
	if not (src and src:IsA("Model")) then
		return nil
	end
	local model = src:Clone()
	local gripInst = model.PrimaryPart or model:FindFirstChild("Grip", true)
	if not (gripInst and gripInst:IsA("BasePart")) then
		model:Destroy()
		return nil
	end
	local grip = gripInst :: BasePart
	model.PrimaryPart = grip
	-- pièces déjà soudées dans l'asset (GetJoints ne marche pas hors Workspace)
	local welded: { [BasePart]: boolean } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D") then
			local j = d :: any
			if j.Part0 then
				welded[j.Part0] = true
			end
			if j.Part1 then
				welded[j.Part1] = true
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			decorate(d)
			if d ~= grip and not welded[d] then
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = grip
				wc.Part1 = d
				wc.Parent = d
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local emitters: { CFrame } = {}
	for i, attName in { "BladeStart", "BladeStart2" } do
		local att = model:FindFirstChild(attName, true)
		if att and att:IsA("Attachment") then
			local rel = grip.CFrame:PointToObjectSpace(att.WorldPosition)
			table.insert(emitters, CFrame.new(rel) * (if i == 2 then FLIP else CFrame.identity))
		end
	end
	if #emitters == 0 then
		table.insert(emitters, CFrame.new(0, grip.Size.Y * 0.5, 0))
	end
	return { Model = model, Grip = grip, Emitters = emitters }
end

local function proceduralSingle(def: SaberColorDef): Hilt
	local model = Instance.new("Model")
	model.Name = "Hilt_Single"
	local grip = part("Grip", Enum.PartType.Block, Vector3.new(0.22, 1.1, 0.22), METAL_DARK, Enum.Material.Metal, model)
	grip.Transparency = 1
	model.PrimaryPart = grip
	ring(grip, model, "Body", 0, 1.1, 0.24, METAL_DARK, Enum.Material.Metal)
	ring(grip, model, "Wrap", -0.14, 0.56, 0.27, WRAP, Enum.Material.Fabric)
	ring(grip, model, "Shroud", 0.47, 0.22, 0.32, METAL_LIGHT, Enum.Material.Metal)
	ring(grip, model, "EmitterGlow", 0.6, 0.04, 0.2, def.Glow, Enum.Material.Neon)
	ring(grip, model, "Pommel", -0.58, 0.12, 0.3, METAL_LIGHT, Enum.Material.Metal)
	local btn = part("Switch", Enum.PartType.Block, Vector3.new(0.07, 0.12, 0.07), ACCENT, Enum.Material.SmoothPlastic, model)
	btn.CFrame = grip.CFrame * CFrame.new(0.13, 0.2, 0)
	weld(grip, btn, CFrame.new(0.13, 0.2, 0))
	return { Model = model, Grip = grip, Emitters = { CFrame.new(0, 0.62, 0) } }
end

local function proceduralStaff(def: SaberColorDef): Hilt
	local model = Instance.new("Model")
	model.Name = "Hilt_Staff"
	local grip = part("Grip", Enum.PartType.Block, Vector3.new(0.22, 2.4, 0.22), METAL_DARK, Enum.Material.Metal, model)
	grip.Transparency = 1
	model.PrimaryPart = grip
	ring(grip, model, "Body", 0, 2.4, 0.25, METAL_DARK, Enum.Material.Metal)
	ring(grip, model, "Center", 0, 0.3, 0.3, METAL_LIGHT, Enum.Material.Metal)
	for _, s in { 1, -1 } do
		ring(grip, model, "Wrap", 0.55 * s, 0.5, 0.28, WRAP, Enum.Material.Fabric)
		ring(grip, model, "Shroud", 1.08 * s, 0.24, 0.33, METAL_LIGHT, Enum.Material.Metal)
		ring(grip, model, "EmitterGlow", 1.22 * s, 0.04, 0.2, def.Glow, Enum.Material.Neon)
	end
	return { Model = model, Grip = grip, Emitters = { CFrame.new(0, 1.24, 0), CFrame.new(0, -1.24, 0) * FLIP } }
end

local function makeHilt(staff: boolean, def: SaberColorDef): Hilt
	local h = assetHilt(if staff then "Hilt_Staff" else "Hilt_Single")
	if h then
		return h
	end
	return if staff then proceduralStaff(def) else proceduralSingle(def)
end

--------------------------------------------------------------------------------
-- Lames

local function seq(c: Color3): ColorSequence
	return ColorSequence.new(c)
end

local function isDark(def: SaberColorDef): boolean
	return def.Effect == "DarkCore" or def.Effect == "InkCore"
end

local function addBlade(hilt: Hilt, emit: CFrame, length: number, def: SaberColorDef): Blade
	local grip = hilt.Grip
	local model = hilt.Model
	local glowColor = SaberColors.glowAt(def, os.clock())
	local core = part("Core", Enum.PartType.Cylinder, Vector3.new(length, BC.CoreWidth, BC.CoreWidth), def.Core, if isDark(def) then Enum.Material.SmoothPlastic else Enum.Material.Neon, model)
	local rel = emit * CFrame.new(0, length * 0.5, 0) * CYL
	core.CFrame = grip.CFrame * rel
	local w = weld(grip, core, rel)
	local glowWidth = if def.Effect == "DarkCore" then BC.GlowWidth * 0.8 else BC.GlowWidth
	local glow = part("Glow", Enum.PartType.Cylinder, Vector3.new(length + 0.08, glowWidth, glowWidth), glowColor, Enum.Material.Neon, model)
	local glowT = if def.Effect == "DarkCore" then 0.7 else BC.GlowTransparency
	glow.Transparency = glowT
	glow.CFrame = core.CFrame
	local gw = weld(core, glow, CFrame.identity)

	local base = Instance.new("Attachment")
	base.Name = "BladeBase"
	base.CFrame = emit
	base.Parent = grip
	local tip = Instance.new("Attachment")
	tip.Name = "BladeTip"
	tip.CFrame = emit * CFrame.new(0, length, 0)
	tip.Parent = grip

	local trail = Instance.new("Trail")
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Color = seq(glowColor)
	trail.LightEmission = if isDark(def) then 0.2 else 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.13
	trail.MinLength = 0.05
	trail.FaceCamera = false
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new(1)
	trail.Enabled = false
	trail.Parent = grip

	local beam = Instance.new("Beam")
	beam.Attachment0 = base
	beam.Attachment1 = tip
	beam.Color = seq(glowColor)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = glowWidth * 2.6
	beam.Width1 = glowWidth * 2.2
	beam.Transparency = NumberSequence.new(if def.Effect == "DarkCore" then 0.82 else 0.72)
	beam.Parent = grip

	local light = Instance.new("PointLight")
	light.Color = glowColor
	light.Brightness = def.LightBrightness
	light.Range = BC.LightRange
	light.Shadows = false
	light.Parent = core

	local particles: ParticleEmitter? = nil
	if def.Effect == "Unstable" or def.Effect == "Nebula" or def.Effect == "InkCore" then
		local pe = Instance.new("ParticleEmitter")
		pe.LightInfluence = 0
		pe.LockedToPart = def.Effect ~= "InkCore"
		if def.Effect == "Unstable" then
			pe.Texture = Config.Textures.Sparkles
			pe.Color = seq(glowColor)
			pe.LightEmission = 1
			pe.Rate = 26
			pe.Lifetime = NumberRange.new(0.08, 0.22)
			pe.Speed = NumberRange.new(2, 6)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
		elseif def.Effect == "Nebula" then
			pe.Texture = Config.Textures.Sparkles
			pe.Color = ColorSequence.new(Color3.fromRGB(180, 140, 255), Color3.fromRGB(255, 120, 210))
			pe.LightEmission = 1
			pe.Rate = 14
			pe.Lifetime = NumberRange.new(0.4, 0.8)
			pe.Speed = NumberRange.new(0.2, 0.6)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(0.5, 0.14), NumberSequenceKeypoint.new(1, 0) })
		else
			pe.Texture = Config.Textures.Smoke
			pe.Color = seq(Color3.fromRGB(10, 8, 12))
			pe.LightEmission = 0
			pe.Rate = 10
			pe.Lifetime = NumberRange.new(0.3, 0.6)
			pe.Speed = NumberRange.new(0.3, 0.8)
			pe.SpreadAngle = Vector2.new(25, 25)
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.3) })
		end
		pe.Parent = core
		particles = pe
	end

	return {
		Grip = grip,
		Core = core,
		Glow = glow,
		Weld = w,
		GlowWeld = gw,
		Base = base,
		Tip = tip,
		Trail = trail,
		Beam = beam,
		Light = light,
		Particles = particles,
		Emit = emit,
		Length = length,
		GlowTransparency = glowT,
		LastTip = tip.WorldPosition,
		TrailOn = false,
	}
end

-- Longueur visible de la lame (0..1), sans allocation de table.
local function setExtend(b: Blade, e: number)
	local len = math.max(0.02, b.Length * e)
	local visible = e > 0.01
	b.Core.Size = Vector3.new(len, BC.CoreWidth, BC.CoreWidth)
	b.Glow.Size = Vector3.new(len + 0.08 * e, b.Glow.Size.Y, b.Glow.Size.Z)
	b.Weld.C0 = b.Emit * CFrame.new(0, len * 0.5, 0) * CYL
	b.Tip.CFrame = b.Emit * CFrame.new(0, len, 0)
	b.Core.Transparency = if visible then 0 else 1
	b.Glow.Transparency = if visible then b.GlowTransparency else 1
	b.Beam.Enabled = visible
	b.Light.Enabled = visible
	b.Light.Range = BC.LightRange * math.max(0.2, e)
	local pe = b.Particles
	if pe then
		pe.Enabled = e > 0.9
	end
	if not visible and b.TrailOn then
		b.TrailOn = false
		b.Trail.Enabled = false
	end
end

local function hiltsFor(weapon: string, def: SaberColorDef): { Hilt }
	if weapon == "Staff" then
		return { makeHilt(true, def) }
	elseif weapon == "Dual" then
		return { makeHilt(false, def), makeHilt(false, def) }
	end
	return { makeHilt(false, def) }
end

local function bladeLength(weapon: string): number
	return BC.Length[weapon] or BC.Length.Single
end

local function resolveDef(colorId: string): SaberColorDef
	return SaberColors.get(colorId) or (SaberColors.get(SaberColors.Default) :: SaberColorDef)
end

--------------------------------------------------------------------------------
-- Aperçu (Atelier)

function SaberVisual.build(weapon: string, colorId: string): Model
	local def = resolveDef(colorId)
	local model = Instance.new("Model")
	model.Name = "EtherSaber_" .. weapon
	local hilts = hiltsFor(weapon, def)
	local len = bladeLength(weapon)
	for i, h in hilts do
		local offset = CFrame.identity
		if weapon == "Dual" then
			offset = if i == 1 then CFrame.new(-0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(-12)) else CFrame.new(0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(12))
		end
		h.Model:PivotTo(offset)
		for _, emit in h.Emitters do
			addBlade(h, emit, len, def)
		end
		for _, d in h.Model:GetChildren() do
			d.Parent = model
		end
		h.Model:Destroy()
		if i == 1 then
			model.PrimaryPart = h.Grip
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return model
end

--------------------------------------------------------------------------------
-- Lames équipées

local function handOf(character: Model, left: boolean): (BasePart?, CFrame)
	local r15 = character:FindFirstChild(if left then "LeftHand" else "RightHand")
	if r15 and r15:IsA("BasePart") then
		return r15, CFrame.new(0, -0.12, 0)
	end
	local r6 = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	if r6 and r6:IsA("BasePart") then
		return r6, CFrame.new(0, -0.95, 0)
	end
	return nil, CFrame.identity
end

local function setOn(self: Saber, on: boolean, instant: boolean?)
	local target = if on then 1 else 0
	if self.Target == target and not instant then
		return
	end
	self.Target = target
	if instant then
		self.Extend = target
		for _, b in self.Blades do
			setExtend(b, target)
		end
	else
		self.Ignite.PlaybackSpeed = if on then 1.05 else 0.8
		self.Ignite:Play()
	end
end

local function isOn(self: Saber): boolean
	return self.Target > 0
end

local function destroy(self: Saber)
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	local i = table.find(active, self)
	if i then
		table.remove(active, i)
	end
	self.Maid:Clean()
end

local function sound(id: string, parent: Instance, volume: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 60
	s.Parent = parent
	return s
end

-- Lames d'un combattant, soudées à ses mains. Éteintes par défaut (setOn pour allumer).
function SaberVisual.attach(character: Model, weapon: string, colorId: string): Saber?
	local def = resolveDef(colorId)
	local rightHand, rightOff = handOf(character, false)
	if not rightHand then
		return nil
	end
	local maid = Maid.new()
	local model = Instance.new("Model")
	model.Name = "EtherSaber"
	local hilts = hiltsFor(weapon, def)
	local len = bladeLength(weapon)
	local blades: { Blade } = {}
	local grips: { BasePart } = {}
	for i, h in hilts do
		local hand: BasePart? = rightHand
		local handOff = rightOff
		if i == 2 then
			hand, handOff = handOf(character, true)
		end
		if hand then
			-- la main tient la poignée un peu sous son centre (lame simple) ou au centre (bâton)
			local slide = if weapon == "Staff" then 0 else 0.15
			local c0 = handOff * TO_HAND * CFrame.new(0, slide, 0)
			h.Model:PivotTo((hand :: BasePart).CFrame * c0)
			for _, emit in h.Emitters do
				table.insert(blades, addBlade(h, emit, len, def))
			end
			local w = Instance.new("Weld")
			w.Name = "HandWeld"
			w.Part0 = hand
			w.Part1 = h.Grip
			w.C0 = c0
			w.C1 = CFrame.identity
			w.Parent = h.Grip
			h.Model.Parent = model
			table.insert(grips, h.Grip)
		else
			h.Model:Destroy()
		end
	end
	model.Parent = character
	maid:Give(model)
	local rings: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d.Name == "EmitterGlow" and d:IsA("BasePart") then
			table.insert(rings, d)
		end
	end
	local anchor: Instance = if blades[1] then blades[1].Core else rightHand
	local hum = sound(Config.Sounds.Hum, anchor, 0, true)
	hum.PlaybackSpeed = 0.32 * def.HumPitch
	local swing = sound(Config.Sounds.Swing, anchor, 0.35, false)
	local ignite = sound(Config.Sounds.Ignite, anchor, 0.5, false)

	local saber: Saber = {
		Model = model,
		Weapon = weapon,
		ColorId = def.Id,
		Def = def,
		Blades = blades,
		Grips = grips,
		Rings = rings,
		Extend = 0,
		Target = 0,
		Hum = hum,
		Swing = swing,
		Ignite = ignite,
		LastSwing = 0,
		EffectClock = 0,
		Destroyed = false,
		Maid = maid,
		setOn = setOn,
		isOn = isOn,
		destroy = destroy,
	}
	for _, b in blades do
		setExtend(b, 0)
	end
	maid:Give(character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			destroy(saber)
		end
	end))
	table.insert(active, saber)
	return saber
end

-- Lames actives (VFX : traces de brûlure le long des lames).
function SaberVisual.all(): { Saber }
	return active
end

--------------------------------------------------------------------------------
-- Boucle d'animation (une seule connexion pour toutes les lames)

local function applyEffects(s: Saber, now: number)
	local def = s.Def
	local effect = def.Effect
	if effect == "Prism" or effect == "Nebula" then
		local c = SaberColors.glowAt(def, now)
		local cs = seq(c)
		for _, b in s.Blades do
			b.Glow.Color = c
			b.Light.Color = c
			b.Trail.Color = cs
			b.Beam.Color = cs
		end
		for _, r in s.Rings do
			r.Color = c
		end
	elseif effect == "Unstable" then
		for _, b in s.Blades do
			local k = rng:NextNumber()
			b.Glow.Transparency = 0.35 + k * 0.4
			b.Light.Brightness = def.LightBrightness * (0.7 + k * 0.6)
			local wdt = BC.GlowWidth * (0.85 + rng:NextNumber() * 0.5)
			b.Glow.Size = Vector3.new(b.Glow.Size.X, wdt, wdt)
		end
	elseif effect == "DarkCore" or effect == "InkCore" then
		local k = (math.sin(now * 5) + 1) * 0.5
		for _, b in s.Blades do
			b.Light.Brightness = def.LightBrightness * (0.85 + k * 0.3)
		end
	end
end

RunService.RenderStepped:Connect(function(dt: number)
	if #active == 0 or dt <= 0 then
		return
	end
	local now = os.clock()
	for _, s in active do
		-- allumage / extinction
		if s.Extend ~= s.Target then
			local dur = if s.Target > s.Extend then BC.IgniteTime else BC.RetractTime
			local step = dt / math.max(dur, 1e-3)
			s.Extend = if s.Target > s.Extend then math.min(s.Target, s.Extend + step) else math.max(s.Target, s.Extend - step)
			local eased = 1 - (1 - s.Extend) * (1 - s.Extend)
			for _, b in s.Blades do
				setExtend(b, eased)
			end
		end
		-- bourdonnement
		local humVol = BC.HumVolume * s.Extend
		if humVol > 0.005 then
			if not s.Hum.IsPlaying then
				s.Hum:Play()
			end
			s.Hum.Volume = humVol
		elseif s.Hum.IsPlaying then
			s.Hum:Stop()
		end
		if s.Extend > 0.05 then
			-- traînée et son de swing selon la vitesse de pointe
			local fastest = 0
			for _, b in s.Blades do
				local tipPos = b.Tip.WorldPosition
				local speed = (tipPos - b.LastTip).Magnitude / dt
				b.LastTip = tipPos
				if speed > fastest then
					fastest = speed
				end
				local want = speed > BC.TrailSpeed
				if want ~= b.TrailOn then
					b.TrailOn = want
					b.Trail.Enabled = want
				end
			end
			if fastest > BC.SwingSpeed and now - s.LastSwing > BC.SwingCooldown and fastest < 600 then
				s.LastSwing = now
				s.Swing.PlaybackSpeed = s.Def.HumPitch * (0.9 + rng:NextNumber() * 0.25)
				s.Swing:Play()
			end
			if now - s.EffectClock >= 1 / BC.EffectRate then
				s.EffectClock = now
				applyEffects(s, now)
			end
		end
	end
end)

return SaberVisual
