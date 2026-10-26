--!strict
--[[
	Arènes GDD §6 :
	- Obsidian Pit (lave bordure)
	- Sanctum des Deux Astres (vents)
	- Trône d'Éclipse (pression anti-camp)
	- Quai Mirage (panneaux temporaires)
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))

local ArenaService = {}

export type ArenaId = "ObsidianPit" | "SanctumAstres" | "TroneEclipse" | "QuaiMirage"

local ARENA_ORDER: { ArenaId } = { "ObsidianPit", "SanctumAstres", "TroneEclipse", "QuaiMirage" }

local activeId: ArenaId = "ObsidianPit"
local arenasRoot: Folder? = nil
local built: { [ArenaId]: Folder } = {}
local hazardAccumulator = 0

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, anchored: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = if anchored == nil then true else anchored
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function getArenasRoot(): Folder
	if arenasRoot and arenasRoot.Parent then
		return arenasRoot
	end
	local arenas = Workspace:FindFirstChild("Arenas")
	if not arenas then
		arenas = Instance.new("Folder")
		arenas.Name = "Arenas"
		arenas.Parent = Workspace
	end
	arenasRoot = arenas :: Folder
	return arenasRoot
end

local function buildSpawns(folder: Folder, offset: Vector3)
	local spawnA = part("SpawnA", Vector3.new(4, 1, 4), CFrame.new(offset + Vector3.new(-18, 1.5, 0)), Color3.fromRGB(120, 120, 140), folder)
	spawnA.Transparency = 0.5
	spawnA.CanCollide = false
	CollectionService:AddTag(spawnA, CombatConfig.Tags.ArenaSpawnA)

	local spawnB = part("SpawnB", Vector3.new(4, 1, 4), CFrame.new(offset + Vector3.new(18, 1.5, 0)), Color3.fromRGB(140, 120, 120), folder)
	spawnB.Transparency = 0.5
	spawnB.CanCollide = false
	CollectionService:AddTag(spawnB, CombatConfig.Tags.ArenaSpawnB)
end

