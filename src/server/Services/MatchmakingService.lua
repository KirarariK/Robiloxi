--!strict
-- Matchmaking 1v1 : files Classé / Non-classé, défis directs, file inter-serveurs.
--  • Local : appariement sur ce serveur par Elo avec une fenêtre qui s'élargit avec l'attente.
--  • Inter-serveurs (jeu publié, hors Studio) : MemoryStore SortedMap `EB_Queue_<Mode>` (clé = Elo + UserId),
--    réclamation atomique par UpdateAsync, ReserveServer + TeleportAsync avec TeleportData { MatchId, Mode, Players }.
--    Le dossier du match (`EB_Matches`) fait foi : le TeleportData (modifiable par le client) n'est jamais cru seul.
--  • Serveur réservé : accueille les deux joueurs, lance le duel, les renvoie vers un serveur public à la fin.
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Guard)
local MatchService = require(script.Parent.MatchService)
local HubPrompts = require(script.Parent.Parent.Match.HubPrompts)

type Result = Guard.Result
type QueueMode = "Ranked" | "Casual"

type Entry = {
	Player: Player,
	Mode: QueueMode,
	Elo: number,
	Since: number, -- os.time() à l'entrée
	ServerSince: number, -- Workspace:GetServerTimeNow() à l'entrée (affichage client)
	Key: string,
	Busy: boolean, -- réclamation / téléportation en cours
	ClaimedSince: number?,
}

type Challenge = { Id: string, From: Player, To: Player, Expires: number }

local MatchmakingService = {}
MatchmakingService.Priority = 50

local TICK = 2
local ENTRY_TTL = 45 -- s : une entrée non rafraîchie disparaît (serveur planté)
local MATCH_TTL = 300
local CHALLENGE_TTL = 20
local RESERVED_WAIT = 60
local RETURN_DELAY = 9

local queue: { [Player]: Entry } = {}
local challenges: { [string]: Challenge } = {}
local lastChallenge: { [Player]: { [number]: number } } = {}

local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local crossServer = not RunService:IsStudio() and game.PlaceId ~= 0 and not isReserved

local maps: { [QueueMode]: MemoryStoreSortedMap } = {}
local matchMap: MemoryStoreSortedMap? = nil

local function notify(p: Player, text: string, kind: string?)
	if p.Parent then
		Net.event("Notify"):FireClient(p, { Text = text, Kind = kind or "Info" })
	end
end

local function pushQueue(p: Player, status: string?)
	local e = queue[p]
	if not p.Parent then
		return
	end
	if e then
		Net.event("QueueState"):FireClient(p, {
			InQueue = true,
			Mode = e.Mode,
			Since = e.ServerSince,
			Status = status or "Recherche d'un adversaire…",
		})
	else
		Net.event("QueueState"):FireClient(p, { InQueue = false, Status = status })
	end
end

-- Fenêtre d'Elo acceptée selon le temps d'attente.
local function window(mode: QueueMode, waited: number): number
	if mode == "Ranked" then
		return math.min(75 + 10 * waited, 1000)
	end
	if waited >= 20 then
		return math.huge
	end
	return 200 + 30 * waited
end

local function compatible(mode: QueueMode, eloA: number, waitA: number, eloB: number, waitB: number): boolean
	return math.abs(eloA - eloB) <= math.max(window(mode, waitA), window(mode, waitB))
end

local function keyFor(elo: number, userId: number): string
	return string.format("%06d_%d", math.clamp(math.floor(elo), 0, 999999), userId)
end

local function removeRemote(e: Entry)
	if not crossServer then
		return
	end
	local map = maps[e.Mode]
	task.spawn(function()
		pcall(function()
			map:RemoveAsync(e.Key)
		end)
	end)
end

local function leave(p: Player, status: string?)
	local e = queue[p]
	if not e then
		return
	end
	queue[p] = nil
	removeRemote(e)
	pushQueue(p, status)
end

