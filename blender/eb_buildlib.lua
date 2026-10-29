-- Bibliotheque de construction (outil d'edition, utilisee depuis la barre de commande / MCP Studio).
-- Placee temporairement dans ServerStorage.EB_BuildLib pendant la construction, puis supprimee.
local L = {}
local SS = game:GetService("ServerStorage")
L.Kit = SS.EtherBladesAssets.Kit

function L.hex(h: string): Color3
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end
function L.col(c) if typeof(c) == "string" then return L.hex(c) end return c or Color3.new(1, 1, 1) end

-- Part ancree generique. opts : Shape, Transparency, Reflectance, CanCollide, CastShadow, Name
function L.part(parent, name, size, cf, color, mat, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = typeof(color) == "string" and L.hex(color) or color or Color3.new(1, 1, 1)
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanTouch = false
	if opts then
		for k, v in pairs(opts) do
			p[k] = v
		end
	end
	if p.Material == Enum.Material.Neon then
		p.CastShadow = false
	end
	if opts == nil or opts.CastShadow == nil then
		if size.X * size.Y * size.Z < 8 then
			p.CastShadow = false
		end
	end
	p.Parent = parent
	return p
end

-- cylindre vertical (axe Y) : d = diametre, h = hauteur
function L.cyl(parent, name, d, h, cf, color, mat, opts)
	opts = opts or {}
	opts.Shape = Enum.PartType.Cylinder
	return L.part(parent, name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, opts)
end

function L.ball(parent, name, d, cf, color, mat, opts)
	opts = opts or {}
	opts.Shape = Enum.PartType.Ball
	return L.part(parent, name, Vector3.new(d, d, d), cf, color, mat, opts)
end

function L.wedge(parent, name, size, cf, color, mat, opts)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = typeof(color) == "string" and L.hex(color) or color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanTouch = false
	if opts then
		for k, v in pairs(opts) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- point de repere invisible, non collidable
function L.marker(parent, name, cf, size)
	return L.part(parent, name, size or Vector3.new(1, 1, 1), cf, Color3.new(1, 0, 1), Enum.Material.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
end

-- clone d'un element du kit Blender (collisions du kit conservees). opts : scale, collide=false, accent, tint, material, noshadow, name (recolore les pieces Accent), glow (couleur des neons)
function L.kit(parent, kitName, cf, opts)
	opts = opts or {}
	local m = L.Kit:FindFirstChild(kitName)
	assert(m, "kit manquant " .. kitName)
	local c = m:Clone()
	c:SetAttribute("Size", nil)
	if opts.scale and opts.scale ~= 1 then
		c:ScaleTo(opts.scale)
	end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			if opts.collide == false then
				p.CanCollide = false
				p.CanQuery = false
			end
			if opts.accent and p:GetAttribute("Accent") then
				p.Color = typeof(opts.accent) == "string" and L.hex(opts.accent) or opts.accent
			end
			if opts.tint and p.Material ~= Enum.Material.Neon then
				p.Color = typeof(opts.tint) == "string" and L.hex(opts.tint) or opts.tint
			end
			if opts.material and p.Material ~= Enum.Material.Neon and p.Material ~= Enum.Material.Metal then
				p.Material = opts.material
			end
			if opts.noshadow then
				p.CastShadow = false
			end
		end
	end
	c:PivotTo(cf)
	if opts.name then
		c.Name = opts.name
	end
	c.Parent = parent
	return c
end

function L.light(part, kind, color, brightness, range, extra)
	local l = Instance.new(kind)
	l.Color = typeof(color) == "string" and L.hex(color) or color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	if extra then
		for k, v in pairs(extra) do
			l[k] = v
		end
	end
	l.Parent = part
	return l
end

function L.folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function L.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- emetteur de particules a partir de textures integrees
function L.particles(part, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = part
	return e
end

function L.seq(a, b)
	return NumberSequence.new(a, b)
end

function L.cseq(c)
	return ColorSequence.new(typeof(c) == "string" and L.hex(c) or c)
end

-- texte SurfaceGui sur la face d'une part
function L.label(part, face, text, color, font)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Brightness = 2
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.GothamBold
	t.TextColor3 = typeof(color) == "string" and L.hex(color) or color
	t.Parent = g
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.new(0, 0, 0)
	s.Transparency = 0.4
	s.Parent = t
	g.Parent = part
	return g
end

-- Anneau de N parts formant un cercle (pour bordures). cb(i, cf) renvoie rien.
function L.ring(n, radius, center, cb)
	for i = 0, n - 1 do
		local a = 2 * math.pi * i / n
		local cf = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		cb(i, cf, a)
	end
end

return L
