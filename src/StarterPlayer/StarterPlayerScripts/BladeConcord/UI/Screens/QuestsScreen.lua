--!strict
--[[
	Écran Quêtes — quotidiennes / progression / RÉCUPÉRER.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Util = Kit.Util
local Button = Kit.Button
local Modal = Kit.Modal
local Bar = Kit.Bar

local QuestsScreen = {}

local function defFor(id: string)
	for _, d in QuestConfig.DailyQuests do
		if d.id == id then
			return d
		end
	end
	return nil
end

function QuestsScreen.open(
	parent: Instance,
	ctx: {
		profile: any,
		metaRemotes: any,
		weekend: any?,
		onClose: (() -> ())?,
		onToast: ((string, Color3?) -> ())?,
	}
): () -> ()
	local profile = ctx.profile
	local modal = Modal.open(parent, {
		title = Strings.Quests,
		subtitle = Strings.Daily,
		size = UDim2.fromScale(0.7, 0.72),
		onClose = ctx.onClose,
	})

	local function rebuild()
		local content = modal.content
		content:ClearAllChildren()

		local tabs = Instance.new("Frame")
		tabs.BackgroundTransparency = 1
		tabs.Size = UDim2.new(1, 0, 0, 40)
		tabs.Parent = content
		Util.list(tabs, Enum.FillDirection.Horizontal, 8)
		for i, name in { Strings.Daily, Strings.Weekly, Strings.LoginStreak } do
			Button.create({
				parent = tabs,
				text = name,
				style = if i == 1 then "primary" else "ghost",
				size = UDim2.fromOffset(160, 36),
				layoutOrder = i,
				textSize = 13,
				onClick = function()
					if i ~= 1 and ctx.onToast then
						ctx.onToast("Bientôt disponible", Theme.Muted)
					end
				end,
			})
		end

		local grid = Instance.new("ScrollingFrame")
		grid.Position = UDim2.new(0, 0, 0, 48)
		grid.Size = UDim2.new(1, 0, 1, -56)
		grid.BackgroundTransparency = 1
		grid.ScrollBarThickness = 3
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.CanvasSize = UDim2.new(0, 0, 0, 0)
		grid.Parent = content
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.32, 0, 0, 160)
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.Parent = grid

		local quests = (profile and profile.dailyQuests) or {}
		for i, q in quests do
			local def = defFor(tostring(q.id))
			local target = def and def.target or 1
			local progress = q.progress or 0
			local claimed = q.claimed == true
			local ready = (not claimed) and progress >= target

			local card = Util.glassPanel(grid, "Q" .. i)
			card.LayoutOrder = i

			local title = Instance.new("TextLabel")
			title.BackgroundTransparency = 1
			title.Position = UDim2.fromOffset(12, 10)
			title.Size = UDim2.new(1, -24, 0, 22)
			Theme.applyFont(title, "Hud")
			title.TextSize = 14
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = Theme.Bone
			title.Text = def and def.displayName or tostring(q.id)
			title.Parent = card

			local st = Instance.new("TextLabel")
			st.BackgroundTransparency = 1
			st.Position = UDim2.fromOffset(12, 34)
			st.Size = UDim2.new(1, -24, 0, 16)
			Theme.applyFont(st, "Body")
			st.TextSize = 12
			st.TextXAlignment = Enum.TextXAlignment.Left
			st.TextColor3 = if claimed then Theme.Success elseif ready then Theme.Gold else Theme.Muted
			st.Text = if claimed then Strings.Claimed elseif ready then Strings.Ready else Strings.InProgress
			st.Parent = card

			local bar = Bar.create(card, {
				size = UDim2.new(1, -24, 0, 12),
				position = UDim2.new(0, 12, 0, 60),
				color = Theme.Focus,
				gradientTo = Theme.Arcane,
				label = string.format("%d / %d", progress, target),
			})
			bar:set(progress / math.max(1, target), true)

			local reward = Instance.new("TextLabel")
			reward.BackgroundTransparency = 1
			reward.Position = UDim2.fromOffset(12, 84)
			reward.Size = UDim2.new(1, -24, 0, 16)
			Theme.applyFont(reward, "Body")
			reward.TextSize = 12
			reward.TextXAlignment = Enum.TextXAlignment.Left
			reward.TextColor3 = Theme.Gold
			reward.Text = "◎ +" .. tostring(def and def.rewardCredits or 0)
			reward.Parent = card

			local qid = q.id
			Button.create({
				parent = card,
				text = Strings.Claim,
				style = if ready then "primary" else "ghost",
				size = UDim2.new(1, -24, 0, 36),
				position = UDim2.new(0, 12, 1, -48),
				onClick = function()
					if not ready then
						return
					end
					ctx.metaRemotes.ClaimQuest:FireServer({ questId = qid })
				end,
			})
			if not ready then
				-- disable visually
			end
		end

		local timer = Instance.new("TextLabel")
		timer.BackgroundTransparency = 1
		timer.AnchorPoint = Vector2.new(0.5, 1)
		timer.Position = UDim2.new(0.5, 0, 1, -4)
		timer.Size = UDim2.new(1, 0, 0, 16)
		Theme.applyFont(timer, "Mono")
		timer.TextSize = 12
		timer.TextColor3 = Theme.Muted
		timer.Text = "Renouvellement à minuit UTC"
		timer.Parent = content
		if ctx.weekend and ctx.weekend.active then
			timer.Text = Strings.EventPrefix
				.. " "
				.. tostring(ctx.weekend.displayName or "Double Crédits")
				.. " ×"
				.. tostring(ctx.weekend.creditMultiplier or 2)
			timer.TextColor3 = Theme.Focus
		end
	end

	rebuild()
	local conn = ctx.metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
		end
		if payload.kind == "QuestClaim" and payload.data and payload.data.ok and ctx.onToast then
			ctx.onToast("Quête récupérée — +" .. tostring(payload.data.credits) .. " crédits", Theme.Success)
		end
		if modal.root.Parent then
			rebuild()
		end
	end)

	local prev = modal.close
	return function()
		conn:Disconnect()
		prev()
	end
end

return QuestsScreen
