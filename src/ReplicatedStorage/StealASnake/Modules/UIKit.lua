--!strict
--[[
	UIKit — design system « bonbon arcade » de Steal A Snake (client uniquement).

	Une seule source pour le thème et les composants, partagée par tous les contrôleurs d'UI :
	  - tokens : polices, encre des contours, palettes d'accent ;
	  - primitives : new, corner, outline, textOutline, grad, label ;
	  - composants : candyButton (survol/clic « juicy »), card, bar (jauge animée), shine (reflet), chip ;
	  - écrans : screen() avec mise à l'échelle responsive commune ;
	  - modales : modal() — une seule ouverte à la fois, fond assombri partagé, pop d'ouverture ;
	  - rail : railButton() — colonne de gros boutons à gauche, partagée par la boutique, l'index, etc. ;
	  - toast() — notifications empilées.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

--[[ ───────────── Tokens ───────────── ]]
UIKit.FONT_TITLE = Font.new("rbxasset://fonts/families/FredokaOne.json")
UIKit.FONT_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
UIKit.FONT_BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

UIKit.INK = Color3.fromRGB(14, 10, 28)
UIKit.WHITE = Color3.fromRGB(255, 255, 255)

-- paires (clair, foncé) pour les dégradés verticaux
UIKit.P = {
	Cash = { Color3.fromRGB(140, 255, 140), Color3.fromRGB(30, 170, 70) },
	Speed = { Color3.fromRGB(130, 215, 255), Color3.fromRGB(40, 110, 235) },
	Rebirth = { Color3.fromRGB(215, 160, 255), Color3.fromRGB(120, 50, 220) },
	Gold = { Color3.fromRGB(255, 240, 140), Color3.fromRGB(255, 160, 30) },
	Danger = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(200, 25, 50) },
	Pink = { Color3.fromRGB(255, 150, 220), Color3.fromRGB(200, 40, 150) },
	Teal = { Color3.fromRGB(120, 255, 220), Color3.fromRGB(20, 160, 150) },
	Grey = { Color3.fromRGB(150, 150, 175), Color3.fromRGB(80, 80, 105) },
	Night = { Color3.fromRGB(52, 34, 92), Color3.fromRGB(20, 16, 40) },
	Slate = { Color3.fromRGB(70, 62, 120), Color3.fromRGB(36, 30, 70) },
}

UIKit.C = {
	Cash = Color3.fromRGB(110, 245, 120),
	Speed = Color3.fromRGB(90, 190, 255),
	Rebirth = Color3.fromRGB(200, 130, 255),
	Gold = Color3.fromRGB(255, 205, 70),
	Danger = Color3.fromRGB(255, 80, 80),
	Muted = Color3.fromRGB(200, 195, 230),
	Text = Color3.fromRGB(255, 255, 255),
}

--[[ ───────────── Primitives ───────────── ]]
function UIKit.new(className: string, props: { [string]: any }): any
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
local new = UIKit.new

function UIKit.corner(p: Instance, r: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, r or 14), Parent = p })
end

function UIKit.outline(p: Instance, th: number?, color: Color3?): UIStroke
	return new("UIStroke", { Color = color or UIKit.INK, Thickness = th or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round, Parent = p })
end

function UIKit.textOutline(p: Instance, th: number?): UIStroke
	return new("UIStroke", { Color = UIKit.INK, Thickness = th or 2.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = p })
end

function UIKit.grad(p: Instance, a: Color3, b: Color3, rot: number?): UIGradient
	return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90, Parent = p })
end

function UIKit.pair(p: Instance, pair: { Color3 }, rot: number?): UIGradient
	return UIKit.grad(p, pair[1], pair[2], rot)
end

function UIKit.darker(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

function UIKit.lighter(c: Color3, k: number): Color3
	return c:Lerp(UIKit.WHITE, k)
end

-- paire de dégradé dérivée d'une couleur (pour les raretés, zones…)
function UIKit.pairOf(c: Color3): { Color3 }
	return { UIKit.lighter(c, 0.3), UIKit.darker(c, 0.6) }
end

function UIKit.label(parent: Instance?, text: string, size: number, props: { [string]: any }?): TextLabel
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		FontFace = UIKit.FONT_TITLE,
		TextColor3 = UIKit.WHITE,
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

-- texte titre contouré (raccourci)
function UIKit.title(parent: Instance?, text: string, size: number, props: { [string]: any }?): TextLabel
	local t = UIKit.label(parent, text, size, props)
	UIKit.textOutline(t, math.clamp(size / 9, 1.5, 4))
	return t
end

function UIKit.fmtTime(s: number): string
	s = math.max(0, math.floor(s))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

--[[ ───────────── Animations ───────────── ]]
function UIKit.pop(target: GuiObject | UIScale, amount: number?)
	local sc: UIScale
	if target:IsA("UIScale") then
		sc = target
	else
		sc = target:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = target })
	end
	sc.Scale = 1 + (amount or 0.15)
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- reflet qui balaie un élément (bande blanche via UIGradient.Offset)
function UIKit.shine(parent: GuiObject, period: number, radius: number?)
	local s = new("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = parent.ZIndex + 3, Parent = parent })
	UIKit.corner(s, radius or 16)
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
	return s
end

-- survol = grossit, clic = écrase puis rebondit
function UIKit.juicy(btn: GuiButton, onClick: (() -> ())?)
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
		if onClick then
			onClick()
		end
	end)
