--!strict
-- Remotes Match : files d'attente, défis directs, état du duel, écran de fin.
return {
	ClientEvents = {} :: { string },
	ServerEvents = {
		"MatchState", -- (state: MatchStateView) phase, scores, adversaire, arène, mode
		"MatchResult", -- (result: MatchResultView) écran de fin (Elo +/-, Cristaux, titres)
		"QueueState", -- (state: { InQueue: boolean, Mode: string?, Since: number?, Status: string? })
		"ChallengeReceived", -- ({ Id: string, FromUserId: number, FromName: string, Expires: number })
	} :: { string },
	Functions = {
		"JoinQueue", -- (mode: "Ranked" | "Casual") -> Result
		"LeaveQueue", -- () -> Result
		"ChallengePlayer", -- (targetUserId: number) -> Result
		"RespondChallenge", -- (challengeId: string, accept: boolean) -> Result
	} :: { string },
}
