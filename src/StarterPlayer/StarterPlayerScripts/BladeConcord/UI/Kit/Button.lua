--!strict
--[[
	Bouton premium — gradient + UIStroke + hover/press tween + son.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))

local Button = {}

export type Style = "primary" | "secondary" | "danger" | "ghost" | "arcane"

export type Opts = {
	text: string,
	style: Style?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	minTouch: boolean?,
	layoutOrder: number?,
	onClick: (() -> ())?,
	parent: Instance,
	name: string?,
	textSize: number?,
}

local SoundHooks: any = nil
local function playUi()
	if SoundHooks == nil then
		pcall(function()
			SoundHooks = require(script.Parent.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))
		end)
		if SoundHooks == nil then
			SoundHooks = false
		end
	end
	if SoundHooks then
		SoundHooks.play("Ui")
	end
end

local function applyStyle(btn: TextButton, style: Style)
	btn:ClearAllChildren()
	Util.corner(btn, Theme.RadiusButton)
	local stroke = Util.stroke(btn, Theme.GoldDark, 2, 0.25)
	stroke.Name = "BtnStroke"

	if style == "primary" then
		btn.BackgroundColor3 = Theme.Gold
		btn.TextColor3 = Theme.Ink900
		Util.gradient(btn, Theme.goldGradient(), 90)
		-- Reflet animé
		local sheen = Instance.new("Frame")
		sheen.Name = "Sheen"
		sheen.Size = UDim2.new(0.35, 0, 1.4, 0)
		sheen.Position = UDim2.new(-0.4, 0, -0.2, 0)
		sheen.BackgroundColor3 = Color3.new(1, 1, 1)
		sheen.BackgroundTransparency = 0.75
		sheen.BorderSizePixel = 0
		sheen.ZIndex = btn.ZIndex + 1
		sheen.Parent = btn
		Util.corner(sheen, 4)
		task.spawn(function()
			while sheen.Parent do
				sheen.Position = UDim2.new(-0.5, 0, -0.2, 0)
				local tw = TweenService:Create(sheen, TweenInfo.new(1.1, Enum.EasingStyle.Sine), {
					Position = UDim2.new(1.1, 0, -0.2, 0),
				})
				tw:Play()
				tw.Completed:Wait()
				task.wait(2.8)
			end
		end)
	elseif style == "danger" then
		btn.BackgroundColor3 = Theme.Danger
		btn.TextColor3 = Theme.Bone
		Util.gradient(btn, ColorSequence.new(Color3.fromRGB(120, 24, 36), Theme.Danger), 90)
		stroke.Color = Color3.fromRGB(90, 20, 28)
	elseif style == "arcane" then
		btn.BackgroundColor3 = Theme.Arcane
		btn.TextColor3 = Theme.Bone
		Util.gradient(btn, ColorSequence.new(Theme.Arcane, Theme.Gold), 90)
		stroke.Color = Theme.Gold
		stroke.Transparency = 0.35
	elseif style == "ghost" then
		btn.BackgroundColor3 = Theme.Ink700
		btn.BackgroundTransparency = 0.35
		btn.TextColor3 = Theme.Bone
		stroke.Color = Theme.PanelEdge
		stroke.Transparency = 0.55
	else -- secondary / verre
		btn.BackgroundColor3 = Theme.Ink700
		btn.BackgroundTransparency = 0.12
		btn.TextColor3 = Theme.Bone
		Util.gradient(btn, ColorSequence.new(Theme.Ink600, Theme.Ink800), 90)
		stroke.Color = Theme.Gold
		stroke.Transparency = 0.55
	end
end

function Button.create(opts: Opts): TextButton
	local style: Style = opts.style or "primary"
	local btn = Instance.new("TextButton")
	btn.Name = opts.name or "BC_Button"
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Text = opts.text
	btn.TextSize = opts.textSize or 16
	Theme.applyFont(btn, "Hud")
	btn.Size = opts.size or UDim2.fromOffset(160, Theme.TouchMin)
	if opts.minTouch ~= false then
		local min = Theme.TouchMin
		if btn.Size.Y.Offset > 0 and btn.Size.Y.Offset < min then
			btn.Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset, btn.Size.Y.Scale, min)
		end
	end
	if opts.position then
		btn.Position = opts.position
	end
	if opts.anchor then
		btn.AnchorPoint = opts.anchor
	end
	if opts.layoutOrder then
		btn.LayoutOrder = opts.layoutOrder
	end
	btn.Parent = opts.parent
	applyStyle(btn, style)
	Util.focusable(btn)

	local baseScale = Instance.new("UIScale")
	baseScale.Scale = 1
	baseScale.Parent = btn
	local stroke = btn:FindFirstChild("BtnStroke") :: UIStroke?
	local accentHover = if style == "primary"
		then Theme.GoldHi
		elseif style == "danger" then Theme.Danger
		elseif style == "arcane" then Theme.Focus
		else Theme.Focus

	btn.MouseEnter:Connect(function()
		TweenService:Create(baseScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.05,
		}):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.12), { Color = accentHover, Transparency = 0.15 }):Play()
		end
		playUi()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(baseScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		if stroke then
			local c = if style == "primary"
				then Theme.GoldDark
				elseif style == "danger" then Color3.fromRGB(90, 20, 28)
				elseif style == "arcane" then Theme.Gold
				else Theme.Gold
			TweenService:Create(stroke, TweenInfo.new(0.12), { Color = c, Transparency = 0.35 }):Play()
		end
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(baseScale, TweenInfo.new(0.06), { Scale = 0.96 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(baseScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.05,
		}):Play()
	end)
	btn.MouseButton1Click:Connect(function()
		playUi()
		if opts.onClick then
			opts.onClick()
		end
	end)

	return btn
end

function Button.setEnabled(btn: TextButton, enabled: boolean)
	btn.Active = enabled
	btn.AutoButtonColor = false
	btn.TextTransparency = if enabled then 0 else 0.45
	btn.BackgroundTransparency = if enabled
		then btn.BackgroundTransparency
		else math.max(btn.BackgroundTransparency, 0.45)
end

function Button.setText(btn: TextButton, text: string)
	btn.Text = text
end

return Button