local function buildObsidianPit(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ObsidianPit"
	folder.Parent = parent
	folder:SetAttribute("DisplayName", "Obsidian Pit — Creuset de Lave")
	folder:SetAttribute("OffsetX", 0)

	local offset = Vector3.new(0, 0, 0)
	local gray = Color3.fromRGB(90, 90, 95)
	local dark = Color3.fromRGB(40, 40, 45)
	local lava = Color3.fromRGB(180, 60, 30)
	local size = Vector3.new(64, 2, 64)
	local wallH = 12

	part("Platform", size, CFrame.new(offset), gray, folder)
	part("Ring", Vector3.new(size.X + 8, 1, size.Z + 8), CFrame.new(offset + Vector3.new(0, -0.5, 0)), dark, folder)
	local halfX, halfZ = size.X / 2, size.Z / 2
	part("WallN", Vector3.new(size.X + 4, wallH, 2), CFrame.new(offset + Vector3.new(0, wallH / 2, -halfZ - 1)), gray, folder)
	part("WallS", Vector3.new(size.X + 4, wallH, 2), CFrame.new(offset + Vector3.new(0, wallH / 2, halfZ + 1)), gray, folder)
	part("WallE", Vector3.new(2, wallH, size.Z), CFrame.new(offset + Vector3.new(halfX + 1, wallH / 2, 0)), gray, folder)
	part("WallW", Vector3.new(2, wallH, size.Z), CFrame.new(offset + Vector3.new(-halfX - 1, wallH / 2, 0)), gray, folder)

	local lavaPart = part("LavaBorder", Vector3.new(size.X + 24, 1, size.Z + 24), CFrame.new(offset + Vector3.new(0, -3, 0)), lava, folder)
	lavaPart.Transparency = 0.35
	lavaPart:SetAttribute("Dps", CombatConfig.Arena.LavaDps)
	lavaPart:SetAttribute("HazardKind", "Lava")
	CollectionService:AddTag(lavaPart, CombatConfig.Tags.KillPlane)
	CollectionService:AddTag(lavaPart, CombatConfig.Tags.Hazard)

	buildSpawns(folder, offset)
	-- TODO: art pass cendres / particles — stub Part OK
	return folder
end

local function buildSanctum(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "SanctumAstres"
	folder.Parent = parent
	folder:SetAttribute("DisplayName", "Sanctum des Deux Astres")
	local ox = 120
	folder:SetAttribute("OffsetX", ox)
	local offset = Vector3.new(ox, 0, 0)
	local stone = Color3.fromRGB(180, 175, 160)
	local size = Vector3.new(56, 2, 56)
	part("Platform", size, CFrame.new(offset), stone, folder)
	part("WallN", Vector3.new(size.X, 10, 2), CFrame.new(offset + Vector3.new(0, 5, -29)), stone, folder)
	part("WallS", Vector3.new(size.X, 10, 2), CFrame.new(offset + Vector3.new(0, 5, 29)), stone, folder)

	-- Vents latéraux (Hazard)
	local windL = part("WindWest", Vector3.new(8, 6, 40), CFrame.new(offset + Vector3.new(-22, 4, 0)), Color3.fromRGB(160, 200, 220), folder)
	windL.Transparency = 0.7
	windL.CanCollide = false
	windL:SetAttribute("HazardKind", "Wind")
	windL:SetAttribute("WindDir", Vector3.new(1, 0, 0))
	CollectionService:AddTag(windL, CombatConfig.Tags.Hazard)

	local windR = part("WindEast", Vector3.new(8, 6, 40), CFrame.new(offset + Vector3.new(22, 4, 0)), Color3.fromRGB(160, 200, 220), folder)
	windR.Transparency = 0.7
	windR.CanCollide = false
	windR:SetAttribute("HazardKind", "Wind")
	windR:SetAttribute("WindDir", Vector3.new(-1, 0, 0))
	CollectionService:AddTag(windR, CombatConfig.Tags.Hazard)

	buildSpawns(folder, offset)
	return folder
end

local function buildThrone(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TroneEclipse"
	folder.Parent = parent
	folder:SetAttribute("DisplayName", "Trône d'Éclipse")
	local ox = 240
	folder:SetAttribute("OffsetX", ox)
	local offset = Vector3.new(ox, 0, 0)
	local dark = Color3.fromRGB(50, 45, 60)
	local size = Vector3.new(60, 2, 60)
	part("Platform", size, CFrame.new(offset), dark, folder)

	-- Estrade centrale (anti-camp pressure)
	local dais = part("Dais", Vector3.new(14, 3, 14), CFrame.new(offset + Vector3.new(0, 2.5, 0)), Color3.fromRGB(70, 55, 90), folder)
	dais:SetAttribute("HazardKind", "ThronePressure")
	dais:SetAttribute("Dps", CombatConfig.Arena.ThronePressureDps)
	CollectionService:AddTag(dais, CombatConfig.Tags.Hazard)

	local throne = part("ThroneStub", Vector3.new(4, 6, 3), CFrame.new(offset + Vector3.new(0, 7, 0)), Color3.fromRGB(30, 25, 40), folder)
	throne.CanCollide = false
	-- TODO: mesh trône — stub Part

	buildSpawns(folder, offset)
	return folder
end

local function buildMirage(parent: Folder): Folder
	local folder = Instance.new("Folder")
	folder.Name = "QuaiMirage"
	folder.Parent = parent
	folder:SetAttribute("DisplayName", "Quai Mirage")
	local ox = 360
	folder:SetAttribute("OffsetX", ox)
	local offset = Vector3.new(ox, 0, 0)
	local teal = Color3.fromRGB(70, 110, 120)
	part("Platform", Vector3.new(58, 2, 40), CFrame.new(offset), teal, folder)

	-- Panneaux temporaires (StringValue config + Parts)
	local panels = Instance.new("Folder")
	panels.Name = "MiragePanels"
	panels.Parent = folder
	local cfg = Instance.new("StringValue")
	cfg.Name = "TODO_PanelCycle"
	cfg.Value = "Cycle panels every Arena.MiragePanelLifetime — art stub"
	cfg.Parent = panels

	for i = 1, 3 do
		local panel = part(
			"Panel" .. i,
			Vector3.new(10, 8, 1),
			CFrame.new(offset + Vector3.new(-15 + i * 10, 5, if i % 2 == 0 then -8 else 8)),
			Color3.fromRGB(120, 180, 190),
			panels
		)
		panel.Transparency = 0.4
		panel:SetAttribute("HazardKind", "MiragePanel")
		panel:SetAttribute("PanelIndex", i)
		CollectionService:AddTag(panel, CombatConfig.Tags.Hazard)
	end

	buildSpawns(folder, offset)
	return folder
end

function ArenaService.ensureAll(): Folder
	local root = getArenasRoot()
	if not built.ObsidianPit then
		built.ObsidianPit = buildObsidianPit(root)
	end
	if not built.SanctumAstres then
		built.SanctumAstres = buildSanctum(root)
	end
	if not built.TroneEclipse then
		built.TroneEclipse = buildThrone(root)
	end
	if not built.QuaiMirage then
		built.QuaiMirage = buildMirage(root)
	end
	return root
end

-- Compat P0
function ArenaService.ensureObsidianPit(): Folder
	ArenaService.ensureAll()
	return built.ObsidianPit
end

function ArenaService.list(): { ArenaId }
	return table.clone(ARENA_ORDER)
end

function ArenaService.getActiveId(): ArenaId
	return activeId
end

function ArenaService.setActive(id: ArenaId)
	ArenaService.ensureAll()
	if built[id] then
		activeId = id
	end
end

function ArenaService.getSpawnCFrames(): (CFrame, CFrame)
	ArenaService.ensureAll()
	local folder = built[activeId]
	local ox = if folder then (folder:GetAttribute("OffsetX") :: number?) or 0 else 0
	local a = CFrame.new(ox - 18, 4, 0) * CFrame.Angles(0, math.rad(90), 0)
	local b = CFrame.new(ox + 18, 4, 0) * CFrame.Angles(0, math.rad(-90), 0)
	return a, b
end

function ArenaService.getDisplayName(): string
	local folder = built[activeId]
	if folder then
		local n = folder:GetAttribute("DisplayName")
		if typeof(n) == "string" then
			return n
		end
	end
	return activeId
end

--[[
	Dangers environnementaux légers — jamais one-shot full HP < 3 s.
]]
function ArenaService.stepHazards(dt: number)
	hazardAccumulator += dt
	if hazardAccumulator < 0.2 then
		return
	end
	local step = hazardAccumulator
	hazardAccumulator = 0

	local folder = built[activeId]
	if not folder then
		return
	end

	for _, fighter in FighterState.getAll() do
		if fighter.actionId == "Dead" or not fighter.character then
			continue
		end
		local hrp = fighter.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end

		for _, inst in CollectionService:GetTagged(CombatConfig.Tags.Hazard) do
			if not inst:IsDescendantOf(folder) or not inst:IsA("BasePart") then
				continue
			end
			local kind = inst:GetAttribute("HazardKind")
			local inZone = (hrp.Position - inst.Position).Magnitude < (inst.Size.Magnitude * 0.45)

			if kind == "Lava" then
				-- Bordure : sous la plateforme
				if hrp.Position.Y < 1 then
					local dps = (inst:GetAttribute("Dps") :: number?) or CombatConfig.Arena.LavaDps
					local dmg = math.min(dps * step, CombatConfig.MaxHp / CombatConfig.Arena.MinLethalFullHpSeconds * step)
					fighter.hp = math.max(0, fighter.hp - dmg)
					local humanoid = fighter.character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = fighter.hp
					end
					if fighter.hp <= 0 then
						fighter.actionId = "Dead"
					end
				end
			elseif kind == "Wind" and inZone then
				local dir = inst:GetAttribute("WindDir")
				if typeof(dir) == "Vector3" and not hrp.Anchored then
					hrp.AssemblyLinearVelocity += dir.Unit * CombatConfig.Arena.WindForce * step
				end
			elseif kind == "ThronePressure" and inZone then
				-- Anti-camp : DPS faible sur estrade
				local dps = (inst:GetAttribute("Dps") :: number?) or CombatConfig.Arena.ThronePressureDps
				local dmg = math.min(dps * step, CombatConfig.MaxHp / CombatConfig.Arena.MinLethalFullHpSeconds * step)
				fighter.hp = math.max(0, fighter.hp - dmg)
				local humanoid = fighter.character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = fighter.hp
				end
				if fighter.hp <= 0 then
					fighter.actionId = "Dead"
				end
			elseif kind == "MiragePanel" then
				-- Cycle visibility stub
				local idx = (inst:GetAttribute("PanelIndex") :: number?) or 1
				local phase = (os.clock() / CombatConfig.Arena.MiragePanelLifetime + idx * 0.3) % 1
				inst.CanCollide = phase < 0.55
				inst.Transparency = if phase < 0.55 then 0.25 else 0.85
			end
		end
	end
end

return ArenaService
