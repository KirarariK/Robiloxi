--!strict
-- HUD de duel : tableau des scores (pastilles de rounds), chrono, barres PV / posture / endurance des deux
-- combattants (attributs Character : HealthPct, Posture, MaxPosture, Stamina, MaxStamina, CombatState),
-- bannières de phase. N'existe qu'en duel ; tout est libéré par le Maid à la fin.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Maid = require(Shared.Util.Maid)

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)
local State = require(script.Parent.State)

local C = Theme.Colors

local MODE_LABEL: { [string]: string } = {
	Ranked = "DUEL CLASSÉ · BO5",
	Casual = "DUEL AMICAL · BO3",
	Challenge = "DÉFI · BO3",
}

local STATE_LABEL: { [string]: string } = {
	Blocking = "GARDE",
	Parrying = "PARADE",
	Dodging = "ESQUIVE",
	Stunned = "ÉTOURDI",
	GuardBroken = "GARDE BRISÉE",
	Dead = "K.O.",
}

export type DuelHud = {
	update: (view: State.MatchView, prev: State.MatchView?) -> (),
	destroy: () -> (),
}

type Fighter = {
	Name: TextLabel,
	Health: Kit.Bar,
	Posture: Kit.Bar,
	Stamina: Kit.Bar,
	State: TextLabel,
	Pips: { Frame },
	Shown: { Health: number, Posture: number, Stamina: number },
}

local DuelHud = {}

local function attrNum(char: Model?, name: string, default: number): number
	if not char then
		return default
	end
	local v = char:GetAttribute(name)
	return if type(v) == "number" and v == v then v else default
end

