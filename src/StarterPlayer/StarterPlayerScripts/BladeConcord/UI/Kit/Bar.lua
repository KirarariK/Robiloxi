--!strict
--[[
	Barres vie / stamina / pity — fill + barre fantôme.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))

local Bar = {}

export type BarHandle = {
	root: Frame,
	set: (self: BarHandle, frac: number, instant: boolean?) -> (),
	setColor: (self: BarHandle, color: Color3) -> (),
	setLabel: (self: BarHandle, text: string) -> (),
}

function Bar.create(
	parent: Instance,
	opts: {
		name: string?,
		size: UDim2?,
		position: UDim2?,
		anchor: Vector2?,
		color: Color3?,
		gradientTo: Color3?,
		label: string?,
		height: number?,
		slanted: boolean?,
	}
): BarHandle
	local h = opts.height or 14
	local root = Instance.new("Frame")
	root.Name = opts.name or "Bar"
	root.BackgroundColor3 = Theme.Ink900
	root.BackgroundTransparency = 0.2
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Size = opts.size or UDim2.new(0.24, 0, 0, h)
	if opts.position then
		root.Position = opts.position
	end
	if opts.anchor then
		root.AnchorPoint = opts.anchor
	end
	root.Parent = parent
	Util.corner(root, 5)
	Util.stroke(root, Theme.PanelEdge, 1, 0.55)

	local ghost = Instance.new("Frame")
	ghost.Name = "Ghost"
	ghost.Size = UDim2.fromScale(1, 1)
	ghost.BackgroundColor3 = Color3.new(1, 1, 1)
	ghost.BackgroundTransparency = 0.72
	ghost.BorderSizePixel = 0
	ghost.Parent = root
	Util.corner(ghost, 5)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = opts.color or Theme.Accent
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = root
	Util.corner(fill, 5)
	if opts.gradientTo then
		Util.gradient(fill, ColorSequence.new(opts.color or Theme.Accent, opts.gradientTo), 0)
	else
		Util.gradient(
			fill,
			ColorSequence.new(
				opts.color or Theme.Accent,
				Color3.new(
					math.clamp((opts.color or Theme.Accent).R * 0.7, 0, 1),
					math.clamp((opts.color or Theme.Accent).G * 0.85, 0, 1),
					math.clamp((opts.color or Theme.Accent).B * 1.05, 0, 1)
				)
			),
			0
		)
	end

	local sheen = Instance.new("Frame")
	sheen.Size = UDim2.new(1, 0, 0.4, 0)
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = 0.78
	sheen.BorderSizePixel = 0
	sheen.ZIndex = 3
	sheen.Parent = fill

	local label: TextLabel? = nil
	if opts.label then
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Position = UDim2.fromOffset(8, 0)
		l.Font = Enum.Font.GothamMedium
		Theme.applyFont(l, "HudSemi")
		l.TextSize = 11
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Theme.Bone
		l.Text = opts.label
		l.ZIndex = 4
		l.Parent = root
		label = l
	end

	local handle: BarHandle
	handle = {
		root = root,
		set = function(_self, frac: number, instant: boolean?)
			local f = math.clamp(frac, 0, 1)
			local target = UDim2.fromScale(f, 1)
			if instant then
				fill.Size = target
				ghost.Size = target
			else
				TweenService:Create(fill, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = target }):Play()
				TweenService:Create(ghost, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = target,
				}):Play()
			end
		end,
		setColor = function(_self, color: Color3)
			fill.BackgroundColor3 = color
		end,
		setLabel = function(_self, text: string)
			if label then
				label.Text = text
			end
		end,
	}
	return handle
end

function Bar.pity(parent: Instance, label: string, current: number, maxN: number, color: Color3, y: number?): Frame
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.new(1, 0, 0, 28)
	if y then
		wrap.Position = UDim2.new(0, 0, 0, y)
	end
	wrap.Parent = parent

	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 0, 14)
	Theme.applyFont(caption, "Body")
	caption.TextSize = 12
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextColor3 = Theme.Muted
	caption.Text = string.format("%s : %d/%d", label, current, maxN)
	caption.Parent = wrap

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.new(0, 0, 0, 16)
	track.BackgroundColor3 = Theme.Ink900
	track.BorderSizePixel = 0
	track.Parent = wrap
	Util.corner(track, 4)

	local fill = Instance.new("Frame")
	local pct = if maxN > 0 then math.clamp(current / maxN, 0, 1) else 0
	fill.Size = UDim2.fromScale(pct, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = track
	Util.corner(fill, 4)
	Util.gradient(fill, ColorSequence.new(color, Theme.GoldHi), 0)

	return wrap
end

function Bar.rarityPill(
	parent: Instance,
	name: string,
	pctText: string,
	color: Color3,
	order: number,
	onDetails: (() -> ())?
): Frame
	local pill = Instance.new("Frame")
	pill.Name = "Rarity_" .. name
	pill.Size = UDim2.new(1, 0, 0, 40)
	pill.BackgroundColor3 = Theme.Ink800
	pill.BackgroundTransparency = 0.1
	pill.BorderSizePixel = 0
	pill.LayoutOrder = order
	pill.Parent = parent
	Util.corner(pill, Theme.RadiusPill)
	local st = Util.stroke(pill, color, 1.5, 0.25)
	st.Name = "RarityStroke"

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BackgroundTransparency = 0.72
	fill.BorderSizePixel = 0
	fill.Parent = pill
	Util.corner(fill, Theme.RadiusPill)
	Util.gradient(fill, ColorSequence.new(color, Color3.new(color.R * 0.4, color.G * 0.4, color.B * 0.5)), 0)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -36, 1, 0)
	label.Position = UDim2.fromOffset(14, 0)
	Theme.applyFont(label, "HudSemi")
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Bone
	label.Text = string.format("%s  (%s)", name, pctText)
	label.ZIndex = 2
	label.Parent = pill

	local chev = Instance.new("TextButton")
	chev.BackgroundTransparency = 1
	chev.Size = UDim2.fromOffset(36, 40)
	chev.Position = UDim2.new(1, -36, 0, 0)
	chev.Text = "▾"
	chev.TextColor3 = Theme.Muted
	chev.TextSize = 14
	chev.Font = Enum.Font.GothamBold
	chev.ZIndex = 3
	chev.Parent = pill
	if onDetails then
		chev.MouseButton1Click:Connect(onDetails)
		pill.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				onDetails()
			end
		end)
	end

	return pill
end

return Bar
