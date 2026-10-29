--!strict
-- Briques des animations procédurales : poses (CFrame par articulation R15), clips à keyframes, easing,
-- miroir gauche/droite, échantillonnage sans allocation de table.
--
-- Convention des poses : rotations exprimées dans le repère du segment parent, axes « personnage »
-- (X = droite, Y = haut, -Z = avant). Repères pratiques :
--   épaule / hanche : rx > 0 lève le membre vers l'avant ; rz > 0 l'écarte vers +X (dehors pour le côté droit)
--   coude : rx > 0 plie l'avant-bras vers l'avant ; genou : rx < 0 plie la jambe
--   Waist / Neck : rx < 0 penche vers l'avant ; ry > 0 tourne vers la gauche
--   Root : translation (px, py, pz) du bassin + rotation du corps entier (saltos, vrilles)
-- La lame est tenue dans l'axe -Z de la main : bras le long du corps → lame vers l'avant.
local TweenService = game:GetService("TweenService")

export type Pose = { [string]: CFrame }
export type Keyframe = {
	Time: number,
	Pose: Pose,
	Style: Enum.EasingStyle,
	Dir: Enum.EasingDirection,
}
export type Marker = { Time: number, Name: string }
export type Clip = {
	Id: string,
	Duration: number,
	Looped: boolean,
	Layer: number,
	FadeIn: number,
	FadeOut: number,
	Keyframes: { Keyframe },
	Joints: { string },
	Markers: { Marker },
}

-- Clé de keyframe à la construction : t = fraction de la durée (0..1), e = easing vers la clé suivante.
export type KeySpec = { t: number, p: Pose, e: string? }
export type ClipOpts = {
	Looped: boolean?,
	Layer: number?,
	FadeIn: number?,
	FadeOut: number?,
	Markers: { Marker }?, -- temps en fraction de la durée
}

local Core = {}

Core.Joints = table.freeze({
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightHip",
	"RightKnee",
	"RightAnkle",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
})

Core.UpperBody = table.freeze({
	"Waist",
	"Neck",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
})

-- Couches : 0 = posture de base (Idle / Run), 1 = actions, 2 = réactions courtes, 3 = emotes et cinématiques.
Core.Layers = table.freeze({ Base = 0, Action = 1, Reaction = 2, Emote = 3 })

type Ease = { S: Enum.EasingStyle, D: Enum.EasingDirection }
local function E(s: Enum.EasingStyle, d: Enum.EasingDirection): Ease
	return { S = s, D = d }
end

