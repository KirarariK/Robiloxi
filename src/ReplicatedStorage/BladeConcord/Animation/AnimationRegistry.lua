--!strict
--[[
	Construit / cache les KeyframeSequences et les charge via Animator.
	Studio : KeyframeSequenceProvider:RegisterKeyframeSequence → AnimationId temporaire.
	Live sans upload : échec Register → CombatAnimator bascule sur ProceduralPlayer + SaberPose.
	Refs : create.roblox.com KeyframeSequenceProvider ; DevForum RegisterKeyframeSequence Studio-only.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")

local AnimationSets = require(script.Parent:WaitForChild("AnimationSets"))
local KeyframeFactory = require(script.Parent:WaitForChild("KeyframeFactory"))

export type LoadedClip = {
	setId: string,
	clipName: string,
	sequence: KeyframeSequence,
	animation: Animation?,
	animationId: string?,
	priority: Enum.AnimationPriority,
	looped: boolean,
	lengthHint: number,
}

local AnimationRegistry = {
	RegisterAvailable = false,
	Built = false,
}

local cache: { [string]: LoadedClip } = {}
local sequencesFolder: Folder? = nil

local function clipKey(setId: string, clipName: string): string
	return setId .. "::" .. clipName
end

local function estimateLength(seq: KeyframeSequence): number
	local length = 0
	for _, kf in seq:GetKeyframes() do
		if kf.Time > length then
			length = kf.Time
		end
	end
	return math.max(length, 0.05)
end

local function tryRegister(seq: KeyframeSequence): (string?, Animation?)
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	end)
	if not ok or typeof(result) ~= "string" or result == "" then
		return nil, nil
	end
	local anim = Instance.new("Animation")
	anim.Name = seq.Name
	anim.AnimationId = result
	return result, anim
end

function AnimationRegistry.ensureBuilt(): Folder
	if sequencesFolder and AnimationRegistry.Built then
		return sequencesFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = "BC_KeyframeSequences"
	-- Parenté sous ce ModuleScript pour debug Studio (non répliqué autrement)
	folder.Parent = script

	local registerOk = false
	local built = 0

	for _, setDef in AnimationSets.Sets do
		local setFolder = Instance.new("Folder")
		setFolder.Name = setDef.id
		setFolder.Parent = folder

		for _, clipName in AnimationSets.ClipNames do
			local seq = KeyframeFactory.buildClip(setDef, clipName)
			seq.Parent = setFolder

			local animId: string? = nil
			local anim: Animation? = nil
			local id, animation = tryRegister(seq)
			if id and animation then
				animId = id
				anim = animation
				animation.Parent = setFolder
				registerOk = true
			end

			cache[clipKey(setDef.id, clipName)] = {
				setId = setDef.id,
				clipName = clipName,
				sequence = seq,
				animation = anim,
				animationId = animId,
				priority = seq.Priority,
				looped = seq.Loop,
				lengthHint = estimateLength(seq),
			}
			built += 1
		end
	end

	AnimationRegistry.RegisterAvailable = registerOk
	AnimationRegistry.Built = true
	sequencesFolder = folder

	print(
		string.format(
			"[BladeConcord] AnimationRegistry: %d clips · %d sets · RegisterKeyframeSequence=%s (Studio=%s)",
			built,
			AnimationSets.Count,
			tostring(registerOk),
			tostring(RunService:IsStudio())
		)
	)

	return folder
end

function AnimationRegistry.getClip(setId: string, clipName: string): LoadedClip?
	AnimationRegistry.ensureBuilt()
	return cache[clipKey(setId, clipName)]
end

function AnimationRegistry.getAnimator(character: Model): Animator?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

function AnimationRegistry.loadTrack(character: Model, setId: string, clipName: string): AnimationTrack?
	local clip = AnimationRegistry.getClip(setId, clipName)
	if not clip or not clip.animation then
		return nil
	end
	local animator = AnimationRegistry.getAnimator(character)
	if not animator then
		return nil
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(clip.animation :: Animation)
	end)
	if not ok or typeof(track) ~= "Instance" then
		return nil
	end
	local animTrack = track :: AnimationTrack
	animTrack.Priority = clip.priority
	animTrack.Looped = clip.looped
	return animTrack
end

function AnimationRegistry.setCount(): number
	return AnimationSets.Count
end

return AnimationRegistry
