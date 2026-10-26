--!strict
--[[
	Formes de combat + gacha — GDD §3.
	Lexique live : Astra / Duelant / Aegis / Zephyr.
]]

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"
export type FormId = "Astra" | "Duelant" | "Aegis" | "Zephyr"

export type FormDef = {
	id: FormId,
	displayName: string,
	tempo: string,
	passives: {
		Common: string,
		Rare: string,
		Epic: string,
		Legendary: string,
	},
	-- multiplicateurs soft (stats) — jamais HP max / dégâts plats > 8 %
	statMods: {
		[Rarity]: {
			staminaRegenMult: number?,
			riposteDamageMult: number?,
			guardDrainMult: number?,
			dodgeCostMult: number?,
			perfectWindowBonus: number?,
			chipTakenMult: number?,
			focusDashCdBonus: number?,
		},
	},
}

local FormConfig = {
	PityEpic = 40,
	PityLegendary = 90,

	DropRates = {
		Common = 0.62,
		Rare = 0.26,
		Epic = 0.10,
		Legendary = 0.02,
	},

	-- Ranked : passifs capped Rare ; Épique/Légendaire = cosmetics-only
	RankedMaxRarityForStats = "Rare" :: Rarity,

	RarityOrder = { "Common", "Rare", "Epic", "Legendary" } :: { Rarity },

	Forms = {
		Astra = {
			id = "Astra",
			displayName = "Astra",
			tempo = "Neutre",
			passives = {
				Common = "+3 % regen stamina",
				Rare = "+5 % regen stamina",
				Epic = "Après clash, +8 stamina",
				Legendary = "Flux : 1×/round, première légère après perfect = +15 %",
			},
			statMods = {
				Common = { staminaRegenMult = 1.03 },
				Rare = { staminaRegenMult = 1.05 },
				Epic = { staminaRegenMult = 1.05 }, -- Unique handled in FormService
				Legendary = { staminaRegenMult = 1.05 },
			},
		} :: FormDef,
		Duelant = {
			id = "Duelant",
			displayName = "Duelant",
			tempo = "Contrôle",
			passives = {
				Common = "+4 % dégâts riposte",
				Rare = "Fenêtre perfect +15 ms",
				Epic = "Chip guard −10 % subi",
				Legendary = "Lame fine : lourde non clashable de face",
			},
			statMods = {
				Common = { riposteDamageMult = 1.04 },
				Rare = { riposteDamageMult = 1.04, perfectWindowBonus = 0.015 },
				Epic = { riposteDamageMult = 1.04, perfectWindowBonus = 0.015, chipTakenMult = 0.90 },
				Legendary = { riposteDamageMult = 1.04, perfectWindowBonus = 0.015, chipTakenMult = 0.90 },
			},
		} :: FormDef,
		Aegis = {
			id = "Aegis",
			displayName = "Aegis",
			tempo = "Tank soft",
			passives = {
				Common = "Guard drain −8 %",
				Rare = "Chip reçu −12 %",
				Epic = "Guard break resist +0,15 s",
				Legendary = "Mur : 1×/match, absorbe un hit lourd",
			},
			statMods = {
				Common = { guardDrainMult = 0.92 },
				Rare = { guardDrainMult = 0.92, chipTakenMult = 0.88 },
				Epic = { guardDrainMult = 0.92, chipTakenMult = 0.88 },
				Legendary = { guardDrainMult = 0.92, chipTakenMult = 0.88 },
			},
		} :: FormDef,
		Zephyr = {
			id = "Zephyr",
			displayName = "Zephyr",
			tempo = "Rush",
			passives = {
				Common = "Esquive −8 % coût",
				Rare = "I-frames esquive +20 ms",
				Epic = "Dash Focus −1,5 s CD",
				Legendary = "Rafale : double sidestep 1×/round",
			},
			statMods = {
				Common = { dodgeCostMult = 0.92 },
				Rare = { dodgeCostMult = 0.92 },
				Epic = { dodgeCostMult = 0.92, focusDashCdBonus = -1.5 },
				Legendary = { dodgeCostMult = 0.92, focusDashCdBonus = -1.5 },
			},
		} :: FormDef,
	} :: { [FormId]: FormDef },

	SeasonFreeForms = { "Astra", "Duelant" } :: { FormId }, -- Ranked free pool
}

return FormConfig
