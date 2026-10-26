--!strict
--[[
	Carte de rareté — bordure couleur, bandeau, prix / état.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))
local Icons = require(script.Parent:WaitForChild("Icons"))

local RarityCard = {}

-- Un seul RenderStepped partagé pour Prismatique
local prismHooks: { UIGradient } = {}
local prismConn: RBXScriptConnection? = nil

local function ensurePrismSpin()
	if prismConn then
		return
	end
	prismConn = RunService.RenderStepped:Connect(function(dt)
		if #prismHooks == 0 then
			return
		end
		for i = #prismHooks, 1, -1 do
			local g = prismHooks[i]
			if not g.Parent then
				table.remove(prismHooks, i)
			else
				g.Rotation = (g.Rotation + 40 * dt) % 360
			end
		end
	end)
end

function RarityCard.create(
	parent: Instance,
	opts: {
		title: string,
		rarity: string,
		subtitle: string?,
		price: string?,
		state: string?, -- ÉQUIPÉE / POSSÉDÉE / VERROUILLÉE / Disponible
		selected: boolean?,
		layoutOrder: number?,
		size: UDim2?,
		onClick: (() -> ())?,
	}
): Frame
	local rarCol = Theme.rarityColor(opts.rarity)
	local card = Instance.new("TextButton")
	card.Name = "RarityCard"
	card.AutoButtonColor = false
	card.Text = ""
	card.Size = opts.size or UDim2.new(1, 0, 0, 88)
	card.BackgroundColor3 = Theme.Ink800
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.LayoutOrder = opts.layoutOrder or 0
	card.Parent = parent
	Util.corner(card, Theme.RadiusCard)
	local st = Util.stroke(card, if opts.selected then Theme.Gold else rarCol, if opts.selected then 2 else 1.5, 0.25)
	Util.gradient(
		card,
		ColorSequence.new(Color3.new(rarCol.R * 0.25, rarCol.G * 0.25, rarCol.B * 0.3), Theme.Ink900),
		90
	)

	if string.lower(opts.rarity) == "prismatic" or string.lower(opts.rarity) == "prismatique" then
		local g = Instance.new("UIGradient")
		g.Color = Theme.prismaticGradient()
		g.Parent = st
		table.insert(prismHooks, g)
		ensurePrismSpin()
	end

	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.fromOffset(56, 56)
	thumb.Position = UDim2.fromOffset(12, 16)
	thumb.BackgroundColor3 = rarCol
	thumb.BackgroundTransparency = 0.55
	thumb.BorderSizePixel = 0
	thumb.Parent = card
	Util.corner(thumb, 8)
	Icons.compose(thumb, "Forms", rarCol)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(80, 12)
	title.Size = UDim2.new(1, -96, 0, 22)
	Theme.applyFont(title, "Hud")
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Bone
	title.Text = string.upper(opts.title)
	title.Parent = card

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(80, 34)
	sub.Size = UDim2.new(1, -96, 0, 16)
	Theme.applyFont(sub, "Body")
	sub.TextSize = 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Theme.Muted
	sub.Text = opts.subtitle or Theme.rarityLabelFr(opts.rarity)
	sub.Parent = card

	local badge = Instance.new("TextLabel")
	badge.BackgroundColor3 = rarCol
	badge.BackgroundTransparency = 0.15
	badge.Position = UDim2.fromOffset(80, 54)
	badge.Size = UDim2.fromOffset(90, 18)
	Theme.applyFont(badge, "HudSemi")
	badge.TextSize = 11
	badge.TextColor3 = Theme.Ink900
	badge.Text = string.upper(Theme.rarityLabelFr(opts.rarity))
	badge.Parent = card
	Util.corner(badge, 4)

	if opts.state or opts.price then
		local state = Instance.new("TextLabel")
		state.BackgroundTransparency = 1
		state.AnchorPoint = Vector2.new(1, 0.5)
		state.Position = UDim2.new(1, -12, 0.5, 0)
		state.Size = UDim2.fromOffset(88, 28)
		Theme.applyFont(state, "HudSemi")
		state.TextSize = 12
		state.TextColor3 = if opts.state == "ÉQUIPÉE" then Theme.Success else Theme.Gold
		state.Text = opts.state or (opts.price or "")
		state.Parent = card
	end

	if opts.onClick then
		card.MouseButton1Click:Connect(opts.onClick)
	end
	Util.focusable(card)
	return card
end

return RarityCard
