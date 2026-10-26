--!strict
--[[
	Quêtes journalières + factions + event week-end — GDD §5.
]]

export type FactionId = "Dawn" | "Dusk" -- Ordre de l'Aube / Voie du Crépuscule

local QuestConfig = {
	Factions = {
		Dawn = {
			id = "Dawn",
			displayName = "Ordre de l'Aube",
			bannerColor = Color3.fromRGB(240, 210, 140),
		},
		Dusk = {
			id = "Dusk",
			displayName = "Voie du Crépuscule",
			bannerColor = Color3.fromRGB(90, 60, 140),
		},
	},

	DailyQuests = {
		{
			id = "wins_2",
			displayName = "Remporter 2 duels",
			stat = "wins",
			target = 2,
			rewardCredits = 80,
		},
		{
			id = "perfects_5",
			displayName = "Réussir 5 parades parfaites",
			stat = "perfects",
			target = 5,
			rewardCredits = 80,
		},
		{
			id = "heavy_damage_300",
			displayName = "Infliger 300 dégâts lourds",
			stat = "heavyDamage",
			target = 300,
			rewardCredits = 80,
		},
		{
			id = "arena_obsidian",
			displayName = "Jouer 1 match à Obsidian Pit",
			stat = "arenaObsidian",
			target = 1,
			rewardCredits = 60,
		},
	},

	WeekendEvent = {
		id = "weekend_double_credits",
		displayName = "Week-end Double Crédits",
		creditMultiplier = 2,
		-- Stub : actif si os.date("%w") in {0,5,6} côté serveur
		activeWeekdays = { [0] = true, [5] = true, [6] = true },
	},
}

return QuestConfig
