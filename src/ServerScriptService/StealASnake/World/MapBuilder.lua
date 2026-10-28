--!strict
--[[
	MapBuilder — construit tout le monde de Steal A Snake au démarrage du serveur.

	Arène-hub murée façon « Steal An Egg » : 8 bases clôturées en rangée, bande ZONE SÉCURISÉE, stand VENDRE,
	place centrale (statue, fontaines) et sortie vers la route · route murée (zone sûre) · 15 zones de 220 × 220
	murées (BiomesConfig) avec décor par thème, nid, porte-crâne et gardien.
	Anti-chute : murs visibles + barrières invisibles de 300 studs autour de tout le monde (BoundsService
	ramène aussi à sa base tout joueur qui passerait sous le sol).

	Contrat de noms (utilisés par les autres systèmes — ne pas renommer) :
	  Map/SafeZone/SafePath (Part invisible : zone sûre) · Map/SafeZone/HubFloor
	  Map/Plots/Plot_N/{PlotPad, OwnerSign(SurfaceGui.OwnerLabel), DropZone, CollectPad(CashBillboard.Amount),
	                   TreadmillSpot, FusionMachine, RebirthShrine, Vivariums/Slot_1..20, PlotSpawn}
	  Map/Biomes/<Id>/{Floor, BiomeBoundary, Nest/SpawnPoints/SP_n, GuardianSpawn, BiomeGate (Order > 1)}

	Les modèles 3D décoratifs sont pris dans ReplicatedStorage.StealASnake.Assets.Models
	(JungleTree, PalmTree, Cactus, SwampTree, Mushrooms, LavaSpire, CosmicCrystal, SkullGate, Nest,
	Vivarium, FusionMachine, RebirthAltar) — avec un repli en Parts si un modèle manque.
]]
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BiomesConfig = require(ReplicatedStorage.StealASnake.Config.BiomesConfig)

local MapBuilder = {}

local terrain = Workspace.Terrain
local rng = Random.new(1337) -- décor identique à chaque démarrage

-- Géométrie globale
local GROUND_Y = 1 -- dessus du sol (terrain)
local ROAD_HALF = 20 -- demi-largeur de la route centrale (et de la sortie de l'arène)
local HUB_Z_MAX = 290 -- mur du fond de l'arène (derrière les bases)
local HUB_Z_MIN = -40 -- mur avant de l'arène (sortie vers la route)
local HUB_HALF_X = 330
local LAST_BIOME = BiomesConfig[#BiomesConfig]
local WORLD_Z_MIN = LAST_BIOME.Center.Z - LAST_BIOME.Size.Z / 2 - 30
local CANYON_HALF_X = BiomesConfig[1].Size.X / 2 -- bord des zones
local WALL_H = 60 -- murs visibles
local BARRIER_H = 300 -- barrières invisibles (anti-sortie de map)

--[[ ───────────────────────── Helpers ───────────────────────── ]]

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function deco(props: { [string]: any }): Part
	local p = part(props)
	p.CanCollide = if props.CanCollide == nil then false else props.CanCollide
	p.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Étiquette flottante au-dessus d'un élément interactif de la base (lisibilité de loin).
local function signBillboard(host: BasePart, text: string, color: Color3, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "SignBillboard"
	bb.Size = UDim2.fromOffset(170, 44)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.MaxDistance = 75
	bb.LightInfluence = 0
	bb.Parent = host
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
	tl.BackgroundTransparency = 0.2
	tl.Text = text
	tl.TextColor3 = color
	tl.TextScaled = true
	tl.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	tl.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = tl
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = tl
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = tl
end

local function template(name: string): Model?
	local root = ReplicatedStorage:FindFirstChild("StealASnake")
	local assets = root and root:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local m = models and models:FindFirstChild(name)
	return if m and m:IsA("Model") then m else nil
end

-- Place un modèle importé posé sur le sol (bas du modèle à `ground`), échelle et rotation.
local function placeTemplate(name: string, parent: Instance, pos: Vector3, scale: number, yaw: number, collide: boolean?): Model?
	local t = template(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	if scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide == true
			d.CanTouch = false
			d.CanQuery = collide == true
		end
	end
	local cf, size = m:GetBoundingBox()
	local pivotOffset = m:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	m:PivotTo(CFrame.new(pos.X, pos.Y + pivotOffset, pos.Z) * CFrame.Angles(0, yaw, 0))
	m.Parent = parent
	return m
end

local function fill(cf: CFrame, size: Vector3, material: Enum.Material)
	terrain:FillBlock(cf, size, material)
end

-- Vrai si (x, z) est sur la route ou trop près du nid → on n'y met pas de décor.
local function blocked(x: number, z: number, center: Vector3, nestClear: number): boolean
	if math.abs(x) < ROAD_HALF + 6 then
		return true
	end
	local dx, dz = x - center.X, z - center.Z
	return (dx * dx + dz * dz) < nestClear * nestClear
end

local function scatter(n: number, center: Vector3, half: number, nestClear: number, fn: (Vector3, number, number) -> ())
	local placed = 0
	local tries = 0
	while placed < n and tries < n * 12 do
		tries += 1
		local x = center.X + rng:NextNumber(-half, half)
		local z = center.Z + rng:NextNumber(-half, half)
		if not blocked(x, z, center, nestClear) then
			placed += 1
			fn(Vector3.new(x, GROUND_Y, z), rng:NextNumber(0, math.pi * 2), rng:NextNumber(0.8, 1.25))
		end
	end
end

--[[ ───────────────────────── Physique & lumière ───────────────────────── ]]

local function ensureGroup(name: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

function MapBuilder.setupPhysics()
	ensureGroup("Players")
	ensureGroup("CarriedSnakes")
	ensureGroup("Guardians")
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("CarriedSnakes", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("CarriedSnakes", "CarriedSnakes", false)
	PhysicsService:CollisionGroupSetCollidable("CarriedSnakes", "Guardians", false)
	PhysicsService:CollisionGroupSetCollidable("Guardians", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Guardians", "Guardians", false)
end

-- Lumière de base (hub ensoleillé). Le client ajuste l'ambiance par biome (EnvironmentController).
function MapBuilder.setupLighting()
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	Lighting.Brightness = 2.6
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 35
	Lighting.Ambient = Color3.fromRGB(95, 100, 115)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 145, 160)
	Lighting.ExposureCompensation = 0.1
	pcall(function()
		Lighting.EnvironmentDiffuseScale = 0.8
		Lighting.EnvironmentSpecularScale = 0.6
	end)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.28
	atmo.Offset = 0.12
	atmo.Color = Color3.fromRGB(205, 225, 255)
	atmo.Decay = Color3.fromRGB(110, 130, 170)
	atmo.Glare = 0.2
	atmo.Haze = 1.2
	atmo.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.Contrast = 0.1
	cc.Parent = Lighting
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

--[[ ───────────────────────── Terrain ───────────────────────── ]]

local function setTerrainColors()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 200, 60))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(58, 140, 60))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(230, 196, 120))
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(70, 82, 50))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(45, 38, 40))
	terrain:SetMaterialColor(Enum.Material.CrackedLava, Color3.fromRGB(255, 110, 40))
	terrain:SetMaterialColor(Enum.Material.Asphalt, Color3.fromRGB(40, 32, 78))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(150, 145, 140))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(120, 110, 100))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(120, 95, 65))
	terrain.WaterColor = Color3.fromRGB(40, 150, 180)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
end

local function buildTerrainBase()
	terrain:Clear()
	setTerrainColors()
	-- Sol de l'arène : herbe vive façon Steal An Egg
	fill(CFrame.new(0, -4, (HUB_Z_MAX + HUB_Z_MIN) / 2), Vector3.new(HUB_HALF_X * 2 + 8, 6, HUB_Z_MAX - HUB_Z_MIN + 8), Enum.Material.Ground)
	fill(CFrame.new(0, -0.5, (HUB_Z_MAX + HUB_Z_MIN) / 2), Vector3.new(HUB_HALF_X * 2 + 8, 3, HUB_Z_MAX - HUB_Z_MIN + 8), Enum.Material.Grass)
	task.wait()
	-- Route : socle + pavés, par tronçons (le terrain n'aime pas les blocs géants)
	local z = HUB_Z_MIN + 4
	while z > WORLD_Z_MIN do
		local zNext = math.max(z - 300, WORLD_Z_MIN)
		local mid, len = (z + zNext) / 2, z - zNext
		fill(CFrame.new(0, -4, mid), Vector3.new(ROAD_HALF * 2 + 16, 6, len), Enum.Material.Ground)
		fill(CFrame.new(0, -0.5, mid), Vector3.new(ROAD_HALF * 2 + 16, 3, len), Enum.Material.Grass)
		fill(CFrame.new(0, 0.2, mid), Vector3.new(ROAD_HALF * 2, 2, len), Enum.Material.Cobblestone)
		z = zNext
		task.wait()
	end
end

-- Mur : visible (hauteur WALL_H) + barrière invisible jusqu'à BARRIER_H. Retourne la partie visible.
local function wall(parent: Instance, a: Vector3, b: Vector3, color: Color3, material: Enum.Material, thickness: number?): Part?
	local t = thickness or 6
	local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	if len < 0.5 then
		return nil
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(b.X, 0, b.Z))
	local visible = deco({
		Name = "Wall",
		Size = Vector3.new(t, WALL_H, len + t),
		CFrame = cf + Vector3.new(0, GROUND_Y + WALL_H / 2 - 2, 0),
		Color = color,
		Material = material,
		CanCollide = true,
		Parent = parent,
	})
	part({
		Name = "Barrier",
		Size = Vector3.new(t, BARRIER_H, len + t),
		CFrame = cf + Vector3.new(0, GROUND_Y + BARRIER_H / 2, 0),
		Transparency = 1,
		CanCollide = true,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = parent,
	})
	return visible
