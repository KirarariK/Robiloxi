--!strict
-- Page « Relance » : roulette des Voies (défilement aux couleurs de rareté), révélation avec flash,
-- résumé des passifs de la Voie obtenue, bouton Équiper. Le tirage est fait par le serveur : la roulette
-- ne fait que mettre en scène le résultat reçu.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local FormData = require(Shared.Config.FormData)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Remote = require(UI.Remote)
local Toast = require(UI.Toast)
local PageTypes = require(script.Parent.PageTypes)

local C = Theme.Colors

local CARD_W, CARD_GAP = 140, 12
local STEP = CARD_W + CARD_GAP
local REEL_LEN = 42
local RESULT_INDEX = 36
local PITY_LIMIT = 50

local RerollPage = {}

local function formCard(parent: Instance, form: any, index: number): Frame
	local color = Theme.rarityColor(form.Rarity)
	local card = Kit.new("Frame", {
		Size = UDim2.fromOffset(CARD_W, 150),
		Position = UDim2.fromOffset((index - 1) * STEP, 10),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Kit.corner(card, 12)
	Kit.stroke(card, color, 2, 0.1)
	Kit.gradient(card, { color:Lerp(C.Bg, 0.55), C.Bg }, 90)
	Kit.label(card, form.Roman, {
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 40,
		TextColor3 = color,
	})
	Kit.label(card, form.Name, {
		Size = UDim2.new(1, -12, 0, 40),
		Position = UDim2.fromOffset(6, 72),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 13,
	})
	Kit.label(card, string.upper(Theme.rarityLabel(form.Rarity)), {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 118),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Title,
		TextSize = 11,
		TextColor3 = color,
	})
	return card
end

function RerollPage.build(container: Frame, ctx: PageTypes.Ctx): PageTypes.Page
	local root = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = container })

	Kit.label(root, "AUTEL DES CRISTAUX", {
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = Theme.Fonts.Display,
		TextSize = 24,
		TextColor3 = C.Gold,
	})
	Kit.label(root, "Dépense tes Cristaux pour éveiller une nouvelle Voie de combat.", {
		Position = UDim2.fromOffset(0, 32),
		TextColor3 = C.TextDim,
		TextSize = 14,
	})

	-- Roulette
	local reel = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.2,
		ClipsDescendants = true,
		Parent = root,
	})
	Kit.corner(reel, 14)
	Kit.stroke(reel, C.Cyan, 1.5, 0.5)
	local strip = Kit.new("Frame", { Size = UDim2.fromOffset(REEL_LEN * STEP, 170), BackgroundTransparency = 1, Parent = reel })
	local marker = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = reel,
	})
	Kit.gradient(marker, { C.Gold, Color3.new(1, 1, 1), C.Gold }, 90)
	for _, side in { 0, 1 } do
		local fade = Kit.new("Frame", {
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.fromScale(side, 0),
			Size = UDim2.new(0, 120, 1, 0),
			BackgroundColor3 = C.Night,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = reel,
		})
		local g = Kit.new("UIGradient", {
			Transparency = NumberSequence.new(if side == 0 then 0 else 1, if side == 0 then 1 else 0),
			Parent = fade,
		})
		g.Rotation = 0
	end
	local flash = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = reel,
	})
	Kit.corner(flash, 14)

	-- Panneau gauche : chances ou résultat
	local left = Kit.panel(root, { Position = UDim2.fromOffset(0, 250), Size = UDim2.new(0.6, -10, 1, -250) })
	Kit.padding(left, 14)
	local odds = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = left })
	Kit.list(odds, false, 4)
	Kit.label(odds, "CHANCES DE TIRAGE", { FontFace = Theme.Fonts.Title, TextSize = 13, TextColor3 = C.Cyan, LayoutOrder = 0 })
	local oddsRows: { [string]: TextLabel } = {}
	for i, f in FormData.List do
		local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i, Parent = odds })
		Kit.new("Frame", {
			Size = UDim2.fromOffset(10, 10),
			Position = UDim2.fromOffset(0, 7),
			BackgroundColor3 = Theme.rarityColor(f.Rarity),
			Parent = row,
		})
		local name = Kit.label(row, string.format("%s · %s", f.Roman, f.Name), {
			Position = UDim2.fromOffset(18, 0),
			Size = UDim2.new(1, -90, 1, 0),
			TextSize = 14,
		})
		oddsRows[f.Id] = name
		Kit.label(row, string.format("%.1f %%", f.Weight / FormData.TotalWeight * 100), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 80, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = Theme.Fonts.Bold,
			TextSize = 14,
			TextColor3 = Theme.rarityColor(f.Rarity),
		})
	end

	local reveal = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = left })
	local revTitle = Kit.label(reveal, "", { Size = UDim2.new(1, 0, 0, 34), FontFace = Theme.Fonts.Display, TextSize = 24 })
	local revRarity = Kit.label(reveal, "", { Position = UDim2.fromOffset(0, 36), FontFace = Theme.Fonts.Title, TextSize = 13 })
	local revDesc = Kit.label(reveal, "", { Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 40), TextColor3 = C.TextDim, TextSize = 14 })
	local revPassive = Kit.label(reveal, "", {
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 0, 58),
		TextSize = 15,
		FontFace = Theme.Fonts.Bold,
		TextColor3 = C.Cyan,
	})
	local revNote = Kit.label(reveal, "", { Position = UDim2.fromOffset(0, 170), TextSize = 14, TextColor3 = C.Gold })
	local equipBtn: TextButton
	local lastForm: string? = nil
	equipBtn = Kit.button(reveal, "ÉQUIPER", {
		Primary = true,
		Accent = C.Cyan,
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(0, 0, 1, -40),
	}, function()
		if lastForm then
			local ok = Remote.call("Equip", false, "Form", lastForm)
			if ok then
				Toast.show("Voie équipée.", "Success")
				equipBtn.Visible = false
			end
		end
	end)
	Kit.button(reveal, "VOIR LES CHANCES", { Size = UDim2.fromOffset(170, 40), Position = UDim2.new(0, 160, 1, -40) }, function()
		reveal.Visible = false
		odds.Visible = true
	end)

	-- Panneau droit : solde, pitié, bouton
	local right = Kit.panel(root, { Position = UDim2.new(0.6, 10, 0, 250), Size = UDim2.new(0.4, -10, 1, -250) })
	Kit.padding(right, 14)
	local balance = Kit.label(right, "", { Size = UDim2.new(1, 0, 0, 30), FontFace = Theme.Fonts.Display, TextSize = 20, TextColor3 = C.Gold })
	Kit.label(right, string.format("Coût d'une relance : %d Cristaux", Theme.RerollCost), {
		Position = UDim2.fromOffset(0, 34),
		TextColor3 = C.TextDim,
		TextSize = 13,
	})
	local pityText = Kit.label(right, "", { Position = UDim2.fromOffset(0, 66), TextSize = 13 })
	local pityBar = Kit.bar(right, Theme.rarityColor("Epique"), { Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 12) })
	local spinning = false
	local spinBtn: TextButton

	local function refresh()
		local p = ctx.profile()
		if not p then
			return
		end
		balance.Text = "◆ " .. Kit.formatNumber(p.Crystals or 0)
		local pity = tonumber(p.RerollPity) or 0
		pityText.Text = string.format("Garantie Épique ou mieux dans %d tirage(s)", math.max(PITY_LIMIT - pity, 1))
		pityBar.set(pity / PITY_LIMIT)
		for id, lbl in oddsRows do
			local owned = p.OwnedForms and p.OwnedForms[id]
			lbl.TextColor3 = if owned then C.Text else C.TextDim
			local f = FormData.get(id)
			if f then
				lbl.Text = string.format("%s · %s%s", f.Roman, f.Name, if owned then "  ✓" else "")
			end
		end
		spinBtn.Active = not spinning
		spinBtn.AutoButtonColor = false
		spinBtn.BackgroundTransparency = if spinning or (p.Crystals or 0) < Theme.RerollCost then 0.6 else 0
	end

	local function buildReel(result: any)
		Kit.clear(strip)
		strip.Position = UDim2.fromOffset(0, 0)
		local rng = Random.new()
		for i = 1, REEL_LEN do
			local f: any
			if i == RESULT_INDEX then
				f = result
			elseif i % 5 == 0 then
				f = FormData.List[rng:NextInteger(1, #FormData.List)] -- un peu de suspense visuel
			else
				f = FormData.pick(rng:NextNumber() * FormData.TotalWeight)
			end
			formCard(strip, f, i)
		end
	end

	local function showReveal(data: any)
		local f = FormData.get(data.FormId)
		if not f then
			return
		end
		local color = Theme.rarityColor(f.Rarity)
		flash.BackgroundTransparency = 0
		Kit.tween(flash, 0.9, { BackgroundTransparency = 1 })
		Kit.sound("Reveal", 0.7)
		if Theme.rarityOrder(f.Rarity) >= 4 then
			Kit.sound("Ping", 0.8, 0.8)
		end
		odds.Visible = false
		reveal.Visible = true
		revTitle.Text = string.format("%s · %s", f.Roman, f.Name)
		revTitle.TextColor3 = color
		revRarity.Text = string.upper(Theme.rarityLabel(f.Rarity)) .. (if data.Forced then "  ·  GARANTIE" else "")
		revRarity.TextColor3 = color
		revDesc.Text = f.Description
		revPassive.Text = "Passif : " .. f.Passive
		revNote.Text = if data.Duplicate
			then string.format("Déjà possédée : +%d Cristaux rendus.", data.Refund or 0)
			else "Nouvelle Voie débloquée !"
		lastForm = f.Id
		local p = ctx.profile()
		equipBtn.Visible = not (p and p.EquippedForm == f.Id)
	end

	spinBtn = Kit.button(right, "RELANCER", {
		Primary = true,
		Accent = C.Gold,
		Size = UDim2.new(1, 0, 0, 54),
		Position = UDim2.new(0, 0, 1, -54),
		TextSize = 20,
		Font = Theme.Fonts.Display,
	}, function()
		if spinning then
			return
		end
		spinning = true
		refresh()
		local ok, data = Remote.call("Reroll", false)
		if not ok or type(data) ~= "table" then
			spinning = false
			refresh()
			return
		end
		local result = FormData.get(data.FormId)
		if not result then
			spinning = false
			refresh()
			return
		end
		reveal.Visible = false
		odds.Visible = true
		buildReel(result)
		-- les positions sont en pixels « non mis à l'échelle » : on retire le facteur UIScale mesuré sur la bande
		local uiScale = if strip.AbsoluteSize.X > 0 then strip.AbsoluteSize.X / (REEL_LEN * STEP) else 1
		local centerX = (reel.AbsoluteSize.X / 2) / uiScale
		local jitter = Random.new():NextNumber(-CARD_W * 0.35, CARD_W * 0.35)
		local target = -((RESULT_INDEX - 1) * STEP + CARD_W / 2 - centerX + jitter)
		local tween = Kit.tween(strip, 4.4, { Position = UDim2.fromOffset(target, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local lastCard = -1
		local tick = RunService.RenderStepped:Connect(function()
			local idx = math.floor((-strip.Position.X.Offset + centerX) / STEP)
			if idx ~= lastCard then
				lastCard = idx
				Kit.sound("Spin", 0.18, 1.5)
			end
		end)
		tween.Completed:Wait()
		tick:Disconnect()
		showReveal(data)
		spinning = false
		refresh()
	end)

	local page: PageTypes.Page = {
		Id = "Reroll",
		Title = "Relance",
		Icon = "◆",
		Root = root,
		onShow = function()
			refresh()
		end,
		onProfile = function()
			refresh()
		end,
	}
	return page
end

return RerollPage
