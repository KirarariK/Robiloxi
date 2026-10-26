--!strict
--[[
	Écran Formes (gacha) — liste, viewport 3D, raretés FormConfig, pitié, UTILISER, PolicyService.
]]

local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local FormConfig = require(Shared:WaitForChild("FormConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Util = Kit.Util
local Button = Kit.Button
local Bar = Kit.Bar
local RarityCard = Kit.RarityCard
local ViewportPreview = Kit.ViewportPreview
local Modal = Kit.Modal
local CurrencyPill = Kit.CurrencyPill
local Toast = Kit.Toast

local FormsScreen = {}

local paidRandomBlocked = false
local policyChecked = false

local function checkPolicy()
	if policyChecked then
		return
	end
	policyChecked = true
	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(Players.LocalPlayer)
		end)
		if ok and typeof(info) == "table" and info.ArePaidRandomItemsRestricted == true then
			paidRandomBlocked = true
		end
	end)
end

local FORM_ORDER = { "Astra", "Duelant", "Aegis", "Zephyr" }

local function ownedLookup(profile: any): { [string]: any }
	local map = {}
	if profile and typeof(profile.ownedForms) == "table" then
		for _, o in profile.ownedForms do
			local key = tostring(o.formId) .. ":" .. tostring(o.rarity)
			map[key] = o
			-- also track best by form
			local prev = map[tostring(o.formId)]
			if not prev then
				map[tostring(o.formId)] = o
			end
		end
	end
	return map
end

