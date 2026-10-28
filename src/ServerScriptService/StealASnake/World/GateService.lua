--!strict
--[[
	GateService — portes de biome débloquées PAR JOUEUR.
	La porte n'a pas de collision : un joueur non qualifié qui la franchit est repoussé doucement
	devant la porte avec le détail de ce qui lui manque. Dès qu'il remplit les conditions
	(Vitesse affichée dans le HUD ≥ requise ET argent ≥ requis), le biome est débloqué
	définitivement (DataManager.MaxBiome, sauvegardé) — l'argent n'est pas dépensé.
	Changement documenté : la condition de Vitesse compare la stat « Vitesse » du HUD (d.Speed)
	et non plus la WalkSpeed, pour que le joueur voie exactement le chiffre demandé.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DataManager = require(script.Parent.Parent.Core.DataManager)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local FormatNumber = require(game.ReplicatedStorage.StealASnake.Modules.FormatNumber)
local BiomesConfig = require(game.ReplicatedStorage.StealASnake.Config.BiomesConfig)

local GateService = {}

local CHECK_INTERVAL = 0.2
local PUSH_BACK = 8 -- studs devant la porte
local MESSAGE_COOLDOWN = 2.5

local lastMessage: { [number]: number } = {}

local function gateZ(cfg: any): number?
	local biomes = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Biomes")
	local biome = biomes and biomes:FindFirstChild(cfg.Id)
	local gate = biome and biome:FindFirstChild("BiomeGate")
	return if gate and gate:IsA("BasePart") then gate.Position.Z else nil
end

local function check(player: Player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local d = DataManager.get(player)
	local pos = root.Position
	for _, cfg in BiomesConfig do
		if cfg.Order <= d.MaxBiome then
			continue
		end
		local gz = gateZ(cfg)
		local backZ = cfg.Center.Z - cfg.Size.Z / 2 - 10
		if not gz or pos.Z >= gz or pos.Z < backZ or math.abs(pos.X) > cfg.Size.X / 2 + 10 then
			continue
		end
		if d.Speed >= cfg.GateSpeed and d.Cash >= cfg.GateCash then
			d.MaxBiome = math.max(d.MaxBiome, cfg.Order)
			DataManager.markDirty(player)
			DataManager.push(player)
			Network.event("Alert"):FireClient(player, "🔓 " .. cfg.Name .. " débloqué !")
			continue
		end
		-- repoussé devant la porte, regard tourné vers la route
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(Vector3.new(pos.X, pos.Y, gz + PUSH_BACK), Vector3.new(pos.X, pos.Y, gz + PUSH_BACK + 10))
		local now = os.clock()
		if now - (lastMessage[player.UserId] or 0) > MESSAGE_COOLDOWN then
			lastMessage[player.UserId] = now
			local missing = {}
			if d.Speed < cfg.GateSpeed then
				table.insert(missing, string.format("⚡ %d Vitesse", math.ceil(cfg.GateSpeed - d.Speed)))
			end
			if d.Cash < cfg.GateCash then
				table.insert(missing, "💵 $" .. FormatNumber.short(cfg.GateCash - d.Cash))
			end
			Network.event("Alert"):FireClient(player, "🔒 " .. cfg.Name .. " — il te manque : " .. table.concat(missing, " · "))
		end
		return
	end
end

function GateService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastMessage[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return GateService
