--!strict
-- Séquence d'un duel : préparation (arène + beginDuel) → intro → rounds jusqu'à RoundsToWin → résultats
-- → exécution finale → poses de victoire → nettoyage (Maid). Les effets de bord (état réseau, profils)
-- sont délégués aux hooks fournis par MatchService.
local Workspace = game:GetService("Workspace")

local MatchTypes = require(script.Parent.MatchTypes)
local ArenaAllocator = require(script.Parent.ArenaAllocator)
local CombatBridge = require(script.Parent.CombatBridge)
local Deps = require(script.Parent.Deps)

type Match = MatchTypes.Match
type Phase = MatchTypes.Phase

export type Hooks = {
	setPhase: (m: Match, phase: Phase) -> (),
	applyResults: (m: Match) -> (),
	cleanup: (m: Match) -> (),
}

local MatchRunner = {}

MatchRunner.RoundTime = 120 -- s avant arbitrage aux points de vie
MatchRunner.RoundPause = 2.5
MatchRunner.VictoryTime = 6
MatchRunner.ForfeitTime = 3

local rng = Random.new()

local function other(m: Match, p: Player): Player
	return if p == m.A then m.B else m.A
end

local function healthPct(p: Player): number
	local char = p.Character
	if not char then
		return 0
	end
	local attr = char:GetAttribute("HealthPct")
	if type(attr) == "number" then
		return attr
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.MaxHealth > 0 then
		return hum.Health / hum.MaxHealth
	end
	return 0
end

-- Fin de temps réglementaire : le plus de PV l'emporte (égalité parfaite : tirage au sort).
local function judge(m: Match): Player
	local a, b = healthPct(m.A), healthPct(m.B)
	if math.abs(a - b) < 1e-3 then
		return if rng:NextNumber() < 0.5 then m.A else m.B
	end
	return if a > b then m.A else m.B
end

local function waitCharacters(m: Match)
	local deadline = os.clock() + 10
	while os.clock() < deadline and not m.Leaver do
		local ready = true
		for _, p in m.Players do
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				ready = false
			end
		end
		if ready then
			return
		end
		task.wait(0.25)
	end
end

local function pause(m: Match, seconds: number)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not m.Leaver do
		task.wait(0.1)
	end
end

function MatchRunner.run(m: Match, h: Hooks)
	h.setPhase(m, "Preparing")
	local arena, release = ArenaAllocator.acquire(m.ArenaId, m.Id)
	m.Maid:Give(release)
	if not arena then
		h.cleanup(m)
		return
	end
	m.Arena = arena
	waitCharacters(m)
	for _, p in m.Players do
		Deps.allowMovement(p, 6)
	end
	if not m.Leaver then
		for _, p in { m.A, m.B } do
			for _, k in { "EB_StatParries", "EB_StatBreaks", "EB_StatCounters" } do
				p:SetAttribute(k, 0)
			end
		end
		CombatBridge.beginDuel(m.Id, m.A, m.B, arena)
	end
	-- endDuel doit passer avant la destruction de l'arène : le Maid nettoie dans l'ordre inverse.
	m.Maid:Give(function()
		CombatBridge.endDuel(m.Id)
	end)

	local pendingWinner: Player? = nil
	local conn = CombatBridge.onRoundEnded(function(id: string, winner: Player, _loser: Player)
		if id == m.Id and m.Phase == "Round" and pendingWinner == nil and (winner == m.A or winner == m.B) then
			pendingWinner = winner
		end
	end)
	m.Maid:Give(function()
		conn:Disconnect()
	end)

	if not m.Leaver then
		h.setPhase(m, "Intro")
		CombatBridge.playIntro(m.Id)
	end

	while not m.Leaver do
		m.Round += 1
		pendingWinner = nil
		CombatBridge.startRound(m.Id)
		m.RoundEndsAt = Workspace:GetServerTimeNow() + MatchRunner.RoundTime
		h.setPhase(m, "Round")
		local deadline = os.clock() + MatchRunner.RoundTime
		while pendingWinner == nil and not m.Leaver and os.clock() < deadline do
			task.wait(0.1)
		end
		if m.Leaver then
			break
		end
		local w = pendingWinner or judge(m)
		m.Scores[w] += 1
		m.LastRoundWinner = w
		if m.Scores[w] >= m.RoundsToWin then
			m.Winner = w
			m.Loser = other(m, w)
			break
		end
		h.setPhase(m, "RoundEnd")
		pause(m, MatchRunner.RoundPause)
	end

	if m.Leaver and not m.Winner then
		-- abandon : défaite automatique du fuyard
		local leaver = m.Leaver :: Player
		m.Loser = leaver
		m.Winner = other(m, leaver)
		h.applyResults(m)
		h.setPhase(m, "Victory")
		task.wait(MatchRunner.ForfeitTime)
	else
		-- résultats appliqués avant l'exécution : quitter pendant la cinématique ne change plus rien
		h.applyResults(m)
		local w, l = m.Winner :: Player, m.Loser :: Player
		h.setPhase(m, "Finisher")
		if w.Parent and l.Parent then
			CombatBridge.playFinisher(m.Id, w, l)
		end
		h.setPhase(m, "Victory")
		task.wait(MatchRunner.VictoryTime)
	end
	h.cleanup(m)
end

return MatchRunner
