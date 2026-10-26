--!strict
--[[
	Éclairage allée slots — ciel clair / lisible, DoF off (ref-lobby).
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
	-- Jour clair (réf allée)
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(90, 95, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.75
	Lighting.ExposureCompensation = 0.05
	Lighting.FogColor = Color3.fromRGB(180, 195, 220)
	Lighting.FogStart = 220
	Lighting.FogEnd = 900
	Lighting.GeographicLatitude = 25

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.12
	atmo.Offset = 0.35
	atmo.Color = Color3.fromRGB(210, 220, 235)
	atmo.Decay = Color3.fromRGB(120, 140, 180)
	atmo.Glare = 0.08
	atmo.Haze = 0.35

	local sky = ensureChild("Sky", "BC_LobbySky") :: Sky
	sky.CelestialBodiesShown = true
	sky.StarCount = 500
	sky.MoonAngularSize = 8
	sky.SunAngularSize = 18

	local bloom = ensureChild("BloomEffect", "BC_Bloom") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = 0.22
	bloom.Size = 14
	bloom.Threshold = 2.0

	local cc = ensureChild("ColorCorrectionEffect", "BC_LobbyCC") :: ColorCorrectionEffect
	cc.Enabled = true
	cc.Contrast = 0.04
	cc.Saturation = 0.06
	cc.TintColor = Color3.fromRGB(255, 252, 248)
	cc.Brightness = 0.03

	local rays = ensureChild("SunRaysEffect", "BC_SunRays") :: SunRaysEffect
	rays.Enabled = true
	rays.Intensity = 0.06
	rays.Spread = 0.5

	local dof = ensureChild("DepthOfFieldEffect", "BC_LobbyDoF") :: DepthOfFieldEffect
	dof.Enabled = false
	dof.FarIntensity = 0
	dof.NearIntensity = 0
	dof.FocusDistance = 80
	dof.InFocusRadius = 100

	for _, child in Lighting:GetChildren() do
		if child:IsA("DepthOfFieldEffect") and child.Name ~= "BC_LobbyDoF" then
			child.Enabled = false
		end
	end

	Lighting:SetAttribute("BC_LightingMode", "ConcordAlley")
	Lighting:SetAttribute("BC_AccentGold", colors.Gold)
	Lighting:SetAttribute("BC_DoF", false)
	Lighting:SetAttribute("BC_Layout", LobbyConfig.Layout)
end

function LobbyLighting.applyMobileFallback()
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Soft
	end)
	local bloom = Lighting:FindFirstChild("BC_Bloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.15
		bloom.Size = 10
	end
	local dof = Lighting:FindFirstChild("BC_LobbyDoF")
	if dof and dof:IsA("DepthOfFieldEffect") then
		dof.Enabled = false
	end
	local rays = Lighting:FindFirstChild("BC_SunRays")
	if rays and rays:IsA("SunRaysEffect") then
		rays.Intensity = 0.03
	end
	Lighting.FogEnd = 600
	Lighting:SetAttribute("BC_LightingMode", "ConcordAlleyMobile")
end

return LobbyLighting
