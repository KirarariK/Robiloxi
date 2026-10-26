--!strict
--[[
	Cour Concord — cour ouverte, 8 terrains × 2 slots (ArtPass 12).

	API :
	  ensure / getSpawnCFrame / applyLobbyLighting
	  bindDuelSlots(claimFn) — claimFn(player, slotIndex 1..8)
	  bindQueuePads(enqueueFn) — legacy Casual/Ranked
	  getDuelSlotInfos / getDuelSlotPad

	Contrat SlotMatchService : BC_DuelSlot + BC_DuelSlotPad (inchangé).
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyConfig = require(script.Parent:WaitForChild("LobbyConfig"))
local LobbyUtil = require(script.Parent:WaitForChild("LobbyUtil"))
local LobbyLighting = require(script.Parent:WaitForChild("LobbyLighting"))
local LobbyProps = require(script.Parent:WaitForChild("LobbyProps"))

local NeonFx = require(
	ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Visual"):WaitForChild("NeonFx")
)

local LobbyBuilder = {}

local built: Model? = nil
local padBound = false
local duelBound = false
local neonBound = false
local duelPadsByIndex: { [number]: BasePart } = {}
local duelPadLists: { [number]: { BasePart } } = {}

local C = LobbyConfig.Colors
local H = LobbyConfig.Hall
local Z = LobbyConfig.Zones

local function colorForKey(key: string): Color3
	local c = (C :: any)[key]
	if typeof(c) == "Color3" then
		return c
	end
	return C.Focus
end

local function buildCourt(root: Model)
	local court = LobbyUtil.model("Court", root, "Hall")
	local spawnZ = H.SpawnLocal.Z
	local endZ = H.BayZ
	local south = spawnZ + 16
	local midZ = (south + endZ) * 0.5
	local len = south - endZ

	LobbyUtil.part(
		"Deck",
		Vector3.new(H.Width, 2, len),
		LobbyUtil.cf(Vector3.new(0, -0.9, midZ)),
		C.Marble,
		court,
		Enum.Material.Slate,
		{ reflectance = 0.05 }
	)
	LobbyUtil.part(
		"Alley",
		Vector3.new(10, 0.25, len - 18),
		LobbyUtil.cf(Vector3.new(0, 0.2, midZ - 4)),
		C.MarbleLite,
		court,
		Enum.Material.Slate,
		{ reflectance = 0.08, canCollide = false }
	)
	LobbyUtil.part(
		"EndCurb",
		Vector3.new(H.Width, 2.2, 2),
		LobbyUtil.cf(Vector3.new(0, 1.1, endZ)),
		C.Metal,
		court,
		Enum.Material.Slate
	)

	local archZ = spawnZ + 10
	for _, x in { -6.5, 6.5 } do
		LobbyUtil.part(
			"ArchPost",
			Vector3.new(1.8, 9, 1.8),
			LobbyUtil.cf(Vector3.new(x, 4.5, archZ)),
			C.Metal,
			court,
			Enum.Material.Slate,
			{ reflectance = 0.12 }
		)
	end
	local lintel = LobbyUtil.part(
		"ArchLintel",
		Vector3.new(16, 1.4, 2),
		LobbyUtil.cf(Vector3.new(0, 9.4, archZ)),
		C.Metal,
		court,
		Enum.Material.Metal,
		{ reflectance = 0.18 }
	)
	if lintel then
		LobbyUtil.billboard(lintel, "COUR CONCORD", C.Gold, Vector2.new(240, 36), 2)
	end
	LobbyUtil.part(
		"BannerDawn",
		Vector3.new(0.35, 6, 2.2),
		LobbyUtil.cf(Vector3.new(-8.4, 6, archZ)),
		C.Dawn,
		court,
		Enum.Material.Fabric,
		{ canCollide = false }
	)
	LobbyUtil.part(
		"BannerDusk",
		Vector3.new(0.35, 6, 2.2),
		LobbyUtil.cf(Vector3.new(8.4, 6, archZ)),
		C.Dusk,
		court,
		Enum.Material.Fabric,
		{ canCollide = false }
	)
end

local function buildSpawns(root: Model)
	local spawns = LobbyUtil.model("Spawns", root, "Hall")
	local base = H.SpawnLocal
	local spots = {
		base,
		base + Vector3.new(5, 0, 4),
		base + Vector3.new(-5, 0, 4),
		base + Vector3.new(0, 0, 8),
	}
	for i, pos in spots do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = if i == 1 then "LobbySpawn" else ("LobbySpawnReserve" .. (i - 1))
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = LobbyUtil.cf(pos) * CFrame.Angles(0, math.rad(180), 0) -- face baie (−Z)
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 4
		spawn.Neutral = true
		spawn.Enabled = true
		spawn.Parent = spawns
		if i == 1 then
			LobbyUtil.tag(spawn, LobbyConfig.Tags.LobbySpawn)
		end
	end
end

local function rememberPad(idx: number, pad: BasePart)
	local list = duelPadLists[idx]
	if not list then
		list = {}
		duelPadLists[idx] = list
	end
	table.insert(list, pad)
	if not duelPadsByIndex[idx] then
		duelPadsByIndex[idx] = pad
	end
end

local function buildDuelSlots(root: Model)
	local folder = LobbyUtil.model("DuelSlots", root, "DuelSlots")
	duelPadsByIndex = {}
	duelPadLists = {}
	for _, spec in LobbyConfig.DuelSlots do
		local pads = LobbyProps.terrainPair(folder, {
			index = spec.index,
			x = spec.x,
			z = spec.z,
			side = spec.side,
			color = colorForKey(spec.colorKey),
		})
		for _, pad in pads do
			rememberPad(spec.index, pad)
		end
	end
end

local function makeQueuePad(
	parent: Instance,
	localPos: Vector3,
	mode: "Casual" | "Ranked",
	color: Color3,
	label: string
): BasePart?
	local zone = LobbyUtil.model("Pad_" .. mode, parent, "Pads")
	local pad = LobbyUtil.part(
		"QueuePad",
		Vector3.new(LobbyConfig.PadRadius * 1.6, 0.35, LobbyConfig.PadRadius * 1.6),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 0.9, 0)),
		color,
		zone,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.3, castShadow = false }
	)
	if not pad then
		return nil
	end
	pad:SetAttribute("BC_QueueMode", mode)
	LobbyUtil.tag(pad, LobbyConfig.Tags.QueuePad)
	LobbyUtil.billboard(pad, label, color, Vector2.new(180, 32), 4)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QueuePrompt"
	prompt.ActionText = if mode == "Casual" then "File Amical" else "File Classé"
	prompt.ObjectText = label
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = pad
	local touch = LobbyUtil.part(
		"TouchVolume",
		Vector3.new(LobbyConfig.PadRadius * 2, 5, LobbyConfig.PadRadius * 2),
		LobbyUtil.cf(localPos + Vector3.new(0, 3, 0)),
		color,
		zone,
		Enum.Material.ForceField,
		{ canCollide = false, transparency = 1, castShadow = false }
	)
	if touch then
		touch:SetAttribute("BC_QueueMode", mode)
		LobbyUtil.tag(touch, LobbyConfig.Tags.QueuePad)
	end
	return pad
