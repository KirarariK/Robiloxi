--!strict
--[[
	Props procéduraux Concord Hall (densité maquette) :
	colonnes ornées or, arches-vues, braseros, cristaux, bannières factions,
	bassins, portails, piédestaux, balcons, vitrine arsenal, forge.
	Lumières optionnelles — budget PointLight géré par LobbyUtil.
	FX néon strips : LobbyProps.attachNeonStrip → Visual/NeonFx (tag BC_NeonStrip).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LobbyConfig = require(script.Parent:WaitForChild("LobbyConfig"))
local LobbyUtil = require(script.Parent:WaitForChild("LobbyUtil"))

local NeonFx = require(
	ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Visual"):WaitForChild("NeonFx")
)

local LobbyProps = {}
local C = LobbyConfig.Colors

local function neonBudgetHooks()
	return NeonFx.hooksFromCounters(LobbyUtil.remainingEmitters, LobbyUtil.noteEmitter)
end

--[[
	Tag BC_NeonStrip + ParticleEmitter drift (budget LobbyUtil ≤30).
	À appeler depuis World après pose d’un strip Neon Material.
]]
function LobbyProps.attachNeonStrip(part: BasePart, color: Color3?): ParticleEmitter?
	NeonFx.tagStrip(part)
	LobbyUtil.tag(part, LobbyConfig.Tags.NeonStrip)
	return NeonFx.attachStripEmitter(part, color or part.Color, nil, neonBudgetHooks())
end

function LobbyProps.column(
	parent: Instance,
	localPos: Vector3,
	height: number?,
	yaw: number?,
	withLight: boolean?
): Model?
	local h = height or LobbyConfig.ColumnHeight
	local m = LobbyUtil.model("Column", parent)
	local base = LobbyUtil.part(
		"Base",
		Vector3.new(7.5, 1.6, 7.5),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.8, 0), yaw),
		C.Ink600,
		m,
		Enum.Material.Slate,
		{ reflectance = 0.05 }
	)
	if not base then
		return nil
	end
	-- Plinthe or
	LobbyUtil.part(
		"BaseGold",
		Vector3.new(7.8, 0.35, 7.8),
		LobbyUtil.cf(localPos + Vector3.new(0, 1.55, 0), yaw),
		C.GoldDark,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.35 }
	)
	LobbyUtil.part(
		"Shaft",
		Vector3.new(5.2, h - 5.5, 5.2),
		LobbyUtil.cf(localPos + Vector3.new(0, h / 2, 0), yaw),
		C.Marble,
		m,
		Enum.Material.Marble,
		{ reflectance = 0.12 }
	)
	-- Cannelures (4 bandeaux sombres)
	for i = 0, 3 do
		local ang = (i / 4) * math.pi * 2 + math.rad(yaw or 0)
		local ox = math.sin(ang) * 2.55
		local oz = -math.cos(ang) * 2.55
		LobbyUtil.part(
			"Flute" .. i,
			Vector3.new(0.55, h - 7, 0.55),
			LobbyUtil.cf(localPos + Vector3.new(ox, h / 2, oz), yaw),
			C.Ink700,
			m,
			Enum.Material.Slate,
			{ canCollide = false }
		)
	end
	-- Anneaux or décoratifs
	for _, yFrac in { 0.28, 0.52, 0.72 } do
		LobbyUtil.part(
			"GoldBand",
			Vector3.new(5.6, 0.4, 5.6),
			LobbyUtil.cf(localPos + Vector3.new(0, h * yFrac, 0), yaw),
			C.Gold,
			m,
			Enum.Material.Metal,
			{ canCollide = false, reflectance = 0.4 }
		)
	end
	LobbyUtil.part(
		"Capital",
		Vector3.new(7, 1.8, 7),
		LobbyUtil.cf(localPos + Vector3.new(0, h - 1.4, 0), yaw),
		C.GoldDark,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.28 }
	)
	LobbyUtil.part(
		"Abacus",
		Vector3.new(8.2, 0.7, 8.2),
		LobbyUtil.cf(localPos + Vector3.new(0, h - 0.25, 0), yaw),
		C.MarbleLite,
		m,
		Enum.Material.Marble
	)
	local neon = LobbyUtil.part(
		"CapitalNeon",
		Vector3.new(5.8, 0.25, 5.8),
		LobbyUtil.cf(localPos + Vector3.new(0, h - 2.2, 0), yaw),
		C.GoldLite,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.45, castShadow = false }
	)
	if neon and withLight then
		LobbyUtil.pointLight(neon, C.Gold, 0.4, 14)
	end
	return m
end

