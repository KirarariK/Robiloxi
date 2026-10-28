--!strict
local VFXFactory = {}

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	for k, v in props do
		(pe :: any)[k] = v
	end
	pe.Parent = parent
	return pe
end

function VFXFactory.ensureAssets(root: Folder)
	local vfx = root:FindFirstChild("Assets")
	if not vfx then
		vfx = Instance.new("Folder")
		vfx.Name = "Assets"
		vfx.Parent = root
	end
	local folder = vfx:FindFirstChild("VFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "VFX"
		folder.Parent = vfx
	end
	assert(folder:IsA("Folder"))

	local function make(name: string, build: (Model) -> ())
		if folder:FindFirstChild(name) then
			return
		end
		local m = Instance.new("Model")
		m.Name = name
		local anchor = Instance.new("Part")
		anchor.Name = "Anchor"
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Parent = m
		m.PrimaryPart = anchor
		build(m)
		m.Parent = folder
	end

	make("AlbinoHighlight", function(m)
		local h = Instance.new("Highlight")
		h.Name = "Highlight"
		h.FillColor = Color3.new(1, 1, 1)
		h.OutlineColor = Color3.new(1, 1, 1)
		h.FillTransparency = 0.75
		h.Parent = m
	end)

	make("VenomousVFX", function(m)
		local h = Instance.new("Highlight")
		h.Name = "Highlight"
		h.FillColor = Color3.fromRGB(40, 200, 40)
		h.OutlineColor = Color3.fromRGB(80, 255, 60)
		h.FillTransparency = 0.7
		h.Parent = m
		local att = Instance.new("Attachment")
		att.Parent = m.PrimaryPart
		emitter(att, {
			Name = "AcidDrops",
			Rate = 12,
			Lifetime = NumberRange.new(0.4, 0.9),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(40, 40),
			Color = ColorSequence.new(Color3.fromRGB(80, 255, 70)),
			Size = NumberSequence.new(0.25, 0),
			LightEmission = 0.4,
		})
		emitter(att, {
			Name = "ToxicSmoke",
			Rate = 6,
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.5, 1.5),
			Color = ColorSequence.new(Color3.fromRGB(40, 120, 40)),
			Size = NumberSequence.new(0.8, 1.6),
			Transparency = NumberSequence.new(0.4, 1),
		})
	end)

	make("GoldVFX", function(m)
		local att = Instance.new("Attachment")
		att.Parent = m.PrimaryPart
		emitter(att, {
			Name = "GoldStars",
			Rate = 10,
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(0.5, 2),
			Color = ColorSequence.new(Color3.fromRGB(255, 210, 60)),
			Size = NumberSequence.new(0.2, 0),
			LightEmission = 0.8,
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
		})
	end)

	make("CosmicVFX", function(m)
		local att = Instance.new("Attachment")
		att.Parent = m.PrimaryPart
		emitter(att, {
			Name = "Nebula",
			Rate = 14,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(1, 3),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
			}),
			Size = NumberSequence.new(0.3, 0.9),
			LightEmission = 0.9,
		})
	end)

	make("HeavySweatVFX", function(m)
		local att = Instance.new("Attachment")
		att.Parent = m.PrimaryPart
		emitter(att, {
			Name = "Sweat",
			Rate = 18,
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(25, 25),
			Color = ColorSequence.new(Color3.fromRGB(180, 220, 255)),
			Size = NumberSequence.new(0.12, 0),
			Acceleration = Vector3.new(0, -20, 0),
		})
	end)

	make("SpeedLinesVFX", function(m)
		local a0 = Instance.new("Attachment")
		a0.Name = "A0"
		a0.Position = Vector3.new(0, 0, 0)
		a0.Parent = m.PrimaryPart
		local a1 = Instance.new("Attachment")
		a1.Name = "A1"
		a1.Position = Vector3.new(0, 0, 2)
		a1.Parent = m.PrimaryPart
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.25
		trail.MinLength = 0.1
		trail.WidthScale = NumberSequence.new(0.6, 0)
		trail.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255), Color3.fromRGB(80, 160, 255))
		trail.LightEmission = 0.5
		trail.Parent = m.PrimaryPart
	end)

	make("CashBurstVFX", function(m)
		local att = Instance.new("Attachment")
		att.Parent = m.PrimaryPart
		emitter(att, {
			Name = "Cash",
			Rate = 0,
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(10, 22),
			SpreadAngle = Vector2.new(180, 180),
			Color = ColorSequence.new(Color3.fromRGB(90, 255, 120), Color3.fromRGB(255, 230, 80)),
			Size = NumberSequence.new(0.45, 0),
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
		})
	end)

	make("DangerVignette", function(m)
		-- Client clones into ScreenGui; marker only
		m:SetAttribute("IsVignette", true)
	end)

	return folder
end

-- Les meshes générés ont une texture : on l'enlève pour que la couleur de mutation s'affiche.
local function recolor(p: BasePart, color: Color3, material: Enum.Material?)
	if p:IsA("MeshPart") then
		p.TextureID = ""
	end
	p.Color = color
	if material then
		p.Material = material
	end
end

function VFXFactory.applyMutation(model: Model, mutation: string, assets: Folder?)
	local head = model.PrimaryPart
	if not head or model:GetAttribute("MutationApplied") then
		return
	end
	model:SetAttribute("MutationApplied", true)
	model:SetAttribute("Mutation", mutation)
	if mutation == "Albino" then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Eye" then
				recolor(p, Color3.fromRGB(250, 245, 240), Enum.Material.SmoothPlastic)
			elseif p:IsA("BasePart") and p.Name == "Eye" then
				p.Color = Color3.fromRGB(255, 40, 40)
				p.Material = Enum.Material.Neon
			end
		end
		local h = Instance.new("Highlight")
		h.FillTransparency = 0.85
		h.OutlineColor = Color3.fromRGB(255, 120, 140)
		h.Parent = model
	elseif mutation == "Venomous" then
		local h = Instance.new("Highlight")
		h.OutlineColor = Color3.fromRGB(80, 255, 60)
		h.FillColor = Color3.fromRGB(40, 200, 40)
		h.FillTransparency = 0.7
		h.Parent = model
		local att = Instance.new("Attachment")
		att.Parent = head
		emitter(att, {
			Rate = 10,
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(1, 3),
			Color = ColorSequence.new(Color3.fromRGB(80, 255, 70)),
			Size = NumberSequence.new(0.2, 0),
		})
	elseif mutation == "Gold" then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Eye" then
				recolor(p, Color3.fromRGB(255, 196, 50), Enum.Material.Foil)
				p.Reflectance = 0.4
			end
		end
		local att = Instance.new("Attachment")
		att.Parent = head
		emitter(att, {
			Rate = 8,
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(0.5, 2),
			Color = ColorSequence.new(Color3.fromRGB(255, 210, 60)),
			Size = NumberSequence.new(0.2, 0),
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
		})
	elseif mutation == "Cosmic" then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Eye" then
				recolor(p, Color3.fromRGB(140, 100, 255), Enum.Material.Neon)
			end
		end
		local att = Instance.new("Attachment")
		att.Parent = head
		emitter(att, {
			Rate = 12,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(1, 3),
			Color = ColorSequence.new(Color3.fromRGB(140, 100, 255), Color3.fromRGB(80, 220, 255)),
			Size = NumberSequence.new(0.25, 0.7),
			LightEmission = 0.9,
		})
	end
end

return VFXFactory
