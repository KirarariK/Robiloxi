--!strict
-- Seau à jetons par joueur et par clé : protège chaque remote contre le spam.
-- Une seule connexion PlayerRemoving partagée par tous les limiteurs (pas de fuite si on en crée beaucoup).
local Players = game:GetService("Players")

type Bucket = { Tokens: number, Last: number }

export type Limiter = {
	Allow: (self: Limiter, player: Player) -> boolean,
	Destroy: (self: Limiter) -> (),
}

type LimiterImpl = {
	_rate: number,
	_burst: number,
	_buckets: { [Player]: Bucket },
}

local limiters: { [LimiterImpl]: boolean } = {}

Players.PlayerRemoving:Connect(function(p: Player)
	for l in limiters do
		l._buckets[p] = nil
	end
end)

local RateLimiter = {}
RateLimiter.__index = RateLimiter

-- `rate` jetons par seconde (> 0), rafale maximale `burst` (>= 1).
function RateLimiter.new(rate: number, burst: number): Limiter
	assert(rate > 0 and rate == rate, "RateLimiter : rate invalide")
	assert(burst >= 1 and burst == burst, "RateLimiter : burst invalide")
	local impl: LimiterImpl = { _rate = rate, _burst = burst, _buckets = {} }
	limiters[impl] = true
	return (setmetatable(impl :: any, RateLimiter) :: any) :: Limiter
end

function RateLimiter.Allow(self: Limiter, player: Player): boolean
	local impl = (self :: any) :: LimiterImpl
	if player.Parent == nil then
		return false -- joueur parti : ne pas recréer de seau
	end
	local now = os.clock()
	local b = impl._buckets[player]
	if not b then
		b = { Tokens = impl._burst, Last = now }
		impl._buckets[player] = b
	end
	local bucket = b :: Bucket
	bucket.Tokens = math.min(impl._burst, bucket.Tokens + (now - bucket.Last) * impl._rate)
	bucket.Last = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

function RateLimiter.Destroy(self: Limiter)
	local impl = (self :: any) :: LimiterImpl
	limiters[impl] = nil
	table.clear(impl._buckets)
end

return RateLimiter
