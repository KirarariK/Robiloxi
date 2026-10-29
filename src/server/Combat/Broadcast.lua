--!strict
-- Diffusion serveur → clients des événements de combat (animations, effets, poussées, refus, cinématiques).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("EtherBlades"):WaitForChild("Net"))
local State = require(script.Parent.State)

type Fighter = State.Fighter

local Broadcast = {}

-- Animation jouée par `f`. `skipOwner` : le client propriétaire l'a déjà prédite.
function Broadcast.anim(f: Fighter, clipId: string, speed: number, skipOwner: boolean)
	local remote = Net.event("CombatAnim")
	local owner = f.Player
	if skipOwner and owner then
		for _, p in Players:GetPlayers() do
			if p ~= owner then
				remote:FireClient(p, f.Model, clipId, speed)
			end
		end
	else
		remote:FireAllClients(f.Model, clipId, speed)
	end
end

function Broadcast.fx(kind: string, data: { [string]: any })
	Net.event("CombatFx"):FireAllClients(kind, data)
end

function Broadcast.impulse(player: Player, velocity: Vector3, duration: number)
	Net.event("CombatImpulse"):FireClient(player, velocity, duration)
end

function Broadcast.reject(player: Player?, action: string, reason: string, seq: number?)
	if player then
		Net.event("CombatReject"):FireClient(player, action, reason, seq)
	end
end

function Broadcast.saberLock(a: Fighter, b: Fighter, point: Vector3, duration: number)
	Net.event("CombatSaberLock"):FireAllClients(a.Model, b.Model, point, duration)
end

function Broadcast.cinematic(players: { Player }, kind: string, data: { [string]: any })
	local remote = Net.event("CombatCinematic")
	for _, p in players do
		if p.Parent then
			remote:FireClient(p, kind, data)
		end
	end
end

return Broadcast
