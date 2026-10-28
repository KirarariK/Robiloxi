--!strict
--[[
	GuardianAI — Serpents Alpha qui gardent les nids. Machine à états : PATROL → CHASE → ATTACK → RETURN.

	Le serveur ne déplace qu'une « Root » invisible (Workspace.Guardians.Guardian_<BiomeId>.Root) et publie
	l'état en attributs (State, BiteAt, Speed). Le corps animé (anneaux qui ondulent, tête, mâchoire)
	est rendu côté client par GuardianRenderer → réseau léger et animation fluide.

	Règles :
	  - aggro si un joueur entre dans le rayon (×1.35 s'il porte un serpent) et n'est pas en zone sûre ;
	  - l'intérieur d'un biome n'est jamais sûr (l'allée est coupée à la frontière) ;
	  - morsure = lâcher le serpent + projection + mort ; immunité de 4 s ensuite.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BiomesConfig = require(game.ReplicatedStorage.StealASnake.Config.BiomesConfig)
local CarrySystem = require(script.Parent.Parent.Core.CarrySystem)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)

type Guardian = {
	Model: Model,
	Root: BasePart,
	Cfg: any,
	State: string,
	Home: Vector3,
	Pos: Vector3,
	Facing: Vector3,
	Target: Player?,
	Alerted: { [number]: boolean },
	AttackUntil: number,
}

local GuardianAI = {}
local guardians: { Guardian } = {}

-- Throttle réseau : l'intensité d'aggro part au client ~6×/s max.
local AGGRO_SEND_INTERVAL = 1 / 6
local lastAggroSent: { [number]: number } = {}
-- Après une morsure, le joueur est ignoré par tous les gardiens (projection + mort + respawn).
local BITE_IMMUNITY = 4
local immuneUntil: { [number]: number } = {}
local BITE_WINDUP = 0.22 -- anticipation (tête qui recule) avant l'impact

local function sendAggro(player: Player, active: boolean, intensity: number)
	local now = os.clock()
	if active then
		local last = lastAggroSent[player.UserId]
		if last and now - last < AGGRO_SEND_INTERVAL then
			return
		end
	end
	lastAggroSent[player.UserId] = if active then now else nil
	Network.event("GuardianAggro"):FireClient(player, active, intensity)
end

local function biteKnockback(player: Player, from: Vector3)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hrp:IsA("BasePart") or not hum then
		return
	end
	local away = hrp.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
	hrp.AssemblyLinearVelocity = dir * 90 + Vector3.new(0, 55, 0)
	task.delay(0.6, function()
		if hum.Parent then
			hum.Health = 0
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastAggroSent[player.UserId] = nil
	immuneUntil[player.UserId] = nil
end)

local function insideBox(part: BasePart, pos: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) <= part.Size.X * 0.5 and math.abs(rel.Z) <= part.Size.Z * 0.5
end

-- Vrai si la position est à l'intérieur d'un biome (zone d'aggro) : jamais sûre, même sur l'allée.
local function inAnyBiome(pos: Vector3): boolean
	local biomes = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Biomes")
	if not biomes then
		return false
	end
	for _, b in biomes:GetChildren() do
		local boundary = b:FindFirstChild("BiomeBoundary")
		if boundary and boundary:IsA("BasePart") and insideBox(boundary, pos) then
			return true
		end
	end
	return false
end

local function inSafeZone(pos: Vector3): boolean
	if inAnyBiome(pos) then
		return false
	end
	local safe = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("SafeZone")
	if not safe then
		return false
	end
	for _, name in { "SafePath", "HubFloor" } do
		local p = safe:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			local rel = p.CFrame:PointToObjectSpace(pos)
			if math.abs(rel.X) < p.Size.X * 0.55 and math.abs(rel.Z) < p.Size.Z * 0.55 and math.abs(rel.Y) < 40 then
				return true
			end
		end
	end
	return false
end

local function nearestThreat(cfg: any, home: Vector3): Player?
	local best: Player? = nil
	local bestDist = math.huge
	local now = os.clock()
	for _, plr in Players:GetPlayers() do
		local immune = immuneUntil[plr.UserId]
		if immune and now < immune then
			continue
		end
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hrp:IsA("BasePart") and hum and hum.Health > 0 then
			if inSafeZone(hrp.Position) then
				continue
			end
			local d = (hrp.Position - home).Magnitude
			local aggro = if CarrySystem.isCarrying(plr) then cfg.AggroRadius * 1.35 else cfg.AggroRadius
			if d < aggro and d < bestDist then
				bestDist = d
				best = plr
			end
		end
	end
	return best
end

local function setState(g: Guardian, state: string)
	if g.State ~= state then
		g.State = state
		g.Model:SetAttribute("State", state)
	end
end

local function moveToward(g: Guardian, target: Vector3, speed: number, dt: number)
	local dir = target - g.Pos
	dir = Vector3.new(dir.X, 0, dir.Z)
	local dist = dir.Magnitude
	if dist < 0.05 then
		g.Model:SetAttribute("Speed", 0)
		return
	end
	local stepLen = math.min(dist, speed * dt)
	g.Pos += dir.Unit * stepLen
	g.Facing = dir.Unit
	g.Model:SetAttribute("Speed", stepLen / math.max(dt, 1e-3))
end

function GuardianAI.start()
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = Workspace

	for _, cfg in BiomesConfig do
		local biomes = Workspace:WaitForChild("Map"):WaitForChild("Biomes")
		local biome = biomes:WaitForChild(cfg.Id)
		local spawn = biome:WaitForChild("GuardianSpawn") :: BasePart
		local scale = 1 + (cfg.Order - 1) * 0.1

		local model = Instance.new("Model")
		model.Name = "Guardian_" .. cfg.Id
		model:SetAttribute("IsGuardian", true)
		model:SetAttribute("BiomeId", cfg.Id)
		model:SetAttribute("Order", cfg.Order)
		model:SetAttribute("GuardianName", cfg.GuardianName)
		model:SetAttribute("Scale", scale)
		model:SetAttribute("State", "PATROL")
		model:SetAttribute("BiteAt", 0)
		model:SetAttribute("Speed", 0)

		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(5, 5, 5) * scale
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
		root.CollisionGroup = "Guardians"
		root.CFrame = CFrame.new(spawn.Position)
		root.Parent = model
		model.PrimaryPart = root
		model.Parent = folder

		table.insert(guardians, {
			Model = model,
			Root = root,
			Cfg = cfg,
			State = "PATROL",
			Home = spawn.Position,
			Pos = spawn.Position,
			Facing = Vector3.new(0, 0, 1),
			Target = nil,
			Alerted = {},
			AttackUntil = 0,
		})
	end

	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		local now = os.clock()
		for _, g in guardians do
			-- Morsure en cours : la tête est figée pendant l'anticipation puis l'impact
			if g.State == "ATTACK" then
				if now >= g.AttackUntil then
					setState(g, "RETURN")
				end
			else
				local threat = nearestThreat(g.Cfg, g.Home)
				if threat then
					local isNew = g.Target ~= threat
					g.Target = threat
					setState(g, "CHASE")
					if isNew and not g.Alerted[threat.UserId] then
						g.Alerted[threat.UserId] = true
						Network.event("Alert"):FireClient(threat, "⚠️ " .. g.Cfg.GuardianName .. " TE POURSUIT ! COURS VERS LA ZONE SÛRE !")
					end
				elseif g.State == "CHASE" then
					if g.Target then
						sendAggro(g.Target, false, 0)
						g.Alerted[g.Target.UserId] = nil
					end
					g.Target = nil
					setState(g, "RETURN")
				end
			end

			if g.State == "CHASE" and g.Target then
				local target = g.Target
				local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") and not inSafeZone(hrp.Position) then
					local flat = Vector3.new(hrp.Position.X - g.Pos.X, 0, hrp.Position.Z - g.Pos.Z)
					sendAggro(target, true, 1 - math.clamp(flat.Magnitude / g.Cfg.AggroRadius, 0, 1))
					moveToward(g, hrp.Position, g.Cfg.GuardianSpeed, dt)
					if flat.Magnitude <= g.Cfg.AttackRadius then
						-- ATTACK : anticipation puis impact
						setState(g, "ATTACK")
						g.AttackUntil = now + BITE_WINDUP + 0.6
						g.Model:SetAttribute("BiteAt", Workspace:GetServerTimeNow())
						immuneUntil[target.UserId] = now + BITE_IMMUNITY
						g.Alerted[target.UserId] = nil
						g.Target = nil
						local from = g.Pos
						task.delay(BITE_WINDUP, function()
							CarrySystem.drop(target, "Le gardien t'a eu !")
							sendAggro(target, false, 0)
							biteKnockback(target, from)
						end)
					end
				else
					if hrp then
						sendAggro(target, false, 0)
					end
					g.Target = nil
					setState(g, "RETURN")
				end
			elseif g.State == "RETURN" or g.State == "PATROL" then
				local orbit = g.Home + Vector3.new(math.sin(t * 0.35 + g.Cfg.Order) * 16, 0, math.cos(t * 0.35 + g.Cfg.Order) * 16)
				moveToward(g, orbit, g.Cfg.GuardianSpeed * 0.4, dt)
				if g.State == "RETURN" and (g.Pos - g.Home).Magnitude < 20 then
					setState(g, "PATROL")
				end
			else
				g.Model:SetAttribute("Speed", 0)
			end

			g.Root.CFrame = CFrame.lookAt(g.Pos, g.Pos + g.Facing)
		end
	end)
end

return GuardianAI
