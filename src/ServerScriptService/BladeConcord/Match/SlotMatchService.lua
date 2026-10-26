--!strict
--[[
	Matchmaking par slot 1v1 — contrat World lobby.

	Parts taguées `BC_DuelSlot` (World pose les pads ; Combat ne touche pas la géométrie).
	Attributs lus :
	  BC_SlotId      number|string  — id unique du pad (requis)
	  BC_QueueMode   "Casual"|"Ranked"  — défaut Casual
	Attributs écrits (feedback monde / UI) :
	  BC_SlotClaimCount   number
	  BC_SlotOccupantA    number userId (0 si vide)
	  BC_SlotOccupantB    number userId (0 si vide)
	  BC_SlotStatus       "Open"|"Waiting"|"Full"|"InMatch"

	Flux : claim (ProximityPrompt / Touched / stand-on) → file slot-scoped →
	  2 joueurs → MatchService.tryStartPair → grande arène (rotation).
	Solo Studio (#Players == 1) : après SlotSoloBotDelay → ConcordBot (demo).
	Sinon : file jusqu’au 2e joueur sur le même slot.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))

local MatchService = require(script.Parent:WaitForChild("MatchService"))

local SlotMatchService = {}

local TAG = CombatConfig.Tags.DuelSlot
local LOBBY_SPAWN_TAG = CombatConfig.Tags.LobbySpawn

export type SlotState = {
	id: string,
	pad: BasePart,
	claimers: { Player },
	soloTimer: number?,
	hooks: { RBXScriptConnection },
}

local slots: { [string]: SlotState } = {}
local playerSlot: { [Player]: string } = {}
local debounce: { [Player]: number } = {}
local started = false

local function slotIdOf(pad: BasePart): string?
	local raw = pad:GetAttribute("BC_SlotId")
	if typeof(raw) == "number" then
		return tostring(raw)
	elseif typeof(raw) == "string" and raw ~= "" then
		return raw
	end
	-- Fallback : Name si World n’a pas encore posé BC_SlotId
	if pad.Name ~= "" then
		return pad.Name
	end
	return nil
end

local function modeOf(pad: BasePart): CombatTypes.MatchMode
	local m = pad:GetAttribute("BC_QueueMode")
	if m == "Ranked" then
		return "Ranked"
	end
	return "Casual"
end

local function writePadAttrs(state: SlotState)
	local a = state.claimers[1]
	local b = state.claimers[2]
	state.pad:SetAttribute("BC_SlotClaimCount", #state.claimers)
	state.pad:SetAttribute("BC_SlotOccupantA", if a then a.UserId else 0)
	state.pad:SetAttribute("BC_SlotOccupantB", if b then b.UserId else 0)
	local status = "Open"
	if #state.claimers >= 2 then
		status = "Full"
	elseif #state.claimers == 1 then
		status = "Waiting"
	end
	state.pad:SetAttribute("BC_SlotStatus", status)
end

local function removeFromSlot(player: Player)
	local sid = playerSlot[player]
	if not sid then
		return
	end
	playerSlot[player] = nil
	local state = slots[sid]
	if not state then
		return
	end
	for i = #state.claimers, 1, -1 do
		if state.claimers[i] == player then
			table.remove(state.claimers, i)
		end
	end
	state.soloTimer = nil
	writePadAttrs(state)
end

local function clearAllClaims()
	for player in playerSlot do
		playerSlot[player] = nil
	end
	for _, state in slots do
		table.clear(state.claimers)
		state.soloTimer = nil
		writePadAttrs(state)
	end
end

local function tryLaunch(state: SlotState)
	if MatchService.getPhase() ~= "Lobby" then
		return
	end
	if #state.claimers < 2 then
		return
	end
	local p1 = state.claimers[1]
	local p2 = state.claimers[2]
	if not p1 or not p2 or p1.Parent ~= Players or p2.Parent ~= Players then
		return
	end
	local matchMode = modeOf(state.pad)
	-- Libérer claims avant start (évite re-trigger)
	for _, p in { p1, p2 } do
		playerSlot[p] = nil
	end
	table.clear(state.claimers)
	state.soloTimer = nil
	state.pad:SetAttribute("BC_SlotStatus", "InMatch")
	state.pad:SetAttribute("BC_SlotClaimCount", 0)
	state.pad:SetAttribute("BC_SlotOccupantA", 0)
	state.pad:SetAttribute("BC_SlotOccupantB", 0)
	MatchService.tryStartPair(p1, p2, matchMode)
end

local function trySoloBot(state: SlotState)
	if MatchService.getPhase() ~= "Lobby" then
		return
	end
	if #Players:GetPlayers() ~= 1 then
		return
	end
	local p = state.claimers[1]
	if not p or p.Parent ~= Players then
		return
	end
	playerSlot[p] = nil
	table.clear(state.claimers)
	state.soloTimer = nil
	writePadAttrs(state)
	MatchService.beginSoloPractice(p)
end

function SlotMatchService.claim(player: Player, pad: BasePart): boolean
	if MatchService.getPhase() ~= "Lobby" then
		return false
	end
	if MatchService.isPlayerQueued(player) then
		return false
	end
	local now = os.clock()
	if debounce[player] and now - debounce[player] < 0.8 then
		return false
	end
	debounce[player] = now

	local sid = slotIdOf(pad)
	if not sid then
		warn("[BladeConcord] BC_DuelSlot sans BC_SlotId:", pad:GetFullName())
		return false
	end

	local state = slots[sid]
	if not state then
		-- Pad vu via prompt avant scan complet
		SlotMatchService.watchPad(pad)
		state = slots[sid]
		if not state then
			return false
		end
	end

	-- Déjà claimé ce slot
	for _, p in state.claimers do
		if p == player then
			writePadAttrs(state)
			return true
		end
	end

	-- Quitter un autre slot
	if playerSlot[player] and playerSlot[player] ~= sid then
		removeFromSlot(player)
	end

	if #state.claimers >= 2 then
		return false
	end

	table.insert(state.claimers, player)
	playerSlot[player] = sid
	writePadAttrs(state)

	if #state.claimers >= 2 then
		state.soloTimer = nil
		tryLaunch(state)
		return true
	end

	-- Solo serveur : timer bot demo ; sinon file jusqu’au 2e
	if #Players:GetPlayers() == 1 then
		state.soloTimer = CombatConfig.Match.SlotSoloBotDelay or 2.5
	else
		state.soloTimer = nil
	end
	writePadAttrs(state)
	MatchService.broadcast()
	return true
end

function SlotMatchService.release(player: Player)
	removeFromSlot(player)
end

function SlotMatchService.watchPad(pad: BasePart)
	local sid = slotIdOf(pad)
	if not sid then
		return
	end
	if slots[sid] and slots[sid].pad == pad then
		return
	end
	-- Remplace si rebuild World
	if slots[sid] then
		for _, c in slots[sid].hooks do
			c:Disconnect()
		end
	end

	local state: SlotState = {
		id = sid,
		pad = pad,
		claimers = {},
		soloTimer = nil,
		hooks = {},
	}
	slots[sid] = state
	pad:SetAttribute("BC_SlotId", if typeof(pad:GetAttribute("BC_SlotId")) == "nil" then sid else pad:GetAttribute("BC_SlotId"))
	writePadAttrs(state)

	local function onClaim(player: Player)
		SlotMatchService.claim(player, pad)
	end

	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		table.insert(state.hooks, prompt.Triggered:Connect(onClaim))
	end

	table.insert(
		state.hooks,
		pad.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				onClaim(player)
			end
		end)
	)

	-- Stand-on : Heartbeat léger via step() — distance pad
end

function SlotMatchService.step(dt: number)
	if MatchService.getPhase() ~= "Lobby" then
		return
	end

	-- Stand-on proximity (si joueur reste sur le pad sans Touched fiable)
	for _, state in slots do
		if not state.pad.Parent then
			continue
		end
		local padPos = state.pad.Position
		local radius = math.max(state.pad.Size.X, state.pad.Size.Z) * 0.55 + 1.5
		for _, player in Players:GetPlayers() do
			if playerSlot[player] then
				continue
			end
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then
				continue
			end
			local flat = Vector3.new(hrp.Position.X - padPos.X, 0, hrp.Position.Z - padPos.Z)
			if flat.Magnitude <= radius and math.abs(hrp.Position.Y - padPos.Y) < 6 then
				SlotMatchService.claim(player, state.pad)
			end
		end

		if state.soloTimer and #state.claimers == 1 then
			state.soloTimer -= dt
			if state.soloTimer <= 0 then
				trySoloBot(state)
			end
		end
	end
end

function SlotMatchService.onPlayerRemoving(player: Player)
	removeFromSlot(player)
	debounce[player] = nil
end

function SlotMatchService.onReturnedToLobby()
	clearAllClaims()
end

function SlotMatchService.getPlayerSlotId(player: Player): string?
	return playerSlot[player]
end

--[[ Expose tag spawn allée pour ArenaService (World). ]]
function SlotMatchService.getLobbySpawnTag(): string
	return LOBBY_SPAWN_TAG
end

function SlotMatchService.start()
	if started then
		return
	end
	started = true

	local function scanExisting()
		for _, inst in CollectionService:GetTagged(TAG) do
			if inst:IsA("BasePart") then
				SlotMatchService.watchPad(inst)
			end
		end
	end

	scanExisting()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		if inst:IsA("BasePart") then
			SlotMatchService.watchPad(inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		if not inst:IsA("BasePart") then
			return
		end
		local sid = slotIdOf(inst)
		if sid and slots[sid] and slots[sid].pad == inst then
			for _, c in slots[sid].hooks do
				c:Disconnect()
			end
			for _, p in slots[sid].claimers do
				playerSlot[p] = nil
			end
			slots[sid] = nil
		end
	end)

	Players.PlayerRemoving:Connect(SlotMatchService.onPlayerRemoving)

	-- onReturnedToLobby appelé depuis MatchService.returnToLobby (évite écraser lobbyHook BotStub)

	if RunService:IsStudio() then
		print("[BladeConcord] SlotMatchService: BC_DuelSlot watch — solo Studio → bot après SlotSoloBotDelay")
	end
end

return SlotMatchService
