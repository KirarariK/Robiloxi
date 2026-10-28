--!strict
local DataManager = require(script.Parent.DataManager)
local CarrySystem = require(script.Parent.CarrySystem)
local PlotManager = require(script.Parent.PlotManager)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local RebirthsConfig = require(game.ReplicatedStorage.StealASnake.Config.RebirthsConfig)
local FormatNumber = require(game.ReplicatedStorage.StealASnake.Modules.FormatNumber)

local RebirthSystem = {}

function RebirthSystem.start()
	Network.event("RequestRebirth").OnServerEvent:Connect(function(player)
		local d = DataManager.get(player)
		local cost = RebirthsConfig.costFor(d.Rebirths)
		if d.Cash < cost then
			Network.event("Alert"):FireClient(player, "Pas assez d'argent : rebirth à $" .. FormatNumber.short(cost))
			return
		end
		CarrySystem.drop(player)
		local keepSpeed = d.Speed * RebirthsConfig.KeepSpeedPercent
		d.Cash = 0
		d.PendingCash = 0
		d.Vivariums = {}
		d.TreadmillLevel = 1
		d.Speed = keepSpeed
		d.Rebirths += 1
		DataManager.markDirty(player)
		PlotManager.renderVivariums(player)
		PlotManager.refreshTreadmill(player)
		CarrySystem.applyWalkSpeed(player)
		DataManager.push(player)
		Network.event("Alert"):FireClient(player, "Rebirth +" .. tostring(d.Rebirths) .. " !")
	end)
end

return RebirthSystem
