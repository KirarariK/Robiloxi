--!strict
--[[
	MenuController — écrans « maison » complémentaires du HUD (design system UIKit).

	  Écran titre   : logo animé + barre de chargement à l'arrivée en jeu
	  Index         : livre de collection des 110 espèces, zone par zone (découvertes / silhouettes ???)
	  Réglages      : sons, vignette de danger, secousses de caméra (préférences locales)
	  Repère de zone: carte haut-droite « ZONE n/15 » + 15 pastilles (zone actuelle, zones déjà visitées)
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.StealASnake.Modules.Network)
local UIKit = require(ReplicatedStorage.StealASnake.Modules.UIKit)
local SnakesConfig = require(ReplicatedStorage.StealASnake.Config.SnakesConfig)
local RarityConfig = require(ReplicatedStorage.StealASnake.Config.RarityConfig)
local BiomesConfig = require(ReplicatedStorage.StealASnake.Config.BiomesConfig)
local EnvironmentController = require(script.Parent.EnvironmentController)

local MenuController = {}

local player = Players.LocalPlayer
local new, label, title, card, P, C = UIKit.new, UIKit.label, UIKit.title, UIKit.card, UIKit.P, UIKit.C
local INK, WHITE = UIKit.INK, UIKit.WHITE

local data: any = nil

--[[ ───────────── Écran titre ───────────── ]]
local function intro()
	local g = UIKit.screen("SAS_Intro", 100)
	local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = g })
	UIKit.grad(bg, Color3.fromRGB(40, 110, 60), Color3.fromRGB(10, 20, 22), 90)
	-- écailles en filigrane
	for i = 0, 11 do
		for j = 0, 7 do
			local s = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.95, BorderSizePixel = 0, Size = UDim2.fromOffset(70, 70), Rotation = 45, Position = UDim2.new((i + (j % 2) * 0.5) / 11, -35, j / 7, -35), Parent = bg })
			UIKit.corner(s, 16)
		end
	end
	local snake = label(bg, "🐍", 130, { FontFace = UIKit.FONT_BOLD, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(200, 170), TextYAlignment = Enum.TextYAlignment.Center })
	local logo = title(bg, "STEAL A SNAKE", 96, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(900, 110), TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 96, Parent = logo })
	UIKit.grad(logo, Color3.fromRGB(255, 245, 150), Color3.fromRGB(255, 150, 30))
	;(logo:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 7
	local tag = title(bg, "Vole · Fuis · Collectionne", 26, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.65), Size = UDim2.fromOffset(700, 34), TextColor3 = Color3.fromRGB(200, 255, 200) })
	local barBack, setBar = UIKit.bar(bg, UDim2.new(0.5, -210, 0.76, 0), UDim2.fromOffset(420, 30), P.Cash)
	setBar(0.05, "Chargement des serpents…")
	local alive = true
	task.spawn(function()
		while alive do
			local t = os.clock()
			snake.Rotation = math.sin(t * 3) * 10
			snake.Position = UDim2.new(0.5, 0, 0.34, math.sin(t * 4) * 8)
			task.wait(1 / 30)
		end
	end)
	task.spawn(function()
		local steps = { { 0.35, "Construction des 15 zones…" }, { 0.65, "Réveil des gardiens…" }, { 0.9, "Ouverture des nids…" } }
		for _, st in steps do
			task.wait(0.6)
			setBar(st[1], st[2])
		end
		local t0 = os.clock()
		while not data and os.clock() - t0 < 8 do
			task.wait(0.1)
		end
		setBar(1, "C'est parti !")
		task.wait(0.5)
		alive = false
		local fade = TweenInfo.new(0.5)
		TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
		for _, d in bg:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, fade, { Transparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
			end
		end
		task.wait(0.55)
		g:Destroy()
	end)
	local _ = barBack
	local _2 = tag
end

--[[ ───────────── Index ───────────── ]]
local function buildIndex(): (Frame, () -> (), TextLabel)
	local api = UIKit.modal("Index", 920, 580, "📖", "INDEX DES SERPENTS", P.Teal)
	local body = api.Body
	local _, setTotal = UIKit.bar(body, UDim2.new(0, 200, 0, 0), UDim2.new(1, -200, 0, 30), P.Teal)
	-- colonne des zones
	local zones = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 186, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.Gold, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 23, Parent = body })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = zones })
	new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = zones })
	local grid = new("ScrollingFrame", { Position = UDim2.fromOffset(200, 42), Size = UDim2.new(1, -200, 1, -42), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.Gold, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 23, Parent = body })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(126, 150), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), Parent = grid })

	local selected = 1
	local zoneBtns: { TextButton } = {}

	local function owned(id: string): boolean
		return data ~= nil and data.Index ~= nil and data.Index[id] == true
	end

	local function zoneCount(order: number): (number, number)
		local list = SnakesConfig.listForBiome(order)
		local n = 0
		for _, def in list do
			if owned(def.Id) then
				n += 1
			end
		end
		return n, #list
	end

	local function renderGrid()
		for _, c in grid:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local list = SnakesConfig.listForBiome(selected)
		for i, def in list do
			local has = owned(def.Id)
			local rc = RarityConfig.color(def.Rarity)
			local f = card(grid, if has then UIKit.pairOf(rc) else { Color3.fromRGB(40, 36, 64), Color3.fromRGB(22, 18, 40) }, { LayoutOrder = RarityConfig.rank(def.Rarity) * 100 + i, ZIndex = 24 }, 16, 3.5)
			;(f:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if has then INK else rc
			local halo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = WHITE, BackgroundTransparency = if has then 0.7 else 0.92, ZIndex = 24, Parent = f })
			UIKit.corner(halo, 35)
			label(f, if has then "🐍" else "❔", 44, { FontFace = UIKit.FONT_BOLD, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(70, 66), TextYAlignment = Enum.TextYAlignment.Center, TextTransparency = if has then 0 else 0.3, ZIndex = 25 })
			local nm = title(f, if has then def.DisplayName else "???", 15, { Position = UDim2.fromOffset(6, 84), Size = UDim2.new(1, -12, 0, 32), TextScaled = true, ZIndex = 25 })
			new("UITextSizeConstraint", { MaxTextSize = 15, Parent = nm })
			local chip = UIKit.chip(f, RarityConfig.name(def.Rarity), UIKit.pairOf(rc), UDim2.new(1, -16, 0, 24), 13)
			chip.AnchorPoint = Vector2.new(0.5, 1)
			chip.Position = UDim2.new(0.5, 0, 1, -8)
			chip.ZIndex = 25
			if has and RarityConfig.rank(def.Rarity) >= 5 then
				UIKit.shine(f, 3, 16)
			end
		end
	end

	local function refresh()
		local total, all = 0, 0
		for o = 1, #BiomesConfig do
			local n, m = zoneCount(o)
			total += n
			all += m
			local b = zoneBtns[o]
			if b then
				local done = n == m and m > 0
				UIKit.setButton(b, string.format("%s %d · %d/%d", if done then "⭐" else "", o, n, m), if o == selected then P.Gold elseif done then P.Cash else P.Slate)
			end
		end
		setTotal(if all > 0 then total / all else 0, string.format("📖 %d / %d espèces découvertes", total, all))
		renderGrid()
	end

	for o, cfg in BiomesConfig do
		local b = UIKit.candyButton(zones, tostring(o), P.Slate, UDim2.new(1, 0, 0, 40), function()
			selected = o
			api.Title.Text = "INDEX · " .. string.upper(cfg.Name)
			refresh()
		end, 16)
		b.LayoutOrder = o
		zoneBtns[o] = b
	end
	api.Title.Text = "INDEX · " .. string.upper(BiomesConfig[1].Name)
	return api.Frame, refresh, api.Title
