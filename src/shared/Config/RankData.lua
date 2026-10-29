--!strict
-- Rangs classés, calcul Elo et formats de match.
local Types = require(script.Parent.Parent.Types)

type RankTier = Types.RankTier

local rgb = Color3.fromRGB

local TIERS: { RankTier } = {
	{ Id = "Initie", Name = "Initié", MinElo = 0, Color = rgb(170, 176, 186) },
	{ Id = "Apprenti", Name = "Apprenti", MinElo = 1100, Color = rgb(110, 200, 140) },
	{ Id = "Chevalier", Name = "Chevalier", MinElo = 1300, Color = rgb(72, 156, 255) },
	{ Id = "Maitre", Name = "Maître", MinElo = 1550, Color = rgb(176, 92, 255) },
	{ Id = "Archonte", Name = "Archonte", MinElo = 1800, Color = rgb(255, 120, 60) },
	{ Id = "GrandMaitre", Name = "Grand Maître", MinElo = 2000, Color = rgb(255, 196, 40), TopOnly = 50 },
}

for _, t in TIERS do
	table.freeze(t)
end

local RankData = {}

RankData.Tiers = table.freeze(TIERS)
RankData.StartElo = 1000
RankData.MinElo = 100
RankData.LeavePenalty = 25 -- Elo retiré en plus de la défaite en cas d'abandon
RankData.LeaveCooldown = 120 -- s avant de pouvoir relancer une file classée après un abandon
RankData.PlacementMatches = 5

-- BO3 en non-classé, BO5 en classé
RankData.Formats = table.freeze({
	Ranked = table.freeze({ RoundsToWin = 3 }),
	Casual = table.freeze({ RoundsToWin = 2 }),
	Challenge = table.freeze({ RoundsToWin = 2 }),
})

-- K dynamique : placement (gros mouvements) → standard → haut niveau (stable).
function RankData.kFactor(elo: number, played: number): number
	if played < RankData.PlacementMatches then
		return 48
	elseif elo >= 1800 then
		return 20
	end
	return 32
end

function RankData.expected(a: number, b: number): number
	return 1 / (1 + 10 ^ ((b - a) / 400))
end

-- Retourne le delta Elo (arrondi) pour le joueur A selon le score (1 victoire, 0 défaite).
function RankData.delta(eloA: number, eloB: number, scoreA: number, playedA: number): number
	local k = RankData.kFactor(eloA, playedA)
	return math.round(k * (scoreA - RankData.expected(eloA, eloB)))
end

-- Rang affiché ; `worldRank` = position mondiale (nil si inconnue).
function RankData.tierFor(elo: number, worldRank: number?): RankTier
	local best = TIERS[1]
	for _, t in TIERS do
		if elo >= t.MinElo then
			if t.TopOnly == nil or (worldRank ~= nil and worldRank <= t.TopOnly) then
				best = t
			end
		end
	end
	return best
end

return table.freeze(RankData)
