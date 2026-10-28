--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DataManager = require(script.Parent.DataManager)
local PlotManager = require(script.Parent.PlotManager)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local SpeedCalculator = require(game.ReplicatedStorage.StealASnake.Modules.SpeedCalculator)
local SnakesConfig = require(game.ReplicatedStorage.StealASnake.Config.SnakesConfig)
local RebirthsConfig = require(game.ReplicatedStorage.StealASnake.Config.RebirthsConfig)
local ModelFactory = require(game.ServerStorage.StealASnake.Templates.ModelFactory)
local VFXFactory = require(game.ReplicatedStorage.StealASnake.Modules.VFXFactory)
local TutorialService = require(script.Parent.TutorialService)
local MutationsConfig = require(game.ReplicatedStorage.StealASnake.Config.MutationsConfig)
local FormatNumber = require(game.ReplicatedStorage.StealASnake.Modules.FormatNumber)

type CarryState = {
	SpeciesId: string,
	Mutation: string,
	Weight: number,
	Model: Model,
	LastPos: Vector3,
	AllowedSpeed: number,
	WindowPos: Vector3,
	WindowTime: number,
	GraceUntil: number,
}

-- Anti-triche : contrôle sur une fenêtre glissante (robuste aux à-coups de réplication)
local CHECK_WINDOW = 0.5 -- secondes
local SPEED_TOLERANCE = 1.35 -- règle métier : distance > vitesse autorisée × dt × 1.35
local JITTER_STUDS = 3 -- marge réseau par fenêtre
local TELEPORT_STUDS = 25 -- saut instantané = téléport évident
local STEAL_GRACE = 0.75 -- secondes sans contrôle juste après le vol

local CarrySystem = {}
local carrying: { [number]: CarryState } = {}