--[[ Grande arche temple + linteau or + néon — ouverture vers diorama / ciel. ]]
function LobbyProps.grandArch(
	parent: Instance,
	localPos: Vector3,
	width: number,
	height: number,
	yaw: number?,
	accent: Color3?,
	withLight: boolean?
)
	local m = LobbyUtil.model("GrandArch", parent)
	local col = accent or C.Gold
	local half = width / 2
	LobbyUtil.part(
		"PillarL",
		Vector3.new(4.5, height, 4.5),
		LobbyUtil.cf(localPos + Vector3.new(-half, height / 2, 0), yaw),
		C.Marble,
		m,
		Enum.Material.Marble,
		{ reflectance = 0.1 }
	)
	LobbyUtil.part(
		"PillarR",
		Vector3.new(4.5, height, 4.5),
		LobbyUtil.cf(localPos + Vector3.new(half, height / 2, 0), yaw),
		C.Marble,
		m,
		Enum.Material.Marble,
		{ reflectance = 0.1 }
	)
	LobbyUtil.part(
		"BaseL",
		Vector3.new(5.5, 1.4, 5.5),
		LobbyUtil.cf(localPos + Vector3.new(-half, 0.7, 0), yaw),
		C.Ink600,
		m,
		Enum.Material.Slate
	)
	LobbyUtil.part(
		"BaseR",
		Vector3.new(5.5, 1.4, 5.5),
		LobbyUtil.cf(localPos + Vector3.new(half, 0.7, 0), yaw),
		C.Ink600,
		m,
		Enum.Material.Slate
	)
	LobbyUtil.part(
		"Lintel",
		Vector3.new(width + 8, 3.2, 5),
		LobbyUtil.cf(localPos + Vector3.new(0, height + 1.4, 0), yaw),
		C.Ink600,
		m,
		Enum.Material.Slate
	)
	LobbyUtil.part(
		"LintelGold",
		Vector3.new(width + 6, 0.55, 5.2),
		LobbyUtil.cf(localPos + Vector3.new(0, height + 0.2, 0), yaw),
		C.Gold,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.35 }
	)
	-- Arc décoratif (3 blocs)
	for i = -1, 1 do
		LobbyUtil.part(
			"ArchKey" .. i,
			Vector3.new(width * 0.28, 2.2, 3.5),
			LobbyUtil.cf(localPos + Vector3.new(i * width * 0.32, height - 1.5, 0), yaw),
			C.MarbleLite,
			m,
			Enum.Material.Marble,
			{ canCollide = false }
		)
	end
	local neon = LobbyUtil.part(
		"ArchNeon",
		Vector3.new(width - 4, 0.45, 0.45),
		LobbyUtil.cf(localPos + Vector3.new(0, height - 2.5, -1.5), yaw),
		col,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.2, castShadow = false }
	)
	if neon then
		LobbyUtil.tag(neon, LobbyConfig.Tags.PortalPulse)
		LobbyProps.attachNeonStrip(neon, col)
		if withLight then
			LobbyUtil.pointLight(neon, col, 0.55, 16)
		end
	end
	return m
end

function LobbyProps.arch(parent: Instance, localPos: Vector3, width: number, height: number, yaw: number?)
	LobbyProps.grandArch(parent, localPos, width, height, yaw, C.Focus, false)
end

