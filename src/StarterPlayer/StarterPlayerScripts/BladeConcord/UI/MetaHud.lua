--!strict
--[[
	UI méta soignée — boutique, banner formes, quêtes, factions, queue.
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

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1
	s.Transparency = 0.4
	s.Parent = parent
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
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Theme.PanelEdge }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = accent or Theme.InkSoft }):Play()
	end)
	return b
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
	stroke(toggle, Theme.Accent)

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -16, 1, -64)
	panel.Size = UDim2.new(0, 360, 0, 440)
	panel.BackgroundColor3 = Theme.Ink
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ScrollBarThickness = 3
	panel.ScrollBarImageColor3 = Theme.Accent
	panel.CanvasSize = UDim2.new(0, 0, 0, 900)
	panel.Parent = gui
	corner(panel, 14)
	stroke(panel, Theme.PanelEdge)

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 4)
	header.BackgroundColor3 = Theme.Accent
	header.BorderSizePixel = 0
	header.Parent = panel

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 0, 880)
	content.BackgroundTransparency = 1
	content.Parent = panel

	local function setOpen(v: boolean)
		open = v
		panel.Visible = v
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
			mkText(
				content,
				string.format(
					"MMR %d (%s) · Forme %s %s",
					profile.mmr or 0,
					profile.rank or "?",
					profile.equippedFormId or "?",
					profile.equippedFormRarity or ""
				),
				13,
				y
			)
			y += 20
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
				local label = string.format("%s %s (×%d)", owned.formId, owned.rarity, owned.count or 1)
				local fid, rar = owned.formId, owned.rarity
				mkButton(content, label, y, function()
					metaRemotes.EquipLoadout:FireServer({ formId = fid, rarity = rar })
				end)
				y += 34
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
				local price = if item.softPrice
					then (tostring(item.softPrice) .. " Cr")
					else ((tostring(item.premiumPrice or "?") .. " Éclats"))
				local id = item.id
				local usePrem = item.softPrice == nil
				mkButton(content, string.format("%s — %s", item.displayName, price), y, function()
					metaRemotes.ShopPurchase:FireServer({ itemId = id, premium = usePrem })
				end)
				y += 34
			end
		end
		y += 12

		mkText(content, "Quêtes journalières", 15, y).Font = Theme.FontTitle
		y += 22
		if profile and typeof(profile.dailyQuests) == "table" then
			for _, q in profile.dailyQuests do
				local st = if q.claimed then "✓" else string.format("%d", q.progress or 0)
				local qid = q.id
				mkButton(content, string.format("[%s] %s — claim", st, qid), y, function()
					metaRemotes.ClaimQuest:FireServer({ questId = qid })
				end)
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
