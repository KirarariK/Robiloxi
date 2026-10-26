--!strict
--[[
	Éclairage / atmosphère Concord Hall (spec §3.8).
	applyHall() quand phase Lobby ; ArenaService garde applyArenaLighting en match.
	Repli mobile : LightingStyle Soft si PrioritizeLightingQuality indisponible.
]]

local Lighting = game:GetService("Lighting")
local LobbyConfig = require(script.Parent:WaitForChild("LobbyConfig"))

local LobbyLighting = {}

local function ensureChild(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

function LobbyLighting.applyHall()
	local colors = LobbyConfig.Colors

	-- Unified Lighting quand dispo (Studio / clients récents)
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Realistic;
		(Lighting :: any).PrioritizeLightingQuality = Enum.PrioritizeLightingQuality.Enabled
	end)

	Lighting.GlobalShadows = true
	Lighting.ClockTime = 18.3
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(36, 32, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(48, 40, 72)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ExposureCompensation = 0
	Lighting.FogColor = Color3.fromRGB(42, 28, 72)
	Lighting.FogStart = 80
	Lighting.FogEnd = 420
	Lighting.GeographicLatitude = 35

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.32
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(199, 184, 255)
	atmo.Decay = Color3.fromRGB(42, 27, 82)
	atmo.Glare = 0.3
	atmo.Haze = 1.8

	local sky = ensureChild("Sky", "BC_LobbySky") :: Sky
	sky.CelestialBodiesShown = true
	sky.StarCount = 4000
	sky.MoonAngularSize = 12
	sky.SunAngularSize = 14
	-- Pas de SkyboxId upload — teintes via Atmosphere + ClockTime

	local bloom = ensureChild("BloomEffect", "BC_Bloom") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.6

	local cc = ensureChild("ColorCorrectionEffect", "BC_LobbyCC") :: ColorCorrectionEffect
	cc.Contrast = 0.08
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(255, 241, 230)
	cc.Brightness = 0.02

	local rays = ensureChild("SunRaysEffect", "BC_SunRays") :: SunRaysEffect
	rays.Intensity = 0.05
	rays.Spread = 0.7

	local dof = ensureChild("DepthOfFieldEffect", "BC_LobbyDoF") :: DepthOfFieldEffect
	dof.Enabled = true
	dof.FarIntensity = 0.12
	dof.NearIntensity = 0.05
	dof.FocusDistance = 40
	dof.InFocusRadius = 55

	-- Marqueur pour clients / debug
	Lighting:SetAttribute("BC_LightingMode", "ConcordHall")
	Lighting:SetAttribute("BC_AccentGold", colors.Gold)
end

--[[ Repli qualité : Soft + effets allégés (appeler si besoin mobile bas de gamme). ]]
function LobbyLighting.applyMobileFallback()
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Soft
	end)
	local bloom = Lighting:FindFirstChild("BC_Bloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.28
		bloom.Size = 16
	end
	local dof = Lighting:FindFirstChild("BC_LobbyDoF")
	if dof and dof:IsA("DepthOfFieldEffect") then
		dof.Enabled = false
	end
	local rays = Lighting:FindFirstChild("BC_SunRays")
	if rays and rays:IsA("SunRaysEffect") then
		rays.Intensity = 0.02
	end
	Lighting:SetAttribute("BC_LightingMode", "ConcordHallMobile")
end

return LobbyLighting
