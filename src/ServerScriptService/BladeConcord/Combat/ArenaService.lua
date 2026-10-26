--!strict
--[[
	Arènes GDD §6 — art direction showcase (matériaux, lighting, props, hazards lisibles).
	- Obsidian Pit : lave glow + cendres
	- Sanctum des Deux Astres : vents bleutés + colonnes
	- Trône d'Éclipse : estrade + trône Constructible
	- Quai Mirage : quai teal + panneaux mirage
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))

local ArenaService = {}

export type ArenaId = "ObsidianPit" | "SanctumAstres" | "TroneEclipse" | "QuaiMirage"

local ARENA_ORDER: { ArenaId } = { "ObsidianPit", "SanctumAstres", "TroneEclipse", "QuaiMirage" }

local activeId: ArenaId = "ObsidianPit"
local arenasRoot: Folder? = nil
local built: { [ArenaId]: Folder } = {}
local hazardAccumulator = 0

local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	anchored: boolean?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = if anchored == nil then true else anchored
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function neonGlow(parent: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Parent = parent
	return light
end

local function ashEmitter(parent: BasePart)
	local att = Instance.new("Attachment")
	att.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Ash"
	pe.Rate = 12
	pe.Lifetime = NumberRange.new(2, 4)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(40, 40)
	pe.Acceleration = Vector3.new(0, 1.5, 0)
	pe.Size = NumberSequence.new(0.15, 0.05)
	pe.Transparency = NumberSequence.new(0.3, 1)
	pe.Color = ColorSequence.new(Color3.fromRGB(80, 70, 60), Color3.fromRGB(40, 35, 30))
	pe.LockedToPart = false
	pe.Parent = att
end

local function applyArenaLighting(id: ArenaId)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	local bloom = Lighting:FindFirstChild("BC_Bloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "BC_Bloom"
		bloom.Parent = Lighting
	end
	local cc = Lighting:FindFirstChild("BC_ArenaCC")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BC_ArenaCC"
		cc.Parent = Lighting
	end
	local bloomFx = bloom :: BloomEffect
	local ccFx = cc :: ColorCorrectionEffect

	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5

	if id == "ObsidianPit" then
		Lighting.ClockTime = 21.5
		Lighting.Brightness = 1.4
		Lighting.Ambient = Color3.fromRGB(40, 22, 18)
		Lighting.OutdoorAmbient = Color3.fromRGB(55, 30, 22)
		Lighting.FogColor = Color3.fromRGB(40, 18, 12)
		Lighting.FogEnd = 220
		atmo.Density = 0.38
		atmo.Color = Color3.fromRGB(90, 40, 25)
		atmo.Decay = Color3.fromRGB(30, 10, 8)
		atmo.Glare = 0.2
		atmo.Haze = 1.5
		bloomFx.Intensity = 0.7
		bloomFx.Size = 28
		bloomFx.Threshold = 0.75
		ccFx.TintColor = Color3.fromRGB(255, 220, 200)
		ccFx.Contrast = 0.08
		ccFx.Saturation = 0.05
	elseif id == "SanctumAstres" then
		Lighting.ClockTime = 17.2
		Lighting.Brightness = 2.2
		Lighting.Ambient = Color3.fromRGB(70, 75, 95)
		Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 150)
		Lighting.FogEnd = 400
		atmo.Density = 0.22
		atmo.Color = Color3.fromRGB(180, 190, 220)
		atmo.Decay = Color3.fromRGB(90, 100, 140)
		atmo.Glare = 0.8
		atmo.Haze = 0.6
		bloomFx.Intensity = 0.45
		bloomFx.Threshold = 0.9
		ccFx.TintColor = Color3.fromRGB(230, 235, 255)
		ccFx.Contrast = 0.05
		ccFx.Saturation = 0.1
	elseif id == "TroneEclipse" then
		Lighting.ClockTime = 23
		Lighting.Brightness = 1.1
		Lighting.Ambient = Color3.fromRGB(28, 22, 45)
		Lighting.OutdoorAmbient = Color3.fromRGB(40, 30, 60)
		Lighting.FogColor = Color3.fromRGB(20, 12, 35)
		Lighting.FogEnd = 180
		atmo.Density = 0.42
		atmo.Color = Color3.fromRGB(50, 35, 80)
		atmo.Decay = Color3.fromRGB(15, 8, 30)
		atmo.Glare = 0.1
		atmo.Haze = 2
		bloomFx.Intensity = 0.55
		bloomFx.Threshold = 0.7
		ccFx.TintColor = Color3.fromRGB(210, 190, 255)
		ccFx.Contrast = 0.12
		ccFx.Saturation = -0.05
	else -- QuaiMirage
		Lighting.ClockTime = 7.5
		Lighting.Brightness = 2.4
		Lighting.Ambient = Color3.fromRGB(50, 80, 90)
		Lighting.OutdoorAmbient = Color3.fromRGB(100, 140, 150)
		Lighting.FogColor = Color3.fromRGB(120, 170, 180)
		Lighting.FogEnd = 280
		atmo.Density = 0.28
		atmo.Color = Color3.fromRGB(140, 190, 200)
		atmo.Decay = Color3.fromRGB(60, 100, 110)
		atmo.Glare = 1.2
		atmo.Haze = 1.4
		bloomFx.Intensity = 0.5
		bloomFx.Threshold = 0.85
		ccFx.TintColor = Color3.fromRGB(210, 245, 250)
		ccFx.Contrast = 0.06
		ccFx.Saturation = 0.12
	end
end

local function getArenasRoot(): Folder
	if arenasRoot and arenasRoot.Parent then
		return arenasRoot
	end
	local arenas = Workspace:FindFirstChild("Arenas")
	if not arenas then
		arenas = Instance.new("Folder")
		arenas.Name = "Arenas"
		arenas.Parent = Workspace
	end
	arenasRoot = arenas :: Folder
	return arenasRoot
end

local function buildSpawns(folder: Folder, offset: Vector3)
	local spawnA = part("SpawnA", Vector3.new(4, 0.4, 4), CFrame.new(offset + Vector3.new(-18, 1.3, 0)), Color3.fromRGB(90, 160, 220), folder, Enum.Material.Neon)
	spawnA.Transparency = 0.55
	spawnA.CanCollide = false
	neonGlow(spawnA, Color3.fromRGB(90, 160, 220), 0.8, 10)
	CollectionService:AddTag(spawnA, CombatConfig.Tags.ArenaSpawnA)

	local spawnB = part("SpawnB", Vector3.new(4, 0.4, 4), CFrame.new(offset + Vector3.new(18, 1.3, 0)), Color3.fromRGB(220, 100, 90), folder, Enum.Material.Neon)
	spawnB.Transparency = 0.55
	spawnB.CanCollide = false
	neonGlow(spawnB, Color3.fromRGB(220, 100, 90), 0.8, 10)
	CollectionService:AddTag(spawnB, CombatConfig.Tags.ArenaSpawnB)
end

local function buildObsidianPit(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ObsidianPit"
	folder.Parent = parent
	folder:SetAttribute("DisplayName", "Obsidian Pit — Creuset de Lave")
	folder:SetAttribute("OffsetX", 0)
	folder:SetAttribute("ArtPass", 2)

	local offset = Vector3.new(0, 0, 0)
	local basalt = Color3.fromRGB(42, 40, 48)
	local basaltLite = Color3.fromRGB(70, 68, 78)
	local ember = Color3.fromRGB(255, 110, 40)
	local lava = Color3.fromRGB(255, 90, 30)
	local size = Vector3.new(64, 2, 64)
	local wallH = 14

	local platform = part("Platform", size, CFrame.new(offset), basalt, folder, Enum.Material.Basalt)
	platform.Reflectance = 0.05
	-- Dallage central
	part("Inlay", Vector3.new(28, 0.25, 28), CFrame.new(offset + Vector3.new(0, 1.1, 0)), basaltLite, folder, Enum.Material.Slate)
	part("Ring", Vector3.new(size.X + 10, 1.2, size.Z + 10), CFrame.new(offset + Vector3.new(0, -0.6, 0)), Color3.fromRGB(28, 26, 32), folder, Enum.Material.Rock)

	local halfX, halfZ = size.X / 2, size.Z / 2
	for _, wall in {
		part("WallN", Vector3.new(size.X + 6, wallH, 3), CFrame.new(offset + Vector3.new(0, wallH / 2, -halfZ - 1.5)), basalt, folder, Enum.Material.Basalt),
		part("WallS", Vector3.new(size.X + 6, wallH, 3), CFrame.new(offset + Vector3.new(0, wallH / 2, halfZ + 1.5)), basalt, folder, Enum.Material.Basalt),
		part("WallE", Vector3.new(3, wallH, size.Z), CFrame.new(offset + Vector3.new(halfX + 1.5, wallH / 2, 0)), basalt, folder, Enum.Material.Basalt),
		part("WallW", Vector3.new(3, wallH, size.Z), CFrame.new(offset + Vector3.new(-halfX - 1.5, wallH / 2, 0)), basalt, folder, Enum.Material.Basalt),
	} do
		wall.Material = Enum.Material.Basalt
	end

	-- Piliers d'angle
	for _, corner in { Vector3.new(-28, 5, -28), Vector3.new(28, 5, -28), Vector3.new(-28, 5, 28), Vector3.new(28, 5, 28) } do
		local pillar = part("Pillar", Vector3.new(4, 10, 4), CFrame.new(offset + corner), basaltLite, folder, Enum.Material.Rock)
		local torch = part("Ember", Vector3.new(1.2, 1.2, 1.2), CFrame.new(offset + corner + Vector3.new(0, 6, 0)), ember, folder, Enum.Material.Neon)
		torch.CanCollide = false
		neonGlow(torch, ember, 2.5, 18)
		ashEmitter(torch)
	end

	local lavaPart = part("LavaBorder", Vector3.new(size.X + 28, 1.5, size.Z + 28), CFrame.new(offset + Vector3.new(0, -3.2, 0)), lava, folder, Enum.Material.Neon)
	lavaPart.Transparency = 0.15
	neonGlow(lavaPart, lava, 3, 40)
	lavaPart:SetAttribute("Dps", CombatConfig.Arena.LavaDps)
	lavaPart:SetAttribute("HazardKind", "Lava")
	CollectionService:AddTag(lavaPart, CombatConfig.Tags.KillPlane)
	CollectionService:AddTag(lavaPart, CombatConfig.Tags.Hazard)

	-- Lave intérieure (anneau visible au bord plateforme)
	local lavaInner = part("LavaLip", Vector3.new(size.X + 4, 0.6, size.Z + 4), CFrame.new(offset + Vector3.new(0, 0.2, 0)), ember, folder, Enum.Material.Neon)
	lavaInner.Transparency = 0.45
	lavaInner.CanCollide = false
	neonGlow(lavaInner, ember, 1.2, 20)

	buildSpawns(folder, offset)
	return folder
end

local function buildSanctum(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "SanctumAstres"
	folder.Parent = parent
	folder:SetAttribute("DisplayName", "Sanctum des Deux Astres")
	folder:SetAttribute("ArtPass", 2)
	local ox = 120
	folder:SetAttribute("OffsetX", ox)
	local offset = Vector3.new(ox, 0, 0)
	local marble = Color3.fromRGB(210, 205, 195)
	local gold = Color3.fromRGB(190, 160, 90)
	local sky = Color3.fromRGB(140, 190, 230)
	local size = Vector3.new(56, 2, 56)

	part("Platform", size, CFrame.new(offset), marble, folder, Enum.Material.Marble)
	local inlayStar = part("InlayStar", Vector3.new(16, 0.3, 16), CFrame.new(offset + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, math.rad(45), 0), gold, folder, Enum.Material.Metal)
	inlayStar.Reflectance = 0.4
	part("WallN", Vector3.new(size.X, 12, 2.5), CFrame.new(offset + Vector3.new(0, 6, -29)), marble, folder, Enum.Material.Limestone)
	part("WallS", Vector3.new(size.X, 12, 2.5), CFrame.new(offset + Vector3.new(0, 6, 29)), marble, folder, Enum.Material.Limestone)

	-- Colonnes latérales
	for z = -18, 18, 12 do
		for _, xSign in { -1, 1 } do
			local col = part(
				"Column",
				Vector3.new(2.5, 14, 2.5),
				CFrame.new(offset + Vector3.new(xSign * 22, 8, z)),
				marble,
				folder,
				Enum.Material.Marble
			)
			local cap = part("Cap", Vector3.new(3.2, 1, 3.2), CFrame.new(offset + Vector3.new(xSign * 22, 15.5, z)), gold, folder, Enum.Material.Metal)
			cap.Reflectance = 0.3
			col.Material = Enum.Material.Marble
		end
	end

	-- Deux « astres » lumineux
	local sun = part("AstreDawn", Vector3.new(5, 5, 5), CFrame.new(offset + Vector3.new(-10, 18, 0)), Color3.fromRGB(255, 200, 120), folder, Enum.Material.Neon)
	sun.Shape = Enum.PartType.Ball
	sun.CanCollide = false
	neonGlow(sun, Color3.fromRGB(255, 200, 120), 3, 35)
	local moon = part("AstreDusk", Vector3.new(4, 4, 4), CFrame.new(offset + Vector3.new(10, 17, 0)), Color3.fromRGB(160, 180, 255), folder, Enum.Material.Neon)
	moon.Shape = Enum.PartType.Ball
	moon.CanCollide = false
	neonGlow(moon, Color3.fromRGB(160, 180, 255), 2.5, 30)

	local windL = part("WindWest", Vector3.new(8, 6, 40), CFrame.new(offset + Vector3.new(-22, 4, 0)), sky, folder, Enum.Material.ForceField)
	windL.Transparency = 0.55
	windL.CanCollide = false
	windL:SetAttribute("HazardKind", "Wind")
	windL:SetAttribute("WindDir", Vector3.new(1, 0, 0))
	CollectionService:AddTag(windL, CombatConfig.Tags.Hazard)
	neonGlow(windL, sky, 0.6, 16)
	ashEmitter(windL) -- particules vent (réutilise emitter)

	local windR = part("WindEast", Vector3.new(8, 6, 40), CFrame.new(offset + Vector3.new(22, 4, 0)), sky, folder, Enum.Material.ForceField)
	windR.Transparency = 0.55
	windR.CanCollide = false
	windR:SetAttribute("HazardKind", "Wind")
	windR:SetAttribute("WindDir", Vector3.new(-1, 0, 0))
	CollectionService:AddTag(windR, CombatConfig.Tags.Hazard)
	neonGlow(windR, sky, 0.6, 16)

	buildSpawns(folder, offset)
	return folder
end

local function buildThrone(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TroneEclipse"
	folder.Parent = parent
	folder:SetAttribute("DisplayName", "Trône d'Éclipse")
	folder:SetAttribute("ArtPass", 2)
	local ox = 240
	folder:SetAttribute("OffsetX", ox)
	local offset = Vector3.new(ox, 0, 0)
	local dark = Color3.fromRGB(32, 28, 42)
	local violet = Color3.fromRGB(90, 55, 140)
	local void = Color3.fromRGB(18, 14, 28)
	local size = Vector3.new(60, 2, 60)

	part("Platform", size, CFrame.new(offset), dark, folder, Enum.Material.Slate)
	part("OuterRing", Vector3.new(size.X + 8, 0.8, size.Z + 8), CFrame.new(offset + Vector3.new(0, -0.4, 0)), void, folder, Enum.Material.Rock)

	-- Estrade centrale (anti-camp)
	local dais = part("Dais", Vector3.new(16, 3.5, 16), CFrame.new(offset + Vector3.new(0, 2.7, 0)), violet, folder, Enum.Material.Neon)
	dais.Transparency = 0.35
	dais:SetAttribute("HazardKind", "ThronePressure")
	dais:SetAttribute("Dps", CombatConfig.Arena.ThronePressureDps)
	CollectionService:AddTag(dais, CombatConfig.Tags.Hazard)
	neonGlow(dais, violet, 1.8, 22)

	-- Trône Constructible
	local seat = part("ThroneSeat", Vector3.new(5, 1.2, 4), CFrame.new(offset + Vector3.new(0, 5.2, -1)), void, folder, Enum.Material.Metal)
	local back = part("ThroneBack", Vector3.new(5.5, 8, 1.2), CFrame.new(offset + Vector3.new(0, 9, -2.8)), void, folder, Enum.Material.Metal)
	back.Reflectance = 0.15
	part("ThroneArmL", Vector3.new(1, 2.5, 3.5), CFrame.new(offset + Vector3.new(-2.8, 6.5, -1)), Color3.fromRGB(50, 40, 70), folder, Enum.Material.Metal)
	part("ThroneArmR", Vector3.new(1, 2.5, 3.5), CFrame.new(offset + Vector3.new(2.8, 6.5, -1)), Color3.fromRGB(50, 40, 70), folder, Enum.Material.Metal)
	local crown = part("ThroneCrown", Vector3.new(6, 1.5, 1.5), CFrame.new(offset + Vector3.new(0, 13.5, -2.8)), Color3.fromRGB(160, 120, 255), folder, Enum.Material.Neon)
	crown.CanCollide = false
	neonGlow(crown, Color3.fromRGB(160, 120, 255), 2.2, 20)
	seat.CanCollide = true

	-- Obélisques
	for _, xz in { Vector3.new(-22, 0, -22), Vector3.new(22, 0, -22), Vector3.new(-22, 0, 22), Vector3.new(22, 0, 22) } do
		local ob = part("Obelisk", Vector3.new(2.5, 16, 2.5), CFrame.new(offset + Vector3.new(xz.X, 9, xz.Z)), dark, folder, Enum.Material.Basalt)
		local tip = part("ObeliskTip", Vector3.new(1.5, 2, 1.5), CFrame.new(offset + Vector3.new(xz.X, 18, xz.Z)), Color3.fromRGB(140, 100, 220), folder, Enum.Material.Neon)
		tip.CanCollide = false
		neonGlow(tip, Color3.fromRGB(140, 100, 220), 1.5, 14)
		ob.Material = Enum.Material.Basalt
	end

	buildSpawns(folder, offset)
	return folder
end

local function buildMirage(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "QuaiMirage"
	folder.Parent = parent
	folder:SetAttribute("DisplayName", "Quai Mirage")
	folder:SetAttribute("ArtPass", 2)
	local ox = 360
	folder:SetAttribute("OffsetX", ox)
	local offset = Vector3.new(ox, 0, 0)
	local teal = Color3.fromRGB(55, 110, 120)
	local sand = Color3.fromRGB(180, 170, 140)
	local water = Color3.fromRGB(40, 120, 140)
	local mirage = Color3.fromRGB(140, 220, 230)

	part("Platform", Vector3.new(58, 2, 40), CFrame.new(offset), teal, folder, Enum.Material.Concrete)
	part("DockEdge", Vector3.new(60, 1, 3), CFrame.new(offset + Vector3.new(0, 0.5, -20)), sand, folder, Enum.Material.WoodPlanks)
	part("DockEdgeS", Vector3.new(60, 1, 3), CFrame.new(offset + Vector3.new(0, 0.5, 20)), sand, folder, Enum.Material.WoodPlanks)

	local waterPlane = part("Water", Vector3.new(90, 1, 70), CFrame.new(offset + Vector3.new(0, -2.5, 0)), water, folder, Enum.Material.Glass)
	waterPlane.Transparency = 0.35
	waterPlane.CanCollide = false
	neonGlow(waterPlane, water, 0.8, 30)

	-- Piliers de quai
	for x = -24, 24, 12 do
		part("Pier", Vector3.new(1.5, 6, 1.5), CFrame.new(offset + Vector3.new(x, -1, -22)), Color3.fromRGB(90, 70, 50), folder, Enum.Material.Wood)
		part("PierS", Vector3.new(1.5, 6, 1.5), CFrame.new(offset + Vector3.new(x, -1, 22)), Color3.fromRGB(90, 70, 50), folder, Enum.Material.Wood)
	end

	local lantern = part("Lantern", Vector3.new(2, 2, 2), CFrame.new(offset + Vector3.new(0, 8, 0)), mirage, folder, Enum.Material.Neon)
	lantern.Shape = Enum.PartType.Ball
	lantern.CanCollide = false
	neonGlow(lantern, mirage, 2.5, 28)

	local panels = Instance.new("Folder")
	panels.Name = "MiragePanels"
	panels.Parent = folder

	for i = 1, 3 do
		local panel = part(
			"Panel" .. i,
			Vector3.new(10, 9, 1.2),
			CFrame.new(offset + Vector3.new(-15 + i * 10, 5.5, if i % 2 == 0 then -8 else 8)),
			mirage,
			panels,
			Enum.Material.ForceField
		)
		panel.Transparency = 0.35
		panel:SetAttribute("HazardKind", "MiragePanel")
		panel:SetAttribute("PanelIndex", i)
		CollectionService:AddTag(panel, CombatConfig.Tags.Hazard)
		neonGlow(panel, mirage, 1.2, 14)
		-- Cadre
		local frame = part(
			"Frame" .. i,
			Vector3.new(11, 10, 0.4),
			CFrame.new(offset + Vector3.new(-15 + i * 10, 5.5, if i % 2 == 0 then -8.8 else 8.8)),
			Color3.fromRGB(80, 100, 110),
			panels,
			Enum.Material.Metal
		)
		frame.CanCollide = false
	end

	buildSpawns(folder, offset)
	return folder
end

function ArenaService.ensureAll(): Folder
	local root = getArenasRoot()
	-- Purge greybox / art pass < 2
	for _, child in root:GetChildren() do
		if child:IsA("Folder") then
			local name = child.Name
			local pass = child:GetAttribute("ArtPass")
			if pass ~= 2 then
				if built[name :: any] then
					built[name :: any] = nil
				end
				child:Destroy()
			elseif built[name :: any] == nil then
				built[name :: any] = child
			end
		end
	end

	if not built.ObsidianPit or not built.ObsidianPit.Parent then
		built.ObsidianPit = buildObsidianPit(root)
	end
	if not built.SanctumAstres or not built.SanctumAstres.Parent then
		built.SanctumAstres = buildSanctum(root)
	end
	if not built.TroneEclipse or not built.TroneEclipse.Parent then
		built.TroneEclipse = buildThrone(root)
	end
	if not built.QuaiMirage or not built.QuaiMirage.Parent then
		built.QuaiMirage = buildMirage(root)
	end
	applyArenaLighting(activeId)
	return root
end

function ArenaService.ensureObsidianPit(): Folder
	ArenaService.ensureAll()
	return built.ObsidianPit
end

function ArenaService.list(): { ArenaId }
	return table.clone(ARENA_ORDER)
end

function ArenaService.getActiveId(): ArenaId
	return activeId
end

function ArenaService.setActive(id: ArenaId)
	ArenaService.ensureAll()
	if built[id] then
		activeId = id
		applyArenaLighting(id)
	end
end

function ArenaService.getSpawnCFrames(): (CFrame, CFrame)
	ArenaService.ensureAll()
	local folder = built[activeId]
	local ox = if folder then (folder:GetAttribute("OffsetX") :: number?) or 0 else 0
	local a = CFrame.new(ox - 18, 4, 0) * CFrame.Angles(0, math.rad(90), 0)
	local b = CFrame.new(ox + 18, 4, 0) * CFrame.Angles(0, math.rad(-90), 0)
	return a, b
end

function ArenaService.getDisplayName(): string
	local folder = built[activeId]
	if folder then
		local n = folder:GetAttribute("DisplayName")
		if typeof(n) == "string" then
			return n
		end
	end
	return activeId
end

function ArenaService.stepHazards(dt: number)
	hazardAccumulator += dt
	if hazardAccumulator < 0.2 then
		return
	end
	local step = hazardAccumulator
	hazardAccumulator = 0

	local folder = built[activeId]
	if not folder then
		return
	end

	for _, fighter in FighterState.getAll() do
		if fighter.actionId == "Dead" or not fighter.character then
			continue
		end
		local hrp = fighter.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end

		for _, inst in CollectionService:GetTagged(CombatConfig.Tags.Hazard) do
			if not inst:IsDescendantOf(folder) or not inst:IsA("BasePart") then
				continue
			end
			local kind = inst:GetAttribute("HazardKind")
			local inZone = (hrp.Position - inst.Position).Magnitude < (inst.Size.Magnitude * 0.45)

			if kind == "Lava" then
				if hrp.Position.Y < 1 then
					local dps = (inst:GetAttribute("Dps") :: number?) or CombatConfig.Arena.LavaDps
					local dmg = math.min(dps * step, CombatConfig.MaxHp / CombatConfig.Arena.MinLethalFullHpSeconds * step)
					fighter.hp = math.max(0, fighter.hp - dmg)
					local humanoid = fighter.character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = fighter.hp
					end
					if fighter.hp <= 0 then
						fighter.actionId = "Dead"
					end
				end
			elseif kind == "Wind" and inZone then
				local dir = inst:GetAttribute("WindDir")
				if typeof(dir) == "Vector3" and not hrp.Anchored then
					hrp.AssemblyLinearVelocity += dir.Unit * CombatConfig.Arena.WindForce * step
				end
			elseif kind == "ThronePressure" and inZone then
				local dps = (inst:GetAttribute("Dps") :: number?) or CombatConfig.Arena.ThronePressureDps
				local dmg = math.min(dps * step, CombatConfig.MaxHp / CombatConfig.Arena.MinLethalFullHpSeconds * step)
				fighter.hp = math.max(0, fighter.hp - dmg)
				local humanoid = fighter.character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = fighter.hp
				end
				if fighter.hp <= 0 then
					fighter.actionId = "Dead"
				end
			elseif kind == "MiragePanel" then
				local idx = (inst:GetAttribute("PanelIndex") :: number?) or 1
				local phase = (os.clock() / CombatConfig.Arena.MiragePanelLifetime + idx * 0.3) % 1
				inst.CanCollide = phase < 0.55
				inst.Transparency = if phase < 0.55 then 0.2 else 0.85
				local light = inst:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = if phase < 0.55 then 1.2 else 0.2
				end
			end
		end
	end
end

return ArenaService