end

--[[ ───────────── Composants ───────────── ]]
-- carte « bonbon » : dégradé + gros contour + coins ronds
function UIKit.card(parent: Instance?, pair: { Color3 }, props: { [string]: any }?, radius: number?, stroke: number?): Frame
	local f = new("Frame", { BackgroundColor3 = UIKit.WHITE, BorderSizePixel = 0, Parent = parent })
	if props then
		for k, v in props do
			(f :: any)[k] = v
		end
	end
	UIKit.corner(f, radius or 16)
	UIKit.outline(f, stroke or 3.5)
	UIKit.pair(f, pair)
	return f
end

export type Button = TextButton & { Label: TextLabel }

function UIKit.candyButton(parent: Instance?, text: string, pair: { Color3 }, size: UDim2, onClick: (() -> ())?, textSize: number?): TextButton
	local btn = new("TextButton", { Name = "Button", AutoButtonColor = false, Text = "", BackgroundColor3 = UIKit.WHITE, Size = size, Parent = parent })
	UIKit.corner(btn, 14)
	UIKit.outline(btn, 3.5)
	UIKit.pair(btn, pair)
	-- liseré clair en haut (volume)
	local gloss = new("Frame", { Name = "Gloss", BackgroundColor3 = UIKit.WHITE, BackgroundTransparency = 0.75, BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 0.36, 0), Parent = btn })
	UIKit.corner(gloss, 10)
	local t = UIKit.title(btn, text, textSize or 22, { Name = "Label", Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = textSize or 22, Parent = t })
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = t })
	UIKit.juicy(btn, onClick)
	return btn
end

function UIKit.setButton(btn: TextButton, text: string?, pair: { Color3 }?, enabled: boolean?)
	local lbl = btn:FindFirstChild("Label") :: TextLabel?
	if lbl and text then
		lbl.Text = text
	end
	local g = btn:FindFirstChildOfClass("UIGradient")
	if g and pair then
		g.Color = ColorSequence.new(pair[1], pair[2])
	end
	if enabled ~= nil then
		btn.Active = enabled
		btn.AutoButtonColor = false
	end
end

-- jauge : renvoie une fonction set(ratio, texte?)
function UIKit.bar(parent: Instance, pos: UDim2, size: UDim2, pair: { Color3 }): (Frame, (number, string?) -> ())
	local back = new("Frame", { Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(20, 14, 38), Parent = parent })
	UIKit.corner(back, 99)
	UIKit.outline(back, 3)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = UIKit.WHITE, Parent = back })
	UIKit.corner(fill, 99)
	UIKit.pair(fill, pair)
	local gloss = new("Frame", { BackgroundColor3 = UIKit.WHITE, BackgroundTransparency = 0.7, BorderSizePixel = 0, Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(1, -8, 0.35, 0), Parent = fill })
	UIKit.corner(gloss, 99)
	local txt = UIKit.title(back, "", 14, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = back.ZIndex + 2 })
	local function set(ratio: number, text: string?)
		TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(ratio, 0.04, 1), 1) }):Play()
		if text then
			txt.Text = text
		end
	end
	return back, set
end

-- pastille (icône + texte), pour les infos courtes
function UIKit.chip(parent: Instance?, text: string, pair: { Color3 }, size: UDim2, textSize: number?): (Frame, TextLabel)
	local f = UIKit.card(parent, pair, { Size = size }, 99, 3)
	local t = UIKit.title(f, text, textSize or 16, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = textSize or 16, Parent = t })
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = t })
	return f, t
end

-- badge rond avec une icône (emoji)
function UIKit.badge(parent: Instance?, icon: string, pair: { Color3 }, px: number): Frame
	local f = UIKit.card(parent, pair, { Size = UDim2.fromOffset(px, px) }, px, 3)
	UIKit.label(f, icon, math.floor(px * 0.55), { FontFace = UIKit.FONT_BOLD, Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center })
	return f
end

