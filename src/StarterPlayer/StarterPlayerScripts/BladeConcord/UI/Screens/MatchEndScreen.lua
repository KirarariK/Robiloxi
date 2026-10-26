--!strict
--[[
	Écran de fin de match — VICTOIRE / DÉFAITE, stats, récompenses, REVANCHE.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Util = Kit.Util
local Button = Kit.Button
local Bar = Kit.Bar
local ViewportPreview = Kit.ViewportPreview

local MatchEndScreen = {}

export type Opts = {
	parent: Instance,
	won: boolean,
	draw: boolean?,
	myWins: number,
	theirWins: number,
	myName: string,
	theirName: string,
	mmrDelta: number?,
	rank: string?,
	faction: string?,
	credits: number?,
	onRematch: () -> (),
	onLobby: () -> (),
	onSpectate: (() -> ())?,
	autoLobbySec: number?,
}

function MatchEndScreen.show(opts: Opts): () -> ()
	local root = Instance.new("CanvasGroup")
	root.Name = "MatchEndScreen"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Ink900
	root.BackgroundTransparency = 0.25
	root.GroupTransparency = 1
	root.BorderSizePixel = 0
	root.ZIndex = 60
	root.Parent = opts.parent
	Util.setMenuBlur(true)

	local titleText = if opts.draw then Strings.Draw elseif opts.won then Strings.Victory else Strings.Defeat
	local titleColor = if opts.won then Theme.Gold elseif opts.draw then Theme.Muted else Color3.fromRGB(140, 160, 190)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.06, 0)
	title.Size = UDim2.new(0.6, 0, 0, 64)
	Theme.applyFont(title, "Display")
	title.TextSize = 56
	title.TextColor3 = titleColor
	title.Text = titleText
	title.TextTransparency = 1
	title.ZIndex = 61
	title.Parent = root
	local ts = Instance.new("UIStroke")
	ts.Color = Theme.Ink900
	ts.Thickness = 2
	ts.Parent = title
	if opts.won then
		Util.gradient(title, Theme.goldGradient(), 0)
	end

	local score = Instance.new("TextLabel")
	score.BackgroundTransparency = 1
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.new(0.5, 0, 0.16, 0)
	score.Size = UDim2.new(0.3, 0, 0, 36)
	Theme.applyFont(score, "Hud")
	score.TextSize = 28
	score.TextColor3 = Theme.Gold
	score.Text = string.format("%d  —  %d", opts.myWins, opts.theirWins)
	score.ZIndex = 61
	score.Parent = root

	if opts.faction == "Dawn" or opts.faction == "Dusk" then
		local fac = Instance.new("TextLabel")
		fac.BackgroundTransparency = 1
		fac.Position = UDim2.new(0.04, 0, 0.06, 0)
		fac.Size = UDim2.new(0.28, 0, 0, 40)
		Theme.applyFont(fac, "HudSemi")
		fac.TextSize = 14
		fac.TextXAlignment = Enum.TextXAlignment.Left
		fac.TextColor3 = if opts.faction == "Dawn" then Theme.Dawn else Theme.Dusk
		fac.Text = (if opts.faction == "Dawn" then Strings.Dawn else Strings.Dusk) .. "\n+15 " .. Strings.WarScore
		fac.ZIndex = 61
		fac.Parent = root
	end

	local function playerCard(name: string, x: number, accent: Color3, stats: { string })
		local card = Util.glassPanel(root, "Card")
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(x, 0, 0.26, 0)
		card.Size = UDim2.new(0.28, 0, 0, 200)
		card.ZIndex = 61
		local st = card:FindFirstChild("OuterStroke") :: UIStroke?
		if st then
			st.Color = accent
		end
		local vp = ViewportPreview.create(card, {
			size = UDim2.new(1, -20, 0, 90),
			position = UDim2.new(0, 10, 0, 8),
			accent = accent,
		})
		vp.root.ZIndex = 62
		local n = Instance.new("TextLabel")
		n.BackgroundTransparency = 1
		n.Position = UDim2.new(0, 12, 0, 100)
		n.Size = UDim2.new(1, -24, 0, 22)
		Theme.applyFont(n, "Hud")
		n.TextSize = 16
		n.TextColor3 = Theme.Bone
		n.Text = name
		n.ZIndex = 62
		n.Parent = card
		for i, line in stats do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.new(0, 12, 0, 120 + (i - 1) * 18)
			l.Size = UDim2.new(1, -24, 0, 16)
			Theme.applyFont(l, "Body")
			l.TextSize = 12
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.TextColor3 = Theme.Muted
			l.Text = line
			l.ZIndex = 62
			l.Parent = card
		end
		return vp
	end

	local vp1 = playerCard(opts.myName, 0.32, if opts.won then Theme.Gold else Theme.Focus, {
		"Parades parfaites : —",
		"Dégâts infligés : —",
		"Précision : —",
	})
	local vp2 = playerCard(opts.theirName, 0.68, Theme.Danger, {
		"Parades parfaites : —",
		"Dégâts infligés : —",
		"Précision : —",
	})

	-- Rank bar
	local rankWrap = Instance.new("Frame")
	rankWrap.BackgroundTransparency = 1
	rankWrap.AnchorPoint = Vector2.new(0.5, 0)
	rankWrap.Position = UDim2.new(0.5, 0, 0.58, 0)
	rankWrap.Size = UDim2.new(0.5, 0, 0, 40)
	rankWrap.ZIndex = 61
	rankWrap.Parent = root
	local rankLbl = Instance.new("TextLabel")
	rankLbl.BackgroundTransparency = 1
	rankLbl.Size = UDim2.new(1, 0, 0, 16)
	Theme.applyFont(rankLbl, "Body")
	rankLbl.TextSize = 12
	rankLbl.TextColor3 = Theme.Muted
	local delta = opts.mmrDelta or (if opts.won then 24 else -16)
	rankLbl.Text = string.format("%s  %+d PC", Theme.rankLabelFr(opts.rank or "Silver"), delta)
	rankLbl.Parent = rankWrap
	local bar = Bar.create(rankWrap, {
		size = UDim2.new(1, 0, 0, 12),
		position = UDim2.new(0, 0, 0, 22),
		color = Theme.Gold,
		gradientTo = Theme.Arcane,
	})
	bar:set(0.3, true)
	task.delay(0.3, function()
		bar:set(0.55)
	end)

	-- Rewards
	local rewards = Instance.new("TextLabel")
	rewards.BackgroundTransparency = 1
	rewards.AnchorPoint = Vector2.new(0.5, 0)
	rewards.Position = UDim2.new(0.5, 0, 0.68, 0)
	rewards.Size = UDim2.new(0.5, 0, 0, 40)
	Theme.applyFont(rewards, "Hud")
	rewards.TextSize = 15
	rewards.TextColor3 = Theme.Gold
	rewards.Text = string.format(
		"%s\n◎ +%d  ·  ◇ +%d",
		Strings.Rewards,
		opts.credits or (if opts.won then 120 else 40),
		if opts.won then 1 else 0
	)
	rewards.ZIndex = 61
	rewards.Parent = root

	local btnRow = Instance.new("Frame")
	btnRow.BackgroundTransparency = 1
	btnRow.AnchorPoint = Vector2.new(0.5, 1)
	btnRow.Position = UDim2.new(0.5, 0, 0.94, 0)
	btnRow.Size = UDim2.new(0.7, 0, 0, 52)
	btnRow.ZIndex = 61
	btnRow.Parent = root
	Util.list(btnRow, Enum.FillDirection.Horizontal, 12)

	local rematchBusy = false
	local rematchCd = CombatConfig.Match.RematchClientCooldown or 1.4
	Button.create({
		parent = btnRow,
		text = Strings.Rematch,
		style = "primary",
		size = UDim2.new(0.32, 0, 0, 48),
		layoutOrder = 1,
		onClick = function()
			if rematchBusy then
				return
			end
			rematchBusy = true
			opts.onRematch()
			task.delay(rematchCd, function()
				rematchBusy = false
			end)
		end,
	})
	Button.create({
		parent = btnRow,
		text = Strings.BackLobby,
		style = "secondary",
		size = UDim2.new(0.32, 0, 0, 48),
		layoutOrder = 2,
		onClick = opts.onLobby,
	})
	Button.create({
		parent = btnRow,
		text = Strings.Spectate,
		style = "ghost",
		size = UDim2.new(0.28, 0, 0, 48),
		layoutOrder = 3,
		onClick = function()
			if opts.onSpectate then
				opts.onSpectate()
			end
		end,
	})

	local autoSec = opts.autoLobbySec or 30
	local autoLbl = Instance.new("TextLabel")
	autoLbl.BackgroundTransparency = 1
	autoLbl.AnchorPoint = Vector2.new(0.5, 1)
	autoLbl.Position = UDim2.new(0.5, 0, 0.98, 0)
	autoLbl.Size = UDim2.new(0.4, 0, 0, 16)
	Theme.applyFont(autoLbl, "Mono")
	autoLbl.TextSize = 11
	autoLbl.TextColor3 = Theme.Muted
	autoLbl.ZIndex = 61
	autoLbl.Parent = root

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Util.setMenuBlur(false)
		TweenService:Create(root, TweenInfo.new(0.2), { GroupTransparency = 1 }):Play()
		task.delay(0.22, function()
			vp1.destroy()
			vp2.destroy()
			root:Destroy()
		end)
	end

	TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
	}):Play()
	TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = 56,
	}):Play()
	title.TextSize = 72

	task.spawn(function()
		for i = autoSec, 0, -1 do
			if closed or not root.Parent then
				return
			end
			autoLbl.Text = string.format("Retour salon dans %ds", i)
			task.wait(1)
		end
		if not closed then
			opts.onLobby()
			close()
		end
	end)

	return close
end

return MatchEndScreen
