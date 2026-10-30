--!nocheck
-- Ether Blades : construction du Hub v2 (sanctuaire flottant dans le ciel d'éther).
-- Disposition : grande place circulaire au centre, escalier nord vers la terrasse des classements
-- (colonnes géantes + bannières), 3 arènes d'entraînement circulaires avec rambardes dorées (pods de file),
-- murets en ruine, colonnes brisées, îles flottantes boisées, cristaux d'éther.
-- Outil d'édition : à exécuter depuis la barre de commande / MCP Studio (mode Edit), section par section :
--   local B = require(ServerStorage.EB_HubV2) ; B.run("all")  (ou "base", "plaza", "terrace", "rings", "ruins", "sky", "props", "light")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local B = {}
local rng = Random.new(20261029)

local KIT = ServerStorage:FindFirstChild("EtherBladesAssets") and ServerStorage.EtherBladesAssets:FindFirstChild("Kit")

-- Palette « éther »
local C = {
	Marble = Color3.fromRGB(232, 226, 214),
	MarbleWarm = Color3.fromRGB(214, 202, 182),
	MarbleDark = Color3.fromRGB(176, 166, 150),
	Seam = Color3.fromRGB(150, 140, 126),
	Stone = Color3.fromRGB(168, 160, 142),
	StoneDark = Color3.fromRGB(122, 116, 104),
	Moss = Color3.fromRGB(96, 128, 70),
	MossLight = Color3.fromRGB(128, 160, 86),
	Gold = Color3.fromRGB(232, 184, 72),
	GoldDark = Color3.fromRGB(176, 128, 44),
	Ether = Color3.fromRGB(80, 230, 255),
	EtherDeep = Color3.fromRGB(40, 120, 255),
	Violet = Color3.fromRGB(170, 110, 255),
	Navy = Color3.fromRGB(24, 32, 78),
	Banner = Color3.fromRGB(30, 46, 120),
	Bark = Color3.fromRGB(96, 70, 50),
	Leaf = Color3.fromRGB(82, 140, 76),
	LeafLight = Color3.fromRGB(120, 176, 96),
	Clay = Color3.fromRGB(150, 104, 74),
	Ranked = Color3.fromRGB(255, 196, 64),
	Casual = Color3.fromRGB(64, 220, 255),
	Challenge = Color3.fromRGB(255, 90, 140),
}

local PLAZA_R = 62

--------------------------------------------------------------------------------
-- Outils

local root: Model

local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Model")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, o: any?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	-- l'or en Metal vire au vert sous l'éclairage : plastique lisse réfléchissant à la place
	if color == C.Gold and mat == Enum.Material.Metal then
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.22
	end
	if o then
		for k, v in o do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, name: string, diameter: number, height: number, pos: Vector3, color: Color3, mat: Enum.Material, o: any?): BasePart
	-- cylindre vertical (l'axe des cylindres Roblox est X : on le couche)
	return P(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, mat, (function()
		local t = o or {}
		t.Shape = Enum.PartType.Cylinder
		return t
	end)())
end

local function ball(parent: Instance, name: string, d: number, pos: Vector3, color: Color3, mat: Enum.Material, o: any?): BasePart
	local t = o or {}
	t.Shape = Enum.PartType.Ball
	return P(parent, name, Vector3.new(d, d, d), CFrame.new(pos), color, mat, t)
end

local function light(part: BasePart, color: Color3, range: number, brightness: number, kind: string?)
	local l = Instance.new(kind or "PointLight")
	;(l :: any).Color = color
	;(l :: any).Range = range
	;(l :: any).Brightness = brightness
	l.Parent = part
	return l
end

local function kit(name: string, parent: Instance, cf: CFrame, scale: number?): Model?
	if not KIT then
		return nil
	end
	local src = KIT:FindFirstChild(name)
	if not src then
		return nil
	end
	local m = src:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	m:PivotTo(cf)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m.Parent = parent
	return m
end

-- Anneau de segments (dalles, rambardes…) : fn(angle, cframe au rayon r)
local function around(n: number, r: number, y: number, fn: (number, CFrame) -> (), center: Vector3?)
	local c = center or Vector3.zero
	for i = 0, n - 1 do
		local a = (i / n) * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		fn(a, CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z)))
	end
end

local function marker(parent: Instance, name: string, cf: CFrame, size: Vector3?): BasePart
	return P(parent, name, size or Vector3.new(4, 1, 4), cf, C.Ether, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = true,
		CanTouch = false,
		CastShadow = false,
	})
end

-- Centres des 3 arènes d'entraînement (pods de file)
B.RingCenters = {
	Vector3.new(-PLAZA_R - 14, 0, 6),
	Vector3.new(PLAZA_R + 14, 0, 6),
	Vector3.new(0, 0, PLAZA_R + 16),
}

-- Vrai si `p` (au sol) est à moins de `margin` studs du bord d'une arène.
function B.nearRing(p: Vector3, margin: number): boolean
	for _, c in B.RingCenters do
		if (Vector3.new(p.X, 0, p.Z) - c).Magnitude < 20 + margin then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- 1. Île porteuse (Terrain) + socle de la place

