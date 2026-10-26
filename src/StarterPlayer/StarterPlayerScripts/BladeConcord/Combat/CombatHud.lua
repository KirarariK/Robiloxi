--!strict
--[[
	HUD combat premium — plaque versus, barres fantômes, Focus, feedback, fin de match.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))
local SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local Strings = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Strings"))
local MatchEndScreen =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Screens"):WaitForChild("MatchEndScreen"))
local Util = Kit.Util
local Bar = Kit.Bar
local Button = Kit.Button

local CombatHud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local root: Frame
local combatChrome: Frame
local hpBar: Bar.BarHandle
local staBar: Bar.BarHandle
local oppHpBar: Bar.BarHandle?
local oppStaBar: Bar.BarHandle?
local flashLabel: TextLabel
local countdownLabel: TextLabel
local scoreLabel: TextLabel
local roundLabel: TextLabel
local timerLabel: TextLabel
local arenaLabel: TextLabel
local nameLeft: TextLabel
local nameRight: TextLabel
local fairKitBadge: Frame
local vignette: Frame
local factionVignette: Frame
local versusPlate: Frame
local versusLeft: TextLabel
local versusRight: TextLabel
local versusVs: TextLabel
local focusRing: Frame
local focusFill: Frame
local exhaustLabel: TextLabel
local lastCountdownCeil: number? = nil
local playerFaction: string? = nil
local lastPhase: string? = nil
local rematchAnnounced = false
local closeMatchEnd: (() -> ())? = nil
local myWinsCached = 0
local theirWinsCached = 0
local profileRank: string? = nil

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
	versusPlate.BackgroundTransparency = 0.1
	versusLeft.TextTransparency = 0
	versusRight.TextTransparency = 0
	versusVs.TextTransparency = 0
	versusPlate.Size = UDim2.new(0, 0, 0, 88)
	TweenService:Create(versusPlate, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 560, 0, 88),
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
	flashLabel.TextSize = 42
	TweenService:Create(flashLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = 34,
	}):Play()
	vignette.BackgroundTransparency = 0.82
	TweenService:Create(flashLabel, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end

local function setCombatChromeVisible(visible: boolean)
	combatChrome.Visible = visible
end

local function scoreFromPayload(scores: any): (number, number)
	local myWins, theirWins = 0, 0
	if typeof(scores) ~= "table" then
		return myWins, theirWins
	end
	for key, value in scores do
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

local function makeRoundDots(parent: Instance): Frame
	local wrap = Instance.new("Frame")
	wrap.Name = "RoundDots"
	wrap.AnchorPoint = Vector2.new(0.5, 0)
	wrap.Position = UDim2.new(0.5, 0, 0, 36)
	wrap.Size = UDim2.fromOffset(80, 10)
	wrap.BackgroundTransparency = 1
	wrap.Parent = parent
	Util.list(wrap, Enum.FillDirection.Horizontal, 6)
	for i = 1, 3 do
		local d = Instance.new("Frame")
		d.Name = "D" .. i
		d.Size = UDim2.fromOffset(10, 10)
		d.BackgroundColor3 = Theme.Ink600
		d.BorderSizePixel = 0
		d.LayoutOrder = i
		d.Parent = wrap
		Util.corner(d, 99)
	end
	return wrap
end

local roundDots: Frame

local function updateDots(my: number, their: number)
	if not roundDots then
		return
	end
	local kids = roundDots:GetChildren()
	local idx = 0
	for _, ch in kids do
		if ch:IsA("Frame") then
			idx += 1
			if idx <= my then
				ch.BackgroundColor3 = Theme.Focus
			elseif idx <= my + their then
				ch.BackgroundColor3 = Theme.Danger
			else
				ch.BackgroundColor3 = Theme.Ink600
			end
		end
	end
end

function CombatHud.start()
	local remotes = Remotes.get()
	local metaRemotes = Remotes.getMeta()

	gui = Util.safeScreenGui("BladeConcordHud", 20, Enum.ScreenInsets.DeviceSafeInsets)
	-- Interactive bits still need CoreUI — nested ScreenGui not needed; padding handles it
	Util.pad(gui, 0)

	root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = root

	combatChrome = Instance.new("Frame")
	combatChrome.Name = "CombatChrome"
	combatChrome.BackgroundTransparency = 1
	combatChrome.Size = UDim2.fromScale(1, 1)
	combatChrome.Visible = false
	combatChrome.Parent = root

	vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Theme.Ink
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 50
	vignette.Parent = root

	factionVignette = Instance.new("Frame")
	factionVignette.Name = "FactionVignette"
	factionVignette.Size = UDim2.fromScale(1, 1)
	factionVignette.BackgroundTransparency = 1
	factionVignette.BorderSizePixel = 0
	factionVignette.ZIndex = 1
	factionVignette.Parent = root
	for i, spec in
		{
			{ UDim2.new(1, 0, 0, 28), UDim2.fromScale(0, 0) },
			{ UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 1, -36) },
			{ UDim2.new(0, 22, 1, 0), UDim2.fromScale(0, 0) },
			{ UDim2.new(0, 22, 1, 0), UDim2.new(1, -22, 0, 0) },
		}
	do
		local edge = Instance.new("Frame")
		edge.Name = "Edge" .. i
		edge.Size = spec[1]
		edge.Position = spec[2]
		edge.BackgroundTransparency = 1
		edge.BorderSizePixel = 0
		edge.Parent = factionVignette
	end

	-- Versus plate (top HUD)
	local plate = Util.glassPanel(combatChrome, "VersusHUD")
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.new(0.5, 0, 0.02, 0)
	plate.Size = UDim2.new(0.62, 0, 0, 78)

	nameLeft = Instance.new("TextLabel")
	nameLeft.BackgroundTransparency = 1
	nameLeft.Position = UDim2.new(0.02, 0, 0, 6)
	nameLeft.Size = UDim2.new(0.28, 0, 0, 18)
	Theme.applyFont(nameLeft, "Hud")
	nameLeft.TextSize = 14
	nameLeft.TextXAlignment = Enum.TextXAlignment.Left
	nameLeft.TextColor3 = Theme.Focus
	nameLeft.Text = player.DisplayName
	nameLeft.Parent = plate

	nameRight = Instance.new("TextLabel")
	nameRight.BackgroundTransparency = 1
	nameRight.Position = UDim2.new(0.7, 0, 0, 6)
	nameRight.Size = UDim2.new(0.28, 0, 0, 18)
	Theme.applyFont(nameRight, "Hud")
	nameRight.TextSize = 14
	nameRight.TextXAlignment = Enum.TextXAlignment.Right
	nameRight.TextColor3 = Theme.Danger
	nameRight.Text = "—"
	nameRight.Parent = plate

	hpBar = Bar.create(plate, {
		name = "HP",
		size = UDim2.new(0.28, 0, 0, 14),
		position = UDim2.new(0.02, 0, 0, 28),
		color = Theme.Focus,
		gradientTo = Color3.fromRGB(40, 200, 180),
	})
	staBar = Bar.create(plate, {
		name = "STA",
		size = UDim2.new(0.28, 0, 0, 8),
		position = UDim2.new(0.02, 0, 0, 46),
		color = Theme.Stamina,
		height = 8,
	})

	oppHpBar = Bar.create(plate, {
		name = "OppHP",
		size = UDim2.new(0.28, 0, 0, 14),
		position = UDim2.new(0.7, 0, 0, 28),
		color = Theme.Danger,
		gradientTo = Theme.AccentHot,
	})
	oppStaBar = Bar.create(plate, {
		name = "OppSTA",
		size = UDim2.new(0.28, 0, 0, 8),
		position = UDim2.new(0.7, 0, 0, 46),
		color = Theme.Stamina,
		height = 8,
	})

	scoreLabel = Instance.new("TextLabel")
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.AnchorPoint = Vector2.new(0.5, 0)
	scoreLabel.Position = UDim2.new(0.5, 0, 0, 4)
	scoreLabel.Size = UDim2.new(0.2, 0, 0, 24)
	Theme.applyFont(scoreLabel, "Hud")
	scoreLabel.TextSize = 22
	scoreLabel.TextColor3 = Theme.Bone
	scoreLabel.Text = "0 — 0"
	scoreLabel.Parent = plate

	roundDots = makeRoundDots(plate)

	roundLabel = Instance.new("TextLabel")
	roundLabel.BackgroundTransparency = 1
	roundLabel.AnchorPoint = Vector2.new(0.5, 0)
	roundLabel.Position = UDim2.new(0.5, 0, 0, 48)
	roundLabel.Size = UDim2.new(0.25, 0, 0, 14)
	Theme.applyFont(roundLabel, "HudSemi")
	roundLabel.TextSize = 11
	roundLabel.TextColor3 = Theme.Muted
	roundLabel.Text = Strings.Round .. " 1"
	roundLabel.Parent = plate

	timerLabel = Instance.new("TextLabel")
	timerLabel.BackgroundTransparency = 1
	timerLabel.AnchorPoint = Vector2.new(0.5, 0)
	timerLabel.Position = UDim2.new(0.5, 0, 0, 60)
	timerLabel.Size = UDim2.new(0.2, 0, 0, 14)
	Theme.applyFont(timerLabel, "Mono")
	timerLabel.TextSize = 12
	timerLabel.TextColor3 = Theme.Gold
	timerLabel.Text = ""
	timerLabel.Parent = plate

	arenaLabel = Instance.new("TextLabel")
	arenaLabel.BackgroundTransparency = 1
	arenaLabel.Position = UDim2.new(0.02, 0, 0, 90)
	arenaLabel.Size = UDim2.new(0.4, 0, 0, 14)
	Theme.applyFont(arenaLabel, "Body")
	arenaLabel.TextSize = 11
	arenaLabel.TextXAlignment = Enum.TextXAlignment.Left
	arenaLabel.TextColor3 = Theme.Muted
	arenaLabel.Text = ""
	arenaLabel.Parent = combatChrome

	-- Fair kit
	fairKitBadge = Util.glassPanel(combatChrome, "FairKit")
	fairKitBadge.AnchorPoint = Vector2.new(1, 0)
	fairKitBadge.Position = UDim2.new(0.99, 0, 0.02, 0)
	fairKitBadge.Size = UDim2.fromOffset(150, 44)
	fairKitBadge.Visible = false
	local fairT = Instance.new("TextLabel")
	fairT.BackgroundTransparency = 1
	fairT.Size = UDim2.fromScale(1, 1)
	Theme.applyFont(fairT, "HudSemi")
	fairT.TextSize = 12
	fairT.TextColor3 = Theme.Success
	fairT.Text = RankedConfig.FairKitBadge .. "\n" .. Strings.FairKitStats
	fairT.Parent = fairKitBadge

	-- Focus orb bottom center
	focusRing = Instance.new("Frame")
	focusRing.Name = "FocusRing"
	focusRing.AnchorPoint = Vector2.new(0.5, 1)
	focusRing.Position = UDim2.new(0.5, 0, 0.95, 0)
	focusRing.Size = UDim2.fromOffset(72, 72)
	focusRing.BackgroundColor3 = Theme.Ink800
	focusRing.BorderSizePixel = 0
	focusRing.Parent = combatChrome
	Util.corner(focusRing, 99)
	Util.stroke(focusRing, Theme.Arcane, 3, 0.25)
	focusFill = Instance.new("Frame")
	focusFill.Size = UDim2.fromScale(0.7, 0.7)
	focusFill.Position = UDim2.fromScale(0.15, 0.15)
	focusFill.BackgroundColor3 = Theme.Arcane
	focusFill.BackgroundTransparency = 0.35
	focusFill.BorderSizePixel = 0
	focusFill.Parent = focusRing
	Util.corner(focusFill, 99)
	local focusLbl = Instance.new("TextLabel")
	focusLbl.BackgroundTransparency = 1
	focusLbl.Size = UDim2.fromScale(1, 1)
	Theme.applyFont(focusLbl, "HudSemi")
	focusLbl.TextSize = 11
	focusLbl.TextColor3 = Theme.Bone
	focusLbl.Text = "FOCUS"
	focusLbl.ZIndex = 2
	focusLbl.Parent = focusRing

	-- Side labels push/dash
	local pushL = Instance.new("TextLabel")
	pushL.BackgroundTransparency = 1
	pushL.AnchorPoint = Vector2.new(1, 0.5)
	pushL.Position = UDim2.new(0.5, -44, 0.95, -36)
	pushL.Size = UDim2.fromOffset(70, 20)
	Theme.applyFont(pushL, "HudSemi")
	pushL.TextSize = 11
	pushL.TextColor3 = Theme.Muted
	pushL.Text = "Poussée [F]"
	pushL.Parent = combatChrome
	local dashL = Instance.new("TextLabel")
	dashL.BackgroundTransparency = 1
	dashL.Position = UDim2.new(0.5, 44, 0.95, -46)
	dashL.Size = UDim2.fromOffset(80, 20)
	Theme.applyFont(dashL, "HudSemi")
	dashL.TextSize = 11
	dashL.TextColor3 = Theme.Muted
	dashL.Text = "Dash [G]"
	dashL.Parent = combatChrome

	exhaustLabel = Instance.new("TextLabel")
	exhaustLabel.BackgroundTransparency = 1
	exhaustLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	exhaustLabel.Position = UDim2.fromScale(0.5, 0.72)
	exhaustLabel.Size = UDim2.new(0.4, 0, 0, 20)
	Theme.applyFont(exhaustLabel, "HudSemi")
	exhaustLabel.TextSize = 13
	exhaustLabel.TextColor3 = Theme.Danger
	exhaustLabel.Text = Strings.Exhausted
	exhaustLabel.TextTransparency = 1
	exhaustLabel.Parent = combatChrome

	flashLabel = Instance.new("TextLabel")
	flashLabel.Name = "Flash"
	flashLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	flashLabel.Position = UDim2.fromScale(0.5, 0.42)
	flashLabel.Size = UDim2.new(0.7, 0, 0, 48)
	flashLabel.BackgroundTransparency = 1
	Theme.applyFont(flashLabel, "Display")
	flashLabel.TextSize = 34
	flashLabel.TextColor3 = Theme.Perfect
	flashLabel.TextTransparency = 1
	flashLabel.Text = ""
	flashLabel.ZIndex = 40
	flashLabel.Parent = root

	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownLabel.Position = UDim2.fromScale(0.5, 0.42)
	countdownLabel.Size = UDim2.new(0.5, 0, 0, 120)
	countdownLabel.BackgroundTransparency = 1
	Theme.applyFont(countdownLabel, "Display")
	countdownLabel.TextSize = 72
	countdownLabel.TextColor3 = Theme.Bone
	countdownLabel.TextTransparency = 1
	countdownLabel.Text = ""
	countdownLabel.ZIndex = 45
	countdownLabel.Parent = root

	-- Versus intro plate
	versusPlate = Util.glassPanel(root, "VersusPlate")
	versusPlate.AnchorPoint = Vector2.new(0.5, 0.5)
	versusPlate.Position = UDim2.fromScale(0.5, 0.28)
	versusPlate.Size = UDim2.new(0, 560, 0, 88)
	versusPlate.Visible = false
	versusPlate.ZIndex = 44

	versusLeft = Instance.new("TextLabel")
	versusLeft.Size = UDim2.new(0.4, 0, 1, 0)
	versusLeft.Position = UDim2.new(0.02, 0, 0, 0)
	versusLeft.BackgroundTransparency = 1
	Theme.applyFont(versusLeft, "Title")
	versusLeft.TextSize = 22
	versusLeft.TextColor3 = Theme.Dawn
	versusLeft.TextXAlignment = Enum.TextXAlignment.Right
	versusLeft.ZIndex = 45
	versusLeft.Parent = versusPlate

	versusVs = Instance.new("TextLabel")
	versusVs.AnchorPoint = Vector2.new(0.5, 0.5)
	versusVs.Position = UDim2.fromScale(0.5, 0.5)
	versusVs.Size = UDim2.new(0.2, 0, 0.6, 0)
	versusVs.BackgroundColor3 = Theme.InkSoft
	versusVs.BackgroundTransparency = 0.25
	Theme.applyFont(versusVs, "Hud")
	versusVs.TextSize = 16
	versusVs.TextColor3 = Theme.AccentHot
	versusVs.Text = "CONTRE"
	versusVs.ZIndex = 45
	versusVs.Parent = versusPlate
	Util.corner(versusVs, 8)

	versusRight = Instance.new("TextLabel")
	versusRight.Size = UDim2.new(0.4, 0, 1, 0)
	versusRight.Position = UDim2.new(0.58, 0, 0, 0)
	versusRight.BackgroundTransparency = 1
	Theme.applyFont(versusRight, "Title")
	versusRight.TextSize = 22
	versusRight.TextColor3 = Theme.Dusk
	versusRight.TextXAlignment = Enum.TextXAlignment.Left
	versusRight.ZIndex = 45
	versusRight.Parent = versusPlate

	-- Mobile hint cluster (visual only — InputCombat owns ContextAction buttons)
	if UserInputService.TouchEnabled then
		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.AnchorPoint = Vector2.new(1, 1)
		hint.Position = UDim2.new(0.98, 0, 0.98, 0)
		hint.Size = UDim2.fromOffset(160, 40)
		Theme.applyFont(hint, "Body")
		hint.TextSize = 11
		hint.TextColor3 = Theme.Muted
		hint.TextXAlignment = Enum.TextXAlignment.Right
		hint.Text = "Attaque · Parade · Esquive"
		hint.Parent = combatChrome
	end

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			if snap.userId == player.UserId then
				local hpFrac = math.clamp(snap.hp / CombatConfig.MaxHp, 0, 1)
				local staFrac = math.clamp(snap.stamina / CombatConfig.Stamina.Max, 0, 1)
				hpBar:set(hpFrac)
				staBar:set(staFrac)
				if snap.flags and snap.flags.exhausted then
					staBar:setColor(Theme.Danger)
					exhaustLabel.TextTransparency = 0.15
				else
					staBar:setColor(Theme.Stamina)
					exhaustLabel.TextTransparency = 1
				end
				if hpFrac < 0.25 then
					vignette.BackgroundColor3 = Theme.Danger
					vignette.BackgroundTransparency = 0.85
				elseif vignette.BackgroundTransparency < 1 and vignette.BackgroundColor3 == Theme.Danger then
					TweenService:Create(vignette, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
				end
				-- Focus ring from focusDash CD
				if snap.cooldowns then
					local cd = snap.cooldowns.focusDash or 0
					local maxCd = CombatConfig.Focus.DashFocus.Cooldown
					local ready = 1 - math.clamp(cd / maxCd, 0, 1)
					focusFill.BackgroundTransparency = 0.2 + (1 - ready) * 0.55
					local st = focusRing:FindFirstChildOfClass("UIStroke")
					if st then
						st.Transparency = if ready > 0.95 then 0.1 else 0.55
					end
				end
			elseif oppHpBar and oppStaBar then
				local hpFrac = math.clamp((snap.hp or 100) / CombatConfig.MaxHp, 0, 1)
				local staFrac = math.clamp((snap.stamina or 100) / CombatConfig.Stamina.Max, 0, 1)
				oppHpBar:set(hpFrac)
				oppStaBar:set(staFrac)
			end
		end
	end)

	metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local prof = payload.profile
		if typeof(prof) == "table" then
			if typeof(prof.faction) == "string" then
				playerFaction = prof.faction
				applyFactionVignette()
			end
			if typeof(prof.rank) == "string" then
				profileRank = prof.rank
			end
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
		if typeof(payload.fighters) == "table" then
			for _, row in payload.fighters do
				if typeof(row) == "table" and row.userId ~= player.UserId then
					theirId = row.userId
					if typeof(row.name) == "string" then
						nameRight.Text = row.name
					end
				elseif typeof(row) == "table" and row.userId == player.UserId and typeof(row.name) == "string" then
					nameLeft.Text = row.name
				end
			end
		end
		if theirId == nil and typeof(payload.scores) == "table" then
			for _, row in payload.scores do
				if row.userId == -9001 then
					theirId = -9001
					nameRight.Text = "ConcordBot"
				end
			end
		end

		myWinsCached = myWins
		theirWinsCached = theirWins
		local modeRaw = tostring(payload.mode or "Casual")
		local roundN = payload.roundNumber or 0
		scoreLabel.Text = string.format("%d — %d", myWins, theirWins)
		roundLabel.Text = if roundN > 0 then string.format("%s %d", Strings.Round, roundN) else modeRaw
		updateDots(myWins, theirWins)
		arenaLabel.Text = tostring(payload.arenaName or payload.arenaId or "")
		fairKitBadge.Visible = payload.fairKit == true

		if typeof(payload.rematchIn) == "number" then
			timerLabel.Text = string.format("◷ %d", math.ceil(payload.rematchIn))
		else
			timerLabel.Text = ""
		end

		local phase = tostring(payload.phase)
		setCombatChromeVisible(phase ~= "Lobby")

		if phase == "Lobby" then
			if versusPlate.Visible then
				hideVersus()
			end
			if closeMatchEnd then
				closeMatchEnd()
				closeMatchEnd = nil
			end
			countdownLabel.TextTransparency = 1
			lastCountdownCeil = nil
			rematchAnnounced = false
		elseif phase == "Countdown" and payload.countdown then
			local ceilN = math.max(1, math.ceil(payload.countdown))
			if closeMatchEnd then
				closeMatchEnd()
				closeMatchEnd = nil
			end
			if lastPhase ~= "Countdown" then
				local left = resolveFighterName(player.UserId)
				local right = resolveFighterName(theirId or -9001)
				showVersus(left, right)
				lastCountdownCeil = nil
				if lastPhase == "MatchEnd" or rematchAnnounced then
					flashBanner(Strings.Rematch, Theme.Accent)
					SoundHooks.play("Rematch")
					rematchAnnounced = false
				end
			end
			if lastCountdownCeil ~= ceilN then
				lastCountdownCeil = ceilN
				pulseCountdown(ceilN)
			end
		elseif phase == "Fighting" and lastPhase == "Countdown" then
			hideVersus()
			countdownLabel.Text = "ALLEZ !"
			countdownLabel.TextColor3 = Theme.Accent
			countdownLabel.TextTransparency = 0
			countdownLabel.TextSize = 56
			SoundHooks.play("Fight")
			TweenService:Create(countdownLabel, TweenInfo.new(0.75), {
				TextTransparency = 1,
				TextSize = 36,
			}):Play()
			lastCountdownCeil = nil
		elseif phase == "MatchEnd" then
			if versusPlate.Visible then
				hideVersus()
			end
			countdownLabel.TextTransparency = 1
			lastCountdownCeil = nil
			rematchAnnounced = true
			if not closeMatchEnd then
				local won = myWins > theirWins
				local draw = myWins == theirWins
				closeMatchEnd = MatchEndScreen.show({
					parent = root,
					won = won,
					draw = draw,
					myWins = myWins,
					theirWins = theirWins,
					myName = resolveFighterName(player.UserId),
					theirName = resolveFighterName(theirId or -9001),
					rank = profileRank,
					faction = playerFaction,
					mmrDelta = if modeRaw == "Ranked" then (if won then 24 else -16) else 0,
					autoLobbySec = math.max(8, math.floor(CombatConfig.Match.MatchEndDelay or 8)),
					onRematch = function()
						SoundHooks.play("Rematch")
						remotes.RequestRematch:FireServer()
					end,
					onLobby = function()
						remotes.RequestReturnLobby:FireServer()
					end,
					onSpectate = function()
						flashBanner(Strings.Spectate, Theme.Focus)
					end,
				})
			end
		elseif phase ~= "Countdown" and phase ~= "Fighting" then
			-- RoundEnd / other : clear versus + countdown
			if versusPlate.Visible then
				hideVersus()
			end
			countdownLabel.TextTransparency = 1
			lastCountdownCeil = nil
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
			flashBanner(Strings.PerfectParry, Theme.Perfect)
		elseif payload.riposte then
			flashBanner("RIPOSTE", Theme.AccentHot)
		elseif payload.guardBreak then
			flashBanner(Strings.GuardBreak, Theme.Danger)
		elseif payload.clash then
			flashBanner("CLASH", Theme.Clash)
		elseif payload.dodged then
			flashBanner("ESQUIVE", Theme.Success)
		elseif payload.critical then
			flashBanner(Strings.Critical, Theme.Danger)
		end
	end)

	remotes.RoundEnded.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local myWins, theirWins = scoreFromPayload(payload.scores)
		myWinsCached = myWins
		theirWinsCached = theirWins
		updateDots(myWins, theirWins)
		scoreLabel.Text = string.format("%d — %d", myWins, theirWins)
		local matchOver = payload.matchOver == true
		local won = payload.winnerUserId == player.UserId
		local draw = payload.winnerUserId == nil
		local title: string
		local color: Color3
		if matchOver then
			title = if won then "CONCORDANCE" else Strings.Defeat
			color = if won then Theme.Success else Theme.Danger
		elseif won then
			title = "MANCHE GAGNÉE"
			color = Theme.Success
		elseif draw then
			title = Strings.Draw
			color = Theme.Muted
		else
			title = "MANCHE PERDUE"
			color = Theme.Danger
		end
		flashBanner(title, color)
		if matchOver and won then
			SoundHooks.play("Ko")
		end
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

	-- silence unused
	local _ = Button
	local _ = myWinsCached
end

return CombatHud
