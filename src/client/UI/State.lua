--!strict
-- État client partagé entre contrôleurs : duel en cours, file d'attente, classements.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("EtherBlades"):WaitForChild("Net"))

export type MatchView = {
	Active: boolean,
	MatchId: string?,
	Mode: string?,
	Phase: string?,
	Round: number?,
	RoundsToWin: number?,
	MyScore: number?,
	OppScore: number?,
	OpponentUserId: number?,
	OpponentName: string?,
	ArenaId: string?,
	ArenaName: string?,
	RoundEndsAt: number?,
	LastRoundWinnerUserId: number?,
	WinnerUserId: number?,
	Forfeit: boolean?,
}

local State = {}

local matchChanged = Instance.new("BindableEvent")
local queueChanged = Instance.new("BindableEvent")
local boardChanged = Instance.new("BindableEvent")
local resultEvent = Instance.new("BindableEvent")

State.MatchChanged = matchChanged.Event -- (view, previous)
State.QueueChanged = queueChanged.Event -- (queue)
State.LeaderboardChanged = boardChanged.Event -- (snapshot)
State.MatchResult = resultEvent.Event -- (result)

State.match = { Active = false } :: MatchView
State.queue = { InQueue = false } :: { [string]: any }
State.leaderboard = nil :: { [string]: any }?

local started = false

function State.inDuel(): boolean
	return State.match.Active == true
end

function State.init()
	if started then
		return
	end
	started = true
	Net.event("MatchState").OnClientEvent:Connect(function(view: any)
		if type(view) ~= "table" then
			return
		end
		local prev = State.match
		State.match = view :: MatchView
		matchChanged:Fire(State.match, prev)
	end)
	Net.event("QueueState").OnClientEvent:Connect(function(q: any)
		if type(q) ~= "table" then
			return
		end
		State.queue = q
		queueChanged:Fire(q)
	end)
	Net.event("LeaderboardData").OnClientEvent:Connect(function(snap: any)
		if type(snap) ~= "table" then
			return
		end
		State.leaderboard = snap
		boardChanged:Fire(snap)
	end)
	Net.event("MatchResult").OnClientEvent:Connect(function(r: any)
		if type(r) == "table" then
			resultEvent:Fire(r)
		end
	end)
end

function State.setLeaderboard(snap: { [string]: any })
	State.leaderboard = snap
	boardChanged:Fire(snap)
end

return State