end

--[[ ───────────── Réglages ───────────── ]]
local function buildSettings(): Frame
	local api = UIKit.modal("Settings", 560, 430, "⚙️", "RÉGLAGES", P.Grey)
	local body = api.Body
	new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local function toggle(order: number, icon: string, text: string, attr: string, onChange: ((boolean) -> ())?)
		local row = card(body, P.Slate, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 72), ZIndex = 23 }, 18, 3)
		label(row, icon, 32, { FontFace = UIKit.FONT_BOLD, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(44, 72), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 24 })
		title(row, text, 20, { Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -170, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 24 })
		local sw = new("TextButton", { AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(88, 42), BackgroundColor3 = WHITE, ZIndex = 24, Parent = row })
		UIKit.corner(sw, 21)
		UIKit.outline(sw, 3)
		local sg = UIKit.pair(sw, P.Cash)
		local knob = card(sw, { WHITE, Color3.fromRGB(210, 210, 225) }, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(32, 32), ZIndex = 25 }, 16, 3)
		local function render(on: boolean, anim: boolean)
			local pos = UDim2.new(if on then 1 else 0, if on then -21 else 21, 0.5, 0)
			if anim then
				TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Position = pos }):Play()
			else
				knob.Position = pos
			end
			local p = if on then P.Cash else P.Grey
			sg.Color = ColorSequence.new(p[1], p[2])
		end
		local on = player:GetAttribute(attr) ~= false
		render(on, false)
		UIKit.juicy(sw, function()
			on = not on
			player:SetAttribute(attr, on)
			render(on, true)
			if onChange then
				onChange(on)
			end
		end)
	end
	toggle(1, "🔊", "Effets sonores", "Set_SFX", function(on)
		local g = SoundService:FindFirstChild("SAS_SFX")
		if g and g:IsA("SoundGroup") then
			g.Volume = if on then 1 else 0
		end
	end)
	toggle(2, "🟥", "Vignette de danger", "Set_Vignette")
	toggle(3, "📳", "Secousses de caméra", "Set_Shake")
	label(body, "Préférences enregistrées pour cette session.", 14, { FontFace = UIKit.FONT_BOLD, LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.Muted, ZIndex = 23 })
	return api.Frame
