--!strict
-- Écran de fin de match : Victoire / Défaite, score, Elo avant → après (compteur animé), changement de rang,
-- Cristaux gagnés, maîtrise de Voie, titres débloqués. Se ferme sur « Continuer » ou après 14 s.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local RankData = require(Shared.Config.RankData)
local FormData = require(Shared.Config.FormData)
local TitleData = require(Shared.Config.TitleData)

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)

local C = Theme.Colors

local MatchEnd = {}

local current: Frame? = nil

local function tierById(id: string): any
	for _, t in RankData.Tiers do
		if t.Id == id then
			return t
		end
	end
	return RankData.Tiers[1]
end

function MatchEnd.close()
	local f = current
	if not f then
		return
	end
	current = nil
	Kit.tween(f, 0.3, { BackgroundTransparency = 1 })
	local card = f:FindFirstChild("Card")
	if card and card:IsA("GuiObject") then
		Kit.tween(card, 0.3, { Position = UDim2.fromScale(0.5, 0.56) })
	end
	task.delay(0.3, function()
		f:Destroy()
	end)
end

function MatchEnd.show(r: { [string]: any })
	MatchEnd.close()
	local won = r.Won == true
	local accent = if won then C.Gold else C.Danger
	local overlay = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 1,
		Parent = Root.gui("Overlay"),
	})
	current = overlay
	Kit.tween(overlay, 0.4, { BackgroundTransparency = 0.35 })
	local card = Kit.panel(overlay, {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(560, 470),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.04,
	})
	Root.scale(card)
	Kit.tween(card, 0.5, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
		stroke.Thickness = 2
		stroke.Transparency = 0.1
	end
	Kit.padding(card, 22)

	local title = Kit.label(card, if won then "VICTOIRE" else "DÉFAITE", {
		Size = UDim2.new(1, 0, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 46,
		TextColor3 = Color3.new(1, 1, 1),
	})
	Kit.gradient(title, if won then { C.Gold, Color3.new(1, 1, 1), C.Gold } else { C.Danger, Color3.fromRGB(255, 200, 200) }, 0)
	local modeName = if r.Mode == "Ranked" then "Duel classé" elseif r.Mode == "Challenge" then "Défi" else "Duel amical"
	Kit.label(card, string.format("%s  ·  %d — %d contre %s%s", modeName, r.MyScore or 0, r.OppScore or 0, tostring(r.OpponentName or "?"), if r.Forfeit then "  ·  par abandon" else ""), {
		Position = UDim2.fromOffset(0, 62),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
		TextSize = 14,
	})

	-- statistiques du duel (comme Dueling Grounds : parades parfaites, gardes brisées, contres)
	local st = if type(r.Stats) == "table" then r.Stats else {}
	Kit.label(card, string.format("Parades parfaites %d  ·  Gardes brisées %d  ·  Contres %d", tonumber(st.Parries) or 0, tonumber(st.Breaks) or 0, tonumber(st.Counters) or 0), {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Gold,
		TextSize = 13,
	})

	-- Elo
	local eloBox = Kit.new("Frame", { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = C.Night, BackgroundTransparency = 0.3, Parent = card })
	Kit.corner(eloBox, 12)
	local eloNum = Kit.label(eloBox, "", {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 34,
	})
	local eloSub = Kit.label(eloBox, "", {
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 15,
	})
	local delta = tonumber(r.EloDelta) or 0
	if r.Mode == "Ranked" then
		local from, to = tonumber(r.EloBefore) or 0, tonumber(r.EloAfter) or 0
		eloNum.Text = tostring(from)
		eloSub.Text = string.format("%s%d Elo", if delta >= 0 then "+" else "", delta)
		eloSub.TextColor3 = if delta >= 0 then C.Success else C.Danger
		local t0 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0 - 0.6) / 1.4, 0, 1)
			local e = 1 - (1 - k) ^ 3
			eloNum.Text = tostring(math.floor(from + (to - from) * e + 0.5)) .. " Elo"
			if k >= 1 or not overlay.Parent then
				conn:Disconnect()
			end
		end)
		local before, after = tierById(r.TierBefore or ""), tierById(r.TierAfter or "")
		eloNum.TextColor3 = after.Color
		if before.Id ~= after.Id then
			local promoted = after.MinElo > before.MinElo
			task.delay(2.1, function()
				if overlay.Parent then
					eloSub.Text = (if promoted then "Promotion : " else "Rétrogradation : ") .. after.Name
					eloSub.TextColor3 = after.Color
					if promoted then
						Kit.sound("Ping", 0.7, 0.9)
					end
				end
			end)
		end
	else
		eloNum.Text = "Elo inchangé"
		eloNum.TextColor3 = C.TextDim
		eloSub.Text = "Seuls les duels classés modifient l'Elo"
		eloSub.TextColor3 = C.TextDim
	end

	-- Récompenses
	local rewards = Kit.new("Frame", { Position = UDim2.fromOffset(0, 206), Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, Parent = card })
	Kit.list(rewards, false, 6)
	local function line(text: string, color: Color3, order: number)
		local l = Kit.label(rewards, text, {
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = Theme.Fonts.Bold,
			TextSize = 16,
			TextColor3 = color,
			TextTransparency = 1,
		})
		task.delay(0.4 + order * 0.25, function()
			if l.Parent then
				Kit.tween(l, 0.3, { TextTransparency = 0 })
			end
		end)
	end
	line(string.format("+%d Cristaux ◆", tonumber(r.Reward) or 0), C.Gold, 1)
	if won and type(r.MasteryForm) == "string" then
		local f = FormData.get(r.MasteryForm)
		line(string.format("Maîtrise %s : %d", if f then f.Name else r.MasteryForm, tonumber(r.MasteryValue) or 0), C.Cyan, 2)
	end
	if won and (tonumber(r.WinStreak) or 0) >= 2 then
		line(string.format("Série de %d victoires !", r.WinStreak), C.Success, 3)
	end
	if type(r.NewTitles) == "table" then
		for i, id in r.NewTitles do
			local def = TitleData.get(id)
			if def then
				line("Titre débloqué : « " .. def.Text .. " »", Theme.rarityColor(def.Rarity), 3 + i)
			end
		end
	end

	Kit.button(card, "CONTINUER", {
		Primary = true,
		Accent = accent,
		Size = UDim2.fromOffset(220, 46),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		TextSize = 17,
		Font = Theme.Fonts.Display,
	}, function()
		MatchEnd.close()
	end)
	task.delay(14, function()
		if current == overlay then
			MatchEnd.close()
		end
	end)
end

return MatchEnd
