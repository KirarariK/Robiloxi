--!strict
--[[
	Lighting croiseur — Future / Realistic, néons-métaux, DoF off.
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

	-- Future lighting (Technology peut être read-only selon client)
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Realistic;
		(Lighting :: any).PrioritizeLightingQuality = Enum.PrioritizeLightingQuality.Enabled
	end)

	Lighting.GlobalShadows = true
	Lighting.ClockTime = 0.5 -- nuit/espace extérieur visible via baie
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(28, 32, 48)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 48, 72)
	Lighting.ColorShift_Top = Color3.fromRGB(80, 100, 160)
	Lighting.ColorShift_Bottom = Color3.fromRGB(20, 18, 30)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 1.0
	Lighting.ExposureCompensation = 0.1
	Lighting.FogColor = Color3.fromRGB(18, 22, 40)
	Lighting.FogStart = 80
	Lighting.FogEnd = 520
	Lighting.GeographicLatitude = 10

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.18
	atmo.Offset = 0.22
	atmo.Color = Color3.fromRGB(90, 100, 150)
	atmo.Decay = Color3.fromRGB(20, 16, 40)
	atmo.Glare = 0.15
	atmo.Haze = 0.8

	local sky = ensureChild("Sky", "BC_LobbySky") :: Sky
	sky.CelestialBodiesShown = true
	sky.StarCount = 5000
	sky.MoonAngularSize = 14
	sky.SunAngularSize = 8

	local bloom = ensureChild("BloomEffect", "BC_Bloom") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = 0.45
	bloom.Size = 22
	bloom.Threshold = 1.35 -- néons Metal/Neon lisibles

	local cc = ensureChild("ColorCorrectionEffect", "BC_LobbyCC") :: ColorCorrectionEffect
	cc.Enabled = true
	cc.Contrast = 0.1
	cc.Saturation = 0.08
	cc.TintColor = Color3.fromRGB(230, 235, 255)
	cc.Brightness = 0.02

	local rays = ensureChild("SunRaysEffect", "BC_SunRays") :: SunRaysEffect
	rays.Enabled = false

	local dof = ensureChild("DepthOfFieldEffect", "BC_LobbyDoF") :: DepthOfFieldEffect
	dof.Enabled = false
	dof.FarIntensity = 0
	dof.NearIntensity = 0

	for _, child in Lighting:GetChildren() do
		if child:IsA("DepthOfFieldEffect") and child.Name ~= "BC_LobbyDoF" then
			child.Enabled = false
		end
	end

	Lighting:SetAttribute("BC_LightingMode", "ConcordCruiser")
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
		bloom.Intensity = 0.28
		bloom.Size = 14
	end
	local dof = Lighting:FindFirstChild("BC_LobbyDoF")
	if dof and dof:IsA("DepthOfFieldEffect") then
		dof.Enabled = false
	end
	Lighting.FogEnd = 380
	Lighting:SetAttribute("BC_LightingMode", "ConcordCruiserMobile")
end

return LobbyLighting
