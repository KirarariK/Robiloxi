--!strict
--[[
	UIController — interface complète de Steal A Snake (construite par code, aucune image requise).

	HUD          : cartes Cash / Speed / Rebirths (+ revenu $/s), popups « +$ », objectif guidé.
	Portage      : panneau haut-centre (nom + mutation + rareté, barre de poids, pénalité de vitesse, bouton LÂCHER [G]).
	Danger       : bannière « … TE POURSUIT ! » qui pulse + vignette rouge selon la proximité du gardien.
	Notifications: toasts empilés en bas · titre de zone à l'entrée d'un biome.
	Panneaux     : Tapis de course, Vivarium, Fusion, Rebirth (ouverts par le serveur via OpenUI).
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local FormatNumber = require(game.ReplicatedStorage.StealASnake.Modules.FormatNumber)
local SnakesConfig = require(game.ReplicatedStorage.StealASnake.Config.SnakesConfig)
local MutationsConfig = require(game.ReplicatedStorage.StealASnake.Config.MutationsConfig)
local TreadmillsConfig = require(game.ReplicatedStorage.StealASnake.Config.TreadmillsConfig)
local RebirthsConfig = require(game.ReplicatedStorage.StealASnake.Config.RebirthsConfig)
local RarityConfig = require(game.ReplicatedStorage.StealASnake.Config.RarityConfig)
local EnvironmentController = require(script.Parent.EnvironmentController)

local UIController = {}

local player = Players.LocalPlayer
local dataCache: any = nil

--[[ ───────────── Thème ───────────── ]]
local FONT_TITLE = Font.new("rbxasset://fonts/families/FredokaOne.json")
local FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local FONT_BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

local C = {
	Panel = Color3.fromRGB(18, 22, 30),
	Panel2 = Color3.fromRGB(28, 34, 46),
	Text = Color3.fromRGB(245, 245, 250),
	Muted = Color3.fromRGB(160, 170, 190),
	Cash = Color3.fromRGB(90, 235, 120),
	Speed = Color3.fromRGB(80, 180, 255),
	Rebirth = Color3.fromRGB(190, 120, 255),
	Danger = Color3.fromRGB(255, 70, 70),
	Gold = Color3.fromRGB(255, 205, 70),
}

--[[ ───────────── Helpers ───────────── ]]
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

local function corner(parent: Instance, r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = parent })
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function textStroke(parent: Instance, thickness: number?)
	return new("UIStroke", { Color = Color3.fromRGB(10, 10, 18), Thickness = thickness or 2, Parent = parent })
end

local function gradient(parent: Instance, a: Color3, b: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90, Parent = parent })
end

local function label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = C.Text,
		FontFace = FONT_BOLD,
		TextScaled = false,
		TextSize = 18,
	}
	for k, v in props do
		defaults[k] = v
	end
	return new("TextLabel", defaults)
end

local function button(props: { [string]: any }, color: Color3): TextButton
	local b = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		TextColor3 = Color3.new(1, 1, 1),
		FontFace = FONT_TITLE,
		TextSize = 22,
	})
	for k, v in props do
		(b :: any)[k] = v
	end
	corner(b, 12)
	gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90)
	stroke(b, color:Lerp(Color3.new(0, 0, 0), 0.45), 3)
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
	end)
	return b
end

local function panel(props: { [string]: any }, accent: Color3?): Frame
	local f = new("Frame", { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08 })
	for k, v in props do
		(f :: any)[k] = v
	end
	corner(f, 16)
	gradient(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 180, 195), 90)
	stroke(f, accent or Color3.fromRGB(70, 80, 100), 2, 0.1)
	return f
end

local function bar(parent: Instance, pos: UDim2, size: UDim2, color: Color3): (Frame, Frame)
	local back = new("Frame", { Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(10, 12, 18), BackgroundTransparency = 0.2, Parent = parent })
	corner(back, 8)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = back })
	corner(fill, 8)
	gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170), 90)
	return back, fill
end

