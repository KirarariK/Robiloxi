--!strict
-- Vfx : effets visuels et sonores du combat (côté client) — étincelles, éclairs lumineux, ondes de choc,
-- distorsion de chaleur (sphère de verre réfractante + flou bref si la caméra est proche), sons ponctuels,
-- et traces de brûlure laissées par les lames (raycasts le long de chaque lame allumée, budget par tick).
-- Toutes les pièces sont ancrées, CanCollide = false, CanQuery = false, CanTouch = false.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Config = require(Shared.Combat.CombatConfig)

local SaberVisual = require(script.Parent.SaberVisual)
local CameraFx = require(script.Parent.CameraFx)

local VC = Config.Vfx

local Vfx = {}

local folder = Instance.new("Folder")
folder.Name = "EtherBladesVfx"
folder.Parent = workspace

local function vfxPart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
end

local function later(inst: Instance, seconds: number)
	task.delay(seconds, function()
		inst:Destroy()
	end)
end

local function cameraDistance(pos: Vector3): number
	return (workspace.CurrentCamera.CFrame.Position - pos).Magnitude
end

--------------------------------------------------------------------------------
-- Sons ponctuels

function Vfx.sound(id: string, pos: Vector3, volume: number, pitch: number)
	local att = Instance.new("Attachment")
	att.Parent = workspace.Terrain
	att.WorldPosition = pos
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 120
	s.Parent = att
	s:Play()
	later(att, 3)
end

--------------------------------------------------------------------------------
-- Étincelles

function Vfx.sparks(pos: Vector3, color: Color3, count: number, speed: number)
	local p = vfxPart("Sparks", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), color, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.Position = pos
	local att = Instance.new("Attachment")
	att.Parent = p
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = Config.Textures.Sparkles
	pe.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.15, 0.45)
	pe.Speed = NumberRange.new(speed * 0.4, speed)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -workspace.Gravity * 0.25, 0)
	pe.Drag = 3
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
	pe.Parent = att
	p.Parent = folder
	pe:Emit(math.clamp(math.floor(count), 1, 80))
	later(p, 0.8)
end

--------------------------------------------------------------------------------
-- Éclair lumineux (sphère néon + PointLight)

function Vfx.flash(pos: Vector3, color: Color3, size: number, duration: number)
	local ball = vfxPart("Flash", Enum.PartType.Ball, Vector3.one * size * 0.3, color, Enum.Material.Neon)
	ball.Transparency = 0.1
	ball.Position = pos
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 6
	light.Range = 10 + size * 4
	light.Shadows = false
	light.Parent = ball
	ball.Parent = folder
	tween(ball, duration, { Size = Vector3.one * size, Transparency = 1 })
	tween(light, duration, { Brightness = 0 })
	later(ball, duration + 0.05)
end

-- Onde de choc horizontale (bris de garde, poussée cinétique).
function Vfx.shockwave(pos: Vector3, color: Color3, radius: number, duration: number)
	local disc = vfxPart("Shockwave", Enum.PartType.Cylinder, Vector3.new(0.12, 1, 1), color, Enum.Material.Neon)
	disc.Transparency = 0.3
	disc.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Parent = folder
	tween(disc, duration, { Size = Vector3.new(0.05, radius * 2, radius * 2), Transparency = 1 })
	later(disc, duration + 0.05)
end

