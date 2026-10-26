--!strict
--[[
	Bootstrap client — input, caméra, poses sabre, FX, HUD combat + méta.
]]

local InputCombat = require(script.Parent:WaitForChild("InputCombat"))
local CombatPredict = require(script.Parent:WaitForChild("CombatPredict"))
local CombatHud = require(script.Parent:WaitForChild("CombatHud"))
local SaberPose = require(script.Parent:WaitForChild("SaberPose"))
local CombatAnimator = require(script.Parent:WaitForChild("CombatAnimator"))
local SoftLockCamera = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("SoftLockCamera"))
local CameraShake = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("CameraShake"))
local CombatFx = require(script.Parent.Parent:WaitForChild("FX"):WaitForChild("CombatFx"))
local SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))
local MetaHud = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("MetaHud"))

SoundHooks.start()
CameraShake.start()
CombatFx.bind({ CameraShake = CameraShake, SoundHooks = SoundHooks, SoftLockCamera = SoftLockCamera })
CombatHud.start()
CombatFx.start()
SaberPose.start() -- visuals + fallback ; listener désactivé par CombatAnimator
CombatAnimator.start() -- chemin principal KeyframeSequence / Procedural
CombatPredict.start()
InputCombat.start()
SoftLockCamera.start()
MetaHud.start()
SoundHooks.startHum()

print(
	string.format(
		"[BladeConcord] Client ready — %d anim sets · LMB/RMB · Q/E esquive · Shift dash · F/G Focus · M méta",
		CombatAnimator.getSetCount()
	)
)
