--!strict
--[[
	AmbienceController — tout ce qui rend le monde vivant, côté client uniquement (zéro coût serveur).
	- Ciel : nuages dynamiques, rayons de soleil, légère profondeur de champ, eau stylisée.
	- Particules d'ambiance autour de la caméra selon la zone :
	  Hub = pétales & papillons · Jungle = lucioles & feuilles · Désert = sable au vent
	  Marais = spores & brume · Volcan = braises & cendres · Cosmos = poussière d'étoiles
	- Auras de rareté sur les serpents sauvages (Rare+ anneau, Épique+ étincelles,
	  Légendaire/Mythique colonne de lumière visible de loin → donne envie d'y aller).
	- Effets de jeu : onde de choc au vol, colonne dorée au dépôt.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SnakesConfig = require(game.ReplicatedStorage.StealASnake.Config.SnakesConfig)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local FormatNumber = require(game.ReplicatedStorage.StealASnake.Modules.FormatNumber)

local AmbienceController = {}

local player = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local RARITY_COLORS: { [string]: Color3 } = {
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
}
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

-- ───────────────────────── Ciel & post-process ─────────────────────────
local function setupSky()
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 250, 245)
	clouds.Parent = Workspace.Terrain

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting

	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect") or Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 60
	dof.InFocusRadius = 70
	dof.NearIntensity = 0
	dof.Parent = Lighting

	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local b = Instance.new("BloomEffect")
		b.Intensity = 0.4
		b.Size = 28
		b.Threshold = 1.6
		b.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.2
		cc.Contrast = 0.08
		cc.Parent = Lighting
	end
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6

	local t = Workspace.Terrain
	t.WaterColor = Color3.fromRGB(40, 170, 200)
	t.WaterTransparency = 0.35
	t.WaterReflectance = 0.6
	t.WaterWaveSize = 0.25
	t.WaterWaveSpeed = 12
end

-- ───────────────────────── Particules d'ambiance ─────────────────────────
local anchor: Part
local zoneEmitters: { [number]: { ParticleEmitter } } = {}

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	pe.LockedToPart = false
	pe.LightInfluence = 0
	for k, v in props do
		(pe :: any)[k] = v
	end
	pe.Parent = parent
	return pe
end

local function buildAmbience()
	anchor = Instance.new("Part")
	anchor.Name = "SAS_Ambience"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(90, 26, 90) -- les particules naissent dans tout ce volume autour du joueur
	anchor.Parent = Workspace.CurrentCamera

	local function pe(zone: number, props: { [string]: any })
		zoneEmitters[zone] = zoneEmitters[zone] or {}
		props.Shape = Enum.ParticleEmitterShape.Box
		props.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		table.insert(zoneEmitters[zone], emitter(anchor, props))
	end

	-- 0 · Hub : pétales roses qui tombent en tournoyant + éclats de lumière
	pe(0, { Rate = 14, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.5, 1.5), Acceleration = Vector3.new(1.5, -1.2, 0.6),
		RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360), Size = NumberSequence.new(0.6),
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 200), Color3.fromRGB(255, 225, 235)), Texture = SPARKLE,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) }) })
	pe(0, { Rate = 5, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.2, 0.6), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 245, 190)), Texture = SPARKLE, LightEmission = 1 })

	-- 1 · Jungle : lucioles qui pulsent + feuilles
	pe(1, { Rate = 22, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(200, 255, 120)), Texture = SPARKLE, LightEmission = 1 })
	pe(1, { Rate = 6, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 1), Acceleration = Vector3.new(0.8, -1.5, 0),
		RotSpeed = NumberRange.new(-120, 120), Size = NumberSequence.new(0.8), Color = ColorSequence.new(Color3.fromRGB(70, 160, 60), Color3.fromRGB(150, 200, 70)) })

	-- 2 · Désert : sable porté par le vent + chaleur
	pe(2, { Rate = 40, Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(14, 22), EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(8, 8),
		Size = NumberSequence.new(0.22), Color = ColorSequence.new(Color3.fromRGB(235, 200, 140)), Transparency = NumberSequence.new(0.3, 1) })
	pe(2, { Rate = 3, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(8, 12), EmissionDirection = Enum.NormalId.Right,
		Size = NumberSequence.new(6, 12), Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(230, 195, 140)), Transparency = NumberSequence.new(0.85, 1) })

	-- 3 · Marais : spores vertes + nappes de brume basse
	pe(3, { Rate = 18, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.2, 0.8), Acceleration = Vector3.new(0, 0.4, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(150, 255, 110)), Texture = SPARKLE, LightEmission = 0.8 })
	pe(3, { Rate = 6, Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(0.5, 1.5), EmissionDirection = Enum.NormalId.Bottom,
		Size = NumberSequence.new(10, 16), Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(170, 200, 160)), Transparency = NumberSequence.new(0.8, 1) })

	-- 4 · Volcan : braises qui montent + cendres
	pe(4, { Rate = 35, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(2, 5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0.5, 2, 0), Size = NumberSequence.new(0.5, 0), Texture = FIRE, LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20)) })
	pe(4, { Rate = 16, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 1.5), Acceleration = Vector3.new(0.4, -0.8, 0),
		Size = NumberSequence.new(0.18), Color = ColorSequence.new(Color3.fromRGB(70, 65, 65)), Transparency = NumberSequence.new(0.2, 1) })

	-- 5 · Cosmos : poussière d'étoiles multicolore + nébuleuses
	pe(5, { Rate = 30, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.2, 1), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0) }),
		Texture = SPARKLE, LightEmission = 1,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 120, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 230, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 220)) }) })
	pe(5, { Rate = 2, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.2, 0.5), Size = NumberSequence.new(14, 22), Texture = SMOKE, LightEmission = 0.6,
		Color = ColorSequence.new(Color3.fromRGB(120, 70, 220), Color3.fromRGB(60, 140, 255)), Transparency = NumberSequence.new(0.88, 1) })
