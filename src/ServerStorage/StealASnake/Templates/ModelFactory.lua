--!strict
--[[
	ModelFactory — fabrique les modèles de jeu à partir des modèles 3D de
	ReplicatedStorage.StealASnake.Assets.Models (générés / importés), avec repli en Parts.

	coiledSnake(modelName, scale) : serpent enroulé (nids, vivariums, portage) normalisé à SNAKE_SIZE studs
	treadmill(level)              : tapis niveaux 1–10 (Treadmill_L1..L5 + teinte/néon par palier)
	basket()                      : panier d'osier porté devant le joueur
	vivarium()                    : terrarium (décor des slots)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelFactory = {}

local SNAKE_SIZE = 3.4 -- plus grande dimension d'un serpent à l'échelle 1

local function models(): Instance?
	local root = ReplicatedStorage:FindFirstChild("StealASnake")
	local assets = root and root:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Models")
end

local function importedTemplate(names: { string }): Model?
	local folder = models()
	if not folder then
		return nil
	end
	for _, n in names do
		local m = folder:FindFirstChild(n)
		if m and m:IsA("Model") then
			return m
		end
	end
	return nil
end

-- Clone : PrimaryPart garanti (la plus grosse pièce), pièces soudées à la PrimaryPart si non ancrées.
local function cloneImported(template: Model, name: string, anchored: boolean, collide: boolean): Model
	local m = template:Clone()
	m.Name = name
	if not m.PrimaryPart then
		local biggest: BasePart? = nil
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (not biggest or d.Size.Magnitude > biggest.Size.Magnitude) then
				biggest = d
			end
		end
		m.PrimaryPart = biggest
	end
	local primary = m.PrimaryPart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
			d.CanCollide = collide
			d.CanTouch = collide
			d.Massless = not anchored
			if primary and d ~= primary and not anchored then
				local w = Instance.new("WeldConstraint")
				w.Part0 = primary
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	return m
end

local function scaleToSize(m: Model, maxDim: number)
	local _, size = m:GetBoundingBox()
	local current = math.max(size.X, size.Y, size.Z)
	if current > 0.01 then
		m:ScaleTo(m:GetScale() * (maxDim / current))
	end
end

local function addStealPrompt(host: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Voler"
	prompt.ObjectText = "Serpent"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = host
end

--[[ ───────────── Serpent enroulé ───────────── ]]

local SPECIES_COLORS: { [string]: { Color3 } } = {
	Viper_Green = { Color3.fromRGB(40, 170, 55), Color3.fromRGB(70, 230, 90) },
	Python_Royal = { Color3.fromRGB(140, 90, 35), Color3.fromRGB(220, 170, 70) },
	Cobra_Royal = { Color3.fromRGB(200, 150, 40), Color3.fromRGB(245, 210, 70) },
	Horned_Rattler = { Color3.fromRGB(180, 120, 55), Color3.fromRGB(230, 160, 70) },
	Anaconda_Spiked = { Color3.fromRGB(70, 120, 55), Color3.fromRGB(140, 50, 170) },
	Magma_Serpent = { Color3.fromRGB(90, 25, 15), Color3.fromRGB(245, 90, 20) },
	Celestial_Ouroboros = { Color3.fromRGB(40, 55, 150), Color3.fromRGB(140, 200, 255) },
}

-- Repli en Parts : spirale de boules + tête + yeux.
local function partSnake(modelName: string, s: number): Model
	local colors = SPECIES_COLORS[modelName] or SPECIES_COLORS.Viper_Green
	local model = Instance.new("Model")
	model.Name = modelName
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.4, 1.2, 1.3) * s
	head.CFrame = CFrame.new(0, 1.2 * s, 0)
	head.Color = colors[2]
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model
	model.PrimaryPart = head
	for i = 1, 8 do
		local t = i / 8
		local ang = t * math.pi * 2 * 2.4
		local rad = (0.6 + t * 0.9) * s
		local seg = Instance.new("Part")
		seg.Name = "Seg" .. i
		seg.Shape = Enum.PartType.Ball
		local r = (1.0 - t * 0.4) * s
		seg.Size = Vector3.new(r, r, r)
		seg.CFrame = CFrame.new(math.cos(ang) * rad, 0.7 * s, math.sin(ang) * rad)
		seg.Color = if i % 2 == 0 then colors[1] else colors[2]
		seg.Material = Enum.Material.SmoothPlastic
		seg.Parent = model
	end
	for _, side in { 0.35, -0.35 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.25, 0.25, 0.25) * s
		eye.CFrame = head.CFrame * CFrame.new(side, 0.2, -0.55)
		eye.Color = Color3.new(0.05, 0.05, 0.05)
		eye.Material = Enum.Material.Neon
		eye.Parent = model
	end
	return model
end

function ModelFactory.coiledSnake(modelName: string, scale: number?): Model
	local s = scale or 1
	local template = importedTemplate({ modelName })
	local m: Model
	if template then
		m = cloneImported(template, modelName, false, false)
		scaleToSize(m, SNAKE_SIZE * s)
	else
		m = cloneImported(partSnake(modelName, s), modelName, false, false)
	end
	m:SetAttribute("IsSnake", true)
	if m.PrimaryPart then
		addStealPrompt(m.PrimaryPart)
	end
	return m
end

--[[ ───────────── Tapis de course (10 niveaux) ───────────── ]]

-- Couleur de liseré par niveau (le modèle 3D est commun, l'accent change).
local TREAD_ACCENTS: { Color3 } = {
	Color3.fromRGB(150, 100, 55), -- 1 bois bricolé
	Color3.fromRGB(150, 150, 165), -- 2 gym
	Color3.fromRGB(60, 150, 255), -- 3 néons bleus
	Color3.fromRGB(160, 80, 255), -- 4 magnétique violet
	Color3.fromRGB(255, 200, 60), -- 5 quantique or
	Color3.fromRGB(80, 255, 200), -- 6
	Color3.fromRGB(255, 90, 160), -- 7 plasma
	Color3.fromRGB(255, 120, 40), -- 8 hyper
	Color3.fromRGB(120, 220, 255), -- 9 warp
	Color3.fromRGB(255, 255, 255), -- 10 anti-gravité
}

function ModelFactory.treadmill(level: number): Model
	local lvl = math.clamp(level, 1, 10)
	local accent = TREAD_ACCENTS[lvl]
	local template = importedTemplate({ "Treadmill_L" .. math.clamp(lvl, 1, 5), "Treadmill" })
	local m: Model
	if template then
		m = cloneImported(template, "Treadmill_L" .. lvl, true, false)
		scaleToSize(m, 10)
	else
		m = Instance.new("Model")
		local deck = Instance.new("Part")
		deck.Name = "Deck"
		deck.Size = Vector3.new(4, 0.8, 9)
		deck.Color = Color3.fromRGB(40, 40, 48)
		deck.Material = Enum.Material.Rubber
		deck.Anchored = true
		deck.CanCollide = false
		deck.Parent = m
		m.PrimaryPart = deck
		for _, x in { -2.2, 2.2 } do
			local rail = Instance.new("Part")
			rail.Name = "Rail"
			rail.Size = Vector3.new(0.4, 0.5, 9)
			rail.CFrame = CFrame.new(x, 0.3, 0)
			rail.Color = accent
			rail.Material = if lvl >= 3 then Enum.Material.Neon else Enum.Material.Wood
			rail.Anchored = true
			rail.CanCollide = false
			rail.Parent = m
			local post = Instance.new("Part")
			post.Name = "Handle"
			post.Size = Vector3.new(0.3, 3.4, 0.3)
			post.CFrame = CFrame.new(x, 1.9, -4)
			post.Color = Color3.fromRGB(60, 60, 70)
			post.Material = Enum.Material.Metal
			post.Anchored = true
			post.CanCollide = false
			post.Parent = m
		end
	end
	m.Name = "Treadmill_L" .. lvl
	-- Liseré lumineux par niveau (au sol, autour du tapis)
	local _, size = m:GetBoundingBox()
	local glow = Instance.new("Part")
	glow.Name = "LevelGlow"
	glow.Size = Vector3.new(size.X + 1, 0.15, size.Z + 1)
	glow.CFrame = m:GetPivot() * CFrame.new(0, -size.Y / 2 + 0.05, 0)
	glow.Color = accent
	glow.Material = if lvl >= 3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	glow.Transparency = 0.35
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CastShadow = false
	glow.Parent = m
	if lvl >= 5 then
		local att = Instance.new("Attachment")
		att.Parent = glow
		local pe = Instance.new("ParticleEmitter")
		pe.Rate = 4 + lvl
		pe.Lifetime = NumberRange.new(0.6, 1.2)
		pe.Speed = NumberRange.new(1, 3)
		pe.Color = ColorSequence.new(accent)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.25, 0)
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Parent = att
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "LevelTag"
	bb.Size = UDim2.fromOffset(120, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2.5, 0)
	bb.MaxDistance = 60
	bb.Parent = glow
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "🏃 Niv. " .. lvl
	tl.TextScaled = true
	tl.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	tl.TextColor3 = accent
	tl.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = tl
	return m
end

--[[ ───────────── Panier & vivarium ───────────── ]]

function ModelFactory.basket(): Model
	local template = importedTemplate({ "WickerBasket" })
	if template then
		local m = cloneImported(template, "WickerBasket", false, false)
		scaleToSize(m, 2.6)
		return m
	end
	local m = Instance.new("Model")
	m.Name = "WickerBasket"
	local wall = Instance.new("Part")
	wall.Name = "Basket"
	wall.Shape = Enum.PartType.Cylinder
	wall.Size = Vector3.new(1.4, 2.4, 2.4)
	wall.CFrame = CFrame.Angles(0, 0, math.rad(90))
	wall.Color = Color3.fromRGB(170, 115, 60)
	wall.Material = Enum.Material.Fabric
	wall.Anchored = false
	wall.Massless = true
	wall.CanCollide = false
	wall.Parent = m
	m.PrimaryPart = wall
	return m
end

function ModelFactory.vivarium(): Model
	local template = importedTemplate({ "Vivarium" })
	if template then
		return cloneImported(template, "Vivarium", true, true)
	end
	local m = Instance.new("Model")
	m.Name = "Vivarium"
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(6, 0.6, 4)
	base.Color = Color3.fromRGB(110, 70, 35)
	base.Anchored = true
	base.Parent = m
	m.PrimaryPart = base
	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Size = Vector3.new(5.6, 4, 3.6)
	glass.Transparency = 0.55
	glass.Color = Color3.fromRGB(160, 220, 255)
	glass.Material = Enum.Material.Glass
	glass.Anchored = true
	glass.CanCollide = false
	glass.CFrame = base.CFrame * CFrame.new(0, 2.2, 0)
	glass.Parent = m
	return m
end

return ModelFactory