function LobbyProps.banner(
	parent: Instance,
	localPos: Vector3,
	color: Color3,
	height: number?,
	yaw: number?,
	label: string?
)
	local h = height or 26
	local m = LobbyUtil.model("Banner", parent)
	LobbyUtil.part(
		"Pole",
		Vector3.new(0.7, h, 0.7),
		LobbyUtil.cf(localPos + Vector3.new(0, h / 2, 0), yaw),
		C.Steel,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.15 }
	)
	LobbyUtil.part(
		"Finial",
		Vector3.new(1.4, 1.2, 1.4),
		LobbyUtil.cf(localPos + Vector3.new(0, h + 0.4, 0), yaw),
		C.Gold,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.4, shape = Enum.PartType.Ball }
	)
	local cloth = LobbyUtil.part(
		"Cloth",
		Vector3.new(10, h * 0.72, 0.4),
		LobbyUtil.cf(localPos + Vector3.new(0, h * 0.52, 0.55), yaw),
		color,
		m,
		Enum.Material.Fabric,
		{ canCollide = false }
	)
	LobbyUtil.part(
		"TrimTop",
		Vector3.new(10.4, 0.5, 0.5),
		LobbyUtil.cf(localPos + Vector3.new(0, h * 0.88, 0.55), yaw),
		C.Gold,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.25 }
	)
	LobbyUtil.part(
		"TrimSideL",
		Vector3.new(0.35, h * 0.7, 0.45),
		LobbyUtil.cf(localPos + Vector3.new(-5, h * 0.52, 0.55), yaw),
		C.GoldDark,
		m,
		Enum.Material.Metal,
		{ canCollide = false }
	)
	LobbyUtil.part(
		"TrimSideR",
		Vector3.new(0.35, h * 0.7, 0.45),
		LobbyUtil.cf(localPos + Vector3.new(5, h * 0.52, 0.55), yaw),
		C.GoldDark,
		m,
		Enum.Material.Metal,
		{ canCollide = false }
	)
	-- Emblème (disque or)
	local emblem = LobbyUtil.part(
		"Emblem",
		Vector3.new(3.2, 3.2, 0.35),
		LobbyUtil.cf(localPos + Vector3.new(0, h * 0.62, 0.85), yaw),
		C.GoldLite,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.15, castShadow = false }
	)
	if cloth then
		if label then
			LobbyUtil.billboard(cloth, label, C.GoldLite, Vector2.new(160, 28), 2)
		end
		task.defer(function()
			local t = TweenService:Create(
				cloth,
				TweenInfo.new(3.4 + math.random() * 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ CFrame = cloth.CFrame * CFrame.Angles(0, 0, math.rad(3.5)) }
			)
			t:Play()
		end)
	end
	return m, emblem
end

function LobbyProps.brazier(parent: Instance, localPos: Vector3, color: Color3?, withLight: boolean?)
	local col = color or C.Forge
	local m = LobbyUtil.model("Brazier", parent)
	LobbyUtil.part(
		"Stem",
		Vector3.new(1.4, 2.4, 1.4),
		LobbyUtil.cf(localPos + Vector3.new(0, 1.1, 0)),
		C.Steel,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.2 }
	)
	LobbyUtil.part(
		"Bowl",
		Vector3.new(3.6, 1.3, 3.6),
		LobbyUtil.cf(localPos + Vector3.new(0, 2.1, 0)),
		C.Ink600,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.18 }
	)
	LobbyUtil.part(
		"RimGold",
		Vector3.new(3.9, 0.3, 3.9),
		LobbyUtil.cf(localPos + Vector3.new(0, 2.7, 0)),
		C.GoldDark,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.3 }
	)
	local flame = LobbyUtil.part(
		"Flame",
		Vector3.new(1.8, 2.2, 1.8),
		LobbyUtil.cf(localPos + Vector3.new(0, 3.6, 0)),
		col,
		m,
		Enum.Material.Neon,
		{ canCollide = false, shape = Enum.PartType.Ball, transparency = 0.18, castShadow = false }
	)
	if flame then
		if withLight then
			LobbyUtil.pointLight(flame, col, 1.5, 20)
		end
		LobbyUtil.emitter(flame, "Embers", {
			rate = 4,
			lifetime = NumberRange.new(1.2, 2.4),
			speed = NumberRange.new(0.5, 1.8),
			accel = Vector3.new(0, 3, 0),
			color = ColorSequence.new(col, Color3.fromRGB(80, 30, 10)),
			lightEmission = 0.6,
		})
	end
	return m
end

function LobbyProps.crystal(parent: Instance, localPos: Vector3, color: Color3, scale: number?, withLight: boolean?)
	local s = scale or 1
	local m = LobbyUtil.model("Crystal", parent)
	local body = LobbyUtil.part(
		"Shard",
		Vector3.new(1.4 * s, 4.5 * s, 1.4 * s),
		LobbyUtil.cf(localPos + Vector3.new(0, 3 * s, 0)) * CFrame.Angles(0, math.rad(25), math.rad(12)),
		color,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.15, castShadow = false }
	)
	if not body then
		return nil
	end
	LobbyUtil.part(
		"Core",
		Vector3.new(0.7 * s, 2.2 * s, 0.7 * s),
		LobbyUtil.cf(localPos + Vector3.new(0, 3 * s, 0)),
		C.Bone,
		m,
		Enum.Material.Glass,
		{ canCollide = false, transparency = 0.4 }
	)
	if withLight then
		LobbyUtil.pointLight(body, color, 0.7, 14)
	end
	LobbyUtil.tag(body, LobbyConfig.Tags.CrystalSpin)
	body:SetAttribute("BC_SpinSpeed", 18 + math.random() * 10)
	return m
end