local function join(p: Player, mode: QueueMode): Result
	if isReserved then
		return { Ok = false, Err = "Les files sont disponibles depuis le Hub public." }
	end
	if MatchService.isInMatch(p) then
		return { Ok = false, Err = "Tu es déjà en duel." }
	end
	local profile = DataService.get(p)
	if not profile then
		return { Ok = false, Err = "Profil en cours de chargement…" }
	end
	if mode == "Ranked" and profile.LeavePenaltyUntil > os.time() then
		return {
			Ok = false,
			Err = string.format("Tu as abandonné un duel : file classée bloquée encore %d s.", profile.LeavePenaltyUntil - os.time()),
		}
	end
	local cur = queue[p]
	if cur and cur.Mode == mode then
		return { Ok = true }
	end
	if cur then
		if cur.Busy then
			return { Ok = false, Err = "Adversaire en cours d'appariement…" }
		end
		leave(p)
	end
	queue[p] = {
		Player = p,
		Mode = mode,
		Elo = profile.Elo,
		Since = os.time(),
		ServerSince = Workspace:GetServerTimeNow(),
		Key = keyFor(profile.Elo, p.UserId),
		Busy = false,
		ClaimedSince = nil,
	}
	pushQueue(p)
	return { Ok = true }
end

local function startLocal(a: Player, b: Player, mode: string)
	leave(a, "Adversaire trouvé !")
	leave(b, "Adversaire trouvé !")
	-- les défis en attente impliquant ces joueurs sont annulés
	for id, c in challenges do
		if c.From == a or c.To == a or c.From == b or c.To == b then
			challenges[id] = nil
		end
	end
	local ok, err = MatchService.start(a, b, mode :: any)
	if not ok then
		notify(a, err or "Duel impossible.", "Error")
		notify(b, err or "Duel impossible.", "Error")
	end
end

--------------------------------------------------------------------------------
-- Appariement local

local function matchLocal()
	for _, mode in { "Ranked", "Casual" } :: { QueueMode } do
		local list: { Entry } = {}
		for _, e in queue do
			if e.Mode == mode and not e.Busy then
				table.insert(list, e)
			end
		end
		table.sort(list, function(x, y)
			return x.Since < y.Since
		end)
		local used: { [Entry]: boolean } = {}
		local now = os.time()
		for i, e in list do
			if not used[e] then
				local best: Entry? = nil
				local bestDiff = math.huge
				for j = i + 1, #list do
					local o = list[j]
					if not used[o] and compatible(mode, e.Elo, now - e.Since, o.Elo, now - o.Since) then
						local d = math.abs(e.Elo - o.Elo)
						if d < bestDiff then
							best, bestDiff = o, d
						end
					end
				end
				if best then
					local o = best :: Entry
					used[e] = true
					used[o] = true
					startLocal(e.Player, o.Player, mode)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Inter-serveurs (MemoryStore + TeleportService)

type RemoteValue = {
	UserId: number,
	Elo: number,
	Since: number,
	JobId: string,
	Claimed: string?,
	ClaimTime: number?,
}

local function teleportToMatch(p: Player, record: any)
	local e = queue[p]
	if e then
		queue[p] = nil
		removeRemote(e)
	end
	pushQueue(p, "Téléportation vers l'arène…")
	notify(p, "Adversaire trouvé ! Téléportation vers l'arène…", "Success")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = record.AccessCode
	options:SetTeleportData({ MatchId = record.MatchId, Mode = record.Mode, Players = record.Players })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { p }, options)
	end)
	if not ok then
		warn("[EtherBlades] téléportation vers le match : " .. tostring(err))
		notify(p, "Téléportation impossible, réessaie.", "Error")
		pushQueue(p)
	end
end

-- Réclamation atomique d'une entrée (la nôtre ou celle de l'adversaire).
local function claim(map: MemoryStoreSortedMap, key: string, matchId: string): boolean
	local ok, res = pcall(function()
		return map:UpdateAsync(key, function(old: any)
			if type(old) ~= "table" or old.Claimed ~= nil then
				return nil
			end
			old.Claimed = matchId
			old.ClaimTime = os.time()
			return old
		end, ENTRY_TTL)
	end)
	return ok and type(res) == "table" and (res :: any).Claimed == matchId
end

local function unclaim(map: MemoryStoreSortedMap, key: string, matchId: string)
	pcall(function()
		map:UpdateAsync(key, function(old: any)
			if type(old) ~= "table" or old.Claimed ~= matchId then
				return nil
			end
			old.Claimed = nil
			old.ClaimTime = nil
			return old
		end, ENTRY_TTL)
	end)
end

-- Rafraîchit notre entrée sans écraser une réclamation ; renvoie la valeur actuelle.
local function refreshEntry(e: Entry): RemoteValue?
	local map = maps[e.Mode]
	local ok, res = pcall(function()
		return map:UpdateAsync(e.Key, function(old: any)
			if type(old) == "table" then
				return old -- conserve Claimed ; renouvelle l'expiration
			end
			return {
				UserId = e.Player.UserId,
				Elo = e.Elo,
				Since = e.Since,
				JobId = game.JobId,
			}
		end, ENTRY_TTL)
	end)
	if ok and type(res) == "table" then
		return res :: any
	end
	return nil