end

local function buildLegacyQueuePads(root: Model)
	makeQueuePad(root, Z.PadCasual, "Casual", C.Focus, "AMICAL")
	makeQueuePad(root, Z.PadRanked, "Ranked", C.Gold, "CLASSÉ")
end

function LobbyBuilder.getSpawnCFrame(): CFrame
	return LobbyUtil.cf(H.SpawnLocal) * CFrame.Angles(0, math.rad(180), 0)
end

function LobbyBuilder.applyLobbyLighting()
	LobbyLighting.applyHall()
end

function LobbyBuilder.getDuelSlotInfos(): {
	{
		index: number,
		localPos: Vector3,
		side: string,
		colorKey: string,
	}
}
	local list = {}
	for _, spec in LobbyConfig.DuelSlots do
		table.insert(list, {
			index = spec.index,
			localPos = Vector3.new(spec.x, 0, spec.z),
			side = spec.side,
			colorKey = spec.colorKey,
		})
	end
	return list
end

function LobbyBuilder.getDuelSlotPad(slotIndex: number): BasePart?
	return duelPadsByIndex[slotIndex]
end

function LobbyBuilder.getDuelSlotPads(slotIndex: number): { BasePart }
	return duelPadLists[slotIndex] or {}
end

function LobbyBuilder.getArenaLayout()
	return LobbyConfig.ArenaLayout
end

