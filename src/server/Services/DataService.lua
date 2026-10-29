--!strict
-- Sauvegarde des profils : verrou de session, tentatives avec attente croissante, sauvegarde
-- automatique, sauvegarde à la fermeture, migration de schéma. En Studio sans accès aux API,
-- bascule sur un stockage en mémoire (le jeu reste jouable, rien n'est écrit).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local FormData = require(Shared.Config.FormData)
local WeaponData = require(Shared.Config.WeaponData)
local SaberColors = require(Shared.Config.SaberColors)
local TitleData = require(Shared.Config.TitleData)
local EmoteData = require(Shared.Config.EmoteData)
local RankData = require(Shared.Config.RankData)

type Profile = Types.Profile

local STORE_NAME = "EtherBlades_Profiles_v1"
local SCHEMA_VERSION = 1
local AUTOSAVE_PERIOD = 120
local LOCK_TIMEOUT = 600 -- s : un verrou plus vieux est considéré comme abandonné (serveur planté)
local MAX_ATTEMPTS = 5

local SERVER_ID = if game.JobId ~= "" then game.JobId else ("studio-" .. HttpService:GenerateGUID(false))

type Record = {
	Profile: Profile,
	LockServer: string?,
	LockTime: number?,
}

type Session = {
	Profile: Profile,
	Dirty: boolean,
	Released: boolean,
}

local DataService = {}

local sessions: { [Player]: Session } = {}
local loadedEvent = Instance.new("BindableEvent")
DataService.ProfileLoaded = loadedEvent.Event -- (player, profile)

-- Stockage : DataStore réel, ou mémoire en Studio sans accès API.
local store: DataStore? = nil
local memory: { [string]: Record } = {}
local useMemory = false

do
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = ds
		if RunService:IsStudio() then
			local probeOk = pcall(function()
				ds:GetAsync("__probe")
			end)
			useMemory = not probeOk
		end
	else
		useMemory = true
	end
	if useMemory then
		warn("[EtherBlades] DataStore indisponible (Studio sans accès API) : profils en mémoire, rien n'est sauvegardé.")
	end
end

local function defaultProfile(): Profile
	local now = os.time()
	local colors: { [string]: boolean } = {}
	for _, id in SaberColors.Starter do
		colors[id] = true
	end
	local mastery: { [Types.FormId]: number } = {}
	for _, f in FormData.List do
		mastery[f.Id] = 0
	end
	local emotes: { string } = {}
	for _, e in EmoteData.Default do
		table.insert(emotes, e)
	end
	return {
		Version = SCHEMA_VERSION,
		Elo = RankData.StartElo,
		PeakElo = RankData.StartElo,
		Wins = 0,
		Losses = 0,
		WinStreak = 0,
		BestStreak = 0,
		RankedPlayed = 0,
		Rerolls = 0,
		Crystals = 300,
		EquippedForm = FormData.Default,
		OwnedForms = { [FormData.Default] = true },
		FormMastery = mastery,
		EquippedWeapon = WeaponData.Default,
		EquippedColor = SaberColors.Default,
		OwnedColors = colors,
		EquippedTitle = TitleData.Default,
		OwnedTitles = { [TitleData.Default] = true },
		EquippedEmotes = emotes,
		LeavePenaltyUntil = 0,
		FirstJoin = now,
		LastJoin = now,
	}
end

-- Complète les champs manquants et corrige les valeurs devenues invalides (données d'une ancienne version).
local function reconcile(raw: any): Profile
	local base = defaultProfile()
	if type(raw) ~= "table" then
		return base
	end
	local p = raw :: any
	for k, v in base :: any do
		if p[k] == nil or typeof(p[k]) ~= typeof(v) then
			p[k] = v
		end
	end
	for _, f in FormData.List do
		if type(p.FormMastery[f.Id]) ~= "number" then
			p.FormMastery[f.Id] = 0
		end
	end
	if not FormData.isValid(p.EquippedForm) or not p.OwnedForms[p.EquippedForm] then
		p.EquippedForm = FormData.Default
		p.OwnedForms[FormData.Default] = true
	end
	if not WeaponData.isValid(p.EquippedWeapon) then
		p.EquippedWeapon = WeaponData.Default
	end
	if not SaberColors.isValid(p.EquippedColor) or not p.OwnedColors[p.EquippedColor] then
		p.EquippedColor = SaberColors.Default
		p.OwnedColors[SaberColors.Default] = true
	end
	if TitleData.get(p.EquippedTitle) == nil or not p.OwnedTitles[p.EquippedTitle] then
		p.EquippedTitle = TitleData.Default
		p.OwnedTitles[TitleData.Default] = true
	end
	local emotes = {}
	for _, id in p.EquippedEmotes do
		if type(id) == "string" and EmoteData.get(id) and #emotes < EmoteData.Slots then
			table.insert(emotes, id)
		end
	end
	p.EquippedEmotes = emotes
	p.Version = SCHEMA_VERSION
	return p :: Profile
end

local function key(userId: number): string
	return "u_" .. userId
end

-- UpdateAsync avec nouvelles tentatives et attente croissante.
local function update(userId: number, transform: (Record?) -> Record?): (boolean, Record?)
	if useMemory then
		local res = transform(memory[key(userId)])
		if res then
			memory[key(userId)] = res
		end
		return true, res
	end
	local ds = store :: DataStore
	for attempt = 1, MAX_ATTEMPTS do
		local result: Record? = nil
		local ok, err = pcall(function()
			ds:UpdateAsync(key(userId), function(old: any)
				result = transform(old)
				return result
			end)
		end)
		if ok then
			return true, result
		end
		warn(string.format("[EtherBlades] DataStore %d (essai %d/%d) : %s", userId, attempt, MAX_ATTEMPTS, tostring(err)))
		task.wait(math.min(2 ^ attempt, 16))
	end
	return false, nil
end

local function publicView(p: Profile): { [string]: any }
	-- Copie superficielle : le client ne reçoit jamais la table serveur elle-même.
	local view = table.clone(p :: any)
	view.OwnedForms = table.clone(p.OwnedForms)
	view.OwnedColors = table.clone(p.OwnedColors)
	view.OwnedTitles = table.clone(p.OwnedTitles)
	view.FormMastery = table.clone(p.FormMastery)
	view.EquippedEmotes = table.clone(p.EquippedEmotes)
	return view
end

local function push(player: Player)
	local s = sessions[player]
	if s and player.Parent then
		Net.event("ProfileUpdated"):FireClient(player, publicView(s.Profile))
	end
end

local function load(player: Player)
	local userId = player.UserId
	local profile: Profile? = nil
	local lockedElsewhere = false
	for _ = 1, 3 do
		lockedElsewhere = false
		local ok, rec = update(userId, function(old: Record?): Record?
			if old and old.LockServer and old.LockServer ~= SERVER_ID and old.LockTime and os.time() - old.LockTime < LOCK_TIMEOUT then
				lockedElsewhere = true
				return nil -- ne pas écrire : la session est encore tenue ailleurs
			end
			return {
				Profile = reconcile(old and old.Profile),
				LockServer = SERVER_ID,
				LockTime = os.time(),
			}
		end)
		if ok and rec and not lockedElsewhere then
			profile = rec.Profile
			break
		end
		if not ok then
			break
		end
		task.wait(6) -- l'autre serveur relâche généralement le verrou en quelques secondes
	end
	if not player.Parent then
		return
	end
	if not profile then
		player:Kick(if lockedElsewhere
			then "Ta session est encore ouverte sur un autre serveur. Réessaie dans un instant."
			else "Impossible de charger tes données. Réessaie dans un instant.")
		return
	end
	local p = profile :: Profile
	p.LastJoin = os.time()
	sessions[player] = { Profile = p, Dirty = true, Released = false }
	loadedEvent:Fire(player, p)
	push(player)
end

local function save(player: Player, release: boolean): boolean
	local s = sessions[player]
	if not s or s.Released then
		return true
	end
	if not s.Dirty and not release then
		return true
	end
	local snapshot = table.clone(s.Profile :: any)
	local ok = update(player.UserId, function(old: Record?): Record?
		if old and old.LockServer and old.LockServer ~= SERVER_ID then
			return nil -- un autre serveur a pris la main : ne pas écraser ses données
		end
		return {
			Profile = snapshot,
			LockServer = if release then nil else SERVER_ID,
			LockTime = if release then nil else os.time(),
		}
	end)
	if ok then
		s.Dirty = false
		if release then
			s.Released = true
		end
	end
	return ok
end

--------------------------------------------------------------------------------
-- API publique

function DataService.get(player: Player): Profile?
	local s = sessions[player]
	return if s then s.Profile else nil
end

-- Modifie le profil via `fn` puis le pousse au client. Retourne false si le profil n'est pas chargé.
function DataService.update(player: Player, fn: (Profile) -> ()): boolean
	local s = sessions[player]
	if not s then
		return false
	end
	fn(s.Profile)
	s.Dirty = true
	push(player)
	return true
end

function DataService.isMemoryMode(): boolean
	return useMemory
end

function DataService.init()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(load, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		save(p, true)
		sessions[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_PERIOD)
			for p in sessions do
				task.spawn(save, p, false)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for p in sessions do
			pending += 1
			task.spawn(function()
				save(p, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

DataService.publicView = publicView

return DataService
