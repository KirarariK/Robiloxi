--!strict
--[[
	MMR / ELO basique + modes Casual vs Ranked.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))
local PlayerDataService = require(script.Parent.Parent.Data:WaitForChild("PlayerDataService"))
local FormService = require(script.Parent:WaitForChild("FormService"))

local RankedService = {}

local function expectedScore(mmrA: number, mmrB: number): number
	return 1 / (1 + 10 ^ ((mmrB - mmrA) / 400))
end

function RankedService.applyMatchResult(winner: Player, loser: Player, mode: string)
	if mode ~= "Ranked" then
		FormService.applyToFighter(winner, "Casual")
		FormService.applyToFighter(loser, "Casual")
		return
	end

	local wProfile = PlayerDataService.get(winner)
	local lProfile = PlayerDataService.get(loser)
	if not wProfile or not lProfile then
		return
	end

	local k = RankedConfig.KFactor
	local expW = expectedScore(wProfile.mmr, lProfile.mmr)
	local expL = expectedScore(lProfile.mmr, wProfile.mmr)
	wProfile.mmr = math.max(0, math.floor(wProfile.mmr + k * (1 - expW) + 0.5))
	lProfile.mmr = math.max(0, math.floor(lProfile.mmr + k * (0 - expL) + 0.5))

	PlayerDataService.save(winner)
	PlayerDataService.save(loser)

	FormService.applyToFighter(winner, "Ranked")
	FormService.applyToFighter(loser, "Ranked")
end

function RankedService.prepareFighters(players: { Player }, mode: string)
	for _, p in players do
		FormService.applyToFighter(p, mode)
	end
end

function RankedService.rankLabel(mmr: number): string
	return RankedConfig.rankFromMmr(mmr)
end

return RankedService
