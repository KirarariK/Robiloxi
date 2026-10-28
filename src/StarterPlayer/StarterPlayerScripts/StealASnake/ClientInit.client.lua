--!strict
local Controllers = script.Parent.Controllers

local EnvironmentController = require(Controllers.EnvironmentController)
local UIController = require(Controllers.UIController)
local CarryController = require(Controllers.CarryController)
local VFXController = require(Controllers.VFXController)
local SoundController = require(Controllers.SoundController)
local AnimationController = require(Controllers.AnimationController)
local GuardianRenderer = require(Controllers.GuardianRenderer)
local AmbienceController = require(Controllers.AmbienceController)

EnvironmentController.start()
UIController.start()
CarryController.start()
VFXController.start()
SoundController.start()
AnimationController.start()
GuardianRenderer.start()
task.spawn(AmbienceController.start, EnvironmentController)

print("[StealASnake] client ready")