function B.base()
	local t = Workspace.Terrain
	-- corps rocheux de l'île principale, effilé vers le bas
	-- boules empilées sous la dalle : le sommet de chacune reste sous y = -4
	for i = 0, 7 do
		local rad = (92 - i * 10) * 0.62
		t:FillBall(Vector3.new(rng:NextNumber(-6, 6), -4 - rad - i * 9, rng:NextNumber(-6, 6) - 10), rad, if i > 4 then Enum.Material.Slate else Enum.Material.Rock)
	end
	t:FillBall(Vector3.new(0, -150, -8), 14, Enum.Material.Basalt)
	-- rebord herbeux et extension nord (terrasse) + pentes est / ouest
	-- couleurs chaudes façon roche sédimentaire, herbe tendre
	t:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(132, 112, 92))
	t:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(104, 92, 82))
	t:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(110, 150, 72))
	t:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 146, 70))
	t:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(70, 64, 60))
	-- galette rocheuse sous la dalle (sommet à y = -2), terrasse nord (sommet sous le plateau à 7,7)
	t:FillCylinder(CFrame.new(0, -8, 0), 7, 64, Enum.Material.Rock) -- (hauteur, rayon) : sommet à -4,5
	t:FillBlock(CFrame.new(0, -0.5, -112), Vector3.new(96, 12, 60), Enum.Material.Rock) -- sommet à 5,5 sous le plateau
	-- herbe uniquement en couronne autour de la place (anneau de boules)
	for i = 0, 47 do
		local a = i / 48 * math.pi * 2
		local gp = Vector3.new(math.cos(a) * 70, -6, math.sin(a) * 70)
		if not B.nearRing(gp, 4) then
			t:FillBall(gp, 7, Enum.Material.LeafyGrass)
		end
	end
	for x = -44, 44, 8 do
		t:FillBall(Vector3.new(x, 5.4, -138), 5, Enum.Material.LeafyGrass)
	end
	-- rochers moussus autour
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(PLAZA_R + 12, 86)
		local p = Vector3.new(math.cos(a) * r, rng:NextNumber(-3, 0), math.sin(a) * r)
		if B.nearRing(p, 9) then
			continue
		end
		t:FillBall(p, rng:NextNumber(3, 7), if rng:NextNumber() < 0.5 then Enum.Material.Rock else Enum.Material.Slate)
		t:FillBall(p + Vector3.new(0, 2.5, 0), rng:NextNumber(2, 4), Enum.Material.Grass)
	end
end

--------------------------------------------------------------------------------
-- 2. Place circulaire en marbre (motif concentrique + veines d'éther)

function B.plaza()
	local f = folder(root, "Plaza")
	-- dalle de base
	cyl(f, "Floor", PLAZA_R * 2, 7, Vector3.new(0, -3.5, 0), C.MarbleWarm, Enum.Material.Limestone)
	-- anneaux concentriques en relief léger (alternance de teintes)
	local rings = { { 60, C.Marble }, { 52, C.MarbleWarm }, { 46, C.Marble }, { 36, C.MarbleDark }, { 34, C.Marble }, { 22, C.MarbleWarm }, { 14, C.Marble } }
	for i, r in rings do
		cyl(f, "Ring" .. i, r[1] * 2, 0.08 + i * 0.01, Vector3.new(0, 0.04 + i * 0.005, 0), r[2], Enum.Material.Limestone, { CastShadow = false })
	end
	-- joints de dalles rayonnants (tous les 15°) entre les anneaux
	for k = 0, 23 do
		local a = math.rad(k * 15)
		for _, band in { { 14, 22 }, { 36, 46 }, { 52, 60 } } do
			local r0, r1 = band[1], band[2]
			local mid = (r0 + r1) / 2
			local pos = Vector3.new(math.cos(a) * mid, 0.13, math.sin(a) * mid)
			P(f, "Seam", Vector3.new(0.25, 0.04, r1 - r0), CFrame.lookAt(pos, Vector3.new(0, 0.13, 0)), C.Seam, Enum.Material.Slate, { CanCollide = false, CastShadow = false })
		end
	end
	-- cercles de séparation (fins anneaux sombres) et veines d'éther lumineuses
	for _, r in { 14, 22, 34, 36, 46, 52, 60 } do
		around(math.floor(r * 1.4), r, 0.12, function(a, cf)
			P(f, "Line", Vector3.new(2 * math.pi * r / math.floor(r * 1.4) + 0.05, 0.05, 0.22), cf, C.Seam, Enum.Material.Slate, { CanCollide = false, CastShadow = false })
		end)
	end
	for _, r in { 22, 46 } do
		around(math.floor(r * 1.4), r + 0.5, 0.14, function(a, cf)
			P(f, "EtherVein", Vector3.new(2 * math.pi * r / math.floor(r * 1.4) + 0.05, 0.05, 0.14), cf, C.Ether, Enum.Material.Neon, { CanCollide = false, CastShadow = false, Transparency = 0.15 })
		end)
	end
	-- rosace centrale : étoile à 8 branches dorée + cœur d'éther
	for k = 0, 7 do
		local a = math.rad(k * 45)
		local pos = Vector3.new(math.cos(a) * 6, 0.16, math.sin(a) * 6)
		P(f, "StarArm", Vector3.new(1.2, 0.06, 11), CFrame.lookAt(pos, Vector3.new(0, 0.16, 0)), C.Gold, Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false, Reflectance = 0.2 })
	end
	local core = cyl(f, "EtherCore", 4, 0.2, Vector3.new(0, 0.18, 0), C.Ether, Enum.Material.Neon, { CanCollide = false })
	light(core, C.Ether, 18, 1.2)
	-- bordure : marche périphérique en pierre
	around(48, PLAZA_R + 1, -0.2, function(a, cf)
		P(f, "Curb", Vector3.new(2 * math.pi * (PLAZA_R + 1) / 48 + 0.3, 1.2, 2.4), cf, C.Stone, Enum.Material.Limestone)
	end)
	-- point d'apparition au centre
	local sp = Instance.new("SpawnLocation")
	sp.Name = "HubSpawn"
	sp.Anchored = true
	sp.Size = Vector3.new(6, 0.2, 6)
	sp.CFrame = CFrame.new(0, 0.25, 8)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Duration = 0
	sp.Parent = root
end

--------------------------------------------------------------------------------
-- Éléments architecturaux détaillés (en Parts, à défaut de Blender)

