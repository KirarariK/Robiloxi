--!strict
--[[
	Arènes Blade Concord — 8 floors vastes (ArtPass 6) autour du croiseur.
	L1–4 gauche / R1–4 droite — offsets LobbyConfig.ArenaLayout (ox, oz).
	Floors ~120² pour dash + Force. Baie Glass lobby spectate.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Theme = require(Shared:WaitForChild("Theme"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))

local ArenaService = {}

export type ArenaId =
	"ObsidianPit"
	| "SanctumAstres"
	| "TroneEclipse"
	| "QuaiMirage"
	| "ForgeAube"
	| "SpireCrepuscule"
	| "RecifNeant"
	| "CourCristal"

local ARENA_ORDER: { ArenaId } = {
	"ObsidianPit",
	"SanctumAstres",
	"TroneEclipse",
	"QuaiMirage",
	"ForgeAube",
	"SpireCrepuscule",
	"RecifNeant",
	"CourCristal",
}
local ART_PASS = 7

-- Accents partagés (cohérence 4 arènes)
local CONCORD_STEEL = Color3.fromRGB(72, 88, 110)

local activeId: ArenaId = "ObsidianPit"
local arenasRoot: Folder? = nil
local built: { [ArenaId]: Folder } = {}
local hazardAccumulator = 0
local lobbyBuilt: Instance? = nil
local LobbyBuilder = require(script.Parent.Parent:WaitForChild("Lobby"):WaitForChild("LobbyBuilder"))
local LobbyConfig = require(script.Parent.Parent:WaitForChild("Lobby"):WaitForChild("LobbyConfig"))
local LobbyLighting = require(script.Parent.Parent:WaitForChild("Lobby"):WaitForChild("LobbyLighting"))

-- Pool croiseur 8 arènes (World tag BC_MatchArena + BC_ArenaIndex 1..8)
local worldByIndex: { [number]: Instance } = {}
local activePoolIndex = 1
local activeWorldRoot: Instance? = nil
local poolRotation = 0
local occupiedPoolIndex: number? = nil

local function arenaOffset(id: string): (Vector3, string)
	for _, entry in LobbyConfig.ArenaLayout do
		if entry.id == id then
			return Vector3.new(entry.ox, 0, entry.oz), entry.displayName
		end
	end
	return Vector3.new(0, 0, 0), id
end

local function spawnSep(): number
	return LobbyConfig.ArenaSpawnSep or 32
end

local function floorSize(): number
	return LobbyConfig.ArenaFloorSize or 120
end

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

--[[ Plateforme vaste + muret bas (dash/Force) — commun aux 8 arènes. ]]
local function vastDeck(folder: Folder, offset: Vector3, color: Color3, material: Enum.Material?): BasePart
	local s = floorSize()
	local deck = part("VastDeck", Vector3.new(s, 2.2, s), CFrame.new(offset), color, folder, material or Enum.Material.Basalt)
	deck.Reflectance = 0.06
	part(
		"DeckRim",
		Vector3.new(s + 6, 1.2, s + 6),
		CFrame.new(offset + Vector3.new(0, -0.4, 0)),
		Color3.fromRGB(28, 30, 40),
		folder,
		Enum.Material.Metal
	)
	local half = s * 0.5
	local wallH = 4
	for _, wall in {
		{ "WN", Vector3.new(s + 4, wallH, 2), Vector3.new(0, wallH * 0.5, -half - 1) },
		{ "WS", Vector3.new(s + 4, wallH, 2), Vector3.new(0, wallH * 0.5, half + 1) },
		{ "WE", Vector3.new(2, wallH, s), Vector3.new(half + 1, wallH * 0.5, 0) },
		{ "WW", Vector3.new(2, wallH, s), Vector3.new(-half - 1, wallH * 0.5, 0) },
	} do
		part(wall[1] :: string, wall[2] :: Vector3, CFrame.new(offset + (wall[3] :: Vector3)), Color3.fromRGB(40, 44, 56), folder, Enum.Material.Metal)
	end
	folder:SetAttribute("FloorSize", s)
	return deck
end

local function neonGlow(parent: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Parent = parent
	return light
end

local function ashEmitter(parent: BasePart, rate: number?, colorA: Color3?, colorB: Color3?)
	local att = Instance.new("Attachment")
	att.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Ash"
	local requested = rate or 12
	local cap = CombatConfig.Fx.ArenaAshRateMax
	pe.Rate = if requested > cap then cap else requested
	pe.Lifetime = NumberRange.new(2, 4)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(40, 40)
	pe.Acceleration = Vector3.new(0, 1.5, 0)
	pe.Size = NumberSequence.new(0.15, 0.05)
	pe.Transparency = NumberSequence.new(0.3, 1)
	pe.Color = ColorSequence.new(colorA or Color3.fromRGB(80, 70, 60), colorB or Color3.fromRGB(40, 35, 30))
	pe.LockedToPart = false
	pe.Parent = att
end

--[[ Drift permanent dust / embers (Pass 3 ambiance) — rate bas, lifetime longue. ]]
local function driftField(
	folder: Folder,
	offset: Vector3,
	colorA: Color3,
	colorB: Color3,
	rate: number,
	upAccel: number,
	name: string?
)
	local host = part(
		name or "DriftHost",
		Vector3.new(48, 1, 48),
		CFrame.new(offset + Vector3.new(0, 6, 0)),
		colorA,
		folder,
		Enum.Material.ForceField
	)
	host.Transparency = 1
	host.CanCollide = false
	host.CastShadow = false
	local att = Instance.new("Attachment")
	att.Parent = host
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Drift"
	local driftCap = CombatConfig.Fx.ArenaDriftRateMax
	pe.Rate = if rate > driftCap then driftCap else rate
	pe.Lifetime = NumberRange.new(4.5, 8)
	pe.Speed = NumberRange.new(0.15, 0.9)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0.2, upAccel, 0.15)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-20, 20)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.5, 0.22),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Color = ColorSequence.new(colorA, colorB)
	pe.LightEmission = 0.35
	pe.LightInfluence = 0.2
	pe.LockedToPart = false
	pe.Parent = att
	return host
end

