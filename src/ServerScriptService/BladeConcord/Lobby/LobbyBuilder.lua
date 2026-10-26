--!strict
--[[
	Concord Lobby — grande allée + slots 1v1 (ArtPass 8, réf ref-lobby).

	API World lobby :
	  LobbyBuilder.ensure(parentFolder) → Model ConcordLobby
	  LobbyBuilder.getSpawnCFrame() → début d’allée face −Z
	  LobbyBuilder.applyLobbyLighting()
	  LobbyBuilder.bindQueuePads(enqueueFn) — legacy Casual/Ranked (fin d’allée)
	  LobbyBuilder.bindDuelSlots(claimFn) — claimFn(player, slotIndex: number)
	  LobbyBuilder.getDuelSlotInfos() → { index, localPos, side, color }
	  LobbyBuilder.getDuelSlotPad(slotIndex) → BasePart?

	Contrat Combat / MatchService (à brancher côté Combat — pas ici) :
	  1. Joueur claim pad tagué BC_DuelSlotPad (Attribute BC_DuelSlot = N)
	     via ProximityPrompt ou Touched → bindDuelSlots callback.
	  2. MatchService maintient une file par slotIndex (max 2).
	  3. 2 joueurs sur le même slot → téléport arène 1v1 (rotation ArenaService) → BO3.
	  4. Solo Studio : option bot si 1 claim seul après délai (décision Match).
	  5. Retour lobby → getSpawnCFrame() / ensureLobby.
	  Ne pas confondre avec BC_QueueMode (pads Casual/Ranked legacy en fin d’allée).
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
local Z = LobbyConfig.Zones

local function colorForKey(key: string): Color3
	local c = (C :: any)[key]
	if typeof(c) == "Color3" then
		return c
	end
	return C.Focus
end

local function buildAlleyFloor(root: Model)
	local floor = LobbyUtil.model("AlleyFloor", root, "Alley")
	local halfLen = LobbyConfig.Alley.Length * 0.5
	local midZ = -halfLen + 20 -- allée centrée vers −Z depuis spawn

	-- Sol large (allée + bas-côtés pour rings)
	LobbyUtil.part(
		"Ground",
		Vector3.new(160, 2.2, LobbyConfig.Alley.Length + 40),
		LobbyUtil.cf(Vector3.new(0, -1.1, midZ)),
		C.Alley,
		floor,
		Enum.Material.Asphalt
	)
	-- Bande centrale (boulevard)
	LobbyUtil.part(
		"Boulevard",
		Vector3.new(LobbyConfig.Alley.Width, 0.35, LobbyConfig.Alley.Length),
		LobbyUtil.cf(Vector3.new(0, 0.15, midZ)),
		C.AlleyEdge,
		floor,
		Enum.Material.Slate,
		{ reflectance = 0.04 }
	)
	-- Liserés or allée
	for _, x in { -LobbyConfig.Alley.Width * 0.5, LobbyConfig.Alley.Width * 0.5 } do
		LobbyUtil.part(
			"AlleyEdge",
			Vector3.new(0.6, 0.25, LobbyConfig.Alley.Length),
			LobbyUtil.cf(Vector3.new(x, 0.35, midZ)),
			C.GoldDark,
			floor,
			Enum.Material.Metal,
			{ canCollide = false, reflectance = 0.25 }
		)
	end
	-- Marques au sol (segments)
	for i = 0, 10 do
		local z = 10 - i * 26
		LobbyUtil.part(
			"LaneMark" .. i,
			Vector3.new(4, 0.12, 8),
			LobbyUtil.cf(Vector3.new(0, 0.4, z)),
			C.Muted,
			floor,
			Enum.Material.Neon,
			{ canCollide = false, transparency = 0.65, castShadow = false }
		)
	end
	-- Escaliers / seuils spawn
	LobbyUtil.part(
		"SpawnPlaza",
		Vector3.new(48, 1.4, 36),
		LobbyUtil.cf(Vector3.new(0, 0.2, 18)),
		C.MarblePolish,
		floor,
		Enum.Material.Marble,
		{ reflectance = 0.1 }
	)
	local titleHost = LobbyUtil.part(
		"TitleHost",
		Vector3.new(1, 1, 1),
		LobbyUtil.cf(Vector3.new(0, 8, 24)),
		C.Gold,
		floor,
		Enum.Material.ForceField,
		{ transparency = 1, canCollide = false }
	)
	if titleHost then
		LobbyUtil.billboard(titleHost, "CONCORD HALL — ALLÉE 1v1", C.GoldLite, Vector2.new(340, 40), 0)
	end
end

local function buildAlleyDecor(root: Model)
	local decor = LobbyUtil.model("AlleyDecor", root)
	-- Piliers légers le long de l’allée (silhouette, pas temple dense)
	for i = 0, 7 do
		local z = -20 - i * 28
		for _, x in { -22, 22 } do
			LobbyUtil.part(
				"Pillar",
				Vector3.new(2.5, 18, 2.5),
				LobbyUtil.cf(Vector3.new(x, 9, z)),
				C.Ink700,
				decor,
				Enum.Material.Slate
			)
			LobbyUtil.part(
				"PillarCap",
				Vector3.new(3.2, 0.6, 3.2),
				LobbyUtil.cf(Vector3.new(x, 18.2, z)),
				C.GoldDark,
				decor,
				Enum.Material.Metal,
				{ canCollide = false, reflectance = 0.25 }
			)
		end
		-- Portique néon occasionnel (+ tag BC_NeonStrip pour VFX polish)
		if i % 2 == 0 then
			LobbyUtil.part(
				"Overhang",
				Vector3.new(44, 0.8, 2),
				LobbyUtil.cf(Vector3.new(0, 16, z)),
				C.Ink600,
				decor,
				Enum.Material.Metal
			)
			local strip = LobbyUtil.part(
				"OverhangNeon",
				Vector3.new(40, 0.25, 0.35),
				LobbyUtil.cf(Vector3.new(0, 15.5, z)),
				if i % 4 == 0 then C.Focus else C.Arcane,
				decor,
				Enum.Material.Neon,
				{ canCollide = false, transparency = 0.35, castShadow = false }
			)
			if strip then
				LobbyProps.attachNeonStrip(strip, strip.Color)
			end
		end
	end
	-- Fin d’allée : portail simple
	LobbyProps.grandArch(decor, Vector3.new(0, 0, -255), 40, 28, 0, C.Gold, true)
end

local function buildSpawns(root: Model)
	local spawns = LobbyUtil.model("Spawns", root, "Alley")
	local base = LobbyConfig.Alley.SpawnLocal
	local spots = {
		base,
		base + Vector3.new(6, 0, 4),
		base + Vector3.new(-6, 0, 4),
		base + Vector3.new(0, 0, 8),
	}
	for i, pos in spots do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = if i == 1 then "LobbySpawn" else ("LobbySpawnReserve" .. (i - 1))
		spawn.Size = Vector3.new(6, 1, 6)
		-- Face nord (−Z) vers les slots
		spawn.CFrame = LobbyUtil.cf(pos) * CFrame.Angles(0, math.rad(180), 0)
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 4
		spawn.Neutral = true
		spawn.Enabled = true
		spawn.Parent = spawns
	end
end

local function buildDuelSlots(root: Model)
	local folder = LobbyUtil.model("DuelSlots", root, "DuelSlots")
	duelPadsByIndex = {}
	for i, spec in LobbyConfig.DuelSlots do
		local pad = LobbyProps.duelSlot(folder, {
			index = spec.index,
			x = spec.x,
			z = spec.z,
			side = spec.side,
			color = colorForKey(spec.colorKey),
		}, i <= 4) -- lights sur les 4 premiers (budget)
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
	local platform = LobbyUtil.part(
		"Platform",
		Vector3.new(LobbyConfig.PadRadius * 2, 1, LobbyConfig.PadRadius * 2),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 0.5, 0)),
		C.Ink700,
		zone,
		Enum.Material.Slate
	)
	local pad = LobbyUtil.part(
		"QueuePad",
		Vector3.new(LobbyConfig.PadRadius * 1.6, 0.35, LobbyConfig.PadRadius * 1.6),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 1.1, 0)),
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
	if platform then
		LobbyUtil.pointLight(pad, color, 1.0, 20)
	end
	LobbyUtil.emitter(pad, "PadEnergy", {
		rate = 4,
		lifetime = NumberRange.new(1, 2),
		speed = NumberRange.new(1, 2.5),
		accel = Vector3.new(0, 5, 0),
		color = ColorSequence.new(color, C.Bone),
		lightEmission = 0.7,
	})
	LobbyUtil.billboard(pad, label, color, Vector2.new(200, 36), 5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QueuePrompt"
	prompt.ActionText = if mode == "Casual" then "File Amical" else "File Classé"
	prompt.ObjectText = label
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = pad
	local touch = LobbyUtil.part(
		"TouchVolume",
		Vector3.new(LobbyConfig.PadRadius * 2.2, 6, LobbyConfig.PadRadius * 2.2),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 3.5, 0)),
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
	-- Conservés en fin d’allée pour MatchService actuel (bindQueuePads)
	makeQueuePad(root, Z.PadCasual, "Casual", C.Focus, "AMICAL")
	makeQueuePad(root, Z.PadRanked, "Ranked", C.Gold, "CLASSÉ — Fair Kit")
