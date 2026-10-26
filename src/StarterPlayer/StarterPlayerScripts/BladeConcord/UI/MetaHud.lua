--!strict
--[[
	UI méta — panneau M clarifié : gacha/pity, formes, Fair Kit Ranked, boutique.
	Vague 6 : premier choix faction Aube / Crépuscule (modal first-time).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))
local FormConfig = require(Shared:WaitForChild("FormConfig"))
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))

local MetaHud = {}

local player = Players.LocalPlayer
local metaRemotes: Remotes.MetaRemotes
local profile: any = nil
local catalog: any = nil
local lastPullFlash: string? = nil
local warScore: { Dawn: number, Dusk: number }? = nil
local open = false
local factionPromptShown = false
local factionOverlay: Frame? = nil

local CATEGORY_COLOR: { [string]: Color3 } = {
	BladeColor = Theme.Accent,
	Hilt = Color3.fromRGB(180, 150, 90),
	Aura = Theme.Focus,
	Skin = Theme.Dawn,
	Emote = Theme.Success,
	Finisher = Theme.AccentHot,
}

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = 0.35
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, c0: Color3, c1: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = 90
	g.Parent = parent
	return g
end

local function mkText(parent: Instance, text: string, size: number, y: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -20, 0, size + 6)
	t.Position = UDim2.new(0, 12, 0, y)
	t.Font = Theme.FontBody
	t.TextSize = size
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Theme.Bone
	t.Text = text
	t.Parent = parent
	return t
end

local function mkSection(parent: Instance, title: string, hint: string, y: number): number
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -24, 0, if hint ~= "" then 44 else 28)
	bar.Position = UDim2.new(0, 12, 0, y)
	bar.BackgroundColor3 = Theme.InkSoft
	bar.BorderSizePixel = 0
	bar.Parent = parent
	corner(bar, 8)
	stroke(bar, Theme.PanelEdge, 1).Transparency = 0.55

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 3, 1, -8)
	accent.Position = UDim2.new(0, 4, 0, 4)
	accent.BackgroundColor3 = Theme.Accent
	accent.BorderSizePixel = 0
	accent.Parent = bar
	corner(accent, 2)

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -20, 0, 20)
	t.Position = UDim2.new(0, 14, 0, 4)
	t.Font = Theme.FontTitle
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Theme.Bone
	t.Text = title
	t.Parent = bar

	if hint ~= "" then
		local h = Instance.new("TextLabel")
		h.BackgroundTransparency = 1
		h.Size = UDim2.new(1, -20, 0, 16)
		h.Position = UDim2.new(0, 14, 0, 24)
		h.Font = Theme.FontBody
		h.TextSize = 11
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.TextColor3 = Theme.Muted
		h.Text = hint
		h.Parent = bar
		return 52
	end
	return 36
end

local function mkButton(parent: Instance, text: string, y: number, callback, accent: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -24, 0, 32)
	b.Position = UDim2.new(0, 12, 0, y)
	b.BackgroundColor3 = accent or Theme.InkSoft
	b.BorderSizePixel = 0
	b.Font = Theme.FontBody
	b.TextSize = 13
	b.TextColor3 = Theme.Bone
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 7)
	stroke(b, Theme.PanelEdge)
	b.MouseButton1Click:Connect(callback)
	local base = accent or Theme.InkSoft
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Theme.PanelEdge }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	return b
end

local function mkIcon(parent: Instance, color: Color3, x: number, y: number, size: number?): Frame
	local s = size or 28
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(s, s)
	f.Position = UDim2.new(0, x, 0, y)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f, 6)
	stroke(f, Color3.new(1, 1, 1), 1).Transparency = 0.7
	local inner = Instance.new("Frame")
	inner.Size = UDim2.new(0.45, 0, 0.45, 0)
	inner.Position = UDim2.new(0.28, 0, 0.28, 0)
	inner.BackgroundColor3 = Color3.new(1, 1, 1)
	inner.BackgroundTransparency = 0.55
	inner.BorderSizePixel = 0
	inner.Parent = f
	corner(inner, 3)
	return f
end