function LobbyBuilder.ensure(parent: Instance): Model
	if built and built.Parent then
		return built
	end
	local existing = parent:FindFirstChild(LobbyConfig.Name)
	if existing and existing:IsA("Model") and existing:GetAttribute("ArtPass") == LobbyConfig.ArtPass then
		built = existing
		duelPadsByIndex = {}
		duelPadLists = {}
		for _, inst in CollectionService:GetTagged(LobbyConfig.Tags.DuelSlotPad) do
			if inst:IsA("BasePart") and inst.Name == "ClaimPad" and inst:IsDescendantOf(existing) then
				local idx = inst:GetAttribute("BC_DuelSlot")
				if typeof(idx) == "number" then
					rememberPad(idx, inst)
				end
			end
		end
		LobbyBuilder.bindNeonStrips()
		return existing
	end
	if existing then
		existing:Destroy()
	end

	LobbyUtil.resetBudget()
	local root = Instance.new("Model")
	root.Name = LobbyConfig.Name
	root.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	root:SetAttribute("DisplayName", LobbyConfig.DisplayName)
	root:SetAttribute("ArtPass", LobbyConfig.ArtPass)
	root:SetAttribute("BC_LobbyOrigin", LobbyConfig.Origin)
	root:SetAttribute("BC_Layout", LobbyConfig.Layout)
	root:SetAttribute("OffsetX", LobbyConfig.Origin.X)
	root:SetAttribute("OffsetZ", LobbyConfig.Origin.Z)
	root:SetAttribute("BC_DuelSlotCount", #LobbyConfig.DuelSlots)
	root:SetAttribute("BC_BayZ", H.BayZ)
	root.Parent = parent

	pcall(function()
		workspace.StreamingEnabled = true
	end)

	buildCourt(root)
	buildSpawns(root)
	buildDuelSlots(root)
	buildLegacyQueuePads(root)

	local primary = root:FindFirstChild("Deck", true)
	if primary and primary:IsA("BasePart") then
		root.PrimaryPart = primary
	end

	built = root
	LobbyBuilder.applyLobbyLighting()
	LobbyBuilder.bindNeonStrips()
	LobbyUtil.warnBudget("ConcordHall")

	return root
end


--[[
	Attache NeonFx sur tous les BC_NeonStrip du hall (idempotent, budget restant).
]]
function LobbyBuilder.bindNeonStrips()
	local root = built
	if not root then
		return
	end
	local hooks = NeonFx.hooksFromCounters(LobbyUtil.remainingEmitters, LobbyUtil.noteEmitter)
	local n = NeonFx.bindTaggedStrips(root, hooks, NeonFx.HallStripEmitterCap)
	if not neonBound then
		neonBound = true
		NeonFx.watchTaggedStrips(root, hooks, NeonFx.HallStripEmitterCap)
	end
	if n > 0 then
		print(string.format("[BladeConcord] NeonFx strips bound=%d remainingEmitters=%d", n, LobbyUtil.remainingEmitters()))
	end
end

function LobbyBuilder.bindQueuePads(enqueueFn: (Player, string) -> ())
	if padBound then
		return
	end
	padBound = true
	local debounce: { [Player]: number } = {}

	local function tryEnqueue(player: Player, modeAttr: any)
		if typeof(modeAttr) ~= "string" then
			return
		end
		if modeAttr ~= "Casual" and modeAttr ~= "Ranked" then
			return
		end
		local now = os.clock()
		if debounce[player] and now - debounce[player] < 1.2 then
			return
		end
		debounce[player] = now
		enqueueFn(player, modeAttr)
	end

	local function hookPad(pad: BasePart)
		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				tryEnqueue(player, pad:GetAttribute("BC_QueueMode"))
			end)
		end
		pad.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				tryEnqueue(player, pad:GetAttribute("BC_QueueMode"))
			end
		end)
	end

	local function scan(root: Instance)
		for _, inst in CollectionService:GetTagged(LobbyConfig.Tags.QueuePad) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(root) then
				hookPad(inst)
			end
		end
	end

	if built then
		scan(built)
	end
	CollectionService:GetInstanceAddedSignal(LobbyConfig.Tags.QueuePad):Connect(function(inst)
		if inst:IsA("BasePart") and built and inst:IsDescendantOf(built) then
			hookPad(inst)
		end
	end)
end

function LobbyBuilder.bindDuelSlots(claimFn: (Player, number) -> ())
	if duelBound then
		return
	end
	duelBound = true
	local debounce: { [Player]: number } = {}

	local function tryClaim(player: Player, slotAttr: any)
		if typeof(slotAttr) ~= "number" then
			return
		end
		local slotIndex = slotAttr :: number
		if slotIndex < 1 or slotIndex > #LobbyConfig.DuelSlots then
			return
		end
		local now = os.clock()
		if debounce[player] and now - debounce[player] < 1.2 then
			return
		end
		debounce[player] = now
		claimFn(player, slotIndex)
	end

	local function hookPad(pad: BasePart)
		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				tryClaim(player, pad:GetAttribute("BC_DuelSlot"))
			end)
		end
		pad.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				tryClaim(player, pad:GetAttribute("BC_DuelSlot"))
			end
		end)
	end

	local function scan(root: Instance)
		for _, inst in CollectionService:GetTagged(LobbyConfig.Tags.DuelSlotPad) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(root) then
				hookPad(inst)
			end
		end
	end

	if built then
		scan(built)
	end
	CollectionService:GetInstanceAddedSignal(LobbyConfig.Tags.DuelSlotPad):Connect(function(inst)
		if inst:IsA("BasePart") and built and inst:IsDescendantOf(built) then
			hookPad(inst)
		end
	end)
end

function LobbyBuilder.getBuilt(): Model?
	return built
end

return LobbyBuilder
