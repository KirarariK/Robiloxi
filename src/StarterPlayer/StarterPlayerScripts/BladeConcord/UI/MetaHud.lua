--!strict
--[[
	Routeur méta — ouvre Formes / Forge / Quêtes / Classé / Factions / Codes.
	Raccourci M · modal first-time faction · une seule modale à la fois.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent:WaitForChild("Strings"))
local LobbyHud = require(script.Parent:WaitForChild("LobbyHud"))
local FormsScreen = require(script.Parent:WaitForChild("Screens"):WaitForChild("FormsScreen"))
local ForgeScreen = require(script.Parent:WaitForChild("Screens"):WaitForChild("ForgeScreen"))
local QuestsScreen = require(script.Parent:WaitForChild("Screens"):WaitForChild("QuestsScreen"))
local RankedScreen = require(script.Parent:WaitForChild("Screens"):WaitForChild("RankedScreen"))
local FactionsScreen = require(script.Parent:WaitForChild("Screens"):WaitForChild("FactionsScreen"))
local Util = Kit.Util
local Button = Kit.Button
local Modal = Kit.Modal
local Toast = Kit.Toast

local MetaHud = {}

local player = Players.LocalPlayer
local metaRemotes: Remotes.MetaRemotes
local profile: any = nil
local catalog: any = nil
local warScore: any = nil
local weekend: any = nil
local rankedInfo: any = nil
local gui: ScreenGui
local closeCurrent: (() -> ())? = nil
local factionPromptShown = false

local function toast(msg: string, col: Color3?)
	Toast.show(msg, col)
end

local function closeStack()
	if closeCurrent then
		local c = closeCurrent
		closeCurrent = nil
		c()
	end
end

local function openScreen(id: string)
	closeStack()
	if id == "Forms" then
		closeCurrent = FormsScreen.open(gui, {
			profile = profile,
			metaRemotes = metaRemotes,
			onToast = toast,
			onClose = function()
				closeCurrent = nil
			end,
		})
	elseif id == "Forge" then
		closeCurrent = ForgeScreen.open(gui, {
			profile = profile,
			catalog = catalog,
			metaRemotes = metaRemotes,
			onToast = toast,
			onClose = function()
				closeCurrent = nil
			end,
		})
	elseif id == "Quests" then
		closeCurrent = QuestsScreen.open(gui, {
			profile = profile,
			metaRemotes = metaRemotes,
			weekend = weekend,
			onToast = toast,
			onClose = function()
				closeCurrent = nil
			end,
		})
	elseif id == "Ranked" then
		closeCurrent = RankedScreen.open(gui, {
			profile = profile,
			metaRemotes = metaRemotes,
			ranked = rankedInfo,
			onClose = function()
				closeCurrent = nil
			end,
		})
	elseif id == "Factions" then
		closeCurrent = FactionsScreen.open(gui, {
			profile = profile,
			warScore = warScore,
			metaRemotes = metaRemotes,
			onToast = toast,
			onClose = function()
				closeCurrent = nil
			end,
		})
	elseif id == "Codes" then
		local m = Modal.open(gui, {
			title = Strings.Codes,
			subtitle = Strings.CodesSoon,
			size = UDim2.fromScale(0.4, 0.35),
			onClose = function()
				closeCurrent = nil
			end,
		})
		local box = Instance.new("TextBox")
		box.PlaceholderText = "CODE…"
		box.Text = ""
		box.Size = UDim2.new(1, -24, 0, 44)
		box.Position = UDim2.new(0, 12, 0, 20)
		box.BackgroundColor3 = Theme.Ink900
		box.BorderSizePixel = 0
		box.TextColor3 = Theme.Bone
		box.PlaceholderColor3 = Theme.Muted
		box.TextSize = 16
		Theme.applyFont(box, "Hud")
		box.Parent = m.content
		Util.corner(box, 8)
		Util.stroke(box, Theme.Gold, 1.2, 0.4)
		Button.create({
			parent = m.content,
			text = "Valider",
			style = "primary",
			size = UDim2.new(1, -24, 0, 44),
			position = UDim2.new(0, 12, 0, 80),
			onClick = function()
				toast(Strings.CodesSoon, Theme.Muted)
			end,
		})
		closeCurrent = m.close
	end
end

local function showFactionPrompt()
	if factionPromptShown then
		return
	end
	if profile and typeof(profile.faction) == "string" and profile.faction ~= "" then
		return
	end
	factionPromptShown = true
	closeCurrent = FactionsScreen.open(gui, {
		profile = profile,
		warScore = warScore,
		metaRemotes = metaRemotes,
		onToast = toast,
		onClose = function()
			closeCurrent = nil
		end,
	})
end

function MetaHud.start()
	metaRemotes = Remotes.getMeta()

	gui = Util.safeScreenGui("BladeConcordMeta", 28, Enum.ScreenInsets.CoreUISafeInsets)
	Toast.bind(gui)

	-- Petite pastille MÉTA (fallback PC)
	local toggle = Button.create({
		parent = gui,
		text = "MÉTA  [M]",
		style = "secondary",
		size = UDim2.fromOffset(120, 40),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -16, 1, -16),
		textSize = 13,
		onClick = function()
			if closeCurrent then
				closeStack()
			else
				openScreen("Forms")
			end
		end,
	})
	toggle.Name = "ToggleMeta"

	LobbyHud.setMetaOpener(openScreen)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			if closeCurrent then
				closeStack()
			else
				openScreen("Forms")
			end
		end
	end)

	metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
		end
		if payload.catalog then
			catalog = payload.catalog
		end
		if typeof(payload.warScore) == "table" then
			warScore = payload.warScore
		end
		if typeof(payload.weekend) == "table" then
			weekend = payload.weekend
		end
		if typeof(payload.ranked) == "table" then
			rankedInfo = payload.ranked
		end
		if payload.kind == "GachaResult" then
			local data = if typeof(payload.data) == "table" then payload.data else payload
			if data.ok == false then
				toast("Tirage : " .. tostring(data.error or "échec"), Theme.Danger)
			end
		end
		if payload.kind == "Faction" and payload.ok == true then
			factionPromptShown = true
		end
		if profile and (profile.faction == nil or profile.faction == "") then
			task.defer(showFactionPrompt)
		end
	end)
end

return MetaHud
