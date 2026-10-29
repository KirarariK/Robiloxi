--!strict
-- Types internes du déroulé des matchs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maid = require(ReplicatedStorage:WaitForChild("EtherBlades").Util.Maid)

export type Mode = "Ranked" | "Casual" | "Challenge"

export type Phase = "Preparing" | "Intro" | "Round" | "RoundEnd" | "Finisher" | "Victory" | "Ended"

export type Match = {
	Id: string,
	Mode: Mode,
	A: Player,
	B: Player,
	Players: { Player },
	UserIds: { number },
	Names: { [Player]: string },
	Scores: { [Player]: number },
	StartElo: { [Player]: number },
	Round: number,
	RoundsToWin: number,
	Phase: Phase,
	ArenaId: string,
	ArenaName: string,
	Arena: Model?,
	RoundEndsAt: number,
	LastRoundWinner: Player?,
	Leaver: Player?,
	LeaverHandled: boolean, -- défaite d'abandon déjà appliquée à la session (DataService.onBeforeRelease)
	Winner: Player?,
	Loser: Player?,
	Finished: boolean,
	Reserved: boolean,
	Maid: Maid.Maid,
}

return {}