end

function LobbyBuilder.getSpawnCFrame(): CFrame
	return LobbyUtil.cf(LobbyConfig.Alley.SpawnLocal) * CFrame.Angles(0, math.rad(180), 0)
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

function LobbyBuilder.ensure(parent: Instance): Model
	if built and built.Parent then
		return built
	end
	local existing = parent:FindFirstChild(LobbyConfig.Name)
	if existing and existing:IsA("Model") and existing:GetAttribute("ArtPass") == LobbyConfig.ArtPass then
		built = existing
		-- Rehydrate pad map
		duelPadsByIndex = {}
		for _, inst in CollectionService:GetTagged(LobbyConfig.Tags.DuelSlotPad) do
			if inst:IsA("BasePart") and inst.Name == "ClaimPad" and inst:IsDescendantOf(existing) then
				local idx = inst:GetAttribute("BC_DuelSlot")
				if typeof(idx) == "number" then
					duelPadsByIndex[idx] = inst
				end
			end
		end
		-- VFX : binders strips même si géométrie déjà posée (idempotent)
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
	root.Parent = parent

	pcall(function()
		workspace.StreamingEnabled = true
	end)

	buildAlleyFloor(root)
	buildAlleyDecor(root)
	buildSpawns(root)
	buildDuelSlots(root)
	buildLegacyQueuePads(root)

	local primary = root:FindFirstChild("Boulevard", true)
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
	Safe à rappeler après hydrate ArtPass existant.
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

--[[
	Combat / MatchService : passer claimFn(player, slotIndex).
	Débounce 1.2 s / joueur. Ne gère PAS la file — owner Match.
]]
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
		-- Évite double-hook TouchVolume + ClaimPad : claim sur Attribute présent
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
