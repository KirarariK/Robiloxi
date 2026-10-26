--!strict
--[[
	Applique les mêmes courbes KeyframeFactory via Motor6D.Transform
	quand RegisterKeyframeSequence / AnimationId n'est pas dispo.
	Refonte qualité : corps entier (LowerLegs + LeftHand), fades easeInOutCubic,
	crossfade previous→new — même feeling qu'un swing KeyframeSequence.
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
	fadeOut: number,
	weight: number,
	stopped: boolean,
	stopClock: number?,
	frozenJoints: { [string]: CFrame }?,
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
	"LeftHand",
	"RightUpperLeg",
	"RightLowerLeg",
	"LeftUpperLeg",
	"LeftLowerLeg",
}

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
local lastApplied: { [Model]: { [string]: CFrame } } = {}
local bound = false

local function easeInOutCubic(t: number): number
	local x = math.clamp(t, 0, 1)
	if x < 0.5 then
		return 4 * x * x * x
	end
	local u = -2 * x + 2
	return 1 - (u * u * u) / 2
end

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
		lastApplied[character] = nil
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
	lastApplied[character] = nil
end

local function applyJoints(character: Model, joints: { [string]: CFrame }, weight: number)
	local motors = findMotors(character)
	local w = math.clamp(weight, 0, 1)
	-- Courbe de poids : évite lerp linéaire robotique pendant fade
	local wEase = if w >= 0.99 or w <= 0.01 then w else easeInOutCubic(w)
	local applied: { [string]: CFrame } = {}
	for _, partName in JOINT_PARTS do
		local cf = joints[partName]
		local motor = motors[partName]
		if cf and motor then
			local final: CFrame
			if wEase >= 0.99 then
				final = cf
			else
				local from = (lastApplied[character] and lastApplied[character][partName]) or CFrame.new()
				final = from:Lerp(cf, wEase)
			end
			motor.Transform = final
			applied[partName] = final
		elseif motor and lastApplied[character] and lastApplied[character][partName] then
			local from = lastApplied[character][partName]
			motor.Transform = from:Lerp(CFrame.new(), 1 - wEase)
			applied[partName] = motor.Transform
		end
	end
	if wEase >= 0.99 then
		lastApplied[character] = applied
	elseif next(applied) ~= nil then
		lastApplied[character] = applied
	end
end

local function sampleHandle(h: PlayHandle, now: number): ({ [string]: CFrame }?, number)
	if h.stopped and h.frozenJoints then
		local fadeOut = h.fadeOut
		local stopAt = h.stopClock or now
		if fadeOut > 0 then
			local age = now - stopAt
			if age < fadeOut then
				local u = 1 - (age / fadeOut)
				return h.frozenJoints, easeInOutCubic(u)
			end
		end
		return nil, 0
	end
	if h.stopped then
		return nil, 0
	end

	local elapsed = now - h.startClock
	local n = if h.length > 0 then elapsed / h.length else 1
	if not h.looped and n >= 1 then
		local setDef = AnimationSets.get(h.setId)
		if setDef then
			h.frozenJoints = KeyframeFactory.samplePose(setDef, h.clipName :: AnimationSets.ClipName, 1)
		end
		h.stopped = true
		h.stopClock = now
		if h.fadeOut > 0 and h.frozenJoints then
			return h.frozenJoints, 1
		end
		return nil, 0
	end

	if h.looped then
		n = n % 1
	else
		n = math.clamp(n, 0, 1)
	end

	local fadeW = 1
	if h.fadeIn > 0 and elapsed < h.fadeIn then
		fadeW = easeInOutCubic(elapsed / h.fadeIn)
	end

	local setDef = AnimationSets.get(h.setId)
	if not setDef then
		return nil, 0
	end
	local joints = KeyframeFactory.samplePose(setDef, h.clipName :: AnimationSets.ClipName, n)
	return joints, h.weight * fadeW
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
				lastApplied[character] = nil
				continue
			end

			local best: PlayHandle? = nil
			local bestJoints: { [string]: CFrame }? = nil
			local bestW = 0
			local fading: { { joints: { [string]: CFrame }, w: number } } = {}

			for _, h in handles do
				local joints, w = sampleHandle(h, now)
				if joints and w > 0.001 then
					if h.stopped then
						table.insert(fading, { joints = joints, w = w })
					elseif not best or h.priority > best.priority then
						best = h
						bestJoints = joints
						bestW = w
					elseif best and h.priority == best.priority and h.startClock > best.startClock then
						best = h
						bestJoints = joints
						bestW = w
					end
				end
			end

			local alive = {}
			for _, h in handles do
				if not h.stopped then
					table.insert(alive, h)
				elseif h.fadeOut > 0 and h.stopClock and (now - h.stopClock) < h.fadeOut then
					table.insert(alive, h)
				end
			end
			activeByChar[character] = alive

			if not bestJoints then
				if #fading > 0 then
					local top = fading[1]
					for i = 2, #fading do
						if fading[i].w > top.w then
							top = fading[i]
						end
					end
					applyJoints(character, top.joints, top.w)
				else
					clearTransforms(character)
				end
				continue
			end

			local outJoints = bestJoints
			local outW = bestW
			if #fading > 0 and bestW < 0.99 then
				local top = fading[1]
				for i = 2, #fading do
					if fading[i].w > top.w then
						top = fading[i]
					end
				end
				local blended: { [string]: CFrame } = {}
				local keys: { [string]: boolean } = {}
				for k in top.joints do
					keys[k] = true
				end
				for k in bestJoints do
					keys[k] = true
				end
				local alpha = bestW / math.max(bestW + top.w * 0.85, 0.001)
				alpha = easeInOutCubic(math.clamp(alpha, 0, 1))
				for k in keys do
					local a = top.joints[k] or CFrame.new()
					local b = bestJoints[k] or CFrame.new()
					blended[k] = a:Lerp(b, alpha)
				end
				outJoints = blended
				outW = 1
			end

			applyJoints(character, outJoints, outW)
		end
	end)
