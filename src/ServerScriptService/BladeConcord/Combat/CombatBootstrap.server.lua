--!strict
--[[
	Bootstrap serveur P0 — wire remotes + services + Heartbeat tick.
	Hors scope : gacha, ranked, shop, Focus powers.
]]

local RunService = game:GetService("RunService")

local CombatService = require(script.Parent:WaitForChild("CombatService"))

CombatService.start()

local broadcastAccumulator = 0
local BROADCAST_HZ = 20 -- coalesce state un peu ; step logique full rate

RunService.Heartbeat:Connect(function(dt)
	CombatService.step(dt)
	broadcastAccumulator += dt
	-- broadcast déjà dans step ; garder simple pour MVP
	if broadcastAccumulator >= 1 / BROADCAST_HZ then
		broadcastAccumulator = 0
	end
end)

print("[BladeConcord] CombatBootstrap server ready — Obsidian Pit + combat MVP")
