--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local RebirthsConfig = require(game.ReplicatedStorage.StealASnake.Config.RebirthsConfig)

export type VivariumSnake = {
	SpeciesId: string,
	Mutation: string,
	Weight: number,
	Income: number,
}

export type PlayerData = {
	Cash: number,
	Speed: number,
	Rebirths: number,
	TreadmillLevel: number,
	PendingCash: number,
	Vivariums: { [string]: VivariumSnake? },
	PlotIndex: number?,
	TutorialStep: number, -- 1..4 = étape du tutoriel, 5 = terminé
	MaxBiome: number, -- plus haut biome débloqué (portes par joueur)
	-- Monétisation / rétention
	Boosts: { [string]: number }, -- clé → fin (unix)
	DailyLast: number, -- n° du dernier jour réclamé (os.time() // 86400)
	DailyStreak: number,
	StarterBought: boolean,
	StarterOfferEnds: number, -- fin de l'offre limitée (unix), 0 = pas encore fixée
	Receipts: { string }, -- PurchaseIds déjà accordés (idempotence ProcessReceipt)
	Codes: { [string]: boolean },
	Index: { [string]: boolean }, -- espèces déjà possédées (livre de collection)
	-- non sauvegardés (recalculés à chaque session)
	Passes: { [string]: boolean },
	Premium: boolean,
	GiftsClaimed: { [number]: boolean },
	SessionStart: number,
}

local DataManager = {}
local store: any = nil
local cache: { [number]: PlayerData } = {}
local dirty: { [number]: boolean } = {}
-- Joueurs dont le chargement DataStore a échoué : on ne sauvegarde JAMAIS par-dessus leur vraie sauvegarde.
local loadFailed: { [number]: boolean } = {}

local function getStore(): any
	if store ~= nil then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("StealASnake_v1")
	end)
	if ok then
		store = result
	else
		store = false -- Studio unpublished / API off → memory only
	end
	return store
end

local function defaultData(): PlayerData
	return {
		Cash = 0,
		Speed = 0,
		Rebirths = 0,
		TreadmillLevel = 1,
		PendingCash = 0,
		Vivariums = {},
		PlotIndex = nil,
		TutorialStep = 1,
		MaxBiome = 1,
		Boosts = {},
		DailyLast = 0,
		DailyStreak = 0,
		StarterBought = false,
		StarterOfferEnds = 0,
		Receipts = {},
		Codes = {},
		Index = {},
		Passes = {},
		Premium = false,
		GiftsClaimed = {},
		SessionStart = os.time(),
	}
end

function DataManager.get(player: Player): PlayerData
	local d = cache[player.UserId]
	if not d then
		d = defaultData()
		cache[player.UserId] = d
	end
	return d
end

function DataManager.markDirty(player: Player)
	dirty[player.UserId] = true
end

function DataManager.rebirthMult(player: Player): number
	local d = DataManager.get(player)
	return 1 + d.Rebirths * RebirthsConfig.IncomeMultPerRebirth
end

function DataManager.push(player: Player)
	local d = DataManager.get(player)
	-- attributs répliqués : lus par le tutoriel (guide) et le rendu des portes côté client
	player:SetAttribute("TutorialStep", d.TutorialStep)
	player:SetAttribute("MaxBiome", d.MaxBiome)
	Network.event("DataUpdate"):FireClient(player, d)
end

