--!strict
-- Clips d'emotes (un `Emote_<Id>` par entrée d'EmoteData), d'intro de duel et d'exécutions finales.
local Core = require(script.Parent.AnimLibraryCore)
local Styles = require(script.Parent.AnimLibraryStyles)
local Config = require(script.Parent.CombatConfig)
local CombatClips = require(script.Parent.AnimLibraryCombat)
local EmoteData = require(script.Parent.Parent.Config.EmoteData)

type Pose = Core.Pose
type Clip = Core.Clip
type KeySpec = Core.KeySpec
type Style = Styles.Style

local J = Core.J
local merge = Core.merge
local compose = Core.compose
local add = Core.add
local Layers = Core.Layers

local Emotes = {}

local function neutral(): Pose
	return {
		Root = CFrame.identity,
		Waist = CFrame.identity,
		Neck = CFrame.identity,
		RightShoulder = J(5, 0, 8),
		RightElbow = J(10, 0, 0),
		RightWrist = J(-80, 0, 0), -- lame / poignée vers le bas
		LeftShoulder = J(5, 0, -8),
		LeftElbow = J(10, 0, 0),
		LeftWrist = CFrame.identity,
		RightHip = CFrame.identity,
		RightKnee = CFrame.identity,
		RightAnkle = CFrame.identity,
		LeftHip = CFrame.identity,
		LeftKnee = CFrame.identity,
		LeftAnkle = CFrame.identity,
	}
end

local function emoteClip(id: string, duration: number, keys: { KeySpec }, looped: boolean): Clip
	return Core.clip(id, duration, keys, { Looped = looped, Layer = Layers.Emote, FadeIn = 0.25, FadeOut = 0.3 })
end

local function durationOf(id: string, fallback: number): number
	local def = EmoteData.get(id)
	if def and def.Duration > 0 then
		return def.Duration
	end
	return fallback
end

--------------------------------------------------------------------------------
-- Emotes

type Builder = (s: Style, weapon: string) -> Clip

local BUILDERS: { [string]: Builder } = {}

BUILDERS.Salut = function(s: Style, weapon: string): Clip
	local n = neutral()
	local hands = merge(n, {
		RightShoulder = J(60, 0, -30),
		RightElbow = J(100, 0, 0),
		RightWrist = J(0, 0, 0),
		LeftShoulder = J(60, 0, 30),
		LeftElbow = J(100, 0, 0),
	})
	local bow = merge(hands, { Waist = J(-32, 0, 0), Neck = J(-15, 0, 0) })
	return emoteClip("Emote_Salut", durationOf("Salut", 2.2), {
		{ t = 0, p = n },
		{ t = 0.2, p = hands },
		{ t = 0.45, p = bow },
		{ t = 0.65, p = bow },
		{ t = 0.85, p = hands },
		{ t = 1, p = n },
	}, false)
end

BUILDERS.SalutLame = function(s: Style, weapon: string): Clip
	local n = neutral()
	local g = CombatClips.guardPose(s, weapon)
	local face = merge(n, { RightShoulder = J(80, 0, -20), RightElbow = J(95, 0, 0), RightWrist = J(0, 0, 0), Neck = J(-5, 0, 0) })
	local down = merge(n, { RightShoulder = J(30, 0, 35), RightElbow = J(5, 0, 0), RightWrist = J(-60, 0, 0), Waist = J(-10, 0, 0) })
	return emoteClip("Emote_SalutLame", durationOf("SalutLame", 2.6), {
		{ t = 0, p = n },
		{ t = 0.25, p = face },
		{ t = 0.5, p = face, e = "quadIn" },
		{ t = 0.65, p = down },
		{ t = 0.85, p = down },
		{ t = 1, p = g },
	}, false)
end

