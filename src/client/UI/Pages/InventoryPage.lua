--!strict
-- Page « Inventaire » : onglets Voies (équiper, maîtrise), Titres (équiper, conditions), Emotes (8 emplacements de la roue).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local FormData = require(Shared.Config.FormData)
local TitleData = require(Shared.Config.TitleData)
local EmoteData = require(Shared.Config.EmoteData)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Remote = require(UI.Remote)
local PageTypes = require(script.Parent.PageTypes)

local C = Theme.Colors

local MASTERY_GOAL = 100

local CATEGORY_LABEL: { [string]: string } = {
	Salut = "Salut",
	Meditation = "Méditation",
	Flourish = "Figure",
	Provocation = "Provocation",
	Victoire = "Victoire",
}

local InventoryPage = {}

local function requirementText(def: any): string
	if def.Source == "Default" then
		return "Offert à tous les duellistes"
	elseif def.Source == "Rank" then
		if def.Id == "RangGrandMaitre" then
			return "Atteindre 2000 Elo et le top 50 mondial"
		end
		return string.format("Atteindre %d Elo en classé", def.Requirement)
	elseif def.Source == "Wins" then
		return string.format("Remporter %d duels", def.Requirement)
	elseif def.Source == "Streak" then
		return string.format("Enchaîner %d victoires", def.Requirement)
	elseif def.Source == "Mastery" then
		local f = FormData.get(def.FormId or "")
		return string.format("%d victoires avec la %s", def.Requirement, if f then f.Name else "Voie")
	elseif def.Source == "Reroll" then
		return "Obtenir une Voie Légendaire ou Mythique en relance"
	end
	return ""
end