--[[ ───────────── Écrans responsive ───────────── ]]
local player = Players.LocalPlayer
local scales: { UIScale } = {}
local function rescaleAll()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local v = cam.ViewportSize
	local s = math.clamp(math.min(v.X / 1280, v.Y / 760), 0.55, 1.15)
	for _, sc in scales do
		sc.Scale = s
	end
end
task.spawn(function()
	local cam = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")
	;(cam :: Camera):GetPropertyChangedSignal("ViewportSize"):Connect(rescaleAll)
end)

function UIKit.scale(): number
	return if scales[1] then scales[1].Scale else 1
end

function UIKit.screen(name: string, displayOrder: number): ScreenGui
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local gui = new("ScreenGui", { Name = name, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = displayOrder, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	local sc = new("UIScale", { Parent = gui })
	table.insert(scales, sc)
	rescaleAll()
	return gui
end

--[[ ───────────── Modales (une à la fois) ───────────── ]]
local modalGui: ScreenGui? = nil
local backdrop: TextButton? = nil
local openModal: Frame? = nil
local onCloseHooks: { [Frame]: () -> () } = {}

local function modalLayer(): (ScreenGui, TextButton)
	if modalGui and modalGui.Parent and backdrop then
		return modalGui, backdrop
	end
	local g = UIKit.screen("SAS_Modals", 30)
	local b = new("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 1, Parent = g })
	b.Activated:Connect(function()
		UIKit.closeModal()
	end)
	modalGui, backdrop = g, b
	return g, b
end

function UIKit.isOpen(m: Frame?): boolean
	if m then
		return openModal == m
	end
	return openModal ~= nil
end

function UIKit.closeModal()
	local m = openModal
	if not m then
		return
	end
	openModal = nil
	local _, b = modalLayer()
	local sc = m:FindFirstChildOfClass("UIScale") :: UIScale
	TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
	TweenService:Create(b, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
	local hook = onCloseHooks[m]
	if hook then
		task.spawn(hook)
	end
	task.delay(0.16, function()
		if openModal ~= m then
			m.Visible = false
		end
		if not openModal then
			b.Visible = false
		end
	end)
end

function UIKit.showModal(m: Frame)
	local _, b = modalLayer()
	if openModal and openModal ~= m then
		openModal.Visible = false
	end
	openModal = m
	b.Visible = true
	m.Visible = true
	local sc = m:FindFirstChildOfClass("UIScale") :: UIScale
	sc.Scale = 0.75
	TweenService:Create(sc, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(b, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
end

export type ModalApi = { Frame: Frame, Body: Frame, Header: Frame, Title: TextLabel, Icon: TextLabel, SetTheme: (pair: { Color3 }, icon: string?, title: string?) -> () }

-- Fenêtre modale : en-tête dégradé (icône + titre), bouton X, corps. Une seule ouverte à la fois.
function UIKit.modal(name: string, w: number, h: number, icon: string, title: string, pair: { Color3 }, onClose: (() -> ())?): ModalApi
	local g = modalLayer()
	local m = new("Frame", { Name = name, Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(w, h), BackgroundColor3 = UIKit.WHITE, Visible = false, ZIndex = 21, Parent = g })
	new("UIScale", { Parent = m })
	UIKit.corner(m, 24)
	UIKit.outline(m, 5)
	UIKit.pair(m, UIKit.P.Night)
	-- motif d'écailles en filigrane
	local scales2 = new("Frame", { Name = "Scales", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 21, Parent = m })
	for i = 0, 7 do
		for j = 0, 4 do
			local s = new("Frame", { BackgroundColor3 = UIKit.WHITE, BackgroundTransparency = 0.965, BorderSizePixel = 0, Size = UDim2.fromOffset(46, 46), Position = UDim2.new((i + (j % 2) * 0.5) / 7, -23, j / 4, -23 + 40), Rotation = 45, ZIndex = 21, Parent = scales2 })
			UIKit.corner(s, 10)
		end
	end
	local head = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = UIKit.WHITE, ZIndex = 22, Parent = m })
	UIKit.corner(head, 24)
	local hg = UIKit.pair(head, pair)
	local fill = new("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), BackgroundColor3 = pair[2], BorderSizePixel = 0, ZIndex = 22, Parent = head })
	new("Frame", { Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = UIKit.INK, BorderSizePixel = 0, ZIndex = 22, Parent = head })
	local ic = UIKit.label(head, icon, 40, { FontFace = UIKit.FONT_BOLD, Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(56, 74), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 23 })
	local t = UIKit.title(head, title, 38, { Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(76, 0), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true, ZIndex = 23 })
	new("UITextSizeConstraint", { MaxTextSize = 38, Parent = t })
	local close = new("TextButton", { Name = "Close", AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 14, 0, -14), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = UIKit.WHITE, ZIndex = 30, Parent = m })
	UIKit.corner(close, 16)
	UIKit.outline(close, 4)
	UIKit.pair(close, UIKit.P.Danger)
	UIKit.title(close, "X", 34, { Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 31 })
	UIKit.juicy(close, UIKit.closeModal)
	local body = new("Frame", { Name = "Body", Position = UDim2.fromOffset(20, 90), Size = UDim2.new(1, -40, 1, -108), BackgroundTransparency = 1, ZIndex = 22, Parent = m })
	if onClose then
		onCloseHooks[m] = onClose
	end
	local api: ModalApi = {
		Frame = m,
		Body = body,
		Header = head,
		Title = t,
		Icon = ic,
		SetTheme = function(p: { Color3 }, newIcon: string?, newTitle: string?)
			hg.Color = ColorSequence.new(p[1], p[2])
			fill.BackgroundColor3 = p[2]
			if newIcon then
				ic.Text = newIcon
			end
			if newTitle then
				t.Text = newTitle
			end
		end,
	}
	return api
end

--[[ ───────────── Rail de gauche ───────────── ]]
local railFrame: Frame? = nil
local function rail(): Frame
	if railFrame and railFrame.Parent then
		return railFrame
	end
	local g = UIKit.screen("SAS_Rail", 8)
	local r = new("Frame", { Name = "Rail", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.43, 0), Size = UDim2.fromOffset(176, 470), BackgroundTransparency = 1, Parent = g })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(84, 84), CellPadding = UDim2.fromOffset(4, 4), FillDirection = Enum.FillDirection.Horizontal, FillDirectionMaxCells = 2, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = r })
	railFrame = r
	return r
end

-- Gros bouton du rail : renvoie (bouton, libellé, pastille de notification, conteneur)
function UIKit.railButton(order: number, icon: string, text: string, pair: { Color3 }, onClick: () -> ()): (TextButton, TextLabel, TextLabel, Frame)
	local holder = new("Frame", { Name = text, LayoutOrder = order, Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, Parent = rail() })
	local btn = new("TextButton", { AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = UIKit.WHITE, Parent = holder })
	UIKit.corner(btn, 20)
	UIKit.outline(btn, 4)
	UIKit.pair(btn, pair)
	local gloss = new("Frame", { BackgroundColor3 = UIKit.WHITE, BackgroundTransparency = 0.72, BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 0.38, 0), Parent = btn })
	UIKit.corner(gloss, 14)
	UIKit.label(btn, icon, 34, { FontFace = UIKit.FONT_BOLD, Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Center })
	local t = UIKit.title(holder, text, 14, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 6, 0, 18), TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 14, Parent = t })
	local badge = UIKit.title(btn, "!", 17, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 50, 70), TextYAlignment = Enum.TextYAlignment.Center, Visible = false, ZIndex = 3 })
	UIKit.corner(badge, 13)
	UIKit.outline(badge, 2.5)
	UIKit.juicy(btn, onClick)
	return btn, t, badge, holder
