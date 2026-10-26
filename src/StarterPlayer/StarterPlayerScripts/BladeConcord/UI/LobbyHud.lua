--!strict
--[[
	Lobby HUD — rails latéraux uniquement (Classe / Boutique / Reroll).
	Monnaies HG. Matchmaking = slots monde (pas de chrome central dense).
	Invisible hors phase Lobby.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Strings = require(script.Parent:WaitForChild("Strings"))
local Util = Kit.Util
local CurrencyPill = Kit.CurrencyPill
local Rail = Kit.Rail
local Toast = Kit.Toast

local LobbyHud = {}

local gui: ScreenGui
local root: Frame
local creditsPill: CurrencyPill.Handle
local shardsPill: CurrencyPill.Handle
local leftRail: Frame
local rightRail: Frame
local visible = true
local profile: any = nil
local openMeta: ((string) -> ())? = nil
local onLobbyVisibility: ((boolean) -> ())? = nil

local function refreshProfile()
	if not profile then
		creditsPill:setAmount(0)
		shardsPill:setAmount(0)
		return
	end
	creditsPill:setAmount(profile.credits or 0, true)
	shardsPill:setAmount(profile.shards or 0, true)
end

local function setVisible(v: boolean)
	visible = v
	root.Visible = v
	if onLobbyVisibility then
		onLobbyVisibility(v)
	end
end

function LobbyHud.setMetaOpener(fn: (string) -> ())
	openMeta = fn
end

function LobbyHud.setVisibilityListener(fn: (boolean) -> ())
	onLobbyVisibility = fn
	fn(visible)
end

function LobbyHud.isVisible(): boolean
	return visible
end

function LobbyHud.start()
	local remotes = Remotes.get()
	local metaRemotes = Remotes.getMeta()

	gui = Util.safeScreenGui("BladeConcordLobby", 22, Enum.ScreenInsets.CoreUISafeInsets)
	root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	Toast.bind(root)

	-- Monnaies haut-gauche (chip ref)
	local currencyCol = Instance.new("Frame")
	currencyCol.Name = "Currencies"
	currencyCol.BackgroundTransparency = 1
	currencyCol.Position = UDim2.new(0, 12, 0, 8)
	currencyCol.Size = UDim2.fromOffset(168, 74)
	currencyCol.Parent = root
	Util.list(currencyCol, Enum.FillDirection.Vertical, 6)

	creditsPill = CurrencyPill.create(currencyCol, {
		kind = "credits",
		amount = 0,
		layoutOrder = 1,
		onPlus = function()
			if openMeta then
				openMeta("Forge")
			end
		end,
	})
	shardsPill = CurrencyPill.create(currencyCol, {
		kind = "shards",
		amount = 0,
		layoutOrder = 2,
		onPlus = function()
			if openMeta then
				openMeta("Forge")
			end
		end,
	})

	local function open(id: string)
		if openMeta then
			openMeta(id)
		end
	end

	-- Rail gauche : Classe + Boutique
	leftRail = Rail.create(root, {
		side = "left",
		name = "LeftMetaRail",
		items = {
			{
				id = "Classe",
				label = Strings.Classe,
				icon = "Forms",
				accent = Theme.Arcane,
				onClick = function()
					open("Forms")
				end,
			},
			{
				id = "Boutique",
				label = Strings.Shop,
				icon = "Shop",
				accent = Theme.Gold,
				onClick = function()
					open("Forge")
				end,
			},
		},
	})

	-- Rail droit : Reroll (gacha formes)
	rightRail = Rail.create(root, {
		side = "right",
		name = "RightMetaRail",
		items = {
			{
				id = "Reroll",
				label = Strings.Reroll,
				icon = "Reroll",
				accent = Theme.Focus,
				onClick = function()
					open("Gacha")
				end,
			},
		},
	})

	-- Entrée douce rails
	root.Visible = true
	for _, rail in { leftRail, rightRail } do
		rail.BackgroundTransparency = 1
	end

	metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
			refreshProfile()
		end
		if payload.kind == "QuestClaim" and payload.data and payload.data.ok then
			Toast.show("Quête terminée — +" .. tostring(payload.data.credits or 0) .. " crédits", Theme.Success)
		end
	end)

	remotes.MatchState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local phase = tostring(payload.phase)
		-- Boutons méta = lobby only
		setVisible(phase == "Lobby")
	end)
end

return LobbyHud