end

local activeZone = -1
local function setZone(z: number)
	if z == activeZone then
		return
	end
	activeZone = z
	for zone, list in zoneEmitters do
		for _, e in list do
			e.Enabled = zone == z
		end
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		TweenService:Create(rays, TweenInfo.new(1.5), { Intensity = if z == 2 or z == 0 or z == 1 then 0.08 else 0.02 }):Play()
	end
end

-- ───────────────────────── Auras de rareté ─────────────────────────
local auraDone: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function addAura(m: Instance)
	if not m:IsA("Model") or auraDone[m] then
		return
	end
	task.defer(function()
		local root = m.PrimaryPart
		local id = m:GetAttribute("SpeciesId")
		if not root or typeof(id) ~= "string" then
			return
		end
		local def = SnakesConfig.get(id)
		local rank = def and RANK[def.Rarity] or 1
		local color = def and RARITY_COLORS[def.Rarity]
		local mutated = (m:GetAttribute("Mutation") or "Normal") ~= "Normal"
		if rank < 3 and not mutated then
			return
		end
		auraDone[m] = true
		color = color or Color3.fromRGB(255, 255, 255)

		-- anneau lumineux au sol
		local att = Instance.new("Attachment")
		att.Name = "SAS_Aura"
		att.Position = Vector3.new(0, -1, 0)
		att.Parent = root
		emitter(att, { Enabled = true, Rate = 8 + rank * 3, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 1.5),
			Acceleration = Vector3.new(0, 3, 0), SpreadAngle = Vector2.new(180, 0), Texture = SPARKLE, LightEmission = 1,
			Size = NumberSequence.new(0.35, 0), Color = ColorSequence.new(color) })
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 6 + rank * 1.5
		light.Brightness = 1.4
		light.Parent = root

		-- Légendaire / Mythique : colonne de lumière visible de très loin
		if rank >= 5 then
			local top = Instance.new("Attachment")
			top.Position = Vector3.new(0, 60, 0)
			top.Parent = root
			local beam = Instance.new("Beam")
			beam.Attachment0 = att
			beam.Attachment1 = top
			beam.Width0 = 2.6
			beam.Width1 = 0.4
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.Brightness = 3
			beam.Color = ColorSequence.new(color)
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			beam.Parent = root
			emitter(att, { Enabled = true, Rate = 6, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(6, 10),
				EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6), Texture = SPARKLE, LightEmission = 1,
				Size = NumberSequence.new(0.6, 0), Color = ColorSequence.new(color, Color3.new(1, 1, 1)) })
		end
	end)
end