end

--[[ ───────────────────────── Bases (Plots) ───────────────────────── ]]

local PLOT_W, PLOT_D = 64, 58

local PLOT_ROW_Z = 220 -- les 8 bases sont alignées au fond de l'arène, entrée face à la place

local function plotCFrame(index: number): (CFrame, number)
	local x = -252 + (index - 1) * 72
	local origin = Vector3.new(x, GROUND_Y, PLOT_ROW_Z)
	-- l'avant de la base regarde la place centrale (−Z)
	local cf = CFrame.lookAt(origin, origin + Vector3.new(0, 0, -1))
	return cf, if x < 0 then -1 else 1
end

local function fence(parent: Instance, cf: CFrame, from: Vector3, to: Vector3)
	local a = (cf * CFrame.new(from)).Position
	local b = (cf * CFrame.new(to)).Position
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local dir = CFrame.lookAt(mid, b)
	for _, h in { 1.4, 2.8 } do
		deco({
			Name = "Rail",
			Size = Vector3.new(0.35, 0.35, len),
			CFrame = dir + Vector3.new(0, h, 0),
			Color = Color3.fromRGB(150, 100, 55),
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
			Parent = parent,
		})
	end
	local posts = math.max(2, math.floor(len / 8) + 1)
	for i = 0, posts - 1 do
		local p = a:Lerp(b, i / (posts - 1))
		deco({
			Name = "Post",
			Size = Vector3.new(0.8, 3.6, 0.8),
			CFrame = CFrame.new(p + Vector3.new(0, 1.8, 0)),
			Color = Color3.fromRGB(120, 78, 42),
			Material = Enum.Material.Wood,
			CanCollide = true,
			Parent = parent,
		})
	end
end

local function surfaceText(host: BasePart, face: Enum.NormalId, text: string, color: Color3, name: string?): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.PixelsPerStud = 40
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.LightInfluence = 0
	sg.Parent = host
	local tl = Instance.new("TextLabel")
	tl.Name = name or "Label"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextScaled = true
	tl.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	tl.TextColor3 = color
	tl.Parent = sg
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(20, 20, 30)
	s.Parent = tl
	return tl
end

