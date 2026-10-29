--!strict
--[[
	ShopController — UI exclusives de monétisation et de rétention (construites par code).

	  Rail gauche   : BOUTIQUE · CADEAUX · QUOTIDIEN · CODES (+ bouton « OFFRE » du pack débutant avec compte à rebours)
	  Boutique      : onglets Offres / Passes / Boosts / Argent, cartes « bonbon » brillantes, rubans, reflets animés
	  Pack débutant : pop-up héros −80 % limité 24 h (s'ouvre une fois par session après le tutoriel)
	  Quotidien     : série de 7 jours (jour 7 = 2× Argent)
	  Cadeaux       : récompenses de temps de jeu (5 / 12 / 25 / 45 min)
	  Codes         : champ + validation serveur
	  Tray droite   : boosts actifs + chance serveur avec minuteurs
	  Fil d'achats  : « X a activé la CHANCE SERVEUR ! » (preuve sociale)

	Le client n'envoie que des clés ; prix, IDs et effets sont résolus côté serveur (MonetizationService).
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.StealASnake.Modules.Network)
local FormatNumber = require(ReplicatedStorage.StealASnake.Modules.FormatNumber)
local M = require(ReplicatedStorage.StealASnake.Config.MonetizationConfig)

local ShopController = {}

local player = Players.LocalPlayer
local data: any = nil
local root = ReplicatedStorage:WaitForChild("StealASnake")

--[[ ───────────── Thème « bonbon arcade » ───────────── ]]
local FONT_TITLE = Font.new("rbxasset://fonts/families/FredokaOne.json")
local FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local FONT_BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

local INK = Color3.fromRGB(14, 10, 28) -- contours épais
local WHITE = Color3.fromRGB(255, 255, 255)
local BUY_A = Color3.fromRGB(120, 255, 120)
local BUY_B = Color3.fromRGB(30, 175, 70)
local GOLD_A = Color3.fromRGB(255, 240, 140)
local GOLD_B = Color3.fromRGB(255, 165, 30)

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(p: Instance, r: number)
	new("UICorner", { CornerRadius = UDim.new(0, r), Parent = p })
end

local function outline(p: Instance, th: number?, color: Color3?)
	return new("UIStroke", { Color = color or INK, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
end

local function textOutline(p: Instance, th: number?)
	return new("UIStroke", { Color = INK, Thickness = th or 2.5, Parent = p })
end

local function grad(p: Instance, a: Color3, b: Color3, rot: number?)
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90, Parent = p })
end

local function darker(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function lighter(c: Color3, k: number): Color3
	return c:Lerp(WHITE, k)
end

local function label(parent: Instance, text: string, size: number, props: { [string]: any }?): TextLabel
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		FontFace = FONT_TITLE,
		TextColor3 = WHITE,
		Size = UDim2.new(1, 0, 0, size + 6),
		TextWrapped = true,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	return t
end

local function fmtTime(s: number): string
	s = math.max(0, math.floor(s))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function incomePerSec(): number
	local total = 0
	if data and data.Vivariums then
		for _, s in data.Vivariums do
			if s and s.Income then
				total += s.Income
			end
		end
		total *= M.incomeMult(data.Passes, data.Boosts, now(), data.Premium)
	end
	return total
end

-- reflet qui balaie un élément (bande blanche via UIGradient.Offset)
local function shine(parent: GuiObject, period: number)
	local s = new("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = parent.ZIndex + 3, Parent = parent })
	corner(s, 16)
	local g = new("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = s,
	})
	task.spawn(function()
		while s.Parent do
			g.Offset = Vector2.new(-1, 0)
			TweenService:Create(g, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Offset = Vector2.new(1, 0) }):Play()
			task.wait(period + math.random() * 1.5)
		end
	end)
end

-- bouton « bonbon » : survol = grossit, clic = écrase puis rebondit
local function juicy(btn: GuiButton, onClick: () -> ())
	local sc = btn:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = btn })
	btn.MouseEnter:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.15), { Scale = 1 }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	btn.Activated:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
end

local function priceButton(parent: Instance, text: string, a: Color3, b: Color3, height: number): TextButton
	local btn = new("TextButton", {
		Name = "Buy",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = WHITE,
		Size = UDim2.new(1, -20, 0, height),
		Parent = parent,
	})
	corner(btn, 12)
	outline(btn, 3)
	grad(btn, a, b)
	local t = label(btn, text, math.floor(height * 0.55), { Name = "Label", Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center })
	textOutline(t, 2)
	return btn
end

