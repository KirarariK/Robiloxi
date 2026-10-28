--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataManager = require(script.Parent.DataManager)
local PlotManager = require(script.Parent.PlotManager)
local CarrySystem = require(script.Parent.CarrySystem)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local TreadmillsConfig = require(game.ReplicatedStorage.StealASnake.Config.TreadmillsConfig)
local TutorialService = require(script.Parent.TutorialService)

local TrainingSystem = {}

local function onTreadmill(player: Player): boolean
	local plot = PlotManager.getPlayerPlot(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not plot or not hrp or not hrp:IsA("BasePart") then
		return false
	end
	local spot = plot:FindFirstChild("TreadmillSpot")
	if not spot or not spot:IsA("BasePart") then
		return false
	end
	return (hrp.Position - spot.Position).Magnitude < 8
end

function TrainingSystem.start()
	Network.event("RequestTreadmillUpgrade").OnServerEvent:Connect(function(player)
		local d = DataManager.get(player)
		local nextLevel = d.TreadmillLevel + 1
		local cfg = TreadmillsConfig[nextLevel]
		if not cfg then
			Network.event("Alert"):FireClient(player, "Niveau max")
			return
		end
		if d.Cash < cfg.Cost then
			Network.event("Alert"):FireClient(player, "Pas assez d'argent")
			return
		end
		d.Cash -= cfg.Cost
		d.TreadmillLevel = nextLevel
		DataManager.markDirty(player)
		PlotManager.refreshTreadmill(player)
		Network.event("Alert"):FireClient(player, "Tapis amélioré : niveau " .. nextLevel .. " !")
		Network.event("VFX"):FireClient(player, "CashBurst", nil)
		DataManager.push(player)
		CarrySystem.applyWalkSpeed(player)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		local step = acc
		acc = 0
		for _, player in Players:GetPlayers() do
			if CarrySystem.isCarrying(player) then
				continue
			end
			if onTreadmill(player) then
				local d = DataManager.get(player)
				local cfg = TreadmillsConfig[d.TreadmillLevel] or TreadmillsConfig[1]
				d.Speed += cfg.SpeedPerSec * step
				if d.Speed >= 1 then
					TutorialService.advance(player, 4)
				end
				DataManager.markDirty(player)
				CarrySystem.applyWalkSpeed(player)
				DataManager.push(player)
			end
		end
	end)
end

return TrainingSystem
