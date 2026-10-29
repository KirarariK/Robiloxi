--!strict
-- Page « Atelier de lame » (ouverte au SaberBench) : aperçu 3D, choix de l'arme et ses stats,
-- grille des cristaux de lame par catégorie (verrouillés avec prix), achat / équipement.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local SaberColors = require(Shared.Config.SaberColors)
local WeaponData = require(Shared.Config.WeaponData)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Remote = require(UI.Remote)
local Toast = require(UI.Toast)
local SaberPreview = require(UI.SaberPreview)
local PageTypes = require(script.Parent.PageTypes)

local C = Theme.Colors

local CATEGORIES = {
	{ Id = "Classique", Label = "CLASSIQUES" },
	{ Id = "Speciale", Label = "SPÉCIALES" },
	{ Id = "Mythique", Label = "MYTHIQUES" },
}

local EFFECT_LABEL: { [string]: string } = {
	None = "",
	DarkCore = "Cœur d'ombre",
	Unstable = "Lame instable, crépitante",
	InkCore = "Cœur d'encre",
	Prism = "Prisme changeant",
	Nebula = "Nébuleuse mouvante",
}

local WorkshopPage = {}

function WorkshopPage.build(container: Frame, ctx: PageTypes.Ctx): PageTypes.Page
	local root = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = container })
	Kit.label(root, "ATELIER DE LAME", { Size = UDim2.new(1, 0, 0, 30), FontFace = Theme.Fonts.Display, TextSize = 24, TextColor3 = C.Cyan })

	local selectedWeapon = WeaponData.Default :: string
	local selectedColor = SaberColors.Default

	-- Colonne gauche : aperçu + arme
	local preview = SaberPreview.new(root, UDim2.fromOffset(300, 300), UDim2.fromOffset(0, 40))
	local colorName = Kit.label(preview.Frame, "", {
		Position = UDim2.new(0, 12, 1, -52),
		Size = UDim2.new(1, -24, 0, 22),
		FontFace = Theme.Fonts.Display,
		TextSize = 15,
		ZIndex = 3,
	})
	local colorFx = Kit.label(preview.Frame, "", {
		Position = UDim2.new(0, 12, 1, -28),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 12,
		TextColor3 = C.TextDim,
		ZIndex = 3,
	})
	Kit.label(preview.Frame, "Glisse pour tourner", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 16),
		TextSize = 11,
		TextColor3 = C.TextDim,
		ZIndex = 3,
	})

	local weaponRow = Kit.new("Frame", { Position = UDim2.fromOffset(0, 350), Size = UDim2.fromOffset(300, 40), BackgroundTransparency = 1, Parent = root })
	Kit.list(weaponRow, true, 6)
	local weaponButtons: { [string]: TextButton } = {}

	local stats = Kit.panel(root, { Position = UDim2.fromOffset(0, 398), Size = UDim2.new(0, 300, 1, -398) })
	Kit.padding(stats, 10, 8)
	Kit.list(stats, false, 3)
	local weaponDesc = Kit.label(stats, "", { Size = UDim2.new(1, 0, 0, 30), TextSize = 12, TextColor3 = C.TextDim, LayoutOrder = 0 })
	type StatRow = { Bar: Kit.Bar, Get: (w: any) -> number, Max: number }
	local statRows: { StatRow } = {}
	local function statRow(label: string, order: number, max: number, get: (w: any) -> number)
		local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = order, Parent = stats })
		Kit.label(row, label, { Size = UDim2.new(0.42, 0, 1, 0), TextSize = 12, FontFace = Theme.Fonts.Bold })
		local bar = Kit.bar(row, C.Cyan, { Position = UDim2.new(0.42, 0, 0, 3), Size = UDim2.new(0.58, 0, 0, 10) })
		table.insert(statRows, { Bar = bar, Get = get, Max = max })
	end
	statRow("Dégâts", 1, 20, function(w)
		return w.HeavyDamage
	end)
	statRow("Cadence", 2, 1.4, function(w)
		return w.AttackSpeed
	end)
	statRow("Posture", 3, 115, function(w)
		return w.MaxPosture
	end)
	statRow("Portée", 4, 7.5, function(w)
		return w.Reach
	end)
	statRow("Zone", 5, 360, function(w)
		return w.Arc
	end)

	-- Colonne droite : grille des cristaux
	local right = Kit.panel(root, { Position = UDim2.fromOffset(316, 40), Size = UDim2.new(1, -316, 1, -100) })
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Cyan,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = right,
	})
	Kit.padding(scroll, 10)
	Kit.list(scroll, false, 8)
	local refresh: () -> () = function() end
	type Swatch = { Button: TextButton, Lock: TextLabel, Ring: UIStroke, Def: any }
	local swatches: { Swatch } = {}
	for ci, cat in CATEGORIES do
		Kit.label(scroll, cat.Label, { FontFace = Theme.Fonts.Title, TextSize = 13, TextColor3 = C.Gold, LayoutOrder = ci * 2 - 1 })
		local grid = Kit.new("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = ci * 2,
			Parent = scroll,
		})
		Kit.grid(grid, Vector2.new(112, 96), 8)
		for i, def in SaberColors.List do
			if def.Category == cat.Id then
				local b = Kit.new("TextButton", {
					Text = "",
					AutoButtonColor = false,
					BackgroundColor3 = C.Bg,
					LayoutOrder = i,
					Parent = grid,
				})
				Kit.corner(b, 10)
				local ring = Kit.stroke(b, Theme.rarityColor(def.Rarity), 1.5, 0.5)
				local orb = Kit.new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 10),
					Size = UDim2.fromOffset(40, 40),
					BackgroundColor3 = def.Glow,
					Parent = b,
				})
				Kit.round(orb)
				Kit.gradient(orb, { def.Core, def.Glow }, 90)
				Kit.stroke(orb, def.Glow, 3, 0.3)
				Kit.label(b, def.Name, {
					Position = UDim2.fromOffset(4, 54),
					Size = UDim2.new(1, -8, 0, 18),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextSize = 11,
					FontFace = Theme.Fonts.Bold,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextWrapped = false,
				})
				local lock = Kit.label(b, "", {
					Position = UDim2.fromOffset(4, 72),
					Size = UDim2.new(1, -8, 0, 16),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextSize = 11,
					TextColor3 = C.Gold,
				})
				local sw: Swatch = { Button = b, Lock = lock, Ring = ring, Def = def }
				table.insert(swatches, sw)
				b.Activated:Connect(function()
					Kit.sound("Click", 0.35)
					selectedColor = def.Id
					preview.set(selectedWeapon, selectedColor)
					refresh()
				end)
			end
		end
	end

	-- Barre d'action
	local action = Kit.panel(root, { Position = UDim2.new(0, 316, 1, -52), Size = UDim2.new(1, -316, 0, 52) })
	local actionText = Kit.label(action, "", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -200, 1, 0),
		FontFace = Theme.Fonts.Bold,
		TextSize = 14,
	})
	local actionBtn: TextButton
	actionBtn = Kit.button(action, "", {
		Primary = true,
		Size = UDim2.fromOffset(170, 38),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
	}, function()
		local p = ctx.profile()
		if not p then
			return
		end
		local def = SaberColors.get(selectedColor)
		if not def then
			return
		end
		if p.OwnedColors and p.OwnedColors[selectedColor] then
			if p.EquippedColor ~= selectedColor then
				if Remote.call("Equip", false, "Color", selectedColor) then
					Toast.show(def.Name .. " équipé.", "Success")
				end
			end
		else
			local ok = Remote.call("BuyColor", false, selectedColor)
			if ok then
				Kit.sound("Reveal", 0.6)
				Toast.show("Cristal « " .. def.Name .. " » acquis !", "Reward")
			end
		end
	end)

	refresh = function()
		local p = ctx.profile()
		if not p then
			return
		end
		for _, sw in swatches do
			local owned = p.OwnedColors and p.OwnedColors[sw.Def.Id]
			local equipped = p.EquippedColor == sw.Def.Id
			sw.Lock.Text = if equipped then "ÉQUIPÉ" elseif owned then "Possédé" else ("🔒 ◆ " .. Kit.formatNumber(Theme.colorPrice(sw.Def.Rarity)))
			sw.Lock.TextColor3 = if equipped then C.Cyan elseif owned then C.Success else C.Gold
			sw.Button.BackgroundTransparency = if owned then 0 else 0.45
			sw.Ring.Thickness = if sw.Def.Id == selectedColor then 3 else 1.5
			sw.Ring.Transparency = if sw.Def.Id == selectedColor then 0 else 0.5
		end
		local def = SaberColors.get(selectedColor)
		if def then
			colorName.Text = def.Name
			colorName.TextColor3 = def.Glow
			colorFx.Text = string.upper(Theme.rarityLabel(def.Rarity)) .. (if EFFECT_LABEL[def.Effect] ~= "" then " · " .. EFFECT_LABEL[def.Effect] else "")
			local owned = p.OwnedColors and p.OwnedColors[def.Id]
			if owned then
				actionText.Text = def.Name .. (if p.EquippedColor == def.Id then " — équipé" else "")
				actionBtn.Text = if p.EquippedColor == def.Id then "ÉQUIPÉ" else "ÉQUIPER"
			else
				local price = Theme.colorPrice(def.Rarity)
				actionText.Text = string.format("%s — %s ◆ (tu as %s)", def.Name, Kit.formatNumber(price), Kit.formatNumber(p.Crystals or 0))
				actionBtn.Text = "ACHETER"
			end
		end
		for id, b in weaponButtons do
			local on = id == selectedWeapon
			b.BackgroundColor3 = if on then C.Cyan else C.PanelLight
			b.TextColor3 = if on then C.Night else C.Text
		end
		local w = WeaponData.get(selectedWeapon)
		if w then
			weaponDesc.Text = w.Description
			for _, r in statRows do
				r.Bar.set(r.Get(w) / r.Max)
			end
		end
	end

	for i, id in WeaponData.Order do
		local w = WeaponData.get(id)
		local b = Kit.button(weaponRow, if w then w.Name else id, { Size = UDim2.fromOffset(96, 38), TextSize = 11, LayoutOrder = i }, function()
			selectedWeapon = id
			preview.set(selectedWeapon, selectedColor)
			refresh()
			Remote.call("Equip", false, "Weapon", id)
		end)
		weaponButtons[id] = b
	end

	local page: PageTypes.Page = {
		Id = "Workshop",
		Title = "Atelier",
		Icon = "⚔",
		Root = root,
		onShow = function()
			local p = ctx.profile()
			if p then
				selectedWeapon = p.EquippedWeapon or selectedWeapon
				selectedColor = p.EquippedColor or selectedColor
			end
			preview.set(selectedWeapon, selectedColor)
			refresh()
		end,
		onProfile = function()
			refresh()
		end,
	}
	return page
end

return WorkshopPage
