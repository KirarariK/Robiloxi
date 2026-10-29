--!strict
-- Clone une arène depuis ServerStorage.EtherBladesAssets.Arenas.<ArenaId> à un emplacement libre,
-- loin du Hub. Si le modèle est absent, construit une arène de repli minimale (plateforme + repères)
-- pour que le déroulé reste testable, avec un avertissement explicite.
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaData = require(ReplicatedStorage:WaitForChild("EtherBlades").Config.ArenaData)

local ArenaAllocator = {}

local ORIGIN = Vector3.new(6000, 400, 6000) -- loin du Hub (autour de l'origine)
local SPACING = 1200
local MAX_SLOTS = 32

local used: { [number]: boolean } = {}
local warned: { [string]: boolean } = {}

local function folder(): Folder
	local f = Workspace:FindFirstChild("EB_Arenas")
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "EB_Arenas"
		nf.Parent = Workspace
		return nf
	end
	return f :: Folder
end

local function marker(model: Model, name: string, cf: CFrame)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(2, 2, 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.CFrame = cf
	p.Parent = model
end

local function buildFallback(arenaId: string): Model
	local m = Instance.new("Model")
	m.Name = arenaId
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(90, 2, 90)
	floor.Anchored = true
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(40, 46, 60)
	floor.CFrame = CFrame.new(0, -1, 0)
	floor.Parent = m
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 60, 60)
	ring.CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(60, 200, 255)
	ring.Transparency = 0.6
	ring.Parent = m
	marker(m, "Center", CFrame.new(0, 3, 0))
	marker(m, "SpawnA", CFrame.lookAt(Vector3.new(0, 3, -16), Vector3.new(0, 3, 16)))
	marker(m, "SpawnB", CFrame.lookAt(Vector3.new(0, 3, 16), Vector3.new(0, 3, -16)))
	marker(m, "IntroCam", CFrame.lookAt(Vector3.new(26, 9, 0), Vector3.new(0, 3, 0)))
	marker(m, "KillY", CFrame.new(0, -40, 0))
	m.PrimaryPart = floor
	return m
end

local function template(arenaId: string): Model?
	local assets = ServerStorage:FindFirstChild("EtherBladesAssets")
	local arenas = assets and assets:FindFirstChild("Arenas")
	local t = arenas and arenas:FindFirstChild(arenaId)
	if t and t:IsA("Model") then
		return t
	end
	return nil
end

-- Choisit une arène au hasard parmi celles qui existent (toutes si aucune n'existe → repli).
function ArenaAllocator.pickArenaId(rng: Random): string
	local available: { string } = {}
	for _, a in ArenaData.List do
		if template(a.Id) then
			table.insert(available, a.Id)
		end
	end
	if #available == 0 then
		for _, a in ArenaData.List do
			table.insert(available, a.Id)
		end
	end
	return available[rng:NextInteger(1, #available)]
end

-- Retourne le modèle placé et une fonction de libération (à confier au Maid du match).
function ArenaAllocator.acquire(arenaId: string, matchId: string): (Model?, () -> ())
	local slot: number? = nil
	for i = 1, MAX_SLOTS do
		if not used[i] then
			slot = i
			break
		end
	end
	if not slot then
		warn("[EtherBlades] plus aucun emplacement d'arène libre")
		return nil, function() end
	end
	local s = slot :: number
	used[s] = true
	local t = template(arenaId)
	local model: Model
	if t then
		model = t:Clone()
	else
		if not warned[arenaId] then
			warned[arenaId] = true
			warn(string.format("[EtherBlades] ServerStorage.EtherBladesAssets.Arenas.%s absent : arène de repli utilisée.", arenaId))
		end
		model = buildFallback(arenaId)
	end
	model.Name = string.format("%s_%s", arenaId, string.sub(matchId, 1, 8))
	local col = (s - 1) % 8
	local row = math.floor((s - 1) / 8)
	model:PivotTo(CFrame.new(ORIGIN + Vector3.new(col * SPACING, 0, row * SPACING)))
	model.Parent = folder()
	local released = false
	return model, function()
		if released then
			return
		end
		released = true
		model:Destroy()
		used[s] = nil
	end
end

function ArenaAllocator.part(arena: Model, name: string): BasePart?
	local p = arena:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

return ArenaAllocator
