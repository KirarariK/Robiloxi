--!strict
--[[
	Rail latéral d'icônes — boutons carrés verre + liseré de catégorie.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))
local Icons = require(script.Parent:WaitForChild("Icons"))

local Rail = {}

export type Item = {
	id: string,
	label: string,
	icon: string,
	accent: Color3,
	badge: string?,
	locked: boolean?,
	soon: boolean?,
	onClick: (() -> ())?,
}

function Rail.create(
	parent: Instance,
	opts: {
		side: "left" | "right",
		items: { Item },
		name: string?,
	}
): Frame
	local n = math.max(1, #opts.items)
	local gap = 10
	local cell = 76 -- cible tactile ≥44px + label
	local railH = n * cell + (n - 1) * gap
	local root = Instance.new("Frame")
	root.Name = opts.name or (if opts.side == "left" then "LeftRail" else "RightRail")
	root.BackgroundTransparency = 1
	root.AnchorPoint = if opts.side == "left" then Vector2.new(0, 0.5) else Vector2.new(1, 0.5)
	root.Position = if opts.side == "left" then UDim2.new(0.012, 0, 0.5, 0) else UDim2.new(0.988, 0, 0.5, 0)
	-- Largeur ~8 % écran ; hauteur calée sur le nombre de boutons (pas de colonne vide)
	root.Size = UDim2.new(0.085, 0, 0, railH)
	root.Parent = parent
	Util.list(root, Enum.FillDirection.Vertical, gap)

	for i, item in opts.items do
		local btn = Instance.new("TextButton")
		btn.Name = item.id
		btn.Size = UDim2.new(1, 0, 0, cell)
		btn.BackgroundColor3 = Theme.Ink700
		btn.BackgroundTransparency = if item.locked or item.soon then 0.35 else 0.12
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.LayoutOrder = i
		btn.Parent = root
		Util.corner(btn, Theme.RadiusCard)
		Util.aspect(btn, 1)
		local st = Util.stroke(btn, item.accent, 1.6, if item.locked then 0.7 else 0.4)
		st.Name = "RailStroke"
		Util.gradient(btn, ColorSequence.new(Theme.Ink600, Theme.Ink800), 90)

		local iconBox = Instance.new("Frame")
		iconBox.BackgroundTransparency = 1
		iconBox.Size = UDim2.new(1, -12, 0, 34)
		iconBox.Position = UDim2.new(0, 6, 0, 8)
		iconBox.Parent = btn
		Icons.compose(iconBox, item.icon, if item.locked then Theme.Muted else item.accent)

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -8, 0, 22)
		label.Position = UDim2.new(0, 4, 1, -26)
		Theme.applyFont(label, "HudSemi")
		label.TextSize = 11
		label.TextColor3 = if item.locked or item.soon then Theme.Muted else Theme.Bone
		label.Text = if item.soon then item.label .. "\n" .. "BIENTÔT" else item.label
		label.TextWrapped = true
		label.Parent = btn

		if item.badge then
			local badge = Instance.new("Frame")
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -4, 0, 4)
			badge.Size = UDim2.fromOffset(18, 18)
			badge.BackgroundColor3 = Theme.Danger
			badge.BorderSizePixel = 0
			badge.ZIndex = 5
			badge.Parent = btn
			Util.corner(badge, 99)
			local bt = Instance.new("TextLabel")
			bt.BackgroundTransparency = 1
			bt.Size = UDim2.fromScale(1, 1)
			bt.Font = Enum.Font.GothamBold
			bt.TextSize = 11
			bt.TextColor3 = Theme.Bone
			bt.Text = item.badge
			bt.ZIndex = 6
			bt.Parent = badge
		end

		if item.locked then
			local lock = Instance.new("TextLabel")
			lock.BackgroundTransparency = 1
			lock.Size = UDim2.fromScale(1, 1)
			lock.Font = Enum.Font.GothamBold
			lock.TextSize = 18
			lock.TextColor3 = Theme.Muted
			lock.Text = "🔒"
			-- Use glyph without emoji preference — geometric lock
			lock.Text = "▣"
			lock.ZIndex = 4
			lock.Parent = btn
		end

		local scale = Instance.new("UIScale")
		scale.Scale = 0.7
		scale.Parent = btn
		btn.BackgroundTransparency = 1
		task.delay((i - 1) * 0.05, function()
			TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
			TweenService:Create(btn, TweenInfo.new(0.35), {
				BackgroundTransparency = if item.locked or item.soon then 0.35 else 0.12,
			}):Play()
		end)

		btn.MouseEnter:Connect(function()
			if item.locked or item.soon then
				return
			end
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
			TweenService:Create(st, TweenInfo.new(0.12), { Transparency = 0.1 }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
			TweenService:Create(st, TweenInfo.new(0.12), { Transparency = 0.4 }):Play()
		end)
		btn.MouseButton1Click:Connect(function()
			if item.locked or item.soon then
				return
			end
			if item.onClick then
				item.onClick()
			end
		end)
		Util.focusable(btn)
	end

	return root
end

return Rail
