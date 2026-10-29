--!strict
-- Branche les handlers serveur derrière une limite de débit, une validation de types et un pcall.
-- Aucun handler ne fait confiance au client : tout argument est revérifié ici puis dans le service.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("EtherBlades"):WaitForChild("Net"))
local RateLimiter = require(script.Parent.RateLimiter)

export type Result = { Ok: boolean, Err: string?, Data: any? }

local Guard = {}

local function warnOnce(player: Player, name: string, msg: string)
	warn(string.format("[EtherBlades] %s → %s : %s", player.Name, name, msg))
end

-- Vérifie les arguments selon une liste de types Luau (« string », « number », « Vector3 », « nil? »…).
function Guard.checkArgs(args: { any }, spec: { string }): boolean
	if #args > #spec then
		return false
	end
	for i, expected in spec do
		local v = args[i]
		local optional = string.sub(expected, -1) == "?"
		local t = if optional then string.sub(expected, 1, -2) else expected
		if v == nil then
			if not optional then
				return false
			end
		elseif typeof(v) ~= t then
			return false
		elseif t == "number" and (v ~= v or v == math.huge or v == -math.huge) then
			return false -- NaN / infini
		elseif t == "string" and #v > 64 then
			return false
		end
	end
	return true
end

-- RemoteFunction protégée. `handler` renvoie un Result.
function Guard.func(name: string, spec: { string }, rate: number, burst: number, handler: (Player, ...any) -> Result)
	local limiter = RateLimiter.new(rate, burst)
	Net.func(name).OnServerInvoke = function(player: Player, ...: any): Result
		if not limiter:Allow(player) then
			return { Ok = false, Err = "Trop de requêtes, patiente un instant." }
		end
		local args = { ... }
		if not Guard.checkArgs(args, spec) then
			warnOnce(player, name, "arguments invalides")
			return { Ok = false, Err = "Requête invalide." }
		end
		local ok, res = pcall(handler, player, table.unpack(args, 1, #spec))
		if not ok then
			warn(string.format("[EtherBlades] erreur dans %s : %s", name, tostring(res)))
			return { Ok = false, Err = "Erreur serveur." }
		end
		return res
	end
end

-- RemoteEvent client → serveur protégé.
function Guard.event(name: string, spec: { string }, rate: number, burst: number, handler: (Player, ...any) -> ())
	local limiter = RateLimiter.new(rate, burst)
	Net.event(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter:Allow(player) then
			return
		end
		local args = { ... }
		if not Guard.checkArgs(args, spec) then
			warnOnce(player, name, "arguments invalides")
			return
		end
		local ok, err = pcall(handler, player, table.unpack(args, 1, #spec))
		if not ok then
			warn(string.format("[EtherBlades] erreur dans %s : %s", name, tostring(err)))
		end
	end)
end

return Guard
