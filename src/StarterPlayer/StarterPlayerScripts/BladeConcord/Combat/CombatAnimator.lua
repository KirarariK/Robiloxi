--!strict
--[[
	Chemin principal animations combat : Animator:LoadAnimation (Studio Register)
	ou ProceduralPlayer (Motor6D.Transform) — SaberPose = fallback lame / visuals.
	Branche sur CombatState (Idle/Startup/Active/Recovery/Guard/Dodge/Dash/Focus/KO).
	Pass continue : fades Guard enter/exit, sync speed ↔ CombatConfig, nil-safe Animator.
	Pass quality : AnimDebugOverlay (F8 / BC_AnimDebug) liste set+clip.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blade = ReplicatedStorage:WaitForChild("BladeConcord")
local Shared = Blade:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local AnimationSets = require(Blade:WaitForChild("Animation"):WaitForChild("AnimationSets"))
local AnimationRegistry = require(Blade:WaitForChild("Animation"):WaitForChild("AnimationRegistry"))
local ProceduralPlayer = require(Blade:WaitForChild("Animation"):WaitForChild("ProceduralPlayer"))

local SaberPose = require(script.Parent:WaitForChild("SaberPose"))
local AnimDebugOverlay = require(script.Parent:WaitForChild("AnimDebugOverlay"))
local SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))

local CombatAnimator = {}

local lastKey: { [number]: string } = {}
local tracksByChar: { [Model]: { [string]: AnimationTrack } } = {}
local useAnimatorPath = false
local feintArmed: { [number]: boolean } = {}
-- Showcase (touche P) : ignore CombatState pour ne pas écraser le cycle démo
local combatPaused = false

local function playLocalSfx(name: string, userId: number)
	local lp = Players.LocalPlayer
	if lp and userId == lp.UserId then
		SoundHooks.play(name)
	end
end

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
	-- Stress : pas de Humanoid → pas d'Animator ; bascule Procedural (bot simplifié OK)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
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
	-- fadeIn, fadeOut — Idle↔Startup / Guard enter-exit plus longs
	if actionId == "Active" then
		return 0.05, 0.1
	elseif actionId == "Startup" then
		return 0.14, 0.12 -- crossfade depuis Idle
	elseif actionId == "Recovery" then
		return 0.1, 0.14
	elseif actionId == "Guard" or actionId == "RiposteLock" then
		return 0.16, 0.18 -- enter / exit Guard densifiés
	elseif actionId == "Idle" then
		return 0.18, 0.14 -- settle doux depuis Guard/Recovery
	elseif actionId == "Dodge" or actionId == "Dash" then
		return 0.06, 0.1
	elseif clipName == "Feint" then
		return 0.08, 0.12
	end
	return 0.1, 0.12
end

--[[
	Vitesse de playback pour coller Track.Length à la frame data CombatConfig
	quand Register/estimate diverge légèrement (tempo Idle inchangé).
]]
local function playbackSpeedFor(clipName: string, trackLength: number): number
	local heavy = string.find(clipName, "Heavy") ~= nil
	local cfg = if heavy then CombatConfig.Heavy else CombatConfig.Light
	local target: number? = nil
	if string.sub(clipName, 1, 7) == "Startup" then
		target = cfg.Startup
	elseif string.sub(clipName, 1, 6) == "Active" then
		target = cfg.Active
	elseif string.sub(clipName, 1, 8) == "Recovery" then
		target = cfg.Recovery
	elseif clipName == "Feint" then
		target = math.max(0.22, CombatConfig.Light.Startup * 0.95)
	end
	if not target or trackLength <= 0.001 then
		return 1
	end
	-- Length/Speed = target  ⇒  Speed = Length / target
	local speed = trackLength / target
	return math.clamp(speed, 0.75, 1.35)
end

local function stopCompeting(character: Model, fadeOut: number, keepTrack: AnimationTrack?)
	local bag = tracksByChar[character]
	if not bag then
		return
	end
	for _, track in bag do
		if track ~= keepTrack and track.IsPlaying then
			track:Stop(fadeOut)
		end
	end
end

