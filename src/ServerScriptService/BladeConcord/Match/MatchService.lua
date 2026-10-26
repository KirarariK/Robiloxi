--!strict
--[[
	Salon → file → countdown → duel BO3 (FT2) → retour salon.
	Modes Casual / Ranked. Bot uniquement après « Jouer » Amical solo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FighterState = require(script.Parent.Parent.Combat:WaitForChild("FighterState"))
local ArenaService = require(script.Parent.Parent.Combat:WaitForChild("ArenaService"))

local MatchService = {}

export type MatchPhase = "Lobby" | "Countdown" | "Fighting" | "RoundEnd" | "MatchEnd"

local remotes: Remotes.CombatRemotes
local metaRemotes: Remotes.MetaRemotes

local phase: MatchPhase = "Lobby"
local mode: CombatTypes.MatchMode = "Casual"
local scores: { [number]: number } = {} -- userId → rounds won
local roundNumber = 0
local phaseTimer = 0
local arenaRotationIndex = 1
local queue: { Player } = {}
local activePair: { Player } = {}
local soloPractice = false
local soloMatchmakingTimer = 0
local pendingSoloPlayer: Player? = nil
local onMatchEndHook: ((winner: Player?, loser: Player?, mode: CombatTypes.MatchMode) -> ())? = nil
local onRoundEndHook: ((winner: Player?) -> ())? = nil
local onLobbyHook: (() -> ())? = nil
local lastRematchRequestAt: { [number]: number } = {} -- userId → clock

local function pruneActivePair()
	local kept = {}
	for _, p in activePair do
		if p and p.Parent == Players then
			table.insert(kept, p)
		end
	end
	activePair = kept
end

local function teleportPlayersToLobby(players: { Player })
	local lobbyCf = ArenaService.getLobbyCFrame()
	for i, p in players do
		local character = p.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				-- Léger offset pour éviter stack
				hrp.CFrame = lobbyCf * CFrame.new((i - 1) * 4 - 2, 0, 0)
			end
		end
	end
end

local function broadcast()
	local scoreboard = {}
	for userId, wins in scores do
		table.insert(scoreboard, { userId = userId, wins = wins })
	end
	local fighters = {}
	for _, p in activePair do
		if p and p.Parent == Players then
			table.insert(fighters, {
				userId = p.UserId,
				name = p.DisplayName ~= "" and p.DisplayName or p.Name,
			})
		end
	end
	if soloPractice then
		table.insert(fighters, { userId = -9001, name = "ConcordBot" })
	end
	local queuedIds = {}
	for _, p in queue do
		if p and p.Parent == Players then
			table.insert(queuedIds, p.UserId)
		end
	end
	remotes.MatchState:FireAllClients({
		phase = phase,
		mode = mode,
		roundNumber = roundNumber,
		firstTo = CombatConfig.Match.FirstTo,
		bestOf = CombatConfig.Match.BestOf,
		scores = scoreboard,
		fighters = fighters,
		arenaId = if phase == "Lobby" then "ConcordLobby" else ArenaService.getActiveId(),
		arenaName = if phase == "Lobby"
			then ArenaService.getLobbyDisplayName()
			else string.format("%s · #%d", ArenaService.getDisplayName(), ArenaService.getActivePoolIndex()),
		arenaIndex = if phase == "Lobby" then nil else ArenaService.getActivePoolIndex(),
		fairKit = mode == "Ranked" and phase ~= "Lobby",
		countdown = if phase == "Countdown" then phaseTimer else nil,
		rematchIn = if phase == "MatchEnd" then phaseTimer else nil,
		queueCount = #queue,
		queuedUserIds = queuedIds,
		soloMatchmaking = pendingSoloPlayer ~= nil,
		inLobby = phase == "Lobby",
	})
end

function MatchService.setMatchEndHook(hook: (winner: Player?, loser: Player?, mode: CombatTypes.MatchMode) -> ())
	onMatchEndHook = hook
end

function MatchService.setRoundEndHook(hook: (winner: Player?) -> ())
	onRoundEndHook = hook
end

function MatchService.setLobbyHook(hook: () -> ())
	onLobbyHook = hook
end

function MatchService.getPhase(): MatchPhase
	return phase
end

function MatchService.getMode(): CombatTypes.MatchMode
	return mode
end

function MatchService.isFighting(): boolean
	return phase == "Fighting"
end

function MatchService.isInLobby(): boolean
	return phase == "Lobby"
end

function MatchService.isPlayerQueued(player: Player): boolean
	for _, p in queue do
		if p == player then
			return true
		end
	end
	return pendingSoloPlayer == player
end

function MatchService.broadcast()
	broadcast()
end

local function resetScores(players: { Player })
	scores = {}
	for _, p in players do
		scores[p.UserId] = 0
	end
	roundNumber = 0
end

local function teleportToArena()
	local a, b = ArenaService.getSpawnCFrames()
	for i, p in activePair do
		local character = p.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				hrp.CFrame = if i == 1 then a else b
			end
		end
		local f = FighterState.get(p)
		if f then
			FighterState.resetRound(f)
			p:SetAttribute("BC_MatchMode", mode)
		end
	end
end

function MatchService.beginCountdown()
	phase = "Countdown"
	phaseTimer = CombatConfig.Match.LobbyCountdown
	pendingSoloPlayer = nil
	soloMatchmakingTimer = 0
	teleportToArena()
	broadcast()
end

function MatchService.beginRound()
	phase = "Fighting"
	roundNumber += 1
	for _, p in activePair do
		local f = FighterState.get(p)
		if f then
			FighterState.resetRound(f)
		end
	end
	teleportToArena()
	workspace:SetAttribute("BC_RoundStart", os.clock())
	broadcast()
end

function MatchService.onRoundWinner(winner: Player?, winnerUserIdOverride: number?)
	if phase ~= "Fighting" then
		return
	end
	phase = "RoundEnd"
	phaseTimer = CombatConfig.Match.InterRoundDelay
	local winId = winnerUserIdOverride or (if winner then winner.UserId else nil)
	if winId then
		scores[winId] = (scores[winId] or 0) + 1
	end
	if onRoundEndHook then
		onRoundEndHook(winner)
	end
	broadcast()

	local ft = CombatConfig.Match.FirstTo
	local matchWinner: Player? = nil
	local matchWinnerId: number? = nil
	for userId, wins in scores do
		if wins >= ft then
			matchWinnerId = userId
			break
		end
	end
	if matchWinnerId then
		for _, p in activePair do
			if p.UserId == matchWinnerId then
				matchWinner = p
				break
			end
		end
	end

	local function resolveLoserUserId(winnerId: number?): number?
		if not winnerId then
			return nil
		end
		if soloPractice then
			if winnerId == -9001 then
				return if activePair[1] then activePair[1].UserId else nil
			end
			return -9001
		end
		for _, p in activePair do
			if p.UserId ~= winnerId then
				return p.UserId
			end
		end
		return nil
	end

	if matchWinnerId then
		phase = "MatchEnd"
		phaseTimer = CombatConfig.Match.MatchEndDelay or 8
		local loser: Player? = nil
		for _, p in activePair do
			if p.UserId ~= matchWinnerId then
				loser = p
			end
		end
		if matchWinner and onMatchEndHook then
			onMatchEndHook(matchWinner, loser, mode)
		elseif soloPractice and matchWinner and onMatchEndHook then
			onMatchEndHook(matchWinner, nil, mode)
		elseif soloPractice and matchWinnerId ~= nil and matchWinner == nil then
			if onMatchEndHook and activePair[1] then
				onMatchEndHook(nil, activePair[1], mode)
			end
		end
		remotes.RoundEnded:FireAllClients({
			winnerUserId = matchWinnerId,
			matchOver = true,
			scores = scores,
		})
		remotes.FxEvent:FireAllClients({
			kind = "KoFinisher",
			payload = {
				winnerUserId = matchWinnerId,
				loserUserId = resolveLoserUserId(matchWinnerId),
				matchOver = true,
			},
		})
		broadcast()
	else
		remotes.RoundEnded:FireAllClients({
			winnerUserId = winId,
			matchOver = false,
			scores = scores,
		})
		remotes.FxEvent:FireAllClients({
			kind = "KoFinisher",
			payload = {
				winnerUserId = winId,
				loserUserId = resolveLoserUserId(winId),
				matchOver = false,
			},
		})
	end
end

--[[ Pool croiseur 8 arènes (World BC_MatchArena 1..8) — rotation / libre. ]]
local function pickArena()
	local idx = ArenaService.pickMatchArena()
	arenaRotationIndex = idx
end

function MatchService.tryStartPair(p1: Player, p2: Player, matchMode: CombatTypes.MatchMode?)
	mode = matchMode or "Casual"
	activePair = { p1, p2 }
	soloPractice = false
	pendingSoloPlayer = nil
	soloMatchmakingTimer = 0
	resetScores(activePair)
	for _, p in activePair do
		local f = FighterState.get(p)
		if f then
			FighterState.resetMatch(f)
		end
	end
	pickArena()
	MatchService.beginCountdown()
end

function MatchService.leaveQueue(player: Player)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	if pendingSoloPlayer == player then
		pendingSoloPlayer = nil
		soloMatchmakingTimer = 0
	end
	-- Libère aussi un claim slot allée
	local SlotMatchService = require(script.Parent:WaitForChild("SlotMatchService"))
	SlotMatchService.release(player)
	broadcast()
end

function MatchService.enqueue(player: Player, matchMode: CombatTypes.MatchMode?)
	if phase ~= "Lobby" then
		-- Déjà en match : ignore (évite double file)
		broadcast()
		return
	end
	mode = matchMode or mode
	-- leaveQueue appelle déjà SlotMatchService.release — on retire seulement la file globale ici
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	if pendingSoloPlayer == player then
		pendingSoloPlayer = nil
		soloMatchmakingTimer = 0
	end
	local SlotMatchService = require(script.Parent:WaitForChild("SlotMatchService"))
	SlotMatchService.release(player)

	-- Deux joueurs déjà présents → démarrer immédiatement si les deux en queue / ou pair auto via file
	table.insert(queue, player)

	if #queue >= 2 then
		local a = table.remove(queue, 1) :: Player
		local b = table.remove(queue, 1) :: Player
		pendingSoloPlayer = nil
		soloMatchmakingTimer = 0
		MatchService.tryStartPair(a, b, mode)
		return
	end

	-- Solo Amical → court matchmaking puis bot
	if mode == "Casual" and #Players:GetPlayers() == 1 then
		pendingSoloPlayer = player
		soloMatchmakingTimer = CombatConfig.Match.SoloMatchmakingDelay or 1.6
		broadcast()
		return
	end

	-- Classé solo ou Amical multi sans pair : reste en file
	pendingSoloPlayer = nil
	soloMatchmakingTimer = 0
	broadcast()
end

function MatchService.returnToLobby()
	pruneActivePair()
	local toTeleport = {}
	for _, p in activePair do
		table.insert(toTeleport, p)
	end
	for _, p in Players:GetPlayers() do
		local found = false
		for _, t in toTeleport do
			if t == p then
				found = true
				break
			end
		end
		if not found then
			table.insert(toTeleport, p)
		end
	end

	soloPractice = false
	pendingSoloPlayer = nil
	soloMatchmakingTimer = 0
	phase = "Lobby"
	phaseTimer = 0
	scores = {}
	roundNumber = 0
	activePair = {}
	queue = {}
	lastRematchRequestAt = {}
	mode = "Casual"

	teleportPlayersToLobby(toTeleport)
	ArenaService.releasePoolOccupation()
	ArenaService.applyLobbyLighting()
	local SlotMatchService = require(script.Parent:WaitForChild("SlotMatchService"))
	SlotMatchService.onReturnedToLobby()
	if onLobbyHook then
		onLobbyHook()
	end
	broadcast()
end

function MatchService.rematch()
	pruneActivePair()
	if #activePair == 0 then
		MatchService.returnToLobby()
		return
	end
	if not soloPractice and #activePair == 1 then
		-- Adversaire parti → salon (pas de bot imposé en silence)
		MatchService.returnToLobby()
		return
	elseif not soloPractice and #activePair < 2 then
		MatchService.returnToLobby()
		return
	end
	resetScores(activePair)
	-- Solo et 1v1 : re-pick dans le pool 8 (libre / rotation)
	if soloPractice then
		scores[-9001] = 0
	end
	pickArena()
	for _, p in activePair do
		local f = FighterState.get(p)
		if f then
			FighterState.resetMatch(f)
		end
	end
	lastRematchRequestAt = {}
	MatchService.beginCountdown()
end

function MatchService.onPlayerRemoving(player: Player)
	MatchService.leaveQueue(player)
	lastRematchRequestAt[player.UserId] = nil
	local wasActive = false
	for i = #activePair, 1, -1 do
		if activePair[i] == player then
			table.remove(activePair, i)
			wasActive = true
		end
	end
	if not wasActive then
		broadcast()
		return
	end
	local remaining = activePair[1]
	if not remaining then
		MatchService.returnToLobby()
		return
	end
	if phase == "Fighting" or phase == "Countdown" or phase == "RoundEnd" then
		scores[remaining.UserId] = CombatConfig.Match.FirstTo
		phase = "MatchEnd"
		phaseTimer = 3
		if onMatchEndHook then
			onMatchEndHook(remaining, nil, mode)
		end
		remotes.RoundEnded:FireAllClients({
			winnerUserId = remaining.UserId,
			matchOver = true,
			scores = scores,
		})
		broadcast()
	elseif phase == "MatchEnd" then
		pruneActivePair()
		broadcast()
	else
		broadcast()
	end
end

--[[ Demande client REVANCHE — MatchEnd only + cooldown anti-spam. ]]
function MatchService.requestRematch(player: Player): boolean
	if phase ~= "MatchEnd" then
		return false
	end
	local inPair = false
	for _, p in activePair do
		if p == player then
			inPair = true
			break
		end
	end
	if not inPair and not (soloPractice and activePair[1] == player) then
		return false
	end
	local cd = CombatConfig.Match.RematchServerCooldown or 2
	local now = os.clock()
	local last = lastRematchRequestAt[player.UserId]
	if last and (now - last) < cd then
		return false
	end
	lastRematchRequestAt[player.UserId] = now
	MatchService.rematch()
	return true
end

function MatchService.requestReturnLobby(player: Player): boolean
	if phase ~= "MatchEnd" and phase ~= "Lobby" then
		-- Autoriser retour salon seulement hors combat actif
		if phase == "Countdown" or phase == "Fighting" or phase == "RoundEnd" then
			return false
		end
	end
	if phase == "Lobby" then
		MatchService.leaveQueue(player)
		return true
	end
	-- MatchEnd : n'importe quel joueur du serveur peut forcer le retour salon
	MatchService.returnToLobby()
	return true
end

function MatchService.isSoloPractice(): boolean
	return soloPractice
end

function MatchService.beginSoloPractice(player: Player)
	soloPractice = true
	mode = "Casual"
	pendingSoloPlayer = nil
	soloMatchmakingTimer = 0
	-- Retirer de la file
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	activePair = { player }
	resetScores(activePair)
	scores[-9001] = 0 -- ConcordBot
	local f = FighterState.get(player)
	if f then
		FighterState.resetMatch(f)
	end
	pickArena() -- pool 8 arènes (pas figé Obsidian)
	MatchService.beginCountdown()
end

function MatchService.step(dt: number)
	if phase == "Countdown" then
		phaseTimer -= dt
		if phaseTimer <= 0 then
			MatchService.beginRound()
		else
			broadcast()
		end
	elseif phase == "RoundEnd" then
		phaseTimer -= dt
		if phaseTimer <= 0 then
			MatchService.beginRound()
		end
	elseif phase == "MatchEnd" then
		phaseTimer -= dt
		broadcast()
		if phaseTimer <= 0 then
			-- Auto → allée lobby (pas revanches infinies sans consentement)
			MatchService.returnToLobby()
		end
	elseif phase == "Lobby" then
		local SlotMatchService = require(script.Parent:WaitForChild("SlotMatchService"))
		SlotMatchService.step(dt)
		-- Matchmaking solo Amical (HUD / ancien pad) → bot après délai
		if pendingSoloPlayer and pendingSoloPlayer.Parent == Players then
			soloMatchmakingTimer -= dt
			if soloMatchmakingTimer <= 0 then
				local p = pendingSoloPlayer
				pendingSoloPlayer = nil
				if p then
					MatchService.beginSoloPractice(p)
				end
			else
				broadcast()
			end
		else
			pendingSoloPlayer = nil
		end
	end
end

function MatchService.teleportPlayerToLobby(player: Player)
	teleportPlayersToLobby({ player })
end

function MatchService.start()
	remotes = Remotes.get()
	metaRemotes = Remotes.getMeta()
	ArenaService.ensureAll()
	ArenaService.ensureLobby()
	ArenaService.applyLobbyLighting()

	-- Pads monde legacy (Casual/Ranked) → file globale ; slots BC_DuelSlot = SlotMatchService
	local LobbyBuilder = require(script.Parent.Parent:WaitForChild("Lobby"):WaitForChild("LobbyBuilder"))
	LobbyBuilder.bindQueuePads(function(player, mode)
		MatchService.enqueue(player, mode :: any)
	end)

	local SlotMatchService = require(script.Parent:WaitForChild("SlotMatchService"))
	SlotMatchService.start()

	metaRemotes.QueueMatch.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			payload = {}
		end
		local m = payload.mode
		if m ~= "Casual" and m ~= "Ranked" then
			m = "Casual"
		end
		MatchService.enqueue(player, m)
	end)

	metaRemotes.LeaveQueue.OnServerEvent:Connect(function(player)
		MatchService.leaveQueue(player)
	end)

	remotes.RequestRematch.OnServerEvent:Connect(function(player)
		MatchService.requestRematch(player)
	end)

	remotes.RequestReturnLobby.OnServerEvent:Connect(function(player)
		MatchService.requestReturnLobby(player)
	end)

	broadcast()
end

return MatchService