BUILDERS.Meditation = function(s: Style, weapon: string): Clip
	local lotus: Pose = {
		Root = J(0, 0, 0, 0, 1.6, 0),
		Waist = J(2, 0, 0),
		Neck = J(-10, 0, 0),
		RightHip = J(80, 0, 40),
		RightKnee = J(-140, 0, 0),
		RightAnkle = J(30, 0, 0),
		LeftHip = J(80, 0, -40),
		LeftKnee = J(-140, 0, 0),
		LeftAnkle = J(30, 0, 0),
		RightShoulder = J(20, 0, 20),
		RightElbow = J(60, 0, 0),
		RightWrist = J(-70, 0, 0),
		LeftShoulder = J(20, 0, -20),
		LeftElbow = J(60, 0, 0),
		LeftWrist = J(0, 0, 0),
	}
	local up = add(lotus, { Root = J(0, 0, 0, 0, 0.18, 0), Waist = J(-2, 0, 0) }, 1)
	return emoteClip("Emote_Meditation", 3, { { t = 0, p = lotus }, { t = 0.5, p = up }, { t = 1, p = lotus } }, true)
end

BUILDERS.Moulinet = function(s: Style, weapon: string): Clip
	local base = merge(neutral(), { RightShoulder = J(70, 0, 20), RightElbow = J(40, 0, 0), Waist = J(-4, -10, 0) })
	local keys: { KeySpec } = { { t = 0, p = neutral() } }
	local steps = 8
	for i = 0, steps do
		local p = merge(base, {})
		p.RightWrist = J(90 * i, 0, 0)
		table.insert(keys, { t = 0.12 + 0.72 * i / steps, p = p, e = "linear" })
	end
	table.insert(keys, { t = 1, p = CombatClips.guardPose(s, weapon) })
	return emoteClip("Emote_Moulinet", durationOf("Moulinet", 2.4), keys, false)
end

BUILDERS.Tourbillon = function(s: Style, weapon: string): Clip
	local ext = merge(neutral(), { RightShoulder = J(90, -60, 0), RightElbow = J(5, 0, 0), RightWrist = J(0, 90, 0), LeftShoulder = J(60, 0, -60) })
	local keys: { KeySpec } = { { t = 0, p = neutral(), e = "quadOut" }, { t = 0.12, p = ext, e = "linear" } }
	for i = 1, 8 do
		local p = merge(ext, {})
		p.Root = J(0, 90 * i, 0, 0, -0.1, 0)
		table.insert(keys, { t = 0.12 + 0.68 * i / 8, p = p, e = "linear" })
	end
	table.insert(keys, { t = 1, p = CombatClips.guardPose(s, weapon) })
	return emoteClip("Emote_Tourbillon", durationOf("Tourbillon", 2.8), keys, false)
end

BUILDERS.Viens = function(s: Style, weapon: string): Clip
	local n = merge(neutral(), { Neck = J(8, 0, 6), Waist = J(4, 10, 0) })
	local open = merge(n, { LeftShoulder = J(80, 0, -10), LeftElbow = J(10, 0, 0), LeftWrist = J(-30, 0, 0) })
	local curl = merge(open, { LeftElbow = J(90, 0, 0), LeftWrist = J(40, 0, 0) })
	return emoteClip("Emote_Viens", durationOf("Viens", 1.8), {
		{ t = 0, p = neutral() },
		{ t = 0.15, p = open },
		{ t = 0.3, p = curl },
		{ t = 0.45, p = open },
		{ t = 0.6, p = curl },
		{ t = 0.75, p = open },
		{ t = 1, p = neutral() },
	}, false)
end

BUILDERS.Bailler = function(s: Style, weapon: string): Clip
	local n = neutral()
	local stretch = merge(n, {
		RightShoulder = J(170, 0, 15),
		RightElbow = J(20, 0, 0),
		LeftShoulder = J(170, 0, -15),
		LeftElbow = J(20, 0, 0),
		Neck = J(25, 0, 0),
		Waist = J(8, 0, 0),
	})
	local slump = merge(n, { Neck = J(-10, 0, 8), Waist = J(-6, 0, 0), RightShoulder = J(0, 0, 4), LeftShoulder = J(0, 0, -4) })
	return emoteClip("Emote_Bailler", durationOf("Bailler", 2.2), {
		{ t = 0, p = n },
		{ t = 0.3, p = stretch },
		{ t = 0.55, p = stretch, e = "quadIn" },
		{ t = 0.75, p = slump },
		{ t = 1, p = n },
	}, false)
