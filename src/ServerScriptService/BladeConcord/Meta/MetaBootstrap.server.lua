--!strict
--[[
	Bootstrap méta P3 : DataStores, formes, shop, ranked hooks, quêtes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local FormConfig = require(Shared:WaitForChild("FormConfig"))
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))

local DataStoreSafe = require(script.Parent.Parent.Data:WaitForChild("DataStoreSafe"))
local PlayerDataService = require(script.Parent.Parent.Data:WaitForChild("PlayerDataService"))
local FormService = require(script.Parent:WaitForChild("FormService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local RankedService = require(script.Parent:WaitForChild("RankedService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local MatchService = require(script.Parent.Parent.Match:WaitForChild("MatchService"))
local HitService = require(script.Parent.Parent.Combat:WaitForChild("HitService"))
local ArenaService = require(script.Parent.Parent.Combat:WaitForChild("ArenaService"))

PlayerDataService.start()
FormService.start()
ShopService.start()
QuestService.start()

Remotes.get()
Remotes.getMeta()

local function pushProfile(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		profile = PlayerDataService.load(player)
	end
	Remotes.getMeta().MetaState:FireClient(player, {
		kind = "Bootstrap",
		profile = PlayerDataService.toClientSnapshot(profile),
		catalog = EconomyConfig.Shop,
		forms = FormConfig.Forms,
		quests = QuestConfig.DailyQuests,
		factions = QuestConfig.Factions,
		warScore = QuestService.getWarScore(),
		weekend = QuestService.weekendSnapshot(),
		ranked = {
			fairKitBadge = RankedConfig.FairKitBadge,
			statsLabel = RankedConfig.FairKitStatsLabel,
		},
		dataStoreMock = DataStoreSafe.isMock(),
	})
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		task.wait(0.5)
		pushProfile(player)
		FormService.applyToFighter(player, "Casual")
	end)
end)
for _, player in Players:GetPlayers() do
	task.defer(function()
		pushProfile(player)
		FormService.applyToFighter(player, "Casual")
	end)
end

MatchService.setMatchEndHook(function(winner, loser, mode)
	if winner and loser then
		RankedService.applyMatchResult(winner, loser, mode)
	end
	local mult = QuestService.creditMultiplier()
	if winner then
		ShopService.grantWinRewards(winner, true, mult)
		QuestService.track(winner, "wins", 1)
		QuestService.addWarScore(winner, 10)
		if ArenaService.getActiveId() == "ObsidianPit" then
			QuestService.track(winner, "arenaObsidian", 1)
		end
		pushProfile(winner)
	end
	if loser then
		ShopService.grantWinRewards(loser, false, mult)
		if ArenaService.getActiveId() == "ObsidianPit" then
			QuestService.track(loser, "arenaObsidian", 1)
		end
		pushProfile(loser)
	end
end)

HitService.setDamageHook(function(attacker, _defender, damage, isHeavy)
	if damage > 0 and isHeavy then
		QuestService.track(attacker.player, "heavyDamage", damage)
	end
end)

HitService.setPerfectHook(function(defender)
	QuestService.track(defender.player, "perfects", 1)
end)

local lastPhase = ""
RunService.Heartbeat:Connect(function()
	local phase = MatchService.getPhase()
	if phase == "Countdown" and lastPhase ~= "Countdown" then
		local mode = MatchService.getMode()
		for _, player in Players:GetPlayers() do
			RankedService.prepareFighters({ player }, mode)
		end
	end
	lastPhase = phase
end)

print(
	"[BladeConcord] MetaBootstrap ready — formes, shop, ranked, quêtes, DataStore"
		.. (if DataStoreSafe.isMock() then " (MOCK Studio)" else "")
)
