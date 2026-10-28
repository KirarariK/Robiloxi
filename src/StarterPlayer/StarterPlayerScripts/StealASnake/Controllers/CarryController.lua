--!strict
--[[
	CarryController — entrée « lâcher le serpent » (touche G / bouton manette X).
	La pose de portage lourd est animée par AnimationController (visible chez tous les joueurs),
	la jauge de poids par UIController.
]]
local UserInputService = game:GetService("UserInputService")

local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)

local CarryController = {}

function CarryController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonX then
			Network.event("RequestDrop"):FireServer()
		end
	end)
end

return CarryController
