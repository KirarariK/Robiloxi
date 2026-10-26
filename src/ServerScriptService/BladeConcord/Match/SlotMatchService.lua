--!strict
--[[
	Matchmaking par slot 1v1 — contrat World croiseur (2 pads devant baie).

	World pose les pads ; Combat ne touche PAS LobbyBuilder géométrie.
	API World :
	  LobbyBuilder.bindDuelSlots(claimFn) — claimFn(player, slotIndex)
	  Tag BC_DuelSlotPad · Attribute BC_DuelSlot = 1|2 seulement (MaxDuelSlots)

	Flux : claim → file slot-scoped (max 2) → MatchService.tryStartPair →
	  une des 8 grandes arènes (ArenaService.pickMatchArena).
	Solo (#Players == 1) : après SlotSoloBotDelay → ConcordBot (demo Studio).

	Feedback attrs écrits sur ClaimPad :
	  BC_SlotClaimCount, BC_SlotOccupantA/B, BC_SlotStatus
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))

local MatchService = require(script.Parent:WaitForChild("MatchService"))

local SlotMatchService = {}

export type SlotState = {
	index: number,
	claimers: { Player },
	soloTimer: number?,
}

local slots: { [number]: SlotState } = {}
local playerSlot: { [Player]: number } = {}
local started = false
local LobbyBuilder: any = nil

local function maxSlots(): number
	return CombatConfig.Match.MaxDuelSlots or 2
end

local function getLobbyBuilder()
	if not LobbyBuilder then
		LobbyBuilder = require(script.Parent.Parent:WaitForChild("Lobby"):WaitForChild("LobbyBuilder"))
	end
	return LobbyBuilder
end

local function ensureSlot(index: number): SlotState
	local state = slots[index]
	if not state then
		state = { index = index, claimers = {}, soloTimer = nil }
		slots[index] = state
	end
	return state
end

local function padFor(index: number): BasePart?
	local lb = getLobbyBuilder()
	if lb.getDuelSlotPad then
		return lb.getDuelSlotPad(index)
	end
	return nil
end

local function writePadAttrs(state: SlotState)
	local pad = padFor(state.index)
	if not pad then
		return
	end
	local a = state.claimers[1]
	local b = state.claimers[2]
	pad:SetAttribute("BC_SlotClaimCount", #state.claimers)
	pad:SetAttribute("BC_SlotOccupantA", if a then a.UserId else 0)
	pad:SetAttribute("BC_SlotOccupantB", if b then b.UserId else 0)
	local status = "Open"
	if #state.claimers >= 2 then
		status = "Full"
	elseif #state.claimers == 1 then
		status = "Waiting"
	end
	pad:SetAttribute("BC_SlotStatus", status)
end

local function removeFromSlot(player: Player)
	local idx = playerSlot[player]
	if not idx then
		return
	end
	playerSlot[player] = nil
	local state = slots[idx]
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
	for _, p in { p1, p2 } do
		playerSlot[p] = nil
	end
	table.clear(state.claimers)
	state.soloTimer = nil
	local pad = padFor(state.index)
	if pad then
		pad:SetAttribute("BC_SlotStatus", "InMatch")
		pad:SetAttribute("BC_SlotClaimCount", 0)
		pad:SetAttribute("BC_SlotOccupantA", 0)
		pad:SetAttribute("BC_SlotOccupantB", 0)
	end
	-- tryStartPair → pickMatchArena (pool 8)
	MatchService.tryStartPair(p1, p2, "Casual")
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

--[[ Claim depuis World bindDuelSlots(player, slotIndex) — indices 1..MaxDuelSlots seulement. ]]
function SlotMatchService.claimByIndex(player: Player, slotIndex: number): boolean
	if MatchService.getPhase() ~= "Lobby" then
		return false
	end
	if MatchService.isPlayerQueued(player) then
		return false
	end
	if typeof(slotIndex) ~= "number" then
		return false
	end
	local idx = math.floor(slotIndex)
	local maxS = maxSlots()
	if idx < 1 or idx > maxS then
		return false
	end

	local state = ensureSlot(idx)

	for _, p in state.claimers do
		if p == player then
			writePadAttrs(state)
			return true
		end
	end

	if playerSlot[player] and playerSlot[player] ~= idx then
		removeFromSlot(player)
	end

	if #state.claimers >= 2 then
		return false
	end

	table.insert(state.claimers, player)
	playerSlot[player] = idx
	writePadAttrs(state)

	if #state.claimers >= 2 then
		state.soloTimer = nil
		tryLaunch(state)
		return true
	end

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

function SlotMatchService.step(dt: number)
	if MatchService.getPhase() ~= "Lobby" then
		return
	end
	for _, state in slots do
		if state.index > maxSlots() then
			continue
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
end

function SlotMatchService.onReturnedToLobby()
	clearAllClaims()
end

function SlotMatchService.getPlayerSlotIndex(player: Player): number?
	return playerSlot[player]
end

function SlotMatchService.getMaxSlots(): number
	return maxSlots()
end

function SlotMatchService.start()
	if started then
		return
	end
	started = true

	-- Pré-crée les 2 files slot
	for i = 1, maxSlots() do
		ensureSlot(i)
	end

	local lb = getLobbyBuilder()
	lb.bindDuelSlots(function(player: Player, slotIndex: number)
		SlotMatchService.claimByIndex(player, slotIndex)
	end)

	Players.PlayerRemoving:Connect(SlotMatchService.onPlayerRemoving)

	if RunService:IsStudio() then
		print(
			string.format(
				"[BladeConcord] SlotMatchService: slots 1–%d → pool %d arènes",
				maxSlots(),
				CombatConfig.Match.MatchArenaCount or 8
			)
		)
	end
end

return SlotMatchService