local function humanoid(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function hrp(player: Player): BasePart?
	local char = player.Character
	local p = char and char:FindFirstChild("HumanoidRootPart")
	return if p and p:IsA("BasePart") then p else nil
end

function CarrySystem.isCarrying(player: Player): boolean
	return carrying[player.UserId] ~= nil
end

function CarrySystem.applyWalkSpeed(player: Player)
	local hum = humanoid(player)
	local root = hrp(player)
	if not hum or not root then
		return
	end
	local d = DataManager.get(player)
	local normal = SpeedCalculator.normalSpeed(d.Speed, d.Rebirths, RebirthsConfig.SpeedBonusPerRebirth)
	local state = carrying[player.UserId]
	if state then
		hum.WalkSpeed = SpeedCalculator.carrySpeed(normal, state.Weight)
		state.AllowedSpeed = hum.WalkSpeed
	else
		hum.WalkSpeed = normal
	end
end

function CarrySystem.drop(player: Player, reason: string?)
	local state = carrying[player.UserId]
	if not state then
		return
	end
	if state.Model then
		state.Model:Destroy()
	end
	carrying[player.UserId] = nil
	if player.Character then
		player.Character:SetAttribute("CarryWeight", nil) -- fin de la pose de portage (AnimationController)
	end
	CarrySystem.applyWalkSpeed(player)
	Network.event("CarryState"):FireClient(player, nil)
	if reason then
		Network.event("Alert"):FireClient(player, reason)
	end
end

function CarrySystem.steal(player: Player, snakeModel: Model): boolean
	if carrying[player.UserId] then
		Network.event("Alert"):FireClient(player, "Tu portes déjà un serpent")
		return false
	end
	local root = hrp(player)
	if not root or not snakeModel.PrimaryPart then
		return false
	end
	if (root.Position - snakeModel.PrimaryPart.Position).Magnitude > 14 then
		Network.event("Alert"):FireClient(player, "Trop loin")
		return false
	end
	if not snakeModel:GetAttribute("IsWild") or not snakeModel:IsDescendantOf(Workspace) then
		return false -- seuls les serpents sauvages des nids sont volables
	end
	local speciesId = snakeModel:GetAttribute("SpeciesId")
	local mutation = snakeModel:GetAttribute("Mutation") or "Normal"
	local weight = snakeModel:GetAttribute("Weight") or 20
	if typeof(speciesId) ~= "string" then
		return false
	end
	snakeModel:Destroy()

	local basket = ModelFactory.basket()
	local coil = ModelFactory.coiledSnake((SnakesConfig.get(speciesId) or { ModelName = "Viper_Green" }).ModelName, 0.6)
	coil:SetAttribute("Mutation", mutation)
	coil:SetAttribute("IsSnake", nil) -- pas d'animation idle / pas volable une fois porté
	local prompt = coil:FindFirstChild("StealPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	VFXFactory.applyMutation(coil, mutation :: string, nil)
	for _, p in coil:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.Massless = true
			p.Anchored = false
			p.CollisionGroup = "CarriedSnakes"
		end
	end
	coil.Parent = basket
	if coil.PrimaryPart and basket.PrimaryPart then
		coil:PivotTo(basket.PrimaryPart.CFrame * CFrame.new(0, 0.8, 0))
		local w = Instance.new("WeldConstraint")
		w.Part0 = basket.PrimaryPart
		w.Part1 = coil.PrimaryPart
		w.Parent = basket.PrimaryPart
	end
	basket.Parent = player.Character
	player.Character:SetAttribute("CarryWeight", weight) -- pose de portage lourd chez tous les clients
	if basket.PrimaryPart then
		basket.PrimaryPart.CFrame = root.CFrame * CFrame.new(0, 0.9, -1.9)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = basket.PrimaryPart
		weld.Parent = basket.PrimaryPart
		basket.PrimaryPart.CollisionGroup = "CarriedSnakes"
	end

	local d = DataManager.get(player)
	local normal = SpeedCalculator.normalSpeed(d.Speed, d.Rebirths, RebirthsConfig.SpeedBonusPerRebirth)
	local allowed = SpeedCalculator.carrySpeed(normal, weight :: number)
	local now = os.clock()
	carrying[player.UserId] = {
		SpeciesId = speciesId,
		Mutation = mutation :: string,
		Weight = weight :: number,
		Model = basket,
		LastPos = root.Position,
		AllowedSpeed = allowed,
		WindowPos = root.Position,
		WindowTime = now,
		GraceUntil = now + STEAL_GRACE,
	}
	CarrySystem.applyWalkSpeed(player)
	Network.event("CarryState"):FireClient(player, {
		SpeciesId = speciesId,
		Mutation = mutation,
		Weight = weight,
		Penalty = math.floor((1 - allowed / math.max(normal, 1)) * 100),
	})
	TutorialService.advance(player, 1)
	return true
end

function CarrySystem.tryDeposit(player: Player)
	local state = carrying[player.UserId]
	local plot = PlotManager.getPlayerPlot(player)
	local root = hrp(player)
	if not state or not plot or not root then
		return
	end
	local drop = plot:FindFirstChild("DropZone")
	if not drop or not drop:IsA("BasePart") then
		return
	end
	if (root.Position - drop.Position).Magnitude > 12 then
		return
	end
	local ok = PlotManager.depositSnake(player, state.SpeciesId, state.Mutation, state.Weight)
	if ok then
		CarrySystem.drop(player, "Serpent sécurisé !")
	end
end

-- Stand VENDRE du hub : vend le serpent porté (même valeur que la vente depuis un vivarium : revenu × 25).
local SELL_RADIUS = 12
local function sellZone(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local stall = hub and hub:FindFirstChild("SellStall")
	local zone = stall and stall:FindFirstChild("SellZone")
	return if zone and zone:IsA("BasePart") then zone else nil
end

function CarrySystem.trySell(player: Player)
	local state = carrying[player.UserId]
	local root = hrp(player)
	local zone = sellZone()
	if not state or not root or not zone then
		return
	end
	local flat = root.Position - zone.Position
	if Vector3.new(flat.X, 0, flat.Z).Magnitude > SELL_RADIUS then
		return
	end
	local def = SnakesConfig.get(state.SpeciesId)
	if not def then
		return
	end
	local mut = MutationsConfig.Defs[state.Mutation] or MutationsConfig.Defs.Normal
	local income = SpeedCalculator.income(def.BaseIncome, def.RarityMult, state.Weight, def.BaseWeight, mut.Multiplier, DataManager.rebirthMult(player))
	local value = math.floor(income * 25)
	local d = DataManager.get(player)
	d.Cash += value
	DataManager.markDirty(player)
	CarrySystem.drop(player, "💲 Vendu ! +$" .. FormatNumber.short(value))
	DataManager.push(player)
	Network.event("VFX"):FireClient(player, "CashBurst", nil)
end

function CarrySystem.start()
	Network.event("RequestSteal").OnServerEvent:Connect(function(player, snake)
		if typeof(snake) ~= "Instance" or not snake:IsA("Model") then
			return
		end
		if not snake:GetAttribute("IsSnake") then
			return
		end
		CarrySystem.steal(player, snake)
	end)

	Network.event("RequestDrop").OnServerEvent:Connect(function(player)
		CarrySystem.drop(player, "Serpent lâché")
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			CarrySystem.applyWalkSpeed(player)
		end)
	end)

	RunService.Heartbeat:Connect(function(dt)
		for userId, state in carrying do
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				carrying[userId] = nil
				continue
			end
			local root = hrp(player)
			if not root then
				continue
			end
			local now = os.clock()
			if now < state.GraceUntil then
				-- juste après le vol : on recale la fenêtre sans sanctionner
				state.LastPos = root.Position
				state.WindowPos = root.Position
				state.WindowTime = now
				continue
			end
			-- Distances horizontales : une chute ou un saut ne déclenche pas l'anti-triche.
			local step = root.Position - state.LastPos
			local stepDist = Vector3.new(step.X, 0, step.Z).Magnitude
			local cheated = stepDist > TELEPORT_STUDS
			local elapsed = now - state.WindowTime
			if not cheated and elapsed >= CHECK_WINDOW then
				local w = root.Position - state.WindowPos
				local windowDist = Vector3.new(w.X, 0, w.Z).Magnitude
				cheated = windowDist > state.AllowedSpeed * elapsed * SPEED_TOLERANCE + JITTER_STUDS
				state.WindowPos = root.Position
				state.WindowTime = now
			end
			if cheated then
				CarrySystem.drop(player, "Anti-cheat: vol annulé")
				local plot = PlotManager.getPlayerPlot(player)
				local spawn = plot and plot:FindFirstChild("PlotSpawn")
				if spawn and spawn:IsA("BasePart") then
					root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
				end
				continue
			end
			state.LastPos = root.Position
			CarrySystem.tryDeposit(player)
			CarrySystem.trySell(player)
		end
	end)
end

return CarrySystem
