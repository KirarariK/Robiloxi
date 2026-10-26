--!strict
--[[
	Couche basse priorité (Core) — animations catalogue Roblox officielles.
	Sous les clips Action Blade Concord ; n'écrase jamais Idle/Guard/Active custom.

	Licence : IDs issus de la doc Creator Hub « Use animations » (bundles avatar
	officiels Ninja / Knight) — utilisables dans une expérience Roblox.
	https://create.roblox.com/docs/animation/using

	Si LoadAnimation échoue (réseau / permission), no-op silencieux.
]]

local CatalogueBed = {}

-- Bundle Ninja (doc officielle) — Idle combat-ish + locomotion soft
CatalogueBed.Ids = {
	NinjaIdleA = "rbxassetid://656117400",
	NinjaIdleB = "rbxassetid://656118341",
	-- Knight Idle : posture plus « garde » pour ambiance sabre
	KnightIdleA = "rbxassetid://657595757",
	KnightIdleB = "rbxassetid://657568135",
}

export type BedKind = "CombatIdle"

local tracksByChar: { [Model]: { [string]: AnimationTrack } } = {}

local function getAnimator(character: Model): Animator?
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

local function loadBedTrack(character: Model, key: string, assetId: string): AnimationTrack?
	local bag = tracksByChar[character]
	if not bag then
		bag = {}
		tracksByChar[character] = bag
		character.Destroying:Once(function()
			tracksByChar[character] = nil
		end)
	end
	local existing = bag[key]
	if existing then
		return existing
	end
	local animator = getAnimator(character)
	if not animator then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.Name = "BC_Catalogue_" .. key
	anim.AnimationId = assetId
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or typeof(track) ~= "Instance" then
		return nil
	end
	local animTrack = track :: AnimationTrack
	animTrack.Priority = Enum.AnimationPriority.Core -- sous Idle/Action custom
	animTrack.Looped = true
	bag[key] = animTrack
	return animTrack
end

--[[
	Démarre (ou maintient) un idle catalogue Core sous nos clips.
	Weight faible pour ne pas concurrencer KeyframeFactory Idle (prio Idle).
]]
function CatalogueBed.ensureCombatIdle(character: Model)
	if not character.Parent then
		return
	end
	-- Prefer Knight idle A (stance) — fallback Ninja si load fail
	local track = loadBedTrack(character, "KnightIdleA", CatalogueBed.Ids.KnightIdleA)
	if not track then
		track = loadBedTrack(character, "NinjaIdleA", CatalogueBed.Ids.NinjaIdleA)
	end
	if not track then
		return
	end
	if not track.IsPlaying then
		-- weight bas : présence corporelle sans écraser nos poses Action/Idle
		track:Play(0.35, 0.22, 0.85)
	end
end

function CatalogueBed.stop(character: Model, fadeOut: number?)
	local bag = tracksByChar[character]
	if not bag then
		return
	end
	local fo = fadeOut or 0.2
	for _, track in bag do
		if track.IsPlaying then
			track:Stop(fo)
		end
	end
end

function CatalogueBed.documentedIds(): { { id: string, name: string, source: string } }
	return {
		{ id = CatalogueBed.Ids.NinjaIdleA, name = "Ninja Idle A", source = "Creator Hub catalog · Ninja bundle" },
		{ id = CatalogueBed.Ids.NinjaIdleB, name = "Ninja Idle B", source = "Creator Hub catalog · Ninja bundle" },
		{ id = CatalogueBed.Ids.KnightIdleA, name = "Knight Idle A", source = "Creator Hub catalog · Knight bundle" },
		{ id = CatalogueBed.Ids.KnightIdleB, name = "Knight Idle B", source = "Creator Hub catalog · Knight bundle" },
	}
end

return CatalogueBed
