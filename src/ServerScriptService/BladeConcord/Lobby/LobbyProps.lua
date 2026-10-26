--!strict
--[[
	Props procéduraux Concord Hall : colonnes, arches, braseros, cristaux,
	bannières, bassins, portails néon, piédestaux sabre, mannequins simples.
]]

local TweenService = game:GetService("TweenService")
local LobbyConfig = require(script.Parent:WaitForChild("LobbyConfig"))
local LobbyUtil = require(script.Parent:WaitForChild("LobbyUtil"))

local LobbyProps = {}
local C = LobbyConfig.Colors

function LobbyProps.column(parent: Instance, localPos: Vector3, height: number?, yaw: number?): Model?
	local h = height or LobbyConfig.ColumnHeight
	local m = LobbyUtil.model("Column", parent)
	local base = LobbyUtil.part(
		"Base",
		Vector3.new(6, 1.2, 6),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.6, 0), yaw),
		C.Ink600,
		m,
		Enum.Material.Slate
	)
	if not base then
		return nil
	end
	LobbyUtil.part(
		"Shaft",
		Vector3.new(4.2, h - 4, 4.2),
		LobbyUtil.cf(localPos + Vector3.new(0, h / 2, 0), yaw),
		C.Marble,
		m,
		Enum.Material.Marble,
		{ reflectance = 0.08 }
	)
	LobbyUtil.part(
		"Capital",
		Vector3.new(5.5, 1.4, 5.5),
		LobbyUtil.cf(localPos + Vector3.new(0, h - 1.2, 0), yaw),
		C.GoldDark,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.25 }
	)
	local trim = LobbyUtil.part(
		"GoldRing",
		Vector3.new(4.6, 0.35, 4.6),
		LobbyUtil.cf(localPos + Vector3.new(0, h * 0.55, 0), yaw),
		C.Gold,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.35 }
	)
	if trim then
		LobbyUtil.pointLight(trim, C.Gold, 0.35, 12)
	end
	return m
end

function LobbyProps.arch(parent: Instance, localPos: Vector3, width: number, height: number, yaw: number?)
	local m = LobbyUtil.model("Arch", parent)
	local half = width / 2
	LobbyUtil.part(
		"PillarL",
		Vector3.new(3, height, 3),
		LobbyUtil.cf(localPos + Vector3.new(-half, height / 2, 0), yaw),
		C.Marble,
		m,
		Enum.Material.Limestone
	)
	LobbyUtil.part(
		"PillarR",
		Vector3.new(3, height, 3),
		LobbyUtil.cf(localPos + Vector3.new(half, height / 2, 0), yaw),
		C.Marble,
		m,
		Enum.Material.Limestone
	)
	LobbyUtil.part(
		"Lintels",
		Vector3.new(width + 4, 2.5, 4),
		LobbyUtil.cf(localPos + Vector3.new(0, height + 1, 0), yaw),
		C.Ink600,
		m,
		Enum.Material.Slate
	)
	local neon = LobbyUtil.part(
		"ArchNeon",
		Vector3.new(width - 2, 0.4, 0.4),
		LobbyUtil.cf(localPos + Vector3.new(0, height - 1, 0), yaw),
		C.Focus,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.25 }
	)
	if neon then
		LobbyUtil.pointLight(neon, C.Focus, 0.5, 14)
		LobbyUtil.tag(neon, LobbyConfig.Tags.PortalPulse)
	end
end

