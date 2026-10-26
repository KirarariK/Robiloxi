--!strict
--[[
	Refonte qualité — KeyframeSequence R15 corps entier (torse, hanches, bras ×2,
	jambes upper+lower, tête, HiltGrip) pour feeling combat sabre compétitif.

	Courbes : easeInOutCubic / easeOutCubic / easeInCubic / easeOutBack (overshoot
	contrôlé). Active Light/Heavy ≥11 keyframes :
	Anticipation → weight shift → coupe → follow-through → settle.

	ProceduralPlayer.samplePose suit la même timeline.
	Sources : Pose / KeyframeSequence / KeyframeSequenceProvider + skill roblox-animation-vfx.
]]

local Shared = script.Parent.Parent:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local AnimationSets = require(script.Parent:WaitForChild("AnimationSets"))

export type JointMap = { [string]: CFrame }

local KeyframeFactory = {}

-- Limites Euler relatives (°) — enveloppe R15 combat sabre
local LIM = {
	UpperArm = { p = { -82, 55 }, y = { -72, 68 }, r = { -42, 42 } },
	LowerArm = { p = { -82, 8 }, y = { -28, 28 }, r = { -18, 18 } },
	Hand = { p = { -35, 35 }, y = { -35, 35 }, r = { -30, 30 } },
	Hilt = { p = { -48, 48 }, y = { -55, 55 }, r = { -35, 35 } },
	Torso = { p = { -22, 22 }, y = { -32, 32 }, r = { -22, 22 } },
	Head = { p = { -28, 32 }, y = { -28, 28 }, r = { -18, 18 } },
	Leg = { p = { -28, 28 }, y = { -18, 18 }, r = { -16, 16 } },
	LowerLeg = { p = { -8, 42 }, y = { -10, 10 }, r = { -8, 8 } },
}

local function attackPhaseDuration(clipName: string): number
	local heavy = string.find(clipName, "Heavy") ~= nil
	local cfg = if heavy then CombatConfig.Heavy else CombatConfig.Light
	if string.sub(clipName, 1, 7) == "Startup" then
		return cfg.Startup
	elseif string.sub(clipName, 1, 6) == "Active" then
		return cfg.Active
	elseif string.sub(clipName, 1, 8) == "Recovery" then
		return cfg.Recovery
	end
	return 0.3
end

local function clampDeg(v: number, lo: number, hi: number): number
	return math.clamp(v, lo, hi)
end

local function ang(xDeg: number, yDeg: number, zDeg: number): CFrame
	return CFrame.Angles(math.rad(xDeg), math.rad(yDeg), math.rad(zDeg))
end

local function angLim(
	xDeg: number,
	yDeg: number,
	zDeg: number,
	lim: { p: { number }, y: { number }, r: { number } }
): CFrame
	return ang(clampDeg(xDeg, lim.p[1], lim.p[2]), clampDeg(yDeg, lim.y[1], lim.y[2]), clampDeg(zDeg, lim.r[1], lim.r[2]))
end

---------------------------------------------------------------------------
-- Courbes (pas un seul smoothstep) — overshoot contrôlé pour la coupe
---------------------------------------------------------------------------

