--!strict
--[[
	UI méta Pass 2 — badges rareté, icônes Frames colorées (sans emoji), shop cards premium.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))

local MetaHud = {}

local player = Players.LocalPlayer
local metaRemotes: Remotes.MetaRemotes
local profile: any = nil
local catalog: any = nil
local open = false

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

local function mkButton(parent: Instance, text: string, y: number, callback, accent: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -24, 0, 30)
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

--[[ Icône text-free : Frame colorée + barre catégorie. ]]
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

	-- Accent barre gauche
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

local function mkFormRow(parent: Instance, owned: any, y: number, onEquip): number
	local rarity = tostring(owned.rarity or "Common")
	local rarCol = Theme.rarityColor(rarity)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -24, 0, 36)
	row.Position = UDim2.new(0, 12, 0, y)
	row.BackgroundColor3 = Theme.InkSoft
	row.BorderSizePixel = 0
	row.Parent = parent
	corner(row, 8)
	stroke(row, rarCol, 1).Transparency = 0.4

	mkIcon(row, rarCol, 8, 4, 28)
	mkRarityBadge(row, rarity, 44, 9)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -180, 1, 0)
	label.Position = UDim2.new(0, 124, 0, 0)
	label.Font = Theme.FontBody
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Bone
	label.Text = string.format("%s  ×%d", tostring(owned.formId), owned.count or 1)
	label.Parent = row

	local eq = Instance.new("TextButton")
	eq.Size = UDim2.fromOffset(64, 26)
	eq.Position = UDim2.new(1, -72, 0.5, -13)
	eq.BackgroundColor3 = Theme.Accent
	eq.BorderSizePixel = 0
	eq.Font = Theme.FontBody
	eq.TextSize = 12
	eq.TextColor3 = Theme.Ink
	eq.Text = "ÉQUIPER"
	eq.Parent = row
	corner(eq, 6)
	eq.MouseButton1Click:Connect(onEquip)

	return 42
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
	panel.Size = UDim2.new(0, 380, 0, 460)
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
	content.Size = UDim2.new(1, 0, 0, 1200)
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
		y += 30

		if profile then
			mkText(
				content,
				string.format(
					"Crédits %d · Éclats %d · Fragments %d",
					profile.credits or 0,
					profile.shards or 0,
					profile.fragments or 0
				),
				13,
				y
			)
			y += 20
			local formRarity = tostring(profile.equippedFormRarity or "")
			local formLine = mkText(
				content,
				string.format(
					"MMR %d (%s) · Forme %s",
					profile.mmr or 0,
					profile.rank or "?",
					profile.equippedFormId or "?"
				),
				13,
				y
			)
			formLine.TextColor3 = Theme.Bone
			y += 4
			mkRarityBadge(content, formRarity ~= "" and formRarity or "Common", 12, y + 16)
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
			y += 22
			mkText(
				content,
				string.format(
					"Pity Épique %d/%d · Légendaire %d/%d",
					profile.pityEpic or 0,
					profile.pityEpicAt or 40,
					profile.pityLegendary or 0,
					profile.pityLegendaryAt or 90
				),
				12,
				y
			).TextColor3 =
				Theme.Muted
			y += 26
		end

		mkText(content, "Matchmaking", 15, y).Font = Theme.FontTitle
		y += 22
		mkButton(content, "Queue Casual", y, function()
			metaRemotes.QueueMatch:FireServer({ mode = "Casual" })
		end, Theme.InkSoft)
		y += 36
		mkButton(content, "Queue Ranked (Fair Kit)", y, function()
			metaRemotes.QueueMatch:FireServer({ mode = "Ranked" })
		end, Color3.fromRGB(30, 50, 48))
		y += 42

		mkText(content, "Formes — Banner", 15, y).Font = Theme.FontTitle
		y += 22
		mkButton(content, "Pull ×1 (300 Cr)", y, function()
			metaRemotes.GachaPull:FireServer({ count = 1, premium = false })
		end)
		y += 36
		mkButton(content, "Pull ×10 premium (450 Éclats)", y, function()
			metaRemotes.GachaPull:FireServer({ count = 10, premium = true })
		end, Color3.fromRGB(48, 36, 70))
		y += 36
		mkButton(content, "Ticket free ×10 / semaine", y, function()
			metaRemotes.GachaPull:FireServer({ count = 10, premium = false })
		end)
		y += 42

		if profile and typeof(profile.ownedForms) == "table" then
			mkText(content, "Équiper une forme", 14, y).Font = Theme.FontTitle
			y += 22
			for _, owned in profile.ownedForms do
				local fid, rar = owned.formId, owned.rarity
				y += mkFormRow(content, owned, y, function()
					metaRemotes.EquipLoadout:FireServer({ formId = fid, rarity = rar })
				end)
			end
			y += 8
		end

		mkText(content, "Boutique (cosmétiques)", 15, y).Font = Theme.FontTitle
		y += 22
		mkButton(content, "Stub +100 Éclats Focus", y, function()
			metaRemotes.ShopPurchase:FireServer({ stubShards = true })
		end)
		y += 36
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

		mkText(content, "Quêtes journalières", 15, y).Font = Theme.FontTitle
		y += 22
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
				y += 34
			end
		end
		y += 12

		mkText(content, "Factions", 15, y).Font = Theme.FontTitle
		y += 22
		mkButton(content, "Rejoindre Ordre de l'Aube", y, function()
			metaRemotes.SelectFaction:FireServer({ factionId = "Dawn" })
		end, Color3.fromRGB(60, 45, 28))
		y += 36
		mkButton(content, "Rejoindre Voie du Crépuscule", y, function()
			metaRemotes.SelectFaction:FireServer({ factionId = "Dusk" })
		end, Color3.fromRGB(40, 28, 60))
		y += 40

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
		rebuild()
	end)

	rebuild()
end

return MetaHud