end

--[[ ───────────── Repère de zone (haut-droite) ───────────── ]]
local function buildTracker()
	local g = UIKit.screen("SAS_Tracker", 6)
	local f = card(g, P.Slate, { Name = "ZoneTracker", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(300, 70) }, 20, 3.5)
	local badge = UIKit.badge(f, "🏡", P.Cash, 58)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, -10, 0.5, 0)
	local icon = badge:FindFirstChildOfClass("TextLabel") :: TextLabel
	local zl = title(f, "HUB · ZONE SÛRE", 18, { Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -66, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 18, Parent = zl })
	local row = new("Frame", { Position = UDim2.fromOffset(56, 38), Size = UDim2.new(1, -66, 0, 18), BackgroundTransparency = 1, Parent = f })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = row })
	local pips: { Frame } = {}
	local visited: { [number]: boolean } = {}
	for i = 1, #BiomesConfig do
		local pf = new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(70, 66, 100), Parent = row })
		UIKit.corner(pf, 6)
		UIKit.outline(pf, 2)
		pips[i] = pf
	end
	EnvironmentController.ZoneChanged:Connect(function(order: number, name: string)
		if order > 0 then
			visited[order] = true
		end
		icon.Text = if order == 0 then "🏡" else "📍"
		local gr = badge:FindFirstChildOfClass("UIGradient") :: UIGradient
		local pair = if order == 0 then P.Cash else UIKit.pairOf(BiomesConfig[order].Guardian.Body)
		gr.Color = ColorSequence.new(pair[1], pair[2])
		zl.Text = if order == 0 then "HUB · ZONE SÛRE" else string.format("ZONE %d · %s", order, string.upper(name))
		for i, pf in pips do
			local cfg = BiomesConfig[i]
			if i == order then
				pf.BackgroundColor3 = UIKit.lighter(cfg.Guardian.Body, 0.3)
				pf.Size = UDim2.fromOffset(16, 16)
			else
				pf.BackgroundColor3 = if visited[i] then UIKit.darker(cfg.Guardian.Body, 0.8) else Color3.fromRGB(70, 66, 100)
				pf.Size = UDim2.fromOffset(12, 12)
			end
		end
		UIKit.pop(f, 0.08)
	end)
end

function MenuController.start()
	intro()
	buildTracker()
	local indexFrame, refreshIndex = buildIndex()
	local settingsFrame = buildSettings()

	local _, _, indexBadge = UIKit.railButton(5, "📖", "INDEX", P.Teal, function()
		refreshIndex()
		UIKit.showModal(indexFrame)
	end)
	UIKit.railButton(6, "⚙️", "RÉGLAGES", P.Grey, function()
		UIKit.showModal(settingsFrame)
	end)

	local lastCount: number? = nil
	local function onData(d: any)
		if typeof(d) ~= "table" then
			return
		end
		data = d
		local n = 0
		for _ in d.Index or {} do
			n += 1
		end
		if lastCount and n > lastCount then
			indexBadge.Visible = true
			indexBadge.Text = "+" .. (n - lastCount)
		end
		lastCount = n
		if UIKit.isOpen(indexFrame) then
			refreshIndex()
		end
	end
	Network.event("DataUpdate").OnClientEvent:Connect(onData)
	task.spawn(function()
		local ok, d = pcall(function()
			return Network.func("GetData"):InvokeServer()
		end)
		if ok then
			onData(d)
		end
	end)
	indexFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if indexFrame.Visible then
			indexBadge.Visible = false
		end
	end)
	Network.event("OpenUI").OnClientEvent:Connect(function(kind)
		if kind == "Index" then
			refreshIndex()
			UIKit.showModal(indexFrame)
		end
	end)
end

return MenuController
