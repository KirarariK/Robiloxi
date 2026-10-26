--!strict
--[[
	La Forge — boutique cosmétiques (onglets, grille, aperçu, ACHETER / ESSAYER).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Util = Kit.Util
local Button = Kit.Button
local Modal = Kit.Modal
local CurrencyPill = Kit.CurrencyPill
local ViewportPreview = Kit.ViewportPreview
local Icons = Kit.Icons

local ForgeScreen = {}

local TABS = {
	{ id = "BladeColor", label = "LAMES", icon = "Sword" },
	{ id = "Hilt", label = "GARDES", icon = "Shield" },
	{ id = "Aura", label = "AURAS", icon = "Focus" },
	{ id = "Skin", label = "TRACES", icon = "Dash" },
	{ id = "Finisher", label = "FINISHERS", icon = "Star" },
	{ id = "Emote", label = "EMOTES", icon = "Emote" },
	{ id = "Title", label = "TITRES", icon = "Crown" },
}

function ForgeScreen.open(
	parent: Instance,
	ctx: {
		profile: any,
		catalog: any,
		metaRemotes: any,
		onClose: (() -> ())?,
		onToast: ((string, Color3?) -> ())?,
	}
): () -> ()
	local profile = ctx.profile
	local catalog = ctx.catalog or EconomyConfig.Shop
	local tab = "BladeColor"
	local selected: any = catalog[1]
	local vp: ViewportPreview.Handle? = nil

	local modal = Modal.open(parent, {
		title = Strings.Forge,
		subtitle = Strings.ForgeSub,
		size = UDim2.fromScale(0.92, 0.88),
		onClose = ctx.onClose,
	})
	local content = modal.content

	local function owns(id: string): boolean
		if not profile or typeof(profile.ownedCosmetics) ~= "table" then
			return false
		end
		for _, c in profile.ownedCosmetics do
			if c == id then
				return true
			end
		end
		return false
	end

	local function toast(msg: string, col: Color3?)
		if ctx.onToast then
			ctx.onToast(msg, col)
		end
	end

	local function rebuild()
		for _, ch in content:GetChildren() do
			ch:Destroy()
		end
		if vp then
			vp.destroy()
			vp = nil
		end

		-- Currencies top-right area inside content
		local topR = Instance.new("Frame")
		topR.BackgroundTransparency = 1
		topR.AnchorPoint = Vector2.new(1, 0)
		topR.Position = UDim2.new(1, -8, 0, 0)
		topR.Size = UDim2.fromOffset(180, 80)
		topR.Parent = content
		CurrencyPill.create(topR, {
			kind = "credits",
			amount = (profile and profile.credits) or 0,
			layoutOrder = 1,
			onPlus = function()
				ctx.metaRemotes.ShopPurchase:FireServer({ stubShards = true })
			end,
		})
		local sh = CurrencyPill.create(topR, {
			kind = "shards",
			amount = (profile and profile.shards) or 0,
			layoutOrder = 2,
		})
		sh.root.Position = UDim2.fromOffset(0, 40)

		-- Tabs
		local tabs = Instance.new("Frame")
		tabs.BackgroundTransparency = 1
		tabs.Position = UDim2.new(0.01, 0, 0.02, 0)
		tabs.Size = UDim2.new(0.15, 0, 0.75, 0)
		tabs.Parent = content
		Util.list(tabs, Enum.FillDirection.Vertical, 6)

		for i, t in TABS do
			local active = t.id == tab
			local b = Button.create({
				parent = tabs,
				text = t.label,
				style = if active then "primary" else "secondary",
				size = UDim2.new(1, 0, 0, 44),
				layoutOrder = i,
				textSize = 13,
				onClick = function()
					tab = t.id
					selected = nil
					for _, item in catalog do
						if item.category == tab then
							selected = item
							break
						end
					end
					rebuild()
				end,
			})
			local iconBox = Instance.new("Frame")
			iconBox.BackgroundTransparency = 1
			iconBox.Size = UDim2.fromOffset(22, 22)
			iconBox.Position = UDim2.fromOffset(8, 11)
			iconBox.Parent = b
			Icons.compose(iconBox, t.icon, if active then Theme.Ink900 else Theme.Gold)
		end

		-- Grid
		local gridWrap = Instance.new("ScrollingFrame")
		gridWrap.Position = UDim2.new(0.18, 0, 0.02, 0)
		gridWrap.Size = UDim2.new(0.48, 0, 0.72, 0)
		gridWrap.BackgroundColor3 = Theme.Ink800
		gridWrap.BackgroundTransparency = 0.35
		gridWrap.BorderSizePixel = 0
		gridWrap.ScrollBarThickness = 4
		gridWrap.AutomaticCanvasSize = Enum.AutomaticSize.Y
		gridWrap.CanvasSize = UDim2.new(0, 0, 0, 0)
		gridWrap.Parent = content
		Util.corner(gridWrap, 10)
		Util.pad(gridWrap, 10)
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.23, 0, 0, 120)
		grid.CellPadding = UDim2.fromOffset(10, 10)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = gridWrap

		local order = 0
		for _, item in catalog do
			if item.category ~= tab then
				continue
			end
			order += 1
			local rarCol = Theme.rarityColor(tostring(item.rarity))
			local card = Instance.new("TextButton")
			card.AutoButtonColor = false
			card.Text = ""
			card.BackgroundColor3 = Theme.Ink700
			card.BackgroundTransparency = 0.1
			card.BorderSizePixel = 0
			card.LayoutOrder = order
			card.Parent = gridWrap
			Util.corner(card, 10)
			Util.stroke(card, if selected and selected.id == item.id then Theme.Gold else rarCol, 1.5, 0.3)

			local thumb = Instance.new("Frame")
			thumb.Size = UDim2.fromOffset(48, 48)
			thumb.Position = UDim2.new(0.5, -24, 0, 12)
			thumb.BackgroundColor3 = rarCol
			thumb.BackgroundTransparency = 0.4
			thumb.BorderSizePixel = 0
			thumb.Parent = card
			Util.corner(thumb, 8)
			Icons.compose(thumb, "Sword", rarCol)

			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.new(0, 4, 0, 66)
			name.Size = UDim2.new(1, -8, 0, 18)
			Theme.applyFont(name, "HudSemi")
			name.TextSize = 11
			name.TextColor3 = Theme.Bone
			name.Text = tostring(item.displayName)
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.Parent = card

			local price = Instance.new("TextLabel")
			price.BackgroundTransparency = 1
			price.Position = UDim2.new(0, 4, 0, 88)
			price.Size = UDim2.new(1, -8, 0, 16)
			Theme.applyFont(price, "Body")
			price.TextSize = 11
			price.TextColor3 = Theme.Gold
			local owned = owns(item.id)
			if owned then
				price.Text = Strings.Owned
				price.TextColor3 = Theme.Success
			elseif item.softPrice then
				price.Text = "◎ " .. Util.formatNumber(item.softPrice)
			else
				price.Text = "◆ " .. Util.formatNumber(item.premiumPrice or 0)
			end
			price.Parent = card

			card.MouseButton1Click:Connect(function()
				selected = item
				rebuild()
			end)
		end

		if order == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.new(1, 0, 0, 40)
			Theme.applyFont(empty, "Body")
			empty.TextSize = 14
			empty.TextColor3 = Theme.Muted
			empty.Text = "Aucun article dans cet onglet."
			empty.Parent = gridWrap
		end

		-- Preview panel
		local preview = Util.glassPanel(content, "Preview")
		preview.AnchorPoint = Vector2.new(1, 0)
		preview.Position = UDim2.new(0.99, 0, 0.02, 0)
		preview.Size = UDim2.new(0.3, 0, 0.78, 0)

		vp = ViewportPreview.create(preview, {
			size = UDim2.new(1, -16, 0, 220),
			position = UDim2.new(0, 8, 0, 8),
			accent = selected and Theme.rarityColor(tostring(selected.rarity)) or Theme.Focus,
		})

		if selected then
			local n = Instance.new("TextLabel")
			n.BackgroundTransparency = 1
			n.Position = UDim2.new(0, 12, 0, 236)
			n.Size = UDim2.new(1, -24, 0, 28)
			Theme.applyFont(n, "Title")
			n.TextSize = 22
			n.TextXAlignment = Enum.TextXAlignment.Left
			n.TextColor3 = Theme.Bone
			n.Text = tostring(selected.displayName)
			n.Parent = preview

			local badge = Instance.new("TextLabel")
			badge.BackgroundColor3 = Theme.rarityColor(tostring(selected.rarity))
			badge.Position = UDim2.new(0, 12, 0, 268)
			badge.Size = UDim2.fromOffset(110, 20)
			Theme.applyFont(badge, "HudSemi")
			badge.TextSize = 11
			badge.TextColor3 = Theme.Ink900
			badge.Text = string.upper(Theme.rarityLabelFr(tostring(selected.rarity)))
			badge.Parent = preview
			Util.corner(badge, 4)

			local d = Instance.new("TextLabel")
			d.BackgroundTransparency = 1
			d.Position = UDim2.new(0, 12, 0, 296)
			d.Size = UDim2.new(1, -24, 0, 48)
			Theme.applyFont(d, "Body")
			d.TextSize = 13
			d.TextWrapped = true
			d.TextXAlignment = Enum.TextXAlignment.Left
			d.TextColor3 = Theme.Muted
			d.Text = Strings.CosmeticOnly .. " — " .. tostring(selected.category)
			d.Parent = preview

			local owned = owns(selected.id)
			local priceLabel = if selected.softPrice
				then Util.formatNumber(selected.softPrice)
				else Util.formatNumber(selected.premiumPrice or 0)
			Button.create({
				parent = preview,
				text = if owned then Strings.Equipped else (priceLabel .. "  " .. Strings.Buy),
				style = "primary",
				size = UDim2.new(1, -24, 0, 48),
				position = UDim2.new(0, 12, 1, -110),
				onClick = function()
					if owned then
						return
					end
					local usePrem = selected.softPrice == nil
					ctx.metaRemotes.ShopPurchase:FireServer({ itemId = selected.id, premium = usePrem })
					toast("Achat…", Theme.Gold)
				end,
			})
			Button.create({
				parent = preview,
				text = Strings.Try,
				style = "secondary",
				size = UDim2.new(1, -24, 0, 40),
				position = UDim2.new(0, 12, 1, -54),
				onClick = function()
					toast("Essai cosmétique 10 s (client)", Theme.Focus)
					if vp then
						vp.setAccent(Theme.rarityColor(tostring(selected.rarity)))
					end
				end,
			})
		end

		-- Offre du jour
		local offer = Util.glassPanel(content, "Offer")
		offer.Position = UDim2.new(0.01, 0, 0.86, 0)
		offer.Size = UDim2.new(0.65, 0, 0.12, 0)
		local ot = Instance.new("TextLabel")
		ot.BackgroundTransparency = 1
		ot.Size = UDim2.fromScale(1, 1)
		ot.Position = UDim2.fromOffset(16, 0)
		Theme.applyFont(ot, "Hud")
		ot.TextSize = 16
		ot.TextXAlignment = Enum.TextXAlignment.Left
		ot.TextColor3 = Theme.Gold
		ot.Text = Strings.OfferOfDay .. " — rotation quotidienne"
		ot.Parent = offer
	end

	rebuild()

	local conn = ctx.metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
		end
		if payload.catalog then
			catalog = payload.catalog
		end
		if payload.kind == "ShopResult" then
			local data = payload.data
			if data and data.ok then
				toast("Acheté !", Theme.Success)
			elseif data then
				toast("Échec : " .. tostring(data.error), Theme.Danger)
			end
		end
		if modal.root.Parent then
			rebuild()
		end
	end)

	local prev = modal.close
	return function()
		conn:Disconnect()
		if vp then
			vp.destroy()
		end
		prev()
	end
end

return ForgeScreen