local EASES: { [string]: Ease } = {
	linear = E(Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
	sine = E(Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	sineOut = E(Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	sineIn = E(Enum.EasingStyle.Sine, Enum.EasingDirection.In),
	quadIn = E(Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	quadOut = E(Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	quad = E(Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	cubicIn = E(Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
	cubicOut = E(Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
	expoIn = E(Enum.EasingStyle.Exponential, Enum.EasingDirection.In),
	expoOut = E(Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	backOut = E(Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	backIn = E(Enum.EasingStyle.Back, Enum.EasingDirection.In),
	elasticOut = E(Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
}

local rad = math.rad

-- Rotation en degrés (ordre YXZ : lacet, puis tangage, puis roulis) + translation optionnelle.
function Core.J(rx: number, ry: number?, rz: number?, px: number?, py: number?, pz: number?): CFrame
	return CFrame.new(px or 0, py or 0, pz or 0) * CFrame.fromEulerAnglesYXZ(rad(rx), rad(ry or 0), rad(rz or 0))
end

-- Copie de `base` dont les articulations de `over` sont remplacées.
function Core.merge(base: Pose, over: Pose?): Pose
	local out: Pose = table.clone(base)
	if over then
		for k, v in over do
			out[k] = v
		end
	end
	return out
end

-- Fusionne plusieurs poses (les suivantes l'emportent).
function Core.compose(...: Pose): Pose
	local out: Pose = {}
	for _, p in { ... } do
		for k, v in p do
			out[k] = v
		end
	end
	return out
end

-- Ajoute un décalage (prémultiplié, repère parent) pondéré par `weight` sur les articulations de `overlay`.
function Core.add(pose: Pose, overlay: Pose, weight: number): Pose
	local out: Pose = table.clone(pose)
	for k, v in overlay do
		local o = if weight >= 1 then v else CFrame.identity:Lerp(v, weight)
		out[k] = o * (out[k] or CFrame.identity)
	end
	return out
end

local function mirrorCF(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function mirrorName(name: string): string
	if string.sub(name, 1, 5) == "Right" then
		return "Left" .. string.sub(name, 6)
	elseif string.sub(name, 1, 4) == "Left" then
		return "Right" .. string.sub(name, 5)
	end
	return name
end

-- Symétrie gauche / droite (utile pour les Lames Jumelles et les esquives latérales).
function Core.mirror(pose: Pose): Pose
	local out: Pose = {}
	for k, v in pose do
		out[mirrorName(k)] = mirrorCF(v)
	end
	return out
end

-- Angle de flexion (degrés) pour abaisser le bassin de `drop` studs en gardant les pieds au sol.
function Core.crouchAngle(drop: number): number
	local legLen = 2.4
	local c = math.clamp(1 - drop / legLen, -1, 1)
	return math.deg(math.acos(c))
end

-- Jambes fléchies : `drop` studs, écart `spread`°, pied droit avancé de `stagger`°.
function Core.legs(drop: number, spread: number, stagger: number): Pose
	local a = Core.crouchAngle(math.max(0, drop))
	local J = Core.J
	return {
		Root = J(0, 0, 0, 0, -drop, 0),
		RightHip = J(a + stagger, 0, spread),
		RightKnee = J(-a * 2 + math.min(0, -stagger * 0.3), 0, 0),
		RightAnkle = J(a - stagger * 0.6, 0, -spread * 0.5),
		LeftHip = J(a - stagger, 0, -spread),
		LeftKnee = J(-a * 2 - math.abs(stagger) * 0.4, 0, 0),
		LeftAnkle = J(a + stagger * 0.6, 0, spread * 0.5),
	}
end

-- Petit bruit déterministe (pour la Voie de la Tempête) : même clip → mêmes secousses.
function Core.hash(s: string): number
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 2147483647
	end
	return h
end

function Core.jitter(pose: Pose, rng: Random, amp: number, joints: { string }): Pose
	local out: Pose = table.clone(pose)
	local J = Core.J
	for _, j in joints do
		local o = J(rng:NextNumber(-amp, amp), rng:NextNumber(-amp, amp), rng:NextNumber(-amp * 0.6, amp * 0.6))
		out[j] = o * (out[j] or CFrame.identity)
	end
	return out
end

-- Construit un clip : complète chaque keyframe avec l'identité sur les articulations manquantes.
function Core.clip(id: string, duration: number, keys: { KeySpec }, opts: ClipOpts?): Clip
	assert(#keys >= 2, "Clip " .. id .. " : au moins deux keyframes")
	local o: ClipOpts = opts or {}
	local seen: { [string]: boolean } = {}
	local joints: { string } = {}
	for _, k in keys do
		for j in k.p do
			if not seen[j] then
				seen[j] = true
				table.insert(joints, j)
			end
		end
	end
	local kfs: { Keyframe } = {}
	for _, k in keys do
		local full: Pose = {}
		for _, j in joints do
			full[j] = k.p[j] or CFrame.identity
		end
		local ease = EASES[k.e or "sine"] or EASES.sine
		table.insert(kfs, {
			Time = math.clamp(k.t, 0, 1) * duration,
			Pose = table.freeze(full),
			Style = ease.S,
			Dir = ease.D,
		})
	end
	table.sort(kfs, function(a, b)
		return a.Time < b.Time
	end)
	local markers: { Marker } = {}
	for _, m in o.Markers or {} do
		table.insert(markers, { Time = math.clamp(m.Time, 0, 1) * duration, Name = m.Name })
	end
	table.sort(markers, function(a, b)
		return a.Time < b.Time
	end)
	local clip: Clip = {
		Id = id,
		Duration = math.max(duration, 1e-3),
		Looped = o.Looped == true,
		Layer = o.Layer or Core.Layers.Action,
		FadeIn = o.FadeIn or 0.06,
		FadeOut = o.FadeOut or 0.14,
		Keyframes = kfs,
		Joints = joints,
		Markers = markers,
	}
	return table.freeze(clip)
end

-- Échantillonne `clip` au temps `t` dans `out` (réutilisée frame après frame).
function Core.sample(clip: Clip, t: number, out: Pose)
	local kfs = clip.Keyframes
	local n = #kfs
	local first = kfs[1]
	local last = kfs[n]
	if t <= first.Time then
		for _, j in clip.Joints do
			out[j] = first.Pose[j]
		end
		return
	elseif t >= last.Time then
		for _, j in clip.Joints do
			out[j] = last.Pose[j]
		end
		return
	end
	local i = 1
	while i < n - 1 and kfs[i + 1].Time <= t do
		i += 1
	end
	local a = kfs[i]
	local b = kfs[i + 1]
	local span = b.Time - a.Time
	local alpha = if span > 1e-6 then (t - a.Time) / span else 1
	alpha = TweenService:GetValue(alpha, a.Style, a.Dir)
	local pa, pb = a.Pose, b.Pose
	for _, j in clip.Joints do
		out[j] = pa[j]:Lerp(pb[j], alpha)
	end
end

return table.freeze(Core)
