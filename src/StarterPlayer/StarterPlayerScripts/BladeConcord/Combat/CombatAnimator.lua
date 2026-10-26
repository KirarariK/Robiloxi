--!strict
--[[
	Chemin principal animations combat : Animator:LoadAnimation (Studio Register)
	ou ProceduralPlayer (Motor6D.Transform) — SaberPose = fallback lame / visuals.
	Branche sur CombatState (Idle/Startup/Active/Recovery/Guard/Dodge/Dash/Focus/KO).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blade = ReplicatedStorage:WaitForChild("BladeConcord")
local Shared = Blade:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnimationSets = require(Blade:WaitForChild("Animation"):WaitForChild("AnimationSets"))
local AnimationRegistry = require(Blade:WaitForChild("Animation"):WaitForChild("AnimationRegistry"))
local ProceduralPlayer = require(Blade:WaitForChild("Animation"):WaitForChild("ProceduralPlayer"))

local SaberPose = require(script.Parent:WaitForChild("SaberPose"))

local CombatAnimator = {}

local lastKey: { [number]: string } = {}
local tracksByChar: { [Model]: { [string]: AnimationTrack } } = {}
local useAnimatorPath = false
local feintArmed: { [number]: boolean } = {}

local function resolveCharacter(userId: number): Model?
	if userId == -9001 then
		local bot = workspace:FindFirstChild("ConcordBot")
		if bot and bot:IsA("Model") then
			return bot
		end
		return nil
	end
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character or nil
end

local function trackCacheKey(setId: string, clipName: string): string
	return setId .. "::" .. clipName
end

local function getOrLoadTrack(character: Model, setId: string, clipName: string): AnimationTrack?
	if not useAnimatorPath then
		return nil
	end
	local bag = tracksByChar[character]
	if not bag then
		bag = {}
		tracksByChar[character] = bag
		character.Destroying:Once(function()
			tracksByChar[character] = nil
		end)
	end
	local key = trackCacheKey(setId, clipName)
	local existing = bag[key]
	if existing then
		return existing
	end
	local track = AnimationRegistry.loadTrack(character, setId, clipName)
	if track then
		bag[key] = track
	end
	return track
end

local function fadeTimesFor(clipName: string, actionId: string): (number, number)
	if actionId == "Active" then
		return 0.04, 0.08
	elseif actionId == "Startup" then
		return 0.1, 0.12
	elseif actionId == "Recovery" then
		return 0.08, 0.12
	elseif actionId == "Guard" or actionId == "Idle" then
		return 0.12, 0.15
	elseif actionId == "Dodge" or actionId == "Dash" then
		return 0.05, 0.08
	end
	return 0.08, 0.1
end

local function stopCompeting(character: Model, keepLooped: boolean?)
	local bag = tracksByChar[character]
	if not bag then
		return
	end
	for _, track in bag do
		if track.IsPlaying then
			if keepLooped and track.Looped then
				-- laissera le blend écraser via priorité
			else
				if not track.Looped then
					track:Stop(0.08)
				end
			end
		end
	end
end

local function playClip(character: Model, setId: string, clipName: string, actionId: string): boolean
	local fadeIn, _fadeOut = fadeTimesFor(clipName, actionId)
	local track = getOrLoadTrack(character, setId, clipName)
	if track then
		stopCompeting(character, clipName == "Idle" or clipName == "Guard")
		-- Stop other looped at same priority when switching Idle↔Guard
		local bag = tracksByChar[character]
		if bag then
			for key, t in bag do
				if t ~= track and t.IsPlaying and t.Looped then
					t:Stop(fadeIn)
				end
			end
		end
		track:Play(fadeIn, 1, 1)
		return true
	end

	-- Procedural path (live / Register indisponible)
	ProceduralPlayer.play(character, setId, clipName, fadeIn, 1)
	return true
end

local function applyState(userId: number, snap: any)
	local actionId = tostring(snap.actionId or "Idle")
	local attackKind = if typeof(snap.attackKind) == "string" then snap.attackKind else nil
	local formId = if typeof(snap.formId) == "string" then snap.formId else nil
	local formRarity = if typeof(snap.formRarity) == "string" then snap.formRarity else nil

	-- Feinte : Startup Light → Guard rapide
	if actionId == "Guard" and feintArmed[userId] then
		feintArmed[userId] = false
		local setDef = AnimationSets.get("Concord_FeintSnap")
		local character = resolveCharacter(userId)
		if setDef and character then
			SaberPose.applyVisuals(character, actionId, attackKind)
			playClip(character, setDef.id, "Feint", actionId)
			-- Motor fallback si besoin de C1 lame
			if not useAnimatorPath then
				-- Procedural déjà applique HiltGrip Transform
			else
				-- Animator drive joints ; SaberPose motor C1 idle
				SaberPose.applyMotorFallback(character, "Guard", attackKind)
			end
			return
		end
	end
	if actionId == "Startup" and attackKind == "Light" then
		feintArmed[userId] = true
	elseif actionId ~= "Startup" and actionId ~= "Guard" then
		feintArmed[userId] = false
	end

	local setDef, clipName = AnimationSets.resolveForSnapshot({
		actionId = actionId,
		attackKind = attackKind,
		formId = formId,
		formRarity = formRarity,
		flags = snap.flags,
	})

	-- Heavy universal : si forme Common, Cross-blend HeavyCleaver sur Active/Startup Heavy
	if attackKind == "Heavy" and (actionId == "Startup" or actionId == "Active" or actionId == "Recovery") then
		if formRarity == "Common" or formId == nil then
			local heavySet = AnimationSets.get("Concord_HeavyCleaver")
			if heavySet then
				setDef = heavySet
				if actionId == "Startup" then
					clipName = "StartupHeavy"
				elseif actionId == "Active" then
					clipName = "ActiveHeavy"
				else
					clipName = "RecoveryHeavy"
				end
			end
		end
	end

	local key = string.format("%s|%s|%s|%s", tostring(userId), setDef.id, clipName, actionId)
	if lastKey[userId] == key then
		return
	end
	lastKey[userId] = key

	local character = resolveCharacter(userId)
	if not character then
		return
	end

	-- Visuels lame (couleur / trail / light) toujours
	SaberPose.applyVisuals(character, actionId, attackKind)

	character:SetAttribute("BC_AnimSet", setDef.id)
	character:SetAttribute("BC_AnimClip", clipName)

	local played = playClip(character, setDef.id, clipName, actionId)

	-- Fallback Motor6D C1 si ni Animator ni Procedural n'ont pu jouer
	if not played then
		SaberPose.applyMotorFallback(character, actionId, attackKind)
	elseif useAnimatorPath then
		-- Animator anime le corps ; garder un micro offset lame via SaberPose léger
		-- (HiltGrip Pose devrait suffire — pas de double tween C1)
	end
end

function CombatAnimator.start()
	AnimationRegistry.ensureBuilt()
	useAnimatorPath = AnimationRegistry.RegisterAvailable

	print(
		string.format(
			"[BladeConcord] CombatAnimator: %d sets · path=%s",
			AnimationRegistry.setCount(),
			if useAnimatorPath then "Animator+KeyframeSequence" else "Procedural+SaberPoseFallback"
		)
	)

	-- SaberPose ne doit plus écouter CombatState (évite double tween)
	SaberPose.setCombatListenerEnabled(false)
	SaberPose.startVisualOnly()

	local remotes = Remotes.get()
	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			if typeof(snap) == "table" and typeof(snap.userId) == "number" then
				applyState(snap.userId, snap)
			end
		end
	end)
end

function CombatAnimator.getSetCount(): number
	return AnimationRegistry.setCount()
end

function CombatAnimator.isAnimatorPath(): boolean
	return useAnimatorPath
end

return CombatAnimator
