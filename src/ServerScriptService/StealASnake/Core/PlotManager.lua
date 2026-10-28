--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DataManager = require(script.Parent.DataManager)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local SpeedCalculator = require(game.ReplicatedStorage.StealASnake.Modules.SpeedCalculator)
local FormatNumber = require(game.ReplicatedStorage.StealASnake.Modules.FormatNumber)
local SnakesConfig = require(game.ReplicatedStorage.StealASnake.Config.SnakesConfig)
local MutationsConfig = require(game.ReplicatedStorage.StealASnake.Config.MutationsConfig)
local ModelFactory = require(game.ServerStorage.StealASnake.Templates.ModelFactory)
local VFXFactory = require(game.ReplicatedStorage.StealASnake.Modules.VFXFactory)
local TutorialService = require(script.Parent.TutorialService)

local PlotManager = {}
local ownerByPlot: { [number]: Player? } = {}
local plotByPlayer: { [number]: number } = {}

local function plotsFolder(): Folder
	return Workspace:WaitForChild("Map"):WaitForChild("Plots") :: Folder
end

local function getPlot(index: number): Folder?
	return plotsFolder():FindFirstChild("Plot_" .. index) :: Folder?
end

function PlotManager.getPlayerPlot(player: Player): Folder?
	local idx = plotByPlayer[player.UserId]
	if not idx then
		return nil
	end
	return getPlot(idx)
end

local function refreshSign(plot: Folder, player: Player?)
	local sign = plot:FindFirstChild("OwnerSign")
	if not sign then
		return
	end
	local label = sign:FindFirstChild("OwnerLabel", true)
	if label and label:IsA("TextLabel") then
		label.Text = if player then player.DisplayName else "Libre"
	end
	-- l'étiquette d'argent n'est visible que sur une base occupée
	local pad = plot:FindFirstChild("CollectPad")
	local bb = pad and pad:FindFirstChild("CashBillboard")
	if bb and bb:IsA("BillboardGui") then
		bb.Enabled = player ~= nil
	end
end

local function refreshCollectBillboard(player: Player)
	local plot = PlotManager.getPlayerPlot(player)
	if not plot then
		return
	end
	local pad = plot:FindFirstChild("CollectPad")
	local bb = pad and pad:FindFirstChild("CashBillboard")
	local amount = bb and bb:FindFirstChild("Amount")
	if amount and amount:IsA("TextLabel") then
		local d = DataManager.get(player)
		amount.Text = "$" .. FormatNumber.short(d.PendingCash)
	end
end

local function clearVivariumVisuals(plot: Folder)
	local vivs = plot:FindFirstChild("Vivariums")
	if not vivs then
		return
	end
	for _, slot in vivs:GetChildren() do
		for _, c in slot:GetChildren() do
			if c:IsA("Model") and c:GetAttribute("IsSnake") then
				c:Destroy()
			end
		end
		slot:SetAttribute("Occupied", false)
	end
end

function PlotManager.renderVivariums(player: Player)
	local plot = PlotManager.getPlayerPlot(player)
	if not plot then
		return
	end
	clearVivariumVisuals(plot)
	local d = DataManager.get(player)
	local vivs = plot:FindFirstChild("Vivariums")
	if not vivs then
		return
	end
	for slotName, snake in d.Vivariums do
		if snake then
			local slot = vivs:FindFirstChild(slotName)
			if slot and slot:IsA("BasePart") then
				local def = SnakesConfig.get(snake.SpeciesId)
				local modelName = if def then def.ModelName else "Viper_Green"
				local m = ModelFactory.coiledSnake(modelName, 0.95)
				m:SetAttribute("Mutation", snake.Mutation)
				local _, size = m:GetBoundingBox()
				m:PivotTo(slot.CFrame * CFrame.new(0, 0.6 + size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0))
				VFXFactory.applyMutation(m, snake.Mutation, nil)
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then
						p.Anchored = true
						p.CanCollide = false
					end
				end
				local prompt = m.PrimaryPart and m.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
				if prompt then
					prompt:Destroy()
				end
				m.Parent = slot
				slot:SetAttribute("Occupied", true)
			end
		end
	end
	refreshCollectBillboard(player)
