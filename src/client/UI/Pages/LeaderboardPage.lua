--!strict
-- Page « Classements » : top 50 mondial Elo / Victoires / Meilleure série (rafraîchi par le serveur toutes les 60 s).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local RankData = require(Shared.Config.RankData)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Remote = require(UI.Remote)
local State = require(UI.State)
local PageTypes = require(script.Parent.PageTypes)

local C = Theme.Colors

local BOARDS = {
	{ Id = "Elo", Label = "ELO", Unit = " Elo" },
	{ Id = "Wins", Label = "VICTOIRES", Unit = " V" },
	{ Id = "Streak", Label = "MEILLEURE SÉRIE", Unit = "" },
}

local LeaderboardPage = {}

function LeaderboardPage.build(container: Frame, _ctx: PageTypes.Ctx): PageTypes.Page
	local root = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = container })
	Kit.label(root, "CLASSEMENTS MONDIAUX", { Size = UDim2.new(1, 0, 0, 30), FontFace = Theme.Fonts.Display, TextSize = 24, TextColor3 = C.Gold })
	local updated = Kit.label(root, "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		Size = UDim2.fromOffset(300, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 12,
		TextColor3 = C.TextDim,
	})
	local tabsRow = Kit.new("Frame", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = root })
	Kit.list(tabsRow, true, 8)
	local mine = Kit.label(root, "", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 44),
		Size = UDim2.fromOffset(340, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Theme.Fonts.Bold,
		TextSize = 14,
		TextColor3 = C.Cyan,
	})
	local listPanel = Kit.panel(root, { Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -84) })
	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Cyan,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = listPanel,
	})
	Kit.padding(scroll, 8)

	local current = "Elo"
	local tabButtons: { [string]: TextButton } = {}

	local function render()
		for id, b in tabButtons do
			local on = id == current
			b.BackgroundColor3 = if on then C.Gold else C.PanelLight
			b.TextColor3 = if on then C.Night else C.Text
		end
		Kit.clear(scroll)
		Kit.padding(scroll, 8)
		Kit.list(scroll, false, 4)
		local snap = State.leaderboard
		local boards = snap and snap.Boards
		local entries: { any } = (boards and boards[current]) or {}
		local unit = ""
		for _, b in BOARDS do
			if b.Id == current then
				unit = b.Unit
			end
		end
		if snap and type(snap.UpdatedAt) == "number" and snap.UpdatedAt > 0 then
			updated.Text = "Mis à jour il y a " .. math.max(0, os.time() - snap.UpdatedAt) .. " s"
		else
			updated.Text = "En attente des premières données…"
		end
		local myId = Players.LocalPlayer.UserId
		local myRank: number? = nil
		for i, e in entries do
			local isMe = e.UserId == myId
			if isMe then
				myRank = e.Rank
			end
			local row = Kit.new("Frame", {
				Size = UDim2.new(1, -6, 0, 36),
				BackgroundColor3 = if isMe then C.CyanDeep else (if i % 2 == 0 then C.PanelLight else C.Bg),
				BackgroundTransparency = if isMe then 0.3 else 0.2,
				LayoutOrder = i,
				Parent = scroll,
			})
			Kit.corner(row, 8)
			local podium = if e.Rank == 1 then C.Gold elseif e.Rank == 2 then Color3.fromRGB(215, 222, 235) elseif e.Rank == 3 then Color3.fromRGB(215, 140, 80) else C.TextDim
			Kit.label(row, "#" .. e.Rank, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 60, 1, 0), FontFace = Theme.Fonts.Title, TextSize = 15, TextColor3 = podium })
			Kit.new("ImageLabel", {
				Position = UDim2.fromOffset(72, 4),
				Size = UDim2.fromOffset(28, 28),
				BackgroundColor3 = C.Night,
				Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", e.UserId),
				Parent = row,
			})
			Kit.label(row, e.Name, { Position = UDim2.fromOffset(110, 0), Size = UDim2.new(0.5, -110, 1, 0), FontFace = Theme.Fonts.Bold, TextSize = 14 })
			if current == "Elo" then
				local tier = RankData.tierFor(e.Value, e.Rank)
				Kit.label(row, tier.Name, {
					Position = UDim2.new(0.5, 0, 0, 0),
					Size = UDim2.new(0.25, 0, 1, 0),
					FontFace = Theme.Fonts.Title,
					TextSize = 12,
					TextColor3 = tier.Color,
				})
			end
			Kit.label(row, Kit.formatNumber(e.Value) .. unit, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.new(0.25, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				FontFace = Theme.Fonts.Bold,
				TextSize = 15,
				TextColor3 = C.Cyan,
			})
		end
		if #entries == 0 then
			Kit.label(scroll, "Aucun duelliste classé pour l'instant.", { TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center })
		end
		mine.Text = if myRank then string.format("Ta position : #%d", myRank) else "Ta position : hors du top 50"
	end

	for i, b in BOARDS do
		tabButtons[b.Id] = Kit.button(tabsRow, b.Label, { Size = UDim2.fromOffset(160, 34), TextSize = 13, LayoutOrder = i }, function()
			current = b.Id
			render()
		end)
	end

	State.LeaderboardChanged:Connect(function()
		if container.Visible then
			render()
		end
	end)

	local page: PageTypes.Page = {
		Id = "Leaderboard",
		Title = "Classements",
		Icon = "♛",
		Root = root,
		onShow = function()
			render()
			task.spawn(function()
				local ok, data = Remote.call("GetLeaderboard", true)
				if ok and type(data) == "table" then
					State.setLeaderboard(data)
				end
			end)
		end,
	}
	return page
end

return LeaderboardPage
