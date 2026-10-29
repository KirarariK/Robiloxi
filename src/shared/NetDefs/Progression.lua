--!strict
-- Remotes Progression : relances, équipement, boutique de cristaux de lame, classements, emotes.
return {
	ClientEvents = {
		"PlayEmote", -- (emoteId: string) demande de lecture d'une emote équipée
		"StopEmote", -- () arrêt de l'emote en cours
	} :: { string },
	ServerEvents = {
		"EmotePlayed", -- (player: Player, emoteId: string) diffusée à tous
		"EmoteStopped", -- (player: Player)
		"LeaderboardData", -- (data: LeaderboardSnapshot) poussé à chaque rafraîchissement (60 s)
	} :: { string },
	Functions = {
		"Reroll", -- () -> Result { FormId, Duplicate, Refund, Pity, Crystals }
		"Equip", -- (kind: string, id: string, slot: number?) -> Result
		"BuyColor", -- (colorId: string) -> Result
		"GetLeaderboard", -- () -> Result LeaderboardSnapshot
	} :: { string },
}
