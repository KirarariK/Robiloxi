--!strict
--[[
	UI méta : boutique, banner formes, quêtes, factions, queue Casual/Ranked.
	Assets limités → stubs textuels.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local MetaHud = {}

local player = Players.LocalPlayer
local metaRemotes: Remotes.MetaRemotes
local profile: any = nil
local catalog: any = nil
local open = false

local function mkText(parent: Instance, text: string, size: number, y: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -16, 0, size + 4)
	t.Position = UDim2.new(0, 8, 0, y)
	t.Font = Enum.Font.Gotham
	t.TextSize = size
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Color3.fromRGB(230, 230, 240)
	t.Text = text
	t.Parent = parent
	return t
end

local function mkButton(parent: Instance, text: string, y: number, callback): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -16, 0, 28)
	b.Position = UDim2.new(0, 8, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = parent
	b.MouseButton1Click:Connect(callback)
	return b
end

function MetaHud.start()
	metaRemotes = Remotes.getMeta()

	local gui = Instance.new("ScreenGui")
	gui.Name = "BladeConcordMeta"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name = "ToggleMeta"
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -16, 1, -16)
	toggle.Size = UDim2.new(0, 120, 0, 36)
	toggle.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 14
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Text = "Méta (M)"
	toggle.Parent = gui

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -16, 1, -60)
	panel.Size = UDim2.new(0, 340, 0, 420)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ScrollBarThickness = 4
	panel.CanvasSize = UDim2.new(0, 0, 0, 900)
	panel.Parent = gui

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
		local y = 8
		local title = mkText(content, "Blade Concord — Méta", 18, y)
		title.Font = Enum.Font.GothamBold
		y += 28

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
			if profile.faction == "Dawn" then
				factionName = "Ordre de l'Aube"
			elseif profile.faction == "Dusk" then
				factionName = "Voie du Crépuscule"
			end
			mkText(content, "Faction : " .. factionName, 13, y)
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
			)
			y += 24
		end

		mkText(content, "Matchmaking", 15, y).Font = Enum.Font.GothamBold
		y += 22
		mkButton(content, "Queue Casual", y, function()
			metaRemotes.QueueMatch:FireServer({ mode = "Casual" })
		end)
		y += 34
		mkButton(content, "Queue Ranked (Fair Kit)", y, function()
			metaRemotes.QueueMatch:FireServer({ mode = "Ranked" })
		end)
		y += 40

		mkText(content, "Formes — Banner", 15, y).Font = Enum.Font.GothamBold
		y += 22
		mkButton(content, "Pull ×1 (300 Cr)", y, function()
			metaRemotes.GachaPull:FireServer({ count = 1, premium = false })
		end)
		y += 34
		mkButton(content, "Pull ×10 premium (450 Éclats)", y, function()
			metaRemotes.GachaPull:FireServer({ count = 10, premium = true })
		end)
		y += 34
		mkButton(content, "Ticket free ×10 / semaine", y, function()
			metaRemotes.GachaPull:FireServer({ count = 10, premium = false })
		end)
		y += 40

		if profile and typeof(profile.ownedForms) == "table" then
			mkText(content, "Équiper une forme", 14, y).Font = Enum.Font.GothamBold
			y += 22
			for _, owned in profile.ownedForms do
				local label = string.format("%s %s (×%d)", owned.formId, owned.rarity, owned.count or 1)
				local fid, rar = owned.formId, owned.rarity
				mkButton(content, label, y, function()
					metaRemotes.EquipLoadout:FireServer({ formId = fid, rarity = rar })
				end)
				y += 32
			end
			y += 8
		end

		mkText(content, "Boutique (cosmétiques)", 15, y).Font = Enum.Font.GothamBold
		y += 22
		mkButton(content, "Stub +100 Éclats Focus", y, function()
			metaRemotes.ShopPurchase:FireServer({ stubShards = true })
		end)
		y += 34
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
				y += 32
			end
		end
		y += 12

		mkText(content, "Quêtes journalières", 15, y).Font = Enum.Font.GothamBold
		y += 22
		if profile and typeof(profile.dailyQuests) == "table" then
			for _, q in profile.dailyQuests do
				local st = if q.claimed then "✓" else string.format("%d", q.progress or 0)
				local qid = q.id
				mkButton(content, string.format("[%s] %s — claim", st, qid), y, function()
					metaRemotes.ClaimQuest:FireServer({ questId = qid })
				end)
				y += 32
			end
		end
		y += 12

		mkText(content, "Factions", 15, y).Font = Enum.Font.GothamBold
		y += 22
		mkButton(content, "Rejoindre Ordre de l'Aube", y, function()
			metaRemotes.SelectFaction:FireServer({ factionId = "Dawn" })
		end)
		y += 34
		mkButton(content, "Rejoindre Voie du Crépuscule", y, function()
			metaRemotes.SelectFaction:FireServer({ factionId = "Dusk" })
		end)
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
