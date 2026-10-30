--!strict
-- Pont vers CombatService (équipe Combat). Chaque appel est protégé par pcall.
-- Si CombatService est absent, un repli minimal permet de tester le déroulé : placement aux spawns, gel,
-- fin de round à la mort du Humanoid ou sous KillY.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Deps = require(script.Parent.Deps)
local ArenaAllocator = require(script.Parent.ArenaAllocator)

local CombatBridge = {}

local roundEnded = Instance.new("BindableEvent") -- (matchId, winner, loser) du repli

type FallbackDuel = { A: Player, B: Player, Arena: Model, Conns: { RBXScriptConnection }, Ended: boolean }
local fallback: { [string]: FallbackDuel } = {}
-- Matchs où un appel à CombatService a échoué : la suite du duel bascule sur le repli.
type Pair = { A: Player, B: Player, Arena: Model }
local pairs_: { [string]: Pair } = {}
local degraded: { [string]: boolean } = {}

local function combat(): any?
	local c = Deps.get("CombatService")
	if c and type(c.beginDuel) == "function" then
		return c
	end
	return nil
end

-- Retourne true si CombatService a traité l'appel. false = le repli doit prendre le relais
-- (CombatService absent, match déjà dégradé, ou erreur pendant l'appel).
local function call(name: string, matchId: string, ...: any): boolean
	local c = combat()
	if not c or degraded[matchId] then
		return false
	end
	local fn = c[name]
	if type(fn) ~= "function" then
		warn("[EtherBlades] CombatService." .. name .. " absent")
		return true
	end
	local ok, err = pcall(fn, matchId, ...)
	if not ok then
		warn(string.format("[EtherBlades] CombatService.%s : %s (bascule sur le repli)", name, tostring(err)))
		degraded[matchId] = true
		return false
	end
	return true
end

local function rootOf(p: Player): BasePart?
	local char = p.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function place(p: Player, spawnPart: BasePart?, anchored: boolean)
	local char = p.Character
	local root = rootOf(p)
	if not char or not root or not spawnPart then
		return
	end
	Deps.allowMovement(p, 3)
	Deps.teleport(p, spawnPart.CFrame + Vector3.new(0, 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = anchored
end

local function clearConns(d: FallbackDuel)
	for _, c in d.Conns do
		c:Disconnect()
	end
	table.clear(d.Conns)
end

function CombatBridge.hasCombat(): boolean
	return combat() ~= nil
end

local function ensureFallback(matchId: string): FallbackDuel?
	local d = fallback[matchId]
	if d then
		return d
	end
	local pr = pairs_[matchId]
	if not pr then
		return nil
	end
	d = { A = pr.A, B = pr.B, Arena = pr.Arena, Conns = {}, Ended = false }
	fallback[matchId] = d
	for _, p in { pr.A, pr.B } do
		local char = p.Character
		if char then
			char:SetAttribute("InDuel", true)
		end
	end
	return d
end

function CombatBridge.beginDuel(matchId: string, a: Player, b: Player, arena: Model)
	pairs_[matchId] = { A = a, B = b, Arena = arena }
	if call("beginDuel", matchId, a, b, arena) then
		return
	end
	fallback[matchId] = { A = a, B = b, Arena = arena, Conns = {}, Ended = false }
	for _, p in { a, b } do
		local char = p.Character
		if char then
			char:SetAttribute("InDuel", true)
		end
	end
	place(a, ArenaAllocator.part(arena, "SpawnA"), true)
	place(b, ArenaAllocator.part(arena, "SpawnB"), true)
end

function CombatBridge.playIntro(matchId: string)
	if call("playIntro", matchId) then
		return
	end
	task.wait(3)
end

function CombatBridge.startRound(matchId: string)
	if call("startRound", matchId) then
		return
	end
	local d = ensureFallback(matchId)
	if not d then
		return
	end
	clearConns(d)
	d.Ended = false
	local killPart = ArenaAllocator.part(d.Arena, "KillY")
	local killY = if killPart then killPart.Position.Y else -math.huge
	local function finish(loser: Player)
		if d.Ended then
			return
		end
		d.Ended = true
		local winner = if loser == d.A then d.B else d.A
		roundEnded:Fire(matchId, winner, loser)
	end
	for _, p in { d.A, d.B } do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
			table.insert(d.Conns, hum.Died:Connect(function()
				finish(p)
			end))
		end
		place(p, ArenaAllocator.part(d.Arena, if p == d.A then "SpawnA" else "SpawnB"), false)
	end
	table.insert(d.Conns, RunService.Heartbeat:Connect(function()
		for _, p in { d.A, d.B } do
			local r = rootOf(p)
			if r and r.Position.Y < killY then
				finish(p)
			end
		end
	end))
end

function CombatBridge.playFinisher(matchId: string, winner: Player, loser: Player)
	if call("playFinisher", matchId, winner, loser) then
		return
	end
	task.wait(1.5)
end

function CombatBridge.endDuel(matchId: string)
	-- CombatService nettoie même un match dégradé ; le repli nettoie ensuite ce qui lui appartient.
	local c = combat()
	if c and type(c.endDuel) == "function" then
		local ok, err = pcall(c.endDuel, matchId)
		if not ok then
			warn(string.format("[EtherBlades] CombatService.endDuel : %s", tostring(err)))
		end
	end
	pairs_[matchId] = nil
	degraded[matchId] = nil
	local d = fallback[matchId]
	if not d then
		return
	end
	clearConns(d)
	fallback[matchId] = nil
	for _, p in { d.A, d.B } do
		local char = p.Character
		if char then
			char:SetAttribute("InDuel", false)
		end
		local r = rootOf(p)
		if r then
			r.Anchored = false
		end
	end
end

-- Abonnement à la fin de round (CombatService.RoundEnded ou repli).
-- Retourne un objet possédant :Disconnect() (RBXScriptConnection ou connexion d'un signal maison).
-- Écoute aussi le repli : un match dégradé en cours de route y signale ses fins de round.
function CombatBridge.onRoundEnded(fn: (string, Player, Player) -> ()): { Disconnect: (any) -> () }
	local conns: { any } = { roundEnded.Event:Connect(fn) }
	local c = combat()
	if c then
		local sig = c.RoundEnded
		if typeof(sig) == "RBXScriptSignal" then
			table.insert(conns, (sig :: RBXScriptSignal):Connect(fn))
		elseif type(sig) == "table" and type(sig.Connect) == "function" then
			table.insert(conns, sig:Connect(fn))
		else
			warn("[EtherBlades] CombatService.RoundEnded absent : fins de round détectées par le repli uniquement")
		end
	end
	return {
		Disconnect = function(_self: any)
			for _, k in conns do
				k:Disconnect()
			end
			table.clear(conns)
		end,
	}
end

Players.PlayerRemoving:Connect(function(p: Player)
	for id, d in fallback do
		if d.A == p or d.B == p then
			clearConns(d)
			fallback[id] = nil
		end
	end
end)

return CombatBridge
