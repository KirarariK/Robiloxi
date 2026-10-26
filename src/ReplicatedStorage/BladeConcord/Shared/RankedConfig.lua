--!strict
--[[
	Ranked MMR / ELO — GDD §5.1. Soft reset saison 8–10 semaines.
]]

export type RankId =
	"Bronze"
	| "Silver"
	| "Gold"
	| "Platinum"
	| "Diamond"
	| "Master"
	| "Grandmaster"

local RankedConfig = {
	StartingMMR = 1000,
	KFactor = 32,
	SeasonWeeks = 9,
	DodgePenaltyMMR = 15,

	Ranks = {
		{ id = "Bronze" :: RankId, minMmr = 0 },
		{ id = "Silver" :: RankId, minMmr = 800 },
		{ id = "Gold" :: RankId, minMmr = 1000 },
		{ id = "Platinum" :: RankId, minMmr = 1200 },
		{ id = "Diamond" :: RankId, minMmr = 1400 },
		{ id = "Master" :: RankId, minMmr = 1600 },
		{ id = "Grandmaster" :: RankId, minMmr = 1800 },
	},

	FairKitBadge = "Fair Kit",
	FairKitStatsLabel = "STATS: RARE CAP",
}

function RankedConfig.rankFromMmr(mmr: number): RankId
	local current: RankId = "Bronze"
	for _, row in RankedConfig.Ranks do
		if mmr >= row.minMmr then
			current = row.id
		end
	end
	return current
end

return RankedConfig
