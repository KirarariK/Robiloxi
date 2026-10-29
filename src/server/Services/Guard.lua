--!strict
-- Branche les handlers serveur derrière une limite de débit, une validation stricte des arguments et un pcall.
-- Aucun handler ne fait confiance au client : tout argument est revérifié ici puis dans le service.
--
-- Spécification d'un argument : "string" | "number" | "boolean" | "Vector3" | "Vector2" | "CFrame",
-- suffixe « ? » = optionnel. Les tables et instances ne sont jamais acceptées depuis le client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("EtherBlades"):WaitForChild("Net"))
local RateLimiter = require(script.Parent.RateLimiter)

export type Result = { Ok: boolean, Err: string?, Data: any? }

local MAX_STRING = 64
local REFUSALS_BEFORE_FLAG = 20 -- refus (débit ou arguments) tolérés par minute avant signalement à l'anti-triche

local ALLOWED: { [string]: boolean } = {
	string = true,
	number = true,
	boolean = true,
	Vector3 = true,
	Vector2 = true,
	CFrame = true,
}

local Guard = {}

-- noms enregistrés, pour vérifier au démarrage que chaque remote a un handler
local registered: { [string]: boolean } = {}

-- limite globale toutes remotes confondues (en plus de la limite propre à chaque remote)
local globalLimiter = RateLimiter.new(60, 90)

local refusals: { [Player]: { Count: number, Since: number } } = {}
local lastLog: { [Player]: number } = {}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function onRefused(player: Player, name: string, msg: string)
	local now = os.clock()
	if (lastLog[player] or 0) + 2 < now then
		lastLog[player] = now
		warn(string.format("[EtherBlades] %s → %s : %s", player.Name, name, msg))
	end
	local r = refusals[player]
	if not r or now - r.Since > 60 then
		r = { Count = 0, Since = now }
		refusals[player] = r
	end
	local rr = r :: { Count: number, Since: number }
	rr.Count += 1
	if rr.Count == REFUSALS_BEFORE_FLAG then
		local mod = script.Parent:FindFirstChild("AntiExploit")
		if mod and mod:IsA("ModuleScript") then
			local ok, ae = pcall(require, mod)
			if ok and type(ae) == "table" and type((ae :: any).flag) == "function" then
				(ae :: any).flag(player, "remotes refusées en rafale (" .. name .. ")")
			end
		end
	end
end

game:GetService("Players").PlayerRemoving:Connect(function(p)
	refusals[p] = nil
	lastLog[p] = nil
end)

local function validValue(v: any, t: string): boolean
	if typeof(v) ~= t then
		return false
	end
	if t == "number" then
		return finite(v)
	elseif t == "string" then
		return #v <= MAX_STRING and utf8.len(v) ~= nil
	elseif t == "Vector3" then
		return finite(v.X) and finite(v.Y) and finite(v.Z)
	elseif t == "Vector2" then
		return finite(v.X) and finite(v.Y)
	elseif t == "CFrame" then
		local p, l = v.Position, v.LookVector
		return finite(p.X) and finite(p.Y) and finite(p.Z) and finite(l.X) and finite(l.Y) and finite(l.Z)
	end
	return true
end

-- Vérifie les arguments reçus (`n` = nombre réel d'arguments, trous compris).
function Guard.checkArgs(args: { any }, n: number, spec: { string }): boolean
	if n > #spec then
		return false
	end
	for i, expected in spec do
		local optional = string.sub(expected, -1) == "?"
		local t = if optional then string.sub(expected, 1, -2) else expected
		assert(ALLOWED[t], "Guard : type non autorisé dans la spec : " .. t)
		local v = args[i]
		if v == nil then
			if not optional then
				return false
			end
		elseif not validValue(v, t) then
			return false
		end
	end
	return true
end

local function register(name: string)
	assert(not registered[name], "Guard : handler déjà branché pour " .. name)
	registered[name] = true
end

-- RemoteFunction protégée. `handler` renvoie un Result.
function Guard.func(name: string, spec: { string }, rate: number, burst: number, handler: (Player, ...any) -> Result)
	register(name)
	local limiter = RateLimiter.new(rate, burst)
	Net.func(name).OnServerInvoke = function(player: Player, ...: any): Result
		if not globalLimiter:Allow(player) or not limiter:Allow(player) then
			onRefused(player, name, "débit dépassé")
			return { Ok = false, Err = "Trop de requêtes, patiente un instant." }
		end
		local n = select("#", ...)
		local args = { ... }
		if not Guard.checkArgs(args, n, spec) then
			onRefused(player, name, "arguments invalides")
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
	register(name)
	local limiter = RateLimiter.new(rate, burst)
	Net.event(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if not globalLimiter:Allow(player) or not limiter:Allow(player) then
			onRefused(player, name, "débit dépassé")
			return
		end
		local n = select("#", ...)
		local args = { ... }
		if not Guard.checkArgs(args, n, spec) then
			onRefused(player, name, "arguments invalides")
			return
		end
		local ok, err = pcall(handler, player, table.unpack(args, 1, #spec))
		if not ok then
			warn(string.format("[EtherBlades] erreur dans %s : %s", name, tostring(err)))
		end
	end)
end

-- Remotes client → serveur ou fonctions déclarées dans NetDefs mais sans handler (appelé après le démarrage).
function Guard.missingHandlers(): { string }
	local missing = {}
	for _, n in Net.ClientEvents do
		if not registered[n] then
			table.insert(missing, n)
		end
	end
	for _, n in Net.Functions do
		if not registered[n] then
			table.insert(missing, n)
		end
	end
	return missing
end

return Guard