end

local function hostMatch(e: Entry, remote: RemoteValue, remoteKey: string)
	local map = maps[e.Mode]
	local matchId = HttpService:GenerateGUID(false)
	e.Busy = true
	if not claim(map, e.Key, matchId) then
		e.Busy = false
		return
	end
	if not claim(map, remoteKey, matchId) then
		unclaim(map, e.Key, matchId)
		e.Busy = false
		return
	end
	local ok, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not ok or type(accessCode) ~= "string" then
		warn("[EtherBlades] ReserveServer : " .. tostring(accessCode))
		unclaim(map, e.Key, matchId)
		unclaim(map, remoteKey, matchId)
		e.Busy = false
		return
	end
	local record = {
		MatchId = matchId,
		Mode = e.Mode,
		AccessCode = accessCode,
		PrivateServerId = privateServerId,
		Players = { e.Player.UserId, remote.UserId },
		Created = os.time(),
	}
	local mm = matchMap :: MemoryStoreSortedMap
	local wrote = pcall(function()
		mm:SetAsync(matchId, record, MATCH_TTL)
	end)
	if not wrote then
		unclaim(map, e.Key, matchId)
		unclaim(map, remoteKey, matchId)
		e.Busy = false
		return
	end
	if e.Player.Parent then
		teleportToMatch(e.Player, record)
	end
end

local function fetchMatch(matchId: string): any?
	local mm = matchMap
	if not mm then
		return nil
	end
	local ok, rec = pcall(function()
		return mm:GetAsync(matchId)
	end)
	return if ok and type(rec) == "table" then rec else nil
end

local function crossTick()
	for _, mode in { "Ranked", "Casual" } :: { QueueMode } do
		local mine: { Entry } = {}
		for _, e in queue do
			if e.Mode == mode and not e.Busy then
				table.insert(mine, e)
			end
		end
		if #mine > 0 then
			local map = maps[mode]
			-- 1) rafraîchir nos entrées et suivre celles réclamées par un autre serveur
			local free: { Entry } = {}
			for _, e in mine do
				local v = refreshEntry(e)
				if v and v.Claimed then
					local rec = fetchMatch(v.Claimed :: string)
					if rec and table.find(rec.Players, e.Player.UserId) then
						e.Busy = true
						task.spawn(teleportToMatch, e.Player, rec)
					elseif os.time() - (v.ClaimTime or 0) > 20 then
						unclaim(map, e.Key, v.Claimed :: string) -- réclamation abandonnée
					end
				elseif v then
					table.insert(free, e)
				end
			end
			-- 2) chercher un adversaire sur un autre serveur
			if #free > 0 then
				local ok, items = pcall(function()
					return map:GetRangeAsync(Enum.SortDirection.Ascending, 200)
				end)
				if ok and type(items) == "table" then
					local now = os.time()
					local taken: { [string]: boolean } = {}
					for _, e in free do
						local best: { key: string, value: RemoteValue }? = nil
						local bestDiff = math.huge
						for _, item in items :: { any } do
							local v = item.value
							if type(v) == "table" and v.Claimed == nil and v.JobId ~= game.JobId
								and type(v.UserId) == "number" and type(v.Elo) == "number"
								and e.Player.UserId < v.UserId -- seul le plus petit UserId réclame : évite les doubles réclamations
								and not taken[item.key]
								and compatible(mode, e.Elo, now - e.Since, v.Elo, now - (tonumber(v.Since) or now))
							then
								local d = math.abs(e.Elo - v.Elo)
								if d < bestDiff then
									best, bestDiff = { key = item.key, value = v }, d
								end
							end
						end
						if best then
							local b = best :: { key: string, value: RemoteValue }
							taken[b.key] = true
							task.spawn(hostMatch, e, b.value, b.key)
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Serveur réservé : accueil des joueurs téléportés

local reservedRecord: any? = nil
local arrived: { [number]: Player } = {}
local reservedStarted = false

local function sendHome(list: { Player }, message: string?)
	if #list == 0 then
		return
	end
	for _, p in list do
		if message then
			notify(p, message, "Info")
		end
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, list)
	end)
	if not ok then
		warn("[EtherBlades] retour au Hub public : " .. tostring(err))
	end
end