function LobbyProps.basin(parent: Instance, localPos: Vector3, radius: number, waterColor: Color3, withLight: boolean?)
	local m = LobbyUtil.model("Basin", parent)
	LobbyUtil.part(
		"Rim",
		Vector3.new(radius * 2, 1.4, radius * 2),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.5, 0)),
		C.Marble,
		m,
		Enum.Material.Marble,
		{ reflectance = 0.15 }
	)
	LobbyUtil.part(
		"RimGold",
		Vector3.new(radius * 2.05, 0.25, radius * 2.05),
		LobbyUtil.cf(localPos + Vector3.new(0, 1.15, 0)),
		C.Gold,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.3 }
	)
	local water = LobbyUtil.part(
		"Water",
		Vector3.new(radius * 1.7, 0.55, radius * 1.7),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.85, 0)),
		waterColor,
		m,
		Enum.Material.Glass,
		{ canCollide = false, transparency = 0.3, reflectance = 0.45 }
	)
	if water then
		if withLight then
			LobbyUtil.pointLight(water, waterColor, 0.45, 14)
		end
		LobbyUtil.emitter(water, "Mist", {
			rate = 2,
			lifetime = NumberRange.new(3, 5),
			speed = NumberRange.new(0.1, 0.4),
			accel = Vector3.new(0, 0.4, 0),
			color = ColorSequence.new(waterColor),
		})
	end
	return m
end

function LobbyProps.stairs(parent: Instance, localPos: Vector3, steps: number, width: number, yaw: number?)
	local m = LobbyUtil.model("Stairs", parent)
	for i = 1, steps do
		LobbyUtil.part(
			"Step" .. i,
			Vector3.new(width, 0.55, 2.2),
			LobbyUtil.cf(localPos + Vector3.new(0, 0.55 * (i - 0.5), -2.2 * (i - 1)), yaw),
			C.MarbleLite,
			m,
			Enum.Material.Slate
		)
		LobbyUtil.part(
			"StepTrim" .. i,
			Vector3.new(width, 0.12, 0.2),
			LobbyUtil.cf(localPos + Vector3.new(0, 0.55 * i, -2.2 * (i - 1) - 1), yaw),
			C.GoldDark,
			m,
			Enum.Material.Metal,
			{ canCollide = false, reflectance = 0.25 }
		)
	end
	return m
end

function LobbyProps.pedestalSaber(parent: Instance, localPos: Vector3, formId: string, bladeColor: Color3, withLight: boolean?)
	local m = LobbyUtil.model("FormPedestal_" .. formId, parent, "Forms")
	local plinth = LobbyUtil.part(
		"Plinth",
		Vector3.new(5.5, 1.3, 5.5),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.65, 0)),
		C.Ink600,
		m,
		Enum.Material.Slate
	)
	LobbyUtil.part(
		"PlinthGold",
		Vector3.new(5.7, 0.25, 5.7),
		LobbyUtil.cf(localPos + Vector3.new(0, 1.25, 0)),
		C.Gold,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.35 }
	)
	LobbyUtil.part(
		"Column",
		Vector3.new(2.6, 4.2, 2.6),
		LobbyUtil.cf(localPos + Vector3.new(0, 3.4, 0)),
		C.Marble,
		m,
		Enum.Material.Marble,
		{ reflectance = 0.12 }
	)
	local glass = LobbyUtil.part(
		"GlassCase",
		Vector3.new(4.4, 7.5, 4.4),
		LobbyUtil.cf(localPos + Vector3.new(0, 7.2, 0)),
		Color3.fromRGB(120, 160, 200),
		m,
		Enum.Material.ForceField,
		{ canCollide = false, transparency = 0.72, castShadow = false }
	)
	LobbyUtil.part(
		"Hilt",
		Vector3.new(0.5, 1.6, 0.5),
		LobbyUtil.cf(localPos + Vector3.new(0, 5.4, 0)),
		C.Steel,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.35 }
	)
	local blade = LobbyUtil.part(
		"Blade",
		Vector3.new(0.38, 5.8, 0.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 9, 0)),
		bladeColor,
		m,
		Enum.Material.Neon,
		{ canCollide = false, castShadow = false }
	)
	if blade then
		if withLight then
			LobbyUtil.pointLight(blade, bladeColor, 0.85, 12)
		end
		LobbyUtil.tag(blade, LobbyConfig.Tags.CrystalSpin)
		blade:SetAttribute("BC_SpinSpeed", 22)
		blade:SetAttribute("BC_FormId", formId)
	end
	if plinth then
		LobbyUtil.billboard(plinth, formId, bladeColor, Vector2.new(120, 28), 11)
	end
	if glass then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Voir les Formes"
		prompt.ObjectText = formId
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = glass
		glass:SetAttribute("BC_OpenPanel", "Forms")
	end
	return m