function DuelHud.new(): DuelHud
	local maid = Maid.new()
	local gui = Root.gui("Hud")
	local layer = Kit.new("Frame", { Name = "DuelHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	maid:Give(layer)

	-- Tableau des scores (haut centre)
	local board = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(620, 96),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	Root.scale(board)
	local center = Kit.panel(board, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(150, 70),
		BackgroundColor3 = C.Night,
	})
	local roundLbl = Kit.label(center, "", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Title,
		TextSize = 11,
		TextColor3 = C.Gold,
	})
	local timerLbl = Kit.label(center, "", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 26,
	})
	local modeLbl = Kit.label(board, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(400, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 11,
		TextColor3 = C.TextDim,
	})

	local function fighter(side: number): Fighter
		-- side 0 = moi (gauche), 1 = adversaire (droite)
		local accent = if side == 0 then C.Cyan else C.Danger
		local panel = Kit.panel(board, {
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.fromScale(side, 0),
			Size = UDim2.fromOffset(220, 70),
			BackgroundColor3 = C.Night,
		})
		local align = if side == 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		local name = Kit.label(panel, "", {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 20),
			TextXAlignment = align,
			FontFace = Theme.Fonts.Bold,
			TextSize = 15,
			TextColor3 = accent,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		})
		local pipRow = Kit.new("Frame", {
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -24, 0, 14),
			BackgroundTransparency = 1,
			Parent = panel,
		})
		local layout = Kit.list(pipRow, true, 6, if side == 0 then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		local state = Kit.label(panel, "", {
			Position = UDim2.fromOffset(12, 48),
			Size = UDim2.new(1, -24, 0, 16),
			TextXAlignment = align,
			FontFace = Theme.Fonts.Title,
			TextSize = 11,
			TextColor3 = C.Gold,
		})
		-- barres (sous le tableau pour l'adversaire, en bas à gauche pour moi)
		local bars = Kit.new("Frame", { BackgroundTransparency = 1, Parent = layer })
		if side == 0 then
			bars.AnchorPoint = Vector2.new(0, 1)
			bars.Position = UDim2.new(0, 24, 1, -24)
			bars.Size = UDim2.fromOffset(340, 74)
		else
			bars.AnchorPoint = Vector2.new(1, 0)
			bars.Position = UDim2.new(1, -24, 0, 120)
			bars.Size = UDim2.fromOffset(300, 64)
		end
		Root.scale(bars)
		Kit.list(bars, false, 6)
		local hp = Kit.bar(bars, C.Health, { Size = UDim2.new(1, 0, 0, if side == 0 then 22 else 18), LayoutOrder = 1 })
		local po = Kit.bar(bars, C.Posture, { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2 })
		local st = Kit.bar(bars, C.Stamina, { Size = UDim2.new(if side == 0 then 0.8 else 1, 0, 0, 12), LayoutOrder = 3 })
		return {
			Name = name,
			Health = hp,
			Posture = po,
			Stamina = st,
			State = state,
			Pips = (function(): { Frame }
				local list: { Frame } = {}
				for i = 1, 3 do
					local pip = Kit.new("Frame", {
						Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = C.Panel,
						LayoutOrder = if side == 0 then i else -i,
						Parent = pipRow,
					})
					Kit.round(pip)
					Kit.stroke(pip, accent, 1.5, 0.2)
					table.insert(list, pip)
				end
				return list
			end)(),
			Shown = { Health = 1, Posture = 1, Stamina = 1 },
		}
	end

	local me = fighter(0)
	local opp = fighter(1)

	-- Bannière de phase
	local banner = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(800, 140),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	Root.scale(banner)
	local bannerTitle = Kit.label(banner, "", {
		Size = UDim2.new(1, 0, 0, 80),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 60,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
	})
	local bannerGrad = Kit.gradient(bannerTitle, { C.Cyan, Color3.new(1, 1, 1) }, 0)
	local bannerSub = Kit.label(banner, "", {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 20,
		TextTransparency = 1,
	})
	local bannerToken = 0
	local function showBanner(title: string, sub: string, colors: { Color3 }, hold: number)
		bannerToken += 1
		local my = bannerToken
		bannerTitle.Text = title
		bannerSub.Text = sub
		local kps = {}
		for i, c in colors do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), c))
		end
		if #kps == 1 then
			table.insert(kps, ColorSequenceKeypoint.new(1, colors[1]))
		end
		bannerGrad.Color = ColorSequence.new(kps)
		bannerTitle.TextSize = 80
		Kit.tween(bannerTitle, 0.35, { TextTransparency = 0, TextSize = 60 }, Enum.EasingStyle.Back)
		Kit.tween(bannerSub, 0.35, { TextTransparency = 0 })
		task.delay(hold, function()
			if bannerToken == my then
				Kit.tween(bannerTitle, 0.4, { TextTransparency = 1 })
				Kit.tween(bannerSub, 0.4, { TextTransparency = 1 })
			end
		end)
	end

	local view: State.MatchView = State.match
	local lp = Players.LocalPlayer

	local function setPips(f: Fighter, score: number, toWin: number)
		for i, pip in f.Pips do
			pip.Visible = i <= toWin
			pip.BackgroundColor3 = if i <= score then C.Gold else C.Panel
		end
	end

	local function readFighter(f: Fighter, char: Model?, dt: number)
		local hp = attrNum(char, "HealthPct", -1)
		if hp < 0 then
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			hp = if hum and hum.MaxHealth > 0 then hum.Health / hum.MaxHealth else 0
		end
		local maxPo = math.max(attrNum(char, "MaxPosture", 100), 1)
		local po = attrNum(char, "Posture", maxPo) / maxPo
		local maxSt = math.max(attrNum(char, "MaxStamina", 100), 1)
		local st = attrNum(char, "Stamina", maxSt) / maxSt
		local k = math.clamp(dt * 12, 0, 1)
		f.Shown.Health += (hp - f.Shown.Health) * k
		f.Shown.Posture += (po - f.Shown.Posture) * k
		f.Shown.Stamina += (st - f.Shown.Stamina) * k
		f.Health.set(f.Shown.Health, string.format("PV %d %%", math.floor(math.clamp(hp, 0, 1) * 100 + 0.5)))
		f.Posture.set(f.Shown.Posture, "Posture")
		f.Stamina.set(f.Shown.Stamina, "Endurance")
		local cs = char and char:GetAttribute("CombatState")
		f.State.Text = if type(cs) == "string" then (STATE_LABEL[cs] or "") else ""
		f.State.TextColor3 = if cs == "GuardBroken" or cs == "Stunned" or cs == "Dead" then C.Danger else C.Gold
	end

	maid:Give(RunService.RenderStepped:Connect(function(dt: number)
		readFighter(me, lp.Character, dt)
		local oppPlayer = if view.OpponentUserId then Players:GetPlayerByUserId(view.OpponentUserId) else nil
		readFighter(opp, if oppPlayer then oppPlayer.Character else nil, dt)
		if view.Phase == "Round" and view.RoundEndsAt then
			local left = math.max(0, view.RoundEndsAt - Workspace:GetServerTimeNow())
			timerLbl.Text = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
			timerLbl.TextColor3 = if left <= 10 then C.Danger else C.Text
		elseif view.Phase == "Intro" or view.Phase == "Preparing" then
			timerLbl.Text = "VS"
			timerLbl.TextColor3 = C.Gold
		end
	end))

	local function update(v: State.MatchView, prev: State.MatchView?)
		view = v
		local toWin = v.RoundsToWin or 2
		me.Name.Text = lp.DisplayName
		opp.Name.Text = v.OpponentName or "Adversaire"
		setPips(me, v.MyScore or 0, toWin)
		setPips(opp, v.OppScore or 0, toWin)
		roundLbl.Text = if (v.Round or 0) > 0 then "ROUND " .. tostring(v.Round) else "DUEL"
		modeLbl.Text = (MODE_LABEL[v.Mode or ""] or "DUEL") .. "  ·  " .. (v.ArenaName or "")
		local changed = prev == nil or prev.Phase ~= v.Phase or prev.Round ~= v.Round
		if not changed then
			return
		end
		if v.Phase == "Intro" then
			showBanner(string.upper(v.ArenaName or "ARÈNE"), (MODE_LABEL[v.Mode or ""] or "") .. "  ·  contre " .. (v.OpponentName or "?"), { C.Gold, Color3.new(1, 1, 1) }, 3)
		elseif v.Phase == "Round" then
			local last = (v.MyScore or 0) + 1 >= toWin and (v.OppScore or 0) + 1 >= toWin
			showBanner("ROUND " .. tostring(v.Round), if last then "Round décisif — combattez !" else "Combattez !", { C.Cyan, Color3.new(1, 1, 1) }, 1.6)
			Kit.sound("Metal", 0.5)
		elseif v.Phase == "RoundEnd" then
			local won = v.LastRoundWinnerUserId == lp.UserId
			showBanner(if won then "ROUND REMPORTÉ" else "ROUND PERDU", string.format("%d — %d", v.MyScore or 0, v.OppScore or 0), if won then { C.Cyan, C.Gold } else { C.Danger, Color3.new(1, 1, 1) }, 2)
		elseif v.Phase == "Finisher" then
			local won = v.WinnerUserId == lp.UserId
			showBanner(if won then "EXÉCUTION" else "VAINCU", "", if won then { C.Gold, Color3.new(1, 1, 1) } else { C.Danger, C.Night }, 2)
		elseif v.Phase == "Victory" then
			local won = v.WinnerUserId == lp.UserId
			showBanner(if won then "VICTOIRE" else "DÉFAITE", if v.Forfeit then (if won then "Ton adversaire a abandonné" else "Abandon") else string.format("%d — %d", v.MyScore or 0, v.OppScore or 0), if won then { C.Gold, Color3.new(1, 1, 1), C.Gold } else { C.Danger, Color3.fromRGB(120, 30, 40) }, 4)
			if won then
				Kit.sound("Victory", 0.7)
			end
		end
	end

	local hud: DuelHud = {
		update = update,
		destroy = function()
			maid:Clean()
		end,
	}
	return hud
end

return DuelHud