-- Colonne cannelée : base moulurée, fût à 16 cannelures, chapiteau, mousse éventuelle
local function column(parent: Instance, pos: Vector3, height: number, radius: number, broken: number?)
	-- modèle Blender (colonne ionique / brisée) si le kit est importé
	local km = kit(if broken then "HColBroken" else "HColumn", parent, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		if broken then (height * broken) / 7.7 else height / 19)
	if km then
		return km
	end
	local m = Instance.new("Model")
	m.Name = if broken then "BrokenColumn" else "Column"
	local h = if broken then height * broken else height
	-- socle
	P(m, "Plinth", Vector3.new(radius * 2.8, 1.2, radius * 2.8), CFrame.new(pos + Vector3.new(0, 0.6, 0)), C.MarbleDark, Enum.Material.Limestone)
	cyl(m, "Torus1", radius * 2.5, 0.8, pos + Vector3.new(0, 1.6, 0), C.Marble, Enum.Material.Limestone)
	cyl(m, "Torus2", radius * 2.25, 0.5, pos + Vector3.new(0, 2.2, 0), C.MarbleWarm, Enum.Material.Limestone)
	-- fût (cylindre + cannelures)
	local shaftH = h - (if broken then 2.4 else 5.2)
	cyl(m, "Shaft", radius * 2, shaftH, pos + Vector3.new(0, 2.4 + shaftH / 2, 0), C.Marble, Enum.Material.Limestone)
	for k = 0, 15 do
		local a = math.rad(k * 22.5)
		local off = Vector3.new(math.cos(a) * radius * 0.97, 0, math.sin(a) * radius * 0.97)
		P(m, "Flute", Vector3.new(radius * 0.22, shaftH - 0.6, radius * 0.22), CFrame.lookAt(pos + off + Vector3.new(0, 2.4 + shaftH / 2, 0), pos + Vector3.new(0, 2.4 + shaftH / 2, 0)), C.MarbleWarm, Enum.Material.Limestone, { CastShadow = false })
	end
	if broken then
		-- cassure irrégulière + débris au pied
		for k = 1, 5 do
			local a = rng:NextNumber(0, math.pi * 2)
			P(m, "Shard", Vector3.new(radius * rng:NextNumber(0.6, 1.1), rng:NextNumber(0.6, 1.6), radius * rng:NextNumber(0.5, 0.9)),
				CFrame.new(pos + Vector3.new(math.cos(a) * radius * 0.4, 2.4 + shaftH + 0.3, math.sin(a) * radius * 0.4)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)),
				C.Marble, Enum.Material.Limestone)
		end
		for k = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = radius * rng:NextNumber(2, 4)
			P(m, "Debris", Vector3.new(radius * 1.6, radius * 1.4, radius * 1.4), CFrame.new(pos + Vector3.new(math.cos(a) * d, radius * 0.6, math.sin(a) * d)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, 0.2), C.MarbleWarm, Enum.Material.Limestone)
		end
		P(m, "Moss", Vector3.new(radius * 2.1, 0.3, radius * 2.1), CFrame.new(pos + Vector3.new(0, 2.4 + shaftH + 0.05, 0)) * CFrame.Angles(0.05, 0, -0.04), C.Moss, Enum.Material.Grass, { CastShadow = false })
	else
		-- chapiteau : astragale, échine, abaque, filet doré
		local top = pos + Vector3.new(0, 2.4 + shaftH, 0)
		cyl(m, "Astragal", radius * 2.2, 0.5, top + Vector3.new(0, 0.25, 0), C.MarbleWarm, Enum.Material.Limestone)
		cyl(m, "GoldBand", radius * 2.25, 0.25, top + Vector3.new(0, 0.62, 0), C.Gold, Enum.Material.Metal)
		cyl(m, "Echinus", radius * 2.7, 1.4, top + Vector3.new(0, 1.45, 0), C.Marble, Enum.Material.Limestone)
		P(m, "Abacus", Vector3.new(radius * 3, 1.2, radius * 3), CFrame.new(top + Vector3.new(0, 2.7, 0)), C.MarbleDark, Enum.Material.Limestone)
		-- volutes (enroulements) sur les 4 faces
		for k = 0, 3 do
			local a = math.rad(k * 90)
			local off = Vector3.new(math.cos(a) * radius * 1.35, 1.7, math.sin(a) * radius * 1.35)
			cyl(m, "Volute", radius * 0.9, 0.5, top + off, C.MarbleWarm, Enum.Material.Limestone)
		end
		-- mousse et lierre
		for k = 1, 3 do
			local y = rng:NextNumber(3, shaftH)
			local a = rng:NextNumber(0, math.pi * 2)
			P(m, "Ivy", Vector3.new(radius * 0.9, rng:NextNumber(1.5, 4), 0.3), CFrame.lookAt(pos + Vector3.new(math.cos(a) * radius * 1.02, y, math.sin(a) * radius * 1.02), pos + Vector3.new(0, y, 0)), C.Moss, Enum.Material.Grass, { CastShadow = false, CanCollide = false })
		end
	end
	m.Parent = parent
	return m
end

-- Pierres de muret en ruine, empilées et décalées, avec mousse
local function ruinWall(parent: Instance, a0: CFrame, length: number, height: number)
	local km = kit("HWall", parent, a0, math.max(0.6, length / 13.5))
	if km then
		return km
	end
	local m = Instance.new("Model")
	m.Name = "RuinWall"
	local x = -length / 2
	while x < length / 2 do
		local w = rng:NextNumber(3, 5.5)
		local rows = math.max(1, math.floor(height / 2.2 + rng:NextNumber(-0.8, 0.8)))
		for r = 0, rows - 1 do
			if rng:NextNumber() > 0.12 or r == 0 then
				local bh = rng:NextNumber(1.8, 2.5)
				local cf = a0 * CFrame.new(x + w / 2 + rng:NextNumber(-0.3, 0.3), bh / 2 + r * 2.2, rng:NextNumber(-0.35, 0.35)) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.05, 0.05))
				local tint = C.Stone:Lerp(C.StoneDark, rng:NextNumber(0, 0.6))
				P(m, "Block", Vector3.new(w - 0.25, bh, rng:NextNumber(2.4, 3.2)), cf, tint, Enum.Material.Limestone)
				if r == rows - 1 and rng:NextNumber() < 0.7 then
					P(m, "Moss", Vector3.new(w * rng:NextNumber(0.5, 0.95), 0.35, 2.6), cf * CFrame.new(0, bh / 2 + 0.1, 0), C.Moss:Lerp(C.MossLight, rng:NextNumber()), Enum.Material.Grass, { CastShadow = false, CanCollide = false })
				end
			end
		end
		x += w
	end
	m.Parent = parent
	return m
end