-- ───────────────────────── Effets de jeu ─────────────────────────
local function burstAt(pos: Vector3, color: Color3, pillar: boolean)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Parent = Workspace
	local att = Instance.new("Attachment")
	att.Parent = p
	local ring = emitter(att, { Rate = 0, Lifetime = NumberRange.new(0.5, 0.7), Speed = NumberRange.new(26, 32), SpreadAngle = Vector2.new(180, 0),
		Texture = SPARKLE, LightEmission = 1, Size = NumberSequence.new(0.8, 0), Color = ColorSequence.new(color), Drag = 4 })
	ring.Enabled = true
	ring:Emit(60)
	-- anneau néon qui s'agrandit
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = 0.2
	disc.Size = Vector3.new(0.2, 2, 2)
	disc.CFrame = CFrame.new(pos - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = p
	TweenService:Create(disc, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 26, 26), Transparency = 1 }):Play()
	if pillar then
		local col = Instance.new("Part")
		col.Anchored = true
		col.CanCollide = false
		col.CanQuery = false
		col.Material = Enum.Material.Neon
		col.Color = color
		col.Transparency = 0.3
		col.Shape = Enum.PartType.Cylinder
		col.Size = Vector3.new(1, 5, 5)
		col.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		col.Parent = p
		TweenService:Create(col, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = Vector3.new(80, 0.5, 0.5),
			CFrame = CFrame.new(pos + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 1,
		}):Play()
	end
	task.delay(1.4, function()
		p:Destroy()
	end)
end

local function hrpPos(): Vector3?
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	return if h and h:IsA("BasePart") then h.Position else nil
end

function AmbienceController.start(environment: any)
	setupSky()
	buildAmbience()

	local wild = Workspace:WaitForChild("WildSnakes", 30)
	if wild then
		for _, m in wild:GetChildren() do
			addAura(m)
		end
		wild.ChildAdded:Connect(addAura)
	end

	local wasCarrying = false
	Network.event("CarryState").OnClientEvent:Connect(function(state)
		local pos = hrpPos()
		if state and not wasCarrying and pos then
			burstAt(pos, Color3.fromRGB(110, 220, 255), false) -- vol réussi
		end
		wasCarrying = state ~= nil
	end)
	Network.event("Alert").OnClientEvent:Connect(function(msg)
		local pos = hrpPos()
		if typeof(msg) == "string" and pos and msg:find("sécurisé") then
			burstAt(pos, Color3.fromRGB(255, 210, 60), true) -- dépôt réussi
		end
	end)

	-- Portes de biome : rendu PAR JOUEUR (ouverte si débloquée pour moi) + anneaux de dépôt pulsés
	local gates: { BasePart } = {}
	local rings: { BasePart } = {}
	local map = Workspace:WaitForChild("Map", 30)
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "BiomeGate" then
				table.insert(gates, d)
			elseif d:IsA("BasePart") and d.Name == "DropRing" then
				table.insert(rings, d)
			end
		end
	end
	local function refreshGates()
		local maxBiome = player:GetAttribute("MaxBiome") or 1
		for _, g in gates do
			local open = maxBiome >= (g:GetAttribute("Order") or 99)
			g.Transparency = if open then 1 else 0.25
			g.Color = if open then Color3.fromRGB(110, 255, 160) else Color3.fromRGB(255, 90, 90)
			local biome = g.Parent
			local req = biome and biome:FindFirstChild("Requirement", true)
			if req and req:IsA("TextLabel") then
				req.Text = if open
					then "✅ Débloqué"
					else string.format("🔒 ⚡ %d Vitesse  ·  💵 $%s", g:GetAttribute("RequiredSpeed") or 0, FormatNumber.short(g:GetAttribute("RequiredCash") or 0))
			end
		end
	end
	refreshGates()
	player:GetAttributeChangedSignal("MaxBiome"):Connect(refreshGates)

	RunService.RenderStepped:Connect(function()
		local pulse = 0.35 + (math.sin(os.clock() * 4) + 1) * 0.25
		for _, r in rings do
			r.Transparency = pulse
		end
		local cam = Workspace.CurrentCamera
		if cam and anchor then
			anchor.CFrame = CFrame.new(cam.CFrame.Position + cam.CFrame.LookVector * 20)
		end
		if environment and environment.getZone then
			setZone(math.max(environment.getZone(), 0))
		end
	end)
end

return AmbienceController