end

BUILDERS.Triomphe = function(s: Style, weapon: string): Clip
	local n = neutral()
	local raised = merge(n, {
		RightShoulder = J(175, 0, 5),
		RightElbow = J(5, 0, 0),
		RightWrist = J(20, 0, 0),
		LeftShoulder = J(40, 0, -40),
		LeftElbow = J(90, 0, 0),
		Neck = J(20, 0, 0),
		Waist = J(10, 0, 0),
	})
	local hold = add(raised, { RightShoulder = J(-3, 0, 0), Waist = J(2, 0, 0) }, 1)
	return emoteClip("Emote_Triomphe", durationOf("Triomphe", 3), {
		{ t = 0, p = n, e = "backOut" },
		{ t = 0.2, p = raised },
		{ t = 0.6, p = hold },
		{ t = 0.85, p = raised },
		{ t = 1, p = n },
	}, false)
end

BUILDERS.Genou = function(s: Style, weapon: string): Clip
	local kneel = merge(CombatClips.defeatedPose(), {
		Waist = J(-10, 0, 0),
		Neck = J(-30, 0, 0),
		RightShoulder = J(60, 0, -5),
		RightElbow = J(30, 0, 0),
		RightWrist = J(-120, 0, 0), -- lame plantée pointe en bas
		LeftShoulder = J(55, 0, 15),
		LeftElbow = J(40, 0, 0),
	})
	return emoteClip("Emote_Genou", durationOf("Genou", 3), {
		{ t = 0, p = neutral() },
		{ t = 0.25, p = kneel },
		{ t = 0.8, p = add(kneel, { Neck = J(-5, 0, 0) }, 1) },
		{ t = 1, p = neutral() },
	}, false)
end

-- Vérification au chargement : chaque emote déclarée possède son clip.
for _, def in EmoteData.List do
	if BUILDERS[def.Id] == nil then
		warn("[EtherBlades] Emote sans animation : " .. def.Id)
	end
end

--------------------------------------------------------------------------------
-- Intro de duel

local function intro(s: Style, weapon: string): Clip
	local d = Config.Intro.Duration
	local ig = Config.Intro.IgniteAt / d
	local n = neutral()
	local g = CombatClips.guardPose(s, weapon)
	local present = merge(n, { RightShoulder = J(70, 0, -10), RightElbow = J(90, 0, 0), RightWrist = J(0, 0, 0), Neck = J(-10, 0, 0) })
	if weapon == "Dual" then
		present = merge(present, { LeftShoulder = J(70, 0, 10), LeftElbow = J(90, 0, 0), LeftWrist = J(0, 0, 0) })
	end
	local salute = merge(present, { RightShoulder = J(80, 0, -20), RightElbow = J(95, 0, 0), Neck = J(0, 0, 0), Waist = J(2, 0, 0) })
	local flourish = merge(g, { RightShoulder = J(140, -20, 40), RightElbow = J(30, 0, 0), RightWrist = J(20, 0, 0) })
	return Core.clip("Intro", d, {
		{ t = 0, p = n },
		{ t = ig - 0.12, p = present, e = "quadOut" },
		{ t = ig, p = present, e = "backOut" },
		{ t = ig + 0.14, p = salute },
		{ t = 0.68, p = salute, e = "quadIn" },
		{ t = 0.78, p = flourish },
		{ t = 0.9, p = g },
		{ t = 1, p = g },
	}, { Layer = Layers.Emote, FadeIn = 0.2, FadeOut = 0.4, Markers = { { Time = ig, Name = "Ignite" } } })
end

--------------------------------------------------------------------------------
-- Exécutions (vainqueur) et réaction du perdant