local function buildPlot(parent: Folder, index: number)
	local cf, side = plotCFrame(index)
	local plot = Instance.new("Folder")
	plot.Name = "Plot_" .. index
	plot:SetAttribute("PlotIndex", index)

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	-- Le terrain (voxels de 4 studs) dépasse un peu : on le creuse sous la base pour que le plancher soit visible
	terrain:FillBlock(at(0, 2, 0), Vector3.new(PLOT_W + 8, 8, PLOT_D + 8), Enum.Material.Air)
	terrain:FillBlock(at(0, -6, 0), Vector3.new(PLOT_W + 8, 8, PLOT_D + 8), Enum.Material.Ground)

	-- Sol de la base : dalle bois + bordure pierre
	part({
		Name = "PlotPad",
		Size = Vector3.new(PLOT_W, 1, PLOT_D),
		CFrame = at(0, 0, 0),
		Color = Color3.fromRGB(104, 196, 62),
		Material = Enum.Material.Grass,
		Parent = plot,
	})
	deco({
		Name = "PadBorder",
		Size = Vector3.new(PLOT_W + 8, 5, PLOT_D + 8),
		CFrame = at(0, -2.05, 0), -- dessus à +0.45 : juste sous le plancher (+0.5)
		Color = Color3.fromRGB(88, 170, 52),
		Material = Enum.Material.Grass,
		CanCollide = true,
		Parent = plot,
	})
	local hw, hd = PLOT_W / 2, PLOT_D / 2
	-- Clôture : arrière + côtés, ouverture à l'avant (côté route)
	fence(plot, cf, Vector3.new(-hw, 0.5, hd), Vector3.new(hw, 0.5, hd))
	fence(plot, cf, Vector3.new(-hw, 0.5, -hd), Vector3.new(-hw, 0.5, hd))
	fence(plot, cf, Vector3.new(hw, 0.5, -hd), Vector3.new(hw, 0.5, hd))
	fence(plot, cf, Vector3.new(-hw, 0.5, -hd), Vector3.new(-12, 0.5, -hd))
	fence(plot, cf, Vector3.new(12, 0.5, -hd), Vector3.new(hw, 0.5, -hd))

	-- Arche d'entrée + enseigne propriétaire
	for _, x in { -12, 12 } do
		deco({
			Name = "GatePost",
			Size = Vector3.new(1.6, 12, 1.6),
			CFrame = at(x, 6.5, -hd),
			Color = Color3.fromRGB(110, 72, 40),
			Material = Enum.Material.Wood,
			CanCollide = true,
			Parent = plot,
		})
	end
	local sign = part({
		Name = "OwnerSign",
		Size = Vector3.new(22, 4.4, 0.6),
		CFrame = at(0, 11.2, -hd),
		Color = Color3.fromRGB(70, 46, 26),
		Material = Enum.Material.WoodPlanks,
		Parent = plot,
	})
	-- Face avant (côté route) : nom du propriétaire · face arrière : numéro du sanctuaire
	local owner = surfaceText(sign, Enum.NormalId.Front, "Libre", Color3.fromRGB(255, 230, 120), "OwnerLabel")
	owner.Parent.Name = "OwnerGui"
	surfaceText(sign, Enum.NormalId.Back, "🐍 SANCTUAIRE " .. index, Color3.fromRGB(150, 255, 150), "SubLabel")

	-- DropZone : tapis vert lumineux + texte au sol
	local drop = part({
		Name = "DropZone",
		Size = Vector3.new(16, 0.4, 10),
		CFrame = at(0, 0.7, -hd + 9),
		Color = Color3.fromRGB(70, 255, 130),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		Parent = plot,
	})
	drop:SetAttribute("IsDropZone", true)
	surfaceText(drop, Enum.NormalId.Top, "⬇ DÉPOSE ICI ⬇", Color3.fromRGB(20, 70, 30))
	light(drop, Color3.fromRGB(90, 255, 140), 14, 1.2)
	signBillboard(drop, "📥 DÉPÔT", Color3.fromRGB(110, 255, 150), 6)
	-- anneau au sol autour de la zone de dépôt (pulsé côté client par AmbienceController)
	deco({
		Name = "DropRing",
		Size = Vector3.new(19, 0.2, 13),
		CFrame = at(0, 0.55, -hd + 9),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CastShadow = false,
		Parent = plot,
	})

	-- CollectPad : gros bouton rond
	deco({
		Name = "CollectBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 11, 11),
		CFrame = at(-20, 0.6, -hd + 12) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
		CanCollide = true,
		Parent = plot,
	})
	local collect = part({
		Name = "CollectPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 8.5, 8.5),
		CFrame = at(-20, 1.2, -hd + 12) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 255, 110),
		Material = Enum.Material.Neon,
		Parent = plot,
	})
	collect:SetAttribute("IsCollectPad", true)
	signBillboard(collect, "💰 RÉCOLTE", Color3.fromRGB(110, 255, 150), 9)
	-- Coffre au trésor débordant de pièces à côté du bouton de récolte
	local chest = placeTemplate("TreasureChest", plot, (at(-20, 0.5, -hd + 4)).Position, 1.3, select(2, cf:ToEulerAnglesYXZ()), true)
	if chest and chest.PrimaryPart then
		local glint = Instance.new("ParticleEmitter")
		glint.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glint.Rate = 4
		glint.Lifetime = NumberRange.new(0.6, 1)
		glint.Speed = NumberRange.new(0.5, 1.5)
		glint.Size = NumberSequence.new(0.5, 0)
		glint.LightEmission = 1
		glint.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
		glint.Parent = chest.PrimaryPart
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "CashBillboard"
	bb.Size = UDim2.fromOffset(200, 64)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	bb.Enabled = false -- activé par PlotManager quand la base a un propriétaire
	bb.Parent = collect
	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Amount"
	cashLabel.Size = UDim2.fromScale(1, 1)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Text = "$0"
	cashLabel.TextColor3 = Color3.fromRGB(130, 255, 150)
	cashLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	cashLabel.TextScaled = true
	cashLabel.Parent = bb
	local cs = Instance.new("UIStroke")
	cs.Thickness = 3
	cs.Color = Color3.fromRGB(10, 40, 15)
	cs.Parent = cashLabel

	-- Tapis de course (le modèle visuel est posé par PlotManager)
	local tread = part({
		Name = "TreadmillSpot",
		Size = Vector3.new(6, 0.3, 11),
		CFrame = at(20, 0.65, -hd + 12),
		Color = Color3.fromRGB(70, 70, 85),
		Material = Enum.Material.Metal,
		Parent = plot,
	})
	signBillboard(tread, "🏃 TAPIS · Vitesse", Color3.fromRGB(110, 200, 255), 9)

	-- Machine de fusion & autel de rebirth (partie interactive = Part invisible, visuel = modèle)
	local fusion = part({
		Name = "FusionMachine",
		Size = Vector3.new(9, 8, 6),
		CFrame = at(-(hw - 7), 4.5, -6),
		Color = Color3.fromRGB(160, 80, 255),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		Parent = plot,
	})
	fusion:SetAttribute("IsFusion", true)
	if not placeTemplate("FusionMachine", plot, (at(-(hw - 7), 0.5, -6)).Position, 1, math.rad(if side < 0 then -90 else 90), true) then
		-- Repli : socle métal + 3 tubes en verre + orbe violette
		local base = at(-(hw - 7), 0.5, -6)
		deco({ Name = "FusionBase", Size = Vector3.new(9, 2, 6), CFrame = base * CFrame.new(0, 1, 0), Color = Color3.fromRGB(70, 72, 85), Material = Enum.Material.DiamondPlate, CanCollide = true, Parent = plot })
		for i = -1, 1 do
			deco({ Name = "Tube", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.5, 1.8, 1.8), CFrame = base * CFrame.new(i * 2.8, 4.3, 1.4) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 230, 255), Material = Enum.Material.Glass, Transparency = 0.5, Parent = plot })
			deco({ Name = "TubeGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.1, 1.1), CFrame = base * CFrame.new(i * 2.8, 3.8, 1.4) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(170, 90, 255), Material = Enum.Material.Neon, CastShadow = false, Parent = plot })
		end
		local orb = deco({ Name = "FusionOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = base * CFrame.new(0, 3.4, -1.6), Color = Color3.fromRGB(200, 120, 255), Material = Enum.Material.Neon, CastShadow = false, Parent = plot })
		light(orb, Color3.fromRGB(190, 110, 255), 14, 1.6)
	end
	local rebirth = part({
		Name = "RebirthShrine",
		Size = Vector3.new(8, 10, 8),
		CFrame = at(hw - 7, 5.5, -6),
		Color = Color3.fromRGB(180, 120, 255),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		Parent = plot,
	})
	rebirth:SetAttribute("IsRebirth", true)
	if not placeTemplate("RebirthAltar", plot, (at(hw - 7, 0.5, -6)).Position, 1, 0, true) then
		-- Repli : marches de pierre + pilier + cristal flottant
		local base = at(hw - 7, 0.5, -6)
		deco({ Name = "AltarStep", Size = Vector3.new(8, 1, 8), CFrame = base * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(200, 195, 210), Material = Enum.Material.Marble, CanCollide = true, Parent = plot })
		deco({ Name = "AltarStep2", Size = Vector3.new(6, 1, 6), CFrame = base * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(185, 180, 200), Material = Enum.Material.Marble, CanCollide = true, Parent = plot })
		deco({ Name = "AltarPillar", Size = Vector3.new(2.6, 3.5, 2.6), CFrame = base * CFrame.new(0, 3.75, 0), Color = Color3.fromRGB(230, 200, 120), Material = Enum.Material.Foil, CanCollide = true, Parent = plot })
		local crystal = deco({ Name = "AltarCrystal", Size = Vector3.new(1.8, 3.6, 1.8), CFrame = base * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(45), math.rad(10)), Color = Color3.fromRGB(190, 120, 255), Material = Enum.Material.Neon, CastShadow = false, Parent = plot })
		crystal:SetAttribute("Float", true)
	end
	light(rebirth, Color3.fromRGB(190, 120, 255), 16, 1.4)

	-- 20 vivariums (4 rangées × 5) au fond de la base
	local vivs = Instance.new("Folder")
	vivs.Name = "Vivariums"
	vivs.Parent = plot
	for slot = 1, 20 do
		local row = math.floor((slot - 1) / 5)
		local col = (slot - 1) % 5
		local slotCf = at(-22 + col * 11, 0.65, 4 + row * 6.5)
		local slotPart = part({
			Name = "Slot_" .. slot,
			Size = Vector3.new(6, 0.3, 4.5),
			CFrame = slotCf,
			Color = Color3.fromRGB(120, 84, 50),
			Material = Enum.Material.Wood,
			Parent = vivs,
		})
		slotPart:SetAttribute("SlotIndex", slot)
		slotPart:SetAttribute("Occupied", false)
		local tank = placeTemplate("Vivarium", slotPart, slotCf.Position + Vector3.new(0, -0.15, 0), 1, select(2, cf:ToEulerAnglesYXZ()) + math.pi)
		if not tank then
			-- Repli : terrarium en Parts (socle bois, montants, vitres, rocher chauffant, branche)
			deco({ Name = "TankBase", Size = Vector3.new(6, 0.6, 4.5), CFrame = slotCf * CFrame.new(0, 0.45, 0), Color = Color3.fromRGB(110, 72, 40), Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = slotPart })
			for _, c in { { -2.85, -2.1 }, { 2.85, -2.1 }, { -2.85, 2.1 }, { 2.85, 2.1 } } do
				deco({ Name = "TankPost", Size = Vector3.new(0.3, 3.8, 0.3), CFrame = slotCf * CFrame.new(c[1], 2.6, c[2]), Color = Color3.fromRGB(95, 60, 32), Material = Enum.Material.Wood, Parent = slotPart })
			end
			for _, e in { { 0, -2.1, 6, 0.3 }, { 0, 2.1, 6, 0.3 }, { -2.85, 0, 0.3, 4.5 }, { 2.85, 0, 0.3, 4.5 } } do
				deco({ Name = "TankRim", Size = Vector3.new(e[3], 0.3, e[4]), CFrame = slotCf * CFrame.new(e[1], 4.55, e[2]), Color = Color3.fromRGB(95, 60, 32), Material = Enum.Material.Wood, Parent = slotPart })
			end
			deco({ Name = "Glass", Size = Vector3.new(5.6, 3.8, 4.1), CFrame = slotCf * CFrame.new(0, 2.6, 0), Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.8, CastShadow = false, Parent = slotPart })
			deco({ Name = "HeatRock", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 0.9, 1.4), CFrame = slotCf * CFrame.new(1.8, 0.95, 1.2), Color = Color3.fromRGB(150, 120, 100), Material = Enum.Material.Slate, Parent = slotPart })
			deco({ Name = "Branch", Size = Vector3.new(0.3, 0.3, 3.6), CFrame = slotCf * CFrame.new(-1.6, 1.6, 0) * CFrame.Angles(math.rad(20), math.rad(15), 0), Color = Color3.fromRGB(120, 85, 50), Material = Enum.Material.Wood, Parent = slotPart })
		end
	end

	-- Point d'apparition
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlotSpawn"
	spawn.Size = Vector3.new(7, 0.4, 7)
	spawn.CFrame = at(0, 0.7, -hd + 22)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = plot

	-- Lampadaires aux coins avant
	for _, x in { -hw + 2, hw - 2 } do
		deco({
			Name = "LampPost",
			Size = Vector3.new(0.6, 9, 0.6),
			CFrame = at(x, 5, -hd + 2),
			Color = Color3.fromRGB(40, 40, 45),
			Material = Enum.Material.Metal,
			Parent = plot,
		})
		local bulb = deco({
			Name = "Lamp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = at(x, 9.8, -hd + 2),
			Color = Color3.fromRGB(255, 220, 150),
			Material = Enum.Material.Neon,
			Parent = plot,
		})
		light(bulb, Color3.fromRGB(255, 210, 150), 24, 1.2)
	end

	plot.Parent = parent
	return plot
end

--[[ ───────────────────────── Hub ───────────────────────── ]]

local function buildHub(map: Folder, safe: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = map

	-- Murs de l'arène (briques orangées), sortie de ROAD_HALF*2 au centre du mur avant
	local brick = Color3.fromRGB(214, 138, 82)
	local x0, x1 = -HUB_HALF_X, HUB_HALF_X
	wall(hub, Vector3.new(x0, 0, HUB_Z_MAX), Vector3.new(x1, 0, HUB_Z_MAX), brick, Enum.Material.Brick)
	wall(hub, Vector3.new(x0, 0, HUB_Z_MIN), Vector3.new(x0, 0, HUB_Z_MAX), brick, Enum.Material.Brick)
	wall(hub, Vector3.new(x1, 0, HUB_Z_MIN), Vector3.new(x1, 0, HUB_Z_MAX), brick, Enum.Material.Brick)
	wall(hub, Vector3.new(x0, 0, HUB_Z_MIN), Vector3.new(-ROAD_HALF - 3, 0, HUB_Z_MIN), brick, Enum.Material.Brick)
	wall(hub, Vector3.new(ROAD_HALF + 3, 0, HUB_Z_MIN), Vector3.new(x1, 0, HUB_Z_MIN), brick, Enum.Material.Brick)
	-- Liseré vert en haut des murs (comme l'herbe qui dépasse)
	for _, seg in { { x0, HUB_Z_MAX, x1, HUB_Z_MAX }, { x0, HUB_Z_MIN, x0, HUB_Z_MAX }, { x1, HUB_Z_MIN, x1, HUB_Z_MAX } } do
		local a, b = Vector3.new(seg[1], 0, seg[2]), Vector3.new(seg[3], 0, seg[4])
		local mid = (a + b) / 2
		deco({ Name = "WallTop", Size = Vector3.new(8, 2, (b - a).Magnitude + 8), CFrame = CFrame.lookAt(mid, b) + Vector3.new(0, GROUND_Y + WALL_H - 1, 0), Color = Color3.fromRGB(90, 210, 60), Material = Enum.Material.Grass, Parent = hub })
	end

	-- Bande « ZONE SÉCURISÉE » devant les bases (lisible du ciel et du sol)
	local safeZ = PLOT_ROW_Z - PLOT_D / 2 - 18
	deco({ Name = "SafeStripe", Size = Vector3.new(HUB_HALF_X * 2 - 20, 0.2, 1.4), CFrame = CFrame.new(0, GROUND_Y + 0.15, safeZ - 6), Color = Color3.fromRGB(255, 80, 120), Material = Enum.Material.Neon, CastShadow = false, Parent = hub })
	local safeSign = deco({ Name = "SafeSign", Size = Vector3.new(90, 0.2, 9), CFrame = CFrame.new(0, GROUND_Y + 0.12, safeZ), Transparency = 1, Parent = hub })
	surfaceText(safeSign, Enum.NormalId.Top, "🛡️ ZONE SÉCURISÉE 🛡️", Color3.fromRGB(255, 255, 255))

	-- Place centrale : statue dorée sur piédestal + titre
	local plazaZ = 90
	terrain:FillCylinder(CFrame.new(0, 0.5, plazaZ), 2, 34, Enum.Material.Cobblestone)
	local pedestal = deco({
		Name = "StatuePedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 16, 16),
		CFrame = CFrame.new(0, 3, plazaZ) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 195, 185),
		Material = Enum.Material.Marble,
		CanCollide = true,
		Parent = hub,
	})
	local statue = placeTemplate("Celestial_Ouroboros", hub, Vector3.new(0, 5, plazaZ), 3.6, math.rad(180), true)
	if statue then
		for _, d in statue:GetDescendants() do
			if d:IsA("BasePart") then
				d.Material = Enum.Material.Foil
				d.Color = Color3.fromRGB(255, 205, 90)
			end
		end
	end
	light(pedestal, Color3.fromRGB(255, 215, 130), 34, 1.5)
	-- Fontaines-serpents de part et d'autre de la place
	for _, fx in { -70, 70 } do
		local f = placeTemplate("SnakeFountain", hub, Vector3.new(fx, GROUND_Y, plazaZ), 1.4, math.rad(if fx < 0 then 90 else -90), true)
		if f then
			local _, fs = f:GetBoundingBox()
			local spout = deco({ Name = "FountainSpout", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(fx, GROUND_Y + fs.Y * 0.8, plazaZ), Transparency = 1, Parent = f })
			local water = Instance.new("ParticleEmitter")
			water.Texture = "rbxasset://textures/particles/smoke_main.dds"
			water.Rate = 40
			water.Lifetime = NumberRange.new(1, 1.4)
			water.Speed = NumberRange.new(10, 13)
			water.SpreadAngle = Vector2.new(14, 14)
			water.EmissionDirection = Enum.NormalId.Top
			water.Acceleration = Vector3.new(0, -24, 0)
			water.Size = NumberSequence.new(0.8, 1.6)
			water.Color = ColorSequence.new(Color3.fromRGB(170, 230, 255))
			water.Transparency = NumberSequence.new(0.3, 1)
			water.Parent = spout
			light(spout, Color3.fromRGB(150, 220, 255), 18, 1)
		end
	end
	local title = deco({ Name = "Title", Size = Vector3.new(26, 6, 0.4), CFrame = CFrame.new(0, 34, plazaZ), Transparency = 1, Parent = hub })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(460, 100)
	bb.MaxDistance = 400
	bb.Parent = title
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "🐍 STEAL A SNAKE 🐍"
	tl.TextScaled = true
	tl.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	tl.TextColor3 = Color3.fromRGB(255, 225, 90)
	tl.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.fromRGB(60, 30, 10)
	st.Parent = tl

	-- Stand VENDRE (rayé rouge/blanc) : vend le serpent porté sans passer par la base
	local sellPos = Vector3.new(150, GROUND_Y, safeZ - 40)
	local sellFolder = Instance.new("Folder")
	sellFolder.Name = "SellStall"
	sellFolder.Parent = hub
	local counter = deco({ Name = "Counter", Size = Vector3.new(14, 3.5, 4), CFrame = CFrame.new(sellPos + Vector3.new(0, 1.75, 0)), Color = Color3.fromRGB(150, 100, 55), Material = Enum.Material.WoodPlanks, CanCollide = true, Parent = sellFolder })
	for _, x in { -6.5, 6.5 } do
		deco({ Name = "Pole", Size = Vector3.new(0.6, 9, 0.6), CFrame = CFrame.new(sellPos + Vector3.new(x, 4.5, 1.5)), Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.SmoothPlastic, Parent = sellFolder })
	end
	for k = 0, 6 do
		deco({ Name = "Awning", Size = Vector3.new(2.1, 0.4, 7), CFrame = CFrame.new(sellPos + Vector3.new(-6.3 + k * 2.1, 9.2, 0.5)) * CFrame.Angles(math.rad(-14), 0, 0), Color = if k % 2 == 0 then Color3.fromRGB(230, 40, 50) else Color3.fromRGB(250, 250, 250), Material = Enum.Material.Fabric, Parent = sellFolder })
	end
	local sellRing = part({ Name = "SellZone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 22, 22), CFrame = CFrame.new(sellPos + Vector3.new(0, 0.15, -7)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 255, 140), Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false, CastShadow = false, Parent = sellFolder })
	sellRing:SetAttribute("IsSellZone", true)
	signBillboard(counter, "💲 VENDRE", Color3.fromRGB(255, 90, 90), 9)

	-- Grande arche de sortie vers les zones
	for _, x in { -(ROAD_HALF + 6), ROAD_HALF + 6 } do
		deco({ Name = "ArchPillar", Size = Vector3.new(6, 30, 6), CFrame = CFrame.new(x, GROUND_Y + 15, HUB_Z_MIN), Color = Color3.fromRGB(180, 110, 60), Material = Enum.Material.Brick, CanCollide = true, Parent = hub })
	end
	local archTop = deco({ Name = "ArchTop", Size = Vector3.new(ROAD_HALF * 2 + 18, 6, 6), CFrame = CFrame.new(0, GROUND_Y + 33, HUB_Z_MIN), Color = Color3.fromRGB(90, 210, 60), Material = Enum.Material.Grass, Parent = hub })
	surfaceText(archTop, Enum.NormalId.Back, "🐍 LES 15 ZONES ➜", Color3.fromRGB(255, 240, 120))

	-- Palmiers et arbres le long des murs latéraux
	for k = 0, 9 do
		for _, x in { -HUB_HALF_X + 18, HUB_HALF_X - 18 } do
			placeTemplate(if k % 2 == 0 then "PalmTree" else "JungleTree", hub, Vector3.new(x, GROUND_Y, HUB_Z_MIN + 20 + k * 22), rng:NextNumber(0.7, 0.95), rng:NextNumber(0, 6.28))
		end
	end
	-- Fleurs sur l'herbe de la place
	local flowerColors = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 230, 90), Color3.fromRGB(150, 140, 255), Color3.fromRGB(255, 255, 255) }
	for _ = 1, 70 do
		local x = rng:NextNumber(-HUB_HALF_X + 10, HUB_HALF_X - 10)
		local z = rng:NextNumber(HUB_Z_MIN + 10, safeZ - 12)
		if math.abs(x) > ROAD_HALF + 4 and (Vector3.new(x, 0, z) - Vector3.new(0, 0, plazaZ)).Magnitude > 40 then
			deco({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(x, GROUND_Y + 0.4, z), Color = flowerColors[rng:NextInteger(1, #flowerColors)], Material = Enum.Material.SmoothPlastic, CastShadow = false, Parent = hub })
		end
	end

	-- Marqueur logique du hub (zone sûre)
	part({
		Name = "HubFloor",
		Size = Vector3.new(HUB_HALF_X * 2, 1, HUB_Z_MAX - HUB_Z_MIN),
		CFrame = CFrame.new(0, GROUND_Y - 0.5, (HUB_Z_MAX + HUB_Z_MIN) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = safe,
	})
end

--[[ ───────────────────────── Biomes ───────────────────────── ]]

type BiomeStyle = {
	Ground: Enum.Material,
	Trail: Enum.Material,
	Cliff: Enum.Material,
	Props: (folder: Folder, center: Vector3, half: number) -> (),
}

local function jungleProps(folder: Folder, center: Vector3, half: number)
	scatter(16, center, half - 6, 22, function(pos, yaw, s)
		if not placeTemplate("JungleTree", folder, pos, s, yaw) then
			deco({ Name = "Trunk", Size = Vector3.new(2, 12, 2), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(100, 65, 35), Material = Enum.Material.Wood, Parent = folder })
			deco({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(10, 8, 10), CFrame = CFrame.new(pos + Vector3.new(0, 13, 0)), Color = Color3.fromRGB(50, 150, 60), Material = Enum.Material.Grass, Parent = folder })
		end
	end)
	scatter(10, center, half - 6, 22, function(pos, yaw, s)
		placeTemplate("PalmTree", folder, pos, s * 0.9, yaw)
	end)
	scatter(30, center, half - 4, 16, function(pos, _yaw, s)
		deco({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 3, 4) * s,
			CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)),
			Color = Color3.fromRGB(40 + rng:NextInteger(0, 30), 130 + rng:NextInteger(0, 40), 50),
			Material = Enum.Material.Grass,
			Parent = folder,
		})
	end)
	scatter(14, center, half - 6, 18, function(pos, yaw, s)
		deco({
			Name = "Rock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(5, 3.2, 4) * s,
			CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, yaw, 0),
			Color = Color3.fromRGB(95 + rng:NextInteger(0, 20), 100, 90),
			Material = Enum.Material.Slate,
			CanCollide = true,
			Parent = folder,
		})
	end)
	scatter(24, center, half - 4, 14, function(pos, yaw, s)
		for i = 0, 4 do
			deco({
				Name = "Fern",
				Size = Vector3.new(0.3, 0.2, 3.2) * s,
				CFrame = CFrame.new(pos + Vector3.new(0, 0.9 * s, 0)) * CFrame.Angles(0, yaw + i * 1.256, 0) * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.new(0, 0, -1.3 * s),
				Color = Color3.fromRGB(40, 140 + rng:NextInteger(0, 40), 55),
				Material = Enum.Material.Grass,
				CastShadow = false,
				Parent = folder,
			})
		end
	end)
	scatter(7, center, half - 10, 24, function(pos, yaw, s)
		deco({
			Name = "FallenLog",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(9, 2, 2) * s,
			CFrame = CFrame.new(pos + Vector3.new(0, 0.8 * s, 0)) * CFrame.Angles(0, yaw, 0),
			Color = Color3.fromRGB(95, 62, 35),
			Material = Enum.Material.Wood,
			CanCollide = true,
			Parent = folder,
		})
	end)
	local flowerColors = { Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(180, 110, 255), Color3.fromRGB(255, 140, 40) }
	scatter(40, center, half - 4, 12, function(pos, _yaw, _s)
		deco({ Name = "FlowerStem", Size = Vector3.new(0.15, 1.2, 0.15), CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)), Color = Color3.fromRGB(60, 140, 50), Material = Enum.Material.Grass, CastShadow = false, Parent = folder })
		deco({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.5, 0.7), CFrame = CFrame.new(pos + Vector3.new(0, 1.3, 0)), Color = flowerColors[rng:NextInteger(1, #flowerColors)], Material = Enum.Material.SmoothPlastic, CastShadow = false, Parent = folder })
	end)
	-- Torches tiki autour du nid : le nid se repère de loin, même dans la végétation
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * 25, 0, math.sin(a) * 25)
		deco({ Name = "TorchPole", Size = Vector3.new(0.6, 6, 0.6), CFrame = CFrame.new(pos.X, GROUND_Y + 3, pos.Z), Color = Color3.fromRGB(110, 75, 40), Material = Enum.Material.Wood, CanCollide = true, Parent = folder })
		local bowl = deco({ Name = "TorchBowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 1.6, 1.6), CFrame = CFrame.new(pos.X, GROUND_Y + 6.2, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 45, 25), Material = Enum.Material.Wood, Parent = folder })
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Color = Color3.fromRGB(255, 150, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fire.Parent = bowl
		light(bowl, Color3.fromRGB(255, 160, 70), 18, 1.4)
	end
	-- Petite mare
	terrain:FillCylinder(CFrame.new(center + Vector3.new(-40, -0.5, 30)), 3, 10, Enum.Material.Water)
end

local function desertProps(folder: Folder, center: Vector3, half: number)
	for _ = 1, 10 do
		local x = center.X + rng:NextNumber(-half, half)
		local z = center.Z + rng:NextNumber(-half, half)
		if not blocked(x, z, center, 24) then
			terrain:FillBall(Vector3.new(x, -4, z), rng:NextNumber(8, 14), Enum.Material.Sand)
		end
	end
	scatter(18, center, half - 6, 22, function(pos, yaw, s)
		if not placeTemplate("Cactus", folder, pos, s, yaw, true) then
			deco({ Name = "Cactus", Size = Vector3.new(2.5, 8, 2.5), CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)), Color = Color3.fromRGB(60, 150, 70), Parent = folder, CanCollide = true })
		end
	end)
	scatter(12, center, half - 4, 20, function(pos, yaw, s)
		deco({
			Name = "DesertRock",
			Size = Vector3.new(6, 4, 5) * s,
			CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), yaw, rng:NextNumber(-0.3, 0.3)),
			Color = Color3.fromRGB(200, 150, 100),
			Material = Enum.Material.Sandstone,
			CanCollide = true,
			Parent = folder,
		})
	end)
	-- Squelette de serpent géant (côtes)
	for i = 0, 7 do
		local p = center + Vector3.new(38, 0, -30 + i * 4)
		deco({ Name = "Rib", Size = Vector3.new(0.8, 7, 0.8), CFrame = CFrame.new(p + Vector3.new(-2.5, 3, 0)) * CFrame.Angles(0, 0, math.rad(-25)), Color = Color3.fromRGB(240, 232, 215), Material = Enum.Material.SmoothPlastic, Parent = folder })
		deco({ Name = "Rib", Size = Vector3.new(0.8, 7, 0.8), CFrame = CFrame.new(p + Vector3.new(2.5, 3, 0)) * CFrame.Angles(0, 0, math.rad(25)), Color = Color3.fromRGB(240, 232, 215), Material = Enum.Material.SmoothPlastic, Parent = folder })
	end
end

local function swampProps(folder: Folder, center: Vector3, half: number)
	for _ = 1, 8 do
		local x = center.X + rng:NextNumber(-half + 8, half - 8)
		local z = center.Z + rng:NextNumber(-half + 8, half - 8)
		if not blocked(x, z, center, 26) then
			local r = rng:NextNumber(6, 11)
			terrain:FillCylinder(CFrame.new(x, -0.6, z), 2.6, r, Enum.Material.Air)
			terrain:FillCylinder(CFrame.new(x, -1.2, z), 1.8, r, Enum.Material.Water)
			for _ = 1, 3 do
				deco({
					Name = "LilyPad",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.15, 2.6, 2.6),
					CFrame = CFrame.new(x + rng:NextNumber(-r * 0.6, r * 0.6), 0.05, z + rng:NextNumber(-r * 0.6, r * 0.6)) * CFrame.Angles(0, 0, math.rad(90)),
					Color = Color3.fromRGB(70, 160, 70),
					Parent = folder,
				})
			end
		end
	end
	scatter(14, center, half - 6, 22, function(pos, yaw, s)
		if not placeTemplate("SwampTree", folder, pos, s, yaw) then
			deco({ Name = "DeadTree", Size = Vector3.new(2, 14, 2), CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0.1, yaw, 0.1), Color = Color3.fromRGB(60, 50, 45), Material = Enum.Material.Wood, Parent = folder })
		end
	end)
	scatter(14, center, half - 4, 16, function(pos, yaw, s)
		local m = placeTemplate("Mushrooms", folder, pos, s * 0.8, yaw)
		local host: BasePart? = if m then m:FindFirstChildWhichIsA("BasePart", true) else nil
		if not host then
			host = deco({ Name = "Mushroom", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1.2, 2.4), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color = Color3.fromRGB(170, 90, 255), Material = Enum.Material.Neon, Parent = folder })
		end
		if host and rng:NextNumber() < 0.6 then
			light(host, Color3.fromRGB(160, 110, 255), 12, 1)
		end
	end)