local function smoothstep(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeInCubic(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * x
end

local function easeOutCubic(t: number): number
	local x = math.clamp(t, 0, 1)
	local u = 1 - x
	return 1 - u * u * u
end

local function easeInOutCubic(t: number): number
	local x = math.clamp(t, 0, 1)
	if x < 0.5 then
		return 4 * x * x * x
	end
	local u = -2 * x + 2
	return 1 - (u * u * u) / 2
end

-- Overshoot léger (s ≈ 1.15) — follow-through épée, pas un snap
local function easeOutBack(t: number): number
	local x = math.clamp(t, 0, 1)
	local s = 1.15
	local u = x - 1
	return 1 + (s + 1) * (u * u * u) + s * (u * u)
end

local function sanitizeStyle(style: AnimationSets.StyleParams): AnimationSets.StyleParams
	return {
		anticipation = clampDeg(style.anticipation, 0.2, 1.05),
		swingArc = clampDeg(style.swingArc, 0.3, 1.38),
		planeBias = clampDeg(style.planeBias, 0, 1),
		followThrough = clampDeg(style.followThrough, 0.15, 0.95),
		guardPitch = clampDeg(style.guardPitch, -0.85, 0.35),
		idleLean = clampDeg(style.idleLean, -0.16, 0.15),
		torsoTwist = clampDeg(style.torsoTwist, -0.35, 0.52),
		offhand = clampDeg(style.offhand, 0.1, 0.72),
		tempo = clampDeg(style.tempo, 0.65, 1.35),
		doubleBeat = style.doubleBeat,
		priority = style.priority,
	}
end

--[[
	Pose hierarchy R15 + HiltGrip + UpperLegs + LowerLegs.
	CFrames = Transform relatifs (identité = rest pose).
]]
local function buildPoseTree(joints: JointMap): Pose
	local root = Instance.new("Pose")
	root.Name = "HumanoidRootPart"
	root.Weight = 0
	root.CFrame = CFrame.new()

	local lower = Instance.new("Pose")
	lower.Name = "LowerTorso"
	lower.Weight = 1
	lower.CFrame = joints.LowerTorso or CFrame.new()
	root:AddSubPose(lower)

	local upper = Instance.new("Pose")
	upper.Name = "UpperTorso"
	upper.Weight = 1
	upper.CFrame = joints.UpperTorso or CFrame.new()
	lower:AddSubPose(upper)

	local head = Instance.new("Pose")
	head.Name = "Head"
	head.Weight = 1
	head.CFrame = joints.Head or CFrame.new()
	upper:AddSubPose(head)

	local rua = Instance.new("Pose")
	rua.Name = "RightUpperArm"
	rua.Weight = 1
	rua.CFrame = joints.RightUpperArm or CFrame.new()
	upper:AddSubPose(rua)

	local rla = Instance.new("Pose")
	rla.Name = "RightLowerArm"
	rla.Weight = 1
	rla.CFrame = joints.RightLowerArm or CFrame.new()
	rua:AddSubPose(rla)

	local rh = Instance.new("Pose")
	rh.Name = "RightHand"
	rh.Weight = 1
	rh.CFrame = joints.RightHand or CFrame.new()
	rla:AddSubPose(rh)

	local grip = Instance.new("Pose")
	grip.Name = "HiltGrip"
	grip.Weight = 1
	grip.CFrame = joints.HiltGrip or CFrame.new()
	rh:AddSubPose(grip)

	local lua_ = Instance.new("Pose")
	lua_.Name = "LeftUpperArm"
	lua_.Weight = 1
	lua_.CFrame = joints.LeftUpperArm or CFrame.new()
	upper:AddSubPose(lua_)

	local lla = Instance.new("Pose")
	lla.Name = "LeftLowerArm"
	lla.Weight = 1
	lla.CFrame = joints.LeftLowerArm or CFrame.new()
	lua_:AddSubPose(lla)

	local lh = Instance.new("Pose")
	lh.Name = "LeftHand"
	lh.Weight = 1
	lh.CFrame = joints.LeftHand or CFrame.new()
	lla:AddSubPose(lh)

	local rul = Instance.new("Pose")
	rul.Name = "RightUpperLeg"
	rul.Weight = 1
	rul.CFrame = joints.RightUpperLeg or CFrame.new()
	lower:AddSubPose(rul)

	local rll = Instance.new("Pose")
	rll.Name = "RightLowerLeg"
	rll.Weight = 1
	rll.CFrame = joints.RightLowerLeg or CFrame.new()
	rul:AddSubPose(rll)

	local lul = Instance.new("Pose")
	lul.Name = "LeftUpperLeg"
	lul.Weight = 1
	lul.CFrame = joints.LeftUpperLeg or CFrame.new()
	lower:AddSubPose(lul)

	local lll = Instance.new("Pose")
	lll.Name = "LeftLowerLeg"
	lll.Weight = 1
	lll.CFrame = joints.LeftLowerLeg or CFrame.new()
	lul:AddSubPose(lll)

	return root
end

local function addKeyframe(seq: KeyframeSequence, t: number, joints: JointMap, name: string?)
	local kf = Instance.new("Keyframe")
	kf.Time = t
	if name then
		kf.Name = name
	end
	kf:AddPose(buildPoseTree(joints))
	seq:AddKeyframe(kf)
end

local function lerpNumber(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function lerpJoints(a: JointMap, b: JointMap, alpha: number): JointMap
	local t = math.clamp(alpha, 0, 1)
	local out: JointMap = {}
	local keys: { [string]: boolean } = {}
	for k in a do
		keys[k] = true
	end
	for k in b do
		keys[k] = true
	end
	for k in keys do
		local ca = a[k] or CFrame.new()
		local cb = b[k] or CFrame.new()
		out[k] = ca:Lerp(cb, t)
	end
	return out
end

--[[
	phaseKind :
	Idle | Guard | Antici | WeightShift | Contact | Follow | Dodge | Dash |
	Focus | Stagger | Dead | Feint | Riposte
]]
local function sampleJoints(
	style: AnimationSets.StyleParams,
	phaseKind: string,
	alpha: number,
	heavy: boolean
): JointMap
	local s = sanitizeStyle(style)
	local a = math.clamp(alpha, 0, 1)
	local heavyMul = if heavy then 1.12 else 1.0
	local ant = math.min(s.anticipation * heavyMul, 1.08)
	local arc = math.min(s.swingArc * heavyMul, 1.45)
	local plane = s.planeBias
	local twist = s.torsoTwist
	local off = s.offhand
	local lean = s.idleLean
	local shoulderRoll = clampDeg(lerpNumber(14, -18, plane) * arc, -28, 28)
	local hipShift = (if heavy then 1.12 else 0.88) * twist

	local pitch = lerpNumber(0, -78, plane)
	local yaw = lerpNumber(-95, -18, 1 - plane)
	local roll = lerpNumber(18, -8, plane)

	local joints: JointMap = {}

	if phaseKind == "Idle" then
		-- Combat idle vivant : breath + micro-sway épée (phases décalées)
		local bob = math.sin(a * math.pi * 2)
		local bobE = smoothstep((bob + 1) * 0.5) * 2 - 1
		local breath = math.sin(a * math.pi * 2)
		local breathE = easeInOutCubic((breath + 1) * 0.5) * 2 - 1
		local sway = math.sin(a * math.pi * 2 + 1.15)
		local swayE = easeInOutCubic((sway + 1) * 0.5) * 2 - 1
		local tip = math.sin(a * math.pi * 2 + 2.4)
		local tipE = smoothstep((tip + 1) * 0.5) * 2 - 1

		joints.LowerTorso = angLim(2 + lean * 18 + breathE * 1.0, lean * 12 + swayE * 1.4, bobE * 1.4, LIM.Torso)
			* CFrame.new(lean * 0.022 + swayE * 0.01, 0.01 + breathE * 0.016, swayE * 0.005)
		joints.UpperTorso = angLim(-3.5 + breathE * 3.6 + bobE * 1.4, lean * 10 + swayE * 2.8, bobE * 3.2 + swayE * 2.2, LIM.Torso)
		joints.Head = angLim(-4 + breathE * 1.8, lean * -8 + swayE * -1.8, bobE * 1.6, LIM.Head)
		joints.RightUpperArm = angLim(-26 + bobE * 4.5 + breathE * 1.8, -16 + swayE * 2.5, 20 + lean * 18 + bobE * 2.8, LIM.UpperArm)
		joints.RightLowerArm = angLim(-36 + tipE * 1.5, 10, bobE * 1.8, LIM.LowerArm)
		joints.RightHand = angLim(tipE * 2, tipE * 1.5, 8 + bobE * 1.8, LIM.Hand)
		joints.HiltGrip = angLim(bobE * 5 + breathE * 2.5 + tipE * 3, bobE * 3.5 + swayE * 2.5, bobE * 2 + tipE * 2, LIM.Hilt)
		joints.LeftUpperArm = angLim(-16 + breathE * 1.4, 22 + swayE * 2.5, -off * 24, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-42, -10, 0, LIM.LowerArm)
		joints.LeftHand = angLim(0, 0, -4, LIM.Hand)
		joints.RightUpperLeg = angLim(bobE * 1.4 + breathE * 0.5, swayE * 1.0, lean * 4, LIM.Leg)
		joints.RightLowerLeg = angLim(2 + bobE * 0.8, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(-bobE * 1.4 - breathE * 0.5, -swayE * 1.0, -lean * 4, LIM.Leg)
		joints.LeftLowerLeg = angLim(2 - bobE * 0.8, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Guard" then
		-- Garde haute lisible + micro-breath hold (distinct Idle)
		local g = easeOutCubic(a)
		local holdBreath = math.sin(a * math.pi * 2) * 0.4 * smoothstep(math.clamp((a - 0.5) / 0.5, 0, 1))
		local guardArmPitch = clampDeg(s.guardPitch * 58 - 18, -78, 20)
		joints.LowerTorso = angLim(5 + g * 1.5 + holdBreath * 0.7, -twist * 20 * g, hipShift * 5 * g, LIM.Torso)
			* CFrame.new(-hipShift * 0.035 * g, holdBreath * 0.01, 0.01 * g)
		joints.UpperTorso = angLim(-8 * g - holdBreath * 1.4, twist * 24 * g, -shoulderRoll * 0.14 * g + holdBreath * 1.6, LIM.Torso)
		joints.Head = angLim(-10 * g, -twist * 12 * g, holdBreath * 0.9, LIM.Head)
		joints.RightUpperArm = angLim(
			lerpNumber(-25, guardArmPitch, g) + holdBreath * 2.2,
			lerpNumber(-15, -52, g),
			lerpNumber(20, 34 + shoulderRoll * 0.22, g),
			LIM.UpperArm
		)
		joints.RightLowerArm = angLim(lerpNumber(-35, -70, g), lerpNumber(10, 24, g), 10 * g, LIM.LowerArm)
		joints.RightHand = angLim(12 * g, 0, lerpNumber(8, -18, g), LIM.Hand)
		joints.HiltGrip = angLim(lerpNumber(0, -26, g), lerpNumber(0, 22, g), lerpNumber(0, -12, g), LIM.Hilt)
		joints.LeftUpperArm = angLim(lerpNumber(-15, -42, g), lerpNumber(20, 48, g), -off * 38 * g, LIM.UpperArm)
		joints.LeftLowerArm = angLim(lerpNumber(-40, -55, g), 0, 0, LIM.LowerArm)
		joints.LeftHand = angLim(4 * g, 0, -6 * g, LIM.Hand)
		joints.RightUpperLeg = angLim(4 * g, 5 * g, 3 * g, LIM.Leg)
		joints.RightLowerLeg = angLim(6 * g, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(3 * g, -7 * g, -4 * g, LIM.Leg)
		joints.LeftLowerLeg = angLim(8 * g, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Antici" then
		-- Chambre : ease-in (charge) — poids arrière
		local e = easeInCubic(a)
		local chamberPitch = clampDeg(-48 - ant * 28 * plane, -78, -20)
		local chamberYaw = clampDeg(-32 - ant * 26 * (1 - plane), -68, -10)
		joints.LowerTorso = angLim(-4.5 * ant * e, -twist * 26 * ant * e, hipShift * 6 * e, LIM.Torso)
			* CFrame.new(hipShift * 0.04 * e, 0.022 * e, 0.032 * e)
		joints.UpperTorso = angLim(-7.5 * ant * e, -twist * 34 * ant * e, 5 * ant * e + shoulderRoll * 0.18 * e, LIM.Torso)
		joints.Head = angLim(6 * ant * e, twist * 14 * ant * e, 0, LIM.Head)
		joints.RightUpperArm = angLim(
			chamberPitch * e + (-25) * (1 - e),
			chamberYaw * e + (-15) * (1 - e),
			22 + ant * 14 * e + shoulderRoll * 0.32 * e,
			LIM.UpperArm
		)
		joints.RightLowerArm = angLim(-18 - ant * 24 * e, 12, 6 * e, LIM.LowerArm)
		joints.RightHand = angLim(-10 * e, -14 * e, 8 + shoulderRoll * 0.18 * e, LIM.Hand)
		joints.HiltGrip = angLim(-36 * ant * e, -28 * ant * e, 14 * ant * e, LIM.Hilt)
		joints.LeftUpperArm = angLim(-24 - off * 6 * e, 30 + off * 18 * e, -off * 28 - off * 8 * e, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-44, -4 * e, 0, LIM.LowerArm)
		joints.LeftHand = angLim(-4 * e, 0, -6 * e, LIM.Hand)
		local legMul = if heavy then 1.15 else 0.7
		joints.RightUpperLeg = angLim(-6 * e * legMul, 5 * e, 4 * e, LIM.Leg)
		joints.RightLowerLeg = angLim(8 * e * legMul, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(9 * e * legMul, -4 * e, -6 * e, LIM.Leg)
		joints.LeftLowerLeg = angLim(4 * e, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "WeightShift" then
		-- Commit hanches avant le tranchant — pont Antici → Contact
		local e = easeInOutCubic(a)
		local antPose = sampleJoints(style, "Antici", 1, heavy)
		local earlyContact = sampleJoints(style, "Contact", 0.18, heavy)
		return lerpJoints(antPose, earlyContact, e)
	elseif phaseKind == "Contact" then
		-- Coupe : ease-out rapide vers l'impact (lisible à distance)
		local pMul = easeOutCubic(a)
		local swingPitch = clampDeg(pitch * arc * 0.35 + 24 * arc * pMul, -78, 52)
		local swingYaw = clampDeg(yaw * arc * 0.3 + 76 * arc * (1 - plane) * pMul * 0.48, -70, 65)
		local swingRoll = clampDeg(roll * arc * 0.25 + shoulderRoll * 0.5 * pMul - 14, -40, 38)
		joints.LowerTorso = angLim(6.5 * math.min(arc, 1.25) * pMul, twist * 38 * pMul, -hipShift * 7 * pMul, LIM.Torso)
			* CFrame.new(-hipShift * 0.048 * pMul, -0.022 * pMul, -0.042 * pMul)
		joints.UpperTorso = angLim(4.5 * math.min(arc, 1.25) * pMul, twist * 46 * pMul, -7 * pMul + shoulderRoll * 0.22 * pMul, LIM.Torso)
		-- Tête suit la lame (yaw / pitch opposés au twist)
		joints.Head = angLim(-6 - 2 * pMul, -twist * 18 * pMul, shoulderRoll * 0.08 * pMul, LIM.Head)
		joints.RightUpperArm = angLim(swingPitch, swingYaw, swingRoll, LIM.UpperArm)
		joints.RightLowerArm = angLim(-10 + 38 * pMul, -18, -6 * pMul, LIM.LowerArm)
		joints.RightHand = angLim(14 * pMul, 22 * pMul, -18 + shoulderRoll * 0.25 * pMul, LIM.Hand)
		joints.HiltGrip = angLim(28 * math.min(arc, 1.28) * pMul, 50 * math.min(arc, 1.28) * pMul * (1 - plane * 0.5), -14, LIM.Hilt)
		-- Contrebalancement bras gauche lisible
		joints.LeftUpperArm = angLim(-30 - off * 18 * pMul, 38 + 6 * pMul, -off * 42 * pMul, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-50, 10, 4 * pMul, LIM.LowerArm)
		joints.LeftHand = angLim(6 * pMul, 0, -8 * pMul, LIM.Hand)
		local legMul = if heavy then 1.2 else 0.75
		joints.RightUpperLeg = angLim(11 * pMul * legMul, -6 * pMul, 5 * pMul, LIM.Leg)
		joints.RightLowerLeg = angLim(14 * pMul * legMul, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(-4 * pMul * legMul, 7 * pMul, -4 * pMul, LIM.Leg)
		joints.LeftLowerLeg = angLim(6 * pMul, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Follow" then
		-- Follow-through + settle (easeOutBack sur le début pour overshoot tip)
		local f = s.followThrough
		local overshoot = math.clamp(easeOutBack(math.min(a * 1.35, 1)) - 1, 0, 0.18) -- pic tip ~0..0.18
		local settle = easeInOutCubic(a)
		local live = 1 - settle
		joints.LowerTorso = angLim(3 * f * live, twist * 22 * f * live, hipShift * 3 * live, LIM.Torso)
			* CFrame.new(0, 0, -0.02 * f * live)
		joints.UpperTorso = angLim(2.5 * live + overshoot * 4, twist * 18 * live, -4 * live + shoulderRoll * 0.1 * live, LIM.Torso)
		joints.Head = angLim(-3.5 * live, -twist * 6 * live, 0, LIM.Head)
		joints.RightUpperArm = angLim(
			14 * f * live + overshoot * 10 - 10 * settle,
			34 * f * live + overshoot * 8 + 6 * settle,
			-10 + shoulderRoll * 0.14 * live,
			LIM.UpperArm
		)
		joints.RightLowerArm = angLim(-22 - overshoot * 6, 6, 0, LIM.LowerArm)
		joints.RightHand = angLim(6 + overshoot * 4, 10, 0, LIM.Hand)
		joints.HiltGrip = angLim(8 * f * live + overshoot * 12, 18 * f * live + overshoot * 10, -overshoot * 6, LIM.Hilt)
		joints.LeftUpperArm = angLim(-18 + 4 * settle, 24 - 4 * settle, -off * 20 * live, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-38, 0, 0, LIM.LowerArm)
		joints.LeftHand = angLim(0, 0, -4, LIM.Hand)
		joints.RightUpperLeg = angLim(5 * live * (if heavy then 1.1 else 0.6), -2 * live, 2 * live, LIM.Leg)
		joints.RightLowerLeg = angLim(6 * live, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(2 * live, 3 * live, -2 * live, LIM.Leg)
		joints.LeftLowerLeg = angLim(3 * live, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Dodge" then
		-- Esquive latérale : lean + jambes croisées, lame haute
		local d = easeOutCubic(a)
		local side = math.sign(lean + 0.001)
		joints.LowerTorso = angLim(-9 * d, lean * 58 * d, lean * 30 * d, LIM.Torso) * CFrame.new(lean * 0.08 * d, 0.022 * d, 0)
		joints.UpperTorso = angLim(-10 * d, lean * 46 * d, lean * 24 * d, LIM.Torso)
		joints.Head = angLim(5 * d, -lean * 32 * d, -lean * 6 * d, LIM.Head)
		joints.RightUpperArm = angLim(-48, 55, -34 + shoulderRoll * 0.18, LIM.UpperArm)
		joints.RightLowerArm = angLim(-40, 0, 0, LIM.LowerArm)
		joints.RightHand = angLim(-6, 8, -10, LIM.Hand)
		joints.HiltGrip = angLim(-20, 36, -22, LIM.Hilt)
		joints.LeftUpperArm = angLim(-38, -28, 18, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-34, 0, 0, LIM.LowerArm)
		joints.LeftHand = angLim(0, 0, 6, LIM.Hand)
		joints.RightUpperLeg = angLim(-12 * d * side, lean * 20 * d, lean * 16 * d, LIM.Leg)
		joints.RightLowerLeg = angLim(18 * d, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(9 * d, -lean * 18 * d, -lean * 14 * d, LIM.Leg)
		joints.LeftLowerLeg = angLim(10 * d, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Dash" then
		-- Fente avant : torse penché, jambe avant pliée
		local d = easeOutCubic(a)
		joints.LowerTorso = angLim(9 * d, 0, 0, LIM.Torso) * CFrame.new(0, -0.024 * d, -0.06 * d)
		joints.UpperTorso = angLim(12 * d, 0, 0, LIM.Torso)
		joints.Head = angLim(-10 * d, 0, 0, LIM.Head)
		joints.RightUpperArm = angLim(10, -24, 10, LIM.UpperArm)
		joints.RightLowerArm = angLim(-30, 0, 0, LIM.LowerArm)
		joints.RightHand = angLim(4, -6, 0, LIM.Hand)
		joints.HiltGrip = angLim(6, -14, 0, LIM.Hilt)
		joints.LeftUpperArm = angLim(6, 20, -10, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-24, 0, 0, LIM.LowerArm)
		joints.LeftHand = angLim(0, 0, -4, LIM.Hand)
		joints.RightUpperLeg = angLim(16 * d, -4 * d, 3 * d, LIM.Leg)
		joints.RightLowerLeg = angLim(22 * d, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(-10 * d, 4 * d, -3 * d, LIM.Leg)
		joints.LeftLowerLeg = angLim(8 * d, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Focus" then
		-- Estoc Focus : lame avant, corps compact (≠ Dash)
		local d = easeInOutCubic(a)
		joints.LowerTorso = angLim(6 * d, 0, 0, LIM.Torso) * CFrame.new(0, 0.008 * d, -0.05 * d)
		joints.UpperTorso = angLim(10 * d, 0, 0, LIM.Torso)
		joints.Head = angLim(-12 * d, 0, 0, LIM.Head)
		joints.RightUpperArm = angLim(-22, -4, shoulderRoll * 0.1, LIM.UpperArm)
		joints.RightLowerArm = angLim(-8 + 20 * d, 0, 0, LIM.LowerArm)
		joints.RightHand = angLim(0, 0, 0, LIM.Hand)
		joints.HiltGrip = angLim(0, 0, 0, LIM.Hilt) * CFrame.new(0, 0, -0.16 * d)
		joints.LeftUpperArm = angLim(-26, 40, -off * 44, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-30, 0, 0, LIM.LowerArm)
		joints.LeftHand = angLim(0, 0, -8, LIM.Hand)
		joints.RightUpperLeg = angLim(7 * d, 0, 0, LIM.Leg)
		joints.RightLowerLeg = angLim(10 * d, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(-4 * d, 0, 0, LIM.Leg)
		joints.LeftLowerLeg = angLim(4 * d, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Stagger" then
		local d = easeOutCubic(a)
		joints.LowerTorso = angLim(-12 * d, -22 * d, 14 * d, LIM.Torso)
		joints.UpperTorso = angLim(-14 * d, -26 * d, 18 * d, LIM.Torso)
		joints.Head = angLim(20 * d, 14 * d, 10 * d, LIM.Head)
		joints.RightUpperArm = angLim(38 * d, -38 * d, 30 * d, LIM.UpperArm)
		joints.RightLowerArm = angLim(-20, 0, 0, LIM.LowerArm)
		joints.RightHand = angLim(8 * d, -6 * d, 8 * d, LIM.Hand)
		joints.HiltGrip = angLim(26 * d, -18 * d, 22 * d, LIM.Hilt)
		joints.LeftUpperArm = angLim(18 * d, 28 * d, -18 * d, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-16, 0, 0, LIM.LowerArm)
		joints.LeftHand = angLim(0, 0, 0, LIM.Hand)
		joints.RightUpperLeg = angLim(-9 * d, 9 * d, 6 * d, LIM.Leg)
		joints.RightLowerLeg = angLim(12 * d, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(6 * d, -8 * d, -5 * d, LIM.Leg)
		joints.LeftLowerLeg = angLim(8 * d, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Dead" then
		local d = easeInOutCubic(a)
		joints.LowerTorso = angLim(-20 * d, 10 * d, 18 * d, LIM.Torso)
		joints.UpperTorso = angLim(-22 * d, 14 * d, 20 * d, LIM.Torso)
		joints.Head = angLim(30 * d, 0, 14 * d, LIM.Head)
		joints.RightUpperArm = angLim(54 * d, -18 * d, 34 * d, LIM.UpperArm)
		joints.RightLowerArm = angLim(-12, 0, 0, LIM.LowerArm)
		joints.RightHand = angLim(10 * d, 0, 8 * d, LIM.Hand)
		joints.HiltGrip = angLim(42 * d, 0, 26 * d, LIM.Hilt)
		joints.LeftUpperArm = angLim(34 * d, 22 * d, -14 * d, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-6, 0, 0, LIM.LowerArm)
		joints.LeftHand = angLim(0, 0, 0, LIM.Hand)
		joints.RightUpperLeg = angLim(-14 * d, 7 * d, 9 * d, LIM.Leg)
		joints.RightLowerLeg = angLim(20 * d, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(-10 * d, -6 * d, -7 * d, LIM.Leg)
		joints.LeftLowerLeg = angLim(16 * d, 0, 0, LIM.LowerLeg)
	elseif phaseKind == "Feint" then
		if a < 0.38 then
			return sampleJoints(style, "Antici", easeInCubic(a / 0.38), false)
		elseif a < 0.48 then
			return sampleJoints(style, "Antici", 1, false)
		elseif a < 0.62 then
			local antPose = sampleJoints(style, "Antici", 1, false)
			local mid = sampleJoints(style, "Guard", 0.35, false)
			return lerpJoints(antPose, mid, easeOutCubic((a - 0.48) / 0.14))
		end
		return sampleJoints(style, "Guard", easeOutCubic((a - 0.62) / 0.38), false)
	elseif phaseKind == "Riposte" then
		local e = easeOutCubic(a)
		joints.LowerTorso = angLim(6 * e, 0, 0, LIM.Torso) * CFrame.new(0, 0, -0.04 * e)
		joints.UpperTorso = angLim(9 * e, 0, 0, LIM.Torso)
		joints.Head = angLim(-8 * e, 0, 0, LIM.Head)
		joints.RightUpperArm = angLim(-16 + 6 * e, -6, 5 + shoulderRoll * 0.1, LIM.UpperArm)
		joints.RightLowerArm = angLim(-4 + 40 * e, 0, 0, LIM.LowerArm)
		joints.RightHand = angLim(0, 0, 0, LIM.Hand)
		joints.HiltGrip = CFrame.new(0, 0, -0.22 * e)
		joints.LeftUpperArm = angLim(-20, 24, -14, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-34, 0, 0, LIM.LowerArm)
		joints.LeftHand = angLim(0, 0, -4, LIM.Hand)
		joints.RightUpperLeg = angLim(9 * e, 0, 0, LIM.Leg)
		joints.RightLowerLeg = angLim(12 * e, 0, 0, LIM.LowerLeg)
		joints.LeftUpperLeg = angLim(-4 * e, 0, 0, LIM.Leg)
		joints.LeftLowerLeg = angLim(4 * e, 0, 0, LIM.LowerLeg)
	else
		joints.RightUpperArm = CFrame.new()
	end

	return joints
end

local function emptySequence(name: string, priority: Enum.AnimationPriority, loop: boolean): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Loop = loop
	seq.Priority = priority
	return seq
end

function KeyframeFactory.buildClip(
	setDef: AnimationSets.AnimationSetDef,
	clipName: AnimationSets.ClipName
): KeyframeSequence
	local style = setDef.style
	local tempo = math.max(0.5, style.tempo)
	local priority = style.priority
	local seqName = setDef.id .. "_" .. clipName
	local heavy = string.find(clipName, "Heavy") ~= nil

	if clipName == "Idle" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Idle, true)
		local dur = 1.75 / tempo
		for i = 0, 13 do
			local u = i / 14
			local name: string? = nil
			if i == 0 then
				name = "Idle0"
			elseif i == 3 then
				name = "IdleInhale"
			elseif i == 7 then
				name = "IdleMid"
			elseif i == 10 then
				name = "IdleExhale"
			end
			addKeyframe(seq, dur * u, sampleJoints(style, "Idle", u, false), name)
		end
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 1, false), "IdleEnd")
		return seq
	end

	if clipName == "Guard" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action, true)
		local dur = 1.1 / tempo
		local function guardBreath(phase: number): JointMap
			local wave = math.sin(phase * math.pi * 2)
			local alpha = 0.88 + 0.12 * easeInOutCubic((wave + 1) * 0.5)
			return sampleJoints(style, "Guard", alpha, false)
		end
		addKeyframe(seq, 0, guardBreath(0), "GuardHoldA")
		addKeyframe(seq, dur * 0.1, guardBreath(0.1), "GuardMicro1")
		addKeyframe(seq, dur * 0.22, guardBreath(0.22), "GuardBreathIn")
		addKeyframe(seq, dur * 0.35, guardBreath(0.35), "GuardMicro2")
		addKeyframe(seq, dur * 0.5, guardBreath(0.5), "GuardSettle")
		addKeyframe(seq, dur * 0.62, guardBreath(0.62), "GuardMicro3")
		addKeyframe(seq, dur * 0.75, guardBreath(0.75), "GuardBreathOut")
		addKeyframe(seq, dur * 0.88, guardBreath(0.88), "GuardMicro4")
		addKeyframe(seq, dur, guardBreath(1), "GuardHoldB")
		return seq
	end

	if clipName == "Dodge" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Movement, false)
		local dur = 0.3 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false), "DodgeFrom")
		addKeyframe(seq, dur * 0.12, sampleJoints(style, "Dodge", 0.2, false), "DodgeWind")
		addKeyframe(seq, dur * 0.32, sampleJoints(style, "Dodge", 0.7, false), "DodgeCommit")
		addKeyframe(seq, dur * 0.5, sampleJoints(style, "Dodge", 1.0, false), "DodgePeak")
		addKeyframe(seq, dur * 0.7, sampleJoints(style, "Dodge", 0.55, false), "DodgeFall")
		addKeyframe(seq, dur * 0.88, sampleJoints(style, "Idle", 0.25, false), "DodgeRecover")
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 0.15, false), "DodgeOut")
		return seq
	end

	if clipName == "Dash" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Movement, false)
		local dur = 0.24 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false), "DashFrom")
		addKeyframe(seq, dur * 0.14, sampleJoints(style, "Dash", 0.3, false), "DashCoil")
		addKeyframe(seq, dur * 0.35, sampleJoints(style, "Dash", 0.85, false), "DashPush")
		addKeyframe(seq, dur * 0.52, sampleJoints(style, "Dash", 1, false), "DashPeak")
		addKeyframe(seq, dur * 0.72, sampleJoints(style, "Dash", 0.45, false), "DashCoast")
		addKeyframe(seq, dur * 0.9, sampleJoints(style, "Idle", 0.15, false), "DashSettle")
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 0.08, false), "DashOut")
		return seq
	end

	if clipName == "FocusPush" or clipName == "FocusDash" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action2, false)
		local dur = (if clipName == "FocusPush" then 0.36 else 0.28) / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Antici", 0.35, false), "FocusWind")
		addKeyframe(seq, dur * 0.18, sampleJoints(style, "Antici", 0.7, false), "FocusChamber")
		addKeyframe(seq, dur * 0.36, sampleJoints(style, "Focus", 0.45, false), "FocusCommit")
		addKeyframe(seq, dur * 0.52, sampleJoints(style, "Focus", 1, false), "FocusPeak")
		addKeyframe(seq, dur * 0.7, sampleJoints(style, "Follow", 0.25, false), "FocusThrough")
		addKeyframe(seq, dur * 0.88, sampleJoints(style, "Follow", 0.5, false), "FocusSettle")
		addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.65, false), "FocusOut")
		return seq
	end

	if clipName == "Stagger" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action4, false)
		local dur = 0.48 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false))
		addKeyframe(seq, dur * 0.12, sampleJoints(style, "Stagger", 0.35, false))
		addKeyframe(seq, dur * 0.32, sampleJoints(style, "Stagger", 1, false), "StaggerHit")
		addKeyframe(seq, dur * 0.55, sampleJoints(style, "Stagger", 0.9, false))
		addKeyframe(seq, dur * 0.78, sampleJoints(style, "Stagger", 0.75, false))
		addKeyframe(seq, dur, sampleJoints(style, "Stagger", 0.65, false))
		return seq
	end

	if clipName == "Dead" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action4, false)
		local dur = 0.72 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Stagger", 0.5, false))
		addKeyframe(seq, dur * 0.2, sampleJoints(style, "Dead", 0.3, false))
		addKeyframe(seq, dur * 0.45, sampleJoints(style, "Dead", 0.7, false))
		addKeyframe(seq, dur * 0.7, sampleJoints(style, "Dead", 0.92, false), "KO")
		addKeyframe(seq, dur, sampleJoints(style, "Dead", 1, false))
		return seq
	end

	if clipName == "Feint" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action2, false)
		local dur = math.max(0.22, CombatConfig.Light.Startup * 0.95) / math.max(0.85, math.min(tempo, 1.35))
		addKeyframe(seq, 0, sampleJoints(style, "Feint", 0, false), "FeintStart")
		addKeyframe(seq, dur * 0.12, sampleJoints(style, "Feint", 0.18, false), "FeintWind")
		addKeyframe(seq, dur * 0.26, sampleJoints(style, "Feint", 0.32, false), "FeintChamber")
		addKeyframe(seq, dur * 0.4, sampleJoints(style, "Feint", 0.42, false), "FeintFake")
		addKeyframe(seq, dur * 0.5, sampleJoints(style, "Feint", 0.5, false), "FeintAbort")
		addKeyframe(seq, dur * 0.62, sampleJoints(style, "Feint", 0.65, false), "FeintSnap")
		addKeyframe(seq, dur * 0.8, sampleJoints(style, "Feint", 0.85, false), "FeintSettle")
		addKeyframe(seq, dur, sampleJoints(style, "Feint", 1, false), "FeintGuard")
		return seq
	end

	if clipName == "Riposte" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action3, false)
		local dur = 0.32 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Guard", 0.55, false), "RiposteFrom")
		addKeyframe(seq, dur * 0.14, sampleJoints(style, "Riposte", 0.15, false), "RiposteWind")
		addKeyframe(seq, dur * 0.32, sampleJoints(style, "Riposte", 0.5, false))
		addKeyframe(seq, dur * 0.5, sampleJoints(style, "Riposte", 1, false), "RiposteHit")
		addKeyframe(seq, dur * 0.7, sampleJoints(style, "Follow", 0.3, false))
		addKeyframe(seq, dur * 0.88, sampleJoints(style, "Follow", 0.5, false))
		addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.6, false), "RiposteOut")
		return seq
	end

	local isStartup = string.sub(clipName, 1, 7) == "Startup"
	local isActive = string.sub(clipName, 1, 6) == "Active"
	local isRecovery = string.sub(clipName, 1, 8) == "Recovery"

	if isStartup then
		local seq = emptySequence(seqName, priority, false)
		local dur = attackPhaseDuration(clipName)
		local idle0 = sampleJoints(style, "Idle", 0, heavy)
		local ant02 = sampleJoints(style, "Antici", 0.2, heavy)
		local ant04 = sampleJoints(style, "Antici", 0.4, heavy)
		local ant06 = sampleJoints(style, "Antici", 0.6, heavy)
		local ant08 = sampleJoints(style, "Antici", 0.8, heavy)
		local ant095 = sampleJoints(style, "Antici", 0.95, heavy)
		local ant1 = sampleJoints(style, "Antici", 1.0, heavy)
		local wshift = sampleJoints(style, "WeightShift", 0.35, heavy)
		addKeyframe(seq, 0, idle0, "StartFromIdle")
		addKeyframe(seq, dur * 0.1, lerpJoints(idle0, ant02, easeInOutCubic(0.6)), "StartBlend")
		addKeyframe(seq, dur * 0.22, ant02, "AnticiEarly")
		addKeyframe(seq, dur * 0.38, ant04, "AnticiMid")
		addKeyframe(seq, dur * 0.55, ant06, "AnticiLoad")
		addKeyframe(seq, dur * 0.7, ant08, "AnticiPeak")
		addKeyframe(seq, dur * 0.82, ant095, "AnticiHold")
		addKeyframe(seq, dur * 0.92, wshift, "WeightPrep")
		addKeyframe(seq, dur, ant1, "AnticiReady")
		return seq
	end

	if isActive then
		local seq = emptySequence(seqName, priority, false)
		local dur = attackPhaseDuration(clipName)
		-- ≥11 KF : release → weight → arc → impact → overshoot → settle
		addKeyframe(seq, 0, sampleJoints(style, "Antici", 1.0, heavy), "SwingRelease")
		if style.doubleBeat then
			addKeyframe(seq, dur * 0.08, sampleJoints(style, "WeightShift", 0.6, heavy), "WeightCommit")
			addKeyframe(seq, dur * 0.16, sampleJoints(style, "Contact", 0.3, heavy), "Beat1In")
			addKeyframe(seq, dur * 0.26, sampleJoints(style, "Contact", 0.85, heavy), "Beat1")
			addKeyframe(seq, dur * 0.34, sampleJoints(style, "Contact", 0.95, heavy), "Beat1Tip")
			addKeyframe(seq, dur * 0.42, sampleJoints(style, "Contact", 0.4, heavy), "Valley")
			addKeyframe(seq, dur * 0.52, sampleJoints(style, "Contact", 0.55, heavy), "Beat2In")
			addKeyframe(seq, dur * 0.64, sampleJoints(style, "Contact", 1.0, heavy), "Beat2")
			addKeyframe(seq, dur * 0.74, sampleJoints(style, "Follow", 0.12, heavy), "Overshoot")
			addKeyframe(seq, dur * 0.86, sampleJoints(style, "Follow", 0.35, heavy), "Through")
			addKeyframe(seq, dur * 0.94, sampleJoints(style, "Follow", 0.55, heavy), "SettleIn")
			addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.65, heavy), "ActiveEnd")
		else
			addKeyframe(seq, dur * 0.07, sampleJoints(style, "WeightShift", 0.55, heavy), "WeightCommit")
			addKeyframe(seq, dur * 0.14, sampleJoints(style, "Contact", 0.15, heavy), "ArcStart")
			addKeyframe(seq, dur * 0.24, sampleJoints(style, "Contact", 0.38, heavy), "ArcMid")
			addKeyframe(seq, dur * 0.36, sampleJoints(style, "Contact", 0.62, heavy), "ArcTip")
			addKeyframe(seq, dur * 0.46, sampleJoints(style, "Contact", 0.82, heavy), "PreImpact")
			addKeyframe(seq, dur * 0.55, sampleJoints(style, "Contact", 1.0, heavy), "Impact")
			addKeyframe(seq, dur * 0.64, sampleJoints(style, "Follow", 0.08, heavy), "Overshoot")
			addKeyframe(seq, dur * 0.76, sampleJoints(style, "Follow", 0.28, heavy), "Through")
			addKeyframe(seq, dur * 0.88, sampleJoints(style, "Follow", 0.5, heavy), "SettleIn")
			addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.62, heavy), "ActiveEnd")
		end
		return seq
	end

	if isRecovery then
		local seq = emptySequence(seqName, priority, false)
		local dur = attackPhaseDuration(clipName)
		local follow0 = sampleJoints(style, "Follow", 0.6, heavy)
		local followMid = sampleJoints(style, "Follow", 0.82, heavy)
		local idleBlend = sampleJoints(style, "Idle", 0.4, heavy)
		local idle0 = sampleJoints(style, "Idle", 0, heavy)
		addKeyframe(seq, 0, follow0, "RecStart")
		addKeyframe(seq, dur * 0.14, followMid, "RecCoast")
		addKeyframe(seq, dur * 0.32, lerpJoints(followMid, idleBlend, easeInOutCubic(0.35)), "RecEase")
		addKeyframe(seq, dur * 0.5, idleBlend, "RecSettle")
		addKeyframe(seq, dur * 0.7, lerpJoints(idleBlend, idle0, easeOutCubic(0.5)), "RecSoft")
		addKeyframe(seq, dur * 0.88, lerpJoints(idleBlend, idle0, easeOutCubic(0.85)), "RecAlmost")
		addKeyframe(seq, dur, idle0, "RecIdle")
		return seq
	end

	local seq = emptySequence(seqName, Enum.AnimationPriority.Idle, true)
	addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false))
	addKeyframe(seq, 0.5, sampleJoints(style, "Idle", 0.5, false))
	return seq
