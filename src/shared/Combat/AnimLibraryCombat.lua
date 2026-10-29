--!strict
-- Générateurs des clips de combat, paramétrés par Voie (style) et par arme.
-- Clips : Idle, Run, Jump (Faucon), M1_1..5 (+ _F / _S / _B), M1_Air, Counter, M2_Charge, M2_Strike,
-- Block, BlockHit, Parry, Dodge_F/B/L/R, Stunned, Flinch, GuardBroken, Defeated, Ignite, SaberLock.
local Core = require(script.Parent.AnimLibraryCore)
local Styles = require(script.Parent.AnimLibraryStyles)
local Config = require(script.Parent.CombatConfig)
local WeaponData = require(script.Parent.Parent.Config.WeaponData)

type Pose = Core.Pose
type Clip = Core.Clip
type KeySpec = Core.KeySpec
type Style = Styles.Style

local J = Core.J
local merge = Core.merge
local compose = Core.compose
local add = Core.add
local mirror = Core.mirror
local Layers = Core.Layers

local Combat = {}

--------------------------------------------------------------------------------
-- Bras

type ArmSpec = { S: { number }, E: number, W: { number } }

local function arm(a: ArmSpec, amp: number): Pose
	return {
		RightShoulder = J(a.S[1], a.S[2] * amp, a.S[3] * amp),
		RightElbow = J(a.E, 0, 0),
		RightWrist = J(a.W[1], a.W[2], a.W[3]),
	}
end

-- Main gauche qui rejoint la poignée tenue à droite.
local function twoHand(p: Pose): Pose
	local rs = p.RightShoulder or CFrame.identity
	return {
		LeftShoulder = CFrame.Angles(0, 0, math.rad(26)) * rs,
		LeftElbow = (p.RightElbow or CFrame.identity) * J(8, 0, 0),
		LeftWrist = p.RightWrist or CFrame.identity,
	}
end

local function leftArmOf(p: Pose): Pose
	local m = mirror(p)
	return { LeftShoulder = m.LeftShoulder, LeftElbow = m.LeftElbow, LeftWrist = m.LeftWrist }
end

local function rightArmOf(p: Pose): Pose
	return { RightShoulder = p.RightShoulder, RightElbow = p.RightElbow, RightWrist = p.RightWrist }
end

-- Bras libre (lame simple tenue à une main).
local function offHand(s: Style, striking: boolean): Pose
	if s.OffHandFencing then
		return { LeftShoulder = J(-35, 0, -65), LeftElbow = J(105, 0, 0), LeftWrist = J(35, 0, 0) }
	elseif s.PushGesture then
		if striking then
			return { LeftShoulder = J(88, 18, 0), LeftElbow = J(4, 0, 0), LeftWrist = J(-78, 0, 0) }
		end
		return { LeftShoulder = J(52, 14, -8), LeftElbow = J(28, 0, 0), LeftWrist = J(-55, 0, 0) }
	elseif s.Acrobatic then
		return { LeftShoulder = J(if striking then 10 else 25, 0, -38), LeftElbow = J(30, 0, 0), LeftWrist = J(0, 0, 0) }
	end
	return { LeftShoulder = J(20, 0, -20), LeftElbow = J(35, 0, 0), LeftWrist = J(0, 0, 0) }
end

local function guardArms(s: Style, weapon: string): Pose
	if weapon == "Staff" then
		local pitch = math.clamp(s.GuardPitch, 25, 75)
		return {
			RightShoulder = J(pitch, -8, 22),
			RightElbow = J(70, 0, 0),
			RightWrist = J(0, 90, 0),
			LeftShoulder = J(pitch, 8, -22),
			LeftElbow = J(70, 0, 0),
			LeftWrist = J(0, -90, 0),
		}
	end
	local r: Pose = {
		RightShoulder = J(s.GuardPitch, -10, 14),
		RightElbow = J(s.GuardElbow, 0, 0),
		RightWrist = J(s.BladeTilt, 0, 0),
	}
	if weapon == "Dual" then
		return compose(r, leftArmOf(r))
	elseif s.TwoHanded then
		return compose(r, twoHand(r))
	end
	return compose(r, offHand(s, false))
end

local function guardBody(s: Style): Pose
	return compose(Core.legs(s.Crouch, s.Spread, s.Stagger), {
		Waist = J(s.Lean, s.GuardYaw, 0),
		Neck = J(-s.Lean * 0.6, -s.GuardYaw * 0.8, 0),
	})
end

local function guard(s: Style, weapon: string): Pose
	return compose(guardBody(s), guardArms(s, weapon))
end

local function upperOnly(p: Pose): Pose
	local out: Pose = {}
	for _, j in Core.UpperBody do
		if p[j] then
			out[j] = p[j]
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Motifs de frappe (bras droit) : windup → impact

type Strike = { Wind: ArmSpec, Hit: ArmSpec, Twist: number, LeanWind: number, LeanHit: number }

