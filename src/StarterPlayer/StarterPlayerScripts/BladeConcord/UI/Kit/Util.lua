--!strict
--[[
	Utilitaires UI partagés — coins, strokes, gradients, scale, blur.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local Util = {}

function Util.corner(parent: Instance, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.RadiusCard)
	c.Parent = parent
	return c
end

function Util.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Gold
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.45
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Util.gradient(parent: Instance, sequence: ColorSequence, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = sequence
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function Util.pad(parent: Instance, px: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Util.list(parent: Instance, dir: Enum.FillDirection?, gap: number?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function Util.aspect(parent: Instance, ratio: number): UIAspectRatioConstraint
	local a = Instance.new("UIAspectRatioConstraint")
	a.AspectRatio = ratio
	a.Parent = parent
	return a
end

function Util.glassPanel(parent: Instance, name: string?): Frame
	local f = Instance.new("Frame")
	f.Name = name or "Glass"
	f.BackgroundColor3 = Theme.Ink700
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	f.Parent = parent
	Util.corner(f, Theme.RadiusCard)
	local outer = Util.stroke(f, Theme.Gold, 1.5, 0.55)
	outer.Name = "OuterStroke"
	local inner = Util.stroke(f, Color3.new(1, 1, 1), 1, 0.9)
	inner.Name = "InnerStroke"
	Util.gradient(f, ColorSequence.new(Theme.Ink600, Theme.Ink800), 90)
	return f
end

function Util.bindUiScale(gui: ScreenGui): UIScale
	local scale = Instance.new("UIScale")
	scale.Name = "BC_UIScale"
	scale.Parent = gui
	local cam = workspace.CurrentCamera
	local function refresh()
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = Theme.uiScale(vp)
	end
	refresh()
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end
		refresh()
	end)
	return scale
end

local blurCount = 0
local blurFx: BlurEffect? = nil
local dofFx: DepthOfFieldEffect? = nil

function Util.setMenuBlur(on: boolean)
	if on then
		blurCount += 1
		if blurCount == 1 then
			local existing = Lighting:FindFirstChild("BC_UIBlur")
			if existing and existing:IsA("BlurEffect") then
				blurFx = existing
			else
				local b = Instance.new("BlurEffect")
				b.Name = "BC_UIBlur"
				b.Size = 0
				b.Parent = Lighting
				blurFx = b
			end
			local dofExisting = Lighting:FindFirstChild("BC_UIDoF")
			if dofExisting and dofExisting:IsA("DepthOfFieldEffect") then
				dofFx = dofExisting
			else
				local d = Instance.new("DepthOfFieldEffect")
				d.Name = "BC_UIDoF"
				d.FarIntensity = 0
				d.NearIntensity = 0
				d.FocusDistance = 20
				d.InFocusRadius = 30
				d.Parent = Lighting
				dofFx = d
			end
			if blurFx then
				TweenService:Create(blurFx, TweenInfo.new(0.25), { Size = 12 }):Play()
			end
			if dofFx then
				TweenService:Create(dofFx, TweenInfo.new(0.25), { FarIntensity = 0.6 }):Play()
			end
		end
	else
		blurCount = math.max(0, blurCount - 1)
		if blurCount == 0 then
			if blurFx then
				TweenService:Create(blurFx, TweenInfo.new(0.2), { Size = 0 }):Play()
			end
			if dofFx then
				TweenService:Create(dofFx, TweenInfo.new(0.2), { FarIntensity = 0 }):Play()
			end
		end
	end
end

function Util.tween(inst: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

function Util.formatNumber(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local k
	while true do
		s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1 %2")
		if k == 0 then
			break
		end
	end
	return s
end

function Util.pct(rate: number): string
	local v = rate * 100
	if v == math.floor(v) then
		return string.format("%.0f %%", v)
	end
	-- 2.5 → « 2,5 % »
	local whole = math.floor(v)
	local frac = math.floor((v - whole) * 10 + 0.5)
	if frac == 0 then
		return string.format("%d %%", whole)
	end
	return string.format("%d,%d %%", whole, frac)
end

function Util.safeScreenGui(name: string, order: number, insets: Enum.ScreenInsets?): ScreenGui
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		gui.ScreenInsets = insets or Enum.ScreenInsets.CoreUISafeInsets
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	Util.bindUiScale(gui)
	return gui
end

function Util.focusable(btn: GuiButton)
	pcall(function()
		btn.Selectable = true
	end)
end

function Util.escapeCloses(onClose: () -> ())
	local UIS = game:GetService("UserInputService")
	return UIS.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			onClose()
		end
	end)
end

-- Exposé pour SelectedObject manette
Util.GuiService = GuiService

return Util