function LobbyProps.banner(parent: Instance, localPos: Vector3, color: Color3, height: number?, yaw: number?)
	local h = height or 26
	local m = LobbyUtil.model("Banner", parent)
	LobbyUtil.part(
		"Pole",
		Vector3.new(0.6, h, 0.6),
		LobbyUtil.cf(localPos + Vector3.new(0, h / 2, 0), yaw),
		C.Steel,
		m,
		Enum.Material.Metal
	)
	local cloth = LobbyUtil.part(
		"Cloth",
		Vector3.new(8, h * 0.7, 0.35),
		LobbyUtil.cf(localPos + Vector3.new(0, h * 0.55, 0.4), yaw),
		color,
		m,
		Enum.Material.Fabric,
		{ canCollide = false }
	)
	if cloth then
		local trim = LobbyUtil.part(
			"Trim",
			Vector3.new(8.2, 0.4, 0.45),
			LobbyUtil.cf(localPos + Vector3.new(0, h * 0.9, 0.4), yaw),
			C.Gold,
			m,
			Enum.Material.Metal,
			{ canCollide = false, reflectance = 0.2 }
		)
		if trim then
			-- sway léger
			task.defer(function()
				local t = TweenService:Create(
					cloth,
					TweenInfo.new(
						3.2 + math.random() * 0.8,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut,
						-1,
						true
					),
					{ CFrame = cloth.CFrame * CFrame.Angles(0, 0, math.rad(4)) }
				)
				t:Play()
			end)
		end
	end
	return m
end

function LobbyProps.brazier(parent: Instance, localPos: Vector3, color: Color3?, withLight: boolean?)
	local col = color or C.Forge
	local m = LobbyUtil.model("Brazier", parent)
	LobbyUtil.part(
		"Bowl",
		Vector3.new(3.2, 1.2, 3.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 1.8, 0)),
		C.Ink600,
		m,
		Enum.Material.Metal,
		{ reflectance = 0.15 }
	)
	LobbyUtil.part(
		"Stem",
		Vector3.new(1.2, 2.2, 1.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.9, 0)),
		C.Steel,
		m,
		Enum.Material.Metal
	)
	local flame = LobbyUtil.part(
		"Flame",
		Vector3.new(1.6, 1.6, 1.6),
		LobbyUtil.cf(localPos + Vector3.new(0, 3.2, 0)),
		col,
		m,
		Enum.Material.Neon,
		{ canCollide = false, shape = Enum.PartType.Ball, transparency = 0.2, castShadow = false }
	)
	if flame then
		if withLight ~= false then
			LobbyUtil.pointLight(flame, col, 1.4, 18)
		end
		LobbyUtil.emitter(flame, "Embers", {
			rate = 5,
			lifetime = NumberRange.new(1.2, 2.4),
			speed = NumberRange.new(0.5, 1.8),
			accel = Vector3.new(0, 3, 0),
			color = ColorSequence.new(col, Color3.fromRGB(80, 30, 10)),
			lightEmission = 0.6,
		})
	end
	return m
end

function LobbyProps.crystal(parent: Instance, localPos: Vector3, color: Color3, scale: number?)
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
	LobbyUtil.pointLight(body, color, 0.7, 14)
	LobbyUtil.tag(body, LobbyConfig.Tags.CrystalSpin)
	body:SetAttribute("BC_SpinSpeed", 18 + math.random() * 10)
	return m
end

