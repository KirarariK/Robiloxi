--!strict
--[[
	Quêtes journalières, factions Aube/Crépuscule, event week-end stub.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlayerDataService = require(script.Parent.Parent.Data:WaitForChild("PlayerDataService"))

local QuestService = {}

local factionWarScore = { Dawn = 0, Dusk = 0 }

function QuestService.isWeekendEventActive(): boolean
	local wday = tonumber(os.date("%w")) or 0
	return QuestConfig.WeekendEvent.activeWeekdays[wday] == true
end

function QuestService.creditMultiplier(): number
	if QuestService.isWeekendEventActive() then
		return QuestConfig.WeekendEvent.creditMultiplier
	end
	return 1
end

function QuestService.track(player: Player, stat: string, amount: number)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	if profile.stats[stat] ~= nil then
		profile.stats[stat] += amount
	end
	for _, q in profile.dailyQuests do
		local def = nil
		for _, d in QuestConfig.DailyQuests do
			if d.id == q.id then
				def = d
				break
			end
		end
		if def and def.stat == stat and not q.claimed then
			q.progress = math.min(def.target, profile.stats[stat])
		end
	end
end

function QuestService.claim(player: Player, questId: string): { [string]: any }
	local profile = PlayerDataService.get(player)
	if not profile then
		return { ok = false, error = "no_profile" }
	end
	for _, q in profile.dailyQuests do
		if q.id == questId then
			local def = nil
			for _, d in QuestConfig.DailyQuests do
				if d.id == questId then
					def = d
					break
				end
			end
			if not def then
				return { ok = false, error = "unknown" }
			end
			if q.claimed then
				return { ok = false, error = "already_claimed" }
			end
			if q.progress < def.target then
				return { ok = false, error = "incomplete" }
			end
			q.claimed = true
			local reward = math.floor(def.rewardCredits * QuestService.creditMultiplier())
			profile.credits += reward
			PlayerDataService.save(player)
			return { ok = true, credits = reward }
		end
	end
	return { ok = false, error = "not_found" }
end

function QuestService.selectFaction(player: Player, factionId: string): boolean
	if factionId ~= "Dawn" and factionId ~= "Dusk" then
		return false
	end
	local profile = PlayerDataService.get(player)
	if not profile then
		return false
	end
	-- Choix tutoriel : une fois
	if profile.faction ~= nil then
		return false
	end
	profile.faction = factionId
	PlayerDataService.save(player)
	return true
end

function QuestService.addWarScore(player: Player, amount: number)
	local profile = PlayerDataService.get(player)
	if not profile or not profile.faction then
		return
	end
	profile.warScoreContribution += amount
	factionWarScore[profile.faction] = (factionWarScore[profile.faction] or 0) + amount
end

function QuestService.getWarScore(): { Dawn: number, Dusk: number }
	return { Dawn = factionWarScore.Dawn, Dusk = factionWarScore.Dusk }
end

function QuestService.weekendSnapshot(): { [string]: any }
	return {
		active = QuestService.isWeekendEventActive(),
		id = QuestConfig.WeekendEvent.id,
		displayName = QuestConfig.WeekendEvent.displayName,
		creditMultiplier = QuestService.creditMultiplier(),
	}
end

function QuestService.start()
	local meta = Remotes.getMeta()
	meta.ClaimQuest.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		local result = QuestService.claim(player, tostring(payload.questId))
		meta.MetaState:FireClient(player, {
			kind = "QuestClaim",
			data = result,
			profile = PlayerDataService.toClientSnapshot(PlayerDataService.get(player)),
		})
	end)

	meta.SelectFaction.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		local ok = QuestService.selectFaction(player, tostring(payload.factionId))
		meta.MetaState:FireClient(player, {
			kind = "Faction",
			ok = ok,
			error = if ok then nil else (if PlayerDataService.get(player) and PlayerDataService.get(player).faction then "already_joined" else "failed"),
			profile = PlayerDataService.toClientSnapshot(PlayerDataService.get(player)),
			warScore = QuestService.getWarScore(),
			factions = QuestConfig.Factions,
		})
	end)
end

return QuestService
