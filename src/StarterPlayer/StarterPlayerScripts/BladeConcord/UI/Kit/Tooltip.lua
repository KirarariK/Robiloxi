--!strict
--[[
	Prompt / tooltip bas-centre — « [E] Jouer — Amical ».
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))

local Tooltip = {}

export type Handle = {
	root: Frame,
	set: (text: string) -> (),
	show: () -> (),
	hide: () -> (),
}

function Tooltip.create(parent: Instance, opts: { position: UDim2? }?): Handle
	local root = Instance.new("Frame")
	root.Name = "PromptTooltip"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = (opts and opts.position) or UDim2.new(0.5, 0, 0.70, 0)
	root.Size = UDim2.fromOffset(280, 36)
	root.BackgroundColor3 = Theme.Ink800
	root.BackgroundTransparency = 0.12
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = parent
	Util.corner(root, Theme.RadiusPill)
	Util.stroke(root, Theme.Focus, 1.2, 0.4)

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	Theme.applyFont(label, "HudSemi")
	label.TextSize = 14
	label.TextColor3 = Theme.Bone
	label.Text = ""
	label.Parent = root

	return {
		root = root,
		set = function(text: string)
			label.Text = text
		end,
		show = function()
			root.Visible = true
			root.BackgroundTransparency = 1
			TweenService:Create(root, TweenInfo.new(0.2), { BackgroundTransparency = 0.12 }):Play()
		end,
		hide = function()
			TweenService:Create(root, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
			task.delay(0.16, function()
				root.Visible = false
			end)
		end,
	}
end

return Tooltip
