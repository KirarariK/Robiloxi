--!strict
--[[
	Bootstrap client P0 — input, prediction visuelle, HUD.
]]

local InputCombat = require(script.Parent:WaitForChild("InputCombat"))
local CombatPredict = require(script.Parent:WaitForChild("CombatPredict"))
local CombatHud = require(script.Parent:WaitForChild("CombatHud"))

CombatHud.start()
CombatPredict.start()
InputCombat.start()

print("[BladeConcord] CombatBootstrap client ready — LMB attaque (hold=lourde), RMB parade")