function FormsScreen.open(
	parent: Instance,
	ctx: {
		profile: any,
		metaRemotes: any,
		onClose: (() -> ())?,
		onToast: ((string, Color3?) -> ())?,
	}
): () -> ()
	checkPolicy()
	local profile = ctx.profile
	local selectedId = tostring((profile and profile.equippedFormId) or "Duelant")
	local selectedRarity = tostring((profile and profile.equippedFormRarity) or "Common")
	local vp: ViewportPreview.Handle? = nil

	local modal = Modal.open(parent, {
		title = Strings.Forms,
		subtitle = Strings.RankedFairReminder,
		size = UDim2.fromScale(0.94, 0.9),
		onClose = ctx.onClose,
		showClose = true,
	})

	local content = modal.content
	content:ClearAllChildren()

	-- Fond vignette
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Theme.Ink900
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	bg.ZIndex = content.ZIndex
	bg.Parent = content
	Util.gradient(bg, ColorSequence.new(Theme.DuskBg, Theme.Ink900), 120)

	local function toast(msg: string, col: Color3?)
		if ctx.onToast then
			ctx.onToast(msg, col)
		else
			Toast.show(msg, col)
		end
	end

	local function rebuild()
		-- clear dynamic (keep bg)
		for _, ch in content:GetChildren() do
			if ch ~= bg then
				ch:Destroy()
			end
		end
		if vp then
			vp.destroy()
			vp = nil
		end

		local owned = ownedLookup(profile)
		local def = FormConfig.Forms[selectedId]
		local rarCol = Theme.rarityColor(selectedRarity)

		-- Liste gauche
		local list = Instance.new("ScrollingFrame")
		list.Name = "FormList"
		list.AnchorPoint = Vector2.new(0, 0.5)
		list.Position = UDim2.new(0.02, 0, 0.52, 0)
		list.Size = UDim2.new(0.22, 0, 0.78, 0)
		list.BackgroundColor3 = Theme.Ink800
		list.BackgroundTransparency = 0.25
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 3
		list.ScrollBarImageColor3 = Theme.Arcane
		list.CanvasSize = UDim2.new(0, 0, 0, 0)
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.ZIndex = content.ZIndex + 1
		list.Parent = content
		Util.corner(list, 10)
		Util.pad(list, 8)
		Util.list(list, Enum.FillDirection.Vertical, 8)

		local listTitle = Instance.new("TextLabel")
		listTitle.BackgroundTransparency = 1
		listTitle.Size = UDim2.new(1, 0, 0, 24)
		listTitle.LayoutOrder = 0
		Theme.applyFont(listTitle, "Hud")
		listTitle.TextSize = 14
		listTitle.TextColor3 = Theme.Gold
		listTitle.Text = "✦  " .. Strings.Forms .. "  ✦"
		listTitle.Parent = list

		for i, fid in FORM_ORDER do
			local fdef = FormConfig.Forms[fid]
			local best = owned[fid]
			local rar = if best then tostring(best.rarity) else "Common"
			local state: string
			if profile and tostring(profile.equippedFormId) == fid then
				state = Strings.Equipped
			elseif best then
				state = Strings.Owned
			else
				state = Strings.Locked
			end
			local tempoKey = fdef and fdef.tempo or ""
			-- FormConfig may use accents (« Contrôle ») — map ASCII aliases in Strings.Tempo
			local tempo = Strings.Tempo[tempoKey] or ("SABRE / " .. string.upper(tostring(tempoKey)))
			RarityCard.create(list, {
				title = fdef and fdef.displayName or fid,
				rarity = rar,
				subtitle = tempo,
				state = state,
				selected = fid == selectedId,
				layoutOrder = i,
				onClick = function()
					selectedId = fid
					selectedRarity = rar
					rebuild()
				end,
			})
		end

		-- Titre centre
		local labelCur = Instance.new("TextLabel")
		labelCur.BackgroundTransparency = 1
		labelCur.AnchorPoint = Vector2.new(0.5, 0)
		labelCur.Position = UDim2.new(0.5, 0, 0.02, 0)
		labelCur.Size = UDim2.new(0.36, 0, 0, 18)
		Theme.applyFont(labelCur, "HudSemi")
		labelCur.TextSize = 12
		labelCur.TextColor3 = Theme.Muted
		labelCur.Text = Strings.FormCurrent
		labelCur.ZIndex = content.ZIndex + 2
		labelCur.Parent = content

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.new(0.5, 0, 0.05, 0)
		title.Size = UDim2.new(0.4, 0, 0, 52)
		Theme.applyFont(title, "Display")
		title.TextSize = 48
		title.Text = string.upper(def and def.displayName or selectedId)
		title.TextColor3 = rarCol
		title.ZIndex = content.ZIndex + 2
		title.Parent = content
		Util.gradient(title, ColorSequence.new(rarCol, Theme.Arcane), 0)
		local tStroke = Instance.new("UIStroke")
		tStroke.Color = Theme.Ink900
		tStroke.Thickness = 2
		tStroke.Parent = title

		local desc = Instance.new("TextLabel")
		desc.BackgroundTransparency = 1
		desc.AnchorPoint = Vector2.new(0.5, 0)
		desc.Position = UDim2.new(0.5, 0, 0.14, 0)
		desc.Size = UDim2.new(0.4, 0, 0, 40)
		Theme.applyFont(desc, "Body")
		desc.TextSize = 14
		desc.TextWrapped = true
		desc.TextColor3 = Theme.Bone
		desc.Text = Strings.FormFlavor[selectedId] or ""
		desc.ZIndex = content.ZIndex + 2
		desc.Parent = content

		-- Viewport
		vp = ViewportPreview.create(content, {
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0.5, 0, 0.52, 0),
			size = UDim2.new(0.32, 0, 0.48, 0),
			accent = rarCol,
		})
		vp.root.ZIndex = content.ZIndex + 1

		-- Barres rareté droite (FormConfig source de vérité)
		local right = Instance.new("Frame")
		right.BackgroundTransparency = 1
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.new(0.98, 0, 0.08, 0)
		right.Size = UDim2.new(0.24, 0, 0.42, 0)
		right.ZIndex = content.ZIndex + 2
		right.Parent = content
		Util.list(right, Enum.FillDirection.Vertical, 8)

		local function showOddsDetails()
			local m = Modal.open(parent, {
				title = Strings.Details,
				subtitle = Strings.OddsDisclaimer,
				size = UDim2.fromScale(0.42, 0.55),
			})
			local y = 8
			for _, rar in FormConfig.RarityOrder do
				local rate = FormConfig.DropRates[rar] or 0
				local row = Instance.new("TextLabel")
				row.BackgroundTransparency = 1
				row.Position = UDim2.new(0, 8, 0, y)
				row.Size = UDim2.new(1, -16, 0, 28)
				Theme.applyFont(row, "HudSemi")
				row.TextSize = 15
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.TextColor3 = Theme.rarityColor(rar)
				row.Text = string.format(
					"%s — %s  ·  odds forme ≈ %s",
					Theme.rarityLabelFr(rar),
					Util.pct(rate),
					Util.pct(rate / #FORM_ORDER)
				)
				row.Parent = m.content
				y += 32
			end
			local pity = Instance.new("TextLabel")
			pity.BackgroundTransparency = 1
			pity.Position = UDim2.new(0, 8, 0, y + 8)
			pity.Size = UDim2.new(1, -16, 0, 48)
			Theme.applyFont(pity, "Body")
			pity.TextSize = 13
			pity.TextWrapped = true
			pity.TextXAlignment = Enum.TextXAlignment.Left
			pity.TextColor3 = Theme.Muted
			pity.Text = string.format(
				"Pitié : Épique à %d tirages · Légendaire à %d tirages.\n%s",
				FormConfig.PityEpic,
				FormConfig.PityLegendary,
				Strings.RankedFairReminder
			)
			pity.Parent = m.content
		end

		for i, rar in FormConfig.RarityOrder do
			local rate = FormConfig.DropRates[rar] or 0
			Bar.rarityPill(right, Theme.rarityLabelFr(rar), Util.pct(rate), Theme.rarityColor(rar), i, showOddsDetails)
		end

		local detailsBtn = Button.create({
			parent = right,
			text = Strings.Details,
			style = "secondary",
			size = UDim2.new(1, 0, 0, 40),
			layoutOrder = 20,
			onClick = showOddsDetails,
		})
		detailsBtn.ZIndex = content.ZIndex + 3

		local eventLbl = Instance.new("TextLabel")
		eventLbl.BackgroundTransparency = 1
		eventLbl.Size = UDim2.new(1, 0, 0, 20)
		eventLbl.LayoutOrder = 21
		Theme.applyFont(eventLbl, "Mono")
		eventLbl.TextSize = 12
		eventLbl.TextColor3 = Theme.Focus
		eventLbl.Text = Strings.EventPrefix .. " Bannière formes active"
		eventLbl.Parent = right

		-- Pity
		local pityEpic = (profile and profile.pityEpic) or 0
		local pityLeg = (profile and profile.pityLegendary) or 0
		local pityWrap = Instance.new("Frame")
		pityWrap.BackgroundTransparency = 1
		pityWrap.AnchorPoint = Vector2.new(0.5, 0)
		pityWrap.Position = UDim2.new(0.5, 0, 0.78, 0)
		pityWrap.Size = UDim2.new(0.28, 0, 0, 56)
		pityWrap.ZIndex = content.ZIndex + 2
		pityWrap.Parent = content
		Bar.pity(pityWrap, Strings.PityEpic, pityEpic, FormConfig.PityEpic, Theme.RarityEpic)
		local p2 = Bar.pity(pityWrap, Strings.PityLegendary, pityLeg, FormConfig.PityLegendary, Theme.RarityLegendary)
		p2.Position = UDim2.new(0, 0, 0, 30)

		-- Cristaux / fragments display
		local crystalLbl = Instance.new("TextLabel")
		crystalLbl.BackgroundTransparency = 1
		crystalLbl.AnchorPoint = Vector2.new(0.5, 0)
		crystalLbl.Position = UDim2.new(0.5, 0, 0.86, 0)
		crystalLbl.Size = UDim2.new(0.3, 0, 0, 20)
		Theme.applyFont(crystalLbl, "Body")
		crystalLbl.TextSize = 13
		crystalLbl.TextColor3 = Theme.Bone
		crystalLbl.Text = string.format(
			"◇ %s : %d   ·   Fragments : %d",
			Strings.FormCrystals,
			math.floor(((profile and profile.credits) or 0) / 300),
			(profile and profile.fragments) or 0
		)
		crystalLbl.ZIndex = content.ZIndex + 2
		crystalLbl.Parent = content

		-- CTA states
		local equipped = profile
			and tostring(profile.equippedFormId) == selectedId
			and tostring(profile.equippedFormRarity) == selectedRarity
		local hasOwned = owned[selectedId] ~= nil
		local canPull = ((profile and profile.credits) or 0) >= 300
		local ctaText = Strings.Use
		local ctaStyle: any = "primary"
		local ctaAction: () -> () = function() end

		if paidRandomBlocked then
			-- Soft currency pulls still OK; block only when premium would be used — we still allow soft
			-- Show note for premium path
		end

		if equipped then
			ctaText = Strings.Equipped
			ctaStyle = "secondary"
			ctaAction = function() end
		elseif hasOwned and selectedId ~= tostring(profile.equippedFormId) then
			ctaText = Strings.Equip
			ctaStyle = "arcane"
			ctaAction = function()
				local o = owned[selectedId]
				ctx.metaRemotes.EquipLoadout:FireServer({
					formId = selectedId,
					rarity = o and o.rarity or selectedRarity,
				})
				toast("Forme équipée : " .. selectedId, Theme.Success)
			end
		elseif not canPull then
			ctaText = Strings.NotEnoughCrystals
			ctaStyle = "ghost"
			ctaAction = function()
				toast(Strings.Insufficient, Theme.Danger)
			end
		else
			ctaText = Strings.Use
			ctaStyle = "primary"
			ctaAction = function()
				if paidRandomBlocked then
					-- soft pull allowed (crédits), premium blocked elsewhere
				end
				toast(Strings.Pulling, Theme.Gold)
				ctx.metaRemotes.GachaPull:FireServer({ count = 1, premium = false })
			end
		end

		local cta = Button.create({
			parent = content,
			text = ctaText,
			style = ctaStyle,
			size = UDim2.new(0.26, 0, 0, 52),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 0.97, 0),
			textSize = 20,
			onClick = ctaAction,
		})
		cta.ZIndex = content.ZIndex + 3
		if equipped then
			Button.setEnabled(cta, false)
		end

		local subCta = Instance.new("TextLabel")
		subCta.BackgroundTransparency = 1
		subCta.AnchorPoint = Vector2.new(0.5, 1)
		subCta.Position = UDim2.new(0.5, 0, 1, -2)
		subCta.Size = UDim2.new(0.3, 0, 0, 16)
		Theme.applyFont(subCta, "Body")
		subCta.TextSize = 12
		subCta.TextColor3 = Theme.Muted
		subCta.Text = string.format(
			"%s : %d  ·  Pull ×1 = 300 crédits",
			Strings.PullsLeft,
			math.floor(((profile and profile.credits) or 0) / 300)
		)
		subCta.ZIndex = content.ZIndex + 2
		subCta.Parent = content

		-- Retour
		Button.create({
			parent = content,
			text = Strings.BackLobby,
			style = "danger",
			size = UDim2.new(0.16, 0, 0, 44),
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0.02, 0, 0.98, 0),
			onClick = function()
				modal.close()
			end,
		}).ZIndex = content.ZIndex
			+ 3

		-- Monnaie + acheter
		local money = Instance.new("Frame")
		money.BackgroundTransparency = 1
		money.AnchorPoint = Vector2.new(1, 1)
		money.Position = UDim2.new(0.98, 0, 0.98, 0)
		money.Size = UDim2.fromOffset(200, 80)
		money.ZIndex = content.ZIndex + 2
		money.Parent = content
		CurrencyPill.create(money, {
			kind = "credits",
			amount = (profile and profile.credits) or 0,
			position = UDim2.fromOffset(0, 0),
		})
		Button.create({
			parent = money,
			text = Strings.BuyPulls,
			style = "secondary",
			size = UDim2.new(1, 0, 0, 36),
			position = UDim2.fromOffset(0, 40),
			textSize = 12,
			onClick = function()
				if paidRandomBlocked then
					toast(Strings.PaidRandomBlocked, Theme.Danger)
					return
				end
				-- Soft stub shards then premium path note
				ctx.metaRemotes.ShopPurchase:FireServer({ stubShards = true })
				toast("+ Éclats Focus (stub)", Theme.Focus)
			end,
		})

		-- Premium ×10 secondary
		Button.create({
			parent = content,
			text = string.format("×10 premium — %d Éclats", EconomyConfig.BannerTenPullPremium),
			style = "arcane",
			size = UDim2.new(0.2, 0, 0, 36),
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.72, 0, 0.97, 0),
			textSize = 12,
			onClick = function()
				if paidRandomBlocked then
					toast(Strings.PaidRandomBlocked, Theme.Danger)
					return
				end
				ctx.metaRemotes.GachaPull:FireServer({ count = 10, premium = true })
			end,
		}).ZIndex = content.ZIndex
			+ 3
	end

	rebuild()

	-- live profile updates while open
	local conn = ctx.metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
		end
		if payload.kind == "GachaResult" then
			local data = if typeof(payload.data) == "table" then payload.data else payload
			if data.ok == false then
				toast("Échec : " .. tostring(data.error or "?"), Theme.Danger)
			elseif typeof(data.results) == "table" and #data.results > 0 then
				local r = data.results[1]
				toast(
					string.format("Obtenu : %s · %s", tostring(r.formId), Theme.rarityLabelFr(tostring(r.rarity))),
					Theme.rarityColor(tostring(r.rarity))
				)
			end
		end
		if modal.root.Parent then
			rebuild()
		end
	end)

	local prevClose = modal.close
	return function()
		conn:Disconnect()
		if vp then
			vp.destroy()
		end
		prevClose()
	end
end

return FormsScreen
