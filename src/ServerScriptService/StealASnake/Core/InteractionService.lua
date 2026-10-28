--!strict
local Players = game:GetService("Players")

local DataManager = require(script.Parent.DataManager)
local PlotManager = require(script.Parent.PlotManager)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local TreadmillsConfig = require(game.ReplicatedStorage.StealASnake.Config.TreadmillsConfig)
local RebirthsConfig = require(game.ReplicatedStorage.StealASnake.Config.RebirthsConfig)
local FormatNumber = require(game.ReplicatedStorage.StealASnake.Modules.FormatNumber)

local InteractionService = {}
local wired: { [number]: boolean } = {}

local function promptOn(part: BasePart, name: string, action: string, object: string, hold: number?): ProximityPrompt
	local existing = part:FindFirstChild(name)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0.4
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = part
	return p
end

--[[
	Les prompts sont câblés une seule fois par parcelle et vérifient le propriétaire ACTUEL à chaque
	activation : un joueur qui récupère la parcelle d'un autre peut l'utiliser normalement.
]]
local function ownerOf(who: Player, plot: Folder): boolean
	return PlotManager.getPlayerPlot(who) == plot
end

local function wirePlot(_player: Player, plot: Folder)
	if plot:GetAttribute("SAS_Wired") == true then
		return
	end
	plot:SetAttribute("SAS_Wired", true)

	local collect = plot:FindFirstChild("CollectPad")
	if collect and collect:IsA("BasePart") then
		local pr = promptOn(collect, "CollectPrompt", "Récolter", "Cash", 0.15)
		pr.Triggered:Connect(function(who)
			if ownerOf(who, plot) then
				PlotManager.collect(who)
			end
		end)
		-- Marcher sur le bouton récolte aussi
		local lastTouch: { [Player]: number } = {}
		collect.Touched:Connect(function(hit)
			local who = Players:GetPlayerFromCharacter(hit.Parent)
			if who and ownerOf(who, plot) and os.clock() - (lastTouch[who] or 0) > 1 then
				lastTouch[who] = os.clock()
				PlotManager.collect(who)
			end
		end)
	end

	local tm = plot:FindFirstChild("TreadmillSpot")
	if tm and tm:IsA("BasePart") then
		local pr = promptOn(tm, "UpgradePrompt", "Améliorer", "Tapis", 0.25)
		pr.Triggered:Connect(function(who)
			if ownerOf(who, plot) then
				Network.event("OpenUI"):FireClient(who, "Treadmill", nil)
			end
		end)
	end

	local fusion = plot:FindFirstChild("FusionMachine")
	if fusion and fusion:IsA("BasePart") then
		local pr = promptOn(fusion, "FusionPrompt", "Fusionner", "3 identiques", 0.4)
		pr.Triggered:Connect(function(who)
			if ownerOf(who, plot) then
				Network.event("OpenUI"):FireClient(who, "Fusion", nil)
			end
		end)
	end

	local rebirth = plot:FindFirstChild("RebirthShrine")
	if rebirth and rebirth:IsA("BasePart") then
		local pr = promptOn(rebirth, "RebirthPrompt", "Rebirth", "Autel", 0.8)
		pr.Triggered:Connect(function(who)
			if ownerOf(who, plot) then
				local d = DataManager.get(who)
				Network.event("OpenUI"):FireClient(who, "Rebirth", {
					Cost = RebirthsConfig.costFor(d.Rebirths),
					Rebirths = d.Rebirths,
				})
			end
		end)
	end

	local vivs = plot:FindFirstChild("Vivariums")
	if vivs then
		for _, slot in vivs:GetChildren() do
			if slot:IsA("BasePart") then
				local pr = promptOn(slot, "ManagePrompt", "Gérer", "Vivarium", 0.15)
				pr.Triggered:Connect(function(who)
					if ownerOf(who, plot) then
						local d = DataManager.get(who)
						Network.event("OpenUI"):FireClient(who, "Vivarium", {
							Slot = slot.Name,
							Snake = d.Vivariums[slot.Name],
						})
					end
				end)
			end
		end
	end
end

function InteractionService.refreshPlayer(player: Player)
	local plot = PlotManager.getPlayerPlot(player)
	if plot then
		wirePlot(player, plot)
		wired[player.UserId] = true
	end
end

function InteractionService.start()
	Players.PlayerAdded:Connect(function(player)
		task.delay(1.2, function()
			InteractionService.refreshPlayer(player)
		end)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			InteractionService.refreshPlayer(player)
		end)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(InteractionService.refreshPlayer, p)
	end

	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local plot = PlotManager.getPlayerPlot(player)
				local spot = plot and plot:FindFirstChild("TreadmillSpot")
				local pr = spot and spot:FindFirstChild("UpgradePrompt")
				if pr and pr:IsA("ProximityPrompt") then
					local d = DataManager.get(player)
					local nextCfg = TreadmillsConfig[d.TreadmillLevel + 1]
					if nextCfg then
						pr.Enabled = true
						pr.ObjectText = string.format(
							"Lvl %d→%d ($%s)",
							d.TreadmillLevel,
							nextCfg.Level,
							FormatNumber.short(nextCfg.Cost)
						)
					else
						pr.ObjectText = "MAX"
						pr.Enabled = false
					end
				end
			end
		end
	end)
end

return InteractionService