local function load(player: Player)
	local ds = getStore()
	local ok, data = false, nil
	if ds then
		for attempt = 1, 3 do
			ok, data = pcall(function()
				return ds:GetAsync("p_" .. player.UserId)
			end)
			if ok then
				break
			end
			task.wait(attempt * 1.5)
		end
		if not ok then
			loadFailed[player.UserId] = true
			warn("[StealASnake] DataStore load failed for " .. player.UserId .. " — progression non sauvegardée cette session")
			Network.event("Alert"):FireClient(player, "Sauvegarde indisponible : ta progression de cette session ne sera pas enregistrée.")
		end
	end
	local d = defaultData()
	if ok and typeof(data) == "table" then
		d.Cash = tonumber(data.Cash) or 0
		d.Speed = tonumber(data.Speed) or 0
		d.Rebirths = tonumber(data.Rebirths) or 0
		d.TreadmillLevel = tonumber(data.TreadmillLevel) or 1
		d.PendingCash = tonumber(data.PendingCash) or 0
		d.Vivariums = if typeof(data.Vivariums) == "table" then data.Vivariums else {}
		-- anciens joueurs (sauvegarde sans tutoriel) : déjà en jeu → tutoriel terminé
		local veteran = d.Cash > 0 or d.Speed > 0 or d.Rebirths > 0 or next(d.Vivariums) ~= nil
		d.TutorialStep = tonumber(data.TutorialStep) or (if veteran then 5 else 1)
		d.MaxBiome = tonumber(data.MaxBiome) or 1
		d.Boosts = if typeof(data.Boosts) == "table" then data.Boosts else {}
		d.DailyLast = tonumber(data.DailyLast) or 0
		d.DailyStreak = tonumber(data.DailyStreak) or 0
		d.StarterBought = data.StarterBought == true
		d.StarterOfferEnds = tonumber(data.StarterOfferEnds) or 0
		d.Receipts = if typeof(data.Receipts) == "table" then data.Receipts else {}
		d.Codes = if typeof(data.Codes) == "table" then data.Codes else {}
		d.Index = if typeof(data.Index) == "table" then data.Index else {}
	end
	-- index rétroactif : tout serpent déjà en vivarium compte comme découvert
	for _, s in d.Vivariums do
		if s and s.SpeciesId then
			d.Index[s.SpeciesId] = true
		end
	end
	d.Premium = player.MembershipType == Enum.MembershipType.Premium
	cache[player.UserId] = d
	DataManager.push(player)
end

local function save(player: Player): boolean
	local d = cache[player.UserId]
	if not d or loadFailed[player.UserId] then
		return false
	end
	local payload = {
		Cash = d.Cash,
		Speed = d.Speed,
		Rebirths = d.Rebirths,
		TreadmillLevel = d.TreadmillLevel,
		PendingCash = d.PendingCash,
		Vivariums = d.Vivariums,
		TutorialStep = d.TutorialStep,
		MaxBiome = d.MaxBiome,
		Boosts = d.Boosts,
		DailyLast = d.DailyLast,
		DailyStreak = d.DailyStreak,
		StarterBought = d.StarterBought,
		StarterOfferEnds = d.StarterOfferEnds,
		Receipts = d.Receipts,
		Codes = d.Codes,
		Index = d.Index,
	}
	local ds = getStore()
	local saved = not ds -- sans DataStore (Studio non publié) : rien à écrire
	if ds then
		for attempt = 1, 3 do
			local ok = pcall(function()
				ds:UpdateAsync("p_" .. player.UserId, function()
					return payload
				end)
			end)
			if ok then
				saved = true
				break
			end
			task.wait(attempt)
		end
	end
	dirty[player.UserId] = false
	return saved
end

-- Sauvegarde immédiate (achats Robux) : vrai si la donnée est en sécurité.
function DataManager.saveNow(player: Player): boolean
	return save(player)
end

function DataManager.isLoaded(player: Player): boolean
	return cache[player.UserId] ~= nil
end

function DataManager.start()
	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		cache[player.UserId] = nil
		dirty[player.UserId] = nil
		loadFailed[player.UserId] = nil
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	task.spawn(function()
		while true do
			task.wait(45)
			for _, p in Players:GetPlayers() do
				if dirty[p.UserId] then
					save(p)
				end
			end
		end
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			save(p)
		end
	end)
	Network.func("GetData").OnServerInvoke = function(player)
		return DataManager.get(player)
	end
end

return DataManager