-- Vase / amphore
local function urn(parent: Instance, pos: Vector3, s: number)
	if kit("HUrn", parent, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), s) then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Urn"
	cyl(m, "Foot", 1.4 * s, 0.4 * s, pos + Vector3.new(0, 0.2 * s, 0), C.Clay, Enum.Material.Slate)
	ball(m, "Belly", 2.6 * s, pos + Vector3.new(0, 1.7 * s, 0), C.Clay, Enum.Material.Slate)
	cyl(m, "Shoulder", 2.0 * s, 0.6 * s, pos + Vector3.new(0, 2.7 * s, 0), C.Clay, Enum.Material.Slate)
	cyl(m, "Neck", 1.1 * s, 1.0 * s, pos + Vector3.new(0, 3.3 * s, 0), C.Clay, Enum.Material.Slate)
	cyl(m, "Lip", 1.6 * s, 0.3 * s, pos + Vector3.new(0, 3.85 * s, 0), C.Clay, Enum.Material.Slate)
	cyl(m, "Band", 2.62 * s, 0.25 * s, pos + Vector3.new(0, 1.9 * s, 0), C.Gold, Enum.Material.Metal, { CastShadow = false })
	m.Parent = parent
end

-- Arbre stylisé (tronc incliné, branches, houppier en grappes)
local function tree(parent: Instance, pos: Vector3, s: number)
	local km = kit(if rng:NextNumber() < 0.5 then "HTree" else "HTree2", parent, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), s)
	if km then
		return km
	end
	local m = Instance.new("Model")
	m.Name = "Tree"
	local lean = CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12))
	local base = CFrame.new(pos) * lean
	local h = 14 * s
	P(m, "Trunk", Vector3.new(h, 2.2 * s, 2.2 * s), base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Bark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	for k = 1, 4 do
		local a = math.rad(k * 90 + rng:NextNumber(-20, 20))
		local br = base * CFrame.new(0, h * rng:NextNumber(0.55, 0.85), 0) * CFrame.Angles(0, a, math.rad(rng:NextNumber(35, 55)))
		P(m, "Branch", Vector3.new(6 * s, 0.9 * s, 0.9 * s), br * CFrame.new(3 * s, 0, 0), C.Bark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
		local tip = (br * CFrame.new(6 * s, 0, 0)).Position
		for j = 1, 3 do
			ball(m, "Leaves", rng:NextNumber(5, 7.5) * s, tip + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(0, 2.5), rng:NextNumber(-2, 2)) * s, C.Leaf:Lerp(C.LeafLight, rng:NextNumber()), Enum.Material.LeafyGrass, { CastShadow = true, CanCollide = false })
		end
	end
	local top = (base * CFrame.new(0, h, 0)).Position
	for j = 1, 4 do
		ball(m, "Crown", rng:NextNumber(7, 10) * s, top + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0, 3), rng:NextNumber(-3, 3)) * s, C.Leaf:Lerp(C.LeafLight, rng:NextNumber()), Enum.Material.LeafyGrass, { CanCollide = false })
	end
	m.Parent = parent
	return m
end

