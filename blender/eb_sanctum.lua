--!nocheck
-- Ether Blades : « Sanctuaire de l'Éther », refonte de l'ambiance visuelle du Hub et des arènes.
-- Univers original : sanctuaire de duellistes bâti autour d'une énergie ancienne (l'Éther).
-- Pierre sombre, bronze patiné, lueurs sarcelle / violette / ambre, brume, glyphes inventés,
-- statues de « Veilleurs » masqués, monolithes gravés, orrerie suspendue, cristaux.
--
-- Ne touche ni aux scripts, ni aux marqueurs, ni aux noms de parts existants : le décor ajouté vit dans
-- Hub.Sanctum et <Arène>.Ambiance (supprimés puis reconstruits à chaque exécution), les parts existantes
-- sont seulement repeintes, et l'éclairage passe par Lighting / Hub.HubLighting / <Arène>.Lighting.
-- Tout le décor ajouté est non collidable (sauf socles et statues hors des zones de jeu) : il ne gêne
-- ni les déplacements ni la caméra (la caméra ignore les parts non collidables).
--
-- Usage (barre de commande ou MCP, mode Edit) :
--   local S = require(ServerStorage.EB_Sanctum)
--   S.run("palette") ; S.run("hub") ; S.run("hublight") ; S.run("arena", "Forge") ...
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local S = {}
local rgb = Color3.fromRGB
local M = Enum.Material
local NEON, SLATE, BASALT, MARBLE, CMETAL, GLASS, FABRIC, WOOD, ROCK =
	M.Neon, M.Slate, M.Basalt, M.Marble, M.CorrodedMetal, M.Glass, M.Fabric, M.Wood, M.Rock

local C = {
	Ether = rgb(70, 235, 215),
	EtherSoft = rgb(150, 255, 240),
	Violet = rgb(150, 95, 255),
	Amber = rgb(255, 165, 70),
	Ember = rgb(255, 100, 40),
	Rose = rgb(255, 90, 200),
	Frost = rgb(175, 195, 255),
	Basalt = rgb(42, 41, 50),
	Slate = rgb(62, 60, 74),
	SlateLight = rgb(84, 82, 98),
	Floor = rgb(46, 45, 58),
	Patina = rgb(92, 124, 108),
	Bronze = rgb(112, 88, 58),
	Wood = rgb(58, 40, 30),
	Leaf = rgb(40, 82, 70),
	LeafLight = rgb(58, 104, 84),
	Rock = rgb(64, 58, 68),
	Cloth = rgb(64, 30, 100),
	ClothDark = rgb(34, 20, 58),
}

local TEX = {
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	spark = "rbxasset://textures/particles/sparkles_main.dds",
}

--------------------------------------------------------------------------------
-- Outils de construction

local function make(class: string, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, solid: boolean?)
	local p = Instance.new(class)
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	if mat == NEON then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local function P(parent, name, size, cf, color, mat, solid)
	return make("Part", parent, name, size, cf, color, mat, solid)
end

local function ballP(parent, name, d, cf, color, mat, solid)
	local p = P(parent, name, Vector3.new(d, d, d), cf, color, mat, solid)
	p.Shape = Enum.PartType.Ball
	return p
end

-- cylindre vertical centré sur cf
local function cylP(parent, name, d, h, cf, color, mat, solid)
	local p = P(parent, name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
	return l
end

-- barre entre deux points
local function seg3(parent, name, a: Vector3, b: Vector3, t: number, color, mat, solid)
	return P(parent, name, Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat, solid)
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function rayDown(origin: Vector3, len: number, exclude: { Instance })
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = exclude
	rp.RespectCanCollide = true
	return Workspace:Raycast(origin, Vector3.new(0, -len, 0), rp)
end

local function fits(cf: CFrame, size: Vector3, exclude: { Instance }): boolean
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = exclude
	op.RespectCanCollide = true
	return #Workspace:GetPartBoundsInBox(cf, size, op) == 0
end

--------------------------------------------------------------------------------
-- Glyphes inventés : tracés sur une grille 3x3, dans le plan XY de `base` (épaisseur selon Z)

local GRID = {}
for i = -1, 1 do
	for j = -1, 1 do
		table.insert(GRID, Vector2.new(i, j))
	end
end

local function glyph(parent, base: CFrame, s: number, color: Color3, depth: number, r: Random)
	local h = s / 2
	local w = math.max(s * 0.11, 0.12)
	local used = {}
	local cur = r:NextInteger(1, 9)
	for _ = 1, r:NextInteger(3, 5) do
		local nbs = {}
		for k, g in GRID do
			local key = math.min(k, cur) * 10 + math.max(k, cur)
			if k ~= cur and (g - GRID[cur]).Magnitude < 1.5 and not used[key] then
				table.insert(nbs, k)
			end
		end
		if #nbs > 0 then
			local nxt = nbs[r:NextInteger(1, #nbs)]
			used[math.min(nxt, cur) * 10 + math.max(nxt, cur)] = true
			local a, b = GRID[cur] * h, GRID[nxt] * h
			local d = b - a
			P(parent, "Glyphe", Vector3.new(d.Magnitude + w, w, depth),
				base * CFrame.new((a.X + b.X) / 2, (a.Y + b.Y) / 2, 0) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), color, NEON)
			cur = if r:NextNumber() < 0.75 then nxt else r:NextInteger(1, 9)
		else
			cur = r:NextInteger(1, 9)
		end
	end
	if r:NextNumber() < 0.45 then
		-- point diacritique au-dessus du signe
		P(parent, "Glyphe", Vector3.new(w * 1.5, w * 1.5, depth), base * CFrame.new(0, h + w * 2.6, 0), color, NEON)
	end
end

-- Cercle tracé au sol (horizontal). groundY(pos) -> y du sol, ou nil pour garder la hauteur du centre.
local function circleLine(parent, center: Vector3, radius: number, n: number, w: number, color, groundY)
	local chord = 2 * radius * math.sin(math.pi / n) + w
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local y = (groundY and groundY(pos)) or center.Y
		pos = Vector3.new(pos.X, y + 0.05, pos.Z)
		P(parent, "Trace", Vector3.new(chord, 0.1, w), CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)), color, NEON)
	end
