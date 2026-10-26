--!strict
--[[
	Lobby HUD premium — Concord Hall.
	Monnaies HG, rails G/D, CTA JOUER, hotbar, zones sûres, UIScale.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))
local FormConfig = require(Shared:WaitForChild("FormConfig"))
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent:WaitForChild("Strings"))
local Util = Kit.Util
local Button = Kit.Button
local CurrencyPill = Kit.CurrencyPill
local Rail = Kit.Rail
local Toast = Kit.Toast
local Tooltip = Kit.Tooltip

local LobbyHud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local root: Frame
local creditsPill: CurrencyPill.Handle
local shardsPill: CurrencyPill.Handle
local playBtn: TextButton
local casualChip: TextButton
local rankedChip: TextButton
local statusLabel: TextLabel
local zoneBanner: TextLabel
local prompt: Tooltip.Handle
local selectedMode: "Casual" | "Ranked" = "Casual"
local inQueue = false
local soloMatchmaking = false
local visible = true
local profile: any = nil
local openMeta: ((string) -> ())? = nil
local queueStartedAt = 0

local function formDisplayName(formId: string): string
	local def = FormConfig.Forms[formId]
	if def and typeof(def.displayName) == "string" then
		return def.displayName
	end
	return formId
end

local function refreshModeChips()
	if selectedMode == "Casual" then
		casualChip.BackgroundColor3 = Theme.Focus
		casualChip.TextColor3 = Theme.Ink900
		rankedChip.BackgroundColor3 = Theme.Ink700
		rankedChip.TextColor3 = Theme.Bone
	else
		rankedChip.BackgroundColor3 = Theme.Arcane
		rankedChip.TextColor3 = Theme.Bone
		casualChip.BackgroundColor3 = Theme.Ink700
		casualChip.TextColor3 = Theme.Bone
	end
end

local function refreshPlay()
	if soloMatchmaking or inQueue then
		local elapsed = math.max(0, math.floor(os.clock() - queueStartedAt))
		local mm = string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
		playBtn.Text = string.format("%s · %s", Strings.CancelSearch, mm)
		Button.setEnabled(playBtn, true)
		statusLabel.Text = if selectedMode == "Ranked"
			then "File Classé · " .. RankedConfig.FairKitBadge
			else "File Amical · adversaire sous peu"
		statusLabel.Visible = true
	else
		playBtn.Text = if selectedMode == "Ranked" then Strings.PlayRanked else Strings.PlayCasual
		Button.setEnabled(playBtn, true)
		statusLabel.Text = if selectedMode == "Ranked"
			then Strings.RankedFairReminder
			else "Amical · stats complètes · bot si solo"
		statusLabel.Visible = true
	end
end

local function refreshProfile()
	if not profile then
		creditsPill:setAmount(0)
		shardsPill:setAmount(0)
		return
	end
	creditsPill:setAmount(profile.credits or 0, true)
	shardsPill:setAmount(profile.shards or 0, true)
end

local function setVisible(v: boolean)
	visible = v
	root.Visible = v
end

function LobbyHud.setMetaOpener(fn: (string) -> ())
	openMeta = fn
end

function LobbyHud.isVisible(): boolean
	return visible
end