-- Bannière : mât, traverse dorée, étoffe bleu nuit et emblème « lames croisées d'éther »
local function banner(parent: Instance, pos: Vector3, facing: Vector3, h: number)
	local km = kit("HBanner", parent, CFrame.lookAt(pos, pos + facing), h / 18)
	if km then
		return km
	end
	local m = Instance.new("Model")
	m.Name = "Banner"
	local cf = CFrame.lookAt(pos, pos + facing)
	cyl(m, "Pole", 0.5, h, pos + Vector3.new(0, h / 2, 0), C.Bark, Enum.Material.Wood)
	P(m, "Tip", Vector3.new(0.6, 1.4, 0.6), CFrame.new(pos + Vector3.new(0, h + 0.7, 0)) * CFrame.Angles(0, math.rad(45), 0), C.Gold, Enum.Material.Metal)
	P(m, "Bar", Vector3.new(5.4, 0.3, 0.3), cf * CFrame.new(0, h - 0.8, -0.4), C.Gold, Enum.Material.Metal)
	local cloth = P(m, "Cloth", Vector3.new(5, 8, 0.15), cf * CFrame.new(0, h - 4.9, -0.45), C.Banner, Enum.Material.Fabric, { CanCollide = false })
	-- pointes basses
	for k = -1, 1, 2 do
		P(m, "Tail", Vector3.new(2.5, 1.6, 0.15), cf * CFrame.new(k * 1.25, h - 9.5, -0.45) * CFrame.Angles(0, 0, math.rad(k * 18)), C.Banner, Enum.Material.Fabric, { CanCollide = false })
	end
	-- liseré doré
	P(m, "Trim", Vector3.new(5.05, 0.2, 0.18), cf * CFrame.new(0, h - 1.0, -0.47), C.Gold, Enum.Material.Metal, { CanCollide = false })
	-- emblème : deux lames croisées (néon d'éther) + cristal
	for k = -1, 1, 2 do
		P(m, "EmblemBlade", Vector3.new(0.28, 5, 0.1), cf * CFrame.new(0, h - 4.8, -0.55) * CFrame.Angles(0, 0, math.rad(k * 35)), C.Ether, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
		P(m, "EmblemHilt", Vector3.new(0.5, 1, 0.12), cf * CFrame.new(0, h - 4.8, -0.56) * CFrame.Angles(0, 0, math.rad(k * 35)) * CFrame.new(0, -2.4, 0), C.Gold, Enum.Material.Metal, { CanCollide = false })
	end
	P(m, "EmblemGem", Vector3.new(0.9, 0.9, 0.12), cf * CFrame.new(0, h - 2.6, -0.57) * CFrame.Angles(0, 0, math.rad(45)), C.Gold, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
	m.Parent = parent
	return cloth
end

-- Cristal d'éther (grappe de prismes lumineux)
local function crystalCluster(parent: Instance, pos: Vector3, s: number, color: Color3?)
	local m = Instance.new("Model")
	m.Name = "EtherCrystals"
	local col = color or C.Ether
	for k = 1, 5 do
		local h = rng:NextNumber(2, 5) * s
		local w = rng:NextNumber(0.6, 1.1) * s
		local cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.45, 0.45), rng:NextNumber(0, 6.28), rng:NextNumber(-0.45, 0.45)) * CFrame.new(0, h / 2, 0)
		local p = P(m, "Prism", Vector3.new(w, h, w), cf * CFrame.Angles(0, math.rad(45), 0), col, Enum.Material.Glass, { Transparency = 0.15, CanCollide = false, CastShadow = false })
		P(m, "Glow", Vector3.new(w * 0.5, h * 0.9, w * 0.5), cf * CFrame.Angles(0, math.rad(45), 0), col, Enum.Material.Neon, { CanCollide = false, CastShadow = false, Transparency = 0.2 })
		if k == 1 then
			light(p, col, 12 * s, 1)
		end
	end
	m.Parent = parent
end

--------------------------------------------------------------------------------
-- 3. Terrasse nord : grand escalier, 3 colonnes géantes, panneaux de classement, bannières

function B.terrace()
	local f = folder(root, "Terrace")
	-- escalier (largeur 44, 8 marches de 1 stud, giron 3)
	for i = 0, 7 do
		local z = -(PLAZA_R + 2) - i * 3
		P(f, "Step", Vector3.new(44, 1 + i * 1, 3.2), CFrame.new(0, (1 + i) / 2 - 0.2, z), if i % 2 == 0 then C.Marble else C.MarbleWarm, Enum.Material.Limestone)
		P(f, "StepNose", Vector3.new(44, 0.15, 0.3), CFrame.new(0, i + 0.73, z + 1.5), C.MarbleDark, Enum.Material.Limestone, { CastShadow = false })
	end
	-- limons latéraux + vasques
	for _, sx in { -1, 1 } do
		P(f, "Stringer", Vector3.new(4, 10, 26), CFrame.new(sx * 24, 3.8, -(PLAZA_R + 12)) * CFrame.Angles(math.rad(17), 0, 0), C.Stone, Enum.Material.Limestone)
		urn(f, Vector3.new(sx * 24, 9.5, -(PLAZA_R + 24)), 1.3)
	end
	-- plateau de la terrasse
	local ty = 8.2
	P(f, "TerraceFloor", Vector3.new(80, 1, 44), CFrame.new(0, ty - 0.5, -(PLAZA_R + 48)), C.MarbleWarm, Enum.Material.Limestone)
	-- mosaïque circulaire au centre de la terrasse
	cyl(f, "Mosaic", 26, 0.1, Vector3.new(0, ty + 0.05, -(PLAZA_R + 44)), C.Marble, Enum.Material.Limestone, { CastShadow = false })
	around(40, 12.4, ty + 0.12, function(a, cf)
		P(f, "MosaicVein", Vector3.new(2, 0.05, 0.18), cf + Vector3.new(0, 0, -(PLAZA_R + 44)), C.Ether, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
	end)
	-- 3 colonnes géantes (fond)
	for _, x in { -18, 0, 18 } do
		column(f, Vector3.new(x, ty, -(PLAZA_R + 64)), 46, 2.6)
	end
	-- architrave reliant les colonnes
	P(f, "Architrave", Vector3.new(46, 3, 7), CFrame.new(0, ty + 47.6, -(PLAZA_R + 64)), C.Marble, Enum.Material.Limestone)
	P(f, "Frieze", Vector3.new(46.2, 0.6, 7.2), CFrame.new(0, ty + 46, -(PLAZA_R + 64)), C.Gold, Enum.Material.Metal)
	-- panneaux de classement (entre les colonnes, face au sud)
	local function board(name: string, x: number, z: number, yaw: number)
		local m = Instance.new("Model")
		m.Name = name .. "_Frame"
		local cf = CFrame.new(x, ty + 9, z) * CFrame.Angles(0, yaw, 0)
		P(m, "Back", Vector3.new(12, 16, 0.8), cf * CFrame.new(0, 0, 0.6), C.Navy, Enum.Material.Slate)
		for _, sx in { -1, 1 } do
			P(m, "Post", Vector3.new(0.9, 18.5, 0.9), cf * CFrame.new(sx * 6.3, -0.8, 0.4), C.Gold, Enum.Material.Metal)
		end
		P(m, "Crown", Vector3.new(13.5, 1, 1.2), cf * CFrame.new(0, 8.6, 0.4), C.Gold, Enum.Material.Metal)
		P(m, "Foot", Vector3.new(13, 1.2, 2.6), cf * CFrame.new(0, -9.6, 0.4), C.MarbleDark, Enum.Material.Limestone)
		local gem = P(m, "Gem", Vector3.new(1.2, 1.2, 0.4), cf * CFrame.new(0, 9.3, 0.1) * CFrame.Angles(0, 0, math.rad(45)), C.Ether, Enum.Material.Neon, { CastShadow = false })
		light(gem, C.Ether, 10, 1)
		local panel = P(m, name, Vector3.new(11, 15, 0.2), cf, Color3.fromRGB(14, 18, 40), Enum.Material.Glass, { Transparency = 0.05 })
		panel:SetAttribute("Face", "Front")
		local sl = light(panel, C.Ether, 14, 0.6, "SurfaceLight")
		;(sl :: any).Face = Enum.NormalId.Front
		m.Parent = f
	end
	-- face Front (-Z local) doit regarder vers le sud (+Z monde) : yaw = 180°
	board("Leaderboard_Elo", -9, -(PLAZA_R + 60), math.rad(180))
	board("Leaderboard_Wins", 9, -(PLAZA_R + 60), math.rad(180))
	board("Leaderboard_Streak", 32, -(PLAZA_R + 50), math.rad(180 + 35))
	-- bannières (de part et d'autre)
	for _, x in { -30, -26, 26, 30 } do
		banner(f, Vector3.new(x, ty, -(PLAZA_R + 56) + (if math.abs(x) == 30 then 8 else 0)), Vector3.new(0, 0, 1), 18)
	end
	-- jardin de méditation (côté ouest de la terrasse)
	for i = 1, 4 do
		local pos = Vector3.new(-28 + (i - 1) % 2 * 8, ty, -(PLAZA_R + 38) - math.floor((i - 1) / 2) * 8)
		cyl(f, "Cushion", 4, 0.6, pos + Vector3.new(0, 0.3, 0), C.Banner, Enum.Material.Fabric)
		cyl(f, "CushionRing", 4.3, 0.2, pos + Vector3.new(0, 0.1, 0), C.Gold, Enum.Material.Metal, { CastShadow = false })
		marker(f, "MeditationSpot_" .. i, CFrame.new(pos + Vector3.new(0, 1.2, 0)))
	end
	crystalCluster(f, Vector3.new(-34, ty, -(PLAZA_R + 46)), 1.2)
	-- autel des relances (côté est de la terrasse) : kit Altar + orbe
	local altarPos = Vector3.new(28, ty, -(PLAZA_R + 38))
	if not kit("Altar", f, CFrame.new(altarPos)) then
		cyl(f, "AltarBase", 10, 3, altarPos + Vector3.new(0, 1.5, 0), C.Marble, Enum.Material.Limestone)
	end
	local orb = ball(f, "RerollShrine", 3, altarPos + Vector3.new(0, 7.2, 0), C.Violet, Enum.Material.Neon, { CanCollide = false })
	light(orb, C.Violet, 20, 2)
	crystalCluster(f, altarPos + Vector3.new(6, 0, 4), 1, C.Violet)
	crystalCluster(f, altarPos + Vector3.new(-6, 0, 4), 0.8, C.Violet)
end

--------------------------------------------------------------------------------
-- 4. Arènes d'entraînement circulaires (pods de file) avec rambarde dorée à arceaux

local function duelRing(parent: Instance, name: string, center: Vector3, color: Color3, label: string)
	local m = Instance.new("Model")
	m.Name = name .. "_Ring"
	local R = 20
	-- sol de l'arène légèrement surélevé + motif
	cyl(m, "RingFloor", R * 2, 6, center + Vector3.new(0, -2.2, 0), C.Marble, Enum.Material.Limestone)
	cyl(m, "RingInlay", R * 2 - 4, 0.06, center + Vector3.new(0, 0.82, 0), C.MarbleWarm, Enum.Material.Limestone, { CastShadow = false })
	around(64, R - 2.2, 0.86, function(a, cf)
		P(m, "Glow", Vector3.new(2 * math.pi * (R - 2.2) / 64 + 0.05, 0.05, 0.3), cf + center, color, Enum.Material.Neon, { CanCollide = false, CastShadow = false, Transparency = 0.1 })
	end)
	-- rambarde dorée à arceaux (entrée laissée ouverte face au centre de la place)
	local toCenter = math.atan2(-center.Z, -center.X)
	if KIT and KIT:FindFirstChild("HRail") then
		-- segments Blender (rayon 20,4, 1/14 de tour) : +Z local vers le centre de l'arène
		for i = 0, 13 do
			local a = (i + 0.5) / 14 * math.pi * 2
			local d = math.abs(((a - toCenter + math.pi) % (2 * math.pi)) - math.pi)
			if d > 0.3 then
				local pos = center + Vector3.new(math.cos(a) * (R + 0.15), 0.8, math.sin(a) * (R + 0.15))
				kit("HRail", m, CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)) * CFrame.Angles(0, math.pi, 0))
			end
		end
	end
	around(if KIT and KIT:FindFirstChild("HRail") then 0 else 28, R + 0.4, 0.8, function(a, cf)
		local d = math.abs(((a - toCenter + math.pi) % (2 * math.pi)) - math.pi)
		if d < 0.42 then
			return
		end
		local pos = cf.Position + center
		local look = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		local seg = 2 * math.pi * (R + 0.4) / 28
		P(m, "RailBase", Vector3.new(seg + 0.1, 0.6, 1.1), look * CFrame.new(0, 0.3, 0), C.MarbleDark, Enum.Material.Limestone)
		P(m, "Post", Vector3.new(0.35, 3.2, 0.35), look * CFrame.new(-seg / 2, 2.2, 0), C.Gold, Enum.Material.Metal, { Reflectance = 0.15 })
		P(m, "TopRail", Vector3.new(seg + 0.1, 0.3, 0.35), look * CFrame.new(0, 3.75, 0), C.Gold, Enum.Material.Metal, { Reflectance = 0.15 })
		-- arceau (demi-anneau dans le plan de la rambarde)
		for k = 1, 5 do
			local t = k / 6
			local ang = math.pi * t
			local x = -seg / 2 + seg * t
			local y = 0.7 + math.sin(ang) * 2.3
			P(m, "Arc", Vector3.new(seg / 5.2, 0.22, 0.22), look * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.cos(ang) * 0.9), C.Gold, Enum.Material.Metal, { CastShadow = false })
		end
	end)
	-- 2 plots face à face (comme un duel) + pod central (prompt)
	for k, sx in { -1, 1 } do
		local pad = cyl(m, "Pad" .. k, 5, 0.4, center + Vector3.new(sx * 7, 1.0, 0), color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.25 })
		cyl(m, "PadRim", 5.6, 0.3, center + Vector3.new(sx * 7, 0.9, 0), C.Gold, Enum.Material.Metal, { CastShadow = false })
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(color)
		pe.LightEmission = 1
		pe.Rate = 6
		pe.Lifetime = NumberRange.new(1.2, 2)
		pe.Speed = NumberRange.new(1, 2.5)
		pe.SpreadAngle = Vector2.new(10, 10)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
		pe.EmissionDirection = Enum.NormalId.Right
		pe.Parent = pad
		light(pad, color, 10, 1.2)
	end
	local pod = cyl(m, name, 6, 0.3, center + Vector3.new(0, 1.0, 0), color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.6 })
	-- totem d'enseigne
	local sign = P(m, "SignPost", Vector3.new(1, 9, 1), CFrame.new(center + Vector3.new(0, 4.5, -R + 1.5)), C.Gold, Enum.Material.Metal)
	local board = P(m, "SignBoard", Vector3.new(9, 2.4, 0.4), CFrame.new(center + Vector3.new(0, 9, -R + 1.5)), C.Navy, Enum.Material.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = label
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBlack
	tl.TextColor3 = color
	tl.Parent = gui
	gui.Parent = board
	local gui2 = gui:Clone()
	gui2.Face = Enum.NormalId.Front
	gui2.Parent = board
	light(board, color, 12, 1)
	m.Parent = parent
	return pod
end

function B.rings()
	local f = folder(root, "DuelRings")
	-- les arènes débordent de la place, sur des avancées herbeuses
	duelRing(f, "Pod_Casual", Vector3.new(-PLAZA_R - 14, 0, 6), C.Casual, "DUEL LIBRE")
	duelRing(f, "Pod_Ranked", Vector3.new(PLAZA_R + 14, 0, 6), C.Ranked, "DUEL CLASSÉ")
	duelRing(f, "Pod_Challenge", Vector3.new(0, 0, PLAZA_R + 16), C.Challenge, "DÉFI DIRECT")
	local t = Workspace.Terrain
	for _, c in { Vector3.new(-PLAZA_R - 14, 0, 6), Vector3.new(PLAZA_R + 14, 0, 6), Vector3.new(0, 0, PLAZA_R + 16) } do
		t:FillCylinder(CFrame.new(c + Vector3.new(0, -7.5, 0)), 6, 25, Enum.Material.Rock)
		
		t:FillBall(c + Vector3.new(0, -24, 0), 18, Enum.Material.Rock)
	end
end

--------------------------------------------------------------------------------
-- 5. Ruines : murets, colonnes brisées, aire d'entraînement, établi

function B.ruins()
	local f = folder(root, "Ruins")
	-- murets en arc autour de la place (en laissant les accès : nord, est, ouest, sud)
	local gaps = { 0, math.pi / 2, math.pi, math.pi * 1.5 }
	for i = 0, 15 do
		local a = (i + 0.5) / 16 * math.pi * 2
		local ok = true
		for _, g in gaps do
			local d = math.abs(((a - g + math.pi) % (2 * math.pi)) - math.pi)
			if d < 0.36 then
				ok = false
			end
		end
		if ok then
			local r = PLAZA_R + 6
			local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			ruinWall(f, CFrame.lookAt(pos, Vector3.new(0, 0, 0)), rng:NextNumber(10, 16), rng:NextNumber(2, 6))
		end
	end
	-- colonnes (intactes et brisées) en couronne extérieure
	for i = 0, 11 do
		local a = (i + 0.25) / 12 * math.pi * 2
		local r = PLAZA_R + 16 + rng:NextNumber(-2, 4)
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if B.nearRing(pos, 6) then
			continue -- dégage les arènes
		end
		if pos.Z < -PLAZA_R then
			continue -- dégage l'escalier
		end
		if i % 3 == 0 then
			column(f, pos, 28, 1.6)
		else
			column(f, pos, 28, 1.6, rng:NextNumber(0.25, 0.6))
		end
	end
	-- aire d'entraînement (sud-ouest de la place) : 3 socles de mannequins
	for i = 1, 3 do
		local a = math.rad(118 + (i - 2) * 16)
		local pos = Vector3.new(math.cos(a) * 44, 0, math.sin(a) * 44)
		cyl(f, "DummyBase", 5, 0.5, pos + Vector3.new(0, 0.25, 0), C.StoneDark, Enum.Material.Slate)
		cyl(f, "DummyRing", 5.4, 0.15, pos + Vector3.new(0, 0.1, 0), C.Ether, Enum.Material.Neon, { CanCollide = false, CastShadow = false })
		marker(f, "Dummy_" .. i, CFrame.lookAt(pos + Vector3.new(0, 3.65, 0), Vector3.new(0, 3.65, 0)), Vector3.new(2, 2, 1))
	end
	-- établi de lame (sud-est) : kit Bench sous un auvent
	local bp = Vector3.new(math.cos(math.rad(62)) * 46, 0, math.sin(math.rad(62)) * 46)
	local benchCf = CFrame.lookAt(bp, Vector3.new(0, 0, 0))
	if not kit("Bench", f, benchCf) then
		P(f, "BenchTable", Vector3.new(6, 3, 3), benchCf * CFrame.new(0, 1.5, 0), C.Bark, Enum.Material.Wood)
	end
	for _, sx in { -1, 1 } do
		P(f, "AwningPost", Vector3.new(0.6, 9, 0.6), benchCf * CFrame.new(sx * 4.5, 4.5, 2.5), C.Gold, Enum.Material.Metal)
	end
	P(f, "Awning", Vector3.new(11, 0.4, 6.5), benchCf * CFrame.new(0, 9.1, 0.8) * CFrame.Angles(math.rad(-12), 0, 0), C.Banner, Enum.Material.Fabric)
	local bench = P(f, "SaberBench", Vector3.new(5, 1, 3), benchCf * CFrame.new(0, 3.4, 0), C.Ether, Enum.Material.Neon, { Transparency = 0.85, CanCollide = false, CastShadow = false })
	light(bench, C.Ether, 12, 1.2)
	-- braseros d'éther en couronne sur la bordure de la place
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * (PLAZA_R - 3), 0, math.sin(a) * (PLAZA_R - 3))
		local kb = kit("HBrazier", f, CFrame.new(pos))
		if kb then
			local flame = kb:FindFirstChild("Flame")
			if flame and flame:IsA("BasePart") then
				flame.CanCollide = false
				local fire = Instance.new("Fire")
				fire.Color = C.Ether
				fire.SecondaryColor = C.EtherDeep
				fire.Size = 4
				fire.Heat = 7
				fire.Parent = flame
				light(flame, C.Ether, 16, 1.4)
			end
			continue
		end
		local m = Instance.new("Model")
		m.Name = "Brazier"
		cyl(m, "Base", 3.2, 0.6, pos + Vector3.new(0, 0.3, 0), C.MarbleDark, Enum.Material.Limestone)
		cyl(m, "Stem", 1.1, 3.2, pos + Vector3.new(0, 2.2, 0), C.Gold, Enum.Material.Metal)
		cyl(m, "Bowl", 3.4, 0.9, pos + Vector3.new(0, 4.1, 0), C.Gold, Enum.Material.Metal)
		cyl(m, "BowlRim", 3.8, 0.25, pos + Vector3.new(0, 4.6, 0), C.GoldDark, Enum.Material.Metal)
		local flame = cyl(m, "Ether", 2.6, 0.3, pos + Vector3.new(0, 4.75, 0), C.Ether, Enum.Material.Neon, { CanCollide = false })
		local fire = Instance.new("Fire")
		fire.Color = C.Ether
		fire.SecondaryColor = C.EtherDeep
		fire.Size = 4
		fire.Heat = 7
		fire.Parent = flame
		light(flame, C.Ether, 16, 1.4)
		m.Parent = f
	end
	-- vases, petits cristaux et touffes de pierre dispersés
	for i = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(PLAZA_R + 3, PLAZA_R + 9)
		urn(f, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(0.9, 1.4))
	end