local function finisher(s: Style, weapon: string): Clip
	local d = Config.Finisher.Duration
	local sf = Config.Finisher.StrikeAt / d
	local g = CombatClips.guardPose(s, weapon)
	local wind, hit = CombatClips.strikePoses(s, weapon, s.HeavyBody)
	local keys: { KeySpec }
	if s.Id == "Duelliste" then
		local salute = merge(g, { RightShoulder = J(80, 0, -20), RightElbow = J(95, 0, 0), RightWrist = J(0, 0, 0) })
		local lunge = add(merge(hit, { RightShoulder = J(92, 0, 0), RightElbow = J(0, 0, 0), RightWrist = J(-92, 0, 0) }), {
			Root = J(0, 0, 0, 0, -0.3, -1.2),
			RightHip = J(40, 0, 0),
			LeftHip = J(-30, 0, 0),
		}, 1)
		local flourishEnd = merge(g, { RightShoulder = J(25, 0, 35), RightElbow = J(5, 0, 0), RightWrist = J(-60, 0, 0) })
		keys = {
			{ t = 0, p = g },
			{ t = 0.22, p = salute },
			{ t = sf - 0.12, p = salute, e = "expoIn" },
			{ t = sf, p = lunge, e = "quadOut" },
			{ t = sf + 0.12, p = lunge },
			{ t = 0.85, p = flourishEnd },
			{ t = 1, p = flourishEnd },
		}
	elseif s.Acrobatic then
		keys = { { t = 0, p = g }, { t = 0.2, p = add(g, { Root = J(0, 0, 0, 0, -0.5, 0) }, 1), e = "quadOut" } }
		for _, k in CombatClips.flipKeys("X", 1, 0.25, sf - 0.06, 3.5, wind, "linear") do
			table.insert(keys, k)
		end
		local land = add(hit, { Root = J(0, 0, 0, 0, -0.6, 0) }, 1)
		table.insert(keys, { t = sf, p = land, e = "quadOut" })
		table.insert(keys, { t = 0.85, p = land })
		table.insert(keys, { t = 1, p = g })
	elseif s.HeavyBody then
		local raised = merge(wind, { RightShoulder = J(178, 0, 5), RightElbow = J(10, 0, 0), RightWrist = J(30, 0, 0) })
		local slam = add(hit, { Root = J(0, 0, 0, 0, -0.5, -0.4), Waist = J(-15, 0, 0) }, 1)
		local rest = merge(g, { RightShoulder = J(155, -20, 40), RightElbow = J(95, 0, 0), RightWrist = J(40, 0, 0) })
		keys = {
			{ t = 0, p = g },
			{ t = 0.3, p = raised, e = "sine" },
			{ t = sf - 0.08, p = add(raised, { Waist = J(8, 0, 0) }, 1), e = "expoIn" },
			{ t = sf, p = slam, e = "quadOut" },
			{ t = sf + 0.14, p = slam },
			{ t = 0.88, p = rest },
			{ t = 1, p = rest },
		}
	elseif s.PushGesture then
		local push = merge(g, { LeftShoulder = J(90, 15, 0), LeftElbow = J(0, 0, 0), LeftWrist = J(-80, 0, 0), Waist = J(-6, 20, 0) })
		local calm = merge(Core.legs(0.2, 8, 6), {
			Waist = J(0, 0, 0),
			Neck = J(-8, 0, 0),
			RightShoulder = J(10, 0, 12),
			RightElbow = J(10, 0, 0),
			RightWrist = J(-80, 0, 0),
			LeftShoulder = J(40, 0, 30),
			LeftElbow = J(100, 0, 0),
		})
		keys = {
			{ t = 0, p = g },
			{ t = 0.3, p = push, e = "backOut" },
			{ t = 0.42, p = push },
			{ t = sf - 0.1, p = wind, e = "sine" },
			{ t = sf, p = hit, e = "sine" },
			{ t = sf + 0.12, p = hit },
			{ t = 0.88, p = calm },
			{ t = 1, p = calm },
		}
	elseif s.Jitter > 0 then
		local h2 = Core.mirror(hit)
		keys = {
			{ t = 0, p = g },
			{ t = sf - 0.3, p = wind, e = "expoIn" },
			{ t = sf - 0.22, p = hit, e = "expoIn" },
			{ t = sf - 0.12, p = h2, e = "expoIn" },
			{ t = sf - 0.06, p = wind, e = "expoIn" },
			{ t = sf, p = add(hit, { Root = J(0, 0, 0, 0, -0.3, -0.5) }, 1), e = "quadOut" },
			{ t = 0.85, p = add(g, { Waist = J(-20, 0, 10), Neck = J(10, 0, 15) }, 1) },
			{ t = 1, p = add(g, { Waist = J(-20, 0, 10), Neck = J(10, 0, 15) }, 1) },
		}
		keys = CombatClips.stormify("Finisher", s, keys)
	elseif s.Id == "Rempart" then
		local bash = add(g, { Root = J(0, 0, 0, 0, -0.2, -0.6), Waist = J(-14, 15, 0), LeftShoulder = J(30, 0, 0) }, 1)
		local up = merge(hit, { RightShoulder = J(150, -30, 50), RightElbow = J(20, 0, 0), RightWrist = J(30, 0, 0) })
		keys = {
			{ t = 0, p = g },
			{ t = 0.3, p = bash, e = "backOut" },
			{ t = sf - 0.1, p = add(g, { Root = J(0, 0, 0, 0, -0.4, 0) }, 1), e = "expoIn" },
			{ t = sf, p = up, e = "quadOut" },
			{ t = sf + 0.12, p = up },
			{ t = 0.88, p = g },
			{ t = 1, p = g },
		}
	else
		-- Origine : grande coupe tournoyante
		keys = { { t = 0, p = g }, { t = 0.25, p = wind, e = "linear" } }
		for i = 1, 4 do
			local p = merge(wind, {})
			p.Root = J(0, -90 * i, 0, 0, -0.2, 0)
			table.insert(keys, { t = 0.25 + (sf - 0.04 - 0.25) * i / 4, p = p, e = "linear" })
		end
		table.insert(keys, { t = sf, p = hit, e = "quadOut" })
		table.insert(keys, { t = sf + 0.14, p = hit })
		local finale = merge(g, { RightShoulder = J(20, 0, 30), RightElbow = J(5, 0, 0), RightWrist = J(-55, 0, 0), Waist = J(0, 0, 0) })
		table.insert(keys, { t = 0.88, p = finale })
		table.insert(keys, { t = 1, p = finale })
	end
	return Core.clip("Finisher", d, keys, {
		Layer = Layers.Emote,
		FadeIn = 0.15,
		FadeOut = 0.4,
		Markers = { { Time = sf, Name = "Strike" } },
	})
