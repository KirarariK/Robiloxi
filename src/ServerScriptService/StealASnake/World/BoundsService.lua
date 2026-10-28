--!strict
--[[
	BoundsService — filet de sécurité anti-chute.
	Les murs + barrières invisibles empêchent de sortir de la map ; si un joueur passe malgré tout
	sous le sol (glitch physique, vitesse extrême) ou hors des limites du monde, il est ramené
	à sa base. Le serpent porté est perdu (comme une morsure), sans autre pénalité.
]]
local Players = game:GetService("Players")

local BiomesConfig = require(game.ReplicatedStorage.StealASnake.Config.BiomesConfig)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local CarrySystem = require(script.Parent.Parent.Core.CarrySystem)
local PlotManager = require(script.Parent.Parent.Core.PlotManager)

local BoundsService = {}

local CHECK_INTERVAL = 0.5
local MIN_Y = -30
local MAX_X = 380
local MAX_Z = 340
local last = BiomesConfig[#BiomesConfig]
local MIN_Z = last.Center.Z - last.Size.Z / 2 - 80

local function outOfBounds(p: Vector3): boolean
	return p.Y < MIN_Y or math.abs(p.X) > MAX_X or p.Z > MAX_Z or p.Z < MIN_Z
end

local function rescue(player: Player, root: BasePart)
	CarrySystem.drop(player, nil)
	local plot = PlotManager.getPlayerPlot(player)
	local spawn = plot and plot:FindFirstChild("PlotSpawn")
	root.AssemblyLinearVelocity = Vector3.zero
	if spawn and spawn:IsA("BasePart") then
		root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
	else
		root.CFrame = CFrame.new(0, 8, 60)
	end
	Network.event("Alert"):FireClient(player, "🪂 Tu es sorti de la map : retour à ta base !")
end

function BoundsService.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and outOfBounds(root.Position) then
					rescue(player, root)
				end
			end
		end
	end)
end

return BoundsService