end

--[[ ───────────── Toasts ───────────── ]]
local toastFrame: Frame? = nil
local toastN = 0
function UIKit.toast(msg: string, pair: { Color3 }?, icon: string?)
	if not toastFrame or not toastFrame.Parent then
		local g = UIKit.screen("SAS_Toasts", 25)
		local f = new("Frame", { Name = "Toasts", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(560, 240), BackgroundTransparency = 1, Parent = g })
		new("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
		toastFrame = f
	end
	local f = toastFrame :: Frame
	toastN += 1
	local p = pair or UIKit.P.Gold
	if icon and string.sub(msg, 1, #icon) == icon then
		msg = string.gsub(string.sub(msg, #icon + 1), "^%s+", "")
	end
	local t = UIKit.card(f, { UIKit.darker(p[2], 0.55), UIKit.darker(p[2], 0.35) }, { LayoutOrder = toastN, Size = UDim2.fromOffset(520, 46) }, 99, 3.5)
	;(t:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = p[1]
	local sc = new("UIScale", { Scale = 0.5, Parent = t })
	if icon then
		local b = UIKit.badge(t, icon, p, 40)
		b.AnchorPoint = Vector2.new(0, 0.5)
		b.Position = UDim2.new(0, 3, 0.5, 0)
	end
	local tl = UIKit.title(t, msg, 18, { Position = UDim2.fromOffset(if icon then 50 else 14, 0), Size = UDim2.new(1, if icon then -62 else -28, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true, TextColor3 = UIKit.lighter(p[1], 0.35) })
	new("UITextSizeConstraint", { MaxTextSize = 18, Parent = tl })
	TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local frames = {}
	for _, c in f:GetChildren() do
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
	task.delay(3, function()
		if t.Parent then
			TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
			task.wait(0.27)
			t:Destroy()
		end
	end)
end

return UIKit