end

local function freezeAndStop(h: PlayHandle, fadeOut: number)
	if h.stopped then
		return
	end
	local setDef = AnimationSets.get(h.setId)
	if setDef then
		local elapsed = os.clock() - h.startClock
		local n = if h.length > 0 then elapsed / h.length else 1
		if h.looped then
			n = n % 1
		else
			n = math.clamp(n, 0, 1)
		end
		h.frozenJoints = KeyframeFactory.samplePose(setDef, h.clipName :: AnimationSets.ClipName, n)
	elseif lastApplied[h.character] then
		h.frozenJoints = lastApplied[h.character]
	end
	h.stopped = true
	h.stopClock = os.clock()
	h.fadeOut = fadeOut
end

function ProceduralPlayer.play(
	character: Model,
	setId: string,
	clipName: string,
	fadeTime: number?,
	weight: number?,
	fadeOutTime: number?
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

	local list = activeByChar[character]
	if not list then
		list = {}
		activeByChar[character] = list
	end
	local rank = PRIORITY_RANK[priorityEnum] or 3
	local fadeIn = fadeTime or 0.08
	local fadeOut = fadeOutTime or fadeIn

	for _, h in list do
		if h.stopped then
			continue
		end
		local sameClip = h.clipName == clipName
		local replaceLooped = h.looped and rank >= h.priority
		local replaceOneShot = (not h.looped) and h.priority <= rank
		if sameClip or replaceLooped or replaceOneShot then
			if h.priority <= rank then
				freezeAndStop(h, fadeOut)
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
		fadeIn = fadeIn,
		fadeOut = fadeOut,
		weight = weight or 1,
		stopped = false,
		stopClock = nil,
		frozenJoints = nil,
	}
	table.insert(list, handle)
	return handle
end

function ProceduralPlayer.stopAll(character: Model, fadeOut: number?)
	local list = activeByChar[character]
	if not list then
		return
	end
	local fo = fadeOut or 0.1
	for _, h in list do
		freezeAndStop(h, fo)
	end
	if fo <= 0 then
		clearTransforms(character)
	end
end

function ProceduralPlayer.stopClip(character: Model, clipName: string, fadeOut: number?)
	local list = activeByChar[character]
	if not list then
		return
	end
	local fo = fadeOut or 0.1
	for _, h in list do
		if h.clipName == clipName and not h.stopped then
			freezeAndStop(h, fo)
		end
	end
end

return ProceduralPlayer