function LobbyProps.basin(parent: Instance, localPos: Vector3, radius: number, waterColor: Color3)
	local m = LobbyUtil.model("Basin", parent)
	LobbyUtil.part(
		"Rim",
		Vector3.new(radius * 2, 1.2, radius * 2),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.4, 0)),
		C.Marble,
		m,
		Enum.Material.Marble
	)
	local water = LobbyUtil.part(
		"Water",
		Vector3.new(radius * 1.7, 0.6, radius * 1.7),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.7, 0)),
		waterColor,
		m,
		Enum.Material.Glass,
		{ canCollide = false, transparency = 0.35, reflectance = 0.3 }
	)
	if water then
		LobbyUtil.pointLight(water, waterColor, 0.4, 12)
		LobbyUtil.emitter(water, "Mist", {
			rate = 3,
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
	end
	return m
end

function LobbyProps.pedestalSaber(parent: Instance, localPos: Vector3, formId: string, bladeColor: Color3)
	local m = LobbyUtil.model("FormPedestal_" .. formId, parent, "Forms")
	local plinth = LobbyUtil.part(
		"Plinth",
		Vector3.new(5, 1.2, 5),
		LobbyUtil.cf(localPos + Vector3.new(0, 0.6, 0)),
		C.Ink600,
		m,
		Enum.Material.Slate
	)
	LobbyUtil.part(
		"Column",
		Vector3.new(2.4, 4, 2.4),
		LobbyUtil.cf(localPos + Vector3.new(0, 3.2, 0)),
		C.Marble,
		m,
		Enum.Material.Marble,
		{ reflectance = 0.1 }
	)
	local glass = LobbyUtil.part(
		"GlassCase",
		Vector3.new(4.2, 7, 4.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 7, 0)),
		Color3.fromRGB(120, 160, 200),
		m,
		Enum.Material.ForceField,
		{ canCollide = false, transparency = 0.75, castShadow = false }
	)
	local hilt = LobbyUtil.part(
		"Hilt",
		Vector3.new(0.45, 1.6, 0.45),
		LobbyUtil.cf(localPos + Vector3.new(0, 5.2, 0)),
		C.Steel,
		m,
		Enum.Material.Metal,
		{ canCollide = false, reflectance = 0.3 }
	)
	local blade = LobbyUtil.part(
		"Blade",
		Vector3.new(0.35, 5.5, 0.18),
		LobbyUtil.cf(localPos + Vector3.new(0, 8.8, 0)),
		bladeColor,
		m,
		Enum.Material.Neon,
		{ canCollide = false, castShadow = false }
	)
	if blade then
		LobbyUtil.pointLight(blade, bladeColor, 0.9, 12)
		LobbyUtil.tag(blade, LobbyConfig.Tags.CrystalSpin)
		blade:SetAttribute("BC_SpinSpeed", 25)
		blade:SetAttribute("BC_FormId", formId)
	end
	if plinth then
		LobbyUtil.billboard(plinth, formId, bladeColor, Vector2.new(120, 28), 10)
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
	return m, hilt
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
		Vector3.new(0.4, h, len),
		LobbyUtil.cf(mid + Vector3.new(0, h / 2, 0), yaw),
		C.Steel,
		parent,
		Enum.Material.Metal,
		{ reflectance = 0.12 }
	)
	local glass = LobbyUtil.part(
		"Glass",
		Vector3.new(0.15, h * 0.85, len * 0.98),
		LobbyUtil.cf(mid + Vector3.new(0, h * 0.5, 0), yaw),
		Color3.fromRGB(140, 180, 220),
		parent,
		Enum.Material.Glass,
		{ canCollide = false, transparency = 0.65 }
	)
	if glass then
		local gold = LobbyUtil.part(
			"GoldCap",
			Vector3.new(0.35, 0.25, len),
			LobbyUtil.cf(mid + Vector3.new(0, h + 0.1, 0), yaw),
			C.Gold,
			parent,
			Enum.Material.Metal,
			{ canCollide = false, reflectance = 0.3 }
		)
		gold = gold
	end
end

function LobbyProps.neonPortal(parent: Instance, localPos: Vector3, color: Color3, label: string, yaw: number?)
	local m = LobbyUtil.model("Portal_" .. label, parent)
	LobbyUtil.part(
		"Frame",
		Vector3.new(14, 18, 1.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 9, 0), yaw),
		C.Ink700,
		m,
		Enum.Material.Metal
	)
	local gate = LobbyUtil.part(
		"Gate",
		Vector3.new(10, 14, 0.4),
		LobbyUtil.cf(localPos + Vector3.new(0, 8, 0), yaw),
		color,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.45, castShadow = false }
	)
	if gate then
		LobbyUtil.pointLight(gate, color, 1.2, 22)
		LobbyUtil.tag(gate, LobbyConfig.Tags.PortalPulse)
		LobbyUtil.emitter(gate, "PortalSparks", {
			rate = 4,
			lifetime = NumberRange.new(0.8, 1.6),
			speed = NumberRange.new(0.5, 2),
			spread = Vector2.new(180, 180),
			color = ColorSequence.new(color, C.Bone),
			lightEmission = 0.7,
		})
		LobbyUtil.billboard(gate, label, color, Vector2.new(180, 32), 10)
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
	local sash = LobbyUtil.part(
		"Sash",
		Vector3.new(2.1, 0.35, 1.2),
		LobbyUtil.cf(localPos + Vector3.new(0, 3.5, 0)),
		accent,
		m,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.3 }
	)
	return m, sash
end

return LobbyProps