local function tryStartReserved()
	local rec = reservedRecord
	if reservedStarted or not rec then
		return
	end
	local a = arrived[rec.Players[1]]
	local b = arrived[rec.Players[2]]
	if not a or not b or not DataService.get(a) or not DataService.get(b) then
		return
	end
	reservedStarted = true
	local ok, err = MatchService.start(a, b, rec.Mode, { MatchId = rec.MatchId, Reserved = true })
	if not ok then
		sendHome({ a, b }, err or "Duel annulé.")
	end
end

local function onReservedJoin(p: Player)
	local joinData = p:GetJoinData()
	local td = joinData and joinData.TeleportData
	local matchId = if type(td) == "table" and type((td :: any).MatchId) == "string" then (td :: any).MatchId else nil
	if not matchId then
		sendHome({ p }, "Aucun duel ne t'attend ici.")
		return
	end
	if not reservedRecord then
		for _ = 1, 4 do
			local rec = fetchMatch(matchId)
			if rec then
				reservedRecord = rec
				break
			end
			task.wait(2)
		end
	end
	local rec = reservedRecord
	-- le dossier MemoryStore fait foi (le TeleportData peut être falsifié par le client)
	if not rec or rec.MatchId ~= matchId or rec.PrivateServerId ~= game.PrivateServerId or not table.find(rec.Players, p.UserId) then
		sendHome({ p }, "Ce duel n'existe plus.")
		return
	end
	arrived[p.UserId] = p
	notify(p, "En attente de ton adversaire…", "Info")
	tryStartReserved()
end

local function startReservedServer()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(onReservedJoin, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onReservedJoin, p)
	end
	DataService.ProfileLoaded:Connect(function()
		tryStartReserved()
	end)
	MatchService.MatchEnded:Connect(function(_id: string, players: { Player }, reserved: boolean)
		if reserved then
			task.delay(RETURN_DELAY, function()
				local list = {}
				for _, p in players do
					if p.Parent then
						table.insert(list, p)
					end
				end
				sendHome(list, "Retour au Hub…")
			end)
		end
	end)
	-- adversaire absent : on renvoie celui qui attend
	task.spawn(function()
		local deadline = os.clock() + RESERVED_WAIT
		while os.clock() < deadline and not reservedStarted do
			task.wait(1)
		end
		if not reservedStarted then
			reservedStarted = true
			sendHome(Players:GetPlayers(), "Ton adversaire ne s'est pas présenté. Duel annulé.")
		end
	end)
end

--------------------------------------------------------------------------------
-- Défis directs

local function challenge(p: Player, targetUserId: number): Result
	if isReserved then
		return { Ok = false, Err = "Les défis se lancent depuis le Hub." }
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == p then
		return { Ok = false, Err = "Joueur introuvable." }
	end
	if MatchService.isInMatch(p) or MatchService.isInMatch(target) then
		return { Ok = false, Err = "Un des duellistes est déjà en duel." }
	end
	if not DataService.get(p) or not DataService.get(target) then
		return { Ok = false, Err = "Profil en cours de chargement…" }
	end
	local mine = lastChallenge[p]
	if not mine then
		mine = {}
		lastChallenge[p] = mine
	end
	local last = (mine :: { [number]: number })[targetUserId]
	if last and os.clock() - last < 10 then
		return { Ok = false, Err = "Patiente avant de défier à nouveau ce joueur." }
	end
	;(mine :: { [number]: number })[targetUserId] = os.clock()
	local id = HttpService:GenerateGUID(false)
	local c: Challenge = { Id = id, From = p, To = target, Expires = os.time() + CHALLENGE_TTL }
	challenges[id] = c
	Net.event("ChallengeReceived"):FireClient(target, {
		Id = id,
		FromUserId = p.UserId,
		FromName = p.DisplayName,
		Expires = Workspace:GetServerTimeNow() + CHALLENGE_TTL,
	})
	task.delay(CHALLENGE_TTL, function()
		if challenges[id] then
			challenges[id] = nil
			notify(p, target.DisplayName .. " n'a pas répondu à ton défi.", "Info")
		end
	end)
	return { Ok = true, Data = { Name = target.DisplayName } }
end

local function respond(p: Player, id: string, accept: boolean): Result
	local c = challenges[id]
	if not c or c.To ~= p then
		return { Ok = false, Err = "Ce défi n'est plus valable." }
	end
	challenges[id] = nil
	if os.time() > c.Expires or not c.From.Parent then
		return { Ok = false, Err = "Ce défi a expiré." }
	end
	if not accept then
		notify(c.From, p.DisplayName .. " a décliné ton défi.", "Info")
		return { Ok = true }
	end
	if (queue[p] and queue[p].Busy) or (queue[c.From] and (queue[c.From] :: Entry).Busy) then
		return { Ok = false, Err = "Un appariement est déjà en cours." }
	end
	notify(c.From, p.DisplayName .. " relève ton défi !", "Success")
	startLocal(c.From, p, "Challenge")
	return { Ok = true }
