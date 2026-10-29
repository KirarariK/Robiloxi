--!strict
-- Remotes de l'équipe Combat.
return {
	ClientEvents = {
		-- intention de combat : (action: string, dir: Vector3?, clientTime: number?, seq: number?)
		-- action ∈ { Light, Heavy, BlockStart, BlockEnd, Parry, Dodge } ; le serveur valide tout
		"CombatInput",
	},
	ServerEvents = {
		"CombatAnim", -- (model: Model, clipId: string, speed: number) : animation jouée par un combattant
		"CombatFx", -- (kind: string, data: table) : impact, garde, parade, bris de garde, esquive, KO…
		"CombatImpulse", -- (velocity: Vector3, duration: number) : poussée appliquée par le client propriétaire
		"CombatReject", -- (action: string, reason: string, seq: number?) : intention refusée → annule la prédiction
		"CombatSaberLock", -- (a: Model, b: Model, point: Vector3, duration: number)
		"CombatCinematic", -- (kind: "Intro" | "Finisher", data: table)
	},
	Functions = {} :: { string },
}