end

-- Couronne de glyphes posée au sol, lisible depuis le centre.
local function glyphRing(parent, center: Vector3, radius: number, count: number, s: number, color, r: Random, groundY)
	local f = model(parent, "CercleGlyphes")
	local n = math.max(32, count * 2)
	circleLine(f, center, radius - s * 0.85, n, 0.22, color, groundY)
	circleLine(f, center, radius + s * 0.85, n, 0.22, color, groundY)
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local y = (groundY and groundY(pos)) or center.Y
		pos = Vector3.new(pos.X, y + 0.05, pos.Z)
		local base = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)) * CFrame.Angles(-math.pi / 2, 0, 0)
		glyph(f, base, s, color, 0.1, r)
	end
	return f
end

--------------------------------------------------------------------------------
-- Pièces de décor

-- Veilleur : gardien masqué, mains posées sur un glaive planté. cf = centre du socle au sol, regard vers -Z.
local function veilleur(parent, cf: CFrame, s: number, glow: Color3, cloth: Color3, r: Random)
	local m = model(parent, "Veilleur")
	local function at(x, y, z)
		return cf * CFrame.new(x * s, y * s, z * s)
	end
	local function V(x, y, z)
		return at(x, y, z).Position
	end
	local function box(name, sx, sy, sz, x, y, z, color, mat, solid, rot)
		return P(m, name, Vector3.new(sx, sy, sz) * s, at(x, y, z) * (rot or CFrame.identity), color, mat, solid)
	end
	box("Socle", 6, 2, 6, 0, 1, 0, C.Slate, SLATE, true)
	box("Liseré", 6.3, 0.35, 6.3, 0, 2.05, 0, C.Patina, CMETAL, true)
	box("Socle", 5.2, 0.8, 5.2, 0, 2.4, 0, C.Basalt, BASALT, true)
	for i = -1, 1 do
		glyph(m, at(i * 1.7, 1, -3.04), 1.1 * s, glow, 0.1 * s, r)
	end
	box("Ourlet", 4, 0.7, 2.9, 0, 3.15, 0.1, C.Basalt, BASALT, true)
	box("Robe", 3.3, 5, 2.3, 0, 5.3, 0.1, C.Basalt, BASALT, true)
	box("Ceinture", 3.5, 0.5, 2.4, 0, 7.8, 0.05, C.Patina, CMETAL)
	box("Torse", 3.6, 3, 2.2, 0, 9.5, 0.05, C.Slate, SLATE, true)
	box("Plastron", 2.4, 1.8, 0.3, 0, 9.7, -1.1, C.Patina, CMETAL)
	box("Sceau", 0.25, 1.2, 0.1, 0, 9.7, -1.27, glow, NEON)
	box("Sceau", 0.9, 0.22, 0.1, 0, 9.9, -1.27, glow, NEON)
	for sx = -1, 1, 2 do
		ballP(m, "Épaulière", 2 * s, at(sx * 2, 10.6, 0.05), C.Patina, CMETAL)
		seg3(m, "Bras", V(sx * 2.1, 10.3, 0), V(sx * 2.0, 8.3, -0.5), 0.9 * s, C.Slate, SLATE)
		seg3(m, "AvantBras", V(sx * 2.0, 8.3, -0.5), V(sx * 0.45, 7.4, -1.9), 0.8 * s, C.Slate, SLATE)
		box("Main", 0.75, 0.75, 0.75, sx * 0.4, 7.4, -1.95, C.Slate, SLATE)
	end
	box("Cou", 1, 0.7, 1, 0, 11.3, 0.05, C.Basalt, BASALT)
	box("Heaume", 1.8, 2.1, 1.9, 0, 12.6, 0.05, C.Basalt, BASALT, true)
	box("Mentonnière", 1.9, 0.5, 2, 0, 11.8, 0.05, C.Patina, CMETAL)
	local visor = box("Visière", 1.5, 0.2, 0.1, 0, 12.8, -0.92, glow, NEON)
	box("Cimier", 0.35, 1.3, 2.3, 0, 14.2, 0.15, C.Patina, CMETAL, false, CFrame.Angles(math.rad(-12), 0, 0))
	box("Cape", 4, 8.6, 0.35, 0, 7, 1.35, cloth, FABRIC, false, CFrame.Angles(math.rad(-5), 0, 0))
	-- glaive planté dans le socle
	box("Lame", 0.35, 4.8, 1.2, 0, 4.6, -1.95, C.SlateLight, MARBLE)
	box("Fil", 0.42, 4.2, 0.16, 0, 4.4, -1.95, glow, NEON)
	box("Garde", 2.6, 0.35, 0.55, 0, 7.05, -1.95, C.Patina, CMETAL)
	box("Poignée", 0.3, 1.2, 0.3, 0, 7.8, -1.95, C.Wood, WOOD)
	ballP(m, "Pommeau", 0.55 * s, at(0, 8.55, -1.95), glow, NEON)
	light(visor, glow, 10 * s, 1.2)
	return m
end

-- Monolithe gravé d'une colonne de glyphes sur la face -Z. cf = base au sol.
local function monolithe(parent, cf: CFrame, s: number, glow: Color3, r: Random)
	local m = model(parent, "Monolithe")
	local function at(x, y, z)
		return cf * CFrame.new(x * s, y * s, z * s)
	end
	P(m, "Assise", Vector3.new(6, 1.2, 3.6) * s, at(0, 0.6, 0), C.Patina, CMETAL, true)
	P(m, "Stèle", Vector3.new(4.2, 16, 1.8) * s, at(0, 9.2, 0), C.Basalt, BASALT, true)
	P(m, "Gravure", Vector3.new(3.2, 14, 0.2) * s, at(0, 9, -0.95), C.Slate, SLATE)
	for k = 0, 4 do
		glyph(m, at(0, 3.6 + k * 2.7, -1.08), 2 * s, glow, 0.12 * s, r)
	end
	P(m, "Couronne", Vector3.new(4.8, 0.7, 2.4) * s, at(0, 17.55, 0), C.Patina, CMETAL)
	P(m, "Pointe", Vector3.new(2.2, 2.2, 1.6) * s, at(0, 18.4, 0) * CFrame.Angles(0, 0, math.rad(45)), C.Basalt, BASALT)
	local shard = P(m, "Éclat", Vector3.new(0.8, 2.6, 0.8) * s, at(0, 21.2, 0) * CFrame.Angles(0, math.rad(45), math.rad(8)), glow, NEON)
	light(shard, glow, 18 * s, 1.4)
	return m
