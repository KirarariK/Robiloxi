--!strict
--[[
	HUD combat soigné — HP / stamina / score BO3 / CDs Focus / flash feedback.
	Pass 3 : countdown 3-2-1 + versus plaque, vignette faction optionnelle.
	Sprint : copy FR countdown / CONTRE / ALLEZ / REVANCHE + hooks audio.
	Vague 5 : recap manche / mort (plaque score + vignette KO).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))
local SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))

local CombatHud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local hpFill: Frame
local staminaFill: Frame
local flashLabel: TextLabel
local statusLabel: TextLabel
local scoreLabel: TextLabel
local arenaLabel: TextLabel
local cdLabel: TextLabel
local fairKitBadge: Frame
local fairKitTitle: TextLabel
local fairKitSub: TextLabel
local fairKitVisible = false
local vignette: Frame
local factionVignette: Frame
local countdownLabel: TextLabel
local versusPlate: Frame
local versusLeft: TextLabel
local versusRight: TextLabel
local versusVs: TextLabel
local recapPlate: Frame
local recapTitle: TextLabel
local recapScore: TextLabel
local recapSub: TextLabel
local deathVeil: Frame
local lastCountdownCeil: number? = nil
local playerFaction: string? = nil
local lastPhase: string? = nil
local rematchAnnounced = false
local recapToken = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = 0.35
	s.Parent = parent
end

local function makeBar(parent: Instance, name: string, y: number, color: Color3): Frame
	local wrap = Instance.new("Frame")
	wrap.Name = name .. "Wrap"
	wrap.Size = UDim2.new(0.3, 0, 0, 22)
	wrap.Position = UDim2.new(0.02, 0, 0, y)
	wrap.BackgroundColor3 = Theme.InkSoft
	wrap.BackgroundTransparency = 0.15
	wrap.BorderSizePixel = 0
	wrap.Parent = parent
	corner(wrap, 6)
	stroke(wrap, Theme.PanelEdge, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = wrap
	corner(fill, 6)

	local glow = Instance.new("Frame")
	glow.Name = "Sheen"
	glow.Size = UDim2.new(1, 0, 0.35, 0)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = 0.75
	glow.BorderSizePixel = 0
	glow.Parent = fill
	corner(glow, 6)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.Font = Theme.FontBody
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Bone
	label.Text = name
	label.ZIndex = 2
	label.Parent = wrap

	return fill
end

local function resolveFighterName(userId: number?): string
	if not userId then
		return "—"
	end
	if userId == -9001 then
		return "ConcordBot"
	end
	if userId == player.UserId then
		return player.DisplayName ~= "" and player.DisplayName or player.Name
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		return p.DisplayName ~= "" and p.DisplayName or p.Name
	end
	return "Dueliste"
end

local function applyFactionVignette()
	if not factionVignette then
		return
	end
	local color = Theme.Ink
	local alpha = 1
	if playerFaction == "Dawn" then
		color = Theme.Dawn
		alpha = 0.88
	elseif playerFaction == "Dusk" then
		color = Theme.Dusk
		alpha = 0.86
	end
	factionVignette.BackgroundColor3 = color
	-- Edges only : 4 thin frames (optionnelle — invisible si pas de faction)
	for _, child in factionVignette:GetChildren() do
		if child:IsA("Frame") then
			child.BackgroundColor3 = color
			child.BackgroundTransparency = if playerFaction then alpha else 1
		end
	end
end

local function showVersus(leftName: string, rightName: string)
	versusLeft.Text = leftName
	versusRight.Text = rightName
	versusPlate.Visible = true
	versusPlate.BackgroundTransparency = 0.15
	versusLeft.TextTransparency = 0
	versusRight.TextTransparency = 0
	versusVs.TextTransparency = 0
	versusPlate.Size = UDim2.new(0, 0, 0, 88)
	TweenService:Create(versusPlate, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 520, 0, 88),
	}):Play()
end