local function mkRarityBadge(parent: Instance, rarity: string, x: number, y: number): Frame
	local col = Theme.rarityColor(rarity)
	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromOffset(72, 18)
	badge.Position = UDim2.new(0, x, 0, y)
	badge.BackgroundColor3 = col
	badge.BorderSizePixel = 0
	badge.Parent = parent
	corner(badge, 4)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.FontBody
	label.TextSize = 11
	label.TextColor3 = Theme.Ink
	label.Text = string.upper(rarity)
	label.Parent = badge
	return badge
end

local function mkPityBar(parent: Instance, label: string, current: number, maxN: number, color: Color3, y: number): number
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, -24, 0, 36)
	wrap.Position = UDim2.new(0, 12, 0, y)
	wrap.BackgroundTransparency = 1
	wrap.Parent = parent

	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 0, 14)
	caption.Font = Theme.FontBody
	caption.TextSize = 11
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextColor3 = Theme.Muted
	caption.Text = string.format("%s  %d / %d", label, current, maxN)
	caption.Parent = wrap

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 10)
	track.Position = UDim2.new(0, 0, 0, 18)
	track.BackgroundColor3 = Theme.InkSoft
	track.BorderSizePixel = 0
	track.Parent = wrap
	corner(track, 4)

	local fill = Instance.new("Frame")
	local pct = if maxN > 0 then math.clamp(current / maxN, 0, 1) else 0
	fill.Size = UDim2.new(pct, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 4)

	return 42
end

local function mkShopCard(parent: Instance, item: any, y: number, onBuy): number
	local rarity = tostring(item.rarity or "Common")
	local rarCol = Theme.rarityColor(rarity)
	local catCol = CATEGORY_COLOR[tostring(item.category)] or Theme.Accent
	local cardH = 64

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -24, 0, cardH)
	card.Position = UDim2.new(0, 12, 0, y)
	card.BackgroundColor3 = Theme.Panel
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card, 10)
	local edge = stroke(card, rarCol, 1.5)
	edge.Transparency = 0.25
	gradient(card, Theme.Panel, Theme.InkSoft)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 4, 1, -8)
	bar.Position = UDim2.new(0, 4, 0, 4)
	bar.BackgroundColor3 = rarCol
	bar.BorderSizePixel = 0
	bar.Parent = card
	corner(bar, 2)

	mkIcon(card, catCol, 16, 18, 28)
	mkRarityBadge(card, rarity, 52, 8)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -140, 0, 20)
	name.Position = UDim2.new(0, 52, 0, 28)
	name.Font = Theme.FontTitle
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Theme.Bone
	name.Text = tostring(item.displayName or item.id)
	name.Parent = card

	local price = if item.softPrice
		then (tostring(item.softPrice) .. " Cr")
		else ((tostring(item.premiumPrice or "?") .. " Éclats"))
	local priceLbl = Instance.new("TextLabel")
	priceLbl.BackgroundTransparency = 1
	priceLbl.Size = UDim2.new(1, -140, 0, 16)
	priceLbl.Position = UDim2.new(0, 52, 0, 46)
	priceLbl.Font = Theme.FontBody
	priceLbl.TextSize = 12
	priceLbl.TextXAlignment = Enum.TextXAlignment.Left
	priceLbl.TextColor3 = Theme.Muted
	priceLbl.Text = price .. " · " .. tostring(item.category or "")
	priceLbl.Parent = card

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.fromOffset(72, 32)
	buy.Position = UDim2.new(1, -84, 0.5, -16)
	buy.BackgroundColor3 = rarCol
	buy.BorderSizePixel = 0
	buy.Font = Theme.FontTitle
	buy.TextSize = 12
	buy.TextColor3 = Theme.Ink
	buy.Text = "ACHETER"
	buy.Parent = card
	corner(buy, 7)
	buy.MouseButton1Click:Connect(onBuy)
	buy.MouseEnter:Connect(function()
		TweenService:Create(buy, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Bone }):Play()
	end)
	buy.MouseLeave:Connect(function()
		TweenService:Create(buy, TweenInfo.new(0.1), { BackgroundColor3 = rarCol }):Play()
	end)

	return cardH + 8
end

local function formDisplayName(formId: string): string
	local def = FormConfig.Forms[formId]
	if def and typeof(def.displayName) == "string" then
		return def.displayName
	end
	return formId
end

