--!strict
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local PlotManager = require(script.Parent.PlotManager)

local EconomySystem = {}

function EconomySystem.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local d = DataManager.get(player)
				local income = 0
				for _, snake in d.Vivariums do
					if snake then
						income += snake.Income
					end
				end
				if income > 0 then
					d.PendingCash += income
					DataManager.markDirty(player)
					PlotManager.refreshCollectBillboard(player)
				end
			end
		end
	end)
end

return EconomySystem
