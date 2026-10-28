--!strict
--[[
	EnvironmentController — ambiance par zone, côté client (transitions douces).
	Hub ensoleillé · Jungle luxuriante · Désert brûlant · Marais brumeux · Volcan rougeoyant · Néant cosmique (nuit étoilée).
	Affiche aussi un titre de zone à l'entrée d'un biome (événement local ZoneChanged).
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BiomesConfig = require(game.ReplicatedStorage.StealASnake.Config.BiomesConfig)

local EnvironmentController = {}

type Mood = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	AtmoColor: Color3,
	AtmoDecay: Color3,
	AtmoDensity: number,
	Haze: number,
	Tint: Color3,
	Saturation: number,
	Bloom: number,
}

local MOODS: { [number]: Mood } = {
	[0] = { ClockTime = 14.5, Brightness = 2.6, Ambient = Color3.fromRGB(95, 100, 115), OutdoorAmbient = Color3.fromRGB(140, 145, 160), AtmoColor = Color3.fromRGB(205, 225, 255), AtmoDecay = Color3.fromRGB(110, 130, 170), AtmoDensity = 0.28, Haze = 1.2, Tint = Color3.fromRGB(255, 255, 255), Saturation = 0.2, Bloom = 0.4 },
}

local current = -1
local zoneChanged = Instance.new("BindableEvent")
EnvironmentController.ZoneChanged = zoneChanged.Event

local function zoneAt(pos: Vector3): number
	for _, cfg in BiomesConfig do
		-- zone élargie (+20) pour que l'ambiance commence au portail
		if math.abs(pos.Z - cfg.Center.Z) <= cfg.Size.Z / 2 + 20 and math.abs(pos.X - cfg.Center.X) <= cfg.Size.X / 2 + 40 then
			return cfg.Order
		end
	end
	return 0
end

local function apply(order: number)
	local cfg = BiomesConfig[order]
	local mood: Mood = if cfg then cfg.Mood :: any else MOODS[0]
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(Lighting, info, {
		ClockTime = mood.ClockTime,
		Brightness = mood.Brightness,
		Ambient = mood.Ambient,
		OutdoorAmbient = mood.OutdoorAmbient,
	}):Play()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, info, { Color = mood.AtmoColor, Decay = mood.AtmoDecay, Density = mood.AtmoDensity, Haze = mood.Haze }):Play()
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		TweenService:Create(cc, info, { TintColor = mood.Tint, Saturation = mood.Saturation }):Play()
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		TweenService:Create(bloom, info, { Intensity = mood.Bloom }):Play()
	end
end

function EnvironmentController.getZone(): number
	return current
end

function EnvironmentController.start()
	local player = Players.LocalPlayer
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then
			return
		end
		acc = 0
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			return
		end
		local z = zoneAt(hrp.Position)
		if z ~= current then
			current = z
			apply(z)
			local name = "Sanctuaires"
			for _, cfg in BiomesConfig do
				if cfg.Order == z then
					name = cfg.Name
				end
			end
			zoneChanged:Fire(z, name)
		end
	end)
end

return EnvironmentController