end

--[[ Vitrine Arsenal / Postures (maquette droite). ]]
function LobbyProps.arsenalCase(parent: Instance, localPos: Vector3, yaw: number?, withLight: boolean?)
	local m = LobbyUtil.model("ArsenalCase", parent, "Forms")
	local frame = LobbyUtil.part(
		"Frame",
		Vector3.new(18, 14, 1.4),
		LobbyUtil.cf(localPos + Vector3.new(0, 8, 0), yaw),
		C.GoldDark,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.25 }
	)
	local glass = LobbyUtil.part(
		"Glass",
		Vector3.new(16, 12, 0.4),
		LobbyUtil.cf(localPos + Vector3.new(0, 8, -0.4), yaw),
		Color3.fromRGB(140, 180, 220),
		m,
		Enum.Material.Glass,
		{ canCollide = false, transparency = 0.55, reflectance = 0.2 }
	)
	LobbyUtil.part(
		"Back",
		Vector3.new(16.5, 12.5, 0.6),
		LobbyUtil.cf(localPos + Vector3.new(0, 8, 0.6), yaw),
		C.Ink800,
		m,
		Enum.Material.Slate
	)
	for i = 1, 3 do
		local x = -5 + (i - 1) * 5
		local col = if i == 1 then C.Focus elseif i == 2 then C.Gold else C.Arcane
		LobbyUtil.part(
			"DisplayHilt" .. i,
			Vector3.new(0.45, 1.4, 0.45),
			LobbyUtil.cf(localPos + Vector3.new(x, 4.5, -0.2), yaw),
			C.Steel,
			m,
			Enum.Material.Metal,
			{ canCollide = false, reflectance = 0.3 }
		)
		local blade = LobbyUtil.part(
			"DisplayBlade" .. i,
			Vector3.new(0.32, 6.5, 0.16),
			LobbyUtil.cf(localPos + Vector3.new(x, 8.8, -0.2), yaw),
			col,
			m,
			Enum.Material.Neon,
			{ canCollide = false, castShadow = false }
		)
		if blade and withLight and i == 2 then
			LobbyUtil.pointLight(blade, col, 0.7, 14)
		end
	end
	if frame then
		LobbyUtil.billboard(frame, "ARSENAL — POSTURES", C.GoldLite, Vector2.new(240, 32), 8)
	end
	if glass then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Voir les Formes"
		prompt.ObjectText = "Arsenal"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = glass
		glass:SetAttribute("BC_OpenPanel", "Forms")
	end
	return m
end

function LobbyProps.forgeHearth(parent: Instance, localPos: Vector3, yaw: number?, withLight: boolean?)
	local m = LobbyUtil.model("ForgeHearth", parent, "Forge")
	LobbyUtil.part(
		"BackWall",
		Vector3.new(22, 16, 2),
		LobbyUtil.cf(localPos + Vector3.new(0, 8, 0), yaw),
		C.Ink700,
		m,
		Enum.Material.Basalt
	)
	LobbyUtil.part(
		"ArchFrame",
		Vector3.new(12, 10, 1.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 6, -1.2), yaw),
		C.Steel,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.15 }
	)
	local fire = LobbyUtil.part(
		"HearthFire",
		Vector3.new(8, 6, 2),
		LobbyUtil.cf(localPos + Vector3.new(0, 5, -1.5), yaw),
		C.Forge,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.25, castShadow = false }
	)
	if fire then
		if withLight then
			LobbyUtil.pointLight(fire, C.Forge, 1.6, 28)
		end
		LobbyUtil.emitter(fire, "ForgeSparks", {
			rate = 5,
			lifetime = NumberRange.new(0.8, 1.6),
			speed = NumberRange.new(1, 3),
			accel = Vector3.new(0, 4, 0),
			color = ColorSequence.new(C.Forge, C.Lava),
			lightEmission = 0.7,
		})
	end
	LobbyUtil.part(
		"MantelGold",
		Vector3.new(14, 0.5, 2.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 11.2, -1), yaw),
		C.Gold,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.35 }
	)
	return m
end

function LobbyProps.balconySegment(parent: Instance, localPos: Vector3, length: number, yaw: number?)
	local m = LobbyUtil.model("Balcony", parent)
	LobbyUtil.part(
		"Deck",
		Vector3.new(length, 1.2, 10),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.6, 0), yaw),
		C.Marble,
		m,
		Enum.Material.Marble,
		{ reflectance = 0.08 }
	)
	LobbyUtil.part(
		"FasciaGold",
		Vector3.new(length, 0.35, 0.4),
		LobbyUtil.cf(localPos + Vector3.new(0, 1.3, -4.8), yaw),
		C.Gold,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.3 }
	)
	LobbyProps.railing(
		m,
		localPos + Vector3.new(-length * 0.45, 1.2, -4.5),
		localPos + Vector3.new(length * 0.45, 1.2, -4.5),
		3.2
	)
	return m
