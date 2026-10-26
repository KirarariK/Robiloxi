--!strict
--[[
	Lobby → duel BO3 (FT2) → rematch. Modes Casual / Ranked.
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
local onMatchEndHook: ((winner: Player?, loser: Player?, mode: CombatTypes.MatchMode) -> ())? = nil
local onRoundEndHook: ((winner: Player?) -> ())? = nil

local function broadcast()
	local scoreboard = {}
	for userId, wins in scores do
		table.insert(scoreboard, { userId = userId, wins = wins })
	end
	remotes.MatchState:FireAllClients({
		phase = phase,
		mode = mode,
		roundNumber = roundNumber,
		firstTo = CombatConfig.Match.FirstTo,
		scores = scoreboard,
		arenaId = ArenaService.getActiveId(),
		arenaName = ArenaService.getDisplayName(),
		fairKit = mode == "Ranked",
		countdown = if phase == "Countdown" then phaseTimer else nil,
		queueCount = #queue,
	})
end

function MatchService.setMatchEndHook(hook: (winner: Player?, loser: Player?, mode: CombatTypes.MatchMode) -> ())
	onMatchEndHook = hook
end

function MatchService.setRoundEndHook(hook: (winner: Player?) -> ())
	onRoundEndHook = hook
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
	-- Bot reset hook via attribute for CombatService
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

	if matchWinnerId then
		phase = "MatchEnd"
		phaseTimer = 3
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
			-- Bot won the match — still reward loss for human
			if onMatchEndHook and activePair[1] then
				onMatchEndHook(nil, activePair[1], mode)
			end
		end
		remotes.RoundEnded:FireAllClients({
			winnerUserId = matchWinnerId,
			matchOver = true,
			scores = scores,
		})
		broadcast()
	else
		remotes.RoundEnded:FireAllClients({
			winnerUserId = winId,
			matchOver = false,
			scores = scores,
		})
	end
end

local function pickArena()
	local list = ArenaService.list()
	arenaRotationIndex = (arenaRotationIndex % #list) + 1
	ArenaService.setActive(list[arenaRotationIndex])
end

function MatchService.tryStartPair(p1: Player, p2: Player, matchMode: CombatTypes.MatchMode?)
	mode = matchMode or "Casual"
	activePair = { p1, p2 }
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

function MatchService.enqueue(player: Player, matchMode: CombatTypes.MatchMode?)
	mode = matchMode or mode
	for _, p in queue do
		if p == player then
			broadcast()
			return
		end
	end
	-- Si déjà 2 joueurs en serveur Studio, auto-start
	table.insert(queue, player)
	if #queue >= 2 then
		local a = table.remove(queue, 1) :: Player
		local b = table.remove(queue, 1) :: Player
		MatchService.tryStartPair(a, b, mode)
	elseif #Players:GetPlayers() >= 2 and #activePair == 0 then
		local all = Players:GetPlayers()
		if #all >= 2 then
			queue = {}
			MatchService.tryStartPair(all[1], all[2], mode)
		end
	else
		broadcast()
	end
end

function MatchService.rematch()
	if #activePair >= 1 then
		resetScores(activePair)
		if soloPractice then
			scores[-9001] = 0
			ArenaService.setActive("ObsidianPit")
		else
			pickArena()
		end
		for _, p in activePair do
			local f = FighterState.get(p)
			if f then
				FighterState.resetMatch(f)
			end
		end
		MatchService.beginCountdown()
	end
end

local soloPractice = false
local soloLobbyWait = 0

function MatchService.isSoloPractice(): boolean
	return soloPractice
end

function MatchService.beginSoloPractice(player: Player)
	soloPractice = true
	mode = "Casual"
	activePair = { player }
	resetScores(activePair)
	scores[-9001] = 0 -- ConcordBot
	local f = FighterState.get(player)
	if f then
		FighterState.resetMatch(f)
	end
	ArenaService.setActive("ObsidianPit")
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
		if phaseTimer <= 0 then
			MatchService.rematch()
		end
	elseif phase == "Lobby" then
		if #Players:GetPlayers() >= 2 and #activePair == 0 then
			soloPractice = false
			local all = Players:GetPlayers()
			MatchService.tryStartPair(all[1], all[2], mode)
		elseif #Players:GetPlayers() == 1 and #activePair == 0 then
			soloLobbyWait += dt
			if soloLobbyWait >= 2 then
				soloLobbyWait = 0
				MatchService.beginSoloPractice(Players:GetPlayers()[1])
			end
		else
			soloLobbyWait = 0
		end
	end
end

function MatchService.start()
	remotes = Remotes.get()
	metaRemotes = Remotes.getMeta()
	ArenaService.ensureAll()

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

	broadcast()
end

return MatchService
