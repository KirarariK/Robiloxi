--!strict
-- Déroulé des duels : création du match, état réseau (`MatchState`), résultats (Elo classé, stats, maîtrise,
-- Cristaux, titres), écran de fin (`MatchResult`), abandon (défaite + pénalité, y compris hors ligne),
-- retour au Hub. La séquence elle-même est dans Match/MatchRunner.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Maid = require(Shared.Util.Maid)
local RankData = require(Shared.Config.RankData)
local ArenaData = require(Shared.Config.ArenaData)

local DataService = require(script.Parent.DataService)
local TitleService = require(script.Parent.TitleService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local RerollService = require(script.Parent.RerollService)

local MatchFolder = script.Parent.Parent.Match
local MatchTypes = require(MatchFolder.MatchTypes)
local MatchRunner = require(MatchFolder.MatchRunner)
local ArenaAllocator = require(MatchFolder.ArenaAllocator)
local Results = require(MatchFolder.Results)
local OfflinePenalty = require(MatchFolder.OfflinePenalty)
local HubPrompts = require(MatchFolder.HubPrompts)
local Deps = require(MatchFolder.Deps)

type Match = MatchTypes.Match
type Mode = MatchTypes.Mode
type Phase = MatchTypes.Phase

local MatchService = {}
MatchService.Priority = 40

local phaseEvent = Instance.new("BindableEvent")
MatchService.PhaseChanged = phaseEvent.Event -- (players: { Player }, phase: string)
local endedEvent = Instance.new("BindableEvent")
MatchService.MatchEnded = endedEvent.Event -- (matchId: string, players: { Player }, reserved: boolean)

local matches: { [string]: Match } = {}
local byPlayer: { [Player]: Match } = {}
local rng = Random.new()

local function other(m: Match, p: Player): Player
	return if p == m.A then m.B else m.A
end

local function present(p: Player): boolean
	return p.Parent == Players
end

local function viewFor(m: Match, p: Player): { [string]: any }
	local opp = other(m, p)
	return {
		Active = m.Phase ~= "Ended",
		MatchId = m.Id,
		Mode = m.Mode,
		Phase = m.Phase,
		Round = m.Round,
		RoundsToWin = m.RoundsToWin,
		MyScore = m.Scores[p],
		OppScore = m.Scores[opp],
		OpponentUserId = opp.UserId,
		OpponentName = m.Names[opp],
		ArenaId = m.ArenaId,
		ArenaName = m.ArenaName,
		RoundEndsAt = m.RoundEndsAt,
		LastRoundWinnerUserId = if m.LastRoundWinner then (m.LastRoundWinner :: Player).UserId else 0,
		WinnerUserId = if m.Winner then (m.Winner :: Player).UserId else 0,
		Forfeit = m.Leaver ~= nil,
	}
end

local function broadcast(m: Match)
	for _, p in m.Players do
		if present(p) then
			Net.event("MatchState"):FireClient(p, viewFor(m, p))
		end
	end
end

local function setPhase(m: Match, phase: Phase)
	m.Phase = phase
	broadcast(m)
	phaseEvent:Fire(table.clone(m.Players), phase)
end

local function applyResults(m: Match)
	if m.Finished then
		return
	end
	m.Finished = true
	local winner = m.Winner :: Player
	for _, p in m.Players do
		local opp = other(m, p)
		local won = p == winner
		local leaver = p == m.Leaver
		local outcome: Results.Outcome = {
			Won = won,
			Mode = m.Mode,
			OppElo = m.StartElo[opp],
			Leaver = leaver, -- Elo retiré en classé uniquement ; délai de file appliqué dans tous les modes
			Reward = RerollService.duelReward(won, m.Mode, m.Scores[p], leaver),
		}
		if leaver and m.LeaverHandled then
			continue -- déjà appliqué à la session juste avant sa sauvegarde finale
		elseif leaver or not present(p) or not DataService.get(p) then
			-- session déjà libérée : écriture hors ligne directe en respectant le verrou
			OfflinePenalty.schedule(p.UserId, function(profile: any)
				Results.apply(profile, outcome)
			end)
		else
			local tierBefore = LeaderboardService.tierOf(p)
			local summary: Results.Summary? = nil
			local newTitles: { string } = {}
			local wr = LeaderboardService.getWorldRank(p.UserId)
			DataService.update(p, function(profile: Types.Profile)
				summary = Results.apply(profile, outcome)
				newTitles = TitleService.evaluate(profile, wr)
			end)
			TitleService.refresh(p)
			local tierAfter = LeaderboardService.tierOf(p)
			local s = summary :: Results.Summary
			Net.event("MatchResult"):FireClient(p, {
				MatchId = m.Id,
				Mode = m.Mode,
				Won = won,
				Forfeit = m.Leaver ~= nil,
				MyScore = m.Scores[p],
				OppScore = m.Scores[opp],
				OpponentName = m.Names[opp],
				EloBefore = s.EloBefore,
				EloAfter = s.EloAfter,
				EloDelta = s.EloDelta,
				Reward = s.Reward,
				WinStreak = s.WinStreak,
				MasteryForm = s.MasteryForm,
				MasteryValue = s.MasteryValue,
				NewTitles = newTitles,
				TierBefore = tierBefore.Id,
				TierAfter = tierAfter.Id,
			})
			if #newTitles > 0 then
				task.delay(2, function()
					if present(p) then
						TitleService.notifyUnlocked(p, newTitles)
					end
				end)
			end
		end
	end
	LeaderboardService.requestRefresh()
end

local function returnToHub(p: Player)
	if not present(p) then
		return
	end
	local spawnPart = HubPrompts.getPart("HubSpawn", 1)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		p:LoadCharacter()
		return
	end
	if spawnPart then
		Deps.allowMovement(p, 4)
		local offset = Vector3.new(rng:NextNumber(-6, 6), 4, rng:NextNumber(-6, 6))
		Deps.teleport(p, CFrame.new(spawnPart.Position + offset) * spawnPart.CFrame.Rotation)
		local root = char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
		end
	else
		p:LoadCharacter()
	end
end

local function cleanup(m: Match)
	m.Phase = "Ended"
	broadcast(m)
	phaseEvent:Fire(table.clone(m.Players), "Ended")
	m.Maid:Clean()
	local stillHere: { Player } = {}
	for _, p in m.Players do
		if byPlayer[p] == m then
			byPlayer[p] = nil
		end
		if present(p) then
			p:SetAttribute("EB_InMatch", false)
			table.insert(stillHere, p)
			returnToHub(p)
		end
	end
	matches[m.Id] = nil
	endedEvent:Fire(m.Id, stillHere, m.Reserved)
end

local hooks: MatchRunner.Hooks = {
	setPhase = setPhase,
	applyResults = applyResults,
	cleanup = cleanup,
}

--------------------------------------------------------------------------------
-- API publique

export type StartOpts = { MatchId: string?, Reserved: boolean? }

function MatchService.isInMatch(p: Player): boolean
	return byPlayer[p] ~= nil
end

function MatchService.phaseOf(p: Player): string?
	local m = byPlayer[p]
	return if m then m.Phase else nil
end

-- Lance un duel sur ce serveur. Retourne false + raison si impossible.
function MatchService.start(a: Player, b: Player, mode: Mode, opts: StartOpts?): (boolean, string?)
	if a == b then
		return false, "Adversaire invalide."
	end
	if not present(a) or not present(b) then
		return false, "Un des joueurs a quitté le serveur."
	end
	if byPlayer[a] or byPlayer[b] then
		return false, "Un des joueurs est déjà en duel."
	end
	local pa, pb = DataService.get(a), DataService.get(b)
	if not pa or not pb then
		return false, "Profil en cours de chargement."
	end
	local format = (RankData.Formats :: any)[mode]
	if not format then
		return false, "Mode inconnu."
	end
	local id = (opts and opts.MatchId) or HttpService:GenerateGUID(false)
	local arenaId = ArenaAllocator.pickArenaId(rng)
	local arenaDef = ArenaData.get(arenaId)
	local m: Match = {
		Id = id,
		Mode = mode,
		A = a,
		B = b,
		Players = { a, b },
		UserIds = { a.UserId, b.UserId },
		Names = { [a] = a.DisplayName, [b] = b.DisplayName },
		Scores = { [a] = 0, [b] = 0 },
		StartElo = { [a] = pa.Elo, [b] = pb.Elo },
		Round = 0,
		RoundsToWin = format.RoundsToWin,
		Phase = "Preparing",
		ArenaId = arenaId,
		ArenaName = if arenaDef then arenaDef.Name else arenaId,
		Arena = nil,
		RoundEndsAt = 0,
		LastRoundWinner = nil,
		Leaver = nil,
		LeaverHandled = false,
		Winner = nil,
		Loser = nil,
		Finished = false,
		Reserved = (opts and opts.Reserved) == true,
		Maid = Maid.new(),
	}
	matches[id] = m
	byPlayer[a] = m
	byPlayer[b] = m
	a:SetAttribute("EB_InMatch", true)
	b:SetAttribute("EB_InMatch", true)
	task.spawn(function()
		local ok, err = pcall(MatchRunner.run, m, hooks)
		if not ok then
			warn(string.format("[EtherBlades] match %s interrompu : %s", id, tostring(err)))
			if matches[id] then
				cleanup(m)
			end
		end
	end)
	return true, nil
end

-- Règle des emotes : libres hors duel ; en duel, Salut à l'intro, poses de victoire (et salut) à la fin.
function MatchService.emoteAllowed(p: Player, def: Types.EmoteDef): (boolean, string?)
	local m = byPlayer[p]
	if not m then
		return true, nil
	end
	if m.Phase == "Preparing" or m.Phase == "Intro" then
		if def.Category == "Salut" then
			return true, nil
		end
		return false, "Avant le duel, seul un salut est permis."
	elseif m.Phase == "Victory" then
		if p == m.Winner or def.Category == "Salut" then
			return true, nil
		end
		return false, "Seul un salut est permis après une défaite."
	end
	return false, "Pas d'emote pendant le combat."
end

function MatchService.init()
	OfflinePenalty.setMemoryMode(DataService.isMemoryMode())
	DataService.ProfileLoaded:Connect(function(player: Player)
		OfflinePenalty.consume(player.UserId, function(apply: (profile: any) -> ())
			DataService.update(player, function(profile)
				apply(profile)
			end)
			Net.event("Notify"):FireClient(player, {
				Text = "Ton dernier duel abandonné a été compté comme une défaite.",
				Kind = "Error",
			})
		end)
		TitleService.refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		local m = byPlayer[p]
		if m and not m.Finished and not m.Leaver then
			m.Leaver = p
		end
	end)
	-- Une frame après PlayerRemoving, avant la sauvegarde finale : la défaite d'abandon est écrite
	-- dans la session encore ouverte (pas besoin d'UpdateAsync hors ligne).
	DataService.onBeforeRelease(function(p: Player, profile: Types.Profile)
		local m = byPlayer[p]
		if not m or m.Finished or m.Leaver ~= p or m.LeaverHandled then
			return
		end
		m.LeaverHandled = true
		local opp = other(m, p)
		Results.apply(profile, {
			Won = false,
			Mode = m.Mode,
			OppElo = m.StartElo[opp],
			Leaver = true,
			Reward = 0,
		})
	end)
	game:BindToClose(function()
		OfflinePenalty.flush()
	end)
end

return MatchService