end

local function volcanoProps(folder: Folder, center: Vector3, half: number)
	for _ = 1, 7 do
		local x = center.X + rng:NextNumber(-half + 8, half - 8)
		local z = center.Z + rng:NextNumber(-half + 8, half - 8)
		if not blocked(x, z, center, 26) then
			local r = rng:NextNumber(5, 9)
			terrain:FillCylinder(CFrame.new(x, 0.6, z), 1.6, r, Enum.Material.CrackedLava)
			local glow = deco({
				Name = "LavaGlow",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, r * 1.6, r * 1.6),
				CFrame = CFrame.new(x, GROUND_Y + 0.4, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 120, 30),
				Material = Enum.Material.Neon,
				Transparency = 0.35,
				CastShadow = false,
				Parent = folder,
			})
			light(glow, Color3.fromRGB(255, 120, 40), 22, 2)
			local att = Instance.new("Attachment")
			att.Parent = glow
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "Embers"
			pe.Rate = 6
			pe.Lifetime = NumberRange.new(1.5, 3)
			pe.Speed = NumberRange.new(3, 7)
			pe.SpreadAngle = Vector2.new(25, 25)
			pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20))
			pe.LightEmission = 1
			pe.Size = NumberSequence.new(0.3, 0)
			pe.Parent = att
		end
	end
	scatter(16, center, half - 6, 22, function(pos, yaw, s)
		if not placeTemplate("LavaSpire", folder, pos, s, yaw, true) then
			deco({ Name = "Spire", Size = Vector3.new(5, 12, 5), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) * CFrame.Angles(0, yaw, 0.1), Color = Color3.fromRGB(40, 32, 34), Material = Enum.Material.Basalt, CanCollide = true, Parent = folder })
		end
	end)