end

-- Grappe de cristaux sur un rocher. pos = point au sol.
local function cristaux(parent, pos: Vector3, s: number, color: Color3, r: Random)
	local m = model(parent, "Cristaux")
	ballP(m, "Roche", 3.2 * s, CFrame.new(pos - Vector3.new(0, s * 0.9, 0)), C.Rock, ROCK, true)
	for i = 1, r:NextInteger(4, 7) do
		local h = s * r:NextNumber(2.5, 8)
		local w = s * r:NextNumber(0.7, 1.4)
		local cf = CFrame.new(pos) * CFrame.Angles(r:NextNumber(-0.55, 0.55), r:NextNumber(0, 6.28), r:NextNumber(-0.55, 0.55))
			* CFrame.new(0, h * 0.4, 0) * CFrame.Angles(0, math.rad(45), 0)
		local core = i <= 2
		local p = P(m, "Éclat", Vector3.new(w, h, w), cf, color, if core then NEON else GLASS)
		p.Transparency = if core then 0.1 else 0.3
		p.Reflectance = if core then 0 else 0.15
		if i == 1 then
			light(p, color, 16 * s, 1.6)
		end
	end
	return m
end

-- Anneau segmenté (bronze + filet lumineux) dans le plan XZ de `base`. skip(cf, size) -> true pour sauter un segment.
local function bronzeRing(parent, base: CFrame, radius: number, glow: Color3, thick: number, skip)
	local n = math.max(16, math.floor(radius * 1.6))
	local chord = 2 * radius * math.sin(math.pi / n) * 1.04
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local b = base * CFrame.Angles(0, -a, 0)
		local cf = b * CFrame.new(radius, 0, 0)
		local size = Vector3.new(thick * 1.3, thick, chord)
		if not (skip and skip(cf, size)) then
			P(parent, "Anneau", size, cf, C.Patina, CMETAL)
			P(parent, "AnneauLueur", Vector3.new(0.25, thick * 0.4, chord), b * CFrame.new(radius - thick * 0.7, 0, 0), glow, NEON)
		end
	end
end

local function seq(...)
	local a = { ... }
	local kp = {}
	for i = 1, #a, 2 do
		table.insert(kp, NumberSequenceKeypoint.new(a[i], a[i + 1]))
	end
	return NumberSequence.new(kp)
end

local function emitter(parent, name: string, cf: CFrame, size: Vector3, props)
	local p = P(parent, name, size, cf, C.Basalt, M.SmoothPlastic)
	p.Transparency = 1
	p.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	for k, v in props do
		e[k] = v
	end
	e.Parent = p
	return e
end

local function mist(parent, cf: CFrame, size: Vector3, color: Color3, rate: number, s0: number, s1: number)
	return emitter(parent, "Brume", cf, size, {
		Texture = TEX.smoke,
		Color = ColorSequence.new(color),
		Rate = rate,
		Lifetime = NumberRange.new(10, 16),
		Speed = NumberRange.new(0.3, 1.2),
		Size = seq(0, s0, 1, s1),
		Transparency = seq(0, 1, 0.25, 0.86, 0.75, 0.9, 1, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-8, 8),
		LightEmission = 0.15,
		LightInfluence = 0.7,
		SpreadAngle = Vector2.new(180, 20),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0.3, 0.05, 0.2),
	})
end