local function playClip(character: Model, setId: string, clipName: string, actionId: string): boolean
	if not character.Parent then
		return false
	end
	-- Anti-nil race CharacterAdded : pas d'Animator / joints tant que Humanoid absent
	if not character:FindFirstChildOfClass("Humanoid") then
		return false
	end
	local fadeIn, fadeOut = fadeTimesFor(clipName, actionId)
	local track = getOrLoadTrack(character, setId, clipName)
	if track then
		-- Crossfade : Stop avec fadeOut = fadeIn du nouveau (Idle↔Startup / Guard exit)
		stopCompeting(character, fadeOut, track)
		local bag = tracksByChar[character]
		if bag then
			for _, t in bag do
				if t ~= track and t.IsPlaying and t.Looped then
					t:Stop(math.max(fadeIn, fadeOut))
				end
			end
		end
		local length = track.Length
		if length <= 0 then
			-- Length 0 tant que non chargé — fallback lengthHint registry
			local clip = AnimationRegistry.getClip(setId, clipName)
			length = if clip then clip.lengthHint else 0.3
		end
		local speed = playbackSpeedFor(clipName, length)
		track:Play(fadeIn, 1, speed)
		return true
	end

	-- Procedural path (live / Register indisponible / pas d'Animator) — jamais nil-crash
	local ok, handle = pcall(function()
		return ProceduralPlayer.play(character, setId, clipName, fadeIn, 1, fadeOut)
	end)
	return ok and handle ~= nil
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
			local feintKey = string.format("%s|%s|Feint|%s", tostring(userId), setDef.id, actionId)
			if lastKey[userId] == feintKey then
				return
			end
			lastKey[userId] = feintKey
			SaberPose.applyVisuals(character, actionId, attackKind)
			character:SetAttribute("BC_AnimSet", setDef.id)
			character:SetAttribute("BC_AnimClip", "Feint")
			playLocalSfx("Feint", userId)
			local playedFeint = playClip(character, setDef.id, "Feint", actionId)
			if not playedFeint then
				SaberPose.applyMotorFallback(character, "Guard", attackKind)
			elseif useAnimatorPath then
				-- Animator path OK — pas de double C1
			end
			return
		end
		-- Pas de character / set : laisser le path Guard normal
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

	-- Swing SFX : chemin Animator (SaberPose listener désactivé → plus de Swing via MotorFallback)
	if actionId == "Active" then
		playLocalSfx("Swing", userId)
	end

	local played = playClip(character, setDef.id, clipName, actionId)

	-- Fallback Motor6D C1 si ni Animator ni Procedural n'ont pu jouer
	if not played then
		SaberPose.applyMotorFallback(character, actionId, attackKind)
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

	-- Overlay debug optionnel (F8 / attribut BC_AnimDebug)
	AnimDebugOverlay.start()

	-- SaberPose ne doit plus écouter CombatState (évite double tween)
	SaberPose.setCombatListenerEnabled(false)
	SaberPose.startVisualOnly()

	-- Respawn : invalide lastKey + cache tracks (évite stale Model / nil Humanoid race)
	local lp = Players.LocalPlayer
	if lp then
		lp.CharacterAdded:Connect(function(character)
			lastKey[lp.UserId] = nil
			feintArmed[lp.UserId] = nil
			-- Purge bag de l'ancien character (Destroying le fait aussi ; double-safe)
			character.Destroying:Once(function()
				tracksByChar[character] = nil
			end)
			-- Attendre Humanoid avant premier playClip (Animator path)
			task.defer(function()
				character:WaitForChild("Humanoid", 8)
			end)
		end)
		if lp.Character then
			lastKey[lp.UserId] = nil
		end
	end

	local remotes = Remotes.get()
	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if combatPaused then
			return
		end
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			if typeof(snap) == "table" and typeof(snap.userId) == "number" then
				-- Bot (-9001) + joueur : même pipeline ; character manquant = no-op soft
				local ok, err = pcall(applyState, snap.userId, snap)
				if not ok then
					warn("[BladeConcord] CombatAnimator applyState failed:", err)
				end
			end
		end
	end)
end

--[[ Pause écoute CombatState (mode Showcase BC_Showcase). ]]
function CombatAnimator.setPaused(paused: boolean)
	combatPaused = paused
	if not paused then
		-- Force re-apply au prochain CombatState
		table.clear(lastKey)
		table.clear(feintArmed)
	end
end

function CombatAnimator.isPaused(): boolean
	return combatPaused
end

--[[ Joue un clip nommé hors CombatState (Showcase / debug). ]]
function CombatAnimator.playDirect(character: Model, setId: string, clipName: string, actionId: string?): boolean
	local action = actionId or "Idle"
	if string.sub(clipName, 1, 7) == "Startup" then
		action = "Startup"
	elseif string.sub(clipName, 1, 6) == "Active" then
		action = "Active"
	elseif string.sub(clipName, 1, 8) == "Recovery" then
		action = "Recovery"
	elseif clipName == "Guard" or clipName == "Riposte" then
		action = "Guard"
	elseif clipName == "Dodge" then
		action = "Dodge"
	elseif clipName == "Dash" then
		action = "Dash"
	elseif clipName == "FocusPush" then
		action = "FocusPush"
	elseif clipName == "FocusDash" then
		action = "FocusDash"
	elseif clipName == "Stagger" then
		action = "Stagger"
	elseif clipName == "Dead" then
		action = "Dead"
	elseif clipName == "Feint" then
		action = "Guard"
	end

	local attackKind: string? = nil
	if string.find(clipName, "Heavy") then
		attackKind = "Heavy"
	elseif string.find(clipName, "Light") or clipName == "Feint" or clipName == "Riposte" then
		attackKind = "Light"
	end

	SaberPose.applyVisuals(character, action, attackKind)
	character:SetAttribute("BC_AnimSet", setId)
	character:SetAttribute("BC_AnimClip", clipName)
	character:SetAttribute("BC_Showcase", true)

	local played = playClip(character, setId, clipName, action)
	if not played then
		SaberPose.applyMotorFallback(character, action, attackKind)
	end
	return played
end

function CombatAnimator.getSetCount(): number
	return AnimationRegistry.setCount()
end

function CombatAnimator.isAnimatorPath(): boolean
	return useAnimatorPath
end

return CombatAnimator