end

--------------------------------------------------------------------------------

function MatchmakingService.isQueued(p: Player): boolean
	return queue[p] ~= nil
end

function MatchmakingService.init()
	if crossServer then
		local ok, err = pcall(function()
			maps.Ranked = MemoryStoreService:GetSortedMap("EB_Queue_Ranked")
			maps.Casual = MemoryStoreService:GetSortedMap("EB_Queue_Casual")
			matchMap = MemoryStoreService:GetSortedMap("EB_Matches")
		end)
		if not ok then
			warn("[EtherBlades] MemoryStore indisponible, file locale uniquement : " .. tostring(err))
			crossServer = false
		end
	end
	Guard.func("JoinQueue", { "string" }, 1, 3, function(p: Player, mode: string)
		if mode ~= "Ranked" and mode ~= "Casual" then
			return { Ok = false, Err = "Mode inconnu." }
		end
		return join(p, mode :: QueueMode)
	end)
	Guard.func("LeaveQueue", {}, 2, 4, function(p: Player)
		local e = queue[p]
		if e and e.Busy then
			return { Ok = false, Err = "Adversaire trouvé, impossible d'annuler." }
		end
		leave(p, "File quittée.")
		return { Ok = true }
	end)
	Guard.func("ChallengePlayer", { "number" }, 0.5, 3, challenge)
	Guard.func("RespondChallenge", { "string", "boolean" }, 2, 4, respond)
	Players.PlayerRemoving:Connect(function(p: Player)
		local e = queue[p]
		if e then
			queue[p] = nil
			removeRemote(e)
		end
		lastChallenge[p] = nil
		for id, c in challenges do
			if c.From == p or c.To == p then
				challenges[id] = nil
			end
		end
		arrived[p.UserId] = nil
	end)
	TeleportService.TeleportInitFailed:Connect(function(p: Player, _res: Enum.TeleportResult, msg: string)
		warn("[EtherBlades] téléportation échouée pour " .. p.Name .. " : " .. tostring(msg))
		notify(p, "Téléportation échouée. Tu peux relancer la file.", "Error")
		pushQueue(p)
	end)
	MatchService.PhaseChanged:Connect(function(players: { Player }, phase: string)
		if phase == "Preparing" then
			for _, p in players do
				if queue[p] then
					leave(p)
				end
			end
		end
	end)
end

local function podPrompt(partName: string, mode: QueueMode, label: string)
	local part = HubPrompts.getPart(partName)
	if not part then
		return
	end
	local prompt = HubPrompts.attach(part, {
		Action = "Queue_" .. mode,
		ActionText = "Rejoindre / quitter la file",
		ObjectText = label,
		HoldDuration = 0.3,
		MaxDistance = 10,
	})
	prompt.Triggered:Connect(function(p: Player)
		if not HubPrompts.isNear(p, part, 16) then
			return
		end
		local e = queue[p]
		if e and e.Mode == mode then
			if not e.Busy then
				leave(p, "File quittée.")
			end
			return
		end
		local res = join(p, mode)
		if not res.Ok then
			notify(p, res.Err or "Impossible de rejoindre la file.", "Error")
		end
	end)
end

function MatchmakingService.start()
	if isReserved then
		startReservedServer()
		return
	end
	task.spawn(podPrompt, "Pod_Ranked", "Ranked", "Duel classé · BO5")
	task.spawn(podPrompt, "Pod_Casual", "Casual", "Duel amical · BO3")
	task.spawn(function()
		local part = HubPrompts.getPart("Pod_Challenge")
		if part then
			-- le client passe en mode « choisir un adversaire » (HubController)
			HubPrompts.attach(part, {
				Action = "ChallengePick",
				ActionText = "Défier un joueur",
				ObjectText = "Cercle des défis · BO3",
				MaxDistance = 10,
			})
		end
	end)
	while true do
		task.wait(TICK)
		local ok, err = pcall(matchLocal)
		if not ok then
			warn("[EtherBlades] appariement local : " .. tostring(err))
		end
		if crossServer then
			local ok2, err2 = pcall(crossTick)
			if not ok2 then
				warn("[EtherBlades] appariement inter-serveurs : " .. tostring(err2))
			end
		end
	end
end

return MatchmakingService