local function motes(parent, name, cf, size, c0: Color3, c1: Color3, rate, dir: Vector3, speed: NumberRange, life: NumberRange, sz: number)
	return emitter(parent, name, cf, size, {
		Texture = TEX.spark,
		Color = ColorSequence.new(c0, c1),
		LightEmission = 1,
		Rate = rate,
		Lifetime = life,
		Speed = speed,
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = dir,
		Size = seq(0, 0, 0.2, sz, 0.8, sz * 0.8, 1, 0),
		Transparency = seq(0, 0.2, 1, 0.6),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
end

--------------------------------------------------------------------------------
-- Éclairage

local LIGHT_KEYS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogEnd", "ExposureCompensation", "GeographicLatitude" }

-- Remplace atmosphère et post-effets de `target`, met à jour (ou crée) le ciel.
local function effects(target: Instance, cfg)
	for _, c in target:GetChildren() do
		if c:IsA("Atmosphere") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end
	local function mk(class, props)
		if not props then
			return
		end
		local e = Instance.new(class)
		for k, v in props do
			e[k] = v
		end
		e.Parent = target
	end
	mk("Atmosphere", cfg.atm)
	mk("ColorCorrectionEffect", cfg.cc)
	mk("BloomEffect", cfg.bloom)
	mk("SunRaysEffect", cfg.rays)
	if cfg.sky then
		local sky = target:FindFirstChildOfClass("Sky") or Instance.new("Sky")
		for k, v in cfg.sky do
			sky[k] = v
		end
		sky.Parent = target
	end
end

local HUB_LIGHT = {
	props = {
		ClockTime = 20.1,
		Brightness = 1.8,
		Ambient = rgb(58, 56, 84),
		OutdoorAmbient = rgb(92, 88, 132),
		FogColor = rgb(40, 36, 72),
		FogEnd = 1400,
		ExposureCompensation = 0.3,
		GeographicLatitude = 30,
	},
	atm = { Density = 0.36, Offset = 0.2, Color = rgb(120, 105, 180), Decay = rgb(70, 40, 110), Glare = 0.25, Haze = 2 },
	cc = { Contrast = 0.14, Saturation = 0.08, Brightness = 0.02, TintColor = rgb(232, 230, 255) },
	bloom = { Intensity = 1, Size = 26, Threshold = 0.95 },
	rays = { Intensity = 0.04, Spread = 0.5 },
	sky = { StarCount = 4000, MoonAngularSize = 16, SunAngularSize = 10, CelestialBodiesShown = true },
}

--------------------------------------------------------------------------------
-- Hub

local RING_CENTERS = { Vector3.new(-76, 0, 6), Vector3.new(76, 0, 6), Vector3.new(0, 0, 78) }
local function nearRing(p: Vector3, margin: number): boolean
	for _, c in RING_CENTERS do
		if (Vector3.new(p.X, 0, p.Z) - c).Magnitude < 20 + margin then
			return true
		end
	end
	return false
end

local function isGold(c: Color3): boolean
	return c.R > 0.6 and c.G > 0.38 and c.B < 0.38 and c.R - c.B > 0.35
end

local STONE = {
	[M.Limestone] = true, [M.Marble] = true, [M.SmoothPlastic] = true, [M.Plastic] = true, [M.Slate] = true,
	[M.Concrete] = true, [M.Sandstone] = true, [M.Granite] = true, [M.Pebble] = true, [M.Cobblestone] = true, [M.Basalt] = true,
}

-- Repeint le Hub existant : pierre claire -> pierre sombre, or -> bronze patiné, lueurs harmonisées.
-- Les couleurs des 3 arènes d'entraînement (lisibilité des files) sont conservées.
function S.palette()
	local hub = Workspace.Hub
	local san = hub:FindFirstChild("Sanctum")
	local rings = hub:FindFirstChild("DuelRings")
	local n = 0
	for _, p in hub:GetDescendants() do
		if not p:IsA("BasePart") or p.Transparency >= 0.99 or (san and p:IsDescendantOf(san)) then
			continue
		end
		local inRing = rings and p:IsDescendantOf(rings)
		local c, m = p.Color, p.Material
		local sat = math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B)
		local lum = (c.R + c.G + c.B) / 3
		if m == NEON then
			if not inRing then
				if c.B > c.R and c.G > 0.55 then
					p.Color = C.Ether
				elseif c.B > c.G and c.R > 0.4 then
					p.Color = C.Violet
				elseif c.R > c.B + 0.3 then
					p.Color = C.Amber
				end
			end
		elseif isGold(c) or m == M.Metal then
			p.Material = CMETAL
			p.Color = C.Patina
			p.Reflectance = 0
		elseif m == WOOD then
			p.Color = C.Wood
		elseif m == M.LeafyGrass or m == M.Grass then
			p.Color = if lum > 0.45 then C.LeafLight else C.Leaf
		elseif m == ROCK then
			p.Color = C.Rock
		elseif m == FABRIC then
			if not inRing then
				p.Color = if sat > 0.15 then C.Cloth else C.ClothDark
			end
		elseif m == GLASS then
			if c.B > c.R then
				p.Color = rgb(90, 210, 220)
			end
		elseif STONE[m] and sat < 0.16 then
			local floorish = p.Name == "Floor" or p.Name:match("^Ring%d") ~= nil or p.Name == "TerraceFloor" or p.Name == "Mosaic"
			if floorish then
				p.Material = MARBLE
				p.Color = C.Floor
			elseif lum > 0.72 then
				p.Material = SLATE
				p.Color = C.SlateLight
			elseif lum > 0.5 then
				p.Material = SLATE
				p.Color = C.Slate
			else
				p.Material = BASALT
				p.Color = C.Basalt
			end
			p.Reflectance = if floorish then 0.04 else 0
		else
			continue
		end
		n += 1
	end
	local T = Workspace.Terrain
	T:SetMaterialColor(M.Grass, rgb(46, 84, 70))
	T:SetMaterialColor(M.LeafyGrass, rgb(40, 78, 64))
	T:SetMaterialColor(M.Rock, rgb(64, 58, 68))
	T:SetMaterialColor(M.Slate, rgb(56, 54, 66))
	T:SetMaterialColor(M.Limestone, rgb(78, 76, 90))
	T:SetMaterialColor(M.Ground, rgb(58, 48, 46))
	T:SetMaterialColor(M.Mud, rgb(50, 42, 40))
	T:SetMaterialColor(M.Basalt, rgb(40, 38, 46))
	return n .. " parts repeintes"
end

function S.hub()
	local hub = Workspace.Hub
	local old = hub:FindFirstChild("Sanctum")
	if old then
		old:Destroy()
	end
	local f = model(hub, "Sanctum")
	local r = Random.new(20261030)
	local ex = { f }
	local motesPart = hub:FindFirstChild("AmbientMotes")
	if motesPart then
		table.insert(ex, motesPart)
	end
	local function groundY(pos: Vector3)
		local hit = rayDown(pos + Vector3.new(0, 30, 0), 60, ex)
		return hit and hit.Position.Y
	end
	local function okSpot(p: Vector3)
		return not nearRing(p, 4) and not (math.abs(p.X) < 46 and p.Z < -54)
	end

	-- 1. Cœur d'Éther : orrerie suspendue au-dessus de la place, reliée au sol par un rayon
	local O = CFrame.new(0, 46, 0)
	local core = ballP(f, "CoeurEther", 6, O, C.Ether, NEON)
	light(core, C.Ether, 60, 3)
	local shell = ballP(f, "Coque", 8.5, O, C.EtherSoft, GLASS)
	shell.Transparency = 0.7
	local orrery = model(f, "Orrerie")
	local rings = {
		{ 24, CFrame.Angles(math.rad(16), 0, math.rad(8)), C.Ether },
		{ 18, CFrame.Angles(math.rad(-28), math.rad(40), 0), C.Violet },
		{ 12.5, CFrame.Angles(math.rad(62), math.rad(-20), math.rad(14)), C.Amber },
	}
	for _, ring in rings do
		local rad, tilt, col = ring[1], ring[2], ring[3]
		bronzeRing(orrery, O * tilt, rad, col, 1.1)
		for k = 0, 3 do
			local b = O * tilt * CFrame.Angles(0, -(k / 4 * math.pi * 2 + rad), 0)
			ballP(orrery, "Astre", 1.8, b * CFrame.new(rad + 1.4, 0, 0), col, NEON)
		end
	end
	local beam = cylP(f, "Rayon", 0.9, 46, CFrame.new(0, 23, 0), C.EtherSoft, NEON)
	beam.Transparency = 0.45

	-- 2. Couronnes de glyphes gravées dans le dallage de la place
	glyphRing(f, Vector3.new(0, 0, 0), 22, 24, 2.4, C.Ether, r, groundY)
	glyphRing(f, Vector3.new(0, 0, 0), 47, 40, 2.6, C.Violet, r, groundY)

	-- 3. Monolithes gravés autour de la place (entre les arènes d'entraînement)
	local monos = 0
	for _, deg in { 30, 60, 120, 150, 205, 245, 295, 335 } do
		local a = math.rad(deg)
		local p = Vector3.new(math.cos(a) * 71, 0, math.sin(a) * 71)
		if okSpot(p) then
			local hit = rayDown(p + Vector3.new(0, 80, 0), 160, ex)
			if hit then
				local g = hit.Position
				local cf = CFrame.lookAt(g, Vector3.new(0, g.Y, 0))
				if fits(cf * CFrame.new(0, 10, 0), Vector3.new(5, 18, 3), ex) then
					monolithe(f, cf, 1, if deg < 180 then C.Ether else C.Violet, r)
					monos += 1
				end
			end
		end
	end

	-- 4. Veilleurs : deux gardiens en haut de l'escalier de la terrasse, deux colosses au nord
	local terrace = hub:FindFirstChild("Terrace")
	local tf = terrace and terrace:FindFirstChild("TerraceFloor")
	local statues = 0
	if tf then
		local top = tf.Position.Y + tf.Size.Y / 2
		local front = tf.Position.Z + tf.Size.Z / 2
		for sx = -1, 1, 2 do
			for _, inset in { 5, 9, 13, 17 } do
				local p = Vector3.new(tf.Position.X + sx * (tf.Size.X / 2 - inset), top, front - 5)
				local cf = CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
				if fits(cf * CFrame.new(0, 7, 0), Vector3.new(5.4, 12, 5.4), ex) then
					veilleur(f, cf, 0.9, C.Ether, C.Cloth, r)
					statues += 1
					break
				end
			end
		end
	end
	for _, deg in { 225, 315 } do
		local a = math.rad(deg)
		local p = Vector3.new(math.cos(a) * 94, 0, math.sin(a) * 94)
		local hit = rayDown(p + Vector3.new(0, 100, 0), 200, ex)
		local g = if hit then hit.Position else Vector3.new(p.X, -6, p.Z)
		veilleur(f, CFrame.lookAt(g - Vector3.new(0, 1, 0), Vector3.new(0, g.Y - 1, 0)), 2.1, C.Violet, C.ClothDark, r)
		statues += 1
	end

	-- 5. Grande Arche derrière la terrasse, un cristal suspendu en son cœur
	if tf then
		local top = tf.Position.Y + tf.Size.Y / 2
		local back = tf.Position.Z - tf.Size.Z / 2 - 8
		local A = CFrame.new(tf.Position.X, top, back)
		local arch = model(f, "GrandeArche")
		for sx = -1, 1, 2 do
			P(arch, "Pilier", Vector3.new(5, 70, 5), A * CFrame.new(sx * 17, -1, 0), C.Basalt, BASALT, true)
			P(arch, "Chapiteau", Vector3.new(6.4, 1.4, 6.4), A * CFrame.new(sx * 17, 33, 0), C.Patina, CMETAL)
			P(arch, "Bague", Vector3.new(6, 1, 6), A * CFrame.new(sx * 17, 2, 0), C.Patina, CMETAL)
			for k = 0, 6 do
				glyph(arch, A * CFrame.new(sx * 17, 6 + k * 3.6, 2.56), 2.2, C.Violet, 0.12, r)
			end
		end
		local n = 13
		local chord = 2 * 17 * math.sin(math.pi / (2 * n)) * 1.06
		for i = 0, n - 1 do
			local a = (i + 0.5) / n * math.pi
			local b = A * CFrame.new(0, 34, 0) * CFrame.Angles(0, 0, a)
			P(arch, "Voussoir", Vector3.new(5, chord, 5), b * CFrame.new(17, 0, 0), C.Slate, SLATE)
			P(arch, "VoussoirLueur", Vector3.new(0.3, chord, 1.4), b * CFrame.new(14.4, 0, 0), C.Violet, NEON)
		end
		local heart = A * CFrame.new(0, 34, 0)
		local big = P(arch, "CristalSuspendu", Vector3.new(3, 9, 3), heart * CFrame.Angles(0, math.rad(45), 0), C.Violet, NEON)
		light(big, C.Violet, 55, 2.4)
		P(arch, "Éclat", Vector3.new(1.6, 5, 1.6), heart * CFrame.new(-2.6, -1.5, 0) * CFrame.Angles(0, 0, math.rad(25)), C.Violet, NEON)
		P(arch, "Éclat", Vector3.new(1.4, 4.4, 1.4), heart * CFrame.new(2.4, -1.2, 0.4) * CFrame.Angles(0, 0, math.rad(-22)), C.Violet, NEON)
		seg3(arch, "Chaîne", (heart * CFrame.new(0, 4.5, 0)).Position, (A * CFrame.new(0, 49, 0)).Position, 0.3, C.Patina, CMETAL)
		motes(arch, "Étincelles", heart, Vector3.new(6, 8, 6), C.Violet, C.EtherSoft, 12, Vector3.new(0, 1.2, 0), NumberRange.new(1, 3), NumberRange.new(3, 5), 0.45)
	end

	-- 6. Cristaux d'éther dispersés sur l'île
	local placed = 0
	for _ = 1, 80 do
		if placed >= 18 then
			break
		end
		local a = r:NextNumber(0, math.pi * 2)
		local d = r:NextNumber(68, 125)
		local p = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if okSpot(p) then
			local hit = rayDown(p + Vector3.new(0, 100, 0), 200, ex)
			if hit and hit.Instance == Workspace.Terrain and fits(CFrame.new(hit.Position + Vector3.new(0, 4.5, 0)), Vector3.new(5, 7, 5), ex) then
				cristaux(f, hit.Position, r:NextNumber(0.7, 1.3), if r:NextNumber() < 0.5 then C.Ether else C.Violet, r)
				placed += 1
			end
		end
	end

	-- 7. Brume : bancs au ras du sol autour de la place, mer de nuages sous l'île
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = Vector3.new(math.cos(a) * 68, 0, math.sin(a) * 68)
		local hit = rayDown(p + Vector3.new(0, 80, 0), 160, ex)
		if hit then
			mist(f, CFrame.new(hit.Position + Vector3.new(0, 1.5, 0)), Vector3.new(18, 1, 18), rgb(150, 150, 205), 2.5, 10, 18)
		end
	end
	mist(f, CFrame.new(0, 1, 0), Vector3.new(110, 1, 110), rgb(140, 150, 205), 2, 12, 20)
	mist(f, CFrame.new(0, -28, 0), Vector3.new(340, 1, 340), rgb(70, 60, 120), 8, 40, 70)
	motes(f, "PoussièreÉther", CFrame.new(0, 10, 0), Vector3.new(120, 14, 120), C.Ether, C.Violet, 14, Vector3.new(0, 0.5, 0), NumberRange.new(0.2, 0.8), NumberRange.new(6, 10), 0.25)

	return string.format("hub : %d monolithes, %d veilleurs, %d cristaux", monos, statues, placed)
end

function S.hublight()
	local hub = Workspace.Hub
	local keep = hub:FindFirstChild("HubLighting") or Instance.new("Folder")
	keep.Name = "HubLighting"
	keep.Parent = hub
	for k, v in HUB_LIGHT.props do
		keep:SetAttribute(k, v)
		Lighting[k] = v
	end
	effects(Lighting, HUB_LIGHT)
	effects(keep, HUB_LIGHT)
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.45
	clouds.Density = 0.55
	clouds.Color = rgb(70, 60, 110)
	clouds.Parent = Workspace.Terrain
	return "éclairage du hub appliqué"
end

--------------------------------------------------------------------------------
-- Arènes : chacune sa palette, sa lumière et ses éléments, la zone de combat reste dégagée

local ARENAS = {}

ARENAS.Sanctuaire = {
	glow = C.Amber,
	props = {
		ClockTime = 17.9, Brightness = 2.2, Ambient = rgb(110, 80, 70), OutdoorAmbient = rgb(190, 130, 100),
		FogColor = rgb(230, 160, 120), FogEnd = 600, ExposureCompensation = 0.1, GeographicLatitude = 35,
	},
	atm = { Density = 0.35, Offset = 0.1, Color = rgb(240, 180, 140), Decay = rgb(140, 70, 90), Glare = 0.6, Haze = 2 },
	cc = { Contrast = 0.12, Saturation = 0.1, Brightness = 0, TintColor = rgb(255, 235, 215) },
	bloom = { Intensity = 0.9, Size = 24, Threshold = 1.2 },
	rays = { Intensity = 0.12, Spread = 0.7 },
	sky = { StarCount = 800, SunAngularSize = 18 },
	build = function(ctx)
		-- poussière dorée dans la lumière du couchant, encens au ras du sol, lanternes suspendues
		motes(ctx.f, "Poussière", CFrame.new(ctx.c + Vector3.new(0, 14, 0)), Vector3.new(90, 20, 90), rgb(255, 220, 160), C.Amber, 30,
			Vector3.new(0.2, 0.15, 0.1), NumberRange.new(0.1, 0.5), NumberRange.new(8, 12), 0.18)
		mist(ctx.f, CFrame.new(ctx.c + Vector3.new(0, 0.6, 0)), Vector3.new(100, 1, 100), rgb(255, 200, 170), 4, 10, 18)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local p = ctx.c + Vector3.new(math.cos(a) * 34, 20, math.sin(a) * 34)
			if fits(CFrame.new(p + Vector3.new(0, 3, 0)), Vector3.new(2.4, 10, 2.4), ctx.ex) then
				local m = model(ctx.f, "Lanterne")
				P(m, "Coiffe", Vector3.new(2.2, 0.5, 2.2), CFrame.new(p + Vector3.new(0, 1.6, 0)), C.Patina, CMETAL)
				P(m, "Fond", Vector3.new(1.8, 0.4, 1.8), CFrame.new(p - Vector3.new(0, 1.4, 0)), C.Patina, CMETAL)
				local glow = P(m, "Flamme", Vector3.new(1.1, 2.2, 1.1), CFrame.new(p), C.Amber, NEON)
				light(glow, C.Amber, 22, 1.5)
				for sx = -1, 1, 2 do
					for sz = -1, 1, 2 do
						seg3(m, "Montant", p + Vector3.new(sx * 0.9, -1.3, sz * 0.9), p + Vector3.new(sx * 0.9, 1.4, sz * 0.9), 0.18, C.Patina, CMETAL)
					end
				end
				seg3(m, "Chaîne", p + Vector3.new(0, 1.8, 0), p + Vector3.new(0, 9, 0), 0.15, C.Patina, CMETAL)
			end
		end
	end,
}

ARENAS.Forge = {
	glow = C.Ember,
	props = {
		ClockTime = 0.3, Brightness = 1.2, Ambient = rgb(90, 34, 18), OutdoorAmbient = rgb(160, 60, 24),
		FogColor = rgb(70, 20, 10), FogEnd = 380, ExposureCompensation = 0.15, GeographicLatitude = 30,
	},
	atm = { Density = 0.45, Offset = 0.1, Color = rgb(190, 70, 30), Decay = rgb(60, 10, 5), Glare = 0.2, Haze = 3 },
	cc = { Contrast = 0.18, Saturation = 0.15, Brightness = 0, TintColor = rgb(255, 222, 200) },
	bloom = { Intensity = 1.2, Size = 30, Threshold = 0.9 },
	rays = { Intensity = 0.03, Spread = 0.4 },
	sky = { StarCount = 300 },
	build = function(ctx)
		-- cendres qui tombent, braises qui montent de la lave, deux colosses engloutis
		emitter(ctx.f, "Cendres", CFrame.new(ctx.c + Vector3.new(0, 50, 0)), Vector3.new(200, 1, 200), {
			Texture = TEX.spark, Color = ColorSequence.new(rgb(120, 110, 105), rgb(70, 64, 60)), Rate = 60,
			Lifetime = NumberRange.new(12, 16), Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(20, 20), Acceleration = Vector3.new(1, -0.6, 0.5), Size = seq(0, 0.25, 1, 0.2),
			Transparency = seq(0, 0.3, 1, 0.8), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), LightEmission = 0,
		})
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local p = ctx.c + Vector3.new(math.cos(a) * (ctx.R + 14), -10, math.sin(a) * (ctx.R + 14))
			motes(ctx.f, "Braises", CFrame.new(p), Vector3.new(22, 1, 22), rgb(255, 210, 90), C.Ember, 14,
				Vector3.new(0, 3, 0), NumberRange.new(5, 10), NumberRange.new(3, 6), 0.35)
		end
		for sx = -1, 1, 2 do
			local base = Vector3.new(ctx.c.X + sx * 110, ctx.floorY - 34, ctx.c.Z)
			veilleur(ctx.f, CFrame.lookAt(base, Vector3.new(ctx.c.X, base.Y, ctx.c.Z)), 4.2, C.Ember, rgb(60, 20, 14), ctx.r)
		end
	end,
}

ARENAS.Ruines = {
	glow = C.Frost,
	props = {
		ClockTime = 0, Brightness = 0.8, Ambient = rgb(44, 52, 70), OutdoorAmbient = rgb(70, 84, 110),
		FogColor = rgb(34, 40, 54), FogEnd = 320, ExposureCompensation = 0.2, GeographicLatitude = 30,
	},
	atm = { Density = 0.5, Offset = 0.05, Color = rgb(90, 100, 130), Decay = rgb(40, 50, 70), Glare = 0, Haze = 2.5 },
	cc = { Contrast = 0.15, Saturation = -0.15, Brightness = 0, TintColor = rgb(215, 225, 255) },
	bloom = { Intensity = 0.8, Size = 24, Threshold = 1.1 },
	rays = { Intensity = 0, Spread = 0.2 },
	sky = { StarCount = 0 },
	build = function(ctx)
		-- pluie battante, brume au sol, stèles brisées et Veilleur renversé hors de l'aire de duel
		emitter(ctx.f, "Pluie", CFrame.new(ctx.c + Vector3.new(0, 70, 0)), Vector3.new(240, 1, 240), {
			Texture = TEX.spark, Color = ColorSequence.new(rgb(170, 190, 230)), Rate = 280,
			Lifetime = NumberRange.new(1.3, 1.6), Speed = NumberRange.new(60, 70), EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(3, 3), Size = seq(0, 0.12, 1, 0.12), Squash = seq(0, -2.5, 1, -2.5),
			Orientation = Enum.ParticleOrientation.VelocityParallel, Transparency = seq(0, 0.35, 1, 0.35), LightEmission = 0.2,
		})
		mist(ctx.f, CFrame.new(ctx.c + Vector3.new(0, 0.8, 0)), Vector3.new(200, 1, 200), rgb(140, 150, 185), 6, 14, 24)
		local fallen = CFrame.new(ctx.c + Vector3.new(ctx.R + 18, ctx.floorY - ctx.c.Y - 2.5, -20)) * CFrame.Angles(0, math.rad(30), math.rad(84))
		veilleur(ctx.f, fallen, 2, rgb(120, 110, 200), C.ClothDark, ctx.r)
		local placed = 0
		for _ = 1, 40 do
			if placed >= 6 then
				break
			end
			local a = ctx.r:NextNumber(0, math.pi * 2)
			local d = ctx.R + ctx.r:NextNumber(8, 34)
			local p = ctx.c + Vector3.new(math.cos(a) * d, 30, math.sin(a) * d)
			local hit = rayDown(p, 80, ctx.ex)
			if hit then
				local cf = CFrame.lookAt(hit.Position, Vector3.new(ctx.c.X, hit.Position.Y, ctx.c.Z)) * CFrame.Angles(math.rad(ctx.r:NextNumber(-8, 8)), 0, math.rad(ctx.r:NextNumber(-8, 8)))
				if fits(cf * CFrame.new(0, 7, 0), Vector3.new(4, 11, 3), ctx.ex) then
					monolithe(ctx.f, cf, 0.6, rgb(150, 120, 255), ctx.r)
					placed += 1
				end
			end
		end
	end,
}

ARENAS.Reacteur = {
	glow = C.Ether,
	props = {
		ClockTime = 0, Brightness = 0.5, Ambient = rgb(40, 40, 70), OutdoorAmbient = rgb(60, 60, 110),
		FogColor = rgb(12, 10, 30), FogEnd = 650, ExposureCompensation = 0.25, GeographicLatitude = 30,
	},
	atm = { Density = 0.35, Offset = 0, Color = rgb(80, 60, 140), Decay = rgb(20, 40, 80), Glare = 0, Haze = 1 },
	cc = { Contrast = 0.2, Saturation = 0.2, Brightness = 0, TintColor = rgb(230, 222, 255) },
	bloom = { Intensity = 1.3, Size = 28, Threshold = 0.8 },
	rays = { Intensity = 0, Spread = 0.2 },
	sky = { StarCount = 5000 },
	build = function(ctx)
		-- le Puits d'Éther : particules montant du vide, anneaux runiques flottant autour du puits
		motes(ctx.f, "RemontéeÉther", CFrame.new(ctx.c + Vector3.new(0, -50, 0)), Vector3.new(160, 1, 160), C.Ether, C.Violet, 40,
			Vector3.new(0, 2, 0), NumberRange.new(8, 14), NumberRange.new(8, 11), 0.5)
		local function skip(cf, size)
			return not fits(cf, size + Vector3.new(2, 2, 2), ctx.ex)
		end
		for k, spec in { { 62, -10, C.Ether }, { 80, 24, C.Violet }, { 96, -32, C.Ether } } do
			local base = CFrame.new(ctx.c + Vector3.new(0, spec[2], 0)) * CFrame.Angles(math.rad(k * 3 - 6), 0, 0)
			bronzeRing(ctx.f, base, spec[1], spec[3], 2, skip)
			local count = math.floor(spec[1] / 3)
			for i = 0, count - 1 do
				local a = (i + 0.5) / count * math.pi * 2
				local b = base * CFrame.Angles(0, -a, 0) * CFrame.new(spec[1] + 1.35, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
				if not skip(b, Vector3.new(2, 2, 2)) then
					glyph(ctx.f, b, 1.5, spec[3], 0.1, ctx.r)
				end
			end
		end
	end,
}

ARENAS.Cristaux = {
	glow = C.Rose,
	props = {
		ClockTime = 22, Brightness = 0.6, Ambient = rgb(30, 50, 80), OutdoorAmbient = rgb(50, 70, 120),
		FogColor = rgb(16, 22, 50), FogEnd = 450, ExposureCompensation = 0.25, GeographicLatitude = 30,
	},
	atm = { Density = 0.4, Offset = 0.05, Color = rgb(60, 90, 160), Decay = rgb(80, 30, 120), Glare = 0, Haze = 1.5 },
	cc = { Contrast = 0.12, Saturation = 0.25, Brightness = 0, TintColor = rgb(220, 235, 255) },
	bloom = { Intensity = 1.4, Size = 32, Threshold = 0.8 },
	rays = { Intensity = 0, Spread = 0.2 },
	sky = { StarCount = 3000 },
	build = function(ctx)
		-- spores bioluminescentes en suspension et grappes de cristaux sur les bords du gouffre
		motes(ctx.f, "Spores", CFrame.new(ctx.c + Vector3.new(0, 12, 0)), Vector3.new(140, 30, 140), C.Ether, C.Rose, 25,
			Vector3.new(0, 0.3, 0), NumberRange.new(0.2, 0.6), NumberRange.new(8, 12), 0.3)
		mist(ctx.f, CFrame.new(ctx.c + Vector3.new(0, 0.6, 0)), Vector3.new(160, 1, 160), rgb(90, 110, 190), 4, 12, 20)
		local placed = 0
		for _ = 1, 90 do
			if placed >= 16 then
				break
			end
			local a = ctx.r:NextNumber(0, math.pi * 2)
			local d = ctx.R + ctx.r:NextNumber(6, 50)
			local hit = rayDown(ctx.c + Vector3.new(math.cos(a) * d, 60, math.sin(a) * d), 140, ctx.ex)
			if hit and fits(CFrame.new(hit.Position + Vector3.new(0, 4.5, 0)), Vector3.new(5, 7, 5), ctx.ex) then
				cristaux(ctx.f, hit.Position, ctx.r:NextNumber(0.9, 1.8), if placed % 2 == 0 then C.Ether else C.Rose, ctx.r)
				placed += 1
			end
		end
	end,
}

function S.arena(id: string)
	local cfg = ARENAS[id]
	assert(cfg, "arène inconnue : " .. tostring(id))
	local m = ServerStorage.EtherBladesAssets.Arenas:FindFirstChild(id)
	assert(m, "modèle d'arène absent : " .. id)
	local oldParent = m.Parent
	m.Parent = Workspace -- les rayons et requêtes spatiales ne voient que Workspace
	local ok, err = pcall(function()
		local old = m:FindFirstChild("Ambiance")
		if old then
			old:Destroy()
		end
		local f = model(m, "Ambiance")
		local ex = { f, m:FindFirstChild("Markers") }
		local c = m.Markers.Center.Position
		local hit = rayDown(c + Vector3.new(0, 4, 0), 40, ex)
		local floorY = if hit then hit.Position.Y else c.Y - 3
		-- rayon de l'aire de duel : on avance jusqu'au bord du sol plat (ou 80 studs au plus)
		local R = 80
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			for d = 4, 80, 2 do
				local h = rayDown(Vector3.new(c.X + math.cos(a) * d, floorY + 3, c.Z + math.sin(a) * d), 8, ex)
				if not h or math.abs(h.Position.Y - floorY) > 1.2 then
					R = math.min(R, d)
					break
				end
			end
		end
		local ctx = { m = m, f = f, ex = ex, c = c, floorY = floorY, R = R, r = Random.new(#id * 7919) }
		-- couronne de glyphes au centre de l'aire : repère visuel plat, entoure les deux points d'apparition
		glyphRing(f, Vector3.new(c.X, floorY, c.Z), 18, 20, 2, cfg.glow, ctx.r, function(pos)
			local g = rayDown(pos + Vector3.new(0, 3, 0), 6, ex)
			return g and g.Position.Y
		end)
		cfg.build(ctx)
		local folder = m:FindFirstChild("Lighting") or Instance.new("Folder")
		folder.Name = "Lighting"
		folder.Parent = m
		for k, v in cfg.props do
			folder:SetAttribute(k, v)
		end
		effects(folder, cfg)
		ctx.result = string.format("%s : sol %.1f, rayon %d, %d pièces de décor", id, floorY, R, #f:GetDescendants())
		S._last = ctx.result
	end)
	m.Parent = oldParent
	assert(ok, err)
	return S._last
end

function S.run(section: string, arg: string?)
	local fn = S[section]
	assert(type(fn) == "function", "section inconnue : " .. tostring(section))
	return fn(arg)
end

return S
