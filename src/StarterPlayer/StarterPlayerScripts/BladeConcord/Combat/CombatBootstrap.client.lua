--!strict
--[[
	Bootstrap client P0–P3 — input, caméra, prediction, HUD combat + méta.
]]

local InputCombat = require(script.Parent:WaitForChild("InputCombat"))
local CombatPredict = require(script.Parent:WaitForChild("CombatPredict"))
local CombatHud = require(script.Parent:WaitForChild("CombatHud"))
local SoftLockCamera = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("SoftLockCamera"))
local MetaHud = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("MetaHud"))

CombatHud.start()
CombatPredict.start()
InputCombat.start()
SoftLockCamera.start()
MetaHud.start()

print(
	"[BladeConcord] Client ready — LMB/RMB · Q/E ou double A/D esquive · Shift dash · F Poussée · G Dash Focus · M méta"
)