end

local function finisherVictim(s: Style, weapon: string): Clip
	local d = Config.Finisher.Duration
	local sf = Config.Finisher.StrikeAt / d
	local g = CombatClips.guardPose(s, weapon)
	local weak = add(g, { Waist = J(-14, 0, 6), Neck = J(-10, 0, 0), RightShoulder = J(-25, 0, 0), Root = J(0, 0, 0, 0, -0.2, 0) }, 1)
	local struck = add(weak, { Root = J(22, 0, 0, 0, 0.1, 0.4), Waist = J(30, 0, 0), Neck = J(30, 0, 0) }, 1)
	local kneel = CombatClips.defeatedPose()
	return Core.clip("Finisher_Victim", d, {
		{ t = 0, p = g },
		{ t = 0.25, p = weak },
		{ t = sf - 0.02, p = weak, e = "expoOut" },
		{ t = sf + 0.06, p = struck, e = "sine" },
		{ t = 0.82, p = kneel },
		{ t = 1, p = kneel },
	}, { Layer = Layers.Emote, FadeIn = 0.15, FadeOut = 0.4, Markers = { { Time = sf, Name = "Struck" } } })
end

function Emotes.build(clipId: string, s: Style, weapon: string): Clip?
	if clipId == "Intro" then
		return intro(s, weapon)
	elseif clipId == "Finisher" then
		return finisher(s, weapon)
	elseif clipId == "Finisher_Victim" then
		return finisherVictim(s, weapon)
	end
	local emoteId = string.match(clipId, "^Emote_(.+)$")
	if emoteId then
		local b = BUILDERS[emoteId]
		if b then
			return b(s, weapon)
		end
	end
	return nil
end

function Emotes.ids(): { string }
	local out: { string } = {}
	for id in BUILDERS do
		table.insert(out, "Emote_" .. id)
	end
	table.sort(out)
	return out
end

return table.freeze(Emotes)
