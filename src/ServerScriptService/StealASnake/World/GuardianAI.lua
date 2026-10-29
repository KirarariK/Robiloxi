--!strict
--[[
	GuardianAI — Serpents Alpha qui gardent les nids. Machine à états : PATROL → CHASE → ATTACK → RETURN.

	Le serveur ne déplace qu'une « Root » invisible (Workspace.Guardians.Guardian_<BiomeId>.Root) et publie
	l'état en attributs (State, BiteAt, Speed). Le corps animé (anneaux qui ondulent, tête, mâchoire)
	est rendu côté client par GuardianRenderer → réseau léger et animation fluide.

	Règles :
	  - le gardien vit DANS son nid (il s'enroule autour) ;
	  - aggro si un joueur entre dans le rayon du nid (×1.35 s'il porte un serpent) ;
	  - une fois lancé, il poursuit le joueur À TRAVERS TOUTES LES ZONES jusqu'au début de la zone 1
	    (seul le hub est sûr), même depuis la zone 15 ;
	  - morsure = lâcher le serpent + projection vers le hub (pas de mort) ; immunité de 4 s ensuite ;
	  - cible perdue → retour au nid (plus rapide que la patrouille).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BiomesConfig = require(game.ReplicatedStorage.StealASnake.Config.BiomesConfig)
local CarrySystem = require(script.Parent.Parent.Core.CarrySystem)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local MonetizationService = require(script.Parent.Parent.Core.MonetizationService)

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
	NestRadius: number,
	RootGroundY: number, -- hauteur de la Root quand le gardien est au sol (hors du nid)
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

-- Morsure : plus de mort ni de réapparition. Le gardien POUSSE le joueur (éjection vers l'arrière,
-- en direction de la sortie de la zone), le fait trébucher un court instant et lui fait lâcher le serpent.
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
	-- biais vers +Z (la route / l'arène) pour sortir le joueur du nid
	dir = (dir + Vector3.new(0, 0, 0.6)).Unit
	hum:ChangeState(Enum.HumanoidStateType.FallingDown)
	hrp.AssemblyLinearVelocity = dir * 120 + Vector3.new(0, 45, 0)
	Network.event("VFX"):FireClient(player, "Bite", from)
	task.delay(0.9, function()
		if hum.Parent and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastAggroSent[player.UserId] = nil
	immuneUntil[player.UserId] = nil
end)

-- Seul le hub est sûr : tout ce qui est au-delà du début de la zone 1 est terrain de chasse.
local ZONE1_FRONT = BiomesConfig[1].Center.Z + BiomesConfig[1].Size.Z / 2
local SAFE_MARGIN = 2

local function inSafeZone(pos: Vector3): boolean
	return pos.Z > ZONE1_FRONT + SAFE_MARGIN
end

local RETURN_SPEED_MULT = 1.5

local function nearestThreat(cfg: any, home: Vector3): Player?
	local best: Player? = nil
	local bestDist = math.huge
	local now = os.clock()
	for _, plr in Players:GetPlayers() do
		local immune = immuneUntil[plr.UserId]
		if immune and now < immune then
			continue
		end
		if MonetizationService.hasShield(plr) then
			continue -- 🛡️ Bouclier (boutique / récompenses)
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
	-- sur le rebord du nid → hauteur du nid ; ailleurs → au sol (transition douce)
	local fromHome = Vector3.new(g.Pos.X - g.Home.X, 0, g.Pos.Z - g.Home.Z).Magnitude
	local targetY = if fromHome < g.NestRadius + 2 then g.Home.Y else g.RootGroundY
	g.Pos = Vector3.new(g.Pos.X, g.Pos.Y + (targetY - g.Pos.Y) * math.min(1, dt * 6), g.Pos.Z)
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
			NestRadius = ((spawn:GetAttribute("NestRadius") :: number?) or 11) * 0.82,
			RootGroundY = ((spawn:GetAttribute("GroundY") :: number?) or 1) + 3,
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
				-- poursuite tenace : on garde la cible tant qu'elle n'est pas rentrée au hub
				local threat = g.Target
				if threat then
					local char = threat.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local imm = immuneUntil[threat.UserId]
					if not threat.Parent or not hrp or not hrp:IsA("BasePart") or not hum or hum.Health <= 0
						or inSafeZone(hrp.Position) or MonetizationService.hasShield(threat) or (imm and now < imm) then
						threat = nil
					end
				end
				if not threat then
					threat = nearestThreat(g.Cfg, g.Home)
				end
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
					sendAggro(target, true, math.max(0.35, 1 - math.clamp(flat.Magnitude / g.Cfg.AggroRadius, 0, 1)))
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
							CarrySystem.drop(target, "💥 Le gardien t'a repoussé ! Tu as lâché le serpent")
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
			elseif g.State == "RETURN" then
				moveToward(g, g.Home + Vector3.new(0, 0, g.NestRadius), g.Cfg.GuardianSpeed * RETURN_SPEED_MULT, dt)
				if Vector3.new(g.Pos.X - g.Home.X, 0, g.Pos.Z - g.Home.Z).Magnitude < g.NestRadius + 4 then
					setState(g, "PATROL")
				end
			elseif g.State == "PATROL" then
				-- enroulé autour du nid : tour lent
				local a = t * 0.3 + g.Cfg.Order
				local orbit = g.Home + Vector3.new(math.sin(a) * g.NestRadius, 0, math.cos(a) * g.NestRadius)
				moveToward(g, orbit, g.Cfg.GuardianSpeed * 0.3, dt)
			else
				g.Model:SetAttribute("Speed", 0)
			end

			g.Root.CFrame = CFrame.lookAt(g.Pos, g.Pos + g.Facing)
		end
	end)
end

return GuardianAI
