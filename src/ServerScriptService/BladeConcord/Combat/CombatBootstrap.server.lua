--!strict
--[[
	Bootstrap serveur combat P0–P2 — remotes + services + Heartbeat.
	Méta P3 bootstrappée via Meta/MetaBootstrap.server.lua (script sibling tree).
]]

local RunService = game:GetService("RunService")

local CombatService = require(script.Parent:WaitForChild("CombatService"))

CombatService.start()

RunService.Heartbeat:Connect(function(dt)
	CombatService.step(dt)
end)

print("[BladeConcord] CombatBootstrap server ready — combat + match + Focus + arènes")
