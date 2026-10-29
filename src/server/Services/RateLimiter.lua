--!strict
-- Seau à jetons par joueur et par clé : protège chaque remote contre le spam.
local Players = game:GetService("Players")

export type Limiter = {
	Allow: (self: Limiter, player: Player) -> boolean,
}

type Bucket = { Tokens: number, Last: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

-- `rate` jetons par seconde, rafale maximale `burst`.
function RateLimiter.new(rate: number, burst: number): Limiter
	local buckets: { [Player]: Bucket } = {}
	local self = setmetatable({ _rate = rate, _burst = burst, _buckets = buckets }, RateLimiter)
	Players.PlayerRemoving:Connect(function(p: Player)
		buckets[p] = nil
	end)
	return (self :: any) :: Limiter
end

function RateLimiter.Allow(self: any, player: Player): boolean
	local now = os.clock()
	local b: Bucket? = self._buckets[player]
	if not b then
		local nb: Bucket = { Tokens = self._burst, Last = now }
		self._buckets[player] = nb
		b = nb
	end
	local bucket = b :: Bucket
	bucket.Tokens = math.min(self._burst, bucket.Tokens + (now - bucket.Last) * self._rate)
	bucket.Last = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

return RateLimiter