end

local function cosmicProps(folder: Folder, center: Vector3, half: number)
	scatter(18, center, half - 6, 22, function(pos, yaw, s)
		local m = placeTemplate("CosmicCrystal", folder, pos, s, yaw, true)
		local host: BasePart? = if m then m:FindFirstChildWhichIsA("BasePart", true) else nil
		if not host then
			host = deco({ Name = "Crystal", Size = Vector3.new(2.5, 9, 2.5), CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0.2, yaw, 0.15), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, Parent = folder })
		end
		if host and rng:NextNumber() < 0.5 then
			light(host, Color3.fromRGB(120, 180, 255), 18, 1.2)
		end
	end)
	-- Rochers flottants avec anneaux lumineux
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * 50, 22 + rng:NextNumber(0, 14), math.sin(a) * 50)
		local rock = deco({
			Name = "FloatingRock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 5, 7) * rng:NextNumber(0.7, 1.4),
			CFrame = CFrame.new(p),
			Color = Color3.fromRGB(50, 40, 90),
			Material = Enum.Material.Slate,
			Parent = folder,
		})
		rock:SetAttribute("Float", true)
		deco({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 11, 11),
			CFrame = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, math.rad(90)),
			Color = Color3.fromRGB(150, 110, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CastShadow = false,
			Parent = folder,
		}):SetAttribute("Float", true)
	end
	local sky = deco({ Name = "StarDust", Size = Vector3.new(140, 1, 140), CFrame = CFrame.new(center + Vector3.new(0, 40, 0)), Transparency = 1, Parent = folder })
	local att = Instance.new("Attachment")
	att.Parent = sky
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Stars"
	pe.Rate = 25
	pe.Lifetime = NumberRange.new(4, 7)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255), Color3.fromRGB(190, 140, 255))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.Parent = att