--[[ ───────────── Construction ───────────── ]]
function ShopController.start()
	local gui = new("ScreenGui", { Name = "SAS_Shop", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	-- échelle responsive (mobile → écran large)
	local uiScale = new("UIScale", { Parent = gui })
	local function rescale()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local v = cam.ViewportSize
		uiScale.Scale = math.clamp(math.min(v.X / 1280, v.Y / 760), 0.55, 1.15)
	end
	rescale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	--[[ ── Modales ── ]]
	local backdrop = new("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = gui })
	local openModal: Frame? = nil

	local function closeModal()
		local m = openModal
		if not m then
			return
		end
		openModal = nil
		local sc = m:FindFirstChildOfClass("UIScale") :: UIScale
		TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
		TweenService:Create(backdrop, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
		task.delay(0.16, function()
			if openModal ~= m then
				m.Visible = false
			end
			if not openModal then
				backdrop.Visible = false
			end
		end)
	end
	backdrop.Activated:Connect(closeModal)

	local function showModal(m: Frame)
		if openModal and openModal ~= m then
			openModal.Visible = false
		end
		openModal = m
		backdrop.Visible = true
		m.Visible = true
		local sc = m:FindFirstChildOfClass("UIScale") :: UIScale
		sc.Scale = 0.75
		TweenService:Create(sc, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	end

	local function modal(name: string, w: number, h: number, title: string, accentA: Color3, accentB: Color3): (Frame, Frame)
		local m = new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(w, h), BackgroundColor3 = WHITE, Visible = false, ZIndex = 21, Parent = gui })
		new("UIScale", { Parent = m })
		corner(m, 24)
		outline(m, 5)
		grad(m, Color3.fromRGB(52, 34, 92), Color3.fromRGB(20, 16, 40))
		-- en-tête dégradé (coins arrondis en haut seulement : un bandeau carré masque l'arrondi du bas)
		local head = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = WHITE, ZIndex = 22, Parent = m })
		corner(head, 24)
		grad(head, accentA, accentB)
		new("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), BackgroundColor3 = accentB, BorderSizePixel = 0, ZIndex = 22, Parent = head })
		new("Frame", { Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = INK, BorderSizePixel = 0, ZIndex = 22, Parent = head })
		local t = label(head, title, 42, { Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(24, 0), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 23 })
		textOutline(t, 3.5)
		local close = new("TextButton", { Name = "Close", AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 14, 0, -14), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = WHITE, ZIndex = 30, Parent = m })
		corner(close, 16)
		outline(close, 4)
		grad(close, Color3.fromRGB(255, 110, 110), Color3.fromRGB(200, 30, 50))
		local x = label(close, "✕", 32, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 31 })
		textOutline(x, 2.5)
		juicy(close, closeModal)
		local body = new("Frame", { Name = "Body", Position = UDim2.fromOffset(18, 88), Size = UDim2.new(1, -36, 1, -104), BackgroundTransparency = 1, ZIndex = 22, Parent = m })
		return m, body
	end

	--[[ ── Carte d'offre ── ]]
	local cardRefresh: { () -> () } = {}

	local function offerCard(parent: Instance, order: number, item: any, isPass: boolean)
		local col: Color3 = item.Color
		local card = new("Frame", { Name = item.Key, LayoutOrder = order, BackgroundColor3 = WHITE, ZIndex = 23, Parent = parent })
		corner(card, 18)
		outline(card, 4)
		grad(card, lighter(col, 0.25), darker(col, 0.55))
		new("UIScale", { Parent = card })
		-- halo derrière l'icône
		local halo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, ZIndex = 23, Parent = card })
		corner(halo, 48)
		local icon = label(card, item.Icon, 62, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 76), ZIndex = 24, FontFace = FONT_BOLD })
		task.spawn(function()
			local t0 = math.random() * 6
			while icon.Parent do
				local k = os.clock() + t0
				icon.Rotation = math.sin(k * 2) * 6
				icon.Position = UDim2.fromOffset(0, 24 + math.sin(k * 2.6) * 3)
				task.wait(1 / 30)
			end
		end)
		local name = label(card, item.Name, 21, { Position = UDim2.fromOffset(6, 104), Size = UDim2.new(1, -12, 0, 26), ZIndex = 24, TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = 21, Parent = name })
		textOutline(name, 2.5)
		local desc = label(card, item.Desc, 13, { FontFace = FONT_BOLD, Position = UDim2.fromOffset(10, 132), Size = UDim2.new(1, -20, 0, 48), ZIndex = 24, TextColor3 = Color3.fromRGB(240, 240, 255), TextYAlignment = Enum.TextYAlignment.Top })
		textOutline(desc, 1.5)
		local amount: TextLabel? = nil
		if item.Kind == "Cash" then
			amount = label(card, "", 20, { Position = UDim2.fromOffset(0, 172), Size = UDim2.new(1, 0, 0, 24), ZIndex = 24, TextColor3 = Color3.fromRGB(170, 255, 170) })
			textOutline(amount :: TextLabel, 2.5)
		end
		local buy = priceButton(card, "R$ " .. item.Price, BUY_A, BUY_B, 44)
		buy.AnchorPoint = Vector2.new(0.5, 1)
		buy.Position = UDim2.new(0.5, 0, 1, -10)
		buy.ZIndex = 25
		;(buy:FindFirstChild("Label") :: TextLabel).ZIndex = 26
		juicy(buy, function()
			Network.event("ShopBuy"):FireServer(item.Key)
		end)
		if item.Tag then
			local rib = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(150, 28), BackgroundColor3 = WHITE, ZIndex = 27, Parent = card })
			corner(rib, 14)
			outline(rib, 3)
			grad(rib, Color3.fromRGB(255, 90, 90), Color3.fromRGB(210, 20, 70))
			local rt = label(rib, item.Tag, 15, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 28 })
			textOutline(rt, 2)
		end
		shine(card, 3.5)
		table.insert(cardRefresh, function()
			local lbl = buy:FindFirstChild("Label") :: TextLabel
			local bg = buy:FindFirstChildOfClass("UIGradient") :: UIGradient
			if isPass and data and data.Passes and data.Passes[item.Key] then
				lbl.Text = "✓ POSSÉDÉ"
				bg.Color = ColorSequence.new(Color3.fromRGB(150, 150, 170), Color3.fromRGB(90, 90, 110))
				buy.Active = false
			else
				lbl.Text = "R$ " .. item.Price
				bg.Color = ColorSequence.new(BUY_A, BUY_B)
				buy.Active = true
			end
			if amount then
				amount.Text = "+$" .. FormatNumber.short(M.cashFor(incomePerSec(), item.CashSeconds or 600, item.CashMin or 0))
			end
		end)
	end

	--[[ ── BOUTIQUE ── ]]
	local shop, shopBody = modal("Shop", 900, 560, "🛒  BOUTIQUE", GOLD_A, GOLD_B)
	local tabsBar = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, ZIndex = 22, Parent = shopBody })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), Parent = tabsBar })
	local pages = new("Frame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), BackgroundTransparency = 1, ZIndex = 22, Parent = shopBody })

	local function page(name: string): ScrollingFrame
		local sf = new("ScrollingFrame", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = GOLD_B,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			ZIndex = 22,
			Parent = pages,
		})
		new("UIPadding", { PaddingTop = UDim.new(0, 18), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), Parent = sf })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(194, 262), CellPadding = UDim2.fromOffset(16, 22), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
		return sf
	end

	local tabDefs = {
		{ Key = "Offres", Text = "⭐ OFFRES", A = Color3.fromRGB(255, 120, 200), B = Color3.fromRGB(200, 40, 140) },
		{ Key = "Passes", Text = "🎫 PASSES", A = Color3.fromRGB(255, 220, 90), B = Color3.fromRGB(230, 140, 20) },
		{ Key = "Boosts", Text = "⚡ BOOSTS", A = Color3.fromRGB(110, 210, 255), B = Color3.fromRGB(40, 120, 230) },
		{ Key = "Argent", Text = "💰 ARGENT", A = Color3.fromRGB(130, 255, 140), B = Color3.fromRGB(30, 170, 70) },
	}
	local pageByKey: { [string]: ScrollingFrame } = {}
	local tabBtns: { [string]: TextButton } = {}
	local function selectTab(key: string)
		for k, sf in pageByKey do
			sf.Visible = k == key
		end
		for k, b in tabBtns do
			local sel = k == key
			TweenService:Create(b, TweenInfo.new(0.15), { Size = UDim2.fromOffset(if sel then 196 else 176, if sel then 46 else 40) }):Play()
			;(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if sel then WHITE else INK
		end
	end
	for i, def in tabDefs do
		local b = new("TextButton", { AutoButtonColor = false, Text = "", LayoutOrder = i, Size = UDim2.fromOffset(176, 40), BackgroundColor3 = WHITE, ZIndex = 23, Parent = tabsBar })
		corner(b, 14)
		outline(b, 3)
		grad(b, def.A, def.B)
		local t = label(b, def.Text, 20, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 24 })
		textOutline(t, 2.5)
		tabBtns[def.Key] = b
		pageByKey[def.Key] = page(def.Key)
		juicy(b, function()
			selectTab(def.Key)
		end)
	end

	local function addProduct(pageKey: string, order: number, key: string)
		local p = M.product(key)
		if p then
			offerCard(pageByKey[pageKey], order, p, false)
		end
	end
	local function addPass(pageKey: string, order: number, key: string)
		local p = M.pass(key)
		if p then
			offerCard(pageByKey[pageKey], order, p, true)
		end
	end
	addProduct("Offres", 1, "ServerLuck")
	addPass("Offres", 2, "Money2x")
	addProduct("Offres", 3, "CashL")
	addPass("Offres", 4, "VIP")
	for i, p in M.Passes do
		addPass("Passes", i, p.Key)
	end
	addProduct("Boosts", 1, "Boost2x")
	addProduct("Boosts", 2, "ServerLuck")
	addProduct("Boosts", 3, "Shield")
	addProduct("Boosts", 4, "TrainBoost")
	addProduct("Argent", 1, "CashS")
	addProduct("Argent", 2, "CashM")
	addProduct("Argent", 3, "CashL")
	addProduct("Argent", 4, "CashXL")
	selectTab("Offres")

	--[[ ── PACK DÉBUTANT (pop-up héros) ── ]]
	local starterP = M.product("Starter") :: M.Product
	local starter, starterBody = modal("Starter", 640, 470, "🎁  PACK DÉBUTANT", Color3.fromRGB(255, 140, 210), Color3.fromRGB(215, 40, 140))
	local hero = new("Frame", { Size = UDim2.new(1, 0, 0, 230), BackgroundColor3 = WHITE, ZIndex = 23, Parent = starterBody })
	corner(hero, 18)
	outline(hero, 4)
	grad(hero, Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 120, 60), 120)
	shine(hero, 2.5)
	local burst = label(hero, "🐍", 120, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.2, 0.5), Size = UDim2.fromOffset(170, 170), ZIndex = 24, FontFace = FONT_BOLD, TextYAlignment = Enum.TextYAlignment.Center })
	local items = new("Frame", { Position = UDim2.fromScale(0.4, 0.08), Size = UDim2.fromScale(0.58, 0.84), BackgroundTransparency = 1, ZIndex = 24, Parent = hero })
	new("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = items })
	local starterCash = label(items, "💰 +$25K", 30, { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 25 })
	textOutline(starterCash, 3)
	for _, line in { "💸 2× Argent · 30 min", "🛡️ Bouclier · 10 min", "⭐ Une seule fois !" } do
		local l = label(items, line, 24, { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 25 })
		textOutline(l, 2.5)
	end
	local discount = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 22, 0, 18), Size = UDim2.fromOffset(92, 92), Rotation = -14, BackgroundColor3 = WHITE, ZIndex = 27, Parent = hero })
	corner(discount, 46)
	outline(discount, 4)
	grad(discount, Color3.fromRGB(255, 80, 80), Color3.fromRGB(190, 0, 50))
	local dl = label(discount, "−80%", 28, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 28 })
	textOutline(dl, 2.5)
	local timerLbl = label(starterBody, "⏳ Se termine dans 23:59:59", 24, { Position = UDim2.fromOffset(0, 242), Size = UDim2.new(1, 0, 0, 30), ZIndex = 23, TextColor3 = Color3.fromRGB(255, 220, 120) })
	textOutline(timerLbl, 2.5)
	local oldPrice = label(starterBody, "R$ 499", 22, { Position = UDim2.fromOffset(0, 276), Size = UDim2.new(1, 0, 0, 26), ZIndex = 23, TextColor3 = Color3.fromRGB(190, 180, 210) })
	textOutline(oldPrice, 2)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 3), BackgroundColor3 = Color3.fromRGB(255, 80, 80), BorderSizePixel = 0, ZIndex = 24, Parent = oldPrice })
	local sBuy = priceButton(starterBody, "ACHETER  R$ " .. starterP.Price, BUY_A, BUY_B, 64)
	sBuy.AnchorPoint = Vector2.new(0.5, 1)
	sBuy.Position = UDim2.new(0.5, 0, 1, 0)
	sBuy.Size = UDim2.new(0.8, 0, 0, 64)
	sBuy.ZIndex = 24
	;(sBuy:FindFirstChild("Label") :: TextLabel).ZIndex = 25
	juicy(sBuy, function()
		Network.event("ShopBuy"):FireServer("Starter")
	end)
	task.spawn(function()
		local sc = sBuy:FindFirstChildOfClass("UIScale") :: UIScale
		while sBuy.Parent do
			if starter.Visible then
				burst.Rotation = math.sin(os.clock() * 3) * 10
				sc.Scale = 1 + math.max(0, math.sin(os.clock() * 5)) * 0.04
			end
			task.wait(1 / 30)
		end
	end)

	--[[ ── QUOTIDIEN ── ]]
	local daily, dailyBody = modal("Daily", 860, 400, "📅  RÉCOMPENSE QUOTIDIENNE", Color3.fromRGB(120, 210, 255), Color3.fromRGB(40, 100, 230))
	local dayRow = new("Frame", { Size = UDim2.new(1, 0, 0, 190), BackgroundTransparency = 1, ZIndex = 22, Parent = dailyBody })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), Parent = dayRow })
	local dayTiles: { { Frame: Frame, Reward: TextLabel, Check: TextLabel } } = {}
	for i, r in M.Daily do
		local big = i == #M.Daily
		local f = new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(if big then 132 else 100, if big then 176 else 150), BackgroundColor3 = WHITE, ZIndex = 23, Parent = dayRow })
		corner(f, 16)
		outline(f, 3)
		grad(f, Color3.fromRGB(80, 90, 140), Color3.fromRGB(40, 40, 80))
		new("UIScale", { Parent = f })
		local d = label(f, "JOUR " .. i, 18, { Position = UDim2.fromOffset(0, 8), ZIndex = 24 })
		textOutline(d, 2)
		local ic = label(f, if r.Boost then (M.BoostInfo[r.Boost] :: any).Icon else "💵", if big then 50 else 40, { FontFace = FONT_BOLD, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 56), ZIndex = 24 })
		local rw = label(f, "", 15, { Position = UDim2.new(0, 4, 1, -50), Size = UDim2.new(1, -8, 0, 40), ZIndex = 24, TextColor3 = Color3.fromRGB(190, 255, 190) })
		textOutline(rw, 2)
		local ck = label(f, "✓", 60, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 26, TextColor3 = Color3.fromRGB(120, 255, 140), Visible = false })
		textOutline(ck, 3)
		local _ = ic
		table.insert(dayTiles, { Frame = f, Reward = rw, Check = ck })
	end
	local dailyBtn = priceButton(dailyBody, "RÉCUPÉRER !", GOLD_A, GOLD_B, 60)
	dailyBtn.AnchorPoint = Vector2.new(0.5, 1)
	dailyBtn.Position = UDim2.new(0.5, 0, 1, 0)
	dailyBtn.Size = UDim2.new(0.55, 0, 0, 60)
	dailyBtn.ZIndex = 24
	;(dailyBtn:FindFirstChild("Label") :: TextLabel).ZIndex = 25
	juicy(dailyBtn, function()
		Network.event("ClaimDaily"):FireServer()
	end)
	local vipNote = label(dailyBody, "👑 VIP : récompenses ×2", 16, { Position = UDim2.new(0, 0, 1, -96), Size = UDim2.new(1, 0, 0, 20), ZIndex = 23, TextColor3 = Color3.fromRGB(255, 215, 100) })
	textOutline(vipNote, 2)

	--[[ ── CADEAUX ── ]]
	local gifts, giftsBody = modal("Gifts", 760, 360, "🎁  CADEAUX", Color3.fromRGB(255, 150, 220), Color3.fromRGB(190, 60, 200))
	local giftRow = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22, Parent = giftsBody })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 16), Parent = giftRow })
	local giftTiles: { { Btn: TextButton, Label: TextLabel, Box: TextLabel } } = {}
	for i, g in M.Gifts do
		local f = new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(160, 236), BackgroundColor3 = WHITE, ZIndex = 23, Parent = giftRow })
		corner(f, 18)
		outline(f, 4)
		grad(f, Color3.fromRGB(255, 170, 230), Color3.fromRGB(150, 40, 170))
		local box = label(f, "🎁", 64, { FontFace = FONT_BOLD, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 80), ZIndex = 24 })
		local rl = label(f, g.Icon .. " " .. g.Label, 16, { Position = UDim2.fromOffset(6, 100), Size = UDim2.new(1, -12, 0, 44), ZIndex = 24 })
		textOutline(rl, 2)
		local b = priceButton(f, "", Color3.fromRGB(110, 110, 140), Color3.fromRGB(60, 60, 90), 46)
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 1, -12)
		b.ZIndex = 25
		;(b:FindFirstChild("Label") :: TextLabel).ZIndex = 26
		juicy(b, function()
			Network.event("ClaimGift"):FireServer(i)
		end)
		table.insert(giftTiles, { Btn = b, Label = b:FindFirstChild("Label") :: TextLabel, Box = box })
	end

	--[[ ── CODES ── ]]
	local codes, codesBody = modal("Codes", 560, 300, "🎟️  CODES", Color3.fromRGB(200, 150, 255), Color3.fromRGB(110, 50, 220))
	local box = new("TextBox", { PlaceholderText = "Entre un code…", Text = "", ClearTextOnFocus = false, FontFace = FONT_TITLE, TextSize = 28, TextColor3 = INK, PlaceholderColor3 = Color3.fromRGB(140, 130, 160), BackgroundColor3 = WHITE, Size = UDim2.new(1, -20, 0, 64), Position = UDim2.fromOffset(10, 10), ZIndex = 23, Parent = codesBody })
	corner(box, 14)
	outline(box, 4)
	local codeMsg = label(codesBody, "Suis le jeu pour de nouveaux codes !", 18, { Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 24), ZIndex = 23, TextColor3 = Color3.fromRGB(220, 210, 255) })
	textOutline(codeMsg, 2)
	local codeBtn = priceButton(codesBody, "VALIDER", BUY_A, BUY_B, 56)
	codeBtn.AnchorPoint = Vector2.new(0.5, 1)
	codeBtn.Position = UDim2.new(0.5, 0, 1, 0)
	codeBtn.Size = UDim2.new(0.6, 0, 0, 56)
	codeBtn.ZIndex = 24
	;(codeBtn:FindFirstChild("Label") :: TextLabel).ZIndex = 25
	juicy(codeBtn, function()
		local ok, res = pcall(function()
			return Network.func("RedeemCode"):InvokeServer(box.Text)
		end)
		codeMsg.Text = if ok then tostring(res) else "Erreur, réessaie"
		box.Text = ""
	end)

	--[[ ── Rail gauche ── ]]
	local rail = new("Frame", { Name = "Rail", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.42, 0), Size = UDim2.fromOffset(92, 470), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = rail })

	local function railButton(order: number, icon: string, text: string, a: Color3, b: Color3, onClick: () -> ()): (TextButton, TextLabel, TextLabel)
		local holder = new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(86, 96), BackgroundTransparency = 1, Parent = rail })
		local btn = new("TextButton", { AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(74, 74), BackgroundColor3 = WHITE, Parent = holder })
		corner(btn, 20)
		outline(btn, 4)
		grad(btn, a, b)
		local ic = label(btn, icon, 40, { FontFace = FONT_BOLD, Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center })
		local t = label(holder, text, 15, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 10, 0, 20) })
		textOutline(t, 2.5)
		local badge = label(btn, "!", 18, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 50, 70), TextYAlignment = Enum.TextYAlignment.Center, Visible = false, ZIndex = 3 })
		corner(badge, 14)
		outline(badge, 2.5)
		juicy(btn, onClick)
		local _ = ic
		return btn, t, badge
	end

	local offerBtn, offerText = railButton(0, "🎁", "OFFRE", Color3.fromRGB(255, 130, 210), Color3.fromRGB(215, 30, 130), function()
		showModal(starter)
	end)
	shine(offerBtn, 2)
	local shopBtn = railButton(1, "🛒", "BOUTIQUE", GOLD_A, GOLD_B, function()
		showModal(shop)
	end)
	shine(shopBtn, 3)
	local _, _, giftBadge = railButton(2, "🎁", "CADEAUX", Color3.fromRGB(255, 160, 230), Color3.fromRGB(170, 50, 190), function()
		showModal(gifts)
	end)
	local _, _, dailyBadge = railButton(3, "📅", "QUOTIDIEN", Color3.fromRGB(130, 215, 255), Color3.fromRGB(40, 100, 230), function()
		showModal(daily)
	end)
	railButton(4, "🎟️", "CODES", Color3.fromRGB(205, 160, 255), Color3.fromRGB(110, 50, 220), function()
		showModal(codes)
	end)
	local offerHolder = offerBtn.Parent :: Frame

	-- respiration du bouton Boutique (attire l'œil sans agresser)
	task.spawn(function()
		local sc = shopBtn:FindFirstChildOfClass("UIScale") :: UIScale
		while shopBtn.Parent do
			TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Scale = 1.06 }):Play()
			task.wait(0.5)
			TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
			task.wait(2.5)
		end
	end)

	--[[ ── Tray droite : boosts actifs ── ]]
	local tray = new("Frame", { Name = "Boosts", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.42, 0), Size = UDim2.fromOffset(230, 300), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = tray })
	local chips: { [string]: { Frame: Frame, Text: TextLabel } } = {}
	local function chip(key: string, order: number, icon: string, color: Color3): { Frame: Frame, Text: TextLabel }
		local f = new("Frame", { Name = key, LayoutOrder = order, Size = UDim2.fromOffset(220, 46), BackgroundColor3 = WHITE, Visible = false, Parent = tray })
		corner(f, 23)
		outline(f, 3)
		grad(f, lighter(color, 0.2), darker(color, 0.6))
		label(f, icon, 26, { FontFace = FONT_BOLD, Size = UDim2.fromOffset(46, 46), TextYAlignment = Enum.TextYAlignment.Center })
		local t = label(f, "", 18, { Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -54, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = 18, Parent = t })
		textOutline(t, 2)
		local c = { Frame = f, Text = t }
		chips[key] = c
		return c
	end
	chip("Luck", 0, "🍀", Color3.fromRGB(80, 230, 140))
	local ord = 1
	for key, info in M.BoostInfo do
		chip(key, ord, (info :: any).Icon, (info :: any).Color)
		ord += 1
	end

	--[[ ── Fil d'achats (preuve sociale) ── ]]
	local feed = new("Frame", { Name = "Feed", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(620, 50), BackgroundColor3 = WHITE, Visible = false, Parent = gui })
	corner(feed, 25)
	outline(feed, 4)
	grad(feed, Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 150, 40))
	local feedText = label(feed, "", 20, { Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 20, Parent = feedText })
	textOutline(feedText, 2.5)
	local feedQueue: { string } = {}
	local feeding = false
	local function pumpFeed()
		if feeding then
			return
		end
		feeding = true
		task.spawn(function()
			while #feedQueue > 0 do
				feedText.Text = table.remove(feedQueue, 1) :: string
				feed.Visible = true
				feed.Position = UDim2.new(0.5, 0, 0, -80)
				TweenService:Create(feed, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 140) }):Play()
				task.wait(3.6)
				TweenService:Create(feed, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
				task.wait(0.3)
			end
			feed.Visible = false
			feeding = false
		end)
	end
	Network.event("ShopFeed").OnClientEvent:Connect(function(msg)
		table.insert(feedQueue, tostring(msg))
		pumpFeed()
	end)

	--[[ ── Rafraîchissement ── ]]
	local function today(): number
		return math.floor(now()) // 86400
	end

	local function refreshCards()
		for _, f in cardRefresh do
			f()
		end
		if data then
			local amount = M.cashFor(incomePerSec(), starterP.CashSeconds or 3600, starterP.CashMin or 0)
			starterCash.Text = "💰 +$" .. FormatNumber.short(amount)
		end
	end

	local function refreshDaily()
		if not data then
			return
		end
		local t = today()
		local claimedToday = data.DailyLast == t
		local streak = data.DailyStreak or 0
		local nextDay = if claimedToday then streak elseif data.DailyLast == t - 1 then (streak % #M.Daily) + 1 else 1
		local ips = incomePerSec()
		local vip = data.Passes and data.Passes.VIP
		for i, tile in dayTiles do
			local r = M.Daily[i]
			local parts = {}
			if r.Minutes then
				table.insert(parts, "$" .. FormatNumber.short(M.cashFor(ips, r.Minutes * 60, r.Min) * (if vip then 2 else 1)))
			end
			if r.Boost then
				table.insert(parts, (M.BoostInfo[r.Boost] :: any).Name)
			end
			tile.Reward.Text = table.concat(parts, "\n")
			local done = (claimedToday and i <= streak) or (not claimedToday and i < nextDay)
			local current = i == nextDay
			tile.Check.Visible = done
			local g = tile.Frame:FindFirstChildOfClass("UIGradient") :: UIGradient
			if current and not claimedToday then
				g.Color = ColorSequence.new(GOLD_A, GOLD_B)
				;(tile.Frame:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = WHITE
			elseif done then
				g.Color = ColorSequence.new(Color3.fromRGB(70, 140, 90), Color3.fromRGB(30, 70, 45))
				;(tile.Frame:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = INK
			else
				g.Color = ColorSequence.new(Color3.fromRGB(80, 90, 140), Color3.fromRGB(40, 40, 80))
				;(tile.Frame:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = INK
			end
		end
		dailyBadge.Visible = not claimedToday
		local lbl = dailyBtn:FindFirstChild("Label") :: TextLabel
		local bg = dailyBtn:FindFirstChildOfClass("UIGradient") :: UIGradient
		if claimedToday then
			lbl.Text = "REVIENS DANS " .. fmtTime((t + 1) * 86400 - now())
			bg.Color = ColorSequence.new(Color3.fromRGB(130, 130, 160), Color3.fromRGB(70, 70, 100))
		else
			lbl.Text = "RÉCUPÉRER JOUR " .. nextDay .. " !"
			bg.Color = ColorSequence.new(GOLD_A, GOLD_B)
		end
	end

	local function refreshGifts()
		if not data or not data.SessionStart then
			return
		end
		local played = now() - data.SessionStart
		local ready = 0
		for i, tile in giftTiles do
			local g = M.Gifts[i]
			local bg = tile.Btn:FindFirstChildOfClass("UIGradient") :: UIGradient
			if data.GiftsClaimed and data.GiftsClaimed[i] then
				tile.Label.Text = "✓ REÇU"
				bg.Color = ColorSequence.new(Color3.fromRGB(70, 140, 90), Color3.fromRGB(30, 70, 45))
				tile.Box.Text = "📦"
				tile.Box.Rotation = 0
			elseif played >= g.At * 60 then
				ready += 1
				tile.Label.Text = "OUVRIR !"
				bg.Color = ColorSequence.new(BUY_A, BUY_B)
				tile.Box.Text = "🎁"
				tile.Box.Rotation = math.sin(os.clock() * 12) * 8
			else
				tile.Label.Text = fmtTime(g.At * 60 - played)
				bg.Color = ColorSequence.new(Color3.fromRGB(110, 110, 140), Color3.fromRGB(60, 60, 90))
				tile.Box.Text = "🎁"
				tile.Box.Rotation = 0
			end
		end
		giftBadge.Visible = ready > 0
		giftBadge.Text = tostring(ready)
	end

	local function refreshStarter(): boolean
		if not data then
			offerHolder.Visible = false
			return false
		end
		local left = (data.StarterOfferEnds or 0) - now()
		local available = not data.StarterBought and left > 0
		offerHolder.Visible = available
		if available then
			offerText.Text = fmtTime(left)
			timerLbl.Text = "⏳ Se termine dans " .. fmtTime(left)
		elseif starter.Visible then
			closeModal()
		end
		return available
	end

	local function refreshTray()
		local t = now()
		local boosts = if data then data.Boosts else nil
		for key, c in chips do
			if key == "Luck" then
				local untilT = root:GetAttribute("ServerLuckUntil") or 0
				local left = untilT - t
				c.Frame.Visible = left > 0
				if left > 0 then
					c.Text.Text = "Chance serveur " .. fmtTime(left)
				end
			else
				local left = (if boosts then boosts[key] or 0 else 0) - t
				c.Frame.Visible = left > 0
				if left > 0 then
					c.Text.Text = (M.BoostInfo[key] :: any).Name .. " " .. fmtTime(left)
				end
			end
		end
	end

	local function onData(d: any)
		if typeof(d) ~= "table" then
			return
		end
		data = d
		refreshCards()
		refreshDaily()
		refreshGifts()
		refreshStarter()
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

	-- minuteurs (4×/s) + pulsation des chips
	local acc = 0
	local cardAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		cardAcc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		refreshTray()
		refreshStarter()
		if gifts.Visible or not giftBadge.Visible then
			refreshGifts()
		end
		if daily.Visible then
			refreshDaily()
		end
		if cardAcc > 2 and shop.Visible then
			cardAcc = 0
			refreshCards()
		end
	end)

	-- Pop-up du pack débutant : une fois par session, après le tutoriel, quand le joueur a goûté au jeu
	task.spawn(function()
		task.wait(10)
		for _ = 1, 120 do
			if data and (data.TutorialStep or 1) >= 5 then
				break
			end
			task.wait(5)
		end
		if refreshStarter() and not openModal then
			showModal(starter)
		end
	end)

	-- Ouverture depuis le serveur (ex. PNJ / panneau en jeu) : OpenUI("Shop")
	Network.event("OpenUI").OnClientEvent:Connect(function(name)
		if name == "Shop" then
			showModal(shop)
		elseif name == "Daily" then
			showModal(daily)
		end
	end)
end

return ShopController
