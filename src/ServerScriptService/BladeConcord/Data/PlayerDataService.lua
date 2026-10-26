--!strict
--[[
	Profil joueur : monnaies, loadout cosmétique, formes, MMR, quêtes, faction.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local FormConfig = require(Shared:WaitForChild("FormConfig"))
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))
local DataStoreSafe = require(script.Parent:WaitForChild("DataStoreSafe"))

local STORE_NAME = "BladeConcord_Player_v1"

export type OwnedForm = {
	formId: string,
	rarity: string,
	count: number,
}

export type QuestProgress = {
	id: string,
	progress: number,
	claimed: boolean,
}

export type PlayerProfile = {
	credits: number,
	shards: number,
	fragments: number,
	mmr: number,
	faction: string?, -- Dawn | Dusk
	equippedFormId: string,
	equippedFormRarity: string,
	ownedForms: { OwnedForm },
	ownedCosmetics: { string },
	equippedCosmetics: {
		bladeColor: string?,
		hilt: string?,
		aura: string?,
		skin: string?,
		emote: string?,
		finisher: string?,
	},
	pityEpic: number,
	pityLegendary: number,
	bannerPulls: number,
	freeTicketWeek: number, -- os.date("%W") last claimed
	dailyQuests: { QuestProgress },
	questDayKey: string,
	stats: {
		wins: number,
		perfects: number,
		heavyDamage: number,
		arenaObsidian: number,
	},
	warScoreContribution: number,
}

local PlayerDataService = {}
local profiles: { [Player]: PlayerProfile } = {}

local function dayKey(): string
	return os.date("%Y-%m-%d") :: string
end

local function freshQuests(): { QuestProgress }
	local list = {}
	for _, q in QuestConfig.DailyQuests do
		table.insert(list, { id = q.id, progress = 0, claimed = false })
	end
	return list
end

local function defaultProfile(): PlayerProfile
	return {
		credits = 500,
		shards = 0,
		fragments = 0,
		mmr = RankedConfig.StartingMMR,
		faction = nil,
		equippedFormId = "Astra",
		equippedFormRarity = "Common",
		ownedForms = {
			{ formId = "Astra", rarity = "Common", count = 1 },
			{ formId = "Duelant", rarity = "Common", count = 1 },
		},
		ownedCosmetics = { "blade_azure" },
		equippedCosmetics = {
			bladeColor = "blade_azure",
			hilt = nil,
			aura = nil,
			skin = nil,
			emote = nil,
			finisher = nil,
		},
		pityEpic = 0,
		pityLegendary = 0,
		bannerPulls = 0,
		freeTicketWeek = 0,
		dailyQuests = freshQuests(),
		questDayKey = dayKey(),
		stats = {
			wins = 0,
			perfects = 0,
			heavyDamage = 0,
			arenaObsidian = 0,
		},
		warScoreContribution = 0,
	}
end

local function refreshDailyIfNeeded(profile: PlayerProfile)
	local today = dayKey()
	if profile.questDayKey ~= today then
		profile.questDayKey = today
		profile.dailyQuests = freshQuests()
		profile.stats.wins = 0
		profile.stats.perfects = 0
		profile.stats.heavyDamage = 0
		profile.stats.arenaObsidian = 0
		-- Soft daily login
		profile.credits += 50
	end
end

function PlayerDataService.get(player: Player): PlayerProfile?
	return profiles[player]
end

function PlayerDataService.load(player: Player): PlayerProfile
	local key = "u_" .. tostring(player.UserId)
	DataStoreSafe.tryLock(key)
	local data = DataStoreSafe.load(STORE_NAME, key, nil)
	local profile: PlayerProfile
	if typeof(data) == "table" then
		profile = data :: PlayerProfile
		-- fill missing defaults
		local d = defaultProfile()
		for k, v in d do
			if profile[k] == nil then
				(profile :: any)[k] = v
			end
		end
	else
		profile = defaultProfile()
	end
	refreshDailyIfNeeded(profile)
	profiles[player] = profile
	return profile
end

function PlayerDataService.save(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local key = "u_" .. tostring(player.UserId)
	return DataStoreSafe.save(STORE_NAME, key, profile)
end

function PlayerDataService.release(player: Player)
	PlayerDataService.save(player)
	local key = "u_" .. tostring(player.UserId)
	DataStoreSafe.unlock(key)
	profiles[player] = nil
end

function PlayerDataService.toClientSnapshot(profile: PlayerProfile): { [string]: any }
	return {
		credits = profile.credits,
		shards = profile.shards,
		fragments = profile.fragments,
		mmr = profile.mmr,
		rank = RankedConfig.rankFromMmr(profile.mmr),
		faction = profile.faction,
		equippedFormId = profile.equippedFormId,
		equippedFormRarity = profile.equippedFormRarity,
		ownedForms = profile.ownedForms,
		ownedCosmetics = profile.ownedCosmetics,
		equippedCosmetics = profile.equippedCosmetics,
		pityEpic = profile.pityEpic,
		pityLegendary = profile.pityLegendary,
		pityEpicAt = FormConfig.PityEpic,
		pityLegendaryAt = FormConfig.PityLegendary,
		dailyQuests = profile.dailyQuests,
		stats = profile.stats,
		dataStoreMock = DataStoreSafe.isMock(),
	}
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDataService.load(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.release(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerDataService.save(player)
		end
	end)
end

return PlayerDataService