end

-- Petits constructeurs réutilisés par les décors des zones
local function pine(folder: Folder, pos: Vector3, s: number, leaf: Color3, snow: boolean)
	deco({ Name = "PineTrunk", Size = Vector3.new(1.4, 6, 1.4) * s, CFrame = CFrame.new(pos + Vector3.new(0, 3 * s, 0)), Color = Color3.fromRGB(95, 65, 40), Material = Enum.Material.Wood, CanCollide = true, Parent = folder })
	for k = 0, 2 do
		local w = (7 - k * 2) * s
		deco({ Name = "PineCone", Shape = Enum.PartType.Ball, Size = Vector3.new(w, 4 * s, w), CFrame = CFrame.new(pos + Vector3.new(0, (6 + k * 3) * s, 0)), Color = leaf, Material = Enum.Material.Grass, Parent = folder })
		if snow then
			deco({ Name = "Snow", Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.7, 1.4 * s, w * 0.7), CFrame = CFrame.new(pos + Vector3.new(0, (7.6 + k * 3) * s, 0)), Color = Color3.fromRGB(245, 250, 255), Material = Enum.Material.Snow, Parent = folder })
		end
	end
end

local function giantMushroom(folder: Folder, pos: Vector3, s: number, cap: Color3, glow: boolean)
	deco({ Name = "MushStem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9 * s, 2.4 * s, 2.4 * s), CFrame = CFrame.new(pos + Vector3.new(0, 4.5 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.SmoothPlastic, CanCollide = true, Parent = folder })
	local c = deco({ Name = "MushCap", Shape = Enum.PartType.Ball, Size = Vector3.new(11, 5, 11) * s, CFrame = CFrame.new(pos + Vector3.new(0, 9.5 * s, 0)), Color = cap, Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic, CanCollide = true, Parent = folder })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		deco({ Name = "CapDot", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 0.8, 1.6) * s, CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 3 * s, 11.6 * s, math.sin(a) * 3 * s)), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Parent = folder })
	end
	if glow then
		light(c, cap, 20, 1.2)
	end
end

local function crystalCluster(folder: Folder, pos: Vector3, s: number, color: Color3)
	for k = 0, 4 do
		local h = rng:NextNumber(5, 12) * s
		local p = deco({ Name = "Crystal", Size = Vector3.new(1.6 * s, h, 1.6 * s), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2) * s, h / 2, rng:NextNumber(-2, 2) * s)) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), k * 1.2, rng:NextNumber(-0.35, 0.35)), Color = color, Material = Enum.Material.Glass, CanCollide = true, Parent = folder })
		p.Transparency = 0.15
		if k == 0 then
			light(p, color, 22, 1.4)
		end
	end
end

local function cloud(folder: Folder, pos: Vector3, s: number)
	for k = 0, 4 do
		deco({ Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 6, 8) * s * rng:NextNumber(0.7, 1.2), CFrame = CFrame.new(pos + Vector3.new((k - 2) * 3.5 * s, rng:NextNumber(0, 2) * s, rng:NextNumber(-2, 2) * s)), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic, Parent = folder })
	end
end

local function tundraProps(folder: Folder, center: Vector3, half: number)
	scatter(26, center, half - 6, 24, function(pos, _yaw, s)
		pine(folder, pos, s, Color3.fromRGB(40, 100, 70), true)
	end)
	scatter(10, center, half - 6, 22, function(pos, yaw, s)
		crystalCluster(folder, pos, s * 0.8, Color3.fromRGB(170, 230, 255))
		local _ = yaw
	end)
	scatter(6, center, half - 10, 26, function(pos, _yaw, s)
		for k = 0, 2 do
			deco({ Name = "Snowman", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * (4 - k) * s, CFrame = CFrame.new(pos + Vector3.new(0, (1.6 + k * 2.6) * s, 0)), Color = Color3.fromRGB(250, 252, 255), Material = Enum.Material.Snow, CanCollide = true, Parent = folder })
		end
	end)
	terrain:FillCylinder(CFrame.new(center + Vector3.new(50, -0.5, -40)), 2, 18, Enum.Material.Ice)
end

local function bambooProps(folder: Folder, center: Vector3, half: number)
	scatter(40, center, half - 4, 22, function(pos, _yaw, s)
		for k = 0, 3 do
			local h = rng:NextNumber(12, 22) * s
			local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
			deco({ Name = "Bamboo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.9, 0.9), CFrame = CFrame.new(pos + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120 + k * 10, 180, 70), Material = Enum.Material.SmoothPlastic, CanCollide = true, Parent = folder })
		end
	end)
	scatter(10, center, half - 8, 26, function(pos, _yaw, s)
		deco({ Name = "LanternPost", Size = Vector3.new(0.5, 6, 0.5) * s, CFrame = CFrame.new(pos + Vector3.new(0, 3 * s, 0)), Color = Color3.fromRGB(60, 40, 30), Material = Enum.Material.Wood, Parent = folder })
		local lantern = deco({ Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 2, 1.6) * s, CFrame = CFrame.new(pos + Vector3.new(0, 6.6 * s, 0)), Color = Color3.fromRGB(230, 50, 40), Material = Enum.Material.Neon, Parent = folder })
		light(lantern, Color3.fromRGB(255, 120, 80), 16, 1.2)
	end)
	terrain:FillCylinder(CFrame.new(center + Vector3.new(-45, -0.5, 35)), 2.5, 16, Enum.Material.Water)
end

local function canyonProps(folder: Folder, center: Vector3, half: number)
	for _ = 1, 9 do
		local x = center.X + rng:NextNumber(-half + 12, half - 12)
		local z = center.Z + rng:NextNumber(-half + 12, half - 12)
		if not blocked(x, z, center, 30) then
			local h = rng:NextNumber(16, 34)
			fill(CFrame.new(x, h / 2, z), Vector3.new(rng:NextNumber(10, 18), h, rng:NextNumber(10, 18)), Enum.Material.Sandstone)
		end
	end
	scatter(16, center, half - 6, 22, function(pos, yaw, s)
		placeTemplate("Cactus", folder, pos, s, yaw, true)
	end)
	scatter(10, center, half - 6, 20, function(pos, yaw, s)
		deco({ Name = "Skull", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 1.6, 2.2) * s, CFrame = CFrame.new(pos + Vector3.new(0, 0.7 * s, 0)) * CFrame.Angles(0, yaw, 0), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.SmoothPlastic, Parent = folder })
	end)
end

local function mushroomProps(folder: Folder, center: Vector3, half: number)
	local caps = { Color3.fromRGB(230, 40, 50), Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(90, 230, 255) }
	scatter(22, center, half - 8, 26, function(pos, _yaw, s)
		giantMushroom(folder, pos, s * rng:NextNumber(0.8, 1.6), caps[rng:NextInteger(1, #caps)], rng:NextNumber() < 0.4)
	end)
	scatter(18, center, half - 4, 16, function(pos, yaw, s)
		placeTemplate("Mushrooms", folder, pos, s * 0.8, yaw)
	end)
end

local function reefProps(folder: Folder, center: Vector3, half: number)
	local corals = { Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 160, 60), Color3.fromRGB(150, 90, 255), Color3.fromRGB(80, 220, 200) }
	scatter(30, center, half - 6, 20, function(pos, yaw, s)
		local c = corals[rng:NextInteger(1, #corals)]
		for k = 0, 4 do
			local h = rng:NextNumber(3, 7) * s
			deco({ Name = "Coral", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.8 * s, 0.8 * s), CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw + k * 1.3, 0) * CFrame.Angles(math.rad(rng:NextNumber(-35, 35)), 0, math.rad(90)) * CFrame.new(h / 2, 0, 0), Color = c, Material = Enum.Material.SmoothPlastic, Parent = folder })
			deco({ Name = "CoralTip", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4) * s, CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw + k * 1.3, 0) * CFrame.Angles(math.rad(rng:NextNumber(-35, 35)), 0, math.rad(90)) * CFrame.new(h, 0, 0), Color = c, Material = Enum.Material.Neon, Parent = folder })
		end
	end)
	scatter(10, center, half - 6, 24, function(pos, yaw, s)
		placeTemplate("PalmTree", folder, pos, s, yaw)
	end)
	for _ = 1, 4 do
		local x = center.X + rng:NextNumber(-half + 20, half - 20)
		local z = center.Z + rng:NextNumber(-half + 20, half - 20)
		if not blocked(x, z, center, 30) then
			terrain:FillCylinder(CFrame.new(x, -0.5, z), 2.5, rng:NextNumber(8, 14), Enum.Material.Water)
		end
	end
end