local SINGLE: { Strike } = {
	-- 1 : diagonale descendante droite → gauche
	{ Wind = { S = { 150, -20, 50 }, E = 30, W = { 20, 0, 0 } }, Hit = { S = { 45, 30, -35 }, E = 10, W = { -50, 0, 0 } }, Twist = 1, LeanWind = 4, LeanHit = -10 },
	-- 2 : revers remontant gauche → droite
	{ Wind = { S = { 40, 40, -40 }, E = 20, W = { -40, 0, 0 } }, Hit = { S = { 150, -30, 50 }, E = 20, W = { 30, 0, 0 } }, Twist = -1, LeanWind = -6, LeanHit = 6 },
	-- 3 : horizontale
	{ Wind = { S = { 90, -80, 0 }, E = 15, W = { 0, 90, 0 } }, Hit = { S = { 90, 70, 0 }, E = 10, W = { 0, 90, 0 } }, Twist = 1.2, LeanWind = 0, LeanHit = -4 },
	-- 4 : verticale de haut en bas
	{ Wind = { S = { 175, 0, 10 }, E = 40, W = { 30, 0, 0 } }, Hit = { S = { 60, 0, 5 }, E = 5, W = { -60, 0, 0 } }, Twist = 0, LeanWind = 15, LeanHit = -25 },
	-- 5 : grand revers horizontal (Jumelles : coup tournoyant)
	{ Wind = { S = { 95, 70, 0 }, E = 20, W = { 0, 90, 0 } }, Hit = { S = { 90, -85, 0 }, E = 5, W = { 0, 90, 0 } }, Twist = -1.3, LeanWind = 0, LeanHit = -8 },
}

-- Duelliste : le 3e coup est une estocade
local THRUST: Strike = {
	Wind = { S = { 70, -10, 10 }, E = 95, W = { -80, 0, 0 } },
	Hit = { S = { 92, 0, 0 }, E = 0, W = { -92, 0, 0 } },
	Twist = 0.4,
	LeanWind = 6,
	LeanHit = -14,
}

local STAFF: { Strike } = {
	{ Wind = { S = { 70, -40, 20 }, E = 50, W = { 0, 90, 0 } }, Hit = { S = { 70, 40, 20 }, E = 40, W = { 0, 90, 0 } }, Twist = 1.5, LeanWind = 0, LeanHit = -6 },
	{ Wind = { S = { 30, 20, 30 }, E = 40, W = { 45, 90, 0 } }, Hit = { S = { 140, -20, 30 }, E = 30, W = { -45, 90, 0 } }, Twist = -1, LeanWind = -4, LeanHit = 8 },
	{ Wind = { S = { 70, 40, 20 }, E = 40, W = { 0, 90, 0 } }, Hit = { S = { 70, -40, 20 }, E = 50, W = { 0, 90, 0 } }, Twist = -1.5, LeanWind = 0, LeanHit = -6 },
	{ Wind = { S = { 120, 0, 25 }, E = 40, W = { 0, 90, 0 } }, Hit = { S = { 80, 0, 25 }, E = 30, W = { 0, 90, 0 } }, Twist = 0, LeanWind = 6, LeanHit = -12 },
}

local function staffArms(rightArm: Pose): Pose
	-- les deux mains tiennent le bâton : la gauche suit la droite, décalée sur la hampe
	local rs = rightArm.RightShoulder or CFrame.identity
	return compose(rightArm, {
		LeftShoulder = CFrame.Angles(0, 0, math.rad(-30)) * mirror({ RightShoulder = rs }).LeftShoulder,
		LeftElbow = rightArm.RightElbow or CFrame.identity,
		LeftWrist = J(0, -90, 0),
	})
end

-- Pose des bras pour un motif, selon l'arme et la main qui frappe.
local function strikeArms(s: Style, weapon: string, spec: ArmSpec, index: number, striking: boolean): Pose
	local amp = s.SwingAmp
	local r = arm(spec, amp)
	if weapon == "Staff" then
		return staffArms(r)
	elseif weapon == "Dual" then
		local g = guardArms(s, weapon)
		if index == 5 then
			return compose(r, leftArmOf(r)) -- double coup simultané
		elseif index % 2 == 0 then
			-- la main gauche frappe, la droite reste en garde
			return compose(rightArmOf(g), leftArmOf(r))
		end
		return compose(r, { LeftShoulder = g.LeftShoulder, LeftElbow = g.LeftElbow, LeftWrist = g.LeftWrist })
	elseif s.TwoHanded then
		return compose(r, twoHand(r))
	end
	return compose(r, offHand(s, striking))
end

