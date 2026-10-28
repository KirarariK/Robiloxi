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

-- Pas de bouton « Réinitialiser » : on ne meurt plus dans Steal A Snake (le gardien repousse)
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

print("[StealASnake] client ready")
