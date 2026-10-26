--!strict
--[[
	Éclairage / atmosphère Concord Hall (spec §3.8 + pass lisibilité).
	Crépuscule or-cyan lisible : Bloom/CC légers, DoF quasi off (pas le flou plateau sombre).
	applyHall() en phase Lobby ; ArenaService garde applyArenaLighting en match.
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

	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Realistic;
		(Lighting :: any).PrioritizeLightingQuality = Enum.PrioritizeLightingQuality.Enabled
	end)

	Lighting.GlobalShadows = true
	Lighting.ClockTime = 18.25
	Lighting.Brightness = 2.15
	-- Fill crépuscule lisible (évite le plateau noir opaque)
	Lighting.Ambient = Color3.fromRGB(52, 46, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(68, 58, 96)
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.85
	Lighting.ExposureCompensation = 0.15
	Lighting.FogColor = Color3.fromRGB(48, 36, 78)
	Lighting.FogStart = 140
	Lighting.FogEnd = 560
	Lighting.GeographicLatitude = 28

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.22
	atmo.Offset = 0.28
	atmo.Color = Color3.fromRGB(199, 184, 255)
	atmo.Decay = Color3.fromRGB(42, 27, 82)
	atmo.Glare = 0.22
	atmo.Haze = 1.1

	local sky = ensureChild("Sky", "BC_LobbySky") :: Sky
	sky.CelestialBodiesShown = true
	sky.StarCount = 3500
	sky.MoonAngularSize = 11
	sky.SunAngularSize = 16

	local bloom = ensureChild("BloomEffect", "BC_Bloom") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = 0.32
	bloom.Size = 18
	bloom.Threshold = 1.85

	local cc = ensureChild("ColorCorrectionEffect", "BC_LobbyCC") :: ColorCorrectionEffect
	cc.Enabled = true
	cc.Contrast = 0.06
	cc.Saturation = 0.1
	cc.TintColor = Color3.fromRGB(255, 244, 236)
	cc.Brightness = 0.04

	local rays = ensureChild("SunRaysEffect", "BC_SunRays") :: SunRaysEffect
	rays.Enabled = true
	rays.Intensity = 0.04
	rays.Spread = 0.55

	-- DoF : désactivé par défaut (captures lobby-current = flou illisible)
	local dof = ensureChild("DepthOfFieldEffect", "BC_LobbyDoF") :: DepthOfFieldEffect
	dof.Enabled = false
	dof.FarIntensity = 0.04
	dof.NearIntensity = 0
	dof.FocusDistance = 60
	dof.InFocusRadius = 80

	-- Désactive d’éventuels DoF legacy non BC_*
	for _, child in Lighting:GetChildren() do
		if child:IsA("DepthOfFieldEffect") and child.Name ~= "BC_LobbyDoF" then
			child.Enabled = false
		end
	end

	Lighting:SetAttribute("BC_LightingMode", "ConcordHall")
	Lighting:SetAttribute("BC_AccentGold", colors.Gold)
	Lighting:SetAttribute("BC_DoF", false)
end

function LobbyLighting.applyMobileFallback()
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Soft
	end)
	local bloom = Lighting:FindFirstChild("BC_Bloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.22
		bloom.Size = 12
	end
	local dof = Lighting:FindFirstChild("BC_LobbyDoF")
	if dof and dof:IsA("DepthOfFieldEffect") then
		dof.Enabled = false
	end
	local rays = Lighting:FindFirstChild("BC_SunRays")
	if rays and rays:IsA("SunRaysEffect") then
		rays.Intensity = 0.02
	end
	Lighting.FogEnd = 420
	Lighting:SetAttribute("BC_LightingMode", "ConcordHallMobile")
end

return LobbyLighting