end

function LobbyProps.railing(parent: Instance, from: Vector3, to: Vector3, height: number?)
	local h = height or 3
	local mid = (from + to) * 0.5
	local delta = to - from
	local len = delta.Magnitude
	if len < 0.5 then
		return
	end
	local yaw = math.deg(math.atan2(-delta.X, -delta.Z))
	LobbyUtil.part(
		"Rail",
		Vector3.new(0.45, h, len),
		LobbyUtil.cf(mid + Vector3.new(0, h / 2, 0), yaw),
		C.Steel,
		parent,
		Enum.Material.Metal,
		{ reflectance = 0.15 }
	)
	LobbyUtil.part(
		"Glass",
		Vector3.new(0.15, h * 0.85, len * 0.98),
		LobbyUtil.cf(mid + Vector3.new(0, h * 0.5, 0), yaw),
		Color3.fromRGB(140, 180, 220),
		parent,
		Enum.Material.Glass,
		{ canCollide = false, transparency = 0.62 }
	)
	LobbyUtil.part(
		"GoldCap",
		Vector3.new(0.4, 0.28, len),
		LobbyUtil.cf(mid + Vector3.new(0, h + 0.12, 0), yaw),
		C.Gold,
		parent,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.35 }
	)
	-- Piliers de balustrade
	local posts = math.clamp(math.floor(len / 8), 2, 12)
	for i = 0, posts do
		local t = i / posts
		local p = from:Lerp(to, t)
		LobbyUtil.part(
			"Post",
			Vector3.new(0.55, h, 0.55),
			LobbyUtil.cf(p + Vector3.new(0, h / 2, 0), yaw),
			C.Ink600,
			parent,
			Enum.Material.Slate,
			{ canCollide = false }
		)
	end
end

function LobbyProps.neonPortal(parent: Instance, localPos: Vector3, color: Color3, label: string, yaw: number?, withLight: boolean?)
	local m = LobbyUtil.model("Portal_" .. label, parent)
	LobbyUtil.part(
		"Frame",
		Vector3.new(16, 20, 1.4),
		LobbyUtil.cf(localPos + Vector3.new(0, 10, 0), yaw),
		C.Ink700,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.12 }
	)
	LobbyUtil.part(
		"FrameGold",
		Vector3.new(16.5, 0.5, 1.6),
		LobbyUtil.cf(localPos + Vector3.new(0, 20.2, 0), yaw),
		C.Gold,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.35 }
	)
	local gate = LobbyUtil.part(
		"Gate",
		Vector3.new(11, 15, 0.45),
		LobbyUtil.cf(localPos + Vector3.new(0, 9, 0), yaw),
		color,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.42, castShadow = false }
	)
	if gate then
		if withLight then
			LobbyUtil.pointLight(gate, color, 1.1, 20)
		end
		LobbyUtil.tag(gate, LobbyConfig.Tags.PortalPulse)
		LobbyUtil.emitter(gate, "PortalSparks", {
			rate = 3,
			lifetime = NumberRange.new(0.8, 1.6),
			speed = NumberRange.new(0.5, 2),
			spread = Vector2.new(180, 180),
			color = ColorSequence.new(color, C.Bone),
			lightEmission = 0.7,
		})
		LobbyUtil.billboard(gate, label, color, Vector2.new(200, 32), 10)
	end
	return m
end

function LobbyProps.mannequin(parent: Instance, localPos: Vector3, accent: Color3)
	local m = LobbyUtil.model("Mannequin", parent)
	LobbyUtil.part(
		"Torso",
		Vector3.new(2, 2.4, 1.1),
		LobbyUtil.cf(localPos + Vector3.new(0, 3.2, 0)),
		C.Ink600,
		m,
		Enum.Material.SmoothPlastic
	)
	LobbyUtil.part(
		"Head",
		Vector3.new(1.2, 1.2, 1.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 5, 0)),
		C.MarbleLite,
		m,
		Enum.Material.SmoothPlastic,
		{ shape = Enum.PartType.Ball }
	)
	LobbyUtil.part(
		"LegL",
		Vector3.new(0.7, 2.2, 0.7),
		LobbyUtil.cf(localPos + Vector3.new(-0.5, 1.1, 0)),
		C.Ink700,
		m,
		Enum.Material.SmoothPlastic
	)
	LobbyUtil.part(
		"LegR",
		Vector3.new(0.7, 2.2, 0.7),
		LobbyUtil.cf(localPos + Vector3.new(0.5, 1.1, 0)),
		C.Ink700,
		m,
		Enum.Material.SmoothPlastic
	)
	LobbyUtil.part(
		"Sash",
		Vector3.new(2.1, 0.35, 1.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 3.5, 0)),
		accent,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.3 }
	)
	return m
