--!strict
--[[
	UIController — HUD et fenêtres de jeu de Steal A Snake, sur le design system UIKit (« bonbon arcade »).

	HUD          : cartes Argent / Vitesse / Rebirths (badge + gros chiffre + détail), « +$ » volants.
	Objectif     : bandeau haut-centre avec badge d'icône et pastilles de progression du tutoriel.
	Portage      : carte de rareté (nom, poids, pénalité de vitesse) + gros bouton LÂCHER [G].
	Danger       : ruban de poursuite rayé (nom du gardien + distance jusqu'au hub) + vignette rouge.
	Zones        : carte « ZONE n/15 » qui glisse à l'entrée d'une zone (nom + gardien).
	Notifications: toasts UIKit colorés par catégorie.
	Stations     : Tapis, Vivarium, Fusion, Rebirth (fenêtre modale UIKit, ouverte par le serveur via OpenUI).
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.StealASnake.Modules.Network)
local FormatNumber = require(ReplicatedStorage.StealASnake.Modules.FormatNumber)
local UIKit = require(ReplicatedStorage.StealASnake.Modules.UIKit)
local SnakesConfig = require(ReplicatedStorage.StealASnake.Config.SnakesConfig)
local MutationsConfig = require(ReplicatedStorage.StealASnake.Config.MutationsConfig)
local TreadmillsConfig = require(ReplicatedStorage.StealASnake.Config.TreadmillsConfig)
local RebirthsConfig = require(ReplicatedStorage.StealASnake.Config.RebirthsConfig)
local RarityConfig = require(ReplicatedStorage.StealASnake.Config.RarityConfig)
local BiomesConfig = require(ReplicatedStorage.StealASnake.Config.BiomesConfig)
local MonetizationConfig = require(ReplicatedStorage.StealASnake.Config.MonetizationConfig)
local EnvironmentController = require(script.Parent.EnvironmentController)

local UIController = {}

local player = Players.LocalPlayer
local dataCache: any = nil

local new, label, title, card, P, C = UIKit.new, UIKit.label, UIKit.title, UIKit.card, UIKit.P, UIKit.C
local INK, WHITE = UIKit.INK, UIKit.WHITE
local ZONE1_FRONT = BiomesConfig[1].Center.Z + BiomesConfig[1].Size.Z / 2

local function snakeTitle(speciesId: string, mutation: string?): (string, Color3, string, any)
	local def = SnakesConfig.get(speciesId)
	local name = if def then def.DisplayName else speciesId
	local mut = MutationsConfig.Defs[mutation or "Normal"] or MutationsConfig.Defs.Normal
	local rarity = if def then def.Rarity else "Common"
	local t = if mut.Id ~= "Normal" then string.format("✨ %s %s", mut.DisplayName, name) else name
	return t, RarityConfig.color(rarity), RarityConfig.name(rarity), mut
end

local function incomePerSec(d: any): number
	local total = 0
	if d and d.Vivariums then
		for _, s in d.Vivariums do
			if s and s.Income then
				total += s.Income
			end
		end
		total *= MonetizationConfig.incomeMult(d.Passes, d.Boosts, workspace:GetServerTimeNow(), d.Premium)
	end
	return total
end

function UIController.start()
	local gui = UIKit.screen("MainHUD", 5)

	--[[ ───────────── Vignette de danger (sous tout le reste) ───────────── ]]
	local vignette = new("Frame", { Name = "DangerVignette", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = gui })
	new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.22, 1), NumberSequenceKeypoint.new(0.78, 1), NumberSequenceKeypoint.new(1, 0) }),
		Parent = vignette,
	})
	local vignette2 = vignette:Clone()
	;(vignette2:FindFirstChildOfClass("UIGradient") :: UIGradient).Rotation = 90
	vignette2.Parent = gui

	--[[ ───────────── Cartes de stats (bas-gauche) ───────────── ]]
	local stats = new("Frame", { Name = "Stats", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(360, 240), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = stats })

	local function statCard(order: number, icon: string, pair: { Color3 }, valueColor: Color3, w: number, h: number): (TextLabel, TextLabel, UIScale)
		local row = card(stats, { UIKit.darker(pair[2], 0.5), UIKit.darker(pair[2], 0.28) }, { LayoutOrder = order, Size = UDim2.fromOffset(w, h), BackgroundTransparency = 0.05 }, 99, 3.5)
		local sc = new("UIScale", { Parent = row })
		local b = UIKit.badge(row, icon, pair, h + 8)
		b.AnchorPoint = Vector2.new(0, 0.5)
		b.Position = UDim2.new(0, -6, 0.5, 0)
		local big = math.floor(h * 0.56)
		local value = title(row, "0", big, { Position = UDim2.fromOffset(h + 10, 2), Size = UDim2.new(1, -h - 22, 0, big + 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = WHITE, TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = big, Parent = value })
		UIKit.grad(value, WHITE, valueColor)
		local sub = title(row, "", math.floor(h * 0.2), { Position = UDim2.new(0, h + 12, 1, -math.floor(h * 0.2) - 10), Size = UDim2.new(1, -h - 24, 0, math.floor(h * 0.2) + 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.lighter(valueColor, 0.55), TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = math.floor(h * 0.2), Parent = sub })
		return value, sub, sc
	end

	local rebirthValue, rebirthSub, rebirthScale = statCard(1, "👑", P.Rebirth, C.Rebirth, 250, 52)
	local speedValue, speedSub, speedScale = statCard(2, "⚡", P.Speed, C.Speed, 300, 64)
	local cashValue, cashSub, cashScale = statCard(3, "💵", P.Cash, C.Cash, 350, 78)

	local function pop(sc: UIScale)
		UIKit.pop(sc, 0.12)
	end

	local function floatText(text: string, color: Color3)
		local l = title(gui, text, 34, { Position = UDim2.new(0, 330, 1, -96), Size = UDim2.fromOffset(260, 40), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color })
		local sc = new("UIScale", { Scale = 0.5, Parent = l })
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(l, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = l.Position - UDim2.fromOffset(0, 70), TextTransparency = 1 }):Play()
		TweenService:Create(l:FindFirstChildOfClass("UIStroke") :: UIStroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		task.delay(1.25, function()
			l:Destroy()
		end)
	end

	--[[ ───────────── Objectif (haut-centre) ───────────── ]]
	local objective = card(gui, P.Slate, { Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(560, 58) }, 99, 3.5)
	;(objective:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = INK
	local objBadge = UIKit.badge(objective, "🎯", P.Gold, 58)
	objBadge.AnchorPoint = Vector2.new(0, 0.5)
	objBadge.Position = UDim2.new(0, -8, 0.5, 0)
	local objIcon = objBadge:FindFirstChildOfClass("TextLabel") :: TextLabel
	local objText = title(objective, "", 18, { Position = UDim2.fromOffset(58, 0), Size = UDim2.new(1, -72, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 18, Parent = objText })
	local stepChip, stepText = UIKit.chip(objective, "ÉTAPE 1/4", P.Gold, UDim2.fromOffset(110, 26), 14)
	stepChip.AnchorPoint = Vector2.new(0.5, 0.5)
	stepChip.Position = UDim2.new(0.5, 0, 1, 2)
	local pips = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 1, 2), Size = UDim2.fromOffset(90, 16), BackgroundTransparency = 1, Parent = objective })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = pips })
	local pipFrames: { Frame } = {}
	for i = 1, 4 do
		local pf = card(pips, P.Grey, { LayoutOrder = i, Size = UDim2.fromOffset(16, 16) }, 8, 2.5)
		pipFrames[i] = pf
	end

	--[[ ───────────── Carte de portage ───────────── ]]
	local carry = card(gui, P.Night, { Name = "CarryGauge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -160), Size = UDim2.fromOffset(500, 132), Visible = false }, 20, 4)
	local carryHead = card(carry, P.Gold, { Size = UDim2.new(1, 0, 0, 46) }, 20, 0)
	carryHead:FindFirstChildOfClass("UIStroke"):Destroy()
	local carryHeadFill = new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = carryHead })
	local carryHeadFillGrad = UIKit.grad(carryHeadFill, P.Gold[2], P.Gold[2])
	local carryTitle = title(carryHead, "", 24, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 24, Parent = carryTitle })
	local rarityChip, rarityText = UIKit.chip(carryHead, "Commun", P.Grey, UDim2.fromOffset(120, 28), 15)
	rarityChip.AnchorPoint = Vector2.new(1, 0.5)
	rarityChip.Position = UDim2.new(1, -140, 0.5, 0)
	title(carry, "⚖️ POIDS", 14, { Position = UDim2.fromOffset(16, 54), Size = UDim2.fromOffset(160, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted })
	local _, setWeight = UIKit.bar(carry, UDim2.fromOffset(16, 74), UDim2.fromOffset(160, 24), P.Gold)
	title(carry, "🏃 VITESSE", 14, { Position = UDim2.fromOffset(190, 54), Size = UDim2.fromOffset(150, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted })
	local _, setPenalty = UIKit.bar(carry, UDim2.fromOffset(190, 74), UDim2.fromOffset(150, 24), P.Speed)
	local carryHint = title(carry, "Ramène-le sur la zone verte de ta base !", 13, { Position = UDim2.fromOffset(16, 104), Size = UDim2.fromOffset(330, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted })
	local dropBtn = UIKit.candyButton(carry, "LÂCHER", P.Danger, UDim2.fromOffset(128, 70), function()
		Network.event("RequestDrop"):FireServer()
	end, 22)
	dropBtn.AnchorPoint = Vector2.new(1, 1)
	dropBtn.Position = UDim2.new(1, -14, 1, -12)
	local key = card(dropBtn, { WHITE, Color3.fromRGB(200, 200, 215) }, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(28, 28), ZIndex = 5 }, 8, 2.5)
	label(key, "G", 18, { Size = UDim2.fromScale(1, 1), TextColor3 = INK, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 6 })

	--[[ ───────────── Ruban de poursuite ───────────── ]]
	local chase = card(gui, P.Danger, { Name = "ChaseBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 230), Size = UDim2.fromOffset(620, 70), Visible = false, ClipsDescendants = true }, 18, 4)
	;(chase:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(255, 220, 90)
	local stripes = new("Frame", { Name = "Stripes", BackgroundTransparency = 1, Size = UDim2.new(1, 120, 1, 0), Parent = chase })
	for i = 0, 22 do
		new("Frame", { BackgroundColor3 = INK, BackgroundTransparency = 0.82, BorderSizePixel = 0, Rotation = 35, Size = UDim2.fromOffset(18, 150), Position = UDim2.fromOffset(i * 34 - 40, -40), Parent = stripes })
	end
	local skull = UIKit.badge(chase, "💀", { Color3.fromRGB(60, 50, 70), INK }, 54)
	skull.AnchorPoint = Vector2.new(0, 0.5)
	skull.Position = UDim2.new(0, 10, 0.5, 0)
	skull.ZIndex = 3
	local chaseText = title(chase, "", 24, { Position = UDim2.fromOffset(74, 4), Size = UDim2.new(1, -90, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 240, 150), TextScaled = true, ZIndex = 3 })
	new("UITextSizeConstraint", { MaxTextSize = 24, Parent = chaseText })
	local chaseSub = title(chase, "🏡 Cours vers le hub !", 16, { Position = UDim2.fromOffset(74, 38), Size = UDim2.new(1, -90, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	local chaseScale = new("UIScale", { Parent = chase })

	--[[ ───────────── Carte de zone ───────────── ]]
	local zoneCard = card(gui, P.Gold, { Name = "ZoneCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, -0.2), Size = UDim2.fromOffset(520, 120), Visible = false }, 22, 5)
	local zoneGrad = zoneCard:FindFirstChildOfClass("UIGradient") :: UIGradient
	local zoneNum, zoneNumText = UIKit.chip(zoneCard, "ZONE 1/15", { WHITE, Color3.fromRGB(215, 215, 230) }, UDim2.fromOffset(150, 32), 18)
	zoneNum.AnchorPoint = Vector2.new(0.5, 0.5)
	zoneNum.Position = UDim2.new(0.5, 0, 0, 0)
	zoneNumText.TextColor3 = INK
	;(zoneNumText:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
	local zoneName = title(zoneCard, "", 44, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 50), TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 44, Parent = zoneName })
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = zoneName })
	local zoneSub = title(zoneCard, "", 18, { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 24), TextColor3 = Color3.fromRGB(255, 240, 200) })
	local zoneToken = 0

	--[[ ───────────── Fenêtre des stations ───────────── ]]
	local station = UIKit.modal("Station", 580, 500, "🏃", "Tapis de course", P.Speed)
	local body = station.Body
	local modalCtx: any = nil

	local function clearBody()
		for _, c in body:GetChildren() do
			c:Destroy()
		end
	end

	-- tuile de stat : icône + libellé + valeur
	local function tile(pos: UDim2, size: UDim2, icon: string, caption: string, value: string, pair: { Color3 }, parent: Instance?)
		local t = card(parent or body, { UIKit.darker(pair[2], 0.55), UIKit.darker(pair[2], 0.32) }, { Position = pos, Size = size, ZIndex = 23 }, 16, 3)
		;(t:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = pair[1]
		label(t, icon, 26, { FontFace = UIKit.FONT_BOLD, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 34, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 24 })
		title(t, caption, 13, { Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -52, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted, ZIndex = 24 })
		local v = title(t, value, 22, { Position = UDim2.fromOffset(46, 22), Size = UDim2.new(1, -52, 1, -26), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.lighter(pair[1], 0.3), TextScaled = true, ZIndex = 24 })
		new("UITextSizeConstraint", { MaxTextSize = 22, Parent = v })
		return t
	end

	local function note(pos: UDim2, size: UDim2, text: string, color: Color3?)
		label(body, text, 15, { FontFace = UIKit.FONT_BOLD, Position = pos, Size = size, TextColor3 = color or C.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23 })
	end

	local function progress(y: number, ratio: number, pair: { Color3 }, text: string)
		local back, set = UIKit.bar(body, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 30), pair)
		back.ZIndex = 23
		for _, d in back:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 24
			end
		end
		set(ratio, text)
	end

	local function actions(aText: string?, aPair: { Color3 }, aEnabled: boolean, bText: string)
		local a: TextButton? = nil
		if aText then
			a = UIKit.candyButton(body, aText, if aEnabled then aPair else P.Grey, UDim2.new(0.5, -8, 0, 62), function()
				if aEnabled then
					UIController._action()
				end
			end, 24)
			;(a :: TextButton).AnchorPoint = Vector2.new(0, 1)
			;(a :: TextButton).Position = UDim2.new(0, 0, 1, 0)
		end
		local b = UIKit.candyButton(body, bText, P.Grey, if aText then UDim2.new(0.5, -8, 0, 62) else UDim2.new(1, 0, 0, 62), UIKit.closeModal, 22)
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, 0, 1, 0)
		for _, btn in { a, b } do
			if btn then
				btn.ZIndex = 24
				for _, d in btn:GetDescendants() do
					if d:IsA("GuiObject") then
						d.ZIndex = 25
					end
				end
			end
		end
	end

	local function openStation(kind: string, payload: any)
		modalCtx = { Kind = kind, Payload = payload }
		clearBody()
		local d = dataCache or {}
		if kind == "Treadmill" then
			local lvl = d.TreadmillLevel or 1
			local cfg = TreadmillsConfig[lvl]
			local nextCfg = TreadmillsConfig[lvl + 1]
			station.SetTheme(P.Speed, "🏃", "Tapis de course")
			-- échelle des niveaux
			local ladder = new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, ZIndex = 23, Parent = body })
			local n = #TreadmillsConfig
			local small = math.min(48, math.floor((540 - 12 - (n - 1) * 6) / n))
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = ladder })
			for i = 1, n do
				local done = i <= lvl
				local px = if i == lvl then small + 12 else small
				local f = card(ladder, if i == lvl then P.Gold elseif done then P.Speed else P.Grey, { LayoutOrder = i, Size = UDim2.fromOffset(px, px), ZIndex = 23 }, 99, 3.5)
				title(f, tostring(i), if i == lvl then 26 else 20, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 24 })
			end
			tile(UDim2.fromOffset(0, 80), UDim2.new(0.5, -6, 0, 66), "⚡", "GAIN ACTUEL", string.format("+%.2f /s", cfg and cfg.SpeedPerSec or 0), P.Speed)
			if nextCfg then
				tile(UDim2.new(0.5, 6, 0, 80), UDim2.new(0.5, -6, 0, 66), "⏫", "NIVEAU " .. nextCfg.Level, string.format("+%.2f /s", nextCfg.SpeedPerSec), P.Cash)
				progress(162, (d.Cash or 0) / nextCfg.Cost, P.Cash, string.format("$%s / $%s", FormatNumber.short(d.Cash or 0), FormatNumber.short(nextCfg.Cost)))
				note(UDim2.fromOffset(0, 204), UDim2.new(1, 0, 0, 60), "Monte sur ton tapis pour gagner de la Vitesse en continu. Plus de vitesse = serpents plus lourds portables et fuite plus facile !")
				actions("ACHETER $" .. FormatNumber.short(nextCfg.Cost), P.Cash, (d.Cash or 0) >= nextCfg.Cost, "FERMER")
			else
				tile(UDim2.new(0.5, 6, 0, 80), UDim2.new(0.5, -6, 0, 66), "🏆", "STATUT", "Niveau max !", P.Gold)
				actions(nil, P.Grey, false, "FERMER")
			end
		elseif kind == "Vivarium" then
			local snake = payload and payload.Snake
			if snake then
				local t, rcol, rname, mut = snakeTitle(snake.SpeciesId, snake.Mutation)
				local rp = UIKit.pairOf(rcol)
				station.SetTheme(rp, "🐍", t)
				local hero = card(body, rp, { Size = UDim2.fromOffset(140, 140), ZIndex = 23 }, 99, 4)
				label(hero, "🐍", 76, { FontFace = UIKit.FONT_BOLD, Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 24 })
				UIKit.shine(hero, 3, 99)
				local rc = UIKit.chip(body, rname, rp, UDim2.fromOffset(150, 30), 16)
				rc.Position = UDim2.fromOffset(160, 6)
				rc.ZIndex = 23
				local mc = UIKit.chip(body, "Mutation : " .. mut.DisplayName, UIKit.pairOf(mut.Color), UDim2.fromOffset(220, 30), 15)
				mc.Position = UDim2.fromOffset(160, 44)
				mc.ZIndex = 23
				tile(UDim2.fromOffset(160, 84), UDim2.new(1, -160, 0, 56), "💰", "REVENU", "$" .. FormatNumber.short(snake.Income) .. " /s", P.Cash)
				tile(UDim2.fromOffset(0, 154), UDim2.new(0.5, -6, 0, 62), "⚖️", "POIDS", string.format("%.1f kg", snake.Weight), P.Gold)
				tile(UDim2.new(0.5, 6, 0, 154), UDim2.new(0.5, -6, 0, 62), "🏷️", "VENTE", "$" .. FormatNumber.short(math.floor(snake.Income * 25)), P.Pink)
				note(UDim2.fromOffset(0, 228), UDim2.new(1, 0, 0, 60), "Vendre libère le vivarium. Pour fusionner, réunis 3 serpents identiques (même espèce + mutation) à la Machine de Fusion.")
				actions("VENDRE", P.Gold, true, "FERMER")
			else
				station.SetTheme(P.Grey, "🪟", "Vivarium " .. tostring(payload and payload.Slot or ""))
				local hero = card(body, P.Slate, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(150, 150), ZIndex = 23 }, 99, 4)
				label(hero, "🥚", 76, { FontFace = UIKit.FONT_BOLD, Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 24 })
				title(body, "Ce vivarium est vide", 24, { Position = UDim2.fromOffset(0, 162), Size = UDim2.new(1, 0, 0, 30), ZIndex = 23 })
				label(body, "Vole un serpent dans un nid et ramène-le sur la zone verte « DÉPOSE ICI » de ta base.", 16, { FontFace = UIKit.FONT_BOLD, Position = UDim2.fromOffset(20, 198), Size = UDim2.new(1, -40, 0, 50), TextColor3 = C.Muted, ZIndex = 23 })
				actions(nil, P.Grey, false, "FERMER")
			end
		elseif kind == "Fusion" then
			station.SetTheme(P.Rebirth, "🧪", "Machine de Fusion")
			local groups: { [string]: { SpeciesId: string, Mutation: string, Slots: { string } } } = {}
			for slotName, s in d.Vivariums or {} do
				local k = s.SpeciesId .. "|" .. s.Mutation
				local g = groups[k] or { SpeciesId = s.SpeciesId, Mutation = s.Mutation, Slots = {} }
				table.insert(g.Slots, slotName)
				groups[k] = g
			end
			local list = {}
			for _, g in groups do
				table.sort(g.Slots, function(a, b)
					return (tonumber(string.match(a, "%d+")) or 0) < (tonumber(string.match(b, "%d+")) or 0)
				end)
				table.insert(list, g)
			end
			table.sort(list, function(a, b)
				if (#a.Slots >= 3) ~= (#b.Slots >= 3) then
					return #a.Slots >= 3
				end
				return #a.Slots > #b.Slots
			end)
			local selected = math.clamp(payload and payload.Selected or 1, 1, math.max(#list, 1))
			local chosen = list[selected]
			local canFuse = chosen ~= nil and #chosen.Slots >= 3
			-- 3 emplacements + flèche + résultat
			local row = new("Frame", { Size = UDim2.new(1, 0, 0, 86), BackgroundTransparency = 1, ZIndex = 23, Parent = body })
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), Parent = row })
			for i = 1, 3 do
				local filled = chosen ~= nil and i <= #chosen.Slots
				local col = if chosen and filled then RarityConfig.color((SnakesConfig.get(chosen.SpeciesId) or { Rarity = "Common" }).Rarity) else Color3.fromRGB(90, 90, 110)
				local f = card(row, if filled then UIKit.pairOf(col) else P.Grey, { LayoutOrder = i, Size = UDim2.fromOffset(74, 74), ZIndex = 23 }, 99, 3.5)
				label(f, if filled then "🐍" else "?", 38, { FontFace = UIKit.FONT_BOLD, Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, TextColor3 = WHITE, ZIndex = 24 })
			end
			title(row, "➜", 40, { LayoutOrder = 4, Size = UDim2.fromOffset(44, 74), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 23 })
			local nextMut = if chosen then MutationsConfig.Defs[MutationsConfig.FusionNext[chosen.Mutation] or "Cosmic"] else MutationsConfig.Defs.Normal
			local res = card(row, if canFuse then UIKit.pairOf(nextMut.Color) else P.Grey, { LayoutOrder = 5, Size = UDim2.fromOffset(86, 86), ZIndex = 23 }, 99, 4)
			label(res, if canFuse then "✨" else "🔒", 42, { FontFace = UIKit.FONT_BOLD, Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 24 })
			if canFuse then
				UIKit.shine(res, 2, 99)
			end
			-- liste des groupes
			local scroll = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = C.Rebirth, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 23, Parent = body })
			new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
			new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = scroll })
			if #list == 0 then
				label(scroll, "Tes vivariums sont vides. Vole 3 serpents identiques (même espèce + même mutation) pour les fusionner en une mutation supérieure.", 15, { FontFace = UIKit.FONT_BOLD, Size = UDim2.new(1, 0, 0, 80), TextColor3 = C.Muted, ZIndex = 24 })
			end
			for i, g in list do
				local t, col = snakeTitle(g.SpeciesId, g.Mutation)
				local ok = #g.Slots >= 3
				local sel = i == selected
				local rb = UIKit.candyButton(scroll, string.format("%s   ×%d/3", t, math.min(#g.Slots, 3)), if sel then P.Rebirth elseif ok then UIKit.pairOf(col) else P.Slate, UDim2.new(1, 0, 0, 42), function()
					openStation("Fusion", { Selected = i })
				end, 17)
				rb.LayoutOrder = i
				rb.ZIndex = 24
				for _, dd in rb:GetDescendants() do
					if dd:IsA("GuiObject") then
						dd.ZIndex = 25
					end
				end
			end
			if chosen then
				note(UDim2.fromOffset(0, 272), UDim2.new(1, 0, 0, 40), if canFuse then "✅ Résultat : " .. (SnakesConfig.get(chosen.SpeciesId) or { DisplayName = chosen.SpeciesId }).DisplayName .. " " .. nextMut.DisplayName .. " · revenu ×" .. nextMut.Multiplier .. ", poids +10 %" else "Il en manque " .. (3 - #chosen.Slots) .. " identique(s) pour fusionner ce serpent.", if canFuse then UIKit.lighter(nextMut.Color, 0.3) else nil)
			end
			modalCtx.FusionSlots = if canFuse and chosen then { chosen.Slots[1], chosen.Slots[2], chosen.Slots[3] } else nil
			actions("FUSIONNER", P.Rebirth, canFuse, "FERMER")
		elseif kind == "Rebirth" then
			local cost = payload and payload.Cost or RebirthsConfig.costFor(d.Rebirths or 0)
			local reb = (payload and payload.Rebirths) or d.Rebirths or 0
			station.SetTheme(P.Rebirth, "👑", "Autel de Rebirth")
			local function column(x: UDim, header: string, pair: { Color3 }, rebV: number)
				local colF = card(body, { UIKit.darker(pair[2], 0.5), UIKit.darker(pair[2], 0.3) }, { Position = UDim2.new(x, UDim.new(0, 0)), Size = UDim2.new(0.5, -26, 0, 150), ZIndex = 23 }, 18, 3)
				;(colF:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = pair[1]
				local hc = UIKit.chip(colF, header, pair, UDim2.fromOffset(110, 28), 15)
				hc.AnchorPoint = Vector2.new(0.5, 0.5)
				hc.Position = UDim2.new(0.5, 0, 0, 0)
				hc.ZIndex = 24
				title(colF, "👑 " .. rebV, 34, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 40), ZIndex = 24 })
				title(colF, string.format("💰 +%d%% revenu", math.floor(rebV * RebirthsConfig.IncomeMultPerRebirth * 100 + 0.5)), 17, { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 24), TextColor3 = UIKit.lighter(C.Cash, 0.3), ZIndex = 24 })
				title(colF, string.format("⚡ +%d vitesse", rebV * RebirthsConfig.SpeedBonusPerRebirth), 17, { Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 24), TextColor3 = UIKit.lighter(C.Speed, 0.3), ZIndex = 24 })
			end
			column(UDim.new(0, 0), "AVANT", P.Grey, reb)
			column(UDim.new(0.5, 26), "APRÈS", P.Rebirth, reb + 1)
			title(body, "➜", 40, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.fromOffset(44, 44), ZIndex = 24 })
			progress(166, (d.Cash or 0) / cost, P.Rebirth, string.format("$%s / $%s", FormatNumber.short(d.Cash or 0), FormatNumber.short(cost)))
			note(UDim2.fromOffset(0, 206), UDim2.new(1, 0, 0, 60), string.format("⚠️ Remet à zéro : argent, vivariums et tapis. Tu gardes %d%% de ta vitesse.", math.floor(RebirthsConfig.KeepSpeedPercent * 100 + 0.5)), Color3.fromRGB(255, 200, 130))
			actions("RENAÎTRE", P.Rebirth, (d.Cash or 0) >= cost, "ANNULER")
		end
		if not UIKit.isOpen(station.Frame) then
			UIKit.showModal(station.Frame)
		end
	end

	UIController._action = function()
		if not modalCtx then
			return
		end
		local kind = modalCtx.Kind
		if kind == "Treadmill" then
			Network.event("RequestTreadmillUpgrade"):FireServer()
		elseif kind == "Vivarium" then
			local slot = modalCtx.Payload and modalCtx.Payload.Slot
			if slot then
				Network.event("RequestSell"):FireServer(slot)
			end
		elseif kind == "Fusion" then
			local slots = modalCtx.FusionSlots
			if not slots then
				return
			end
			Network.event("RequestFusion"):FireServer(slots[1], slots[2], slots[3])
		elseif kind == "Rebirth" then
			Network.event("RequestRebirth"):FireServer()
		end
		UIKit.closeModal()
	end

	--[[ ───────────── État ───────────── ]]
	local carrying = false
	local chasing = false

	local function setObjective(icon: string, text: string, step: number?)
		objIcon.Text = icon
		objText.Text = text
		stepChip.Visible = step ~= nil
		pips.Visible = step ~= nil
		if step then
			stepText.Text = "ÉTAPE " .. step .. "/4"
			for i, pf in pipFrames do
				local g = pf:FindFirstChildOfClass("UIGradient") :: UIGradient
				local p = if i < step then P.Cash elseif i == step then P.Gold else P.Grey
				g.Color = ColorSequence.new(p[1], p[2])
			end
		end
	end

	local function refreshObjective()
		local d = dataCache or {}
		local count = 0
		if d.Vivariums then
			for _ in d.Vivariums do
				count += 1
			end
		end
		local step = player:GetAttribute("TutorialStep") or 5
		if step < 5 and not chasing then
			local texts = {
				{ "🎯", "Suis le rayon jusqu'au nid de la Jungle et vole un serpent (maintiens E)" },
				{ "🏠", "Ramène-le sur la zone verte « DÉPOSE ICI » de ta base" },
				{ "💰", "Ton serpent rapporte de l'argent : marche sur le bouton vert pour récolter" },
				{ "🏃", "Monte sur ton tapis de course pour gagner de la Vitesse" },
			}
			local t = texts[step]
			if t then
				setObjective(t[1], t[2], step)
			end
			return
		end
		if carrying then
			setObjective("🏠", "Ramène le serpent sur la zone verte de ta base !")
		elseif chasing then
			setObjective("🏃", "Fuis jusqu'au hub : c'est la seule zone sûre !")
		elseif (d.PendingCash or 0) > 0 then
			setObjective("💰", "Récolte $" .. FormatNumber.short(d.PendingCash) .. " sur le bouton vert de ta base")
		elseif count == 0 then
			setObjective("🎯", "Va au nid de la Jungle et vole un serpent (maintiens E)")
		else
			setObjective("⚡", "Entraîne-toi sur ton tapis pour aller plus loin et porter plus lourd")
		end
	end

	local lastCash: number? = nil
	local lastSpeed: number? = nil
	local lastReb: number? = nil
	local function applyData(data: any)
		dataCache = data
		local cash = data.Cash or 0
		cashValue.Text = "$" .. FormatNumber.short(cash)
		cashSub.Text = string.format("+$%s /s  ·  en attente $%s", FormatNumber.short(incomePerSec(data)), FormatNumber.short(data.PendingCash or 0))
		speedValue.Text = FormatNumber.short(data.Speed or 0)
		local lvl = data.TreadmillLevel or 1
		speedSub.Text = string.format("Tapis niv. %d  ·  +%.2f/s", lvl, (TreadmillsConfig[lvl] or TreadmillsConfig[1]).SpeedPerSec)
		rebirthValue.Text = tostring(data.Rebirths or 0)
		rebirthSub.Text = string.format("Prochain : $%s", FormatNumber.short(RebirthsConfig.costFor(data.Rebirths or 0)))
		if lastCash and cash > lastCash then
			pop(cashScale)
			floatText("+$" .. FormatNumber.short(cash - lastCash), C.Cash)
		end
		if lastSpeed and math.floor(data.Speed or 0) > math.floor(lastSpeed) then
			pop(speedScale)
		end
		if lastReb and (data.Rebirths or 0) > lastReb then
			pop(rebirthScale)
		end
		lastCash, lastSpeed, lastReb = cash, data.Speed or 0, data.Rebirths or 0
		refreshObjective()
		if modalCtx and UIKit.isOpen(station.Frame) and (modalCtx.Kind == "Treadmill" or modalCtx.Kind == "Rebirth") then
			openStation(modalCtx.Kind, modalCtx.Payload)
		end
	end

	player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
		refreshObjective()
		UIKit.pop(objective, 0.1)
	end)

	Network.event("DataUpdate").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" then
			applyData(data)
		end
	end)

	Network.event("CarryState").OnClientEvent:Connect(function(state)
		if not state then
			carrying = false
			TweenService:Create(carry, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -160) }):Play()
			task.delay(0.26, function()
				if not carrying then
					carry.Visible = false
				end
			end)
			refreshObjective()
			return
		end
		carrying = true
		local t, rcol, rname = snakeTitle(state.SpeciesId, state.Mutation)
		local rp = UIKit.pairOf(rcol)
		carryTitle.Text = "🐍 " .. t
		rarityText.Text = rname
		;(rarityChip:FindFirstChildOfClass("UIGradient") :: UIGradient).Color = ColorSequence.new(rp[1], rp[2])
		;(carryHead:FindFirstChildOfClass("UIGradient") :: UIGradient).Color = ColorSequence.new(rp[1], rp[2])
		carryHeadFillGrad.Color = ColorSequence.new(rp[2], rp[2])
		;(carry:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = INK
		local w = state.Weight or 0
		setWeight(w / 150, string.format("%.1f kg", w))
		local pen = state.Penalty or 0
		setPenalty(1 - pen / 100, string.format("-%d%%", pen))
		carryHint.Text = if pen > 40 then "Lourd ! Les gardiens vont te rattraper, entraîne-toi." else "Ramène-le sur la zone verte de ta base !"
		carry.Visible = true
		TweenService:Create(carry, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 86) }):Play()
		refreshObjective()
	end)

	Network.event("Alert").OnClientEvent:Connect(function(msg)
		local text = tostring(msg)
		local upper = string.upper(text)
		if string.find(upper, "POURSUIT") then
			chasing = true
			local name = string.match(text, "⚠️%s*(.-)%s+TE POURSUIT") or "Le gardien"
			chaseText.Text = string.upper(name) .. " TE POURSUIT !"
			chase.Visible = true
			refreshObjective()
			return
		end
		local pair, icon = P.Gold, "🔔"
		if string.find(upper, "SÉCURISÉ") or string.find(upper, "FUSION →") or string.find(upper, "REBIRTH +") or string.find(upper, "✅") or string.find(upper, "🔓") or string.find(upper, "🎉") or string.find(upper, "VENDU") or string.find(upper, "AMÉLIORÉ") then
			pair, icon = P.Cash, "✅"
		elseif string.find(upper, "GARDIEN") or string.find(upper, "ANTI") or string.find(upper, "PAS ASSEZ") or string.find(upper, "PLEINS") or string.find(upper, "🔒") or string.find(upper, "💥") then
			pair, icon = P.Danger, "⚠️"
		elseif string.find(upper, "📖") then
			pair, icon = P.Teal, "📖"
		elseif string.find(upper, "✨") then
			pair, icon = P.Pink, "✨"
		elseif string.find(upper, "🎁") or string.find(upper, "📅") or string.find(upper, "💰") then
			pair, icon = P.Gold, "🎁"
		end
		UIKit.toast(text, pair, icon)
	end)

	Network.event("OpenUI").OnClientEvent:Connect(function(kind, payload)
		if kind == "Shop" or kind == "Daily" or kind == "Index" then
			return -- gérés par ShopController / MenuController
		end
		openStation(tostring(kind), payload)
	end)

	local aggroIntensity = 0
	Network.event("GuardianAggro").OnClientEvent:Connect(function(active: boolean, intensity: number?)
		if active then
			aggroIntensity = intensity or 0.3
			if not chasing then
				chaseText.Text = "UN GARDIEN TE POURSUIT !"
			end
			chasing = true
			chase.Visible = true
		else
			aggroIntensity = 0
			chasing = false
			chase.Visible = false
		end
		refreshObjective()
	end)

	Network.event("VFX").OnClientEvent:Connect(function(kind)
		if kind == "CashBurst" then
			pop(cashScale)
		end
	end)

	EnvironmentController.ZoneChanged:Connect(function(order: number, name: string)
		zoneToken += 1
		local my = zoneToken
		local cfg = BiomesConfig[order]
		local pair = if order == 0 then P.Cash else UIKit.pairOf(if cfg and cfg.Guardian then cfg.Guardian.Body else C.Gold)
		zoneGrad.Color = ColorSequence.new(pair[1], pair[2])
		zoneNumText.Text = if order == 0 then "ZONE SÛRE" else string.format("ZONE %d/%d", order, #BiomesConfig)
		zoneName.Text = if order == 0 then "🏡 " .. name else "🐍 " .. name
		zoneSub.Text = if order == 0 then "Les gardiens ne peuvent pas t'atteindre ici" elseif cfg then "⚠️ Gardien : " .. cfg.GuardianName else ""
		zoneCard.Visible = true
		zoneCard.Position = UDim2.fromScale(0.5, -0.2)
		TweenService:Create(zoneCard, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.43) }):Play()
		task.delay(2.6, function()
			if zoneToken == my then
				TweenService:Create(zoneCard, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, -0.2) }):Play()
			end
		end)
	end)

	-- Pulsations (ruban + vignette + rayures) et distance jusqu'au hub
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if chase.Visible then
			chaseScale.Scale = 1 + math.sin(now * 8) * 0.025
			stripes.Position = UDim2.fromOffset(-((now * 60) % 34), 0)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				local dist = math.max(0, ZONE1_FRONT - hrp.Position.Z)
				chaseSub.Text = string.format("🏡 Hub à %d studs : cours !", math.floor(dist))
			end
		end
		local vignetteOn = player:GetAttribute("Set_Vignette") ~= false
		local target = if chasing and vignetteOn then 1 - math.clamp(aggroIntensity, 0, 1) * 0.4 - (math.sin(now * (6 + aggroIntensity * 8)) + 1) * 0.04 else 1
		vignette.BackgroundTransparency += (target - vignette.BackgroundTransparency) * 0.2
		vignette2.BackgroundTransparency = vignette.BackgroundTransparency
	end)

	task.spawn(function()
		local ok, data = pcall(function()
			return Network.func("GetData"):InvokeServer()
		end)
		if ok and typeof(data) == "table" then
			applyData(data)
		end
	end)
	refreshObjective()
end

UIController._action = function() end

return UIController