end

--------------------------------------------------------------------------------
-- 6. Ciel : îles flottantes boisées, rochers suspendus, cristaux d'éther

function B.sky()
	local f = folder(root, "SkyIslands")
	local t = Workspace.Terrain
	local spots = {
		{ Vector3.new(-150, 46, -70), 16 },
		{ Vector3.new(150, 58, -110), 20 },
		{ Vector3.new(-120, 72, 140), 14 },
		{ Vector3.new(170, 36, 80), 12 },
		{ Vector3.new(-190, 26, 40), 11 },
		{ Vector3.new(40, 96, -230), 22 },
		{ Vector3.new(-60, 52, 200), 10 },
		{ Vector3.new(90, 70, 190), 13 },
	}
	for i, s in spots do
		local c, r = s[1], s[2]
		if KIT and KIT:FindFirstChild("HIsland") then
			-- île Blender : pivot au fond, dessus herbeux à topH × échelle au-dessus du pivot
			local name = if i % 2 == 0 then "HIsland2" else "HIsland"
			local base = if name == "HIsland2" then 7 else 10
			local topH = if name == "HIsland2" then 15.9 else 21.1
			local sc = r / base
			kit(name, f, CFrame.new(c - Vector3.new(0, topH * sc, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), sc)
			local top = c
			tree(f, top + Vector3.new(rng:NextNumber(-r * 0.3, r * 0.3), 0, rng:NextNumber(-r * 0.3, r * 0.3)), r / 18)
			if i % 2 == 0 then
				column(f, top + Vector3.new(r * 0.4, 0, -r * 0.2), 16, 1.2, 0.5)
			end
			crystalCluster(f, top + Vector3.new(-r * 0.4, 0, r * 0.25), r / 18)
			continue
		end
		-- dessus plat herbeux, dessous effilé
		t:FillCylinder(CFrame.new(c), 4, r, Enum.Material.Rock)
		t:FillCylinder(CFrame.new(c + Vector3.new(0, 2.2, 0)), 1.2, r - 1, Enum.Material.LeafyGrass)
		for k = 1, 4 do
			local rad = r * (0.8 - k * 0.16)
			t:FillBall(c + Vector3.new(rng:NextNumber(-r * 0.2, r * 0.2), -2 - rad - (k - 1) * r * 0.22, rng:NextNumber(-r * 0.2, r * 0.2)), rad, if k > 2 then Enum.Material.Slate else Enum.Material.Rock)
		end
		local top = c + Vector3.new(0, 2.8, 0)
		tree(f, top + Vector3.new(rng:NextNumber(-r * 0.3, r * 0.3), 0, rng:NextNumber(-r * 0.3, r * 0.3)), r / 22)
		if i % 2 == 0 then
			column(f, top + Vector3.new(r * 0.4, 0, -r * 0.2), 16, 1.2, 0.5)
		end
		crystalCluster(f, top + Vector3.new(-r * 0.4, 0, r * 0.25), r / 18)
		-- cristaux pendant sous l'île
		local hang = P(f, "HangingCrystal", Vector3.new(2, r * 0.6, 2), CFrame.new(c + Vector3.new(0, -r * 1.55, 0)) * CFrame.Angles(0, math.rad(45), 0), C.Ether, Enum.Material.Neon, { CanCollide = false, CastShadow = false, Transparency = 0.1 })
		light(hang, C.Ether, 24, 1.4)
	end
	-- arbres sur l'île principale (hors place)
	for _, p in { Vector3.new(-82, 0, -40), Vector3.new(84, 0, -46), Vector3.new(-70, 0, 64), Vector3.new(74, 0, 70), Vector3.new(-40, 8.2, -128), Vector3.new(44, 8.2, -126) } do
		tree(f, p, 1.1)
	end
end

--------------------------------------------------------------------------------
-- 7. Ambiance : ciel d'éther au crépuscule doré, brume, particules

function B.light()
	local keep = root:FindFirstChild("HubLighting") or Instance.new("Folder")
	keep.Name = "HubLighting"
	keep:ClearAllChildren()
	keep.Parent = root
	local cfg = {
		ClockTime = 16.4,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(96, 92, 120),
		OutdoorAmbient = Color3.fromRGB(150, 140, 170),
		FogColor = Color3.fromRGB(196, 206, 240),
		FogEnd = 1800,
		ExposureCompensation = 0.15,
		GeographicLatitude = 30,
	}
	for k, v in cfg do
		keep:SetAttribute(k, v)
		;(Lighting :: any)[k] = v
	end
	for _, c in Lighting:GetChildren() do
		if c:IsA("Atmosphere") or c:IsA("Sky") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(205, 214, 245)
	atm.Decay = Color3.fromRGB(120, 110, 190)
	atm.Glare = 0.4
	atm.Haze = 1.6
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.StarCount = 1500
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.08
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(255, 248, 240)
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 30
	bloom.Threshold = 1.6
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	for _, e in { atm, sky, cc, bloom, rays } do
		e.Parent = Lighting
		e:Clone().Parent = keep
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.5
	clouds.Color = Color3.fromRGB(240, 238, 255)
	clouds.Parent = Workspace.Terrain
	-- particules d'éther et feuilles flottant au-dessus de la place
	local emitterPart = P(root, "AmbientMotes", Vector3.new(160, 1, 160), CFrame.new(0, 34, -10), C.Ether, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(C.Ether, Color3.fromRGB(255, 230, 160))
	motes.LightEmission = 1
	motes.Rate = 18
	motes.Lifetime = NumberRange.new(8, 12)
	motes.Speed = NumberRange.new(0.5, 1.5)
	motes.SpreadAngle = Vector2.new(30, 30)
	motes.Acceleration = Vector3.new(0.4, -0.25, 0.2)
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 0) })
	motes.EmissionDirection = Enum.NormalId.Bottom
	motes.Parent = emitterPart
end

--------------------------------------------------------------------------------

function B.run(section: string)
	root = Workspace:FindFirstChild("Hub") :: Model
	if section == "reset" or not root then
		local old = Workspace:FindFirstChild("Hub")
		if old then
			old:Destroy()
		end
		Workspace.Terrain:Clear()
		root = Instance.new("Model")
		root.Name = "Hub"
		root.Parent = Workspace
		return "hub vide créé"
	end
	local fn = (B :: any)[section]
	assert(type(fn) == "function", "section inconnue : " .. section)
	fn()
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("%s OK (%d pièces au total)", section, n)
end

return B
