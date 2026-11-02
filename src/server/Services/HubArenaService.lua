--!strict
-- Two players stepping onto a ring's pads starts a local duel in that Hub arena.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MatchService = require(script.Parent.MatchService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local Net = require(ReplicatedStorage:WaitForChild("EtherBlades").Net)

type ArenaQueue = {
	Slot: number,
	Model: Model,
	Pads: { BasePart },
	Players: { Player? },
	Busy: boolean,
	LastAttempt: number,
}

local HubArenaService = {}
HubArenaService.Priority = 45

local queues: { ArenaQueue } = {}

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	return if character then Players:GetPlayerFromCharacter(character) else nil
end

local function onPadTouched(queue: ArenaQueue, padIndex: number, hit: BasePart)
	if queue.Busy then
		return
	end
	local player = playerFromHit(hit)
	if not player or player:GetAttribute("EB_InMatch") == true then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	for index, occupant in queue.Players do
		if occupant == player then
			if index == padIndex then
				return
			end
			queue.Players[index] = nil
		end
	end
	if queue.Players[padIndex] then
		return
	end
	queue.Players[padIndex] = player
end

local function standingOn(player: Player, pad: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local localPosition = pad.CFrame:PointToObjectSpace(root.Position)
	return math.abs(localPosition.X) <= pad.Size.X / 2 + 1
		and math.abs(localPosition.Z) <= pad.Size.Z / 2 + 1
		and localPosition.Y >= pad.Size.Y / 2
		and localPosition.Y <= 8
end

local function notify(player: Player, message: string, kind: string)
	if player.Parent == Players then
		Net.event("Notify"):FireClient(player, { Text = message, Kind = kind })
	end
end

local function tryStart(queue: ArenaQueue)
	local a, b = queue.Players[1], queue.Players[2]
	if queue.Busy or not a or not b or a == b or os.clock() - queue.LastAttempt < 2 then
		return
	end
	queue.LastAttempt = os.clock()

	if MatchmakingService.isQueued(a) or MatchmakingService.isQueued(b) then
		notify(a, "Quitte ta file d'attente avant d'utiliser une arène.", "Info")
		notify(b, "Quitte ta file d'attente avant d'utiliser une arène.", "Info")
		return
	end

	queue.Busy = true
	local ok, reason = MatchService.start(a, b, "Casual", { ArenaSlot = queue.Slot })
	queue.Players[1] = nil
	queue.Players[2] = nil
	queue.Busy = false
	if not ok then
		local message = reason or "Ce duel ne peut pas commencer."
		notify(a, message, "Error")
		notify(b, message, "Error")
	end
end

function HubArenaService.start()
	local hub = Workspace:FindFirstChild("Hub") or Workspace:WaitForChild("Hub", 20)
	local rings = hub and hub:FindFirstChild("DuelRings")
	if not rings then
		warn("[EtherBlades] Workspace.Hub.DuelRings absent : les pads de duel sont désactivés.")
		return
	end

	for slot = 1, 6 do
		local model = rings:FindFirstChild(string.format("LiveArena_%d", slot))
		local padA = model and model:FindFirstChild("EntryPadA", true)
		local padB = model and model:FindFirstChild("EntryPadB", true)
		if model and model:IsA("Model") and padA and padA:IsA("BasePart") and padB and padB:IsA("BasePart") then
			local queue: ArenaQueue = {
				Slot = slot,
				Model = model,
				Pads = { padA, padB },
				Players = {},
				Busy = false,
				LastAttempt = -math.huge,
			}
			table.insert(queues, queue)
			for index, pad in queue.Pads do
				pad.Touched:Connect(function(hit: BasePart)
					onPadTouched(queue, index, hit)
					tryStart(queue)
				end)
			end
		else
			warn(string.format("[EtherBlades] LiveArena_%d ou ses pads sont incomplets.", slot))
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, queue in queues do
			for index, occupant in queue.Players do
				if occupant == player then
					queue.Players[index] = nil
				end
			end
		end
	end)

	while true do
		task.wait(0.25)
		for _, queue in queues do
			for index, player in queue.Players do
				if not player.Parent or not standingOn(player, queue.Pads[index]) then
					queue.Players[index] = nil
				end
			end
			tryStart(queue)
		end
	end
end

return HubArenaService