end

--[[ God-ray vertical (Beam cheap via Part ForceField). ]]
function LobbyProps.godRay(parent: Instance, localPos: Vector3, color: Color3, height: number?)
	local h = height or 48
	local ray = LobbyUtil.part(
		"GodRay",
		Vector3.new(6, h, 6),
		LobbyUtil.cf(localPos + Vector3.new(0, h / 2, 0)),
		color,
		parent,
		Enum.Material.ForceField,
		{ canCollide = false, transparency = 0.82, castShadow = false }
	)
	return ray
end

export type DuelSlotSpec = {
	index: number,
	x: number,
	z: number,
	side: string,
	color: Color3,
}

--[[
	Ring 1v1 + pad claim (réf allée).
	Retourne le ClaimPad (BasePart) tagué BC_DuelSlotPad / BC_DuelSlot.
]]
function LobbyProps.duelSlot(parent: Instance, spec: DuelSlotSpec, withLight: boolean?): BasePart?
	local idx = spec.index
	local center = Vector3.new(spec.x, 0, spec.z)
	local towardAlley = if spec.side == "Left" then 1 else -1 -- pad décalé vers X=0
	local yaw = if spec.side == "Left" then 90 else -90
	local ringSize = LobbyConfig.SlotRingSize
	local matColor = if idx % 2 == 1 then C.RingMatA else C.RingMatB

	local zone = LobbyUtil.model("DuelSlot_" .. idx, parent, "DuelSlot")
	zone:SetAttribute("BC_DuelSlot", idx)
	zone:SetAttribute("BC_DuelSlotSide", spec.side)

	-- Plateforme ring
	local floor = LobbyUtil.part(
		"RingFloor",
		ringSize,
		LobbyUtil.cf(center + Vector3.new(0, ringSize.Y * 0.5, 0), yaw),
		matColor,
		zone,
		Enum.Material.Fabric,
		{ reflectance = 0.04 }
	)
	LobbyUtil.part(
		"RingSkirt",
		Vector3.new(ringSize.X + 1.5, 0.6, ringSize.Z + 1.5),
		LobbyUtil.cf(center + Vector3.new(0, 0.2, 0), yaw),
		C.Ink700,
		zone,
		Enum.Material.Slate
	)

	-- 4 poteaux coins
	local halfX = ringSize.X * 0.5 - 0.8
	local halfZ = ringSize.Z * 0.5 - 0.8
	local postH = 8
	local corners = {
		Vector3.new(-halfX, 0, -halfZ),
		Vector3.new(halfX, 0, -halfZ),
		Vector3.new(-halfX, 0, halfZ),
		Vector3.new(halfX, 0, halfZ),
	}
	for i, off in corners do
		LobbyUtil.part(
			"Post" .. i,
			Vector3.new(1.1, postH, 1.1),
			LobbyUtil.cf(center + Vector3.new(off.X, postH * 0.5 + 1, off.Z), yaw),
			C.Ink900,
			zone,
			Enum.Material.Metal,
			{ reflectance = 0.1 }
		)
	end

	-- Cordes (3 hauteurs × 4 côtés) — Neon lisible
	local ropeColors = { Color3.fromRGB(255, 70, 80), Color3.fromRGB(70, 140, 255), Color3.fromRGB(255, 70, 80) }
	for layer = 1, 3 do
		local y = 2.2 + (layer - 1) * 2.0
		local col = ropeColors[layer]
		-- avant / arrière (le long de X local ring)
		LobbyUtil.part(
			"RopeF" .. layer,
			Vector3.new(ringSize.X - 2, 0.25, 0.25),
			LobbyUtil.cf(center + Vector3.new(0, y, -halfZ), yaw),
			col,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, castShadow = false }
		)
		LobbyUtil.part(
			"RopeB" .. layer,
			Vector3.new(ringSize.X - 2, 0.25, 0.25),
			LobbyUtil.cf(center + Vector3.new(0, y, halfZ), yaw),
			col,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, castShadow = false }
		)
		LobbyUtil.part(
			"RopeL" .. layer,
			Vector3.new(0.25, 0.25, ringSize.Z - 2),
			LobbyUtil.cf(center + Vector3.new(-halfX, y, 0), yaw),
			col,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, castShadow = false }
		)
		LobbyUtil.part(
			"RopeR" .. layer,
			Vector3.new(0.25, 0.25, ringSize.Z - 2),
			LobbyUtil.cf(center + Vector3.new(halfX, y, 0), yaw),
			col,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, castShadow = false }
		)
	end

	-- Pad claim vers l’allée
	local padSize = LobbyConfig.SlotPadSize
	local padPos = center + Vector3.new(towardAlley * (halfX + padSize.X * 0.55 + 2), 0, 0)
	local pad = LobbyUtil.part(
		"ClaimPad",
		padSize,
		LobbyUtil.cf(padPos + Vector3.new(0, 0.55, 0), yaw),
		spec.color,
		zone,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.25, castShadow = false }
	)
	if not pad then
		return nil
	end
	pad:SetAttribute("BC_DuelSlot", idx)
	pad:SetAttribute("BC_DuelSlotSide", spec.side)
	LobbyUtil.tag(pad, LobbyConfig.Tags.DuelSlotPad)

	LobbyUtil.part(
		"PadRim",
		Vector3.new(padSize.X + 1.2, 0.2, padSize.Z + 1.2),
		LobbyUtil.cf(padPos + Vector3.new(0, 0.35, 0), yaw),
		spec.color,
		zone,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.55, castShadow = false }
	)

	if withLight then
		LobbyUtil.pointLight(pad, spec.color, 1.2, 22)
	end
	LobbyUtil.emitter(pad, "SlotEnergy", {
		rate = 4,
		lifetime = NumberRange.new(0.8, 1.8),
		speed = NumberRange.new(0.8, 2.2),
		accel = Vector3.new(0, 5, 0),
		color = ColorSequence.new(spec.color, C.Bone),
		lightEmission = 0.75,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ClaimPrompt"
	prompt.ActionText = "Rejoindre Slot " .. idx
	prompt.ObjectText = "1v1"
	prompt.HoldDuration = 0.12
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = pad

	local touch = LobbyUtil.part(
		"TouchVolume",
		Vector3.new(padSize.X + 2, 6, padSize.Z + 2),
		LobbyUtil.cf(padPos + Vector3.new(0, 3.2, 0), yaw),
		spec.color,
		zone,
		Enum.Material.ForceField,
		{ canCollide = false, transparency = 1, castShadow = false }
	)
	if touch then
		touch:SetAttribute("BC_DuelSlot", idx)
		LobbyUtil.tag(touch, LobbyConfig.Tags.DuelSlotPad)
	end

	-- Panneau SurfaceGui « Slot N »
	local board = LobbyUtil.part(
		"SlotSign",
		Vector3.new(10, 6, 0.6),
		LobbyUtil.cf(center + Vector3.new(-towardAlley * (halfX + 1.5), 8, 0), yaw + 180),
		C.Ink900,
		zone,
		Enum.Material.Metal,
		{ reflectance = 0.08 }
	)
	if board then
		LobbyUtil.part(
			"SignNeon",
			Vector3.new(10.4, 6.4, 0.25),
			board.CFrame * CFrame.new(0, 0, -0.4),
			spec.color,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, transparency = 0.4, castShadow = false }
		)
		if LobbyUtil.noteSurfaceGui() then
			local sg = Instance.new("SurfaceGui")
			sg.Name = "SlotLabelGui"
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 25
			sg.Parent = board
			board:SetAttribute("BC_DuelSlot", idx)
			local frame = Instance.new("Frame")
			frame.Name = "Frame"
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = C.Ink900
			frame.BackgroundTransparency = 0.15
			frame.Parent = sg
			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.Size = UDim2.new(1, -12, 0.45, 0)
			title.Position = UDim2.fromOffset(6, 8)
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.GothamBlack
			title.TextSize = 36
			title.TextColor3 = spec.color
			title.Text = "SLOT " .. idx
			title.Parent = frame
			local sub = Instance.new("TextLabel")
			sub.Name = "Status"
			sub.Size = UDim2.new(1, -12, 0.35, 0)
			sub.Position = UDim2.new(0, 6, 0.5, 0)
			sub.BackgroundTransparency = 1
			sub.Font = Enum.Font.GothamMedium
			sub.TextSize = 18
			sub.TextColor3 = C.Bone
			sub.Text = "1v1 — libre"
			sub.Parent = frame
		end
	end

	if floor then
		LobbyUtil.billboard(floor, "Slot " .. idx, spec.color, Vector2.new(120, 28), 10)
	end

	return pad
end

return LobbyProps

