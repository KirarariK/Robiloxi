--!strict
-- Page « Profil » : rang, Elo, progression vers le rang suivant, statistiques, équipement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local RankData = require(Shared.Config.RankData)
local FormData = require(Shared.Config.FormData)
local WeaponData = require(Shared.Config.WeaponData)
local SaberColors = require(Shared.Config.SaberColors)
local TitleData = require(Shared.Config.TitleData)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local PageTypes = require(script.Parent.PageTypes)

local C = Theme.Colors

local ProfilePage = {}

function ProfilePage.build(container: Frame, ctx: PageTypes.Ctx): PageTypes.Page
	local lp = Players.LocalPlayer
	local root = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = container })

	local card = Kit.panel(root, { Size = UDim2.new(0, 300, 1, 0) })
	Kit.padding(card, 16)
	local avatar = Kit.new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = C.Night,
		Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", lp.UserId),
		Parent = card,
	})
	Kit.round(avatar)
	local avatarRing = Kit.stroke(avatar, C.Cyan, 3, 0)
	Kit.label(card, lp.DisplayName, {
		Position = UDim2.fromOffset(0, 130),
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 18,
	})
	local titleLbl = Kit.label(card, "", {
		Position = UDim2.fromOffset(0, 158),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
	})
	local titleGrad = Kit.gradient(titleLbl, { C.Text }, 0)
	local tierLbl = Kit.label(card, "", {
		Position = UDim2.fromOffset(0, 196),
		Size = UDim2.new(1, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 24,
	})
	local eloLbl = Kit.label(card, "", {
		Position = UDim2.fromOffset(0, 232),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 16,
		TextColor3 = C.Cyan,
	})
	local nextBar = Kit.bar(card, C.Cyan, { Position = UDim2.fromOffset(0, 264), Size = UDim2.new(1, 0, 0, 16) })
	local nextLbl = Kit.label(card, "", {
		Position = UDim2.fromOffset(0, 284),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = C.TextDim,
	})
	local penaltyLbl = Kit.label(card, "", {
		Position = UDim2.new(0, 0, 1, -40),
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = C.Danger,
	})

	local statsPanel = Kit.panel(root, { Position = UDim2.fromOffset(316, 0), Size = UDim2.new(1, -316, 1, 0) })
	Kit.padding(statsPanel, 16)
	Kit.label(statsPanel, "STATISTIQUES", { FontFace = Theme.Fonts.Title, TextSize = 14, TextColor3 = C.Gold })
	local grid = Kit.new("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 260), BackgroundTransparency = 1, Parent = statsPanel })
	Kit.grid(grid, Vector2.new(170, 74), 10)
	Kit.label(statsPanel, "ÉQUIPEMENT", { Position = UDim2.fromOffset(0, 300), FontFace = Theme.Fonts.Title, TextSize = 14, TextColor3 = C.Gold })
	local gear = Kit.label(statsPanel, "", {
		Position = UDim2.fromOffset(0, 328),
		Size = UDim2.new(1, 0, 1, -328),
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	})

	local function stat(label: string, value: string, order: number, color: Color3?)
		local f = Kit.new("Frame", { BackgroundColor3 = C.Bg, BackgroundTransparency = 0.2, LayoutOrder = order, Parent = grid })
		Kit.corner(f, 10)
		Kit.stroke(f, C.Line, 1, 0.3)
		Kit.label(f, value, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 32),
			FontFace = Theme.Fonts.Display,
			TextSize = 22,
			TextColor3 = color or C.Text,
		})
		Kit.label(f, label, { Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 18), TextSize = 12, TextColor3 = C.TextDim })
	end

	local function render()
		local p = ctx.profile()
		if not p then
			return
		end
		local wr = lp:GetAttribute("EB_WorldRank")
		local worldRank = if type(wr) == "number" and wr > 0 then wr else nil
		local tier = RankData.tierFor(p.Elo or RankData.StartElo, worldRank)
		tierLbl.Text = string.upper(tier.Name)
		tierLbl.TextColor3 = tier.Color
		avatarRing.Color = tier.Color
		eloLbl.Text = string.format("%s Elo  ·  record %s%s", Kit.formatNumber(p.Elo or 0), Kit.formatNumber(p.PeakElo or 0), if worldRank then string.format("  ·  #%d mondial", worldRank) else "")
		local nextTier: any = nil
		for _, t in RankData.Tiers do
			if t.MinElo > (p.Elo or 0) then
				nextTier = t
				break
			end
		end
		if nextTier then
			local lo = tier.MinElo
			nextBar.set(((p.Elo or 0) - lo) / math.max(nextTier.MinElo - lo, 1), string.format("%d / %d", p.Elo or 0, nextTier.MinElo))
			nextLbl.Text = "Prochain rang : " .. nextTier.Name .. (if nextTier.TopOnly then " (top 50 mondial)" else "")
		else
			nextBar.set(1, "Sommet atteint")
			nextLbl.Text = if tier.Id == "GrandMaitre" then "Tu fais partie de l'élite mondiale." else "Entre dans le top 50 pour devenir Grand Maître."
		end
		local t = TitleData.get(p.EquippedTitle or "")
		titleLbl.Text = if t then "« " .. t.Text .. " »" else ""
		if t then
			local kps = {}
			for i, col in t.Gradient do
				table.insert(kps, ColorSequenceKeypoint.new((i - 1) / math.max(#t.Gradient - 1, 1), col))
			end
			if #kps == 1 then
				table.insert(kps, ColorSequenceKeypoint.new(1, t.Gradient[1]))
			end
			titleGrad.Color = ColorSequence.new(kps)
		end
		local penalty = (p.LeavePenaltyUntil or 0) - os.time()
		penaltyLbl.Text = if penalty > 0 then string.format("Pénalité d'abandon : file classée bloquée %d s", penalty) else ""

		Kit.clear(grid, true)
		local wins, losses = p.Wins or 0, p.Losses or 0
		local ratio = if wins + losses > 0 then math.floor(wins / (wins + losses) * 100 + 0.5) else 0
		stat("Victoires", Kit.formatNumber(wins), 1, C.Success)
		stat("Défaites", Kit.formatNumber(losses), 2, C.Danger)
		stat("Taux de victoire", ratio .. " %", 3)
		stat("Série en cours", tostring(p.WinStreak or 0), 4, C.Gold)
		stat("Meilleure série", tostring(p.BestStreak or 0), 5, C.Gold)
		stat("Duels classés", Kit.formatNumber(p.RankedPlayed or 0), 6)
		stat("Relances", Kit.formatNumber(p.Rerolls or 0), 7)
		stat("Cristaux", "◆ " .. Kit.formatNumber(p.Crystals or 0), 8, C.Gold)
		local owned = 0
		for _ in p.OwnedForms or {} do
			owned += 1
		end
		stat("Voies possédées", string.format("%d / %d", owned, #FormData.List), 9, C.Cyan)

		local f = FormData.get(p.EquippedForm or "")
		local w = WeaponData.get(p.EquippedWeapon or "")
		local c = SaberColors.get(p.EquippedColor or "")
		local mastery = if f and p.FormMastery then p.FormMastery[f.Id] or 0 else 0
		gear.Text = string.format(
			"Voie : <b>%s</b> (maîtrise %d)\nArme : <b>%s</b>\nCristal : <b><font color=\"#%s\">%s</font></b>",
			if f then f.Roman .. " · " .. f.Name else "?",
			mastery,
			if w then w.Name else "?",
			if c then c.Glow:ToHex() else "FFFFFF",
			if c then c.Name else "?"
		)
	end

	local page: PageTypes.Page = {
		Id = "Profile",
		Title = "Profil",
		Icon = "☰",
		Root = root,
		onShow = function()
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

return ProfilePage
