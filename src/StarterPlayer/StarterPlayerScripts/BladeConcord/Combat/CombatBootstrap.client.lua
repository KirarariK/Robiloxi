--!strict
--[[
	Bootstrap client — input, caméra, poses sabre, FX, HUD combat + méta.
]]

local InputCombat = require(script.Parent:WaitForChild("InputCombat"))
local CombatPredict = require(script.Parent:WaitForChild("CombatPredict"))
local CombatHud = require(script.Parent:WaitForChild("CombatHud"))
local SaberPose = require(script.Parent:WaitForChild("SaberPose"))
local SoftLockCamera = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("SoftLockCamera"))
local CameraShake = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("CameraShake"))
local CombatFx = require(script.Parent.Parent:WaitForChild("FX"):WaitForChild("CombatFx"))
local SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))
local MetaHud = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("MetaHud"))

SoundHooks.start()
CameraShake.start()
CombatFx.bind({ CameraShake = CameraShake, SoundHooks = SoundHooks })
CombatHud.start()
CombatFx.start()
SaberPose.start()
CombatPredict.start()
InputCombat.start()
SoftLockCamera.start()
MetaHud.start()

print(
	"[BladeConcord] Client ready — polish visuel · LMB/RMB · Q/E esquive · Shift dash · F Poussée · G Dash Focus · M méta"
)