end

local function sendHome(player: Player)
	local plot = PlotManager.getPlayerPlot(player)
	local spawn = plot and plot:FindFirstChild("PlotSpawn")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if spawn and spawn:IsA("BasePart") and root and root:IsA("BasePart") then
		root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	end
end

function PlotManager.assign(player: Player)
	-- Déjà propriétaire : jamais deux parcelles pour un même joueur.
	local existing = plotByPlayer[player.UserId]
	if existing then
		return existing
	end
	for i = 1, 8 do
		if ownerByPlot[i] == nil then
			ownerByPlot[i] = player
			plotByPlayer[player.UserId] = i
			local d = DataManager.get(player)
			d.PlotIndex = i
			local plot = getPlot(i)
			if plot then
				refreshSign(plot, player)
				local spawn = plot:FindFirstChild("PlotSpawn")
				if spawn and spawn:IsA("SpawnLocation") then
					player.RespawnLocation = spawn -- réapparaît toujours sur SA parcelle
				end
				sendHome(player)
				PlotManager.refreshTreadmill(player)
				PlotManager.renderVivariums(player)
			end
			DataManager.push(player)
			return i
		end
	end
	return nil
end

-- (Re)pose le modèle de tapis correspondant au niveau du joueur sur TreadmillSpot.
function PlotManager.refreshTreadmill(player: Player)
	local plot = PlotManager.getPlayerPlot(player)
	local spot = plot and plot:FindFirstChild("TreadmillSpot")
	if not plot or not spot or not spot:IsA("BasePart") then
		return
	end
	for _, c in plot:GetChildren() do
		if c.Name:match("^Treadmill_L") then
			c:Destroy()
		end
	end
	local d = DataManager.get(player)
	local tm = ModelFactory.treadmill(d.TreadmillLevel)
	local _, size = tm:GetBoundingBox()
	tm:PivotTo(spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + size.Y / 2, 0))
	tm.Parent = plot
end

function PlotManager.release(player: Player)
	local idx = plotByPlayer[player.UserId]
	if idx then
		ownerByPlot[idx] = nil
		local plot = getPlot(idx)
		if plot then
			refreshSign(plot, nil)
			clearVivariumVisuals(plot)
			for _, c in plot:GetChildren() do
				if c.Name:match("^Treadmill_L") then
					c:Destroy()
				end
			end
		end
	end
	plotByPlayer[player.UserId] = nil
	player.RespawnLocation = nil
end

function PlotManager.firstFreeSlot(player: Player): string?
	local d = DataManager.get(player)
	for i = 1, 20 do
		local key = "Slot_" .. i
		if d.Vivariums[key] == nil then
			return key
		end
	end
	return nil
end

function PlotManager.depositSnake(player: Player, speciesId: string, mutation: string, weight: number): boolean
	local slot = PlotManager.firstFreeSlot(player)
	if not slot then
		Network.event("Alert"):FireClient(player, "Vivariums pleins !")
		return false
	end
	local def = SnakesConfig.get(speciesId)
	if not def then
		return false
	end
	local mut = MutationsConfig.Defs[mutation] or MutationsConfig.Defs.Normal
	local income = SpeedCalculator.income(
		def.BaseIncome,
		def.RarityMult,
		weight,
		def.BaseWeight,
		mut.Multiplier,
		DataManager.rebirthMult(player)
	)
	local d = DataManager.get(player)
	d.Vivariums[slot] = {
		SpeciesId = speciesId,
		Mutation = mutation,
		Weight = weight,
		Income = income,
	}
	DataManager.markDirty(player)
	PlotManager.renderVivariums(player)
	DataManager.push(player)
	Network.event("VFX"):FireClient(player, "CashBurst", nil)
	TutorialService.advance(player, 2)
	return true
end

