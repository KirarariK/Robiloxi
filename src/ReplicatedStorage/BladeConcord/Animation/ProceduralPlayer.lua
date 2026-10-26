--!strict
--[[
	Applique les mêmes courbes KeyframeFactory via Motor6D.Transform
	quand RegisterKeyframeSequence / AnimationId n'est pas dispo (live sans upload).
	Compatible R15 + HiltGrip (SaberMotor).
]]

local RunService = game:GetService("RunService")

local AnimationSets = require(script.Parent:WaitForChild("AnimationSets"))
local KeyframeFactory = require(script.Parent:WaitForChild("KeyframeFactory"))
local AnimationRegistry = require(script.Parent:WaitForChild("AnimationRegistry"))

export type PlayHandle = {
	character: Model,
	setId: string,
	clipName: string,
	priority: number,
	looped: boolean,
	length: number,
	startClock: number,
	fadeIn: number,
	weight: number,
	stopped: boolean,
}

local ProceduralPlayer = {}

local JOINT_PARTS = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"HiltGrip",
	"LeftUpperArm",
	"LeftLowerArm",
}

-- Priorité numérique alignée skill (plus haut gagne)
local PRIORITY_RANK: { [Enum.AnimationPriority]: number } = {
	[Enum.AnimationPriority.Core] = 0,
	[Enum.AnimationPriority.Idle] = 1,
	[Enum.AnimationPriority.Movement] = 2,
	[Enum.AnimationPriority.Action] = 3,
	[Enum.AnimationPriority.Action2] = 4,
	[Enum.AnimationPriority.Action3] = 5,
	[Enum.AnimationPriority.Action4] = 6,
}

local activeByChar: { [Model]: { PlayHandle } } = {}
local motorCache: { [Model]: { [string]: Motor6D } } = {}
local bound = false

local function findMotors(character: Model): { [string]: Motor6D }
	local cached = motorCache[character]
	if cached then
		return cached
	end
	local map: { [string]: Motor6D } = {}
	for _, inst in character:GetDescendants() do
		if inst:IsA("Motor6D") and inst.Part1 then
			map[inst.Part1.Name] = inst
		end
	end
	motorCache[character] = map
	character.Destroying:Once(function()
		motorCache[character] = nil
		activeByChar[character] = nil
	end)
	return map
end

local function clearTransforms(character: Model)
	local motors = findMotors(character)
	for _, partName in JOINT_PARTS do
		local motor = motors[partName]
		if motor then
			motor.Transform = CFrame.new()
		end
	end
end

local function applyJoints(character: Model, joints: { [string]: CFrame }, weight: number)
	local motors = findMotors(character)
	local w = math.clamp(weight, 0, 1)
	for _, partName in JOINT_PARTS do
		local cf = joints[partName]
		local motor = motors[partName]
		if cf and motor then
			if w >= 0.99 then
				motor.Transform = cf
			else
				motor.Transform = CFrame.new():Lerp(cf, w)
			end
		end
	end
end

local function bindHeartbeat()
	if bound then
		return
	end
	bound = true
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for character, handles in activeByChar do
			if not character.Parent then
				activeByChar[character] = nil
				continue
			end
			-- Choisir handle priorité max non stopped
			local best: PlayHandle? = nil
			for _, h in handles do
				if h.stopped then
					continue
				end
				local elapsed = now - h.startClock
				local n = if h.length > 0 then elapsed / h.length else 1
				if not h.looped and n >= 1 then
					h.stopped = true
					continue
				end
				if not best or h.priority > best.priority then
					best = h
				elseif best and h.priority == best.priority and h.startClock > best.startClock then
					best = h
				end
			end

			-- Purge stopped
			local alive = {}
			for _, h in handles do
				if not h.stopped then
					table.insert(alive, h)
				end
			end
			activeByChar[character] = alive

			if not best then
				clearTransforms(character)
				continue
			end

			local elapsed = now - best.startClock
			local n = elapsed / best.length
			if best.looped then
				n = n % 1
			else
				n = math.clamp(n, 0, 1)
			end

			local fadeW = 1
			if best.fadeIn > 0 and elapsed < best.fadeIn then
				fadeW = elapsed / best.fadeIn
			end

			local setDef = AnimationSets.get(best.setId)
			if not setDef then
				continue
			end
			local joints = KeyframeFactory.samplePose(setDef, best.clipName :: AnimationSets.ClipName, n)
			applyJoints(character, joints, best.weight * fadeW)
		end
	end)
end

function ProceduralPlayer.play(
	character: Model,
	setId: string,
	clipName: string,
	fadeTime: number?,
	weight: number?
): PlayHandle?
	bindHeartbeat()
	AnimationRegistry.ensureBuilt()

	local clip = AnimationRegistry.getClip(setId, clipName)
	local setDef = AnimationSets.get(setId)
	if not setDef then
		return nil
	end

	local length = if clip then clip.lengthHint else 0.3
	local priorityEnum = if clip then clip.priority else setDef.style.priority
	local looped = if clip then clip.looped else (clipName == "Idle" or clipName == "Guard")

	-- Stop same-or-lower priority one-shots ; Idle remplacé
	local list = activeByChar[character]
	if not list then
		list = {}
		activeByChar[character] = list
	end
	local rank = PRIORITY_RANK[priorityEnum] or 3
	for _, h in list do
		if h.clipName == clipName or (not h.looped and h.priority <= rank) or (h.looped and rank >= h.priority) then
			if h.priority <= rank then
				h.stopped = true
			end
		end
	end

	local handle: PlayHandle = {
		character = character,
		setId = setId,
		clipName = clipName,
		priority = rank,
		looped = looped,
		length = length,
		startClock = os.clock(),
		fadeIn = fadeTime or 0.08,
		weight = weight or 1,
		stopped = false,
	}
	table.insert(list, handle)
	return handle
end

function ProceduralPlayer.stopAll(character: Model)
	local list = activeByChar[character]
	if not list then
		return
	end
	for _, h in list do
		h.stopped = true
	end
	clearTransforms(character)
end

function ProceduralPlayer.stopClip(character: Model, clipName: string)
	local list = activeByChar[character]
	if not list then
		return
	end
	for _, h in list do
		if h.clipName == clipName then
			h.stopped = true
		end
	end
end

return ProceduralPlayer