local function strikeFor(s: Style, weapon: string, index: number): Strike
	if weapon == "Staff" then
		return STAFF[((index - 1) % #STAFF) + 1]
	end
	if s.OffHandFencing and index == 3 then
		return THRUST
	end
	return SINGLE[((index - 1) % #SINGLE) + 1]
end

-- Signe du buste : les coups de la main gauche (Jumelles) tournent dans l'autre sens.
local function twistSign(weapon: string, index: number): number
	if weapon == "Dual" and index % 2 == 0 and index ~= 5 then
		return -1
	end
	return 1
end

local function bodyAt(s: Style, twist: number, lean: number, crouchExtra: number, staggerExtra: number): Pose
	return compose(Core.legs(s.Crouch + crouchExtra, s.Spread, s.Stagger + staggerExtra), {
		Waist = J(s.Lean + lean, s.GuardYaw * 0.3 + twist * s.SwingTwist, 0),
		Neck = J(-(s.Lean + lean) * 0.5, -twist * s.SwingTwist * 0.55, 0),
	})
end

--------------------------------------------------------------------------------
-- Variantes de direction

local function variantOverlay(s: Style, suffix: string, index: number): Pose?
	local k = if s.OffHandFencing then 1.4 else 1
	if suffix == "_F" then
		return {
			Root = J(0, 0, 0, 0, -0.15 * k, -0.9 * k),
			Waist = J(-12 * k, 0, 0),
			RightHip = J(32 * k, 0, 0),
			RightKnee = J(-18 * k, 0, 0),
			LeftHip = J(-24 * k, 0, 0),
			LeftKnee = J(-16, 0, 0),
		}
	elseif suffix == "_S" then
		local sign = if index % 2 == 1 then 1 else -1
		return {
			Root = J(0, 22 * sign, 0, 0.6 * sign, -0.1, 0),
			Waist = J(0, 18 * sign, -6 * sign),
		}
	elseif suffix == "_B" then
		return {
			Root = J(6, 0, 0, 0, 0, 0.7),
			Waist = J(8, 0, 0),
			Neck = J(-6, 0, 0),
			LeftHip = J(-18, 0, 0),
			RightHip = J(-10, 0, 0),
		}
	end
	return nil
end

-- Saltos : rotations par pas de 90° (le Lerp de CFrame prend toujours le plus court chemin).
local function flipKeys(axis: string, sign: number, t0: number, t1: number, height: number, base: Pose, e: string?): { KeySpec }
	local keys: { KeySpec } = {}
	for i = 1, 4 do
		local f = i / 4
		local ang = 90 * i * sign
		local rot = if axis == "X" then J(ang, 0, 0) elseif axis == "Z" then J(0, 0, ang) else J(0, ang, 0)
		local lift = math.sin(f * math.pi) * height
		local tuck: Pose = {}
		if i < 4 then
			tuck = {
				RightHip = J(75, 0, 8),
				RightKnee = J(-110, 0, 0),
				LeftHip = J(75, 0, -8),
				LeftKnee = J(-110, 0, 0),
				Waist = J(-25, 0, 0),
			}
		end
		local p = merge(base, tuck)
		p.Root = CFrame.new(0, lift, 0) * rot * (if i < 4 then CFrame.identity else (base.Root or CFrame.identity))
		table.insert(keys, { t = t0 + (t1 - t0) * f, p = p, e = e or "linear" })
	end
	return keys
end

local function rngFor(id: string, s: Style): Random
	return Random.new(Core.hash(id .. "|" .. s.Id))
end

-- Tempête : secousses sur les keyframes intermédiaires.
local function stormify(id: string, s: Style, keys: { KeySpec }): { KeySpec }
	if s.Jitter <= 0 then
		return keys
	end
	local rng = rngFor(id, s)
	local joints = { "Waist", "Neck", "RightShoulder", "LeftShoulder" }
	local out: { KeySpec } = {}
	for i, k in keys do
		if i > 1 and i < #keys then
			table.insert(out, { t = k.t, p = Core.jitter(k.p, rng, s.Jitter, joints), e = k.e })
		else
			table.insert(out, k)
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Clips

local function idle(s: Style, weapon: string): Clip
	local g = guard(s, weapon)
	local up = add(g, { Root = J(0, 0, 0, 0, s.IdleBob, 0), Waist = J(-2, 0, 0) }, 1)
	local keys: { KeySpec } = { { t = 0, p = g }, { t = 0.5, p = up }, { t = 1, p = g } }
	if s.Fluid then
		keys = {
			{ t = 0, p = g },
			{ t = 0.25, p = add(g, { Waist = J(-2, 6, 0), Root = J(0, 0, 0, 0, s.IdleBob, 0) }, 1) },
			{ t = 0.5, p = g },
			{ t = 0.75, p = add(g, { Waist = J(-2, -6, 0), Root = J(0, 0, 0, 0, s.IdleBob, 0) }, 1) },
			{ t = 1, p = g },
		}
	elseif s.Jitter > 0 then
		local rng = rngFor("Idle", s)
		keys = { { t = 0, p = g } }
		for i = 1, 5 do
			table.insert(keys, { t = i / 6, p = Core.jitter(up, rng, s.Jitter * 0.4, { "Waist", "Neck", "RightShoulder" }), e = "quadOut" })
		end
		table.insert(keys, { t = 1, p = g })
	end
	return Core.clip("Idle", s.IdlePeriod, keys, { Looped = true, Layer = Layers.Base, FadeIn = 0.25, FadeOut = 0.25 })
end

local function run(s: Style, weapon: string): Clip
	local r: Pose
	if s.Acrobatic then
		r = { RightShoulder = J(-60, 0, 15), RightElbow = J(15, 0, 0), RightWrist = J(-40, 0, 0), LeftShoulder = J(-60, 0, -15), LeftElbow = J(15, 0, 0) }
	elseif s.HeavyBody then
		r = compose({ RightShoulder = J(155, -20, 40), RightElbow = J(95, 0, 0), RightWrist = J(40, 0, 0) }, offHand(s, false))
	elseif s.Id == "Rempart" then
		r = upperOnly(guardArms(s, weapon))
	elseif s.OffHandFencing then
		r = compose({ RightShoulder = J(20, 0, 12), RightElbow = J(25, 0, 0), RightWrist = J(-30, 0, 0) }, offHand(s, false))
	else
		r = compose({ RightShoulder = J(-25, 0, 20), RightElbow = J(30, 0, 0), RightWrist = J(-70, 0, 0) }, offHand(s, false))
	end
	if weapon == "Dual" and not s.Acrobatic then
		r = compose(rightArmOf(r), leftArmOf(r))
	elseif weapon == "Staff" and s.Id ~= "Rempart" then
		r = compose({ RightShoulder = J(-10, 0, 15), RightElbow = J(20, 0, 0), RightWrist = J(0, 90, 0) }, offHand(s, false))
	end
	local lean = if s.Acrobatic then -25 elseif s.Jitter > 0 then -22 else -8 + s.Lean * 0.3
	local a = merge(r, { Waist = J(lean, 6, 0), Neck = J(-lean * 0.6, -6, 0) })
	local b = merge(r, { Waist = J(lean, -6, 0), Neck = J(-lean * 0.6, 6, 0) })
	if not s.Acrobatic and s.Id ~= "Rempart" then
		a = add(a, { LeftShoulder = J(18, 0, 0) }, 1)
		b = add(b, { LeftShoulder = J(-18, 0, 0) }, 1)
	end
	return Core.clip("Run", 0.7, {
		{ t = 0, p = a },
		{ t = 0.5, p = b },
		{ t = 1, p = a },
	}, { Looped = true, Layer = Layers.Base, FadeIn = 0.2, FadeOut = 0.2 })
end

local function jump(s: Style, weapon: string): Clip?
	if not s.Acrobatic then
		return nil
	end
	local g = guard(s, weapon)
	local keys: { KeySpec } = { { t = 0, p = g } }
	for _, k in flipKeys("X", -1, 0.1, 0.8, 0.6, g, "linear") do
		table.insert(keys, k)
	end
	table.insert(keys, { t = 1, p = g })
	return Core.clip("Jump", 0.6, keys, { Layer = Layers.Action, FadeIn = 0.05, FadeOut = 0.15 })
end

local function light(id: string, s: Style, weapon: string, index: number, suffix: string, air: boolean): Clip?
	local w = WeaponData.get(weapon)
	if not w or index < 1 or index > w.ComboLength then
		return nil
	end
	local duration = Config.Light.Windup + Config.Light.Recovery + (if index >= w.ComboLength then Config.Light.FinisherExtraRecovery else 0)
	local wf = Config.Light.Windup / duration
	local st = if air then SINGLE[4] else strikeFor(s, weapon, index)
	if air and weapon == "Staff" then
		st = STAFF[4]
	end
	local sign = twistSign(weapon, index)
	local g = guard(s, weapon)
	local crouchHit = if s.HeavyBody then 0.25 else 0.1
	local wind = compose(bodyAt(s, -st.Twist * sign, st.LeanWind, 0, 0), strikeArms(s, weapon, st.Wind, index, false))
	local hit = compose(bodyAt(s, st.Twist * sign, st.LeanHit, crouchHit, 10), strikeArms(s, weapon, st.Hit, index, true))
	local follow = add(hit, { Waist = J(-4, st.Twist * sign * 10, 0) }, 1)

	local midHop: Pose? = nil
	if s.Hop > 0 and not air then
		midHop = add(wind, { Root = J(0, 0, 0, 0, s.Hop * 0.5, 0) }, 1)
	end

	local keys: { KeySpec } = {
		{ t = 0, p = g, e = "quadOut" },
		{ t = wf * 0.6, p = midHop or wind, e = s.SwingEase },
		{ t = wf, p = hit, e = "quadOut" },
		{ t = wf + (1 - wf) * 0.35, p = follow, e = if s.Fluid then "sine" else "quad" },
		{ t = 1, p = g },
	}

	-- Jumelles, coup 5 : tourbillon complet
	if weapon == "Dual" and index == 5 and not air then
		keys = { { t = 0, p = g, e = "quadOut" }, { t = wf * 0.4, p = wind, e = "linear" } }
		for i = 1, 4 do
			local p = merge(hit, {})
			p.Root = J(0, -90 * i, 0, 0, -0.1, 0)
			table.insert(keys, { t = wf * 0.4 + (wf * 1.25 - wf * 0.4) * i / 4, p = p, e = "linear" })
		end
		table.insert(keys, { t = 1, p = g })
	end

	if air then
		local tuck: Pose = { RightHip = J(70, 0, 8), RightKnee = J(-100, 0, 0), LeftHip = J(40, 0, -8), LeftKnee = J(-80, 0, 0), Root = J(0, 0, 0, 0, 0.2, 0) }
		for i = 2, 4 do
			keys[i] = { t = keys[i].t, p = merge(keys[i].p, tuck), e = keys[i].e }
		end
		if s.Acrobatic then
			-- Faucon : salto avant puis frappe plongeante
			local flips = flipKeys("X", -1, 0.02, wf * 0.95, 0.4, wind, "linear")
			keys = { { t = 0, p = g, e = "linear" } }
			for _, k in flips do
				table.insert(keys, k)
			end
			table.insert(keys, { t = wf, p = merge(hit, tuck), e = "quadOut" })
			table.insert(keys, { t = 1, p = g })
		end
	else
		local ov = variantOverlay(s, suffix, index)
		if ov then
			local weights = { 0, 0.5, 1, 0.8, 0 }
			for i, k in keys do
				local wgt = weights[math.min(i, #weights)] or 0
				if i > 1 and i < #keys and wgt > 0 then
					keys[i] = { t = k.t, p = add(k.p, ov, wgt), e = k.e }
				end
			end
		end
	end

	keys = stormify(id, s, keys)
	return Core.clip(id, duration, keys, {
		FadeIn = 0.04,
		FadeOut = 0.12,
		Markers = { { Time = wf * 0.7, Name = "Swing" }, { Time = wf, Name = "Impact" } },
	})
end

local function counter(s: Style, weapon: string): Clip
	local windup = Config.Light.Windup * Config.Counter.WindupMult
	local duration = windup + Config.Light.Recovery
	local wf = windup / duration
	local g = guard(s, weapon)
	local thrust = compose(bodyAt(s, 0.3, -16, 0.15, 18), strikeArms(s, weapon, THRUST.Hit, 1, true))
	thrust = add(thrust, { Root = J(0, 0, 0, 0, -0.1, -0.8) }, 1)
	return Core.clip("Counter", duration, {
		{ t = 0, p = g, e = "expoIn" },
		{ t = wf, p = thrust, e = "quadOut" },
		{ t = wf + (1 - wf) * 0.4, p = thrust, e = "sine" },
		{ t = 1, p = g },
	}, { FadeIn = 0.03, Markers = { { Time = wf, Name = "Impact" } } })
end

local function heavyCharge(s: Style, weapon: string): Clip
	local spec: ArmSpec
	if weapon == "Staff" then
		spec = { S = { 100, -60, 30 }, E = 40, W = { 0, 90, 0 } }
	elseif s.HeavyBody then
		spec = { S = { 178, -10, 20 }, E = 50, W = { 40, 0, 0 } }
	else
		spec = { S = { 160, -30, 60 }, E = 40, W = { 30, 0, 0 } }
	end
	local arms = strikeArms(s, weapon, spec, 1, false)
	if weapon == "Dual" then
		arms = compose(rightArmOf(arms), leftArmOf(arms))
	end
	local body = upperOnly(bodyAt(s, -1.2, if s.HeavyBody then 10 else 6, 0, 0))
	local p = compose(body, arms)
	local a = add(p, { RightShoulder = J(2, 0, 0), Waist = J(0, 2, 0) }, 1)
	local b = add(p, { RightShoulder = J(-2, 0, 0), Waist = J(0, -2, 0) }, 1)
	return Core.clip("M2_Charge", 0.24, { { t = 0, p = p }, { t = 0.33, p = a }, { t = 0.66, p = b }, { t = 1, p = p } }, {
		Looped = true,
		FadeIn = 0.12,
		FadeOut = 0.1,
	})
end

local function heavyStrike(s: Style, weapon: string): Clip?
	local w = WeaponData.get(weapon)
	if not w then
		return nil
	end
	local duration = Config.Heavy.StrikeWindup + w.HeavyRecovery
	local wf = Config.Heavy.StrikeWindup / duration
	local g = guard(s, weapon)
	local wind = compose(bodyAt(s, -1.3, 10, 0.05, 0), strikeArms(s, weapon, { S = { 170, -20, 40 }, E = 40, W = { 35, 0, 0 } }, 1, false))
	local hitArms = strikeArms(s, weapon, { S = { 50, 35, -30 }, E = 5, W = { -65, 0, 0 } }, 1, true)
	if weapon == "Dual" then
		hitArms = compose(rightArmOf(hitArms), leftArmOf(hitArms)) -- coupe en X
		wind = compose(wind, leftArmOf(wind))
	end
	local hit = compose(bodyAt(s, 1.3, -28, if s.HeavyBody then 0.5 else 0.3, 20), hitArms)
	hit = add(hit, { Root = J(0, 0, 0, 0, 0, -0.6) }, 1)
	local keys: { KeySpec } = {
		{ t = 0, p = wind, e = s.SwingEase },
		{ t = wf, p = hit, e = "quadOut" },
		{ t = wf + (1 - wf) * 0.45, p = add(hit, { Waist = J(-4, 8, 0) }, 1), e = "sine" },
		{ t = 1, p = g },
	}
	if weapon == "Staff" then
		-- frappe circulaire à 360°
		keys = { { t = 0, p = wind, e = "linear" } }
		for i = 1, 4 do
			local p = merge(hit, {})
			p.Root = J(0, 90 * i, 0, 0, -0.25, 0)
			table.insert(keys, { t = wf * 1.6 * i / 4, p = p, e = "linear" })
		end
		table.insert(keys, { t = wf * 1.6 + (1 - wf * 1.6) * 0.4, p = hit, e = "sine" })
		table.insert(keys, { t = 1, p = g })
	end
	keys = stormify("M2_Strike", s, keys)
	return Core.clip("M2_Strike", duration, keys, {
		FadeIn = 0.05,
		FadeOut = 0.15,
		Markers = { { Time = wf * 0.6, Name = "Swing" }, { Time = wf, Name = "Impact" } },
	})
end

local function blockPose(s: Style, weapon: string): Pose
	local arms: Pose
	if weapon == "Staff" then
		arms = {
			RightShoulder = J(110, 0, 25),
			RightElbow = J(40, 0, 0),
			RightWrist = J(0, 90, 0),
			LeftShoulder = J(110, 0, -25),
			LeftElbow = J(40, 0, 0),
			LeftWrist = J(0, -90, 0),
		}
	elseif weapon == "Dual" then
		local r: Pose = { RightShoulder = J(80, 30, 0), RightElbow = J(50, 0, 0), RightWrist = J(0, 45, 0) }
		arms = compose(r, leftArmOf(r))
	elseif s.Id == "Rempart" then
		local r: Pose = { RightShoulder = J(45, 20, 0), RightElbow = J(85, 0, 0), RightWrist = J(10, 70, 0) }
		arms = compose(r, twoHand(r))
	elseif s.OffHandFencing then
		arms = compose({ RightShoulder = J(70, 10, 0), RightElbow = J(40, 0, 0), RightWrist = J(-10, 0, 0) }, offHand(s, false))
	else
		local r: Pose = { RightShoulder = J(105, 35, 0), RightElbow = J(55, 0, 0), RightWrist = J(0, 90, 0) }
		arms = if s.TwoHanded then compose(r, twoHand(r)) else compose(r, offHand(s, false))
	end
	local lean = if s.Id == "Rempart" then -12 else -6
	return compose(arms, { Waist = J(lean, s.GuardYaw * 0.4, 0), Neck = J(-lean * 0.5, -s.GuardYaw * 0.3, 0) })
end

local function block(s: Style, weapon: string): Clip
	local p = blockPose(s, weapon)
	local b = add(p, { Waist = J(0, 2, 0) }, 1)
	return Core.clip("Block", 1.2, { { t = 0, p = p }, { t = 0.5, p = b }, { t = 1, p = p } }, { Looped = true, FadeIn = 0.06, FadeOut = 0.1 })
end

local function blockHit(s: Style, weapon: string): Clip
	local p = blockPose(s, weapon)
	local recoil = add(p, { Waist = J(10, 0, 0), Neck = J(6, 0, 0), RightShoulder = J(-14, 0, 0), LeftShoulder = J(-14, 0, 0) }, 1)
	return Core.clip("BlockHit", 0.24, { { t = 0, p = p, e = "quadOut" }, { t = 0.3, p = recoil, e = "sine" }, { t = 1, p = p } }, {
		Layer = Layers.Reaction,
		FadeIn = 0.02,
		FadeOut = 0.08,
	})
end

local function parry(s: Style, weapon: string): Clip
	local g = upperOnly(guard(s, weapon))
	local spec: ArmSpec = { S = { 120, 60, -20 }, E = 30, W = { -30, 0, 0 } }
	if s.Id == "Rempart" then
		spec = { S = { 60, 50, -10 }, E = 70, W = { -20, 0, 0 } }
	end
	local arms = strikeArms(s, weapon, spec, 1, true)
	if weapon == "Dual" then
		arms = compose(rightArmOf(arms), leftArmOf(arms))
	end
	local deflect = compose(upperOnly(bodyAt(s, 0.6, if s.HeavyBody then -14 else -4, 0, 0)), arms)
	return Core.clip("Parry", 0.4, {
		{ t = 0, p = g, e = "expoOut" },
		{ t = 0.22, p = deflect, e = "sine" },
		{ t = 0.55, p = deflect, e = "sine" },
		{ t = 1, p = g },
	}, { FadeIn = 0.02, FadeOut = 0.1 })
end

local function dodge(s: Style, weapon: string, dir: string): Clip
	local g = guard(s, weapon)
	local duration = Config.Dodge.Duration
	local scale = if s.OffHandFencing then 0.5 elseif s.Id == "Rempart" then 0.65 else 1
	local keys: { KeySpec }
	if s.Acrobatic then
		local axis = if dir == "F" or dir == "B" then "X" else "Z"
		local sign = if dir == "F" then -1 elseif dir == "B" then 1 elseif dir == "R" then -1 else 1
		keys = { { t = 0, p = g, e = "linear" } }
		for _, k in flipKeys(axis, sign, 0.05, 0.85, 1.1, g, "linear") do
			table.insert(keys, k)
		end
		table.insert(keys, { t = 1, p = g })
	elseif s.Fluid and (dir == "L" or dir == "R") then
		-- Équilibre : pirouette latérale
		local sign = if dir == "L" then 1 else -1
		keys = { { t = 0, p = g, e = "linear" } }
		for i = 1, 3 do
			local p = merge(g, {})
			p.Root = J(0, 120 * i * sign, 0, 0, -0.2, 0)
			table.insert(keys, { t = 0.85 * i / 3, p = p, e = "linear" })
		end
		table.insert(keys, { t = 1, p = g })
	else
		local pose: Pose
		if dir == "F" then
			pose = compose(g, {
				Root = J(-25 * scale, 0, 0, 0, -0.6 * scale, -0.4),
				Waist = J(-15 * scale, 0, 0),
				RightShoulder = J(-40, 0, 20),
				RightHip = J(60 * scale, 0, 5),
				RightKnee = J(-70 * scale, 0, 0),
				LeftHip = J(-20, 0, -5),
				LeftKnee = J(-40, 0, 0),
			})
			if s.TwoHanded then
				pose = compose(pose, twoHand(pose))
			end
		elseif dir == "B" then
			pose = add(g, {
				Root = J(12 * scale, 0, 0, 0, 0.25 * scale, 0.3),
				Waist = J(10 * scale, 0, 0),
				RightHip = J(-20 * scale, 0, 0),
				LeftHip = J(30 * scale, 0, 0),
				LeftKnee = J(-50 * scale, 0, 0),
			}, 1)
		else
			local r = add(g, {
				Root = J(0, 0, -14 * scale, 0.4 * scale, -0.35 * scale, 0),
				Waist = J(0, 0, -8 * scale),
				RightHip = J(0, 0, 25 * scale),
				LeftHip = J(0, 0, 10 * scale),
				LeftKnee = J(-30, 0, 0),
			}, 1)
			pose = if dir == "R" then r else mirror(r)
		end
		keys = { { t = 0, p = g, e = "quadOut" }, { t = 0.3, p = pose, e = "sine" }, { t = 0.7, p = pose, e = "sine" }, { t = 1, p = g } }
	end
	keys = stormify("Dodge_" .. dir, s, keys)
	return Core.clip("Dodge_" .. dir, duration, keys, { FadeIn = 0.03, FadeOut = 0.08 })
end

local function stunned(s: Style, weapon: string): Clip
	local g = guard(s, weapon)
	local hit = compose(Core.legs(s.Crouch + 0.1, s.Spread + 4, -10), {
		Root = J(14, 0, 0, 0, -0.1, 0.3),
		Waist = J(18, 10, 8),
		Neck = J(20, 0, 0),
		RightShoulder = J(60, 0, 70),
		RightElbow = J(20, 0, 0),
		RightWrist = J(20, 0, 0),
		LeftShoulder = J(30, 0, -60),
		LeftElbow = J(20, 0, 0),
	})
	local wobble = add(hit, { Waist = J(-6, -14, -6), Neck = J(-8, 10, 0) }, 1)
	return Core.clip("Stunned", Config.Parry.AttackerStun, {
		{ t = 0, p = g, e = "backOut" },
		{ t = 0.18, p = hit, e = "sine" },
		{ t = 0.55, p = wobble, e = "sine" },
		{ t = 1, p = g },
	}, { FadeIn = 0.03, FadeOut = 0.15 })
end

local function flinch(s: Style, weapon: string): Clip
	local g = upperOnly(guard(s, weapon))
	local f = add(g, { Waist = J(12, 8, 4), Neck = J(14, -6, 0) }, 1)
	return Core.clip("Flinch", Config.Light.HitStun, { { t = 0, p = g, e = "expoOut" }, { t = 0.3, p = f, e = "sine" }, { t = 1, p = g } }, {
		Layer = Layers.Reaction,
		FadeIn = 0.02,
		FadeOut = 0.08,
	})
end

local function guardBroken(s: Style, weapon: string): Clip
	local g = guard(s, weapon)
	local open = compose(Core.legs(0.6, s.Spread + 6, -14), {
		Root = J(18, 0, 0, 0, -0.6, 0.4),
		Waist = J(25, 15, 0),
		Neck = J(25, 0, 0),
		RightShoulder = J(-20, 0, 80),
		RightElbow = J(10, 0, 0),
		RightWrist = J(40, 0, 0),
		LeftShoulder = J(-10, 0, -70),
		LeftElbow = J(15, 0, 0),
	})
	local sag = add(open, { Waist = J(-30, -20, 6), Neck = J(-20, 0, 0), Root = J(0, 0, 0, 0, -0.2, 0) }, 1)
	return Core.clip("GuardBroken", Config.GuardBroken.Duration, {
		{ t = 0, p = g, e = "expoOut" },
		{ t = 0.12, p = open, e = "sine" },
		{ t = 0.5, p = sag, e = "sine" },
		{ t = 0.82, p = sag, e = "sine" },
		{ t = 1, p = g },
	}, { FadeIn = 0.03, FadeOut = 0.2 })
end

function Combat.defeatedPose(): Pose
	return {
		Root = J(0, 0, 0, 0, -1.1, 0),
		RightHip = J(85, 0, 6),
		RightKnee = J(-85, 0, 0),
		RightAnkle = J(0, 0, 0),
		LeftHip = J(-10, 0, -6),
		LeftKnee = J(-95, 0, 0),
		LeftAnkle = J(15, 0, 0),
		Waist = J(-30, 0, 0),
		Neck = J(-25, 0, 0),
		RightShoulder = J(10, 0, 10),
		RightElbow = J(10, 0, 0),
		RightWrist = J(-60, 0, 0),
		LeftShoulder = J(5, 0, -8),
		LeftElbow = J(10, 0, 0),
		LeftWrist = J(0, 0, 0),
	}
end

local function defeated(): Clip
	local p = Combat.defeatedPose()
	local b = add(p, { Waist = J(-3, 0, 0), Root = J(0, 0, 0, 0, -0.03, 0) }, 1)
	return Core.clip("Defeated", 2.2, { { t = 0, p = p }, { t = 0.5, p = b }, { t = 1, p = p } }, { Looped = true, FadeIn = 0.35, FadeOut = 0.3 })
end

local function ignite(s: Style, weapon: string): Clip
	local g = upperOnly(guard(s, weapon))
	local leftPresent: Pose = offHand(s, false)
	local leftFlourish: Pose = offHand(s, true)
	if weapon == "Dual" then
		leftPresent = { LeftShoulder = J(70, 0, 10), LeftElbow = J(90, 0, 0), LeftWrist = J(0, 0, 0) }
		leftFlourish = { LeftShoulder = J(140, 20, -40), LeftElbow = J(30, 0, 0), LeftWrist = J(20, 0, 0) }
	end
	local present = compose(
		{ RightShoulder = J(70, 0, -10), RightElbow = J(90, 0, 0), RightWrist = J(0, 0, 0) },
		leftPresent,
		{ Waist = J(-4, 0, 0), Neck = J(-12, 0, 0) }
	)
	local flourish = compose(
		{ RightShoulder = J(140, -20, 40), RightElbow = J(30, 0, 0), RightWrist = J(20, 0, 0) },
		leftFlourish,
		{ Waist = J(4, -10, 0), Neck = J(4, 8, 0) }
	)
	if weapon == "Staff" then
		flourish = compose(flourish, { RightWrist = J(0, 90, 0), LeftShoulder = J(60, 0, -20), LeftElbow = J(60, 0, 0) })
	end
	return Core.clip("Ignite", 1.2, {
		{ t = 0, p = g, e = "quadOut" },
		{ t = 0.28, p = present, e = "sine" },
		{ t = 0.4, p = present, e = "backOut" },
		{ t = 0.62, p = flourish, e = "sine" },
		{ t = 1, p = g },
	}, { FadeIn = 0.1, FadeOut = 0.2, Markers = { { Time = 0.35, Name = "On" } } })
end

local function saberLock(s: Style, weapon: string): Clip
	local r: Pose = { RightShoulder = J(95, 25, 0), RightElbow = J(35, 0, 0), RightWrist = J(10, 60, 0) }
	local arms = if weapon == "Dual" then compose(r, leftArmOf(r)) elseif weapon == "Staff" then staffArms(r) else compose(r, twoHand(r))
	local p = compose(Core.legs(0.55, 12, 30), arms, { Root = J(0, 0, 0, 0, -0.55, -0.2), Waist = J(-15, 0, 0), Neck = J(10, 0, 0) })
	local a = add(p, { RightShoulder = J(3, 0, 0), LeftShoulder = J(3, 0, 0), Waist = J(-1, 2, 0) }, 1)
	local b = add(p, { RightShoulder = J(-3, 0, 0), LeftShoulder = J(-3, 0, 0), Waist = J(1, -2, 0) }, 1)
	return Core.clip("SaberLock", 0.36, { { t = 0, p = p }, { t = 0.3, p = a }, { t = 0.7, p = b }, { t = 1, p = p } }, {
		Looped = true,
		FadeIn = 0.08,
		FadeOut = 0.2,
	})
end

--------------------------------------------------------------------------------
-- Aiguillage

-- Pose de garde exportée (cinématiques, emotes, exécutions).
function Combat.guardPose(s: Style, weapon: string): Pose
	return guard(s, weapon)
end

function Combat.strikePoses(s: Style, weapon: string, heavy: boolean): (Pose, Pose)
	local wind = compose(bodyAt(s, -1.3, 10, 0.05, 0), strikeArms(s, weapon, { S = { 170, -20, 40 }, E = 40, W = { 35, 0, 0 } }, 1, false))
	local hitArms = strikeArms(s, weapon, { S = { 50, 35, -30 }, E = 5, W = { -65, 0, 0 } }, 1, true)
	if weapon == "Dual" then
		hitArms = compose(rightArmOf(hitArms), leftArmOf(hitArms))
		wind = compose(wind, leftArmOf(wind))
	end
	local hit = compose(bodyAt(s, 1.3, -28, if heavy then 0.5 else 0.25, 20), hitArms)
	return wind, hit
end

function Combat.flipKeys(axis: string, sign: number, t0: number, t1: number, height: number, base: Pose, e: string?): { KeySpec }
	return flipKeys(axis, sign, t0, t1, height, base, e)
end

function Combat.stormify(id: string, s: Style, keys: { KeySpec }): { KeySpec }
	return stormify(id, s, keys)
end

function Combat.build(clipId: string, s: Style, weapon: string): Clip?
	if clipId == "Idle" then
		return idle(s, weapon)
	elseif clipId == "Run" then
		return run(s, weapon)
	elseif clipId == "Jump" then
		return jump(s, weapon)
	elseif clipId == "M1_Air" then
		return light(clipId, s, weapon, 4, "", true)
	elseif clipId == "Counter" then
		return counter(s, weapon)
	elseif clipId == "M2_Charge" then
		return heavyCharge(s, weapon)
	elseif clipId == "M2_Strike" then
		return heavyStrike(s, weapon)
	elseif clipId == "Block" then
		return block(s, weapon)
	elseif clipId == "BlockHit" then
		return blockHit(s, weapon)
	elseif clipId == "Parry" then
		return parry(s, weapon)
	elseif clipId == "Stunned" then
		return stunned(s, weapon)
	elseif clipId == "Flinch" then
		return flinch(s, weapon)
	elseif clipId == "GuardBroken" then
		return guardBroken(s, weapon)
	elseif clipId == "Defeated" then
		return defeated()
	elseif clipId == "Ignite" then
		return ignite(s, weapon)
	elseif clipId == "SaberLock" then
		return saberLock(s, weapon)
	end
	local d = string.match(clipId, "^Dodge_([FBLR])$")
	if d then
		return dodge(s, weapon, d)
	end
	local idx, suffix = string.match(clipId, "^M1_(%d)(.*)$")
	if idx then
		local sfx = suffix or ""
		if sfx == "" or sfx == "_F" or sfx == "_S" or sfx == "_B" then
			return light(clipId, s, weapon, tonumber(idx) or 1, sfx, false)
		end
	end
	return nil
end

return table.freeze(Combat)
