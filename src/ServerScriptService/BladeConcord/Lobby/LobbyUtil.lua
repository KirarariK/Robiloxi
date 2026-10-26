--!strict
--[[
	Helpers Constructible + compteurs budget (parts / lights / emitters).
]]

local CollectionService = game:GetService("CollectionService")
local LobbyConfig = require(script.Parent:WaitForChild("LobbyConfig"))

local LobbyUtil = {}

export type Budget = {
	parts: number,
	lights: number,
	emitters: number,
	surfaceGuis: number,
}

local budget: Budget = {
	parts = 0,
	lights = 0,
	emitters = 0,
	surfaceGuis = 0,
}

function LobbyUtil.resetBudget()
	budget = { parts = 0, lights = 0, emitters = 0, surfaceGuis = 0 }
end

function LobbyUtil.getBudget(): Budget
	return budget
end

function LobbyUtil.world(localPos: Vector3): Vector3
	return LobbyConfig.Origin + localPos
end

function LobbyUtil.cf(localPos: Vector3, yawDeg: number?): CFrame
	local yaw = math.rad(yawDeg or 0)
	return CFrame.new(LobbyUtil.world(localPos)) * CFrame.Angles(0, yaw, 0)
end

function LobbyUtil.canAddPart(n: number?): boolean
	local add = n or 1
	return budget.parts + add <= LobbyConfig.Budget.MaxParts
end

function LobbyUtil.part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	opts: {
		anchored: boolean?,
		canCollide: boolean?,
		transparency: number?,
		reflectance: number?,
		shape: Enum.PartType?,
		castShadow: boolean?,
	}?
): BasePart?
	if not LobbyUtil.canAddPart(1) then
		return nil
	end
	local o = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = if o.anchored == nil then true else o.anchored
	p.CanCollide = if o.canCollide == nil then true else o.canCollide
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	p.CastShadow = if o.castShadow == nil then true else o.castShadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape then
		p.Shape = o.shape
	end
	p.Parent = parent
	budget.parts += 1
	return p
end

function LobbyUtil.pointLight(parent: BasePart, color: Color3, brightness: number, range: number): PointLight?
	if budget.lights >= LobbyConfig.Budget.MaxLights then
		return nil
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	budget.lights += 1
	return light
end

function LobbyUtil.remainingEmitters(): number
	return math.max(0, LobbyConfig.Budget.MaxEmitters - budget.emitters)
end

--[[
	Réserve 1 slot emitter (NeonFx / helpers externes). False si budget plein.
]]
function LobbyUtil.noteEmitter(): boolean
	if budget.emitters >= LobbyConfig.Budget.MaxEmitters then
		return false
	end
	budget.emitters += 1
	return true
end

function LobbyUtil.emitter(
	parent: BasePart,
	name: string,
	props: {
		rate: number?,
		lifetime: NumberRange?,
		speed: NumberRange?,
		spread: Vector2?,
		accel: Vector3?,
		size: NumberSequence?,
		transparency: NumberSequence?,
		color: ColorSequence?,
		lightEmission: number?,
	}
): ParticleEmitter?
	if not LobbyUtil.noteEmitter() then
		return nil
	end
	local att = parent:FindFirstChildOfClass("Attachment")
	if not att then
		att = Instance.new("Attachment")
		att.Parent = parent
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.Rate = props.rate or 6
	pe.Lifetime = props.lifetime or NumberRange.new(2, 4)
	pe.Speed = props.speed or NumberRange.new(0.2, 1)
	pe.SpreadAngle = props.spread or Vector2.new(40, 40)
	pe.Acceleration = props.accel or Vector3.new(0, 0.8, 0)
	pe.Size = props.size
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 0.05),
		})
	pe.Transparency = props.transparency
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.45),
			NumberSequenceKeypoint.new(0.85, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
	pe.Color = props.color or ColorSequence.new(Color3.fromRGB(200, 210, 230))
	pe.LightEmission = props.lightEmission or 0.35
	pe.LightInfluence = 0.25
	pe.LockedToPart = false
	pe.Parent = att
	return pe
end

function LobbyUtil.billboard(host: BasePart, text: string, color: Color3, size: Vector2?, studsY: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(size and size.X or 220, size and size.Y or 36)
	gui.StudsOffset = Vector3.new(0, studsY or (host.Size.Y * 0.5 + 2), 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 160
	gui.Adornee = host
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = LobbyConfig.Colors.Ink900
	label.BackgroundTransparency = 0.35
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = label
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1.1
	s.Transparency = 0.45
	s.Parent = label
	return gui
end

function LobbyUtil.tag(inst: Instance, tag: string)
	CollectionService:AddTag(inst, tag)
end

function LobbyUtil.model(name: string, parent: Instance, zoneId: string?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if zoneId then
		m:SetAttribute("BC_ZoneId", zoneId)
		LobbyUtil.tag(m, LobbyConfig.Tags.Zone)
	end
	m.Parent = parent
	return m
end

function LobbyUtil.noteSurfaceGui(): boolean
	if budget.surfaceGuis >= LobbyConfig.Budget.MaxSurfaceGuis then
		return false
	end
	budget.surfaceGuis += 1
	return true
end

function LobbyUtil.warnBudget(prefix: string)
	local b = budget
	local lim = LobbyConfig.Budget
	print(
		string.format(
			"[BladeConcord] %s budget parts=%d/%d lights=%d/%d emitters=%d/%d gui=%d/%d",
			prefix,
			b.parts,
			lim.MaxParts,
			b.lights,
			lim.MaxLights,
			b.emitters,
			lim.MaxEmitters,
			b.surfaceGuis,
			lim.MaxSurfaceGuis
		)
	)
end

return LobbyUtil