local function crystalProps(folder: Folder, center: Vector3, half: number)
	local colors = { Color3.fromRGB(110, 220, 255), Color3.fromRGB(220, 120, 255), Color3.fromRGB(255, 140, 200), Color3.fromRGB(140, 255, 210) }
	scatter(30, center, half - 6, 22, function(pos, _yaw, s)
		crystalCluster(folder, pos, s * rng:NextNumber(0.8, 1.6), colors[rng:NextInteger(1, #colors)])
	end)
	scatter(14, center, half - 6, 22, function(pos, yaw, s)
		placeTemplate("CosmicCrystal", folder, pos, s, yaw, true)
	end)
	for _ = 1, 10 do
		local x = center.X + rng:NextNumber(-half + 10, half - 10)
		local z = center.Z + rng:NextNumber(-half + 10, half - 10)
		if not blocked(x, z, center, 28) then
			fill(CFrame.new(x, 6, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(6, 14, 6), Enum.Material.Slate)
		end
	end
end

local function graveyardProps(folder: Folder, center: Vector3, half: number)
	scatter(40, center, half - 6, 20, function(pos, yaw, s)
		deco({ Name = "Tombstone", Size = Vector3.new(3, 4, 0.8) * s, CFrame = CFrame.new(pos + Vector3.new(0, 2 * s, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), yaw, 0), Color = Color3.fromRGB(120, 125, 135), Material = Enum.Material.Slate, CanCollide = true, Parent = folder })
	end)
	scatter(14, center, half - 6, 24, function(pos, yaw, s)
		if not placeTemplate("SwampTree", folder, pos, s, yaw) then
			deco({ Name = "DeadTree", Size = Vector3.new(2, 14, 2), CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)), Color = Color3.fromRGB(50, 45, 45), Material = Enum.Material.Wood, Parent = folder })
		end
	end)
	scatter(12, center, half - 6, 18, function(pos, _yaw, s)
		local pumpkin = deco({ Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1.8, 2.4) * s, CFrame = CFrame.new(pos + Vector3.new(0, 0.9 * s, 0)), Color = Color3.fromRGB(255, 130, 20), Material = Enum.Material.SmoothPlastic, Parent = folder })
		light(pumpkin, Color3.fromRGB(255, 150, 50), 12, 1.2)
	end)
end

local function templeProps(folder: Folder, center: Vector3, half: number)
	-- Pyramide à degrés au fond de la zone
	local base = center + Vector3.new(0, 0, -half + 40)
	for k = 0, 5 do
		local w = 44 - k * 7
		deco({ Name = "PyramidStep", Size = Vector3.new(w, 4, w), CFrame = CFrame.new(base + Vector3.new(0, GROUND_Y + 2 + k * 4, 0)), Color = Color3.fromRGB(170 - k * 6, 140 - k * 6, 90), Material = Enum.Material.Cobblestone, CanCollide = true, Parent = folder })
	end
	scatter(14, center, half - 8, 26, function(pos, _yaw, s)
		deco({ Name = "Pillar", Size = Vector3.new(3, 14, 3) * s, CFrame = CFrame.new(pos + Vector3.new(0, 7 * s, 0)), Color = Color3.fromRGB(190, 170, 120), Material = Enum.Material.Limestone, CanCollide = true, Parent = folder })
	end)
	scatter(14, center, half - 6, 24, function(pos, yaw, s)
		placeTemplate("JungleTree", folder, pos, s, yaw)
	end)
end

local function toxicProps(folder: Folder, center: Vector3, half: number)
	for _ = 1, 8 do
		local x = center.X + rng:NextNumber(-half + 10, half - 10)
		local z = center.Z + rng:NextNumber(-half + 10, half - 10)
		if not blocked(x, z, center, 28) then
			local r = rng:NextNumber(5, 9)
			local pool = deco({ Name = "ToxicPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r * 2, r * 2), CFrame = CFrame.new(x, GROUND_Y + 0.15, z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 255, 40), Material = Enum.Material.Neon, Transparency = 0.2, CastShadow = false, Parent = folder })
			light(pool, Color3.fromRGB(150, 255, 40), 20, 1.6)
		end
	end
	scatter(24, center, half - 6, 20, function(pos, yaw, s)
		local barrel = deco({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 2.2, 2.2) * s, CFrame = CFrame.new(pos + Vector3.new(0, 1.7 * s, 0)) * CFrame.Angles(0, yaw, math.rad(if rng:NextNumber() < 0.3 then 0 else 90)), Color = Color3.fromRGB(230, 200, 30), Material = Enum.Material.Metal, CanCollide = true, Parent = folder })
		local _ = barrel
	end)
	scatter(12, center, half - 6, 24, function(pos, yaw, s)
		deco({ Name = "DeadTree", Size = Vector3.new(1.6, 12, 1.6) * s, CFrame = CFrame.new(pos + Vector3.new(0, 6 * s, 0)) * CFrame.Angles(0.15, yaw, 0.1), Color = Color3.fromRGB(60, 55, 45), Material = Enum.Material.Wood, Parent = folder })
	end)
end

local function skyProps(folder: Folder, center: Vector3, half: number)
	scatter(20, center, half - 6, 24, function(pos, _yaw, s)
		cloud(folder, pos + Vector3.new(0, 2, 0), s)
	end)
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		cloud(folder, center + Vector3.new(math.cos(a) * 70, 30 + rng:NextNumber(0, 20), math.sin(a) * 70), rng:NextNumber(1.2, 2))
	end
	scatter(12, center, half - 8, 26, function(pos, _yaw, s)
		deco({ Name = "GoldPillar", Size = Vector3.new(3, 16, 3) * s, CFrame = CFrame.new(pos + Vector3.new(0, 8 * s, 0)), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Marble, CanCollide = true, Parent = folder })
		local orb = deco({ Name = "PillarOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6) * s, CFrame = CFrame.new(pos + Vector3.new(0, 17.5 * s, 0)), Color = Color3.fromRGB(255, 240, 180), Material = Enum.Material.Neon, Parent = folder })
		light(orb, Color3.fromRGB(255, 230, 160), 18, 1.4)
	end)
	-- Arc-en-ciel au-dessus de l'entrée
	for k = 0, 5 do
		for step = 0, 18 do
			local a = step / 18 * math.pi
			local r = 60 - k * 2.5
			deco({ Name = "Rainbow", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(center + Vector3.new(math.cos(a) * r, math.sin(a) * r * 0.6, half - 30)), Color = Color3.fromHSV(k / 6, 0.7, 1), Material = Enum.Material.Neon, Transparency = 0.25, CastShadow = false, Parent = folder })
		end
	end
end

local STYLES: { [string]: BiomeStyle } = {
	Jungle = { Ground = Enum.Material.LeafyGrass, Trail = Enum.Material.Ground, Cliff = Enum.Material.Rock, Props = jungleProps },
	Desert = { Ground = Enum.Material.Sand, Trail = Enum.Material.Sandstone, Cliff = Enum.Material.Sandstone, Props = desertProps },
	Swamp = { Ground = Enum.Material.Mud, Trail = Enum.Material.Ground, Cliff = Enum.Material.Rock, Props = swampProps },
	Tundra = { Ground = Enum.Material.Snow, Trail = Enum.Material.Ice, Cliff = Enum.Material.Glacier, Props = tundraProps },
	Bamboo = { Ground = Enum.Material.Grass, Trail = Enum.Material.Ground, Cliff = Enum.Material.Rock, Props = bambooProps },
	Canyon = { Ground = Enum.Material.Sandstone, Trail = Enum.Material.Ground, Cliff = Enum.Material.Sandstone, Props = canyonProps },
	Mushroom = { Ground = Enum.Material.Limestone, Trail = Enum.Material.Ground, Cliff = Enum.Material.Rock, Props = mushroomProps },
	Reef = { Ground = Enum.Material.Salt, Trail = Enum.Material.Sand, Cliff = Enum.Material.Rock, Props = reefProps },
	Volcano = { Ground = Enum.Material.Basalt, Trail = Enum.Material.Basalt, Cliff = Enum.Material.Basalt, Props = volcanoProps },
	Crystal = { Ground = Enum.Material.Glacier, Trail = Enum.Material.Slate, Cliff = Enum.Material.Slate, Props = crystalProps },
	Graveyard = { Ground = Enum.Material.Slate, Trail = Enum.Material.Ground, Cliff = Enum.Material.Slate, Props = graveyardProps },
	Temple = { Ground = Enum.Material.Brick, Trail = Enum.Material.Cobblestone, Cliff = Enum.Material.Rock, Props = templeProps },
	Toxic = { Ground = Enum.Material.Pavement, Trail = Enum.Material.Ground, Cliff = Enum.Material.Rock, Props = toxicProps },
	Sky = { Ground = Enum.Material.Ice, Trail = Enum.Material.Marble, Cliff = Enum.Material.Ice, Props = skyProps },
	Cosmic = { Ground = Enum.Material.Asphalt, Trail = Enum.Material.Asphalt, Cliff = Enum.Material.Slate, Props = cosmicProps },
}

local function buildBiome(parent: Folder, cfg: any)
	local folder = Instance.new("Folder")
	folder.Name = cfg.Id
	folder:SetAttribute("BiomeOrder", cfg.Order)
	folder:SetAttribute("GateSpeed", cfg.GateSpeed)
	folder:SetAttribute("GateCash", cfg.GateCash)
	local style = STYLES[cfg.Theme] or STYLES.Jungle
	terrain:SetMaterialColor(cfg.Ground, cfg.GroundColor)
	local center = Vector3.new(cfg.Center.X, GROUND_Y, cfg.Center.Z)
	local half = cfg.Size.X / 2

	-- Sol du biome + sentier central
	fill(CFrame.new(center.X, -1, center.Z), Vector3.new(cfg.Size.X, 4, cfg.Size.Z), style.Ground)
	fill(CFrame.new(center.X, -0.6, center.Z), Vector3.new(ROAD_HALF * 2, 4, cfg.Size.Z), style.Trail)

	-- Falaises de chaque côté (décor) + murs d'enceinte avec ouvertures pour la route (anti-chute)
	for _, sx in { -1, 1 } do
		local z = center.Z - half
		while z <= center.Z + half do
			terrain:FillBall(Vector3.new(sx * (CANYON_HALF_X - 4 + rng:NextNumber(0, 6)), rng:NextNumber(2, 10), z), rng:NextNumber(10, 16), style.Cliff)
			z += 10
		end
	end
	task.wait()
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder
	local wallColor = cfg.GroundColor:Lerp(Color3.new(0, 0, 0), 0.25)
	local zF, zB = center.Z + half, center.Z - half
	local xL, xR = center.X - half - 3, center.X + half + 3
	wall(walls, Vector3.new(xL, 0, zF), Vector3.new(xL, 0, zB), wallColor, Enum.Material.Rock)
	wall(walls, Vector3.new(xR, 0, zF), Vector3.new(xR, 0, zB), wallColor, Enum.Material.Rock)
	for _, zz in { zF, zB } do
		if not (cfg.Order == #BiomesConfig and zz == zB) then
			wall(walls, Vector3.new(xL, 0, zz), Vector3.new(-ROAD_HALF - 3, 0, zz), wallColor, Enum.Material.Rock)
			wall(walls, Vector3.new(ROAD_HALF + 3, 0, zz), Vector3.new(xR, 0, zz), wallColor, Enum.Material.Rock)
		else
			wall(walls, Vector3.new(xL, 0, zz), Vector3.new(xR, 0, zz), wallColor, Enum.Material.Rock)
		end
	end

	-- Marqueurs logiques
	part({
		Name = "Floor",
		Size = Vector3.new(cfg.Size.X, 1, cfg.Size.Z),
		CFrame = CFrame.new(center.X, GROUND_Y - 0.5, center.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	local boundary = part({
		Name = "BiomeBoundary",
		Size = Vector3.new(cfg.Size.X * 0.85, 30, cfg.Size.Z * 0.85),
		CFrame = CFrame.new(center + Vector3.new(0, 15, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})
	boundary:SetAttribute("AggroRadius", cfg.AggroRadius)

	-- Nid + points d'apparition
	local nestFolder = Instance.new("Folder")
	nestFolder.Name = "Nest"
	nestFolder.Parent = folder
	local nest = placeTemplate("Nest", nestFolder, center, 1, rng:NextNumber(0, 6.28))
	local nestTop = GROUND_Y + 1.6
	if nest then
		nest.Name = "NestMesh"
		local cf, size = nest:GetBoundingBox()
		nestTop = cf.Position.Y + size.Y * 0.5 - 1.4 -- au ras du rebord : serpents visibles de loin
	else
		part({
			Name = "NestMesh",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 22, 22),
			CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(110, 76, 40),
			Material = Enum.Material.Wood,
			Parent = nestFolder,
		})
		nestTop = GROUND_Y + 2.5
	end
	local spawns = Instance.new("Folder")
	spawns.Name = "SpawnPoints"
	spawns.Parent = nestFolder
	for i = 1, 12 do
		local ang = (i / 12) * math.pi * 2
		local r = if i % 2 == 0 then 7 else 4
		local p = part({
			Name = "SP_" .. i,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(center + Vector3.new(math.cos(ang) * r, nestTop - GROUND_Y, math.sin(ang) * r)) * CFrame.Angles(0, -ang + math.pi / 2, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = spawns,
		})
		p:SetAttribute("SpawnIndex", i)
	end

	part({
		Name = "GuardianSpawn",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(center + Vector3.new(0, 3, -32)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = folder,
	})

	-- Porte-crâne à l'entrée (côté hub)
	local entranceZ = center.Z + half
	local gateDeco = Instance.new("Folder")
	gateDeco.Name = "Entrance"
	gateDeco.Parent = folder
	if not placeTemplate("SkullGate", gateDeco, Vector3.new(0, GROUND_Y, entranceZ + 2), 1.35, 0, false) then
		for _, x in { -16, 16 } do
			deco({ Name = "Fang", Size = Vector3.new(4, 20, 4), CFrame = CFrame.new(x, 10, entranceZ + 2) * CFrame.Angles(0, 0, math.rad(x > 0 and 8 or -8)), Color = Color3.fromRGB(235, 228, 210), Parent = gateDeco, CanCollide = true })
		end
	end
	local banner = deco({
		Name = "BiomeBanner",
		Size = Vector3.new(30, 5, 0.5),
		CFrame = CFrame.new(0, 27, entranceZ + 4),
		Transparency = 1,
		Parent = gateDeco,
	})
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(360, 110)
	bb.MaxDistance = 220
	bb.Parent = banner
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.6)
	name.BackgroundTransparency = 1
	name.Text = cfg.Name
	name.TextScaled = true
	name.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Parent = bb
	local ns = Instance.new("UIStroke")
	ns.Thickness = 4
	ns.Color = Color3.fromRGB(20, 20, 30)
	ns.Parent = name
	local req = Instance.new("TextLabel")
	req.Name = "Requirement"
	req.Size = UDim2.fromScale(1, 0.38)
	req.Position = UDim2.fromScale(0, 0.62)
	req.BackgroundTransparency = 1
	req.Text = if cfg.Order > 1 then string.format("⚡ %d Vitesse  ·  💵 $%s", cfg.GateSpeed, tostring(cfg.GateCash)) else "⚠️ Gardien : " .. cfg.GuardianName
	req.TextScaled = true
	req.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	req.TextColor3 = Color3.fromRGB(255, 220, 120)
	req.Parent = bb
	local rs = Instance.new("UIStroke")
	rs.Thickness = 3
	rs.Color = Color3.fromRGB(20, 20, 30)
	rs.Parent = req

	if cfg.Order > 1 then
		local gate = part({
			Name = "BiomeGate",
			Size = Vector3.new(ROAD_HALF * 2 + 4, 18, 2),
			CFrame = CFrame.new(0, GROUND_Y + 9, entranceZ + 2),
			Color = Color3.fromRGB(120, 200, 255),
			Material = Enum.Material.ForceField,
			Parent = folder,
		})
		gate:SetAttribute("RequiredSpeed", cfg.GateSpeed)
		gate:SetAttribute("RequiredCash", cfg.GateCash)
		gate:SetAttribute("Order", cfg.Order)
		-- déblocage PAR JOUEUR : le serveur repousse les joueurs non qualifiés (GateService),
		-- le client affiche la porte ouverte/fermée selon son propre MaxBiome (AmbienceController)
		gate.CanCollide = false
	end

	-- Ligne de sécurité visible au sol (sortie du biome = zone sûre)
	for _, z in { entranceZ + 8, center.Z - half - 8 } do
		deco({
			Name = "SafeLine",
			Size = Vector3.new(ROAD_HALF * 2, 0.15, 1.2),
			CFrame = CFrame.new(0, GROUND_Y + 0.25, z),
			Color = Color3.fromRGB(90, 255, 160),
			Material = Enum.Material.Neon,
			CastShadow = false,
			Parent = folder,
		})
	end

	style.Props(folder, center, half)
	folder.Parent = parent
	return folder
end

--[[ ───────────────────────── Route (lampadaires) ───────────────────────── ]]

-- Route entre l'arène et les zones : haies murées des deux côtés + lampadaires.
local function buildRoadLamps(safe: Folder)
	local hedge = Color3.fromRGB(70, 160, 60)
	-- tronçons de route hors zones
	local segments: { { number } } = {}
	local zTop = HUB_Z_MIN
	for _, cfg in BiomesConfig do
		local front = cfg.Center.Z + cfg.Size.Z / 2
		table.insert(segments, { zTop, front })
		zTop = cfg.Center.Z - cfg.Size.Z / 2
	end
	for _, seg in segments do
		for _, x in { -(ROAD_HALF + 3), ROAD_HALF + 3 } do
			local v = wall(safe, Vector3.new(x, 0, seg[1]), Vector3.new(x, 0, seg[2]), hedge, Enum.Material.Grass, 4)
			if v then
				v.Size = Vector3.new(v.Size.X, 10, v.Size.Z)
				v.CFrame = v.CFrame - Vector3.new(0, WALL_H / 2 - 5, 0)
			end
		end
		local z = seg[1] - 6
		while z > seg[2] + 2 do
			for _, x in { -(ROAD_HALF - 1), ROAD_HALF - 1 } do
				deco({ Name = "RoadLampPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = CFrame.new(x, GROUND_Y + 4, z), Color = Color3.fromRGB(35, 35, 40), Material = Enum.Material.Metal, Parent = safe })
				local bulb = deco({ Name = "RoadLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(x, GROUND_Y + 8.6, z), Color = Color3.fromRGB(140, 255, 190), Material = Enum.Material.Neon, Parent = safe })
				light(bulb, Color3.fromRGB(140, 255, 190), 22, 1.1)
			end
			z -= 14
		end
	end
end

--[[ ───────────────────────── Build ───────────────────────── ]]

function MapBuilder.build()
	MapBuilder.setupPhysics()
	MapBuilder.setupLighting()

	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	buildTerrainBase()

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	local safe = Instance.new("Folder")
	safe.Name = "SafeZone"
	safe.Parent = map
	-- Zone sûre logique (route entière ; les biomes sont exclus par GuardianAI)
	part({
		Name = "SafePath",
		Size = Vector3.new(ROAD_HALF * 2 + 8, 1, HUB_Z_MAX - WORLD_Z_MIN),
		CFrame = CFrame.new(0, GROUND_Y - 0.5, (HUB_Z_MAX + WORLD_Z_MIN) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = safe,
	}):SetAttribute("IsSafeZone", true)

	buildHub(map, safe)
	task.wait()

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	for i = 1, 8 do
		buildPlot(plots, i)
		task.wait()
	end

	local biomes = Instance.new("Folder")
	biomes.Name = "Biomes"
	biomes.Parent = map
	for _, cfg in BiomesConfig do
		buildBiome(biomes, cfg)
		task.wait()
	end

	buildRoadLamps(safe)
	return map
end

return MapBuilder
