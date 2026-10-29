--!strict
-- Applique une défaite + pénalité d'abandon à un joueur qui a quitté le serveur pendant un duel.
-- Écrit directement le profil (store `EtherBlades_Profiles_v1`, clé `u_<userId>`, enregistrement
-- { Profile, LockServer, LockTime }) via UpdateAsync, **en respectant le verrou de session** :
-- tant qu'une session est ouverte (y compris la sauvegarde de sortie de ce serveur), on réessaie plus tard.
-- Si le joueur revient sur ce serveur avant, la pénalité est appliquée à sa session dès le chargement.
local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME = "EtherBlades_Profiles_v1"
local LOCK_TIMEOUT = 600 -- identique à DataService : un verrou plus vieux est abandonné
local RETRY_PERIOD = 20
local MAX_TRIES = 45 -- ~15 min, au-delà du délai d'expiration d'un verrou

type Pending = {
	UserId: number,
	Apply: (profile: any) -> (),
	Tries: number,
	InFlight: boolean,
	Done: boolean,
}

local OfflinePenalty = {}

local pending: { [number]: { Pending } } = {}
local store: DataStore? = nil
local memoryMode = false

function OfflinePenalty.setMemoryMode(on: boolean)
	memoryMode = on
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = ds
	end
	return store
end

local function remove(entry: Pending)
	local list = pending[entry.UserId]
	if not list then
		return
	end
	local i = table.find(list, entry)
	if i then
		table.remove(list, i)
	end
	if #list == 0 then
		pending[entry.UserId] = nil
	end
end

-- Une tentative ; renvoie true si c'est terminé (appliqué ou abandon définitif).
local function attempt(entry: Pending): boolean
	if entry.Done then
		return true
	end
	local ds = getStore()
	if memoryMode or not ds then
		return false -- en Studio : on attend que le joueur revienne sur ce serveur
	end
	entry.InFlight = true
	local applied = false
	local locked = false
	local dataStore = ds :: DataStore
	local ok, err = pcall(function()
		dataStore:UpdateAsync("u_" .. entry.UserId, function(old: any): any
			applied = false
			locked = false
			if type(old) ~= "table" or type(old.Profile) ~= "table" then
				return nil -- aucun profil : rien à pénaliser
			end
			if old.LockServer ~= nil and os.time() - (tonumber(old.LockTime) or 0) < LOCK_TIMEOUT then
				locked = true
				return nil -- session encore ouverte (ici ou ailleurs) : ne rien écrire
			end
			entry.Apply(old.Profile)
			applied = true
			return old
		end)
	end)
	entry.InFlight = false
	if not ok then
		warn(string.format("[EtherBlades] pénalité hors ligne %d : %s", entry.UserId, tostring(err)))
		return false
	end
	if applied then
		entry.Done = true
		return true
	end
	return not locked -- pas de profil : abandon ; verrou : on réessaie
end

local function loop(entry: Pending)
	task.wait(4) -- laisse DataService terminer la sauvegarde de sortie et libérer le verrou
	while not entry.Done and entry.Tries < MAX_TRIES do
		entry.Tries += 1
		if attempt(entry) then
			break
		end
		task.wait(RETRY_PERIOD)
	end
	if not entry.Done and entry.Tries >= MAX_TRIES then
		warn(string.format("[EtherBlades] pénalité d'abandon de %d non appliquée (session toujours ouverte)", entry.UserId))
	end
	remove(entry)
end

-- Programme l'application de `apply` sur le profil hors ligne de `userId`.
function OfflinePenalty.schedule(userId: number, apply: (profile: any) -> ())
	local entry: Pending = { UserId = userId, Apply = apply, Tries = 0, InFlight = false, Done = false }
	local list = pending[userId]
	if not list then
		list = {}
		pending[userId] = list
	end
	table.insert(list :: { Pending }, entry)
	task.spawn(loop, entry)
end

-- À appeler au chargement d'un profil sur ce serveur : applique les pénalités encore en attente à la session.
function OfflinePenalty.consume(userId: number, applyToSession: ((profile: any) -> ()) -> ())
	local list = pending[userId]
	if not list then
		return
	end
	for _, entry in table.clone(list) do
		while entry.InFlight do
			task.wait(0.2)
		end
		if not entry.Done then
			entry.Done = true
			applyToSession(entry.Apply)
		end
		remove(entry)
	end
end

-- Dernière chance à la fermeture du serveur.
function OfflinePenalty.flush()
	for _, list in pending do
		for _, entry in list do
			if not entry.Done and not entry.InFlight then
				task.spawn(attempt, entry)
			end
		end
	end
end

return OfflinePenalty
