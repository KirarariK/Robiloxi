--!strict
--[[
	Écran Factions — choix Aube / Crépuscule + Score de Guerre.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent.Parent:WaitForChild("Strings"))
local Util = Kit.Util
local Button = Kit.Button
local Modal = Kit.Modal

local FactionsScreen = {}

function FactionsScreen.open(
	parent: Instance,
	ctx: {
		profile: any,
		warScore: any?,
		metaRemotes: any,
		onClose: (() -> ())?,
		onToast: ((string, Color3?) -> ())?,
	}
): () -> ()
	local profile = ctx.profile
	local war = ctx.warScore or { Dawn = 0, Dusk = 0 }
	local hasFaction = profile and typeof(profile.faction) == "string" and profile.faction ~= ""

	local modal = Modal.open(parent, {
		title = Strings.Factions,
		subtitle = if hasFaction then Strings.WarScore else Strings.FactionOnce,
		size = UDim2.fromScale(0.72, 0.7),
		onClose = ctx.onClose,
	})
	local content = modal.content

	local function panel(side: "Dawn" | "Dusk", xScale: number)
		local isDawn = side == "Dawn"
		local f = Util.glassPanel(content, side)
		f.Position = UDim2.new(xScale, 0, 0.05, 0)
		f.Size = UDim2.new(0.46, 0, 0.72, 0)
		local accent = if isDawn then Theme.Dawn else Theme.Dusk
		local bg = if isDawn then Theme.DawnBg else Theme.DuskBg
		f.BackgroundColor3 = bg
		local st = f:FindFirstChild("OuterStroke") :: UIStroke?
		if st then
			st.Color = accent
		end

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.new(0, 16, 0, 20)
		title.Size = UDim2.new(1, -32, 0, 36)
		Theme.applyFont(title, "Display")
		title.TextSize = 26
		title.TextColor3 = accent
		title.Text = if isDawn then Strings.Dawn else Strings.Dusk
		title.Parent = f

		local motto = Instance.new("TextLabel")
		motto.BackgroundTransparency = 1
		motto.Position = UDim2.new(0, 16, 0, 64)
		motto.Size = UDim2.new(1, -32, 0, 48)
		Theme.applyFont(motto, "Body")
		motto.TextSize = 14
		motto.TextWrapped = true
		motto.TextXAlignment = Enum.TextXAlignment.Left
		motto.TextColor3 = Theme.Bone
		motto.Text = if isDawn
			then "L'ordre du premier rayon. Discipline et clarté."
			else "La voie de l'ombre portée. Instinct et flux."
		motto.Parent = f

		local score = Instance.new("TextLabel")
		score.BackgroundTransparency = 1
		score.Position = UDim2.new(0, 16, 0, 130)
		score.Size = UDim2.new(1, -32, 0, 24)
		Theme.applyFont(score, "Hud")
		score.TextSize = 16
		score.TextXAlignment = Enum.TextXAlignment.Left
		score.TextColor3 = Theme.Muted
		score.Text = Strings.WarScore .. " : " .. tostring(war[side] or 0)
		score.Parent = f

		if not hasFaction then
			Button.create({
				parent = f,
				text = if isDawn then Strings.JoinDawn else Strings.JoinDusk,
				style = if isDawn then "primary" else "arcane",
				size = UDim2.new(1, -32, 0, 48),
				position = UDim2.new(0, 16, 1, -64),
				onClick = function()
					ctx.metaRemotes.SelectFaction:FireServer({ factionId = side })
					if ctx.onToast then
						ctx.onToast("Faction choisie…", accent)
					end
				end,
			})
		elseif profile.faction == side then
			local you = Instance.new("TextLabel")
			you.BackgroundTransparency = 1
			you.Position = UDim2.new(0, 16, 1, -56)
			you.Size = UDim2.new(1, -32, 0, 28)
			Theme.applyFont(you, "Hud")
			you.TextSize = 16
			you.TextColor3 = Theme.Success
			you.Text = "Ta faction"
			you.Parent = f
		end
	end

	panel("Dawn", 0.02)
	panel("Dusk", 0.52)

	-- Tug of war
	local total = math.max(1, (war.Dawn or 0) + (war.Dusk or 0))
	local dawnFrac = (war.Dawn or 0) / total
	local tug = Instance.new("Frame")
	tug.Position = UDim2.new(0.1, 0, 0.82, 0)
	tug.Size = UDim2.new(0.8, 0, 0, 18)
	tug.BackgroundColor3 = Theme.Dusk
	tug.BorderSizePixel = 0
	tug.Parent = content
	Util.corner(tug, 9)
	local dawnFill = Instance.new("Frame")
	dawnFill.Size = UDim2.fromScale(0, 1)
	dawnFill.BackgroundColor3 = Theme.Dawn
	dawnFill.BorderSizePixel = 0
	dawnFill.Parent = tug
	Util.corner(dawnFill, 9)
	TweenService:Create(dawnFill, TweenInfo.new(0.6, Enum.EasingStyle.Cubic), {
		Size = UDim2.fromScale(dawnFrac, 1),
	}):Play()

	local contrib = Instance.new("TextLabel")
	contrib.BackgroundTransparency = 1
	contrib.Position = UDim2.new(0, 0, 0.9, 0)
	contrib.Size = UDim2.new(1, 0, 0, 20)
	Theme.applyFont(contrib, "Body")
	contrib.TextSize = 13
	contrib.TextColor3 = Theme.Muted
	contrib.Text = Strings.YourContribution .. " : " .. tostring((profile and profile.warScoreContribution) or 0)
	contrib.Parent = content

	local conn = ctx.metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
			hasFaction = typeof(profile.faction) == "string" and profile.faction ~= ""
		end
		if typeof(payload.warScore) == "table" then
			war = payload.warScore
		end
		if payload.kind == "Faction" and payload.ok and ctx.onToast then
			ctx.onToast("Bienvenue dans ta faction", Theme.Success)
			modal.close()
		end
	end)

	-- silence unused
	local _ = QuestConfig

	local prev = modal.close
	return function()
		conn:Disconnect()
		prev()
	end
end

return FactionsScreen