function InventoryPage.build(container: Frame, ctx: PageTypes.Ctx): PageTypes.Page
	local root = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = container })
	Kit.label(root, "INVENTAIRE", { Size = UDim2.new(1, 0, 0, 30), FontFace = Theme.Fonts.Display, TextSize = 24, TextColor3 = C.Cyan })

	local tabsRow = Kit.new("Frame", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = root })
	Kit.list(tabsRow, true, 8)
	local body = Kit.new("Frame", { Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -84), BackgroundTransparency = 1, Parent = root })

	local current = "Forms"
	local tabButtons: { [string]: TextButton } = {}
	local selectedSlot = 1

	local function scrollArea(parent: Instance, size: UDim2, pos: UDim2?): ScrollingFrame
		local s = Kit.new("ScrollingFrame", {
			Size = size,
			Position = pos or UDim2.new(),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = C.Cyan,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = parent,
		})
		Kit.padding(s, 4)
		return s
	end

	local render: () -> () = function() end

	local function renderForms(p: { [string]: any })
		local s = scrollArea(body, UDim2.fromScale(1, 1))
		Kit.grid(s, Vector2.new(276, 150), 10)
		for i, f in FormData.List do
			local owned = p.OwnedForms and p.OwnedForms[f.Id]
			local equipped = p.EquippedForm == f.Id
			local color = Theme.rarityColor(f.Rarity)
			local card = Kit.new("Frame", { BackgroundColor3 = C.Bg, BackgroundTransparency = if owned then 0.05 else 0.4, LayoutOrder = i, Parent = s })
			Kit.corner(card, 12)
			Kit.stroke(card, color, if equipped then 2.5 else 1.2, if equipped then 0 else 0.45)
			Kit.gradient(card, { color:Lerp(C.Bg, 0.7), C.Bg }, 0)
			Kit.label(card, f.Roman, {
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.fromOffset(60, 40),
				FontFace = Theme.Fonts.Display,
				TextSize = 30,
				TextColor3 = color,
			})
			Kit.label(card, f.Name, { Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -84, 0, 22), FontFace = Theme.Fonts.Bold, TextSize = 14 })
			Kit.label(card, string.upper(Theme.rarityLabel(f.Rarity)), {
				Position = UDim2.fromOffset(74, 28),
				Size = UDim2.new(1, -84, 0, 16),
				FontFace = Theme.Fonts.Title,
				TextSize = 10,
				TextColor3 = color,
			})
			Kit.label(card, f.Passive, {
				Position = UDim2.fromOffset(10, 52),
				Size = UDim2.new(1, -20, 0, 44),
				TextSize = 11,
				TextColor3 = if owned then C.Text else C.TextDim,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			local mastery = (p.FormMastery and p.FormMastery[f.Id]) or 0
			local bar = Kit.bar(card, C.Gold, { Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -130, 0, 12) })
			bar.set(mastery / MASTERY_GOAL, string.format("Maîtrise %d/%d", math.min(mastery, MASTERY_GOAL), MASTERY_GOAL))
			if owned then
				local b = Kit.button(card, if equipped then "ÉQUIPÉE" else "ÉQUIPER", {
					Primary = not equipped,
					Size = UDim2.fromOffset(100, 30),
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -10, 1, -10),
					TextSize = 12,
				}, function()
					if not equipped then
						Remote.call("Equip", false, "Form", f.Id)
					end
				end)
				b.Active = not equipped
			else
				Kit.label(card, string.format("🔒 Relance · %.1f %%", f.Weight / FormData.TotalWeight * 100), {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -10, 1, -12),
					Size = UDim2.fromOffset(110, 26),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextSize = 11,
					TextColor3 = C.Gold,
				})
			end
		end
	end

	local function renderTitles(p: { [string]: any })
		local s = scrollArea(body, UDim2.fromScale(1, 1))
		Kit.list(s, false, 6)
		local list = table.clone(TitleData.List)
		table.sort(list, function(a, b)
			local oa = if p.OwnedTitles and p.OwnedTitles[a.Id] then 0 else 1
			local ob = if p.OwnedTitles and p.OwnedTitles[b.Id] then 0 else 1
			if oa ~= ob then
				return oa < ob
			end
			return Theme.rarityOrder(a.Rarity) < Theme.rarityOrder(b.Rarity)
		end)
		for i, def in list do
			local owned = p.OwnedTitles and p.OwnedTitles[def.Id]
			local equipped = p.EquippedTitle == def.Id
			local row = Kit.new("Frame", { Size = UDim2.new(1, -8, 0, 52), BackgroundColor3 = C.Bg, BackgroundTransparency = if owned then 0.05 else 0.45, LayoutOrder = i, Parent = s })
			Kit.corner(row, 10)
			Kit.stroke(row, Theme.rarityColor(def.Rarity), if equipped then 2 else 1, if equipped then 0 else 0.6)
			local t = Kit.label(row, def.Text, {
				Position = UDim2.fromOffset(14, 4),
				Size = UDim2.new(0.5, 0, 0, 26),
				FontFace = Theme.Fonts.Display,
				TextSize = 17,
				TextColor3 = Color3.new(1, 1, 1),
			})
			Kit.gradient(t, def.Gradient, 0)
			Kit.label(row, requirementText(def), {
				Position = UDim2.fromOffset(14, 28),
				Size = UDim2.new(0.62, 0, 0, 18),
				TextSize = 11,
				TextColor3 = C.TextDim,
			})
			Kit.label(row, string.upper(Theme.rarityLabel(def.Rarity)), {
				Position = UDim2.new(0.62, 0, 0, 0),
				Size = UDim2.new(0.16, 0, 1, 0),
				FontFace = Theme.Fonts.Title,
				TextSize = 10,
				TextColor3 = Theme.rarityColor(def.Rarity),
			})
			if owned then
				local b = Kit.button(row, if equipped then "PORTÉ" else "PORTER", {
					Primary = not equipped,
					Size = UDim2.fromOffset(100, 32),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					TextSize = 12,
				}, function()
					if not equipped then
						Remote.call("Equip", false, "Title", def.Id)
					end
				end)
				b.Active = not equipped
			else
				Kit.label(row, "🔒", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -20, 0.5, 0),
					Size = UDim2.fromOffset(30, 30),
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end
		end
	end

	local function renderEmotes(p: { [string]: any })
		local equippedList: { string } = p.EquippedEmotes or {}
		Kit.label(body, "Choisis un emplacement de la roue, puis une emote. Touche B (ou bouton ✦ sur mobile) pour ouvrir la roue.", {
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 12,
			TextColor3 = C.TextDim,
		})
		local slots = Kit.new("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1, Parent = body })
		Kit.list(slots, true, 8)
		for i = 1, EmoteData.Slots do
			local id = equippedList[i]
			local def = id and EmoteData.get(id)
			local on = i == selectedSlot
			local b = Kit.new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.fromOffset(98, 70),
				BackgroundColor3 = if on then C.PanelLight else C.Bg,
				LayoutOrder = i,
				Parent = slots,
			})
			Kit.corner(b, 10)
			Kit.stroke(b, if on then C.Gold else C.Cyan, if on then 2 else 1, if on then 0 else 0.6)
			Kit.label(b, tostring(i), { Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(20, 16), FontFace = Theme.Fonts.Title, TextSize = 11, TextColor3 = C.Gold })
			Kit.label(b, if def then def.Name else "Vide", {
				Position = UDim2.fromOffset(6, 22),
				Size = UDim2.new(1, -12, 0, 40),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 11,
				FontFace = Theme.Fonts.Bold,
				TextColor3 = if def then C.Text else C.TextDim,
			})
			b.Activated:Connect(function()
				Kit.sound("Click", 0.3)
				selectedSlot = i
				render()
			end)
		end
		local clear = Kit.button(body, "VIDER L'EMPLACEMENT", { Size = UDim2.fromOffset(200, 32), Position = UDim2.fromOffset(0, 108), TextSize = 12 }, function()
			if equippedList[selectedSlot] then
				Remote.call("Equip", false, "Emote", "", selectedSlot)
			end
		end)
		clear.Visible = equippedList[selectedSlot] ~= nil
		local s = scrollArea(body, UDim2.new(1, 0, 1, -150), UDim2.fromOffset(0, 150))
		Kit.grid(s, Vector2.new(205, 64), 8)
		for i, e in EmoteData.List do
			local slotOf = table.find(equippedList, e.Id)
			local b = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.Bg, LayoutOrder = i, Parent = s })
			Kit.corner(b, 10)
			Kit.stroke(b, if slotOf then C.Gold else C.Line, 1.2, 0.3)
			Kit.label(b, e.Name, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 20), FontFace = Theme.Fonts.Bold, TextSize = 13 })
			Kit.label(b, (CATEGORY_LABEL[e.Category] or e.Category) .. (if slotOf then string.format("  ·  emplacement %d", slotOf) else ""), {
				Position = UDim2.fromOffset(12, 32),
				Size = UDim2.new(1, -24, 0, 18),
				TextSize = 11,
				TextColor3 = if slotOf then C.Gold else C.TextDim,
			})
			b.Activated:Connect(function()
				Kit.sound("Click", 0.35)
				local target = math.min(selectedSlot, #equippedList + 1)
				Remote.call("Equip", false, "Emote", e.Id, target)
			end)
		end
	end

	render = function()
		Kit.clear(body)
		for id, b in tabButtons do
			local on = id == current
			b.BackgroundColor3 = if on then C.Cyan else C.PanelLight
			b.TextColor3 = if on then C.Night else C.Text
		end
		local p = ctx.profile()
		if not p then
			Kit.label(body, "Chargement du profil…", { TextColor3 = C.TextDim })
			return
		end
		if current == "Forms" then
			renderForms(p)
		elseif current == "Titles" then
			renderTitles(p)
		else
			renderEmotes(p)
		end
	end

	for i, t in { { Id = "Forms", Label = "VOIES" }, { Id = "Titles", Label = "TITRES" }, { Id = "Emotes", Label = "EMOTES" } } do
		tabButtons[t.Id] = Kit.button(tabsRow, t.Label, { Size = UDim2.fromOffset(130, 34), TextSize = 13, LayoutOrder = i }, function()
			current = t.Id
			render()
		end)
	end

	local page: PageTypes.Page = {
		Id = "Inventory",
		Title = "Inventaire",
		Icon = "▣",
		Root = root,
		onShow = function(sub: string?)
			if sub == "Forms" or sub == "Titles" or sub == "Emotes" then
				current = sub
			end
			render()
		end,
		onProfile = function()
			if container.Visible then
				render()
			end
		end,
	}
	return page
end

return InventoryPage
