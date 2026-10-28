--!strict
--[[
	SnakeBuilder — construit un serpent enroulé en Parts à partir d'un Look (SnakesConfig).

	Silhouette : spirale de 18 anneaux qui monte vers le centre + cou dressé + tête typée.
	Variations : 7 motifs × 9 têtes × 20 accessoires × 8 matières → chaque espèce est lisible au premier coup d'œil.
	Le modèle est construit une seule fois par espèce (cache) puis cloné.
	PrimaryPart = tête (prompts / étiquettes) ; le pivot est recentré sur la boîte englobante
	pour que PivotTo pose le serpent au sol comme les modèles importés.
]]
local SnakeBuilder = {}

type Look = {
	Body: Color3,
	Accent: Color3,
	Belly: Color3,
	Pattern: string,
	Head: string,
	Extras: { string },
	Material: string,
	Size: number,
}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local BONE = Color3.fromRGB(240, 232, 214)
local GOLD = Color3.fromRGB(255, 205, 60)

local MATERIALS: { [string]: Enum.Material } = {
	Smooth = Enum.Material.SmoothPlastic,
	Neon = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.Glass,
	Foil = Enum.Material.Foil,
	Ice = Enum.Material.Ice,
	Slate = Enum.Material.Slate,
	Marble = Enum.Material.Marble,
	Velvet = Enum.Material.Fabric,
}