end

--[[
	Sample pour ProceduralPlayer — même timeline densifiée que buildClip.
]]
function KeyframeFactory.samplePose(
	setDef: AnimationSets.AnimationSetDef,
	clipName: AnimationSets.ClipName,
	normalizedTime: number
): JointMap
	local n = math.clamp(normalizedTime, 0, 1)
	local heavy = string.find(clipName, "Heavy") ~= nil
	local style = setDef.style

	if clipName == "Idle" then
		return sampleJoints(style, "Idle", n, false)
	elseif clipName == "Guard" then
		local wave = math.sin(n * math.pi * 2)
		local alpha = 0.88 + 0.12 * easeInOutCubic((wave + 1) * 0.5)
		return sampleJoints(style, "Guard", alpha, false)
	elseif clipName == "Dodge" then
		if n < 0.5 then
			return sampleJoints(style, "Dodge", easeOutCubic(n / 0.5), false)
		end
		local idle = sampleJoints(style, "Idle", 0.15, false)
		local dodge = sampleJoints(style, "Dodge", 1, false)
		return lerpJoints(dodge, idle, easeInOutCubic((n - 0.5) / 0.5))
	elseif clipName == "Dash" then
		if n < 0.52 then
			return sampleJoints(style, "Dash", easeOutCubic(n / 0.52), false)
		end
		local idle = sampleJoints(style, "Idle", 0.08, false)
		local dash = sampleJoints(style, "Dash", 1, false)
		return lerpJoints(dash, idle, easeInOutCubic((n - 0.52) / 0.48))
	elseif clipName == "FocusPush" or clipName == "FocusDash" then
		if n < 0.2 then
			return sampleJoints(style, "Antici", easeInCubic(n / 0.2) * 0.7, false)
		elseif n < 0.55 then
			return sampleJoints(style, "Focus", easeOutCubic((n - 0.2) / 0.35), false)
		end
		return sampleJoints(style, "Follow", 0.25 + easeInOutCubic((n - 0.55) / 0.45) * 0.4, false)
	elseif clipName == "Stagger" then
		return sampleJoints(style, "Stagger", math.min(1, easeOutCubic(n) * 1.05), false)
	elseif clipName == "Dead" then
		return sampleJoints(style, "Dead", easeInOutCubic(n), false)
	elseif clipName == "Feint" then
		return sampleJoints(style, "Feint", n, false)
	elseif clipName == "Riposte" then
		if n < 0.14 then
			return sampleJoints(style, "Guard", 0.55, false)
		elseif n < 0.5 then
			return sampleJoints(style, "Riposte", easeOutCubic((n - 0.14) / 0.36), false)
		end
		return sampleJoints(style, "Follow", 0.3 + easeInOutCubic((n - 0.5) / 0.5) * 0.3, false)
	elseif string.sub(clipName, 1, 7) == "Startup" then
		if n < 0.12 then
			local idle = sampleJoints(style, "Idle", 0, heavy)
			local ant = sampleJoints(style, "Antici", 0.2, heavy)
			return lerpJoints(idle, ant, easeInOutCubic(n / 0.12))
		elseif n < 0.9 then
			return sampleJoints(style, "Antici", easeInCubic((n - 0.12) / 0.78), heavy)
		end
		local ant = sampleJoints(style, "Antici", 1, heavy)
		local ws = sampleJoints(style, "WeightShift", 0.4, heavy)
		return lerpJoints(ant, ws, easeInOutCubic((n - 0.9) / 0.1))
	elseif string.sub(clipName, 1, 6) == "Active" then
		if style.doubleBeat then
			if n < 0.08 then
				return sampleJoints(style, "WeightShift", easeInOutCubic(n / 0.08) * 0.6, heavy)
			elseif n < 0.28 then
				return sampleJoints(style, "Contact", easeOutCubic((n - 0.08) / 0.2) * 0.9, heavy)
			elseif n < 0.42 then
				local hi = sampleJoints(style, "Contact", 0.95, heavy)
				local lo = sampleJoints(style, "Contact", 0.4, heavy)
				return lerpJoints(hi, lo, easeInOutCubic((n - 0.28) / 0.14))
			elseif n < 0.68 then
				return sampleJoints(style, "Contact", 0.4 + easeOutCubic((n - 0.42) / 0.26) * 0.6, heavy)
			end
			return sampleJoints(style, "Follow", easeInOutCubic((n - 0.68) / 0.32) * 0.65, heavy)
		end
		-- Simple coupe : weight → contact → overshoot follow
		if n < 0.1 then
			return sampleJoints(style, "WeightShift", easeInOutCubic(n / 0.1), heavy)
		elseif n < 0.55 then
			return sampleJoints(style, "Contact", easeOutCubic((n - 0.1) / 0.45), heavy)
		end
		return sampleJoints(style, "Follow", easeInOutCubic((n - 0.55) / 0.45) * 0.62, heavy)
	elseif string.sub(clipName, 1, 8) == "Recovery" then
		if n < 0.4 then
			return sampleJoints(style, "Follow", 0.6 + easeOutCubic(n / 0.4) * 0.25, heavy)
		end
		local follow = sampleJoints(style, "Follow", 0.85, heavy)
		local idle = sampleJoints(style, "Idle", 0, heavy)
		return lerpJoints(follow, idle, easeInOutCubic((n - 0.4) / 0.6))
	end
	return sampleJoints(style, "Idle", 0, false)
end

return KeyframeFactory
