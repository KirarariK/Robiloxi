--!strict
--[[
	Routeur méta — Formes (Classe) / Forge (Boutique) / Gacha (Reroll).
	Raccourci M · modal first-time faction · chrome méta lobby-only.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local LobbyHud = require(script.Parent:WaitForChild("LobbyHud"))
local FormsScreen = require(script.Parent:WaitForChild("Screens"):WaitForChild("FormsScreen"))
local ForgeScreen = require(script.Parent:WaitForChild("Screens"):WaitForChild("ForgeScreen"))
local FactionsScreen = require(script.Parent:WaitForChild("Screens"):WaitForChild("FactionsScreen"))
local Util = Kit.Util
local Button = Kit.Button
local Toast = Kit.Toast

local MetaHud = {}

local metaRemotes: Remotes.MetaRemotes
local profile: any = nil
local catalog: any = nil
local warScore: any = nil
local gui: ScreenGui
local closeCurrent: (() -> ())? = nil
local factionPromptShown = false
local metaToggle: TextButton
local inLobby = true

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
	if not inLobby and id ~= "Factions" then
		-- Méta hors lobby : ignore (combat HUD only)
		return
	end
	closeStack()
	if id == "Forms" or id == "Gacha" or id == "Classe" or id == "Reroll" then
		-- FormsScreen = vitrine + tirages (Classe / Reroll ouvrissent le même écran)
		closeCurrent = FormsScreen.open(gui, {
			profile = profile,
			metaRemotes = metaRemotes,
			onToast = toast,
			onClose = function()
				closeCurrent = nil
			end,
		})
	elseif id == "Forge" or id == "Shop" or id == "Boutique" then
		closeCurrent = ForgeScreen.open(gui, {
			profile = profile,
			catalog = catalog,
			metaRemotes = metaRemotes,
			onToast = toast,
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
	end
end

local function showFactionPrompt()
	if factionPromptShown then
		return
	end
	if profile and typeof(profile.faction) == "string" and profile.faction ~= "" then
		return
	end
	if not inLobby then
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

local function setLobbyChrome(lobby: boolean)
	inLobby = lobby
	if metaToggle then
		metaToggle.Visible = lobby
	end
	if not lobby then
		closeStack()
	end
end

function MetaHud.start()
	metaRemotes = Remotes.getMeta()
	local remotes = Remotes.get()

	gui = Util.safeScreenGui("BladeConcordMeta", 28, Enum.ScreenInsets.CoreUISafeInsets)
	Toast.bind(gui)

	-- Pastille MÉTA fallback PC (lobby only)
	metaToggle = Button.create({
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
	metaToggle.Name = "ToggleMeta"

	LobbyHud.setMetaOpener(openScreen)
	LobbyHud.setVisibilityListener(setLobbyChrome)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			if not inLobby then
				return
			end
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

	-- Filet MatchState : ferme écrans méta dès sortie lobby
	remotes.MatchState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local lobby = tostring(payload.phase) == "Lobby"
		setLobbyChrome(lobby)
	end)
end

return MetaHud
