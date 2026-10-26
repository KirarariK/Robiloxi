--!strict
--[[
	Écran Mode Classé — rang, Fair Kit, saison, CTA file.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Util = Kit.Util
local Button = Kit.Button
local Modal = Kit.Modal
local Bar = Kit.Bar

local RankedScreen = {}

function RankedScreen.open(
	parent: Instance,
	ctx: {
		profile: any,
		metaRemotes: any,
		ranked: any?,
		onClose: (() -> ())?,
		onQueue: (() -> ())?,
	}
): () -> ()
	local profile = ctx.profile
	local modal = Modal.open(parent, {
		title = Strings.Ranked,
		subtitle = Strings.FairKit .. " — " .. Strings.FairKitStats,
		size = UDim2.fromScale(0.55, 0.7),
		onClose = ctx.onClose,
	})
	local content = modal.content

	local mmr = (profile and profile.mmr) or RankedConfig.StartingMMR
	local rank = (profile and profile.rank) or RankedConfig.rankFromMmr(mmr)

	local emblem = Util.glassPanel(content, "Emblem")
	emblem.AnchorPoint = Vector2.new(0.5, 0)
	emblem.Position = UDim2.new(0.5, 0, 0.02, 0)
	emblem.Size = UDim2.fromOffset(120, 120)
	Util.gradient(emblem, ColorSequence.new(Theme.Arcane, Theme.Gold), 90)

	local rankLbl = Instance.new("TextLabel")
	rankLbl.BackgroundTransparency = 1
	rankLbl.Position = UDim2.new(0, 0, 0, 140)
	rankLbl.Size = UDim2.new(1, 0, 0, 36)
	Theme.applyFont(rankLbl, "Display")
	rankLbl.TextSize = 32
	rankLbl.TextColor3 = Theme.Gold
	rankLbl.Text = Theme.rankLabelFr(tostring(rank))
	rankLbl.Parent = content

	local mmrLbl = Instance.new("TextLabel")
	mmrLbl.BackgroundTransparency = 1
	mmrLbl.Position = UDim2.new(0, 0, 0, 178)
	mmrLbl.Size = UDim2.new(1, 0, 0, 20)
	Theme.applyFont(mmrLbl, "Body")
	mmrLbl.TextSize = 14
	mmrLbl.TextColor3 = Theme.Muted
	mmrLbl.Text = string.format("%s · MMR %d", Strings.PC, mmr)
	mmrLbl.Parent = content

	local fair = Util.glassPanel(content, "Fair")
	fair.Position = UDim2.new(0.1, 0, 0, 210)
	fair.Size = UDim2.new(0.8, 0, 0, 56)
	local fairT = Instance.new("TextLabel")
	fairT.BackgroundTransparency = 1
	fairT.Size = UDim2.fromScale(1, 1)
	Theme.applyFont(fairT, "Hud")
	fairT.TextSize = 14
	fairT.TextColor3 = Theme.Success
	fairT.Text = (ctx.ranked and ctx.ranked.fairKitBadge or RankedConfig.FairKitBadge) .. "\n" .. Strings.FairKitStats
	fairT.Parent = fair

	local season = Instance.new("TextLabel")
	season.BackgroundTransparency = 1
	season.Position = UDim2.new(0, 0, 0, 280)
	season.Size = UDim2.new(1, 0, 0, 20)
	Theme.applyFont(season, "Body")
	season.TextSize = 13
	season.TextColor3 = Theme.Muted
	season.Text = Strings.Season .. " 1 — " .. tostring(RankedConfig.SeasonWeeks) .. " semaines"
	season.Parent = content

	-- Fake PC bar within rank band
	local bar = Bar.create(content, {
		size = UDim2.new(0.7, 0, 0, 16),
		position = UDim2.new(0.15, 0, 0, 310),
		color = Theme.Arcane,
		gradientTo = Theme.Gold,
		label = "Progression de rang",
	})
	bar:set(0.55, true)

	Button.create({
		parent = content,
		text = Strings.PlayRanked,
		style = "arcane",
		size = UDim2.new(0.7, 0, 0, 52),
		position = UDim2.new(0.15, 0, 1, -70),
		textSize = 18,
		onClick = function()
			ctx.metaRemotes.QueueMatch:FireServer({ mode = "Ranked" })
			if ctx.onQueue then
				ctx.onQueue()
			end
			modal.close()
		end,
	})

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.new(0, 0, 1, -24)
	hint.Size = UDim2.new(1, 0, 0, 18)
	Theme.applyFont(hint, "Body")
	hint.TextSize = 12
	hint.TextColor3 = Theme.Muted
	hint.Text = "Pénalité de fuite : −" .. tostring(RankedConfig.DodgePenaltyMMR) .. " MMR"
	hint.Parent = content

	return modal.close
end

return RankedScreen