--[[ Fog volumétrique léger (Parts ForceField semi-transparentes). ]]
local function fogBank(folder: Folder, offset: Vector3, color: Color3, count: number)
	for i = 1, count do
		local fog = part(
			"FogBank" .. i,
			Vector3.new(10 + (i % 3) * 4, 3 + (i % 2), 8 + (i % 4) * 2),
			CFrame.new(offset + Vector3.new(((i * 17) % 40) - 20, 2 + (i % 3), ((i * 13) % 36) - 18)),
			color,
			folder,
			Enum.Material.ForceField
		)
		fog.Transparency = 0.82
		fog.CanCollide = false
		fog.CastShadow = false
	end
end

--[[ Debris scatter au sol (lisibilité arène). ]]
local function scatterDebris(folder: Folder, offset: Vector3, color: Color3, material: Enum.Material, n: number)
	for i = 1, n do
		local sx = 0.6 + (i % 4) * 0.35
		local sz = 0.5 + (i % 3) * 0.4
		local px = ((i * 23) % 50) - 25
		local pz = ((i * 31) % 48) - 24
		-- Évite le centre de duel
		if math.abs(px) < 6 and math.abs(pz) < 6 then
			px += 10
		end
		local d = part(
			"Debris" .. i,
			Vector3.new(sx, 0.35 + (i % 3) * 0.15, sz),
			CFrame.new(offset + Vector3.new(px, 1.25, pz)) * CFrame.Angles(0, math.rad(i * 37), math.rad((i % 5) * 8)),
			color,
			folder,
			material
		)
		d.CanCollide = false
	end
end