local function mkFormRow(parent: Instance, owned: any, y: number, equipped: boolean, onEquip): number
	local rarity = tostring(owned.rarity or "Common")
	local rarCol = Theme.rarityColor(rarity)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -24, 0, 44)
	row.Position = UDim2.new(0, 12, 0, y)
	row.BackgroundColor3 = if equipped then Color3.fromRGB(28, 42, 52) else Theme.InkSoft
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, 8)
	stroke(row, if equipped then Theme.Accent else rarCol, if equipped then 1.5 else 1).Transparency = if equipped
		then 0.15
		else 0.4

	mkIcon(row, rarCol, 8, 8, 28)
	mkRarityBadge(row, rarity, 44, 4)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -180, 0, 20)
	label.Position = UDim2.new(0, 124, 0, 4)
	label.Font = Theme.FontTitle
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Bone
	label.Text = formDisplayName(tostring(owned.formId))
	label.Parent = row

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -180, 0, 16)
	sub.Position = UDim2.new(0, 124, 0, 24)
	sub.Font = Theme.FontBody
	sub.TextSize = 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Theme.Muted
	sub.Text = string.format("×%d  ·  tempo %s", owned.count or 1, (FormConfig.Forms[owned.formId] and FormConfig.Forms[owned.formId].tempo) or "—")
	sub.Parent = row

	local eq = Instance.new("TextButton")
	eq.Size = UDim2.fromOffset(72, 28)
	eq.Position = UDim2.new(1, -80, 0.5, -14)
	eq.BackgroundColor3 = if equipped then Theme.Success else Theme.Accent
	eq.BorderSizePixel = 0
	eq.Font = Theme.FontBody
	eq.TextSize = 12
	eq.TextColor3 = Theme.Ink
	eq.Text = if equipped then "ÉQUIPÉE" else "ÉQUIPER"
	eq.Parent = row
	corner(eq, 6)
	if not equipped then
		eq.MouseButton1Click:Connect(onEquip)
	end

	return 50
end

local function hideFactionPrompt()
	if factionOverlay then
		local ov = factionOverlay
		factionOverlay = nil
		TweenService:Create(ov, TweenInfo.new(0.22), { BackgroundTransparency = 1 }):Play()
		task.delay(0.25, function()
			ov:Destroy()
		end)
	end
end

local function showFactionPrompt(parentGui: ScreenGui)
	if factionPromptShown or factionOverlay then
		return
	end
	if profile and typeof(profile.faction) == "string" and profile.faction ~= "" then
		return
	end
	factionPromptShown = true

	local overlay = Instance.new("Frame")
	overlay.Name = "FactionFirstPick"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Ink
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 80
	overlay.Parent = parentGui
	factionOverlay = overlay

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.48)
	card.Size = UDim2.new(0, 420, 0, 280)
	card.BackgroundColor3 = Theme.Panel
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.ZIndex = 81
	card.Parent = overlay
	corner(card, 14)
	stroke(card, Theme.Accent, 1.5)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 24, 0, 20)
	title.Size = UDim2.new(1, -48, 0, 28)
	title.Font = Theme.FontTitle
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Bone
	title.Text = "Choisis ta faction"
	title.ZIndex = 82
	title.Parent = card

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 24, 0, 52)
	sub.Size = UDim2.new(1, -48, 0, 40)
	sub.Font = Theme.FontBody
	sub.TextSize = 13
	sub.TextWrapped = true
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextYAlignment = Enum.TextYAlignment.Top
	sub.TextColor3 = Theme.Muted
	sub.Text = "Choix unique — Ordre de l'Aube ou Voie du Crépuscule. Modifie la vignette HUD."
	sub.ZIndex = 82
	sub.Parent = card

	local function pick(factionId: string, label: string, color: Color3, y: number)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -48, 0, 52)
		b.Position = UDim2.new(0, 24, 0, y)
		b.BackgroundColor3 = color
		b.BorderSizePixel = 0
		b.Font = Theme.FontTitle
		b.TextSize = 16
		b.TextColor3 = Theme.Bone
		b.Text = label
		b.ZIndex = 82
		b.Parent = card
		corner(b, 10)
		stroke(b, Theme.Bone, 1).Transparency = 0.55
		b.MouseButton1Click:Connect(function()
			b.Text = "…"
			metaRemotes.SelectFaction:FireServer({ factionId = factionId })
			hideFactionPrompt()
		end)
	end

	pick("Dawn", "Ordre de l'Aube", Color3.fromRGB(70, 48, 28), 110)
	pick("Dusk", "Voie du Crépuscule", Color3.fromRGB(42, 28, 68), 176)

	card.Size = UDim2.new(0, 360, 0, 240)
	TweenService:Create(card, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 420, 0, 280),
	}):Play()
