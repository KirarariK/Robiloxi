--!strict
--[[
	Icônes en glyphes / formes Luau (pas d'upload assets).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))

local Icons = {}

local GLYPHS: { [string]: string } = {
	Shop = "▣",
	Forms = "✦",
	Quests = "☰",
	Codes = "※",
	Ranked = "⚔",
	Factions = "◈",
	Servers = "◉",
	Trade = "⇄",
	Coin = "◎",
	Shard = "◆",
	Crystal = "◇",
	Plus = "+",
	Close = "✕",
	Back = "◀",
	Chevron = "▾",
	Play = "▶",
	Check = "✓",
	Lock = "▣",
	Sword = "†",
	Shield = "⬡",
	Emote = "✶",
	Star = "★",
	Crown = "♛",
	Eye = "◉",
	Home = "⌂",
	Clock = "◷",
	Sun = "☀",
	Moon = "☾",
	Attack = "⚔",
	Guard = "⬡",
	Dodge = "⇢",
	Dash = "⇉",
	Focus = "☾",
	Push = "◎",
}

function Icons.glyph(name: string): string
	return GLYPHS[name] or "•"
end

function Icons.drawGlyph(parent: Instance, name: string, color: Color3?, size: number?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Icon_" .. name
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBold
	Theme.applyFont(t, "Hud")
	t.TextSize = size or 22
	t.TextColor3 = color or Theme.Bone
	t.Text = Icons.glyph(name)
	t.ZIndex = (parent :: GuiObject).ZIndex + 1
	t.Parent = parent
	return t
end

--[[
	Composition géométrique simple (cadre + accent) pour rails.
]]
function Icons.compose(parent: Instance, kind: string, accent: Color3): Frame
	local wrap = Instance.new("Frame")
	wrap.Name = "IconCompose"
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromScale(1, 1)
	wrap.Parent = parent

	if kind == "Shop" then
		local bag = Instance.new("Frame")
		bag.Size = UDim2.fromScale(0.42, 0.48)
		bag.Position = UDim2.fromScale(0.29, 0.28)
		bag.BackgroundColor3 = accent
		bag.BackgroundTransparency = 0.15
		bag.BorderSizePixel = 0
		bag.Parent = wrap
		Util.corner(bag, 4)
		local handle = Instance.new("Frame")
		handle.Size = UDim2.fromScale(0.28, 0.18)
		handle.Position = UDim2.fromScale(0.36, 0.14)
		handle.BackgroundColor3 = accent
		handle.BackgroundTransparency = 0.35
		handle.BorderSizePixel = 0
		handle.Parent = wrap
		Util.corner(handle, 3)
	elseif kind == "Forms" then
		for i = 1, 3 do
			local d = Instance.new("Frame")
			d.Size = UDim2.fromScale(0.22, 0.22)
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Position = UDim2.fromScale(0.5 + (i - 2) * 0.18, 0.5)
			d.BackgroundColor3 = accent
			d.BackgroundTransparency = 0.1 + (i - 1) * 0.15
			d.Rotation = 45
			d.BorderSizePixel = 0
			d.Parent = wrap
			Util.corner(d, 2)
		end
	elseif kind == "Quests" then
		local scroll = Instance.new("Frame")
		scroll.Size = UDim2.fromScale(0.5, 0.58)
		scroll.Position = UDim2.fromScale(0.25, 0.2)
		scroll.BackgroundColor3 = accent
		scroll.BackgroundTransparency = 0.2
		scroll.BorderSizePixel = 0
		scroll.Parent = wrap
		Util.corner(scroll, 3)
		for i = 1, 3 do
			local line = Instance.new("Frame")
			line.Size = UDim2.new(0.7, 0, 0, 2)
			line.Position = UDim2.new(0.15, 0, 0.25 + (i - 1) * 0.22, 0)
			line.BackgroundColor3 = Theme.Ink900
			line.BackgroundTransparency = 0.35
			line.BorderSizePixel = 0
			line.Parent = scroll
		end
	elseif kind == "Codes" then
		local gift = Instance.new("Frame")
		gift.Size = UDim2.fromScale(0.48, 0.42)
		gift.Position = UDim2.fromScale(0.26, 0.34)
		gift.BackgroundColor3 = accent
		gift.BackgroundTransparency = 0.15
		gift.BorderSizePixel = 0
		gift.Parent = wrap
		Util.corner(gift, 4)
		local bow = Instance.new("Frame")
		bow.Size = UDim2.fromScale(0.55, 0.14)
		bow.Position = UDim2.fromScale(0.225, 0.22)
		bow.BackgroundColor3 = Theme.GoldHi
		bow.BorderSizePixel = 0
		bow.Parent = wrap
		Util.corner(bow, 3)
	elseif kind == "Ranked" then
		local a = Instance.new("Frame")
		a.Size = UDim2.fromScale(0.12, 0.55)
		a.Position = UDim2.fromScale(0.32, 0.22)
		a.Rotation = -28
		a.BackgroundColor3 = accent
		a.BorderSizePixel = 0
		a.Parent = wrap
		Util.corner(a, 2)
		local b = Instance.new("Frame")
		b.Size = UDim2.fromScale(0.12, 0.55)
		b.Position = UDim2.fromScale(0.56, 0.22)
		b.Rotation = 28
		b.BackgroundColor3 = Theme.Gold
		b.BorderSizePixel = 0
		b.Parent = wrap
		Util.corner(b, 2)
	elseif kind == "Factions" then
		local shield = Instance.new("Frame")
		shield.Size = UDim2.fromScale(0.46, 0.55)
		shield.Position = UDim2.fromScale(0.27, 0.2)
		shield.BackgroundColor3 = accent
		shield.BackgroundTransparency = 0.1
		shield.BorderSizePixel = 0
		shield.Parent = wrap
		Util.corner(shield, 6)
	elseif kind == "Servers" then
		local c = Instance.new("Frame")
		c.Size = UDim2.fromScale(0.4, 0.4)
		c.Position = UDim2.fromScale(0.3, 0.3)
		c.BackgroundColor3 = accent
		c.BackgroundTransparency = 0.2
		c.BorderSizePixel = 0
		c.Parent = wrap
		Util.corner(c, 99)
		local inner = Instance.new("Frame")
		inner.Size = UDim2.fromScale(0.4, 0.4)
		inner.Position = UDim2.fromScale(0.3, 0.3)
		inner.BackgroundColor3 = Theme.Ink900
		inner.BorderSizePixel = 0
		inner.Parent = c
		Util.corner(inner, 99)
	elseif kind == "Trade" then
		Icons.drawGlyph(wrap, "Trade", accent, 20)
	elseif kind == "Coin" then
		local coin = Instance.new("Frame")
		coin.Size = UDim2.fromScale(0.72, 0.72)
		coin.Position = UDim2.fromScale(0.14, 0.14)
		coin.BackgroundColor3 = Theme.Gold
		coin.BorderSizePixel = 0
		coin.Parent = wrap
		Util.corner(coin, 99)
		Util.gradient(coin, Theme.goldGradient(), 90)
		local mark = Instance.new("TextLabel")
		mark.BackgroundTransparency = 1
		mark.Size = UDim2.fromScale(1, 1)
		mark.Font = Enum.Font.GothamBold
		mark.TextSize = 14
		mark.TextColor3 = Theme.Ink900
		mark.Text = "¤"
		mark.Parent = coin
	elseif kind == "Shard" then
		local gem = Instance.new("Frame")
		gem.Size = UDim2.fromScale(0.42, 0.55)
		gem.Position = UDim2.fromScale(0.29, 0.2)
		gem.Rotation = 45
		gem.BackgroundColor3 = Theme.Focus
		gem.BorderSizePixel = 0
		gem.Parent = wrap
		Util.corner(gem, 3)
		Util.gradient(gem, ColorSequence.new(Theme.Focus, Theme.Arcane), 45)
	else
		Icons.drawGlyph(wrap, kind, accent, 20)
	end

	return wrap
end

return Icons