function LobbyHud.start()
	local remotes = Remotes.get()
	local metaRemotes = Remotes.getMeta()

	gui = Util.safeScreenGui("BladeConcordLobby", 22, Enum.ScreenInsets.CoreUISafeInsets)
	root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	Toast.bind(root)
	prompt = Tooltip.create(root)

	-- Monnaies haut-gauche
	local currencyCol = Instance.new("Frame")
	currencyCol.Name = "Currencies"
	currencyCol.BackgroundTransparency = 1
	currencyCol.Position = UDim2.new(0, 12, 0, 8)
	currencyCol.Size = UDim2.fromOffset(168, 74)
	currencyCol.Parent = root
	Util.list(currencyCol, Enum.FillDirection.Vertical, 6)

	creditsPill = CurrencyPill.create(currencyCol, {
		kind = "credits",
		amount = 0,
		layoutOrder = 1,
		onPlus = function()
			if openMeta then
				openMeta("Forge")
			end
		end,
	})
	shardsPill = CurrencyPill.create(currencyCol, {
		kind = "shards",
		amount = 0,
		layoutOrder = 2,
		onPlus = function()
			if openMeta then
				openMeta("Forge")
			end
		end,
	})

	-- Bandeau zone
	zoneBanner = Instance.new("TextLabel")
	zoneBanner.Name = "ZoneBanner"
	zoneBanner.AnchorPoint = Vector2.new(0.5, 0)
	zoneBanner.Position = UDim2.new(0.5, 0, 0.06, 0)
	zoneBanner.Size = UDim2.new(0.36, 0, 0, 36)
	zoneBanner.BackgroundTransparency = 1
	Theme.applyFont(zoneBanner, "Display")
	zoneBanner.TextSize = 28
	zoneBanner.TextColor3 = Theme.Gold
	zoneBanner.Text = Strings.Hall
	zoneBanner.Parent = root
	local zbStroke = Instance.new("UIStroke")
	zbStroke.Color = Theme.Ink900
	zbStroke.Thickness = 1.5
	zbStroke.Parent = zoneBanner

	-- Rails
	local function open(id: string)
		if openMeta then
			openMeta(id)
		end
	end

	Rail.create(root, {
		side = "left",
		items = {
			{
				id = "Shop",
				label = Strings.Shop,
				icon = "Shop",
				accent = Theme.Gold,
				onClick = function()
					open("Forge")
				end,
			},
			{
				id = "Forms",
				label = Strings.Forms,
				icon = "Forms",
				accent = Theme.Arcane,
				onClick = function()
					open("Forms")
				end,
			},
			{
				id = "Quests",
				label = Strings.Quests,
				icon = "Quests",
				accent = Theme.Focus,
				onClick = function()
					open("Quests")
				end,
			},
			{
				id = "Codes",
				label = Strings.Codes,
				icon = "Codes",
				accent = Theme.Success,
				onClick = function()
					open("Codes")
				end,
			},
		},
	})

	Rail.create(root, {
		side = "right",
		items = {
			{
				id = "Ranked",
				label = Strings.Ranked,
				icon = "Ranked",
				accent = Theme.Arcane,
				badge = "!",
				onClick = function()
					open("Ranked")
				end,
			},
			{
				id = "Factions",
				label = Strings.Factions,
				icon = "Factions",
				accent = Theme.Dawn,
				onClick = function()
					open("Factions")
				end,
			},
			{ id = "Servers", label = Strings.Servers, icon = "Servers", accent = Theme.Success, soon = true },
			{ id = "Trade", label = Strings.Trade, icon = "Trade", accent = Theme.FocusDark, soon = true },
		},
	})

	-- Mode chips + CTA JOUER
	local playCluster = Instance.new("Frame")
	playCluster.Name = "PlayCluster"
	playCluster.AnchorPoint = Vector2.new(0.5, 1)
	playCluster.Position = UDim2.new(0.5, 0, 0.80, 0)
	playCluster.Size = UDim2.new(0.32, 0, 0, 96)
	playCluster.BackgroundTransparency = 1
	playCluster.Parent = root

	casualChip = Instance.new("TextButton")
	casualChip.Name = "Casual"
	casualChip.Size = UDim2.new(0.48, 0, 0, 36)
	casualChip.Position = UDim2.new(0, 0, 0, 0)
	casualChip.BackgroundColor3 = Theme.Focus
	casualChip.BorderSizePixel = 0
	casualChip.Text = Strings.Casual
	casualChip.TextColor3 = Theme.Ink900
	casualChip.TextSize = 14
	casualChip.AutoButtonColor = false
	Theme.applyFont(casualChip, "Hud")
	casualChip.Parent = playCluster
	Util.corner(casualChip, 8)
	Util.stroke(casualChip, Theme.FocusDark, 1.2, 0.3)

	rankedChip = Instance.new("TextButton")
	rankedChip.Name = "Ranked"
	rankedChip.Size = UDim2.new(0.48, 0, 0, 36)
	rankedChip.Position = UDim2.new(0.52, 0, 0, 0)
	rankedChip.BackgroundColor3 = Theme.Ink700
	rankedChip.BorderSizePixel = 0
	rankedChip.Text = Strings.RankedShort
	rankedChip.TextColor3 = Theme.Bone
	rankedChip.TextSize = 14
	rankedChip.AutoButtonColor = false
	Theme.applyFont(rankedChip, "Hud")
	rankedChip.Parent = playCluster
	Util.corner(rankedChip, 8)
	Util.stroke(rankedChip, Theme.Arcane, 1.2, 0.4)

	playBtn = Button.create({
		parent = playCluster,
		text = Strings.PlayCasual,
		style = "primary",
		name = "Play",
		size = UDim2.new(1, 0, 0, 48),
		position = UDim2.new(0, 0, 0, 44),
		textSize = 18,
		onClick = function()
			if inQueue or soloMatchmaking then
				metaRemotes.LeaveQueue:FireServer()
				inQueue = false
				soloMatchmaking = false
				refreshPlay()
				return
			end
			queueStartedAt = os.clock()
			metaRemotes.QueueMatch:FireServer({ mode = selectedMode })
			Toast.show(if selectedMode == "Ranked" then Strings.Searching else "Entrée en file Amical…", Theme.Focus)
		end,
	})

	statusLabel = Instance.new("TextLabel")
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.Position = UDim2.new(0.5, 0, 0.805, 0)
	statusLabel.Size = UDim2.new(0.4, 0, 0, 18)
	statusLabel.BackgroundTransparency = 1
	Theme.applyFont(statusLabel, "Body")
	statusLabel.TextSize = 12
	statusLabel.TextColor3 = Theme.Muted
	statusLabel.Text = ""
	statusLabel.Parent = root

	-- Cancel queue when in queue — clicking play again leaves; also show leave via status
	-- Hotbar bas
	local hotbar = Instance.new("Frame")
	hotbar.Name = "Hotbar"
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 0.975, 0)
	hotbar.Size = UDim2.new(0.22, 0, 0, 64)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = root
	Util.list(hotbar, Enum.FillDirection.Horizontal, 8)

	local hotSlots = {
		{ "1", "Sword", Theme.Focus, Strings.HotbarForm },
		{ "2", "Emote", Theme.Arcane, Strings.HotbarEmote },
		{ "3", "Star", Theme.Gold, Strings.HotbarCosmetic },
	}
	for i, slot in hotSlots do
		local cell = Util.glassPanel(hotbar, "Slot" .. i)
		cell.Size = UDim2.fromOffset(64, 64)
		cell.LayoutOrder = i
		Util.aspect(cell, 1)
		local num = Instance.new("TextLabel")
		num.BackgroundTransparency = 1
		num.Position = UDim2.fromOffset(4, 2)
		num.Size = UDim2.fromOffset(16, 14)
		Theme.applyFont(num, "Hud")
		num.TextSize = 11
		num.TextColor3 = Theme.Gold
		num.Text = slot[1]
		num.ZIndex = 3
		num.Parent = cell
		local iconBox = Instance.new("Frame")
		iconBox.BackgroundTransparency = 1
		iconBox.Size = UDim2.fromScale(0.7, 0.7)
		iconBox.Position = UDim2.fromScale(0.15, 0.18)
		iconBox.Parent = cell
		Kit.Icons.compose(iconBox, slot[2], slot[3])
		if i == 1 then
			local st = cell:FindFirstChild("OuterStroke") :: UIStroke?
			if st then
				st.Color = Theme.Gold
				st.Transparency = 0.15
			end
		end
	end

	casualChip.MouseButton1Click:Connect(function()
		if inQueue or soloMatchmaking then
			return
		end
		selectedMode = "Casual"
		refreshModeChips()
		refreshPlay()
		prompt.set("[E] " .. Strings.PlayCasual)
	end)
	rankedChip.MouseButton1Click:Connect(function()
		if inQueue or soloMatchmaking then
			return
		end
		selectedMode = "Ranked"
		refreshModeChips()
		refreshPlay()
		prompt.set("[E] Entrer dans la file Classé")
	end)

	refreshModeChips()
	refreshPlay()
	prompt.set("[E] " .. Strings.PlayCasual)
	prompt.show()

	-- Fade entrée
	root.Visible = true
	zoneBanner.TextTransparency = 1
	Util.tween(zoneBanner, TweenInfo.new(0.6), { TextTransparency = 0 })
	task.delay(3.2, function()
		Util.tween(zoneBanner, TweenInfo.new(0.5), { TextTransparency = 0.35 })
	end)

	-- Timer file
	task.spawn(function()
		while gui.Parent do
			if visible and (inQueue or soloMatchmaking) then
				refreshPlay()
			end
			task.wait(1)
		end
	end)

	metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
			refreshProfile()
			-- Hotbar slot 1 label could reflect form — visual only
			local _ = formDisplayName(tostring(profile.equippedFormId or "Astra"))
		end
		if payload.kind == "QuestClaim" and payload.data and payload.data.ok then
			Toast.show("Quête terminée — +" .. tostring(payload.data.credits or 0) .. " crédits", Theme.Success)
		end
	end)

	remotes.MatchState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local phase = tostring(payload.phase)
		setVisible(phase == "Lobby")
		if phase ~= "Lobby" then
			inQueue = false
			soloMatchmaking = false
			prompt.hide()
			return
		end
		prompt.show()
		soloMatchmaking = payload.soloMatchmaking == true
		local queued = false
		if typeof(payload.queuedUserIds) == "table" then
			for _, uid in payload.queuedUserIds do
				if uid == player.UserId then
					queued = true
					break
				end
			end
		end
		local wasQueued = inQueue or soloMatchmaking
		inQueue = queued or soloMatchmaking
		if inQueue and not wasQueued then
			queueStartedAt = os.clock()
		end
		if typeof(payload.mode) == "string" and (payload.mode == "Casual" or payload.mode == "Ranked") then
			if inQueue then
				selectedMode = payload.mode
				refreshModeChips()
			end
		end
		refreshPlay()
	end)
end

return LobbyHud