end

function MetaHud.start()
	metaRemotes = Remotes.getMeta()

	local gui = Instance.new("ScreenGui")
	gui.Name = "BladeConcordMeta"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 25
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name = "ToggleMeta"
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -16, 1, -16)
	toggle.Size = UDim2.new(0, 132, 0, 40)
	toggle.BackgroundColor3 = Theme.Panel
	toggle.BorderSizePixel = 0
	toggle.Font = Theme.FontTitle
	toggle.TextSize = 14
	toggle.TextColor3 = Theme.Bone
	toggle.Text = "MÉTA  [M]"
	toggle.Parent = gui
	corner(toggle, 10)
	stroke(toggle, Theme.Accent, 1.5)

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -16, 1, -64)
	panel.Size = UDim2.new(0, 400, 0, 500)
	panel.BackgroundColor3 = Theme.Ink
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ScrollBarThickness = 3
	panel.ScrollBarImageColor3 = Theme.Accent
	panel.CanvasSize = UDim2.new(0, 0, 0, 900)
	panel.Parent = gui
	corner(panel, 14)
	stroke(panel, Theme.PanelEdge, 1.5)

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 4)
	header.BackgroundColor3 = Theme.Accent
	header.BorderSizePixel = 0
	header.Parent = panel

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 0, 1400)
	content.BackgroundTransparency = 1
	content.Parent = panel

	local SoundHooks: any = nil
	pcall(function()
		SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))
	end)

	local function setOpen(v: boolean)
		open = v
		panel.Visible = v
		if v and SoundHooks then
			SoundHooks.play("Ui")
		end
	end

	toggle.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			setOpen(not open)
		end
	end)

	local function rebuild()
		content:ClearAllChildren()
		local y = 14
		local title = mkText(content, Theme.Brand .. " — Méta", 18, y)
		title.Font = Theme.FontTitle
		title.TextColor3 = Theme.Accent
		y += 28

		-- Profil résumé
		if profile then
			y += mkSection(content, "Profil", "Devises · rang · forme équipée", y)
			mkText(
				content,
				string.format(
					"Crédits %d  ·  Éclats %d  ·  Fragments %d",
					profile.credits or 0,
					profile.shards or 0,
					profile.fragments or 0
				),
				13,
				y
			)
			y += 20
			local formRarity = tostring(profile.equippedFormRarity or "Common")
			mkText(
				content,
				string.format(
					"MMR %d (%s)  ·  Forme %s",
					profile.mmr or 0,
					profile.rank or "?",
					formDisplayName(tostring(profile.equippedFormId or "?"))
				),
				13,
				y
			)
			y += 4
			mkRarityBadge(content, formRarity, 12, y + 16)
			y += 40

			local factionName = "—"
			local factionColor = Theme.Muted
			if profile.faction == "Dawn" then
				factionName = "Ordre de l'Aube"
				factionColor = Theme.Dawn
			elseif profile.faction == "Dusk" then
				factionName = "Voie du Crépuscule"
				factionColor = Theme.Dusk
			end
			local fac = mkText(content, "Faction : " .. factionName, 13, y)
			fac.TextColor3 = factionColor
			y += 24
		end

		-- Matchmaking + Fair Kit
		y += mkSection(
			content,
			"Matchmaking",
			"Amical = stats full · Classé = " .. RankedConfig.FairKitBadge
		)
		mkButton(content, "File Amical", y, function()
			metaRemotes.QueueMatch:FireServer({ mode = "Casual" })
		end, Theme.InkSoft)
		y += 38

		-- Callout Fair Kit
		local fair = Instance.new("Frame")
		fair.Size = UDim2.new(1, -24, 0, 68)
		fair.Position = UDim2.new(0, 12, 0, y)
		fair.BackgroundColor3 = Color3.fromRGB(22, 40, 38)
		fair.BorderSizePixel = 0
		fair.Parent = content
		corner(fair, 8)
		stroke(fair, Theme.Success, 1.2).Transparency = 0.25
		local fairTitle = Instance.new("TextLabel")
		fairTitle.BackgroundTransparency = 1
		fairTitle.Size = UDim2.new(1, -16, 0, 18)
		fairTitle.Position = UDim2.new(0, 10, 0, 6)
		fairTitle.Font = Theme.FontTitle
		fairTitle.TextSize = 13
		fairTitle.TextXAlignment = Enum.TextXAlignment.Left
		fairTitle.TextColor3 = Theme.Success
		fairTitle.Text = RankedConfig.FairKitBadge .. "  ·  " .. RankedConfig.FairKitStatsLabel
		fairTitle.Parent = fair
		local fairBody = Instance.new("TextLabel")
		fairBody.BackgroundTransparency = 1
		fairBody.Size = UDim2.new(1, -16, 0, 36)
		fairBody.Position = UDim2.new(0, 10, 0, 26)
		fairBody.Font = Theme.FontBody
		fairBody.TextSize = 11
		fairBody.TextXAlignment = Enum.TextXAlignment.Left
		fairBody.TextYAlignment = Enum.TextYAlignment.Top
		fairBody.TextWrapped = true
		fairBody.TextColor3 = Theme.Muted
		fairBody.Text =
			"En Classé, les passifs stats sont plafonnés Rare. Épique / Légendaire restent cosmétiques (pas de P2W)."
		fairBody.Parent = fair
		y += 76

		mkButton(content, "File Classé (Fair Kit)", y, function()
			metaRemotes.QueueMatch:FireServer({ mode = "Ranked" })
		end, Color3.fromRGB(30, 50, 48))
		y += 44

		-- Gacha
		y += mkSection(content, "Gacha — Banner formes", "Pity soft · rates affichés · feedback pull")
		if profile then
			y += mkPityBar(
				content,
				"Pity Épique",
				profile.pityEpic or 0,
				profile.pityEpicAt or FormConfig.PityEpic,
				Theme.RarityEpic,
				y
			)
			y += mkPityBar(
				content,
				"Pity Légendaire",
				profile.pityLegendary or 0,
				profile.pityLegendaryAt or FormConfig.PityLegendary,
				Theme.RarityLegendary,
				y
			)
		end
		local rates = mkText(
			content,
			string.format(
				"Rates · C %.0f%%  R %.0f%%  E %.0f%%  L %.0f%%",
				FormConfig.DropRates.Common * 100,
				FormConfig.DropRates.Rare * 100,
				FormConfig.DropRates.Epic * 100,
				FormConfig.DropRates.Legendary * 100
			),
			11,
			y
		)
		rates.TextColor3 = Theme.Muted
		y += 20

		if lastPullFlash then
			local flash = mkText(content, "Dernier pull : " .. lastPullFlash, 12, y)
			flash.TextColor3 = Theme.Perfect
			y += 20
		end

		mkButton(content, "Pull ×1  —  300 Crédits", y, function()
			lastPullFlash = "×1 soft…"
			metaRemotes.GachaPull:FireServer({ count = 1, premium = false })
		end)
		y += 38
		mkButton(content, "Pull ×10 premium  —  450 Éclats", y, function()
			lastPullFlash = "×10 premium…"
			metaRemotes.GachaPull:FireServer({ count = 10, premium = true })
		end, Color3.fromRGB(48, 36, 70))
		y += 38
		mkButton(content, "Ticket free ×10 / semaine", y, function()
			lastPullFlash = "ticket free…"
			metaRemotes.GachaPull:FireServer({ count = 10, premium = false })
		end)
		y += 44

		-- Formes
		y += mkSection(content, "Formes possédées", "Équiper change les anims + passifs (Casual full)")
		if profile and typeof(profile.ownedForms) == "table" then
			local eqId = tostring(profile.equippedFormId or "")
			local eqR = tostring(profile.equippedFormRarity or "")
			for _, owned in profile.ownedForms do
				local fid, rar = owned.formId, owned.rarity
				local isEq = tostring(fid) == eqId and tostring(rar) == eqR
				y += mkFormRow(content, owned, y, isEq, function()
					metaRemotes.EquipLoadout:FireServer({ formId = fid, rarity = rar })
				end)
			end
			y += 8
		else
			mkText(content, "Aucune forme — lance un pull", 12, y).TextColor3 = Theme.Muted
			y += 24
		end

		-- Boutique
		y += mkSection(content, "Boutique cosmétiques", "Couleurs lame, hilts, auras — pas de stats")
		mkButton(content, "Stub +100 Éclats Focus", y, function()
			metaRemotes.ShopPurchase:FireServer({ stubShards = true })
		end)
		y += 38
		if typeof(catalog) == "table" then
			for _, item in catalog do
				local id = item.id
				local usePrem = item.softPrice == nil
				y += mkShopCard(content, item, y, function()
					metaRemotes.ShopPurchase:FireServer({ itemId = id, premium = usePrem })
				end)
			end
		end
		y += 12

		-- Quêtes
		y += mkSection(content, "Quêtes journalières", "Claim pour crédits / fragments")
		if profile and typeof(profile.dailyQuests) == "table" then
			for _, q in profile.dailyQuests do
				local done = q.claimed == true
				local st = if done then "OK" else string.format("%d", q.progress or 0)
				local qid = q.id
				local btn = mkButton(content, string.format("[%s] %s — claim", st, qid), y, function()
					metaRemotes.ClaimQuest:FireServer({ questId = qid })
				end, if done then Color3.fromRGB(28, 48, 40) else Theme.InkSoft)
				if done then
					btn.TextColor3 = Theme.Success
				end
				y += 36
			end
		end
		y += 12

		-- Factions
		y += mkSection(content, "Factions", "Choix unique — Aube / Crépuscule")
		if profile and (profile.faction == "Dawn" or profile.faction == "Dusk") then
			mkText(content, "Faction verrouillée — choix tutoriel unique.", 12, y).TextColor3 = Theme.Muted
			y += 22
			if warScore then
				mkText(
					content,
					string.format("War Score  Aube %d · Crépuscule %d", warScore.Dawn or 0, warScore.Dusk or 0),
					12,
					y
				).TextColor3 =
					Theme.Muted
				y += 22
			end
		else
			mkButton(content, "Rejoindre Ordre de l'Aube", y, function()
				metaRemotes.SelectFaction:FireServer({ factionId = "Dawn" })
			end, Color3.fromRGB(60, 45, 28))
			y += 38
			mkButton(content, "Rejoindre Voie du Crépuscule", y, function()
				metaRemotes.SelectFaction:FireServer({ factionId = "Dusk" })
			end, Color3.fromRGB(40, 28, 60))
			y += 40
		end

		content.Size = UDim2.new(1, 0, 0, y + 40)
		panel.CanvasSize = UDim2.new(0, 0, 0, y + 40)
	end

	metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
		end
		if payload.catalog then
			catalog = payload.catalog
		end
		if typeof(payload.warScore) == "table" then
			warScore = payload.warScore
		end
		-- Feedback pull gacha (FormService: kind=GachaResult, data.results)
		-- Défensif : aussi payload.results top-level (anciens payloads / outils)
		if payload.kind == "GachaResult" then
			local data = if typeof(payload.data) == "table" then payload.data else payload
			local results = if typeof(data) == "table" then data.results else nil
			if typeof(results) ~= "table" and typeof(payload.results) == "table" then
				results = payload.results
			end
			if typeof(results) == "table" and #results > 0 then
				local names = {}
				for i, r in results do
					if i > 3 then
						break
					end
					if typeof(r) == "table" then
						table.insert(names, string.format("%s/%s", tostring(r.formId or r.id), tostring(r.rarity or "?")))
					end
				end
				lastPullFlash = if #names > 0 then table.concat(names, " · ") else "Pull OK"
				if #results > 3 then
					lastPullFlash ..= string.format(" (+%d)", #results - 3)
				end
				if SoundHooks then
					SoundHooks.play("Ui")
				end
			elseif typeof(data) == "table" and data.ok == false then
				lastPullFlash = "Échec : " .. tostring(data.error or "?")
			else
				lastPullFlash = lastPullFlash or "Pas de résultat"
			end
		end
		if payload.kind == "Faction" and payload.ok == true then
			hideFactionPrompt()
		end
		-- First-time : modal Aube / Crépuscule si pas encore de faction
		if profile and (profile.faction == nil or profile.faction == "") then
			task.defer(function()
				showFactionPrompt(gui)
			end)
		elseif profile and typeof(profile.faction) == "string" then
			hideFactionPrompt()
		end
		rebuild()
	end)

	rebuild()
end

return MetaHud