--[[ Hazard label Billboard lisible (pas de lexique SW). ]]
local function hazardLabel(host: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HazardLabel"
	gui.Size = UDim2.fromOffset(140, 28)
	gui.StudsOffset = Vector3.new(0, host.Size.Y * 0.55 + 1.5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	label.BackgroundTransparency = 0.35
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = label
end

--[[ Anneau de duel central + rails acier Concord — même langage sur les 4 maps. ]]
local function coherenceKit(folder: Folder, offset: Vector3, accent: Color3)
	local ring = part(
		"DuelRing",
		Vector3.new(22, 0.2, 22),
		CFrame.new(offset + Vector3.new(0, 1.15, 0)),
		accent,
		folder,
		Enum.Material.Neon
	)
	ring.Transparency = 0.72
	ring.CanCollide = false
	ring.CastShadow = false
	neonGlow(ring, accent, 0.45, 14)

	local inner = part(
		"DuelDisk",
		Vector3.new(10, 0.15, 10),
		CFrame.new(offset + Vector3.new(0, 1.18, 0)),
		CONCORD_STEEL,
		folder,
		Enum.Material.Metal
	)
	inner.Transparency = 0.55
	inner.CanCollide = false
	inner.Reflectance = 0.2

	-- Rails latéraux (lisibilité bordure arène)
	for _, xz in
		{
			Vector3.new(0, 0, -30),
			Vector3.new(0, 0, 30),
			Vector3.new(-30, 0, 0),
			Vector3.new(30, 0, 0),
		}
	do
		local rail = part(
			"ConcordRail",
			if math.abs(xz.X) > 1 then Vector3.new(2, 0.6, 40) else Vector3.new(40, 0.6, 2),
			CFrame.new(offset + Vector3.new(xz.X, 1.4, xz.Z)),
			CONCORD_STEEL,
			folder,
			Enum.Material.Metal
		)
		rail.Reflectance = 0.15
		rail.CanCollide = false
	end
end

--[[ Titre flottant (clip / orientation joueur). ]]
local function arenaTitle(folder: Folder, offset: Vector3, displayName: string, color: Color3)
	local host = part(
		"TitleHost",
		Vector3.new(1, 1, 1),
		CFrame.new(offset + Vector3.new(0, 14, -28)),
		color,
		folder,
		Enum.Material.ForceField
	)
	host.Transparency = 1
	host.CanCollide = false
	host.CastShadow = false
	local gui = Instance.new("BillboardGui")
	gui.Name = "ArenaTitle"
	gui.Size = UDim2.fromOffset(280, 48)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.Adornee = host
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Theme.Ink
	label.BackgroundTransparency = 0.35
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 18
	label.TextColor3 = color
	label.Text = displayName
	label.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = label
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1.2
	s.Transparency = 0.4
	s.Parent = label
end

local function applyArenaSky(id: ArenaId)
	local sky = Lighting:FindFirstChild("BC_ArenaSky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = "BC_ArenaSky"
		sky.Parent = Lighting
	end
	local s = sky :: Sky
	-- SkyboxIds vides = teintes Sky via CelestialBodies / Atmosphere seulement
	-- (pas d'assets skybox custom — distinct via Sun/Moon + atmo)
	s.CelestialBodiesShown = true
	if id == "ObsidianPit" then
		s.StarCount = 800
		s.MoonAngularSize = 4
		s.SunAngularSize = 8
		Lighting.GeographicLatitude = 55
	elseif id == "SanctumAstres" then
		s.StarCount = 3000
		s.MoonAngularSize = 14
		s.SunAngularSize = 16
		Lighting.GeographicLatitude = 20
	elseif id == "TroneEclipse" then
		s.StarCount = 5000
		s.MoonAngularSize = 22
		s.SunAngularSize = 2
		Lighting.GeographicLatitude = 70
	else
		s.StarCount = 1200
		s.MoonAngularSize = 8
		s.SunAngularSize = 21
		Lighting.GeographicLatitude = 10
	end
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
	-- Pass 5 : plages lighting resserrées (cohérence entre maps)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.48
	applyArenaSky(id)

	if id == "ObsidianPit" then
		Lighting.ClockTime = 21.2
		Lighting.Brightness = 1.45
		Lighting.Ambient = Color3.fromRGB(48, 28, 24)
		Lighting.OutdoorAmbient = Color3.fromRGB(62, 34, 28)
		Lighting.FogColor = Color3.fromRGB(52, 22, 16)
		Lighting.FogStart = 45
		Lighting.FogEnd = 220
		atmo.Density = 0.38
		atmo.Color = Color3.fromRGB(100, 40, 28)
		atmo.Decay = Color3.fromRGB(38, 12, 10)
		atmo.Glare = 0.22
		atmo.Haze = 1.6
		bloomFx.Intensity = 0.65
		bloomFx.Size = 28
		bloomFx.Threshold = 0.74
		ccFx.TintColor = Color3.fromRGB(255, 215, 198)
		ccFx.Contrast = 0.08
		ccFx.Saturation = 0.06
	elseif id == "SanctumAstres" then
		Lighting.ClockTime = 17.4
		Lighting.Brightness = 2.15
		Lighting.Ambient = Color3.fromRGB(70, 76, 98)
		Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 155)
		Lighting.FogColor = Color3.fromRGB(160, 175, 210)
		Lighting.FogStart = 60
		Lighting.FogEnd = 360
		atmo.Density = 0.22
		atmo.Color = Color3.fromRGB(185, 195, 230)
		atmo.Decay = Color3.fromRGB(80, 90, 140)
		atmo.Glare = 0.85
		atmo.Haze = 0.55
		bloomFx.Intensity = 0.52
		bloomFx.Size = 26
		bloomFx.Threshold = 0.86
		ccFx.TintColor = Color3.fromRGB(232, 236, 252)
		ccFx.Contrast = 0.06
		ccFx.Saturation = 0.1
	elseif id == "TroneEclipse" then
		Lighting.ClockTime = 22.8
		Lighting.Brightness = 1.2
		Lighting.Ambient = Color3.fromRGB(30, 24, 48)
		Lighting.OutdoorAmbient = Color3.fromRGB(42, 32, 64)
		Lighting.FogColor = Color3.fromRGB(22, 14, 40)
		Lighting.FogStart = 35
		Lighting.FogEnd = 190
		atmo.Density = 0.4
		atmo.Color = Color3.fromRGB(50, 36, 90)
		atmo.Decay = Color3.fromRGB(16, 10, 32)
		atmo.Glare = 0.12
		atmo.Haze = 2.0
		bloomFx.Intensity = 0.58
		bloomFx.Size = 28
		bloomFx.Threshold = 0.7
		ccFx.TintColor = Color3.fromRGB(205, 190, 250)
		ccFx.Contrast = 0.1
		ccFx.Saturation = -0.04
	else -- QuaiMirage
		Lighting.ClockTime = 7.5
		Lighting.Brightness = 2.25
		Lighting.Ambient = Color3.fromRGB(58, 88, 98)
		Lighting.OutdoorAmbient = Color3.fromRGB(105, 145, 155)
		Lighting.FogColor = Color3.fromRGB(125, 175, 185)
		Lighting.FogStart = 50
		Lighting.FogEnd = 280
		atmo.Density = 0.3
		atmo.Color = Color3.fromRGB(145, 200, 210)
		atmo.Decay = Color3.fromRGB(55, 105, 115)
		atmo.Glare = 1.1
		atmo.Haze = 1.4
		bloomFx.Intensity = 0.52
		bloomFx.Size = 26
		bloomFx.Threshold = 0.84
		ccFx.TintColor = Color3.fromRGB(210, 245, 252)
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
	local sep = spawnSep()
	local stoneA = part(
		"SpawnStoneA",
		Vector3.new(7, 0.4, 7),
		CFrame.new(offset + Vector3.new(-sep, 1.15, 0)),
		Color3.fromRGB(88, 86, 96),
		folder,
		Enum.Material.Slate
	)
	stoneA.CanCollide = false
	local stoneB = part(
		"SpawnStoneB",
		Vector3.new(7, 0.4, 7),
		CFrame.new(offset + Vector3.new(sep, 1.15, 0)),
		Color3.fromRGB(88, 86, 96),
		folder,
		Enum.Material.Slate
	)
	stoneB.CanCollide = false
	local spawnA = part(
		"SpawnA",
		Vector3.new(5, 0.4, 5),
		CFrame.new(offset + Vector3.new(-sep, 1.3, 0)),
		Color3.fromRGB(90, 160, 220),
		folder,
		Enum.Material.Neon
	)
	spawnA.Transparency = 0.55
	spawnA.CanCollide = false
	neonGlow(spawnA, Color3.fromRGB(90, 160, 220), 0.8, 12)
	CollectionService:AddTag(spawnA, CombatConfig.Tags.ArenaSpawnA)

	local spawnB = part(
		"SpawnB",
		Vector3.new(5, 0.4, 5),
		CFrame.new(offset + Vector3.new(sep, 1.3, 0)),
		Color3.fromRGB(220, 100, 90),
		folder,
		Enum.Material.Neon
	)
	spawnB.Transparency = 0.55
	spawnB.CanCollide = false
	neonGlow(spawnB, Color3.fromRGB(220, 100, 90), 0.8, 12)
	CollectionService:AddTag(spawnB, CombatConfig.Tags.ArenaSpawnB)
end

local function buildObsidianPit(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ObsidianPit"
	folder.Parent = parent
	local offset, displayName = arenaOffset("ObsidianPit")
	folder:SetAttribute("DisplayName", displayName)
	folder:SetAttribute("OffsetX", offset.X)
	folder:SetAttribute("OffsetZ", offset.Z)
	folder:SetAttribute("ArtPass", ART_PASS)
	folder:SetAttribute("BC_ArenaSide", "Left")
	folder:SetAttribute("BC_ArenaIndex", 1)

	local basalt = Color3.fromRGB(42, 40, 48)
	vastDeck(folder, offset, basalt, Enum.Material.Basalt)
	local basaltLite = Color3.fromRGB(70, 68, 78)
	local ember = Color3.fromRGB(255, 110, 40)
	local lava = Color3.fromRGB(255, 90, 30)
	local size = Vector3.new(64, 2, 64)
	local wallH = 14

	local platform = part("Platform", size, CFrame.new(offset), basalt, folder, Enum.Material.Basalt)
	platform.Reflectance = 0.05
	-- Dallage central
	part(
		"Inlay",
		Vector3.new(28, 0.25, 28),
		CFrame.new(offset + Vector3.new(0, 1.1, 0)),
		basaltLite,
		folder,
		Enum.Material.Slate
	)
	part(
		"Ring",
		Vector3.new(size.X + 10, 1.2, size.Z + 10),
		CFrame.new(offset + Vector3.new(0, -0.6, 0)),
		Color3.fromRGB(28, 26, 32),
		folder,
		Enum.Material.Rock
	)

	local halfX, halfZ = size.X / 2, size.Z / 2
	for _, wall in
		{
			part(
				"WallN",
				Vector3.new(size.X + 6, wallH, 3),
				CFrame.new(offset + Vector3.new(0, wallH / 2, -halfZ - 1.5)),
				basalt,
				folder,
				Enum.Material.Basalt
			),
			part(
				"WallS",
				Vector3.new(size.X + 6, wallH, 3),
				CFrame.new(offset + Vector3.new(0, wallH / 2, halfZ + 1.5)),
				basalt,
				folder,
				Enum.Material.Basalt
			),
			part(
				"WallE",
				Vector3.new(3, wallH, size.Z),
				CFrame.new(offset + Vector3.new(halfX + 1.5, wallH / 2, 0)),
				basalt,
				folder,
				Enum.Material.Basalt
			),
			part(
				"WallW",
				Vector3.new(3, wallH, size.Z),
				CFrame.new(offset + Vector3.new(-halfX - 1.5, wallH / 2, 0)),
				basalt,
				folder,
				Enum.Material.Basalt
			),
		}
	do
		wall.Material = Enum.Material.Basalt
	end

	-- Piliers d'angle
	for _, corner in
		{ Vector3.new(-28, 5, -28), Vector3.new(28, 5, -28), Vector3.new(-28, 5, 28), Vector3.new(28, 5, 28) }
	do
		local pillar =
			part("Pillar", Vector3.new(4, 10, 4), CFrame.new(offset + corner), basaltLite, folder, Enum.Material.Rock)
		local torch = part(
			"Ember",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(offset + corner + Vector3.new(0, 6, 0)),
			ember,
			folder,
			Enum.Material.Neon
		)
		torch.CanCollide = false
		neonGlow(torch, ember, 2.5, 18)
		ashEmitter(torch)
	end

	local lavaPart = part(
		"LavaBorder",
		Vector3.new(size.X + 28, 1.5, size.Z + 28),
		CFrame.new(offset + Vector3.new(0, -3.2, 0)),
		lava,
		folder,
		Enum.Material.Neon
	)
	lavaPart.Transparency = 0.15
	neonGlow(lavaPart, lava, 3, 40)
	lavaPart:SetAttribute("Dps", CombatConfig.Arena.LavaDps)
	lavaPart:SetAttribute("HazardKind", "Lava")
	CollectionService:AddTag(lavaPart, CombatConfig.Tags.KillPlane)
	CollectionService:AddTag(lavaPart, CombatConfig.Tags.Hazard)
	hazardLabel(lavaPart, "LAVE — mortelle", ember)

	-- Lave intérieure (anneau visible au bord plateforme)
	local lavaInner = part(
		"LavaLip",
		Vector3.new(size.X + 4, 0.6, size.Z + 4),
		CFrame.new(offset + Vector3.new(0, 0.2, 0)),
		ember,
		folder,
		Enum.Material.Neon
	)
	lavaInner.Transparency = 0.45
	lavaInner.CanCollide = false
	neonGlow(lavaInner, ember, 1.2, 20)
	ashEmitter(lavaInner, 18, Color3.fromRGB(255, 120, 40), Color3.fromRGB(80, 40, 20))

	scatterDebris(folder, offset, Color3.fromRGB(55, 48, 42), Enum.Material.Rock, 14)
	fogBank(folder, offset, Color3.fromRGB(80, 35, 20), 5)
	driftField(folder, offset, Color3.fromRGB(255, 120, 40), Color3.fromRGB(80, 30, 10), 18, 1.8, "EmberDrift")
	coherenceKit(folder, offset, Color3.fromRGB(255, 140, 60))
	arenaTitle(folder, offset, "Obsidian Pit", ember)

	buildSpawns(folder, offset)
	return folder
end

local function buildSanctum(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "SanctumAstres"
	folder.Parent = parent
	local offset, displayName = arenaOffset("SanctumAstres")
	folder:SetAttribute("DisplayName", displayName)
	folder:SetAttribute("ArtPass", ART_PASS)
	folder:SetAttribute("OffsetX", offset.X)
	folder:SetAttribute("OffsetZ", offset.Z)
	folder:SetAttribute("BC_ArenaSide", "Left")
	folder:SetAttribute("BC_ArenaIndex", 2)
	local marble = Color3.fromRGB(210, 205, 195)
	vastDeck(folder, offset, marble, Enum.Material.Marble)
	local gold = Color3.fromRGB(190, 160, 90)
	local sky = Color3.fromRGB(140, 190, 230)
	local size = Vector3.new(56, 2, 56)

	part("Platform", size, CFrame.new(offset), marble, folder, Enum.Material.Marble)
	local inlayStar = part(
		"InlayStar",
		Vector3.new(16, 0.3, 16),
		CFrame.new(offset + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, math.rad(45), 0),
		gold,
		folder,
		Enum.Material.Metal
	)
	inlayStar.Reflectance = 0.4
	part(
		"WallN",
		Vector3.new(size.X, 12, 2.5),
		CFrame.new(offset + Vector3.new(0, 6, -29)),
		marble,
		folder,
		Enum.Material.Limestone
	)
	part(
		"WallS",
		Vector3.new(size.X, 12, 2.5),
		CFrame.new(offset + Vector3.new(0, 6, 29)),
		marble,
		folder,
		Enum.Material.Limestone
	)

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
			local cap = part(
				"Cap",
				Vector3.new(3.2, 1, 3.2),
				CFrame.new(offset + Vector3.new(xSign * 22, 15.5, z)),
				gold,
				folder,
				Enum.Material.Metal
			)
			cap.Reflectance = 0.3
			col.Material = Enum.Material.Marble
		end
	end

	-- Deux « astres » lumineux
	local sun = part(
		"AstreDawn",
		Vector3.new(5, 5, 5),
		CFrame.new(offset + Vector3.new(-10, 18, 0)),
		Color3.fromRGB(255, 200, 120),
		folder,
		Enum.Material.Neon
	)
	sun.Shape = Enum.PartType.Ball
	sun.CanCollide = false
	neonGlow(sun, Color3.fromRGB(255, 200, 120), 3, 35)
	local moon = part(
		"AstreDusk",
		Vector3.new(4, 4, 4),
		CFrame.new(offset + Vector3.new(10, 17, 0)),
		Color3.fromRGB(160, 180, 255),
		folder,
		Enum.Material.Neon
	)
	moon.Shape = Enum.PartType.Ball
	moon.CanCollide = false
	neonGlow(moon, Color3.fromRGB(160, 180, 255), 2.5, 30)

	local windL = part(
		"WindWest",
		Vector3.new(8, 6, 40),
		CFrame.new(offset + Vector3.new(-22, 4, 0)),
		sky,
		folder,
		Enum.Material.ForceField
	)
	windL.Transparency = 0.55
	windL.CanCollide = false
	windL:SetAttribute("HazardKind", "Wind")
	windL:SetAttribute("WindDir", Vector3.new(1, 0, 0))
	CollectionService:AddTag(windL, CombatConfig.Tags.Hazard)
	neonGlow(windL, sky, 0.9, 18)
	ashEmitter(windL, 22, Color3.fromRGB(180, 210, 255), Color3.fromRGB(120, 160, 220))
	hazardLabel(windL, "VENT — poussée", sky)

	local windR = part(
		"WindEast",
		Vector3.new(8, 6, 40),
		CFrame.new(offset + Vector3.new(22, 4, 0)),
		sky,
		folder,
		Enum.Material.ForceField
	)
	windR.Transparency = 0.55
	windR.CanCollide = false
	windR:SetAttribute("HazardKind", "Wind")
	windR:SetAttribute("WindDir", Vector3.new(-1, 0, 0))
	CollectionService:AddTag(windR, CombatConfig.Tags.Hazard)
	neonGlow(windR, sky, 0.9, 18)
	ashEmitter(windR, 22, Color3.fromRGB(180, 210, 255), Color3.fromRGB(120, 160, 220))
	hazardLabel(windR, "VENT — poussée", sky)

	scatterDebris(folder, offset, Color3.fromRGB(190, 185, 170), Enum.Material.Marble, 10)
	fogBank(folder, offset, Color3.fromRGB(170, 190, 230), 4)
	driftField(folder, offset, Color3.fromRGB(200, 220, 255), Color3.fromRGB(140, 160, 210), 14, 0.6, "DustDrift")
	coherenceKit(folder, offset, gold)
	arenaTitle(folder, offset, "Sanctum des Deux Astres", gold)

	buildSpawns(folder, offset)
	return folder
end

local function buildThrone(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TroneEclipse"
	folder.Parent = parent
	local offset, displayName = arenaOffset("TroneEclipse")
	folder:SetAttribute("DisplayName", displayName)
	folder:SetAttribute("ArtPass", ART_PASS)
	folder:SetAttribute("OffsetX", offset.X)
	folder:SetAttribute("OffsetZ", offset.Z)
	folder:SetAttribute("BC_ArenaSide", "Left")
	folder:SetAttribute("BC_ArenaIndex", 3)
	local dark = Color3.fromRGB(32, 28, 42)
	vastDeck(folder, offset, dark, Enum.Material.Slate)
	local violet = Color3.fromRGB(90, 55, 140)
	local void = Color3.fromRGB(18, 14, 28)
	local size = Vector3.new(60, 2, 60)

	part("Platform", size, CFrame.new(offset), dark, folder, Enum.Material.Slate)
	part(
		"OuterRing",
		Vector3.new(size.X + 8, 0.8, size.Z + 8),
		CFrame.new(offset + Vector3.new(0, -0.4, 0)),
		void,
		folder,
		Enum.Material.Rock
	)

	-- Estrade centrale (anti-camp)
	local dais = part(
		"Dais",
		Vector3.new(16, 3.5, 16),
		CFrame.new(offset + Vector3.new(0, 2.7, 0)),
		violet,
		folder,
		Enum.Material.Neon
	)
	dais.Transparency = 0.35
	dais:SetAttribute("HazardKind", "ThronePressure")
	dais:SetAttribute("Dps", CombatConfig.Arena.ThronePressureDps)
	CollectionService:AddTag(dais, CombatConfig.Tags.Hazard)
	neonGlow(dais, violet, 2.2, 26)
	hazardLabel(dais, "PRESSION — DPS", Color3.fromRGB(200, 140, 255))
	ashEmitter(dais, 10, Color3.fromRGB(120, 80, 200), Color3.fromRGB(40, 20, 60))

	-- Trône Constructible
	local seat = part(
		"ThroneSeat",
		Vector3.new(5, 1.2, 4),
		CFrame.new(offset + Vector3.new(0, 5.2, -1)),
		void,
		folder,
		Enum.Material.Metal
	)
	local back = part(
		"ThroneBack",
		Vector3.new(5.5, 8, 1.2),
		CFrame.new(offset + Vector3.new(0, 9, -2.8)),
		void,
		folder,
		Enum.Material.Metal
	)
	back.Reflectance = 0.15
	part(
		"ThroneArmL",
		Vector3.new(1, 2.5, 3.5),
		CFrame.new(offset + Vector3.new(-2.8, 6.5, -1)),
		Color3.fromRGB(50, 40, 70),
		folder,
		Enum.Material.Metal
	)
	part(
		"ThroneArmR",
		Vector3.new(1, 2.5, 3.5),
		CFrame.new(offset + Vector3.new(2.8, 6.5, -1)),
		Color3.fromRGB(50, 40, 70),
		folder,
		Enum.Material.Metal
	)
	local crown = part(
		"ThroneCrown",
		Vector3.new(6, 1.5, 1.5),
		CFrame.new(offset + Vector3.new(0, 13.5, -2.8)),
		Color3.fromRGB(160, 120, 255),
		folder,
		Enum.Material.Neon
	)
	crown.CanCollide = false
	neonGlow(crown, Color3.fromRGB(160, 120, 255), 2.2, 20)
	seat.CanCollide = true

	-- Obélisques
	for _, xz in { Vector3.new(-22, 0, -22), Vector3.new(22, 0, -22), Vector3.new(-22, 0, 22), Vector3.new(22, 0, 22) } do
		local ob = part(
			"Obelisk",
			Vector3.new(2.5, 16, 2.5),
			CFrame.new(offset + Vector3.new(xz.X, 9, xz.Z)),
			dark,
			folder,
			Enum.Material.Basalt
		)
		local tip = part(
			"ObeliskTip",
			Vector3.new(1.5, 2, 1.5),
			CFrame.new(offset + Vector3.new(xz.X, 18, xz.Z)),
			Color3.fromRGB(140, 100, 220),
			folder,
			Enum.Material.Neon
		)
		tip.CanCollide = false
		neonGlow(tip, Color3.fromRGB(140, 100, 220), 1.5, 14)
		ob.Material = Enum.Material.Basalt
	end

	scatterDebris(folder, offset, Color3.fromRGB(40, 32, 55), Enum.Material.Slate, 12)
	fogBank(folder, offset, Color3.fromRGB(50, 30, 80), 6)
	driftField(folder, offset, Color3.fromRGB(160, 100, 255), Color3.fromRGB(40, 20, 70), 16, 0.9, "VoidEmberDrift")
	coherenceKit(folder, offset, Color3.fromRGB(160, 120, 255))
	arenaTitle(folder, offset, "Trône d'Éclipse", Color3.fromRGB(180, 140, 255))

	buildSpawns(folder, offset)
	return folder
end

local function buildMirage(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "QuaiMirage"
	folder.Parent = parent
	local offsetMirage, displayMirage = arenaOffset("QuaiMirage")
	folder:SetAttribute("DisplayName", displayMirage)
	folder:SetAttribute("ArtPass", ART_PASS)
	folder:SetAttribute("OffsetX", offsetMirage.X)
	folder:SetAttribute("OffsetZ", offsetMirage.Z)
	folder:SetAttribute("BC_ArenaSide", "Left")
	folder:SetAttribute("BC_ArenaIndex", 4)
	vastDeck(folder, offsetMirage, Color3.fromRGB(55, 140, 150), Enum.Material.Concrete)
	local offset = offsetMirage
	local teal = Color3.fromRGB(55, 110, 120)
	local sand = Color3.fromRGB(180, 170, 140)
	local water = Color3.fromRGB(40, 120, 140)
	local mirage = Color3.fromRGB(140, 220, 230)

	part("Platform", Vector3.new(58, 2, 40), CFrame.new(offset), teal, folder, Enum.Material.Concrete)
	part(
		"DockEdge",
		Vector3.new(60, 1, 3),
		CFrame.new(offset + Vector3.new(0, 0.5, -20)),
		sand,
		folder,
		Enum.Material.WoodPlanks
	)
	part(
		"DockEdgeS",
		Vector3.new(60, 1, 3),
		CFrame.new(offset + Vector3.new(0, 0.5, 20)),
		sand,
		folder,
		Enum.Material.WoodPlanks
	)

	local waterPlane = part(
		"Water",
		Vector3.new(90, 1, 70),
		CFrame.new(offset + Vector3.new(0, -2.5, 0)),
		water,
		folder,
		Enum.Material.Glass
	)
	waterPlane.Transparency = 0.35
	waterPlane.CanCollide = false
	neonGlow(waterPlane, water, 0.8, 30)

	-- Piliers de quai
	for x = -24, 24, 12 do
		part(
			"Pier",
			Vector3.new(1.5, 6, 1.5),
			CFrame.new(offset + Vector3.new(x, -1, -22)),
			Color3.fromRGB(90, 70, 50),
			folder,
			Enum.Material.Wood
		)
		part(
			"PierS",
			Vector3.new(1.5, 6, 1.5),
			CFrame.new(offset + Vector3.new(x, -1, 22)),
			Color3.fromRGB(90, 70, 50),
			folder,
			Enum.Material.Wood
		)
	end

	local lantern = part(
		"Lantern",
		Vector3.new(2, 2, 2),
		CFrame.new(offset + Vector3.new(0, 8, 0)),
		mirage,
		folder,
		Enum.Material.Neon
	)
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
		neonGlow(panel, mirage, 1.5, 16)
		hazardLabel(panel, "MIRAGE — phase", mirage)
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

	scatterDebris(folder, offset, Color3.fromRGB(100, 90, 70), Enum.Material.Sand, 11)
	fogBank(folder, offset, Color3.fromRGB(120, 180, 190), 5)
	driftField(folder, offset, Color3.fromRGB(180, 230, 235), Color3.fromRGB(90, 140, 150), 12, 0.35, "MistDrift")
	coherenceKit(folder, offset, mirage)
	arenaTitle(folder, offset, "Quai Mirage", mirage)

	buildSpawns(folder, offset)
	return folder
end

--[[ Arènes droites R1–R4 — floors vastes thématiques Dawn/Dusk/Néant/Cristal. ]]
local function buildThematicVast(
	parent: Folder,
	id: ArenaId,
	side: string,
	arenaIndex: number,
	deckColor: Color3,
	accent: Color3,
	material: Enum.Material,
	propsFn: ((Folder, Vector3) -> ())?
): Folder
	local folder = Instance.new("Folder")
	folder.Name = id
	folder.Parent = parent
	local offset, displayName = arenaOffset(id)
	folder:SetAttribute("DisplayName", displayName)
	folder:SetAttribute("ArtPass", ART_PASS)
	folder:SetAttribute("OffsetX", offset.X)
	folder:SetAttribute("OffsetZ", offset.Z)
	folder:SetAttribute("BC_ArenaSide", side)
	folder:SetAttribute("BC_ArenaIndex", arenaIndex)

	vastDeck(folder, offset, deckColor, material)
	part(
		"CenterInlay",
		Vector3.new(36, 0.3, 36),
		CFrame.new(offset + Vector3.new(0, 1.2, 0)),
		accent,
		folder,
		Enum.Material.Neon
	).Transparency = 0.55
	neonGlow(
		part("AccentOrb", Vector3.new(4, 4, 4), CFrame.new(offset + Vector3.new(0, 10, -40)), accent, folder, Enum.Material.Neon),
		accent,
		1.2,
		28
	)
	if propsFn then
		propsFn(folder, offset)
	end
	coherenceKit(folder, offset, accent)
	arenaTitle(folder, offset, displayName, accent)
	buildSpawns(folder, offset)
	return folder
end

local function buildForgeAube(parent: Folder): Folder
	return buildThematicVast(parent, "ForgeAube", "Right", 5, Color3.fromRGB(48, 32, 24), Color3.fromRGB(255, 140, 60), Enum.Material.Basalt, function(folder, offset)
		for i = -2, 2 do
			part(
				"Brazier",
				Vector3.new(3, 2, 3),
				CFrame.new(offset + Vector3.new(i * 18, 2, 40)),
				Color3.fromRGB(255, 100, 40),
				folder,
				Enum.Material.Neon
			)
		end
		driftField(folder, offset, Color3.fromRGB(255, 140, 50), Color3.fromRGB(80, 30, 10), 10, 1.2, "ForgeEmbers")
	end)
end

local function buildSpireCrepuscule(parent: Folder): Folder
	return buildThematicVast(
		parent,
		"SpireCrepuscule",
		"Right",
		6,
		Color3.fromRGB(28, 24, 48),
		Color3.fromRGB(120, 90, 255),
		Enum.Material.Slate,
		function(folder, offset)
			part(
				"Spire",
				Vector3.new(8, 36, 8),
				CFrame.new(offset + Vector3.new(0, 20, -45)),
				Color3.fromRGB(60, 50, 100),
				folder,
				Enum.Material.Metal
			)
			local tip = part(
				"SpireTip",
				Vector3.new(5, 5, 5),
				CFrame.new(offset + Vector3.new(0, 40, -45)),
				Color3.fromRGB(150, 120, 255),
				folder,
				Enum.Material.Neon
			)
			tip.Shape = Enum.PartType.Ball
			tip.CanCollide = false
			neonGlow(tip, Color3.fromRGB(150, 120, 255), 1.4, 30)
			driftField(folder, offset, Color3.fromRGB(160, 120, 255), Color3.fromRGB(40, 20, 80), 10, 0.5, "DuskMotes")
		end
	)
end

local function buildRecifNeant(parent: Folder): Folder
	return buildThematicVast(
		parent,
		"RecifNeant",
		"Right",
		7,
		Color3.fromRGB(22, 26, 32),
		Color3.fromRGB(80, 200, 180),
		Enum.Material.Rock,
		function(folder, offset)
			for i = 1, 8 do
				local ang = (i / 8) * math.pi * 2
				part(
					"Reef",
					Vector3.new(6, 4 + (i % 3) * 2, 6),
					CFrame.new(offset + Vector3.new(math.sin(ang) * 40, 2, math.cos(ang) * 40)),
					Color3.fromRGB(50, 70, 75),
					folder,
					Enum.Material.Limestone
				)
			end
			fogBank(folder, offset, Color3.fromRGB(40, 80, 90), 4)
		end
	)
end

local function buildCourCristal(parent: Folder): Folder
	return buildThematicVast(
		parent,
		"CourCristal",
		"Right",
		8,
		Color3.fromRGB(40, 48, 62),
		Color3.fromRGB(120, 210, 255),
		Enum.Material.Marble,
		function(folder, offset)
			for i = 0, 5 do
				local shard = part(
					"Crystal",
					Vector3.new(2, 10, 2),
					CFrame.new(offset + Vector3.new(-30 + i * 12, 6, 42)) * CFrame.Angles(0, 0, math.rad(12)),
					Color3.fromRGB(140, 220, 255),
					folder,
					Enum.Material.Neon
				)
				shard.Transparency = 0.25
				shard.CanCollide = false
			end
			driftField(folder, offset, Color3.fromRGB(180, 230, 255), Color3.fromRGB(100, 160, 220), 8, 0.4, "CrystalDust")
		end
	)
end

function ArenaService.ensureAll(): Folder
	local root = getArenasRoot()
	-- Purge greybox / art pass < ART_PASS
	for _, child in root:GetChildren() do
		local name = child.Name
		local pass = child:GetAttribute("ArtPass")
		if name == "ConcordLobby" then
			if pass ~= LobbyConfig.ArtPass then
				lobbyBuilt = nil
				child:Destroy()
			elseif lobbyBuilt == nil then
				lobbyBuilt = child
			end
		elseif child:IsA("Folder") then
			if pass ~= ART_PASS then
				if built[name :: any] then
					built[name :: any] = nil
				end
				child:Destroy()
			elseif built[name :: any] == nil then
				built[name :: any] = child
			end
		end
	end

	local builders: { [ArenaId]: (Folder) -> Folder } = {
		ObsidianPit = buildObsidianPit,
		SanctumAstres = buildSanctum,
		TroneEclipse = buildThrone,
		QuaiMirage = buildMirage,
		ForgeAube = buildForgeAube,
		SpireCrepuscule = buildSpireCrepuscule,
		RecifNeant = buildRecifNeant,
		CourCristal = buildCourCristal,
	}
	for _, id in ARENA_ORDER do
		local folder = built[id]
		if not folder or not folder.Parent then
			built[id] = builders[id](root)
		end
		-- Pool Match : tag BC_MatchArena pour pickMatchArena / refreshWorldPool
		local f = built[id]
		if f then
			CollectionService:AddTag(f, CombatConfig.Tags.MatchArena)
		end
	end
	ArenaService.refreshWorldPool()
	ArenaService.ensureLobby()
	LobbyLighting.applyHall()
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

function ArenaService.getActivePoolIndex(): number
	return activePoolIndex
end

--[[ World : tag BC_MatchArena + BC_ArenaIndex 1..8 (+ SpawnA/B ou Offset*). ]]
function ArenaService.refreshWorldPool()
	table.clear(worldByIndex)
	local tag = CombatConfig.Tags.MatchArena
	for _, inst in CollectionService:GetTagged(tag) do
		local idx = inst:GetAttribute("BC_ArenaIndex")
		if typeof(idx) == "number" then
			local n = math.floor(idx)
			local maxN = CombatConfig.Match.MatchArenaCount or 8
			if n >= 1 and n <= maxN then
				worldByIndex[n] = inst
			end
		end
	end
end

function ArenaService.listPoolIndices(): { number }
	ArenaService.refreshWorldPool()
	local maxN = CombatConfig.Match.MatchArenaCount or 8
	local list = {}
	local worldCount = 0
	for i = 1, maxN do
		if worldByIndex[i] then
			worldCount += 1
		end
	end
	if worldCount > 0 then
		for i = 1, maxN do
			if worldByIndex[i] then
				table.insert(list, i)
			end
		end
		return list
	end
	-- Fallback procédural : 8 indices virtuels sur les 4 thèmes (1 match / serveur)
	for i = 1, maxN do
		table.insert(list, i)
	end
	return list
end

local function themeForPoolIndex(index: number): ArenaId
	return ARENA_ORDER[((index - 1) % #ARENA_ORDER) + 1]
end

local function findSpawnPart(root: Instance, tag: string, name: string): BasePart?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(root) then
			return inst
		end
	end
	local named = root:FindFirstChild(name, true)
	if named and named:IsA("BasePart") then
		return named
	end
	return nil
end

function ArenaService.setActive(id: ArenaId)
	ArenaService.ensureAll()
	if built[id] then
		activeId = id
		activeWorldRoot = nil
		applyArenaLighting(id)
	end
end

function ArenaService.setActivePoolIndex(index: number)
	ArenaService.ensureAll()
	ArenaService.refreshWorldPool()
	local maxN = CombatConfig.Match.MatchArenaCount or 8
	local idx = math.clamp(math.floor(index), 1, maxN)
	activePoolIndex = idx
	local world = worldByIndex[idx]
	if world and world.Parent then
		activeWorldRoot = world
		local themeAttr = world:GetAttribute("BC_ArenaTheme")
		if typeof(themeAttr) == "string" and built[themeAttr :: any] then
			activeId = themeAttr :: ArenaId
		else
			activeId = themeForPoolIndex(idx)
		end
		if built[activeId] then
			applyArenaLighting(activeId)
		end
	else
		activeWorldRoot = nil
		activeId = themeForPoolIndex(idx)
		if built[activeId] then
			applyArenaLighting(activeId)
		end
	end
	occupiedPoolIndex = idx
end

--[[ Rotation / libre : saute l’index occupé si pool > 1. ]]
function ArenaService.pickMatchArena(): number
	local pool = ArenaService.listPoolIndices()
	if #pool == 0 then
		ArenaService.setActive("ObsidianPit")
		activePoolIndex = 1
		return 1
	end
	poolRotation = (poolRotation % #pool) + 1
	local start = poolRotation
	local chosen = pool[start]
	-- Préfère une arène libre (≠ occupied) quand plusieurs dispo
	if occupiedPoolIndex and #pool > 1 then
		for step = 0, #pool - 1 do
			local i = ((start - 1 + step) % #pool) + 1
			if pool[i] ~= occupiedPoolIndex then
				chosen = pool[i]
				poolRotation = i
				break
			end
		end
	end
	ArenaService.setActivePoolIndex(chosen)
	return chosen
end

function ArenaService.releasePoolOccupation()
	occupiedPoolIndex = nil
end

function ArenaService.getSpawnCFrames(): (CFrame, CFrame)
	ArenaService.ensureAll()

	if activeWorldRoot and activeWorldRoot.Parent then
		local spawnA = findSpawnPart(activeWorldRoot, CombatConfig.Tags.ArenaSpawnA, "SpawnA")
		local spawnB = findSpawnPart(activeWorldRoot, CombatConfig.Tags.ArenaSpawnB, "SpawnB")
		if spawnA and spawnB then
			return spawnA.CFrame + Vector3.new(0, 3, 0), spawnB.CFrame + Vector3.new(0, 3, 0)
		end
		local ox = (activeWorldRoot:GetAttribute("OffsetX") :: number?) or 0
		local oy = (activeWorldRoot:GetAttribute("OffsetY") :: number?) or 0
		local oz = (activeWorldRoot:GetAttribute("OffsetZ") :: number?) or 0
		local origin = Vector3.new(ox, oy, oz)
		local sep = spawnSep()
		local a = CFrame.new(origin + Vector3.new(-sep, 4, 0)) * CFrame.Angles(0, math.rad(90), 0)
		local b = CFrame.new(origin + Vector3.new(sep, 4, 0)) * CFrame.Angles(0, math.rad(-90), 0)
		return a, b
	end

	local folder = built[activeId]
	local ox = if folder then (folder:GetAttribute("OffsetX") :: number?) or 0 else 0
	local oz = if folder then (folder:GetAttribute("OffsetZ") :: number?) or 0 else 0
	local sep = spawnSep()
	local a = CFrame.new(ox - sep, 4, oz) * CFrame.Angles(0, math.rad(90), 0)
	local b = CFrame.new(ox + sep, 4, oz) * CFrame.Angles(0, math.rad(-90), 0)
	return a, b
end

--[[ Concord Hall — grand lobby procédural (voir Lobby/*). ]]
function ArenaService.ensureLobby(): Instance
	local root = getArenasRoot()
	-- Purge ancien Folder greybox / ArtPass obsolète
	local existing = root:FindFirstChild(LobbyConfig.Name)
	if existing and existing:GetAttribute("ArtPass") ~= LobbyConfig.ArtPass then
		existing:Destroy()
		lobbyBuilt = nil
	end
	local model = LobbyBuilder.ensure(root)
	lobbyBuilt = model
	return model
end

--[[
	Retour allée : LobbyBuilder.getSpawnCFrame() (ArtPass 8 = début d’allée).
	Si World tague un BC_LobbySpawn, on le préfère (sans toucher la géométrie).
]]
function ArenaService.getLobbyCFrame(): CFrame
	ArenaService.ensureLobby()
	local spawnTag = CombatConfig.Tags.LobbySpawn
	for _, inst in CollectionService:GetTagged(spawnTag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(Workspace) then
			local look = inst.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			local cf = inst.CFrame + Vector3.new(0, 3, 0)
			if flat.Magnitude > 1e-3 then
				return CFrame.lookAt(cf.Position, cf.Position + flat.Unit)
			end
			return cf
		end
	end
	return LobbyBuilder.getSpawnCFrame()
end

function ArenaService.getLobbyDisplayName(): string
	ArenaService.ensureLobby()
	if lobbyBuilt then
		local layout = lobbyBuilt:GetAttribute("BC_Layout")
		local n = lobbyBuilt:GetAttribute("DisplayName")
		if layout == "AlleySlots" then
			return if typeof(n) == "string" and n ~= "" then n else "Allée Concord"
		end
		if typeof(n) == "string" and n ~= "" then
			return n
		end
	end
	return "Allée Concord"
end

function ArenaService.applyLobbyLighting()
	LobbyLighting.applyHall()
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
					local dmg =
						math.min(dps * step, CombatConfig.MaxHp / CombatConfig.Arena.MinLethalFullHpSeconds * step)
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
				local solid = phase < 0.55
				inst.CanCollide = solid
				-- Solide = opaque + glow fort ; fantôme = presque invisible
				inst.Transparency = if solid then 0.12 else 0.88
				inst.Material = if solid then Enum.Material.Neon else Enum.Material.ForceField
				local light = inst:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = if solid then 2.0 else 0.15
					light.Range = if solid then 18 else 8
				end
				local labelGui = inst:FindFirstChild("HazardLabel")
				if labelGui and labelGui:IsA("BillboardGui") then
					local lbl = labelGui:FindFirstChildOfClass("TextLabel")
					if lbl then
						lbl.Text = if solid then "MIRAGE — SOLIDE" else "MIRAGE — fantôme"
						lbl.TextColor3 = if solid then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(140, 200, 210)
					end
				end
			end
		end
	end
end

return ArenaService
