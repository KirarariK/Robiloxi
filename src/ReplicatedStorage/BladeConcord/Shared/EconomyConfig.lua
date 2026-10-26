--!strict
--[[
	Économie & boutique — GDD §4. Cosmétiques only (premium = 0 stats).
]]

export type Currency = "ArenaCredits" | "FocusShards" | "FormFragments"

export type ShopItem = {
	id: string,
	displayName: string,
	category: "BladeColor" | "Hilt" | "Aura" | "Skin" | "Emote" | "Finisher",
	rarity: string,
	softPrice: number?, -- Crédits d'Arène
	premiumPrice: number?, -- Éclats Focus (stub Robux conversion)
	cosmeticOnly: boolean,
}

local EconomyConfig = {
	WinCredits = 120,
	LossCredits = 40,
	QuestCredits = 80,
	DailyLoginCredits = 50,

	-- Stub conversion : 1 Robux → N Éclats (jamais de secrets / product IDs hardcodés sensibles)
	FocusShardStubGrant = 100,

	Shop = {
		{
			id = "blade_azure",
			displayName = "Lame Azur",
			category = "BladeColor",
			rarity = "Common",
			softPrice = 800,
			cosmeticOnly = true,
		},
		{
			id = "blade_ember",
			displayName = "Lame Braise",
			category = "BladeColor",
			rarity = "Common",
			softPrice = 800,
			cosmeticOnly = true,
		},
		{
			id = "hilt_ironwood",
			displayName = "Manche Bois-fer",
			category = "Hilt",
			rarity = "Rare",
			softPrice = 4500,
			premiumPrice = 199,
			cosmeticOnly = true,
		},
		{
			id = "aura_eclipse",
			displayName = "Aura Éclipse",
			category = "Aura",
			rarity = "Epic",
			premiumPrice = 399,
			cosmeticOnly = true,
		},
		{
			id = "finisher_concord",
			displayName = "Finisher Concord",
			category = "Finisher",
			rarity = "Legendary",
			premiumPrice = 799,
			cosmeticOnly = true,
		},
		{
			id = "emote_salute",
			displayName = "Emote Salut de lame",
			category = "Emote",
			rarity = "Common",
			softPrice = 600,
			cosmeticOnly = true,
		},
		{
			id = "skin_dawn",
			displayName = "Tenue Aube",
			category = "Skin",
			rarity = "Rare",
			softPrice = 3200,
			cosmeticOnly = true,
		},
		{
			id = "skin_dusk",
			displayName = "Tenue Crépuscule",
			category = "Skin",
			rarity = "Rare",
			softPrice = 3200,
			cosmeticOnly = true,
		},
	} :: { ShopItem },

	BannerTenPullPremium = 450,
	BannerFreeTicketPerWeek = 1,

	-- Runtime visuals (SaberBuilder) — map itemId → couleur / aura
	CosmeticVisuals = {
		blade_azure = { kind = "blade", color = Color3.fromRGB(90, 190, 255) },
		blade_ember = { kind = "blade", color = Color3.fromRGB(255, 110, 45) },
		aura_eclipse = { kind = "aura", color = Color3.fromRGB(140, 90, 255) },
		hilt_ironwood = { kind = "hilt", wrapColor = Color3.fromRGB(72, 52, 36), ringColor = Color3.fromRGB(180, 150, 90) },
	} :: { [string]: { [string]: any } },
}

return EconomyConfig