function PlotManager.collect(player: Player)
	local d = DataManager.get(player)
	if d.PendingCash <= 0 then
		return
	end
	d.Cash += d.PendingCash
	d.PendingCash = 0
	DataManager.markDirty(player)
	refreshCollectBillboard(player)
	DataManager.push(player)
	Network.event("VFX"):FireClient(player, "CashBurst", nil)
	TutorialService.advance(player, 3)
end

function PlotManager.start()
	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if not plotByPlayer[player.UserId] then
				PlotManager.assign(player)
			else
				sendHome(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		hookCharacter(player)
		task.defer(function()
			PlotManager.assign(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		PlotManager.release(player)
	end)
	for _, p in Players:GetPlayers() do
		hookCharacter(p)
		PlotManager.assign(p)
	end

	Network.event("RequestCollect").OnServerEvent:Connect(function(player)
		PlotManager.collect(player)
	end)

	Network.event("RequestSell").OnServerEvent:Connect(function(player, slotName)
		if typeof(slotName) ~= "string" then
			return
		end
		local d = DataManager.get(player)
		local snake = d.Vivariums[slotName]
		if not snake then
			return
		end
		d.Cash += math.floor(snake.Income * 25)
		d.Vivariums[slotName] = nil
		DataManager.markDirty(player)
		PlotManager.renderVivariums(player)
		DataManager.push(player)
	end)

	local lastFusion: { [number]: number } = {}
	local function isSlot(s: any): boolean
		return typeof(s) == "string" and string.match(s, "^Slot_%d+$") ~= nil
	end
	Network.event("RequestFusion").OnServerEvent:Connect(function(player, slotA, slotB, slotC)
		-- validation : 3 vivariums distincts, joueur près de SA machine, 1 fusion / 0,5 s
		if not (isSlot(slotA) and isSlot(slotB) and isSlot(slotC)) or slotA == slotB or slotB == slotC or slotA == slotC then
			return
		end
		local now = os.clock()
		if now - (lastFusion[player.UserId] or 0) < 0.5 then
			return
		end
		lastFusion[player.UserId] = now
		local plot = PlotManager.getPlayerPlot(player)
		local machine = plot and plot:FindFirstChild("FusionMachine")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not machine or not machine:IsA("BasePart") or not root or not root:IsA("BasePart") or (root.Position - machine.Position).Magnitude > 20 then
			return
		end
		local d = DataManager.get(player)
		local a, b, c = d.Vivariums[slotA], d.Vivariums[slotB], d.Vivariums[slotC]
		if not a or not b or not c then
			return
		end
		if a.SpeciesId ~= b.SpeciesId or b.SpeciesId ~= c.SpeciesId then
			Network.event("Alert"):FireClient(player, "Fusion: 3 serpents identiques requis")
			return
		end
		if a.Mutation ~= b.Mutation or b.Mutation ~= c.Mutation then
			Network.event("Alert"):FireClient(player, "Fusion: même mutation requise")
			return
		end
		local nextMut = MutationsConfig.FusionNext[a.Mutation] or "Cosmic"
		local weight = (a.Weight + b.Weight + c.Weight) / 3 * 1.1
		d.Vivariums[slotB] = nil
		d.Vivariums[slotC] = nil
		local def = SnakesConfig.get(a.SpeciesId)
		if not def then
			return
		end
		local mut = MutationsConfig.Defs[nextMut]
		d.Vivariums[slotA] = {
			SpeciesId = a.SpeciesId,
			Mutation = nextMut,
			Weight = weight,
			Income = SpeedCalculator.income(
				def.BaseIncome,
				def.RarityMult,
				weight,
				def.BaseWeight,
				mut.Multiplier,
				DataManager.rebirthMult(player)
			),
		}
		DataManager.markDirty(player)
		PlotManager.renderVivariums(player)
		DataManager.push(player)
		Network.event("Alert"):FireClient(player, "Fusion → " .. nextMut)
	end)
end

PlotManager.refreshCollectBillboard = refreshCollectBillboard

return PlotManager