local function hideVersus()
	TweenService:Create(versusPlate, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 420, 0, 72),
	}):Play()
	TweenService:Create(versusLeft, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	TweenService:Create(versusRight, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	TweenService:Create(versusVs, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	task.delay(0.3, function()
		versusPlate.Visible = false
	end)
end

local function pulseCountdown(n: number)
	countdownLabel.Text = tostring(n)
	countdownLabel.TextTransparency = 0
	countdownLabel.TextStrokeTransparency = 0.25
	countdownLabel.TextSize = 96
	countdownLabel.TextColor3 = if n <= 1 then Theme.AccentHot else Theme.Bone
	TweenService:Create(countdownLabel, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextSize = 64,
		TextTransparency = 0.15,
	}):Play()
	vignette.BackgroundTransparency = 0.78
	TweenService:Create(vignette, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	SoundHooks.play("Countdown")
end

local function flashBanner(text: string, color: Color3)
	flashLabel.Text = text
	flashLabel.TextColor3 = color
	flashLabel.TextTransparency = 0
	flashLabel.TextStrokeTransparency = 0.35
	vignette.BackgroundTransparency = 0.82
	TweenService:Create(flashLabel, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

local function hideRecap()
	recapToken += 1
	if not recapPlate.Visible then
		return
	end
	TweenService:Create(recapPlate, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 280, 0, 72),
	}):Play()
	TweenService:Create(recapTitle, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
	TweenService:Create(recapScore, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
	TweenService:Create(recapSub, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
	TweenService:Create(deathVeil, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	local token = recapToken
	task.delay(0.28, function()
		if token == recapToken then
			recapPlate.Visible = false
		end
	end)
end

local function pulseDeathVeil(lost: boolean)
	if not lost then
		deathVeil.BackgroundTransparency = 1
		return
	end
	deathVeil.BackgroundColor3 = Theme.Danger
	deathVeil.BackgroundTransparency = 0.72
	TweenService:Create(deathVeil, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	vignette.BackgroundTransparency = 0.7
	TweenService:Create(vignette, TweenInfo.new(0.85), { BackgroundTransparency = 1 }):Play()
end

local function showRecap(opts: {
	title: string,
	color: Color3,
	myWins: number,
	theirWins: number,
	matchOver: boolean,
	lost: boolean,
})
	recapToken += 1
	local token = recapToken
	recapTitle.Text = opts.title
	recapTitle.TextColor3 = opts.color
	recapScore.Text = string.format("%d  —  %d", opts.myWins, opts.theirWins)
	if opts.matchOver then
		recapSub.Text = if opts.lost then "Match terminé · revanche auto…" else "Victoire · revanche auto…"
	else
		recapSub.Text = "Prochaine manche…"
	end
	recapPlate.Visible = true
	recapPlate.BackgroundTransparency = 0.55
	recapPlate.Size = UDim2.new(0, 260, 0, 68)
	recapTitle.TextTransparency = 1
	recapScore.TextTransparency = 1
	recapSub.TextTransparency = 1
	TweenService:Create(recapPlate, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.1,
		Size = UDim2.new(0, 340, 0, 96),
	}):Play()
	TweenService:Create(recapTitle, TweenInfo.new(0.28), { TextTransparency = 0 }):Play()
	TweenService:Create(recapScore, TweenInfo.new(0.32), { TextTransparency = 0 }):Play()
	TweenService:Create(recapSub, TweenInfo.new(0.36), { TextTransparency = 0.05 }):Play()
	pulseDeathVeil(opts.lost)
	-- Auto-hide (match over stays a bit longer)
	local hold = if opts.matchOver then 2.6 else 1.9
	task.delay(hold, function()
		if token == recapToken then
			hideRecap()
		end
	end)
end

local function scoreFromPayload(scores: any): (number, number)
	local myWins, theirWins = 0, 0
	if typeof(scores) ~= "table" then
		return myWins, theirWins
	end
	for key, value in scores do
		-- Format scoreboard { { userId, wins }, … } ou map userId → wins
		if typeof(value) == "table" and value.userId ~= nil then
			local uid = value.userId
			local w = if typeof(value.wins) == "number" then value.wins else 0
			if uid == player.UserId then
				myWins = w
			else
				theirWins = w
			end
		elseif typeof(value) == "number" then
			local uid = tonumber(key) or key
			if uid == player.UserId then
				myWins = value
			else
				theirWins = value
			end
		end
	end
	return myWins, theirWins
end

function CombatHud.start()
	local remotes = Remotes.get()
	local metaRemotes = Remotes.getMeta()

	gui = Instance.new("ScreenGui")
	gui.Name = "BladeConcordHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	-- Vignette douce (impacts)
	vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Theme.Ink
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 50
	vignette.Parent = root

	-- Vignette bords faction (Dawn / Dusk) — optionnelle
	factionVignette = Instance.new("Frame")
	factionVignette.Name = "FactionVignette"
	factionVignette.Size = UDim2.fromScale(1, 1)
	factionVignette.BackgroundTransparency = 1
	factionVignette.BorderSizePixel = 0
	factionVignette.ZIndex = 1
	factionVignette.Parent = root
	local edgeSpecs = {
		{ UDim2.new(1, 0, 0, 28), UDim2.fromScale(0, 0) }, -- top
		{ UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 1, -36) }, -- bottom
		{ UDim2.new(0, 22, 1, 0), UDim2.fromScale(0, 0) }, -- left
		{ UDim2.new(0, 22, 1, 0), UDim2.new(1, -22, 0, 0) }, -- right
	}
	for i, spec in edgeSpecs do
		local edge = Instance.new("Frame")
		edge.Name = "Edge" .. i
		edge.Size = spec[1]
		edge.Position = spec[2]
		edge.BackgroundColor3 = Theme.Ink
		edge.BackgroundTransparency = 1
		edge.BorderSizePixel = 0
		edge.ZIndex = 1
		edge.Parent = factionVignette
	end

	local brand = Instance.new("TextLabel")
	brand.Name = "Brand"
	brand.Position = UDim2.new(0.02, 0, 0, 14)
	brand.Size = UDim2.new(0.4, 0, 0, 26)
	brand.BackgroundTransparency = 1
	brand.Font = Theme.FontTitle
	brand.TextSize = 20
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.TextColor3 = Theme.Bone
	brand.Text = Theme.Brand
	brand.Parent = root

	local brandAccent = Instance.new("Frame")
	brandAccent.Size = UDim2.new(0, 48, 0, 3)
	brandAccent.Position = UDim2.new(0.02, 0, 0, 40)
	brandAccent.BackgroundColor3 = Theme.Accent
	brandAccent.BorderSizePixel = 0
	brandAccent.Parent = root
	corner(brandAccent, 2)

	hpFill = makeBar(root, "VITALITÉ", 52, Theme.Danger)
	staminaFill = makeBar(root, "ENDURANCE", 80, Theme.Stamina)

	flashLabel = Instance.new("TextLabel")
	flashLabel.Name = "Flash"
	flashLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	flashLabel.Position = UDim2.fromScale(0.5, 0.38)
	flashLabel.Size = UDim2.new(0.6, 0, 0, 48)
	flashLabel.BackgroundTransparency = 1
	flashLabel.Font = Theme.FontTitle
	flashLabel.TextSize = 34
	flashLabel.TextColor3 = Theme.Perfect
	flashLabel.TextTransparency = 1
	flashLabel.TextStrokeTransparency = 0.5
	flashLabel.Text = ""
	flashLabel.ZIndex = 40
	flashLabel.Parent = root

	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownLabel.Position = UDim2.fromScale(0.5, 0.42)
	countdownLabel.Size = UDim2.new(0.5, 0, 0, 120)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Font = Theme.FontTitle
	countdownLabel.TextSize = 72
	countdownLabel.TextColor3 = Theme.Bone
	countdownLabel.TextTransparency = 1
	countdownLabel.TextStrokeTransparency = 0.4
	countdownLabel.TextStrokeColor3 = Theme.Ink
	countdownLabel.Text = ""
	countdownLabel.ZIndex = 45
	countdownLabel.Parent = root

	-- Versus plaque
	versusPlate = Instance.new("Frame")
	versusPlate.Name = "VersusPlate"
	versusPlate.AnchorPoint = Vector2.new(0.5, 0.5)
	versusPlate.Position = UDim2.fromScale(0.5, 0.28)
	versusPlate.Size = UDim2.new(0, 520, 0, 88)
	versusPlate.BackgroundColor3 = Theme.Panel
	versusPlate.BackgroundTransparency = 0.15
	versusPlate.BorderSizePixel = 0
	versusPlate.Visible = false
	versusPlate.ZIndex = 44
	versusPlate.Parent = root
	corner(versusPlate, 12)
	stroke(versusPlate, Theme.Accent, 1.5)

	versusLeft = Instance.new("TextLabel")
	versusLeft.Name = "Left"
	versusLeft.Size = UDim2.new(0.4, 0, 1, 0)
	versusLeft.Position = UDim2.new(0.02, 0, 0, 0)
	versusLeft.BackgroundTransparency = 1
	versusLeft.Font = Theme.FontTitle
	versusLeft.TextSize = 22
	versusLeft.TextColor3 = Theme.Dawn
	versusLeft.TextXAlignment = Enum.TextXAlignment.Right
	versusLeft.Text = ""
	versusLeft.ZIndex = 45
	versusLeft.Parent = versusPlate

	versusVs = Instance.new("TextLabel")
	versusVs.Name = "Contre"
	versusVs.AnchorPoint = Vector2.new(0.5, 0.5)
	versusVs.Position = UDim2.fromScale(0.5, 0.5)
	versusVs.Size = UDim2.new(0.22, 0, 0.7, 0)
	versusVs.BackgroundColor3 = Theme.InkSoft
	versusVs.BackgroundTransparency = 0.25
	versusVs.Font = Theme.FontTitle
	versusVs.TextSize = 16
	versusVs.TextColor3 = Theme.AccentHot
	versusVs.Text = "CONTRE"
	versusVs.ZIndex = 45
	versusVs.Parent = versusPlate
	corner(versusVs, 8)

	versusRight = Instance.new("TextLabel")
	versusRight.Name = "Right"
	versusRight.Size = UDim2.new(0.4, 0, 1, 0)
	versusRight.Position = UDim2.new(0.58, 0, 0, 0)
	versusRight.BackgroundTransparency = 1
	versusRight.Font = Theme.FontTitle
	versusRight.TextSize = 22
	versusRight.TextColor3 = Theme.Dusk
	versusRight.TextXAlignment = Enum.TextXAlignment.Left
	versusRight.Text = ""
	versusRight.ZIndex = 45
	versusRight.Parent = versusPlate

	-- Veil mort / KO (sous le recap)
	deathVeil = Instance.new("Frame")
	deathVeil.Name = "DeathVeil"
	deathVeil.Size = UDim2.fromScale(1, 1)
	deathVeil.BackgroundColor3 = Theme.Danger
	deathVeil.BackgroundTransparency = 1
	deathVeil.BorderSizePixel = 0
	deathVeil.ZIndex = 48
	deathVeil.Parent = root

	-- Plaque recap manche / match
	recapPlate = Instance.new("Frame")
	recapPlate.Name = "RecapPlate"
	recapPlate.AnchorPoint = Vector2.new(0.5, 0.5)
	recapPlate.Position = UDim2.fromScale(0.5, 0.52)
	recapPlate.Size = UDim2.new(0, 340, 0, 96)
	recapPlate.BackgroundColor3 = Theme.Panel
	recapPlate.BackgroundTransparency = 0.1
	recapPlate.BorderSizePixel = 0
	recapPlate.Visible = false
	recapPlate.ZIndex = 49
	recapPlate.Parent = root
	corner(recapPlate, 12)
	stroke(recapPlate, Theme.PanelEdge, 1.4)

	local recapAccent = Instance.new("Frame")
	recapAccent.Name = "Accent"
	recapAccent.Size = UDim2.new(0, 4, 1, -16)
	recapAccent.Position = UDim2.new(0, 8, 0, 8)
	recapAccent.BackgroundColor3 = Theme.Accent
	recapAccent.BorderSizePixel = 0
	recapAccent.ZIndex = 50
	recapAccent.Parent = recapPlate
	corner(recapAccent, 2)

	recapTitle = Instance.new("TextLabel")
	recapTitle.Name = "Title"
	recapTitle.BackgroundTransparency = 1
	recapTitle.Position = UDim2.new(0, 22, 0, 10)
	recapTitle.Size = UDim2.new(1, -32, 0, 28)
	recapTitle.Font = Theme.FontTitle
	recapTitle.TextSize = 22
	recapTitle.TextXAlignment = Enum.TextXAlignment.Left
	recapTitle.TextColor3 = Theme.Bone
	recapTitle.Text = ""
	recapTitle.ZIndex = 50
	recapTitle.Parent = recapPlate

	recapScore = Instance.new("TextLabel")
	recapScore.Name = "Score"
	recapScore.BackgroundTransparency = 1
	recapScore.Position = UDim2.new(0, 22, 0, 40)
	recapScore.Size = UDim2.new(1, -32, 0, 24)
	recapScore.Font = Theme.FontTitle
	recapScore.TextSize = 20
	recapScore.TextXAlignment = Enum.TextXAlignment.Left
	recapScore.TextColor3 = Theme.Bone
	recapScore.Text = "0  —  0"
	recapScore.ZIndex = 50
	recapScore.Parent = recapPlate

	recapSub = Instance.new("TextLabel")
	recapSub.Name = "Sub"
	recapSub.BackgroundTransparency = 1
	recapSub.Position = UDim2.new(0, 22, 0, 66)
	recapSub.Size = UDim2.new(1, -32, 0, 18)
	recapSub.Font = Theme.FontBody
	recapSub.TextSize = 13
	recapSub.TextXAlignment = Enum.TextXAlignment.Left
	recapSub.TextColor3 = Theme.Muted
	recapSub.Text = ""
	recapSub.ZIndex = 50
	recapSub.Parent = recapPlate

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Position = UDim2.new(0.02, 0, 0, 110)
	statusLabel.Size = UDim2.new(0.48, 0, 0, 18)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Theme.FontMono
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Theme.Muted
	statusLabel.Text = Theme.Brand
	statusLabel.Parent = root

	cdLabel = Instance.new("TextLabel")
	cdLabel.Name = "Cooldowns"
	cdLabel.Position = UDim2.new(0.02, 0, 0, 130)
	cdLabel.Size = UDim2.new(0.55, 0, 0, 16)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Font = Theme.FontMono
	cdLabel.TextSize = 11
	cdLabel.TextXAlignment = Enum.TextXAlignment.Left
	cdLabel.TextColor3 = Theme.Accent
	cdLabel.Text = ""
	cdLabel.Parent = root

	local scorePlate = Instance.new("Frame")
	scorePlate.Name = "ScorePlate"
	scorePlate.AnchorPoint = Vector2.new(0.5, 0)
	scorePlate.Position = UDim2.fromScale(0.5, 0.018)
	scorePlate.Size = UDim2.new(0, 320, 0, 52)
	scorePlate.BackgroundColor3 = Theme.Panel
	scorePlate.BackgroundTransparency = 0.2
	scorePlate.BorderSizePixel = 0
	scorePlate.Parent = root
	corner(scorePlate, 10)
	stroke(scorePlate, Theme.PanelEdge, 1.2)

	scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "Score"
	scoreLabel.Size = UDim2.new(1, 0, 0, 28)
	scoreLabel.Position = UDim2.new(0, 0, 0, 4)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Font = Theme.FontTitle
	scoreLabel.TextSize = 20
	scoreLabel.TextColor3 = Theme.Bone
	scoreLabel.Text = "Amical · Manche 0 · 0 — 0 (FT2)"
	scoreLabel.Parent = scorePlate

	arenaLabel = Instance.new("TextLabel")
	arenaLabel.Name = "Arena"
	arenaLabel.Size = UDim2.new(1, 0, 0, 18)
	arenaLabel.Position = UDim2.new(0, 0, 0, 30)
	arenaLabel.BackgroundTransparency = 1
	arenaLabel.Font = Theme.FontBody
	arenaLabel.TextSize = 12
	arenaLabel.TextColor3 = Theme.Muted
	arenaLabel.Text = ""
	arenaLabel.Parent = scorePlate

	-- Fair Kit Ranked — badge combat visible (titre + sous-label Rare cap)
	fairKitBadge = Instance.new("Frame")
	fairKitBadge.Name = "FairKitBadge"
	fairKitBadge.AnchorPoint = Vector2.new(1, 0)
	fairKitBadge.Position = UDim2.new(0.985, 0, 0, 14)
	fairKitBadge.Size = UDim2.new(0, 168, 0, 44)
	fairKitBadge.BackgroundColor3 = Theme.InkSoft
	fairKitBadge.BackgroundTransparency = 0.08
	fairKitBadge.BorderSizePixel = 0
	fairKitBadge.Visible = false
	fairKitBadge.ZIndex = 25
	fairKitBadge.Parent = root
	corner(fairKitBadge, 8)
	stroke(fairKitBadge, Theme.Success, 2)

	local fairAccent = Instance.new("Frame")
	fairAccent.Name = "AccentBar"
	fairAccent.Size = UDim2.new(0, 4, 1, -10)
	fairAccent.Position = UDim2.new(0, 6, 0, 5)
	fairAccent.BackgroundColor3 = Theme.Success
	fairAccent.BorderSizePixel = 0
	fairAccent.ZIndex = 26
	fairAccent.Parent = fairKitBadge
	corner(fairAccent, 2)

	fairKitTitle = Instance.new("TextLabel")
	fairKitTitle.Name = "Title"
	fairKitTitle.BackgroundTransparency = 1
	fairKitTitle.Position = UDim2.new(0, 16, 0, 4)
	fairKitTitle.Size = UDim2.new(1, -22, 0, 20)
	fairKitTitle.Font = Theme.FontTitle
	fairKitTitle.TextSize = 15
	fairKitTitle.TextXAlignment = Enum.TextXAlignment.Left
	fairKitTitle.TextColor3 = Theme.Success
	fairKitTitle.Text = RankedConfig.FairKitBadge
	fairKitTitle.ZIndex = 26
	fairKitTitle.Parent = fairKitBadge

	fairKitSub = Instance.new("TextLabel")
	fairKitSub.Name = "Sub"
	fairKitSub.BackgroundTransparency = 1
	fairKitSub.Position = UDim2.new(0, 16, 0, 22)
	fairKitSub.Size = UDim2.new(1, -22, 0, 16)
	fairKitSub.Font = Theme.FontMono
	fairKitSub.TextSize = 11
	fairKitSub.TextXAlignment = Enum.TextXAlignment.Left
	fairKitSub.TextColor3 = Theme.Bone
	fairKitSub.Text = RankedConfig.FairKitStatsLabel
	fairKitSub.ZIndex = 26
	fairKitSub.Parent = fairKitBadge

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			if snap.userId == player.UserId then
				local hpFrac = math.clamp(snap.hp / CombatConfig.MaxHp, 0, 1)
				local staFrac = math.clamp(snap.stamina / CombatConfig.Stamina.Max, 0, 1)
				TweenService:Create(hpFill, TweenInfo.new(0.12), { Size = UDim2.new(hpFrac, 0, 1, 0) }):Play()
				TweenService:Create(staminaFill, TweenInfo.new(0.1), { Size = UDim2.new(staFrac, 0, 1, 0) }):Play()
				if snap.flags and snap.flags.exhausted then
					staminaFill.BackgroundColor3 = Theme.Danger
				else
					staminaFill.BackgroundColor3 = Theme.Stamina
				end
				local formBit = ""
				if snap.formId then
					formBit = string.format(" · %s %s", tostring(snap.formId), tostring(snap.formRarity or ""))
				end
				statusLabel.Text = string.format(
					"%d PV · %d END · %s%s",
					math.floor(snap.hp + 0.5),
					math.floor(snap.stamina + 0.5),
					tostring(snap.actionId),
					formBit
				)
				if snap.cooldowns then
					cdLabel.Text = string.format(
						"Esquive %.1fs · Dash %.1fs · Poussée %.1fs · Dash Focus %.1fs",
						snap.cooldowns.dodge or 0,
						snap.cooldowns.dash or 0,
						snap.cooldowns.focusPush or 0,
						snap.cooldowns.focusDash or 0
					)
				end
			end
		end
	end)

	metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local prof = payload.profile
		if typeof(prof) == "table" and typeof(prof.faction) == "string" then
			playerFaction = prof.faction
			applyFactionVignette()
		elseif payload.kind == "Profile" and typeof(payload.profile) == "table" then
			playerFaction = payload.profile.faction
			applyFactionVignette()
		end
	end)

	remotes.MatchState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local myWins, theirWins = 0, 0
		local theirId: number? = nil
		if typeof(payload.scores) == "table" then
			for _, row in payload.scores do
				if row.userId == player.UserId then
					myWins = row.wins or 0
				else
					theirWins = row.wins or 0
					theirId = row.userId
				end
			end
		end
		-- Resolve opponent from fighters list if provided
		if typeof(payload.fighters) == "table" then
			for _, row in payload.fighters do
				if typeof(row) == "table" and row.userId ~= player.UserId then
					theirId = row.userId
				end
			end
		end
		if theirId == nil and typeof(payload.scores) == "table" then
			-- Solo : ConcordBot often in scores as -9001
			for _, row in payload.scores do
				if row.userId == -9001 then
					theirId = -9001
				end
			end
		end

		local modeRaw = tostring(payload.mode or "Casual")
		local modeFr = if modeRaw == "Ranked" then "Classé" else "Amical"
		local roundN = payload.roundNumber or 0
		local ft = payload.firstTo or 2
		scoreLabel.Text = string.format("%s · Manche %d · %d — %d (FT%d)", modeFr, roundN, myWins, theirWins, ft)
		arenaLabel.Text = tostring(payload.arenaName or payload.arenaId or "")
		if payload.fairKit then
			fairKitBadge.Visible = true
			if not fairKitVisible then
				fairKitVisible = true
				fairKitBadge.BackgroundTransparency = 0.35
				fairKitBadge.Size = UDim2.new(0, 140, 0, 36)
				TweenService:Create(fairKitBadge, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.08,
					Size = UDim2.new(0, 168, 0, 44),
				}):Play()
			end
		else
			fairKitVisible = false
			fairKitBadge.Visible = false
		end

		local phase = tostring(payload.phase)
		local arenaBase = tostring(payload.arenaName or payload.arenaId or "")
		if phase == "Lobby" then
			local q = payload.queueCount or 0
			if q > 0 then
				arenaLabel.Text = if arenaBase ~= ""
					then string.format("%s · file d'attente · %d joueur%s", arenaBase, q, if q > 1 then "s" else "")
					else string.format("Salon · file d'attente · %d", q)
			else
				arenaLabel.Text = if arenaBase ~= ""
					then arenaBase .. " · salon · duel auto sous peu"
					else "Salon Concord · en attente d'un adversaire"
			end
			if versusPlate.Visible then
				hideVersus()
			end
			hideRecap()
			countdownLabel.TextTransparency = 1
			lastCountdownCeil = nil
			rematchAnnounced = false
		elseif phase == "Countdown" and payload.countdown then
			local ceilN = math.max(1, math.ceil(payload.countdown))
			arenaLabel.Text = if arenaBase ~= "" then arenaBase .. " · prêt…" else "Prêt…"
			if lastPhase ~= "Countdown" then
				hideRecap()
				local left = resolveFighterName(player.UserId)
				local right = resolveFighterName(theirId or -9001)
				showVersus(left, right)
				lastCountdownCeil = nil
				if lastPhase == "MatchEnd" or rematchAnnounced then
					flashBanner("REVANCHE", Theme.Accent)
					SoundHooks.play("Rematch")
					rematchAnnounced = false
				end
			end
			if lastCountdownCeil ~= ceilN then
				lastCountdownCeil = ceilN
				pulseCountdown(ceilN)
			end
			-- Hide legacy flash during dedicated countdown (sauf bandeau REVANCHE)
			if flashLabel.Text ~= "REVANCHE" then
				flashLabel.TextTransparency = 1
			end
		elseif phase == "Fighting" and lastPhase == "Countdown" then
			hideVersus()
			hideRecap()
			arenaLabel.Text = if arenaBase ~= "" then arenaBase .. " · en duel" else "En duel"
			countdownLabel.Text = "ALLEZ !"
			countdownLabel.TextColor3 = Theme.Accent
			countdownLabel.TextTransparency = 0
			countdownLabel.TextSize = 56
			SoundHooks.play("Fight")
			TweenService:Create(countdownLabel, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 1,
				TextSize = 36,
			}):Play()
			lastCountdownCeil = nil
		elseif phase == "RoundEnd" then
			if versusPlate.Visible then
				hideVersus()
			end
			countdownLabel.TextTransparency = 1
			lastCountdownCeil = nil
			arenaLabel.Text = (if arenaBase ~= "" then arenaBase .. " · " else "") .. "entre deux manches…"
		elseif phase == "MatchEnd" then
			if versusPlate.Visible then
				hideVersus()
			end
			countdownLabel.TextTransparency = 1
			lastCountdownCeil = nil
			arenaLabel.Text = (if arenaBase ~= "" then arenaBase .. " · " else "") .. "match terminé · revanche auto"
			rematchAnnounced = true
		elseif phase ~= "Countdown" then
			if versusPlate.Visible then
				hideVersus()
			end
			countdownLabel.TextTransparency = 1
			lastCountdownCeil = nil
			arenaLabel.Text = arenaBase
		end
		lastPhase = phase
	end)

	remotes.HitResolved.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local involvesMe = payload.attackerUserId == player.UserId or payload.defenderUserId == player.UserId
		if not involvesMe then
			return
		end
		if payload.perfect then
			flashBanner("PARADE PARFAITE", Theme.Perfect)
		elseif payload.riposte then
			flashBanner("RIPOSTE", Theme.AccentHot)
		elseif payload.guardBreak then
			flashBanner("GARDE BRISÉE", Theme.Danger)
		elseif payload.clash then
			flashBanner("CLASH", Theme.Clash)
		elseif payload.dodged then
			flashBanner("ESQUIVE", Theme.Success)
		elseif payload.critical then
			flashBanner("CRITIQUE", Theme.Danger)
		end
	end)

	remotes.RoundEnded.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local myWins, theirWins = scoreFromPayload(payload.scores)
		local matchOver = payload.matchOver == true
		local won = payload.winnerUserId == player.UserId
		local draw = payload.winnerUserId == nil
		local lost = not won and not draw
		local title: string
		local color: Color3
		if matchOver then
			if won then
				title = "CONCORDANCE"
				color = Theme.Success
			else
				title = "DÉFAITE"
				color = Theme.Danger
			end
		elseif won then
			title = "MANCHE GAGNÉE"
			color = Theme.Success
		elseif draw then
			title = "ÉGALITÉ"
			color = Theme.Muted
		else
			title = "MANCHE PERDUE"
			color = Theme.Danger
		end
		-- Flash court + plaque recap (score BO3)
		flashBanner(title, color)
		showRecap({
			title = title,
			color = color,
			myWins = myWins,
			theirWins = theirWins,
			matchOver = matchOver,
			lost = lost,
		})
	end)

	remotes.FxEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "FocusPushParried" then
			flashBanner("POUSSÉE RENVOYÉE", Theme.Focus)
		elseif payload.kind == "FocusPush" then
			flashBanner("POUSSÉE FOCUS", Theme.Focus)
		elseif payload.kind == "FocusDash" then
			flashBanner("DASH FOCUS", Theme.BladeFocus)
		end
	end)
end

return CombatHud
