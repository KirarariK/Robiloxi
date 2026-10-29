--!strict
-- Application pure (sans yield) du résultat d'un duel à un profil : Elo (classé), PeakElo, RankedPlayed,
-- victoires / défaites, séries, maîtrise de Voie, Cristaux, pénalité d'abandon.
-- Utilisée aussi bien sur la session en ligne (DataService.update) que sur un profil hors ligne (UpdateAsync).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RankData = require(ReplicatedStorage:WaitForChild("EtherBlades").Config.RankData)

export type Outcome = {
	Won: boolean,
	Mode: string,
	OppElo: number,
	Leaver: boolean,
	Reward: number,
}

export type Summary = {
	EloBefore: number,
	EloAfter: number,
	EloDelta: number,
	Reward: number,
	MasteryForm: string?,
	MasteryValue: number?,
	WinStreak: number,
	PenaltyUntil: number?,
}

local Results = {}

local function num(v: any, default: number): number
	return if type(v) == "number" and v == v then v else default
end

function Results.apply(profile: any, o: Outcome): Summary
	local p = profile
	local eloBefore = num(p.Elo, RankData.StartElo)
	local elo = eloBefore
	if o.Mode == "Ranked" then
		local played = num(p.RankedPlayed, 0)
		local d = RankData.delta(elo, o.OppElo, if o.Won then 1 else 0, played)
		if o.Leaver then
			d -= RankData.LeavePenalty
		end
		elo = math.max(RankData.MinElo, elo + d)
		p.Elo = elo
		p.RankedPlayed = played + 1
		p.PeakElo = math.max(num(p.PeakElo, elo), elo)
	end
	local masteryForm: string? = nil
	local masteryValue: number? = nil
	if o.Won then
		p.Wins = num(p.Wins, 0) + 1
		p.WinStreak = num(p.WinStreak, 0) + 1
		p.BestStreak = math.max(num(p.BestStreak, 0), p.WinStreak)
		if type(p.EquippedForm) == "string" and type(p.FormMastery) == "table" then
			masteryForm = p.EquippedForm
			masteryValue = num(p.FormMastery[p.EquippedForm], 0) + 1
			p.FormMastery[p.EquippedForm] = masteryValue
		end
	else
		p.Losses = num(p.Losses, 0) + 1
		p.WinStreak = 0
	end
	local penaltyUntil: number? = nil
	if o.Leaver then
		penaltyUntil = os.time() + RankData.LeaveCooldown
		p.LeavePenaltyUntil = penaltyUntil
	end
	p.Crystals = num(p.Crystals, 0) + o.Reward
	return {
		EloBefore = eloBefore,
		EloAfter = elo,
		EloDelta = elo - eloBefore,
		Reward = o.Reward,
		MasteryForm = masteryForm,
		MasteryValue = masteryValue,
		WinStreak = num(p.WinStreak, 0),
		PenaltyUntil = penaltyUntil,
	}
end

return Results
