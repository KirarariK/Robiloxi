--!strict
--[[
	Lighting cour ouverte — jour, haze faible, DoF off.
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
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(96, 102, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 158, 176)
	Lighting.ColorShift_Top = Color3.fromRGB(180, 196, 220)
	Lighting.ColorShift_Bottom = Color3.fromRGB(70, 74, 88)
	Lighting.EnvironmentDiffuseScale = 0.85
	Lighting.EnvironmentSpecularScale = 0.55
	Lighting.ExposureCompensation = 0.2
	Lighting.FogColor = Color3.fromRGB(168, 186, 210)
	Lighting.FogStart = 500
	Lighting.FogEnd = 2400
	Lighting.GeographicLatitude = 28

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.22
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(190, 206, 224)
	atmo.Decay = Color3.fromRGB(120, 140, 170)
	atmo.Glare = 0.05
	atmo.Haze = 0.08

	local sky = ensureChild("Sky", "BC_LobbySky") :: Sky
	sky.CelestialBodiesShown = true
	sky.StarCount = 0
	sky.MoonAngularSize = 8
	sky.SunAngularSize = 16

	local bloom = ensureChild("BloomEffect", "BC_Bloom") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = 0.16
	bloom.Size = 8
	bloom.Threshold = 1.7

	local cc = ensureChild("ColorCorrectionEffect", "BC_LobbyCC") :: ColorCorrectionEffect
	cc.Enabled = true
	cc.Contrast = 0.06
	cc.Saturation = 0.04
	cc.TintColor = Color3.fromRGB(255, 250, 244)
	cc.Brightness = 0.04

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

	Lighting:SetAttribute("BC_LightingMode", "ConcordCourt")
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
		bloom.Intensity = 0.12
		bloom.Size = 6
	end
	local dof = Lighting:FindFirstChild("BC_LobbyDoF")
	if dof and dof:IsA("DepthOfFieldEffect") then
		dof.Enabled = false
	end
	Lighting.FogEnd = 380
	Lighting:SetAttribute("BC_LightingMode", "ConcordCourtMobile")
end

return LobbyLighting
