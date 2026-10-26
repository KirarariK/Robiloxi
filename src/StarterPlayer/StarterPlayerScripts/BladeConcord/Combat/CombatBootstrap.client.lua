--!strict
--[[
	Bootstrap client — input, caméra, poses sabre, FX, HUD combat + méta.
]]

local InputCombat = require(script.Parent:WaitForChild("InputCombat"))
local CombatPredict = require(script.Parent:WaitForChild("CombatPredict"))
local CombatHud = require(script.Parent:WaitForChild("CombatHud"))
local SaberPose = require(script.Parent:WaitForChild("SaberPose"))
local CombatAnimator = require(script.Parent:WaitForChild("CombatAnimator"))
local AnimationShowcase = require(script.Parent:WaitForChild("AnimationShowcase"))
local SoftLockCamera = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("SoftLockCamera"))
local CameraShake = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("CameraShake"))
local CombatFx = require(script.Parent.Parent:WaitForChild("FX"):WaitForChild("CombatFx"))
local SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))
local MetaHud = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("MetaHud"))
local LobbyHud = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("LobbyHud"))
local TutorialTips = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("TutorialTips"))

SoundHooks.start()
CameraShake.start()
CombatFx.bind({ CameraShake = CameraShake, SoundHooks = SoundHooks, SoftLockCamera = SoftLockCamera })
LobbyHud.start() -- salon d'abord
CombatHud.start()
CombatFx.start()
SaberPose.start() -- visuals + fallback ; listener désactivé par CombatAnimator
CombatAnimator.start() -- chemin principal KeyframeSequence / Procedural
CombatPredict.start()
InputCombat.start()
SoftLockCamera.start()
MetaHud.start()
TutorialTips.start() -- tips FR salon / combat (première session)
AnimationShowcase.bind() -- touche P → BC_Showcase
SoundHooks.startHum()

print(
	string.format(
		"[BladeConcord] Client ready — salon · %d anim sets · Jouer · M méta · F8 debug",
		CombatAnimator.getSetCount()
	)
)