local function newPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function wedge(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.Parent = model
	return w
end

local function emitter(parent: Instance, props: { [string]: any })
	local att = Instance.new("Attachment")
	att.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.LightEmission = 0.8
	for k, v in props do
		(pe :: any)[k] = v
	end
	pe.Parent = att
end

local function has(look: Look, extra: string): boolean
	return table.find(look.Extras, extra) ~= nil
end

-- Point de la spirale (u ∈ [0,1], 0 = bout de la queue à l'extérieur, 1 = base du cou au centre)
local SEGMENTS = 18
local function coilPoint(u: number): Vector3
	local angle = u * math.pi * 2 * 2.1
	local radius = 1.55 - u * 1.0
	return Vector3.new(math.cos(angle) * radius, 0.42 + u * 0.55, math.sin(angle) * radius)
end

local function buildHead(model: Model, look: Look, base: CFrame, bodyMat: Enum.Material, scale: number): Part
	local kind = look.Head
	local headColor = if kind == "Skull" then BONE else look.Body
	local head: Part
	if kind == "Viper" or kind == "Horned" then
		head = newPart(model, "Head", Enum.PartType.Block, Vector3.new(0.95, 0.5, 1.05) * scale, base, headColor, bodyMat)
		wedge(model, "Snout", Vector3.new(0.95, 0.5, 0.55) * scale, base * CFrame.new(0, 0, -0.8 * scale) * CFrame.Angles(0, math.pi, 0), headColor, bodyMat)
	else
		head = newPart(model, "Head", Enum.PartType.Ball, Vector3.new(0.95, 0.78, 1.1) * scale, base, headColor, bodyMat)
		newPart(model, "Snout", Enum.PartType.Ball, Vector3.new(0.7, 0.5, 0.7) * scale, base * CFrame.new(0, -0.08 * scale, -0.45 * scale), headColor, bodyMat)
	end
	-- Yeux
	local glowing = look.Pattern == "Glow" or look.Material == "Neon"
	local eyeColor = if kind == "Skull" then Color3.fromRGB(20, 20, 20) elseif glowing then look.Accent else Color3.fromRGB(255, 215, 60)
	for _, x in { -1, 1 } do
		local eye = newPart(model, "Eye", Enum.PartType.Ball, Vector3.new(0.24, 0.24, 0.24) * scale, base * CFrame.new(x * 0.36 * scale, 0.16 * scale, -0.32 * scale), eyeColor, if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		if not glowing and kind ~= "Skull" then
			newPart(model, "Pupil", Enum.PartType.Block, Vector3.new(0.05, 0.18, 0.05) * scale, eye.CFrame * CFrame.new(x * 0.1 * scale, 0, -0.06 * scale), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		end
	end
	-- Langue fourchue
	newPart(model, "Tongue", Enum.PartType.Block, Vector3.new(0.08, 0.04, 0.5) * scale, base * CFrame.new(0, -0.18 * scale, -0.95 * scale), Color3.fromRGB(230, 40, 70), Enum.Material.SmoothPlastic)

	if kind == "Cobra" then
		local hood = newPart(model, "Hood", Enum.PartType.Cylinder, Vector3.new(0.18, 1.9, 1.5) * scale, base * CFrame.new(0, -0.35 * scale, 0.45 * scale) * CFrame.Angles(0, math.rad(90), 0), look.Body, bodyMat)
		newPart(model, "HoodMark", Enum.PartType.Cylinder, Vector3.new(0.2, 0.9, 0.7) * scale, hood.CFrame * CFrame.new(-0.02 * scale, 0, 0), look.Accent, bodyMat)
	elseif kind == "Horned" then
		for _, x in { -1, 1 } do
			wedge(model, "Horn", Vector3.new(0.18, 0.6, 0.3) * scale, base * CFrame.new(x * 0.3 * scale, 0.5 * scale, 0.1 * scale) * CFrame.Angles(math.rad(-20), 0, math.rad(x * -15)), look.Accent, bodyMat)
		end
	elseif kind == "Crest" then
		for i = 0, 2 do
			wedge(model, "CrestFin", Vector3.new(0.08, 0.45 - i * 0.08, 0.45) * scale, base * CFrame.new(0, (0.55 - i * 0.04) * scale, (0.1 + i * 0.35) * scale), look.Accent, bodyMat)
		end
	elseif kind == "Mane" then
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			newPart(model, "Mane", Enum.PartType.Ball, Vector3.new(0.38, 0.38, 0.38) * scale, base * CFrame.new(math.cos(a) * 0.62 * scale, math.sin(a) * 0.5 * scale, 0.42 * scale), look.Accent, Enum.Material.Fabric)
		end
		for _, x in { -1, 1 } do
			newPart(model, "Whisker", Enum.PartType.Block, Vector3.new(0.04, 0.04, 0.9) * scale, base * CFrame.new(x * 0.45 * scale, -0.1 * scale, -0.75 * scale) * CFrame.Angles(0, math.rad(x * 30), 0), look.Accent, Enum.Material.SmoothPlastic)
		end
	elseif kind == "Crown" then
		local band = newPart(model, "Crown", Enum.PartType.Cylinder, Vector3.new(0.25, 0.7, 0.7) * scale, base * CFrame.new(0, 0.48 * scale, 0.05 * scale) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Foil)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2
			wedge(model, "CrownTip", Vector3.new(0.1, 0.25, 0.12) * scale, band.CFrame * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(math.cos(a) * 0.3 * scale, 0.22 * scale, math.sin(a) * 0.3 * scale), GOLD, Enum.Material.Foil)
		end
		newPart(model, "CrownGem", Enum.PartType.Ball, Vector3.new(0.16, 0.16, 0.16) * scale, base * CFrame.new(0, 0.5 * scale, -0.32 * scale), look.Accent, Enum.Material.Neon)
	elseif kind == "Skull" then
		for _, x in { -1, 1 } do
			newPart(model, "Socket", Enum.PartType.Ball, Vector3.new(0.34, 0.3, 0.2) * scale, base * CFrame.new(x * 0.28 * scale, 0.14 * scale, -0.4 * scale), Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)
			newPart(model, "SocketGlow", Enum.PartType.Ball, Vector3.new(0.12, 0.12, 0.12) * scale, base * CFrame.new(x * 0.28 * scale, 0.14 * scale, -0.47 * scale), look.Accent, Enum.Material.Neon)
		end
		for i = -2, 2 do
			newPart(model, "Tooth", Enum.PartType.Block, Vector3.new(0.08, 0.14, 0.06) * scale, base * CFrame.new(i * 0.1 * scale, -0.3 * scale, -0.62 * scale), BONE, Enum.Material.SmoothPlastic)
		end
	end
	return head
end

function SnakeBuilder.build(name: string, look: Look): Model
	local model = Instance.new("Model")
	model.Name = name
	local bodyMat = MATERIALS[look.Material] or Enum.Material.SmoothPlastic
	local accentMat = if look.Material == "Neon" or look.Pattern == "Glow" then Enum.Material.Neon else bodyMat
	local transparent = if look.Material == "Glass" then 0.2 elseif has(look, "Ghost") then 0.35 else 0

	-- Corps en spirale (queue fine à l'extérieur → épais au centre)
	local points: { Vector3 } = {}
	for i = 0, SEGMENTS - 1 do
		table.insert(points, coilPoint(i / (SEGMENTS - 1)))
	end
	local segs: { Part } = {}
	for i, p in points do
		local u = (i - 1) / (SEGMENTS - 1)
		local d = 0.38 + u * 0.55
		local nextP = points[math.min(i + 1, #points)]
		local dir = if (nextP - p).Magnitude > 1e-3 then CFrame.lookAt(p, nextP) else CFrame.new(p)
		local color = look.Body
		if look.Pattern == "Bands" and i % 3 == 0 then
			color = look.Accent
		elseif look.Pattern == "Rings" then
			color = if i % 2 == 0 then look.Accent else look.Body
		end
		local seg = newPart(model, "Seg" .. i, Enum.PartType.Ball, Vector3.new(d, d * 0.9, d * 1.25), dir, color, bodyMat)
		seg.Transparency = transparent
		table.insert(segs, seg)
		-- Motifs posés sur le dos
		local top = dir * CFrame.new(0, d * 0.38, 0)
		if look.Pattern == "Stripes" then
			newPart(model, "Stripe", Enum.PartType.Block, Vector3.new(d * 0.22, 0.06, d * 1.1), top, look.Accent, accentMat)
		elseif look.Pattern == "Spots" and i % 2 == 0 then
			newPart(model, "Spot", Enum.PartType.Ball, Vector3.new(d * 0.45, d * 0.2, d * 0.45), top, look.Accent, accentMat)
		elseif look.Pattern == "Diamonds" and i % 2 == 1 then
			newPart(model, "Diamond", Enum.PartType.Block, Vector3.new(d * 0.42, 0.08, d * 0.42), top * CFrame.Angles(0, math.rad(45), 0), look.Accent, accentMat)
		elseif look.Pattern == "Glow" and i % 2 == 0 then
			newPart(model, "GlowBand", Enum.PartType.Block, Vector3.new(d * 0.3, 0.07, d * 0.8), top, look.Accent, Enum.Material.Neon)
		end
		-- Accessoires le long du corps
		if has(look, "Spikes") and i % 3 == 1 then
			wedge(model, "Spike", Vector3.new(0.1, d * 0.45, d * 0.5), top * CFrame.new(0, d * 0.2, 0), look.Accent, accentMat)
		end
		if has(look, "Bones") and i % 3 == 2 then
			newPart(model, "Rib", Enum.PartType.Block, Vector3.new(d * 1.15, 0.08, 0.1), top, BONE, Enum.Material.SmoothPlastic)
		end
		if has(look, "Crystals") and i % 4 == 0 then
			wedge(model, "Crystal", Vector3.new(0.18, d * 0.9, d * 0.35), top * CFrame.new(0, d * 0.35, 0) * CFrame.Angles(0, math.rad(i * 37), math.rad(10)), look.Accent, Enum.Material.Glass).Transparency = 0.15
		end
		if has(look, "Leaves") and i % 4 == 1 then
			newPart(model, "Leaf", Enum.PartType.Cylinder, Vector3.new(0.05, d * 0.7, d * 0.45), top * CFrame.new(d * 0.3, 0.05, 0) * CFrame.Angles(0, 0, math.rad(80)), Color3.fromRGB(60, 170, 60), Enum.Material.Grass)
		end
		if has(look, "Mushrooms") and i % 5 == 2 then
			newPart(model, "MushStem", Enum.PartType.Block, Vector3.new(0.08, 0.2, 0.08), top * CFrame.new(0, 0.1, 0), BONE, Enum.Material.SmoothPlastic)
			newPart(model, "MushCap", Enum.PartType.Ball, Vector3.new(0.32, 0.16, 0.32), top * CFrame.new(0, 0.22, 0), Color3.fromRGB(230, 40, 50), Enum.Material.SmoothPlastic)
		end
		if has(look, "Flowers") and i % 4 == 3 then
			newPart(model, "Flower", Enum.PartType.Ball, Vector3.new(0.22, 0.12, 0.22), top * CFrame.new(0, 0.05, 0), Color3.fromRGB(255, 120, 180), Enum.Material.SmoothPlastic)
		end
		if has(look, "Lava") and i % 2 == 1 then
			newPart(model, "LavaCrack", Enum.PartType.Block, Vector3.new(d * 0.9, 0.05, 0.08), top, Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
		end
		if has(look, "Frost") and i % 3 == 0 then
			wedge(model, "Icicle", Vector3.new(0.08, d * 0.5, 0.2), top * CFrame.new(0, d * 0.22, 0), Color3.fromRGB(220, 245, 255), Enum.Material.Glass).Transparency = 0.25
		end
	end

	-- Queue : grelot ou pointe
	local tail = points[1]
	if has(look, "Rattle") then
		for k = 1, 3 do
			newPart(model, "Rattle", Enum.PartType.Ball, Vector3.new(0.26, 0.2, 0.26), CFrame.new(tail + Vector3.new(0, 0.08 * k, 0)), Color3.fromRGB(225, 200, 150), Enum.Material.SmoothPlastic)
		end
	end

	-- Cou dressé jusqu'à la tête
	local neckBase = points[#points]
	local headPos = Vector3.new(0, 2.05, -0.15)
	for k = 1, 3 do
		local p = neckBase:Lerp(headPos, k / 4) + Vector3.new(0, math.sin(k / 4 * math.pi) * 0.15, 0)
		local seg = newPart(model, "Neck" .. k, Enum.PartType.Ball, Vector3.new(0.82, 0.82, 0.82), CFrame.new(p), if look.Pattern == "Rings" and k % 2 == 0 then look.Accent else look.Body, bodyMat)
		seg.Transparency = transparent
		newPart(model, "Belly", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), CFrame.new(p + Vector3.new(0, -0.05, -0.25)), look.Belly, bodyMat).Transparency = transparent
	end
	local headCf = CFrame.lookAt(headPos, headPos + Vector3.new(0, -0.1, -1))
	local head = buildHead(model, look, headCf, bodyMat, 1)
	head.Transparency = transparent
	model.PrimaryPart = head

	-- Hydre : deux têtes supplémentaires sur des cous latéraux
	if look.Head == "Hydra" then
		for _, x in { -1, 1 } do
			local side = Vector3.new(x * 0.95, 1.65, 0.1)
			for k = 1, 2 do
				newPart(model, "SideNeck", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), CFrame.new(neckBase:Lerp(side, k / 3)), look.Body, bodyMat)
			end
			buildHead(model, { Body = look.Body, Accent = look.Accent, Belly = look.Belly, Pattern = look.Pattern, Head = "Viper", Extras = {}, Material = look.Material, Size = look.Size }, CFrame.lookAt(side, side + Vector3.new(x * 0.4, -0.1, -1)), bodyMat, 0.75)
		end
	end

	-- Accessoires de tête / dos
	if has(look, "Wings") then
		for _, x in { -1, 1 } do
			local root = CFrame.new(Vector3.new(x * 0.35, 1.55, 0.35))
			for f = 0, 2 do
				local feather = newPart(model, "Wing", Enum.PartType.Block, Vector3.new(0.06, 0.32, 1.5 - f * 0.3), root * CFrame.Angles(math.rad(-25 + f * 18), math.rad(x * 70), 0) * CFrame.new(0, f * 0.18, -0.7), if f == 0 then look.Accent else look.Body, bodyMat)
				feather.Transparency = math.max(transparent, 0.05)
			end
		end
	end
	if has(look, "Feathers") then
		local colors = { Color3.fromRGB(230, 50, 50), Color3.fromRGB(40, 180, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(60, 120, 230) }
		for f = 1, 5 do
			newPart(model, "Plume", Enum.PartType.Block, Vector3.new(0.08, 0.9, 0.18), headCf * CFrame.new(0, 0.5, 0.35) * CFrame.Angles(math.rad(-30), 0, math.rad((f - 3) * 18)) * CFrame.new(0, 0.4, 0), colors[(f - 1) % #colors + 1], Enum.Material.Fabric)
		end
	end
	if has(look, "Halo") then
		local halo = newPart(model, "Halo", Enum.PartType.Cylinder, Vector3.new(0.06, 0.95, 0.95), headCf * CFrame.new(0, 0.85, 0.1) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Neon)
		halo.Transparency = 0.15
	end
	if has(look, "Fins") then
		for _, x in { -1, 1 } do
			wedge(model, "Fin", Vector3.new(0.06, 0.45, 0.55), headCf * CFrame.new(x * 0.5, 0.05, 0.25) * CFrame.Angles(0, 0, math.rad(x * -70)), look.Accent, accentMat)
		end
		wedge(model, "DorsalFin", Vector3.new(0.06, 0.6, 0.9), CFrame.new(points[10] + Vector3.new(0, 0.5, 0)), look.Accent, accentMat)
	end
	if has(look, "Antlers") then
		for _, x in { -1, 1 } do
			local a = headCf * CFrame.new(x * 0.25, 0.45, 0.15) * CFrame.Angles(math.rad(-15), 0, math.rad(x * -25))
			newPart(model, "Antler", Enum.PartType.Block, Vector3.new(0.08, 0.7, 0.08), a * CFrame.new(0, 0.35, 0), look.Accent, Enum.Material.SmoothPlastic)
			newPart(model, "AntlerTip", Enum.PartType.Block, Vector3.new(0.06, 0.35, 0.06), a * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(x * -50)) * CFrame.new(0, 0.17, 0), look.Accent, Enum.Material.SmoothPlastic)
		end
	end
	if has(look, "Tusks") then
		for _, x in { -1, 1 } do
			newPart(model, "Tusk", Enum.PartType.Block, Vector3.new(0.08, 0.35, 0.08), headCf * CFrame.new(x * 0.22, -0.32, -0.55) * CFrame.Angles(math.rad(-25), 0, 0), BONE, Enum.Material.SmoothPlastic)
		end
	end

	-- Effets
	if has(look, "Flames") then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Color = look.Accent
		fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fire.Parent = segs[#segs]
	end
	if has(look, "Sparkle") or has(look, "Stars") then
		emitter(head, { Texture = SPARKLE, Rate = 4, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.25, 0), Color = ColorSequence.new(look.Accent), LightEmission = 1 })
	end
	if has(look, "Bubbles") then
		emitter(head, { Texture = SPARKLE, Rate = 3, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.8, 1.4), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(0.18, 0.3), Color = ColorSequence.new(Color3.fromRGB(190, 255, 170)), Transparency = NumberSequence.new(0.3, 1) })
	end
	if has(look, "Ghost") then
		emitter(head, { Texture = SMOKE, Rate = 3, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(0.3, 0.8), Size = NumberSequence.new(0.6, 1.2), Color = ColorSequence.new(look.Accent), Transparency = NumberSequence.new(0.6, 1), LightEmission = 1 })
	end
	if look.Pattern == "Glow" or look.Material == "Neon" then
		local l = Instance.new("PointLight")
		l.Color = look.Accent
		l.Range = 8
		l.Brightness = 1.2
		l.Parent = head
	end

	-- Pivot recentré sur la boîte englobante (pose au sol identique aux modèles importés)
	local boxCf = model:GetBoundingBox()
	head.PivotOffset = head.CFrame:ToObjectSpace(boxCf)
	return model
end

-- Effets d'ambiance (particules, lumière, feu) pour un modèle importé (voxels Blender) :
-- la géométrie vient du FBX, les effets animés sont ajoutés ici selon le Look de l'espèce.
function SnakeBuilder.decorate(model: Model, look: Look)
	local host = model.PrimaryPart
	if not host or model:GetAttribute("Decorated") then
		return
	end
	model:SetAttribute("Decorated", true)
	if has(look, "Flames") then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Color = look.Accent
		fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
		fire.Parent = host
	end
	if has(look, "Sparkle") or has(look, "Stars") then
		emitter(host, { Texture = SPARKLE, Rate = 4, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.25, 0), Color = ColorSequence.new(look.Accent), LightEmission = 1 })
	end
	if has(look, "Bubbles") then
		emitter(host, { Texture = SPARKLE, Rate = 3, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.8, 1.4), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(0.18, 0.3), Color = ColorSequence.new(Color3.fromRGB(190, 255, 170)), Transparency = NumberSequence.new(0.3, 1) })
	end
	if has(look, "Ghost") then
		emitter(host, { Texture = SMOKE, Rate = 3, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(0.3, 0.8), Size = NumberSequence.new(0.6, 1.2), Color = ColorSequence.new(look.Accent), Transparency = NumberSequence.new(0.6, 1), LightEmission = 1 })
	end
	if look.Pattern == "Glow" or look.Material == "Neon" then
		local l = Instance.new("PointLight")
		l.Color = look.Accent
		l.Range = 8
		l.Brightness = 1.2
		l.Parent = host
	end
end

return SnakeBuilder