-- Distorsion de chaleur : sphère de verre (réfraction) qui gonfle, flou bref si l'impact est proche.
function Vfx.heat(pos: Vector3, intensity: number)
	local glass = vfxPart("Heat", Enum.PartType.Ball, Vector3.one * 0.8, Color3.fromRGB(255, 236, 220), Enum.Material.Glass)
	glass.Transparency = 0.72
	glass.Reflectance = 0
	glass.Position = pos
	glass.Parent = folder
	local size = 3 + intensity * 4
	tween(glass, 0.35, { Size = Vector3.one * size, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	later(glass, 0.4)
	local d = cameraDistance(pos)
	if d < VC.HeatRadius then
		local k = 1 - d / VC.HeatRadius
		CameraFx.blurPulse(2 + 6 * k * intensity, 0.22)
	end
end

--------------------------------------------------------------------------------
-- Traces de brûlure

type Mark = { Scorch: Part, Ember: Part, Born: number, Alive: boolean }

local marks: { Mark } = {}
local markHead = 0
local lastMarkPos: { [Attachment]: Vector3 } = {}
local burnParams = RaycastParams.new()
burnParams.FilterType = Enum.RaycastFilterType.Exclude
burnParams.RespectCanCollide = true
burnParams.IgnoreWater = true
local filterClock = 0
local burnClock = 0
local cursor = 0

local SCORCH = Color3.fromRGB(24, 18, 14)
local EMBER = Color3.fromRGB(255, 120, 40)

local function refreshFilter()
	local list: { Instance } = { folder }
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c then
			table.insert(list, c)
		end
	end
	local dummies = workspace:FindFirstChild("CombatDummies")
	if dummies then
		table.insert(list, dummies)
	end
	burnParams.FilterDescendantsInstances = list
end

local function placeMark(pos: Vector3, normal: Vector3, glow: Color3)
	markHead = markHead % VC.BurnMaxMarks + 1
	local m = marks[markHead]
	if not m then
		local scorch = vfxPart("Scorch", Enum.PartType.Cylinder, Vector3.new(0.03, 0.42, 0.42), SCORCH, Enum.Material.SmoothPlastic)
		local ember = vfxPart("Ember", Enum.PartType.Cylinder, Vector3.new(0.035, 0.22, 0.22), EMBER, Enum.Material.Neon)
		scorch.Parent = folder
		ember.Parent = folder
		m = { Scorch = scorch, Ember = ember, Born = 0, Alive = false }
		marks[markHead] = m
	end
	local mark = m :: Mark
	-- cylindre couché sur la surface : son axe X suit la normale
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, math.pi / 2, 0)
	mark.Scorch.CFrame = cf
	mark.Ember.CFrame = cf * CFrame.new(0.005, 0, 0)
	mark.Ember.Color = EMBER:Lerp(glow, 0.35)
	mark.Scorch.Transparency = 0.15
	mark.Ember.Transparency = 0
	mark.Born = os.clock()
	mark.Alive = true
end

local function fadeMarks(now: number)
	for _, m in marks do
		if m.Alive then
			local age = now - m.Born
			if age >= VC.BurnLifetime then
				m.Alive = false
				m.Scorch.Transparency = 1
				m.Ember.Transparency = 1
			else
				m.Ember.Transparency = math.clamp(age / 0.9, 0, 1)
				m.Scorch.Transparency = 0.15 + 0.85 * math.clamp((age - VC.BurnLifetime * 0.5) / (VC.BurnLifetime * 0.5), 0, 1)
			end
		end
	end
end

local function burnTick(now: number)
	local sabers = SaberVisual.all()
	local n = #sabers
	if n == 0 then
		return
	end
	local camPos = workspace.CurrentCamera.CFrame.Position
	local budget = VC.BurnRaysPerTick
	local tries = 0
	while budget > 0 and tries < n do
		tries += 1
		cursor = cursor % n + 1
		local s = sabers[cursor]
		if s.Extend > 0.9 then
			for _, b in s.Blades do
				if budget <= 0 then
					break
				end
				local from = b.Base.WorldPosition
				if (from - camPos).Magnitude <= VC.BurnMaxDistance then
					budget -= 1
					local to = b.Tip.WorldPosition
					local hit = workspace:Raycast(from, to - from, burnParams)
					if hit then
						local last = lastMarkPos[b.Tip]
						if last == nil or (last - hit.Position).Magnitude >= VC.BurnSpacing then
							lastMarkPos[b.Tip] = hit.Position
							placeMark(hit.Position, hit.Normal, s.Def.Glow)
							if math.random() < 0.35 then
								Vfx.sparks(hit.Position, s.Def.Glow, 4, 10)
							end
						end
					end
				end
			end
		end
	end
	-- oublie les lames détruites
	for att in lastMarkPos do
		if att.Parent == nil then
			lastMarkPos[att] = nil
		end
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	filterClock += dt
	if filterClock >= 1 then
		filterClock = 0
		refreshFilter()
	end
	burnClock += dt
	if burnClock >= 1 / VC.BurnRate then
		burnClock = 0
		burnTick(now)
		fadeMarks(now)
	end
end)
refreshFilter()

--------------------------------------------------------------------------------
-- Effets composés (appelés par CombatController)

function Vfx.impact(pos: Vector3, color: Color3, heavy: boolean)
	Vfx.sparks(pos, color, if heavy then 34 else 16, if heavy then 30 else 20)
	Vfx.flash(pos, color, if heavy then 4.5 else 2.6, if heavy then 0.25 else 0.15)
	Vfx.heat(pos, if heavy then 1 else 0.45)
	Vfx.sound(Config.Sounds.Hit, pos, if heavy then 0.8 else 0.55, if heavy then 0.85 else 1.05)
end

function Vfx.clash(pos: Vector3, color: Color3, heavy: boolean)
	Vfx.sparks(pos, color, if heavy then 40 else 22, if heavy then 34 else 24)
	Vfx.flash(pos, Color3.new(1, 1, 1):Lerp(color, 0.4), if heavy then 4 else 2.4, 0.18)
	Vfx.heat(pos, if heavy then 0.8 else 0.4)
	Vfx.sound(Config.Sounds.Clash, pos, if heavy then 0.9 else 0.6, if heavy then 0.8 else 1)
end

function Vfx.parry(pos: Vector3, color: Color3)
	Vfx.sparks(pos, Color3.fromRGB(255, 240, 200), 46, 38)
	Vfx.flash(pos, Color3.new(1, 1, 1), 5.5, 0.3)
	Vfx.shockwave(pos, color, 5, 0.35)
	Vfx.heat(pos, 1)
	Vfx.sound(Config.Sounds.Clash, pos, 1, 1.25)
	Vfx.sound(Config.Sounds.Ping, pos, 0.6, 1.6)
end

function Vfx.guardBreak(pos: Vector3, color: Color3)
	Vfx.sparks(pos, color, 60, 42)
	Vfx.flash(pos, color, 6.5, 0.4)
	Vfx.shockwave(pos - Vector3.new(0, 1.2, 0), color, 8, 0.5)
	Vfx.heat(pos, 1.2)
	Vfx.sound(Config.Sounds.Clash, pos, 1, 0.6)
end

function Vfx.dodge(pos: Vector3, color: Color3)
	local p = vfxPart("DodgeDust", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), color, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.Position = pos - Vector3.new(0, 2.5, 0)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = Config.Textures.Smoke
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 200, 210))
	pe.LightInfluence = 1
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(3, 6)
	pe.SpreadAngle = Vector2.new(70, 10)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = p
	p.Parent = folder
	pe:Emit(10)
	later(p, 0.8)
	Vfx.sound(Config.Sounds.Lunge, pos, 0.45, 1.2)
end

function Vfx.ko(pos: Vector3, color: Color3)
	Vfx.flash(pos, color, 7, 0.6)
	Vfx.shockwave(pos - Vector3.new(0, 2, 0), color, 10, 0.7)
	Vfx.sparks(pos, color, 50, 26)
end

return Vfx
