--!strict
--[[
	Charge / construit l'arène Obsidian Pit (parts grises) + spawns A/B + kill plane.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local ArenaService = {}

local arenaFolder: Folder? = nil

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

function ArenaService.ensureObsidianPit(): Folder
	if arenaFolder and arenaFolder.Parent then
		return arenaFolder
	end

	local arenas = Workspace:FindFirstChild("Arenas")
	if not arenas then
		arenas = Instance.new("Folder")
		arenas.Name = "Arenas"
		arenas.Parent = Workspace
	end

	local existing = arenas:FindFirstChild(CombatConfig.Arena.Name)
	if existing and existing:IsA("Folder") and existing:FindFirstChild("Platform") then
		arenaFolder = existing
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = CombatConfig.Arena.Name
	folder.Parent = arenas

	local gray = Color3.fromRGB(90, 90, 95)
	local dark = Color3.fromRGB(40, 40, 45)
	local lava = Color3.fromRGB(180, 60, 30)
	local size = CombatConfig.Arena.PlatformSize
	local wallH = CombatConfig.Arena.WallHeight

	part("Platform", size, CFrame.new(0, 0, 0), gray, folder)
	-- Anneau fissuré placeholder (ring)
	part("Ring", Vector3.new(size.X + 8, 1, size.Z + 8), CFrame.new(0, -0.5, 0), dark, folder)

	-- Murs bas
	local halfX = size.X / 2
	local halfZ = size.Z / 2
	part("WallN", Vector3.new(size.X + 4, wallH, 2), CFrame.new(0, wallH / 2, -halfZ - 1), gray, folder)
	part("WallS", Vector3.new(size.X + 4, wallH, 2), CFrame.new(0, wallH / 2, halfZ + 1), gray, folder)
	part("WallE", Vector3.new(2, wallH, size.Z), CFrame.new(halfX + 1, wallH / 2, 0), gray, folder)
	part("WallW", Vector3.new(2, wallH, size.Z), CFrame.new(-halfX - 1, wallH / 2, 0), gray, folder)

	-- Lave bordure soft (KillPlane tag + DPS attr)
	local lavaPart = part("LavaBorder", Vector3.new(size.X + 24, 1, size.Z + 24), CFrame.new(0, -3, 0), lava, folder)
	lavaPart.Transparency = 0.35
	lavaPart:SetAttribute("Dps", CombatConfig.Arena.LavaDps)
	CollectionService:AddTag(lavaPart, CombatConfig.Tags.KillPlane)

	-- Spawns A / B face à face
	local spawnA = part("SpawnA", Vector3.new(4, 1, 4), CFrame.new(-18, 1.5, 0), Color3.fromRGB(120, 120, 140), folder)
	spawnA.Transparency = 0.5
	spawnA.CanCollide = false
	CollectionService:AddTag(spawnA, CombatConfig.Tags.ArenaSpawnA)

	local spawnB = part("SpawnB", Vector3.new(4, 1, 4), CFrame.new(18, 1.5, 0), Color3.fromRGB(140, 120, 120), folder)
	spawnB.Transparency = 0.5
	spawnB.CanCollide = false
	CollectionService:AddTag(spawnB, CombatConfig.Tags.ArenaSpawnB)

	-- Attachments orientation
	local attA = Instance.new("Attachment")
	attA.Name = "Facing"
	attA.Parent = spawnA
	local attB = Instance.new("Attachment")
	attB.Name = "Facing"
	attB.Parent = spawnB

	arenaFolder = folder
	return folder
end

function ArenaService.getSpawnCFrames(): (CFrame, CFrame)
	ArenaService.ensureObsidianPit()
	local a = CFrame.new(-18, 4, 0) * CFrame.Angles(0, math.rad(90), 0) -- face +X
	local b = CFrame.new(18, 4, 0) * CFrame.Angles(0, math.rad(-90), 0) -- face −X
	return a, b
end

return ArenaService
