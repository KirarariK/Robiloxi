--!strict
--[[
	Concord Lobby — croiseur intérieur + baie Glass + 2 slots (ArtPass 9).

	API :
	  ensure / getSpawnCFrame / applyLobbyLighting
	  bindDuelSlots(claimFn) — claimFn(player, slotIndex 1|2)
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

local function neonStrip(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, withLight: boolean?)
	local p = LobbyUtil.part(name, size, cf, color, parent, Enum.Material.Neon, {
		canCollide = false,
		castShadow = false,
		transparency = 0.15,
	})
	if p then
		LobbyProps.attachNeonStrip(p, color)
		if withLight then
			LobbyUtil.pointLight(p, color, 0.7, 18)
		end
	end
	return p
end

local function buildCruiserHull(root: Model)
	local hull = LobbyUtil.model("CruiserHull", root, "Hall")
	local w = H.Width
	local len = H.Length
	local h = H.Height
	local midZ = (H.SpawnLocal.Z + H.BayZ) * 0.5

	-- Sol intérieur
	LobbyUtil.part(
		"Deck",
		Vector3.new(w, 2, len),
		LobbyUtil.cf(Vector3.new(0, -1, midZ)),
		C.Hull,
		hull,
		Enum.Material.Metal,
		{ reflectance = 0.08 }
	)
	LobbyUtil.part(
		"DeckInlay",
		Vector3.new(w * 0.55, 0.25, len * 0.92),
		LobbyUtil.cf(Vector3.new(0, 0.2, midZ)),
		C.HullLite,
		hull,
		Enum.Material.Metal,
		{ reflectance = 0.12, canCollide = false }
	)
	-- Liserés Focus / Dawn le long de l’allée
	neonStrip(
		hull,
		"StripL",
		Vector3.new(0.35, 0.2, len * 0.9),
		LobbyUtil.cf(Vector3.new(-w * 0.22, 0.35, midZ)),
		C.Focus,
		false
	)
	neonStrip(
		hull,
		"StripR",
		Vector3.new(0.35, 0.2, len * 0.9),
		LobbyUtil.cf(Vector3.new(w * 0.22, 0.35, midZ)),
		C.Dawn,
		false
	)

	-- Parois Metal
	local wallH = h
	LobbyUtil.part(
		"WallL",
		Vector3.new(2.5, wallH, len),
		LobbyUtil.cf(Vector3.new(-w * 0.5, wallH * 0.5, midZ)),
		C.MetalDark,
		hull,
		Enum.Material.Metal,
		{ reflectance = 0.15 }
	)
	LobbyUtil.part(
		"WallR",
		Vector3.new(2.5, wallH, len),
		LobbyUtil.cf(Vector3.new(w * 0.5, wallH * 0.5, midZ)),
		C.MetalDark,
		hull,
		Enum.Material.Metal,
		{ reflectance = 0.15 }
	)
	-- Plafond
	LobbyUtil.part(
		"Ceiling",
		Vector3.new(w + 4, 2, len),
		LobbyUtil.cf(Vector3.new(0, h + 0.5, midZ)),
		C.Hull,
		hull,
		Enum.Material.Metal,
		{ reflectance = 0.1 }
	)
	-- Strips plafond néon
	for i = 0, 5 do
		local z = H.SpawnLocal.Z - 12 - i * 22
		neonStrip(
			hull,
			"CeilNeon" .. i,
			Vector3.new(w * 0.7, 0.3, 0.5),
			LobbyUtil.cf(Vector3.new(0, h - 0.8, z)),
			if i % 2 == 0 then C.Focus else C.Arcane,
			i == 1 or i == 3
		)
	end
	-- Strips muraux verticaux
	for i = 0, 6 do
		local z = H.SpawnLocal.Z - 8 - i * 18
		neonStrip(
			hull,
			"WallNeonL" .. i,
			Vector3.new(0.3, h * 0.7, 0.3),
			LobbyUtil.cf(Vector3.new(-w * 0.5 + 1.6, h * 0.4, z)),
			C.Dusk,
			false
		)
		neonStrip(
			hull,
			"WallNeonR" .. i,
			Vector3.new(0.3, h * 0.7, 0.3),
			LobbyUtil.cf(Vector3.new(w * 0.5 - 1.6, h * 0.4, z)),
			C.Dawn,
			false
		)
	end

	-- Cloison arrière (sud, derrière spawn)
	LobbyUtil.part(
		"BulkheadAft",
		Vector3.new(w + 4, wallH, 3),
		LobbyUtil.cf(Vector3.new(0, wallH * 0.5, H.SpawnLocal.Z + 28)),
		C.Metal,
		hull,
		Enum.Material.Metal,
		{ reflectance = 0.12 }
	)

	-- Piliers structure
	for _, x in { -18, 18 } do
		for i = 0, 4 do
			local z = 20 - i * 28
			LobbyUtil.part(
				"Rib",
				Vector3.new(2, h - 2, 2),
				LobbyUtil.cf(Vector3.new(x, h * 0.45, z)),
				C.Steel,
				hull,
				Enum.Material.Metal,
				{ reflectance = 0.2 }
			)
		end
	end

	local titleHost = LobbyUtil.part(
		"TitleHost",
		Vector3.new(1, 1, 1),
		LobbyUtil.cf(Vector3.new(0, 10, 48)),
		C.Gold,
		hull,
		Enum.Material.ForceField,
		{ transparency = 1, canCollide = false }
	)
	if titleHost then
		LobbyUtil.billboard(titleHost, "CONCORD HALL", C.GoldLite, Vector2.new(280, 40), 0)
	end
end

local function buildGlassBay(root: Model)
	local bay = LobbyUtil.model("ObservationBay", root, "Bay")
	local z = H.BayZ
	local bw = H.BayWidth
	local bh = H.BayHeight

	-- Cadre Metal
	LobbyUtil.part(
		"BayFrameL",
		Vector3.new(3, bh + 4, 4),
		LobbyUtil.cf(Vector3.new(-bw * 0.5, bh * 0.5 + 1, z)),
		C.Metal,
		bay,
		Enum.Material.Metal,
		{ reflectance = 0.25 }
	)
	LobbyUtil.part(
		"BayFrameR",
		Vector3.new(3, bh + 4, 4),
		LobbyUtil.cf(Vector3.new(bw * 0.5, bh * 0.5 + 1, z)),
		C.Metal,
		bay,
		Enum.Material.Metal,
		{ reflectance = 0.25 }
	)
	LobbyUtil.part(
		"BayFrameTop",
		Vector3.new(bw + 6, 3, 4),
		LobbyUtil.cf(Vector3.new(0, bh + 2.5, z)),
		C.Metal,
		bay,
		Enum.Material.Metal,
		{ reflectance = 0.2 }
	)
	LobbyUtil.part(
		"BaySill",
		Vector3.new(bw + 4, 1.5, 5),
		LobbyUtil.cf(Vector3.new(0, 0.75, z + 1)),
		C.HullLite,
		bay,
		Enum.Material.Metal
	)

	-- Immense baie Glass (spectate arènes)
	local glass = LobbyUtil.part(
		"BayGlass",
		Vector3.new(bw, bh, 1.2),
		LobbyUtil.cf(Vector3.new(0, bh * 0.5 + 1.2, z)),
		C.Glass,
		bay,
		Enum.Material.Glass,
		{ canCollide = true, transparency = 0.35, reflectance = 0.45 }
	)
	if glass then
		glass:SetAttribute("BC_ZoneId", "Bay")
		LobbyUtil.billboard(glass, "BAIE D'OBSERVATION", C.Focus, Vector2.new(260, 32), 14)
		LobbyUtil.pointLight(glass, C.Focus, 0.5, 24)
	end

	-- Montants Glass
	for i = -2, 2 do
		if i ~= 0 then
			LobbyUtil.part(
				"Mullion",
				Vector3.new(0.6, bh, 1.4),
				LobbyUtil.cf(Vector3.new(i * (bw / 5), bh * 0.5 + 1.2, z)),
				C.MetalDark,
				bay,
				Enum.Material.Metal,
				{ reflectance = 0.15 }
			)
		end
	end

	neonStrip(
		bay,
		"BayNeonTop",
		Vector3.new(bw * 0.9, 0.35, 0.35),
		LobbyUtil.cf(Vector3.new(0, bh + 0.8, z + 1.5)),
		C.Focus,
		true
	)
	neonStrip(
		bay,
		"BayNeonDawn",
		Vector3.new(bw * 0.4, 0.3, 0.3),
		LobbyUtil.cf(Vector3.new(-bw * 0.25, 2, z + 1.5)),
		C.Dawn,
		false
	)
	neonStrip(
		bay,
		"BayNeonDusk",
		Vector3.new(bw * 0.4, 0.3, 0.3),
		LobbyUtil.cf(Vector3.new(bw * 0.25, 2, z + 1.5)),
		C.Dusk,
		false
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

local function buildDuelSlots(root: Model)
	local folder = LobbyUtil.model("DuelSlots", root, "DuelSlots")
	duelPadsByIndex = {}
	-- Exactement 2 slots devant la baie
	for i, spec in LobbyConfig.DuelSlots do
		local pad = LobbyProps.duelSlot(folder, {
			index = spec.index,
			x = spec.x,
			z = spec.z,
			side = spec.side,
			color = colorForKey(spec.colorKey),
		}, true)
		if pad then
			duelPadsByIndex[spec.index] = pad
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
		for _, inst in CollectionService:GetTagged(LobbyConfig.Tags.DuelSlotPad) do
			if inst:IsA("BasePart") and inst.Name == "ClaimPad" and inst:IsDescendantOf(existing) then
				local idx = inst:GetAttribute("BC_DuelSlot")
				if typeof(idx) == "number" then
					duelPadsByIndex[idx] = inst
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

	buildCruiserHull(root)
	buildGlassBay(root)
	buildSpawns(root)
	buildDuelSlots(root)
	buildLegacyQueuePads(root)

	local primary = root:FindFirstChild("BayGlass", true)
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