local function snakeTitle(speciesId: string, mutation: string?): (string, Color3, string)
	local def = SnakesConfig.get(speciesId)
	local name = if def then def.DisplayName else speciesId
	local mut = MutationsConfig.Defs[mutation or "Normal"] or MutationsConfig.Defs.Normal
	local rarity = if def then def.Rarity else "Common"
	local title = if mut.Id ~= "Normal" then string.format("✨ [%s] %s", string.upper(mut.DisplayName), name) else name
	return title, RarityConfig.color(rarity), RarityConfig.name(rarity)
end

local function incomePerSec(d: any): number
	local total = 0
	if d and d.Vivariums then
		for _, s in d.Vivariums do
			if s and s.Income then
				total += s.Income
			end
		end
	end
	return total
end

--[[ ───────────── Construction ───────────── ]]
function UIController.start()
	local gui = new("ScreenGui", {
		Name = "MainHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Vignette de danger (sous tout le reste)
	local vignette = new("Frame", { Name = "DangerVignette", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = gui })
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.22, 1),
			NumberSequenceKeypoint.new(0.78, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = vignette,
	})
	local vignette2 = vignette:Clone()
	vignette2.Name = "DangerVignetteV"
	;(vignette2:FindFirstChildOfClass("UIGradient") :: UIGradient).Rotation = 90
	vignette2.Parent = gui

	-- Cartes de stats (gauche)
	local stats = new("Frame", { Name = "Stats", Position = UDim2.new(0, 18, 0.5, -120), Size = UDim2.fromOffset(250, 240), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stats })

	local function statCard(order: number, icon: string, title: string, color: Color3): (TextLabel, TextLabel, UIScale)
		local card = panel({ Name = title, LayoutOrder = order, Size = UDim2.fromOffset(250, 70) }, color)
		card.Parent = stats
		local sc = new("UIScale", { Parent = card })
		local bubble = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = color, Parent = card })
		corner(bubble, 25)
		gradient(bubble, Color3.new(1, 1, 1), Color3.fromRGB(160, 160, 160), 90)
		stroke(bubble, color:Lerp(Color3.new(0, 0, 0), 0.5), 3)
		label({ Size = UDim2.fromScale(1, 1), Text = icon, TextSize = 26, Parent = bubble })
		label({ Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -80, 0, 18), Text = string.upper(title), TextColor3 = C.Muted, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		local value = label({ Position = UDim2.fromOffset(72, 24), Size = UDim2.new(1, -80, 0, 28), Text = "0", FontFace = FONT_TITLE, TextSize = 28, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		textStroke(value, 2)
		local sub = label({ Position = UDim2.fromOffset(72, 50), Size = UDim2.new(1, -80, 0, 14), Text = "", TextColor3 = C.Muted, TextSize = 12, FontFace = FONT_BODY, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		return value, sub, sc
	end

	local cashValue, cashSub, cashScale = statCard(1, "💵", "Argent", C.Cash)
	local speedValue, speedSub, speedScale = statCard(2, "⚡", "Vitesse", C.Speed)
	local rebirthValue, rebirthSub, rebirthScale = statCard(3, "👑", "Rebirths", C.Rebirth)

	local function pop(sc: UIScale)
		sc.Scale = 1.12
		TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	-- Logo (haut-droite)
	local logo = label({ Name = "Logo", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 14), Size = UDim2.fromOffset(300, 46), Text = "STEAL A SNAKE", FontFace = FONT_TITLE, TextSize = 34, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, Parent = gui })
	textStroke(logo, 3)

	-- Objectif guidé (bas-gauche)
	local objective = panel({ Name = "Objective", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -18), Size = UDim2.fromOffset(330, 52) }, C.Gold)
	objective.Parent = gui
	local objText = label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -24, 1, 0), Text = "", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = objective })

	-- Panneau de portage (haut-centre)
	local carry = panel({ Name = "CarryGauge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140), Size = UDim2.fromOffset(470, 118), Visible = false }, C.Danger)
	carry.Parent = gui
	local carryTitle = label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -150, 0, 28), Text = "", FontFace = FONT_TITLE, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = carry })
	textStroke(carryTitle, 2)
	local carryRarity = label({ Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -150, 0, 16), Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = carry })
	label({ Position = UDim2.fromOffset(16, 56), Size = UDim2.fromOffset(110, 16), Text = "⚖️ POIDS", TextColor3 = C.Muted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = carry })
	local _, weightFill = bar(carry, UDim2.fromOffset(16, 72), UDim2.fromOffset(170, 12), C.Gold)
	local weightText = label({ Position = UDim2.fromOffset(16, 88), Size = UDim2.fromOffset(170, 18), Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = carry })
	label({ Position = UDim2.fromOffset(200, 56), Size = UDim2.fromOffset(120, 16), Text = "🏃 VITESSE", TextColor3 = C.Muted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = carry })
	local _, speedFill = bar(carry, UDim2.fromOffset(200, 72), UDim2.fromOffset(120, 12), C.Speed)
	local penaltyText = label({ Position = UDim2.fromOffset(200, 88), Size = UDim2.fromOffset(120, 18), Text = "", TextColor3 = C.Danger, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = carry })
	local dropBtn = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(118, 86), Text = "LÂCHER\n[G]", TextSize = 22 }, C.Danger)
	dropBtn.Parent = carry
	dropBtn.MouseButton1Click:Connect(function()
		Network.event("RequestDrop"):FireServer()
	end)

	-- Bannière de poursuite
	local chase = panel({ Name = "ChaseBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 192), Size = UDim2.fromOffset(640, 54), Visible = false, BackgroundColor3 = Color3.fromRGB(140, 15, 20) }, Color3.fromRGB(255, 200, 80))
	chase.Parent = gui
	local chaseText = label({ Size = UDim2.fromScale(1, 1), Text = "", FontFace = FONT_TITLE, TextSize = 24, TextColor3 = Color3.fromRGB(255, 235, 140), Parent = chase })
	textStroke(chaseText, 2)
	local chaseScale = new("UIScale", { Parent = chase })

	-- Titre de zone (centre)
	local zoneTitle = label({ Name = "ZoneTitle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.28), Size = UDim2.fromOffset(700, 70), Text = "", FontFace = FONT_TITLE, TextSize = 54, TextTransparency = 1, Parent = gui })
	local zoneStroke = textStroke(zoneTitle, 4)
	zoneStroke.Transparency = 1

	-- Toasts (bas-centre)
	local toasts = new("Frame", { Name = "Toasts", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(460, 200), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toasts })
	local toastN = 0
	local function toast(msg: string, color: Color3?)
		toastN += 1
		local accent = color or C.Gold
		local t = panel({ LayoutOrder = toastN, Size = UDim2.fromOffset(440, 42), BackgroundTransparency = 0.05 }, accent)
		t.Parent = toasts
		local sc = new("UIScale", { Scale = 0.6, Parent = t })
		local tl = label({ Size = UDim2.fromScale(1, 1), Text = msg, TextSize = 18, TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.5), Parent = t })
		textStroke(tl, 1.5)
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		local list = toasts:GetChildren()
		local frames = {}
		for _, c in list do
			if c:IsA("Frame") then
				table.insert(frames, c)
			end
		end
		if #frames > 4 then
			table.sort(frames, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			frames[1]:Destroy()
		end
		task.delay(2.8, function()
			if t.Parent then
				TweenService:Create(sc, TweenInfo.new(0.25), { Scale = 0 }):Play()
				task.wait(0.27)
				t:Destroy()
			end
		end)
	end

	-- Popup « +$ » qui monte près de la carte argent
	local function floatText(text: string, color: Color3)
		local l = label({ Position = UDim2.new(0, 280, 0.5, -105), Size = UDim2.fromOffset(200, 30), Text = text, FontFace = FONT_TITLE, TextSize = 26, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = gui })
		textStroke(l, 2)
		TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Position = l.Position - UDim2.fromOffset(0, 60), TextTransparency = 1 }):Play()
		task.delay(1.15, function()
			l:Destroy()
		end)
	end

	--[[ ───────────── Panneau modal ───────────── ]]
	local overlay = new("TextButton", { Name = "ModalOverlay", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = gui })
	local modal = panel({ Name = "Modal", Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(470, 380), ZIndex = 21 })
	modal.Parent = overlay
	local modalScale = new("UIScale", { Parent = modal })
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = C.Gold, ZIndex = 22, Parent = modal })
	corner(header, 16)
	local headerGrad = gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(160, 160, 160), 90)
	local _ = headerGrad
	local headerFix = new("Frame", { Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = C.Gold, BorderSizePixel = 0, ZIndex = 22, Parent = header })
	local modalIcon = label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(50, 64), Text = "", TextSize = 34, ZIndex = 23, Parent = header })
	local modalTitle = label({ Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -130, 1, 0), Text = "", FontFace = FONT_TITLE, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = header })
	textStroke(modalTitle, 2.5)
	local closeBtn = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(42, 42), Text = "✕", TextSize = 22, ZIndex = 24 }, Color3.fromRGB(220, 60, 60))
	closeBtn.Parent = header
	local body = new("Frame", { Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -40, 1, -160), BackgroundTransparency = 1, ZIndex = 22, Parent = modal })
	local actionA = button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -18), Size = UDim2.new(0.5, -28, 0, 58), Text = "OK", ZIndex = 23 }, C.Cash)
	actionA.Parent = modal
	local actionB = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -18), Size = UDim2.new(0.5, -28, 0, 58), Text = "Fermer", ZIndex = 23 }, Color3.fromRGB(90, 95, 115))
	actionB.Parent = modal

	local modalCtx: any = nil

	local function clearBody()
		for _, c in body:GetChildren() do
			c:Destroy()
		end
	end

	local function line(y: number, left: string, right: string, color: Color3?)
		label({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(0.55, 0, 0, 26), Text = left, TextColor3 = C.Muted, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = body })
		local r = label({ Position = UDim2.new(0.45, 0, 0, y), Size = UDim2.new(0.55, 0, 0, 26), Text = right, TextColor3 = color or C.Text, FontFace = FONT_TITLE, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23, Parent = body })
		textStroke(r, 1.5)
	end

	local function note(y: number, text: string, color: Color3?)
		label({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 44), Text = text, TextColor3 = color or C.Muted, TextSize = 15, FontFace = FONT_BODY, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23, Parent = body })
	end

	local function progress(y: number, ratio: number, color: Color3, text: string)
		local back, fill = bar(body, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 22), color)
		back.ZIndex = 23
		fill.ZIndex = 24
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		local t = label({ Size = UDim2.fromScale(1, 1), Text = text, TextSize = 14, ZIndex = 25, Parent = back })
		textStroke(t, 1.5)
	end

	local function themeModal(color: Color3, icon: string, title: string)
		header.BackgroundColor3 = color
		headerFix.BackgroundColor3 = color
		;(modal:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = color
		modalIcon.Text = icon
		modalTitle.Text = title
	end

	local function closeModal()
		if not overlay.Visible then
			return
		end
		TweenService:Create(modalScale, TweenInfo.new(0.15), { Scale = 0.8 }):Play()
		TweenService:Create(overlay, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
		task.delay(0.15, function()
			overlay.Visible = false
		end)
		modalCtx = nil
	end

	local function openModal(kind: string, payload: any)
		modalCtx = { Kind = kind, Payload = payload }
		clearBody()
		actionA.Visible = true
		actionB.Visible = true
		actionB.Text = "Fermer"
		local d = dataCache or {}
		if kind == "Treadmill" then
			local lvl = d.TreadmillLevel or 1
			local cfg = TreadmillsConfig[lvl]
			local nextCfg = TreadmillsConfig[lvl + 1]
			themeModal(C.Speed, "🏃", "Tapis de course")
			line(0, "Niveau actuel", string.format("Niv. %d · %s", lvl, cfg and cfg.DisplayName or "?"), C.Speed)
			line(32, "Gain de vitesse", string.format("+%.2f /s", cfg and cfg.SpeedPerSec or 0), C.Cash)
			if nextCfg then
				line(72, "Niveau suivant", string.format("Niv. %d · %s", nextCfg.Level, nextCfg.DisplayName), C.Gold)
				line(104, "Nouveau gain", string.format("+%.2f /s", nextCfg.SpeedPerSec), C.Cash)
				progress(146, (d.Cash or 0) / nextCfg.Cost, C.Cash, string.format("$%s / $%s", FormatNumber.short(d.Cash or 0), FormatNumber.short(nextCfg.Cost)))
				note(178, "Monte sur ton tapis pour gagner de la Vitesse en continu. Plus de vitesse = plus de poids portable !")
				actionA.Text = "Acheter $" .. FormatNumber.short(nextCfg.Cost)
				actionA.BackgroundColor3 = if (d.Cash or 0) >= nextCfg.Cost then C.Cash else Color3.fromRGB(90, 95, 115)
			else
				note(80, "🏆 Niveau maximum atteint !", C.Gold)
				actionA.Visible = false
			end
		elseif kind == "Vivarium" then
			local snake = payload and payload.Snake
			if snake then
				local title, rcol, rname = snakeTitle(snake.SpeciesId, snake.Mutation)
				themeModal(rcol, "🦎", title)
				line(0, "Rareté", rname, rcol)
				line(32, "Mutation", (MutationsConfig.Defs[snake.Mutation] or MutationsConfig.Defs.Normal).DisplayName, (MutationsConfig.Defs[snake.Mutation] or MutationsConfig.Defs.Normal).Color)
				line(64, "Poids", string.format("%.1f kg", snake.Weight), C.Gold)
				line(96, "Revenu", "$" .. FormatNumber.short(snake.Income) .. " /s", C.Cash)
				line(128, "Valeur de vente", "$" .. FormatNumber.short(math.floor(snake.Income * 25)), C.Gold)
				note(168, "Vendre libère le vivarium. Pour fusionner, réunis 3 serpents identiques (même espèce + mutation) puis va à la Machine de Fusion.")
				actionA.Text = "Vendre"
				actionA.BackgroundColor3 = C.Gold
			else
				themeModal(Color3.fromRGB(120, 130, 150), "🪟", "Vivarium " .. tostring(payload and payload.Slot or ""))
				note(10, "Ce vivarium est vide.\n\nVole un serpent dans un nid et ramène-le sur la zone verte « DÉPOSE ICI » de ta base.", C.Text)
				actionA.Visible = false
			end
		elseif kind == "Fusion" then
			themeModal(Color3.fromRGB(170, 90, 255), "🧪", "Machine de Fusion")
			-- Regroupe les vivariums par espèce + mutation ; un groupe de 3+ est fusionnable.
			local groups: { [string]: { SpeciesId: string, Mutation: string, Slots: { string } } } = {}
			for slotName, s in d.Vivariums or {} do
				local key = s.SpeciesId .. "|" .. s.Mutation
				local g = groups[key] or { SpeciesId = s.SpeciesId, Mutation = s.Mutation, Slots = {} }
				table.insert(g.Slots, slotName)
				groups[key] = g
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
			if #list == 0 then
				note(10, "Tes vivariums sont vides.\n\nVole 3 serpents identiques (même espèce + même mutation) pour les fusionner en une mutation supérieure.", C.Text)
			end
			for i = 1, math.min(#list, 5) do
				local g = list[i]
				local title, col = snakeTitle(g.SpeciesId, g.Mutation)
				local ok = #g.Slots >= 3
				local rowBtn = button({
					Position = UDim2.fromOffset(0, (i - 1) * 46),
					Size = UDim2.new(1, 0, 0, 40),
					Text = string.format("%s%s  ×%d/3", if i == selected then "▶ " else "", title, math.min(#g.Slots, 3)),
					TextSize = 17,
					TextColor3 = if ok then col else C.Muted,
					ZIndex = 23,
				}, if i == selected then Color3.fromRGB(70, 50, 110) else Color3.fromRGB(40, 42, 56))
				rowBtn.Parent = body
				rowBtn.MouseButton1Click:Connect(function()
					openModal("Fusion", { Selected = i })
				end)
			end
			if chosen then
				local nextMut = MutationsConfig.Defs[MutationsConfig.FusionNext[chosen.Mutation] or "Cosmic"]
				if canFuse then
					note(math.min(#list, 5) * 46 + 4, "✅ Résultat : " .. (SnakesConfig.get(chosen.SpeciesId) or { DisplayName = chosen.SpeciesId }).DisplayName .. " " .. nextMut.DisplayName .. " (revenu ×" .. nextMut.Multiplier .. ", poids +10 %)", nextMut.Color)
				else
					note(math.min(#list, 5) * 46 + 4, "Il en manque " .. (3 - #chosen.Slots) .. " identique(s) pour fusionner ce serpent.")
				end
			end
			modalCtx.FusionSlots = if canFuse and chosen then { chosen.Slots[1], chosen.Slots[2], chosen.Slots[3] } else nil
			actionA.Text = "Fusionner"
			actionA.BackgroundColor3 = if canFuse then Color3.fromRGB(170, 90, 255) else Color3.fromRGB(90, 95, 115)
		elseif kind == "Rebirth" then
			local cost = payload and payload.Cost or RebirthsConfig.costFor(d.Rebirths or 0)
			local reb = (payload and payload.Rebirths) or d.Rebirths or 0
			themeModal(C.Rebirth, "👑", "Autel de Rebirth")
			line(0, "Rebirths", tostring(reb) .. " → " .. tostring(reb + 1), C.Rebirth)
			line(32, "Bonus revenu", string.format("+%d%% → +%d%%", math.floor(reb * RebirthsConfig.IncomeMultPerRebirth * 100 + 0.5), math.floor((reb + 1) * RebirthsConfig.IncomeMultPerRebirth * 100 + 0.5)), C.Cash)
			line(64, "Bonus vitesse", string.format("+%d", (reb + 1) * RebirthsConfig.SpeedBonusPerRebirth), C.Speed)
			progress(104, (d.Cash or 0) / cost, C.Rebirth, string.format("$%s / $%s", FormatNumber.short(d.Cash or 0), FormatNumber.short(cost)))
			note(136, string.format("⚠️ Remet à zéro : argent, vivariums et tapis. Tu gardes %d%% de ta vitesse.", math.floor(RebirthsConfig.KeepSpeedPercent * 100 + 0.5)), Color3.fromRGB(255, 190, 120))
			actionA.Text = "Renaître"
			actionA.BackgroundColor3 = if (d.Cash or 0) >= cost then C.Rebirth else Color3.fromRGB(90, 95, 115)
			actionB.Text = "Annuler"
		end
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		modalScale.Scale = 0.75
		TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(modalScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	actionA.MouseButton1Click:Connect(function()
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
		closeModal()
	end)
	actionB.MouseButton1Click:Connect(closeModal)
	closeBtn.MouseButton1Click:Connect(closeModal)
	overlay.MouseButton1Click:Connect(closeModal)

	--[[ ───────────── État ───────────── ]]
	local carrying = false
	local chasing = false

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
			objText.Text = ({
				"🎯  Étape 1/4 · Suis le rayon jusqu'au nid de la Jungle et vole un serpent (maintiens E)",
				"🏠  Étape 2/4 · Ramène-le sur la zone verte « DÉPOSE ICI » de ta base",
				"💰  Étape 3/4 · Ton serpent rapporte de l'argent : marche sur le bouton vert pour récolter",
				"🏃  Étape 4/4 · Monte sur ton tapis de course pour gagner de la Vitesse",
			})[step] or ""
			objective.Size = UDim2.fromOffset(380, 64)
			return
		end
		objective.Size = UDim2.fromOffset(330, 52)
		if carrying then
			objText.Text = "🏠  Ramène le serpent sur la zone verte de ta base !"
		elseif chasing then
			objText.Text = "🏃  Fuis vers la route (zone sûre) !"
		elseif (d.PendingCash or 0) > 0 then
			objText.Text = "💰  Récolte $" .. FormatNumber.short(d.PendingCash) .. " sur le bouton vert de ta base"
		elseif count == 0 then
			objText.Text = "🎯  Va au nid de la Jungle et vole un serpent (maintiens E)"
		else
			objText.Text = "⚡  Entraîne-toi sur ton tapis pour porter des serpents plus lourds"
		end
	end

	local lastCash: number? = nil
	local lastSpeed: number? = nil
	local lastReb: number? = nil
	local function applyData(data: any)
		dataCache = data
		local cash = data.Cash or 0
		cashValue.Text = "$" .. FormatNumber.short(cash)
		local ips = incomePerSec(data)
		cashSub.Text = string.format("+$%s /s · en attente $%s", FormatNumber.short(ips), FormatNumber.short(data.PendingCash or 0))
		speedValue.Text = FormatNumber.short(data.Speed or 0)
		local lvl = data.TreadmillLevel or 1
		speedSub.Text = string.format("Tapis niv. %d · +%.2f/s", lvl, (TreadmillsConfig[lvl] or TreadmillsConfig[1]).SpeedPerSec)
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
		if modalCtx and (modalCtx.Kind == "Treadmill" or modalCtx.Kind == "Rebirth") then
			openModal(modalCtx.Kind, modalCtx.Payload)
		end
	end

	player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
		refreshObjective()
		pop(cashScale)
	end)

	Network.event("DataUpdate").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" then
			applyData(data)
		end
	end)

	Network.event("CarryState").OnClientEvent:Connect(function(state)
		if not state then
			carrying = false
			TweenService:Create(carry, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -140) }):Play()
			task.delay(0.26, function()
				if not carrying then
					carry.Visible = false
				end
			end)
			refreshObjective()
			return
		end
		carrying = true
		local title, rcol, rname = snakeTitle(state.SpeciesId, state.Mutation)
		carryTitle.Text = title
		carryTitle.TextColor3 = rcol
		carryRarity.Text = rname
		carryRarity.TextColor3 = rcol
		;(carry:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = rcol
		local w = state.Weight or 0
		weightText.Text = string.format("%.1f kg", w)
		weightFill.Size = UDim2.fromScale(math.clamp(w / 150, 0.03, 1), 1)
		weightFill.BackgroundColor3 = if w > 80 then C.Danger elseif w > 35 then C.Gold else C.Cash
		local pen = state.Penalty or 0
		penaltyText.Text = string.format("-%d%%", pen)
		speedFill.Size = UDim2.fromScale(math.clamp(1 - pen / 100, 0.03, 1), 1)
		carry.Visible = true
		TweenService:Create(carry, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 62) }):Play()
		refreshObjective()
	end)

	Network.event("Alert").OnClientEvent:Connect(function(msg)
		local text = tostring(msg)
		if string.find(string.upper(text), "POURSUIT") then
			chasing = true
			chaseText.Text = text
			chase.Visible = true
			refreshObjective()
			return
		end
		local color = C.Gold
		local upper = string.upper(text)
		if string.find(upper, "SÉCURISÉ") or string.find(upper, "FUSION →") or string.find(upper, "REBIRTH +") or string.find(upper, "✅") or string.find(upper, "🔓") or string.find(upper, "🎉") then
			color = C.Cash
		elseif string.find(upper, "GARDIEN") or string.find(upper, "ANTI") or string.find(upper, "PAS ASSEZ") or string.find(upper, "PLEINS") or string.find(upper, "🔒") then
			color = C.Danger
		end
		toast(text, color)
	end)

	Network.event("OpenUI").OnClientEvent:Connect(function(kind, payload)
		openModal(tostring(kind), payload)
	end)

	local aggroIntensity = 0
	Network.event("GuardianAggro").OnClientEvent:Connect(function(active: boolean, intensity: number?)
		if active then
			aggroIntensity = intensity or 0.3
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
		zoneTitle.Text = if order == 0 then "🏡 " .. name else "🐍 " .. name
		zoneTitle.TextColor3 = if order == 0 then C.Cash else C.Gold
		zoneTitle.TextTransparency = 1
		zoneStroke.Transparency = 1
		TweenService:Create(zoneTitle, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		TweenService:Create(zoneStroke, TweenInfo.new(0.4), { Transparency = 0 }):Play()
		task.delay(2.2, function()
			TweenService:Create(zoneTitle, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			TweenService:Create(zoneStroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end)
	end)

	-- Pulsations (bannière + vignette)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if chase.Visible then
			chaseScale.Scale = 1 + math.sin(now * 8) * 0.03
		end
		local target = if chasing then 1 - math.clamp(aggroIntensity, 0, 1) * 0.65 - (math.sin(now * (6 + aggroIntensity * 8)) + 1) * 0.06 else 1
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

return UIController
