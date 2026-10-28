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
	[1] = { ClockTime = 13, Brightness = 2.4, Ambient = Color3.fromRGB(70, 100, 70), OutdoorAmbient = Color3.fromRGB(110, 150, 110), AtmoColor = Color3.fromRGB(190, 235, 200), AtmoDecay = Color3.fromRGB(80, 140, 90), AtmoDensity = 0.36, Haze = 1.8, Tint = Color3.fromRGB(235, 255, 235), Saturation = 0.28, Bloom = 0.4 },
	[2] = { ClockTime = 12, Brightness = 3.2, Ambient = Color3.fromRGB(130, 110, 85), OutdoorAmbient = Color3.fromRGB(180, 155, 120), AtmoColor = Color3.fromRGB(255, 225, 170), AtmoDecay = Color3.fromRGB(220, 160, 90), AtmoDensity = 0.34, Haze = 2.2, Tint = Color3.fromRGB(255, 240, 215), Saturation = 0.15, Bloom = 0.35 },
	[3] = { ClockTime = 17.4, Brightness = 1.4, Ambient = Color3.fromRGB(60, 75, 60), OutdoorAmbient = Color3.fromRGB(85, 105, 85), AtmoColor = Color3.fromRGB(150, 185, 140), AtmoDecay = Color3.fromRGB(70, 95, 70), AtmoDensity = 0.52, Haze = 3, Tint = Color3.fromRGB(215, 245, 215), Saturation = 0.05, Bloom = 0.5 },
	[4] = { ClockTime = 18.6, Brightness = 1.2, Ambient = Color3.fromRGB(110, 55, 40), OutdoorAmbient = Color3.fromRGB(140, 70, 50), AtmoColor = Color3.fromRGB(255, 130, 80), AtmoDecay = Color3.fromRGB(120, 40, 20), AtmoDensity = 0.45, Haze = 2.6, Tint = Color3.fromRGB(255, 215, 195), Saturation = 0.25, Bloom = 0.7 },
	[5] = { ClockTime = 0.5, Brightness = 1.6, Ambient = Color3.fromRGB(70, 60, 130), OutdoorAmbient = Color3.fromRGB(80, 70, 150), AtmoColor = Color3.fromRGB(120, 110, 220), AtmoDecay = Color3.fromRGB(40, 30, 100), AtmoDensity = 0.32, Haze = 1.5, Tint = Color3.fromRGB(220, 215, 255), Saturation = 0.35, Bloom = 0.9 },
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
	local mood = MOODS[order] or MOODS[0]
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
