--!strict
--[[
	Construit des KeyframeSequence R15 (+ HiltGrip + jambes) à partir des StyleParams.
	Pass fluidité : densification Active/Startup/Recovery, ease curves, shoulder roll,
	weight shift LowerTorso, ancrage RightUpperLeg/LeftUpperLeg (Dodge/Dash/Heavy).
	Pass continue : Idle breathing, Guard enter/exit densifiés, Feint 8 KF,
	Track Length = CombatConfig Light/Heavy (frame data).
	Pass quality : amplitudes R15 réalistes (clamp angles), smoothstep partout,
	pas d'hyper-extension bras / poignet.
	Sources : docs Pose / KeyframeSequence / KeyframeSequenceProvider.
]]

local Shared = script.Parent.Parent:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local AnimationSets = require(script.Parent:WaitForChild("AnimationSets"))

export type JointMap = { [string]: CFrame }

local KeyframeFactory = {}

-- Limites Euler relatives (°) — R15 combat sabre, évite bras cassés / hyper-extension
local LIM = {
	UpperArm = { p = { -82, 55 }, y = { -72, 68 }, r = { -42, 42 } },
	LowerArm = { p = { -82, 8 }, y = { -28, 28 }, r = { -18, 18 } },
	Hand = { p = { -35, 35 }, y = { -35, 35 }, r = { -30, 30 } },
	Hilt = { p = { -48, 48 }, y = { -55, 55 }, r = { -35, 35 } },
	Torso = { p = { -22, 22 }, y = { -32, 32 }, r = { -22, 22 } },
	Head = { p = { -28, 32 }, y = { -28, 28 }, r = { -18, 18 } },
	Leg = { p = { -22, 22 }, y = { -18, 18 }, r = { -16, 16 } },
}

-- Durées attaque = frame data serveur (tempo n'étire plus Startup/Active/Recovery)
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

-- Smoothstep Hermite (canonical) — Pass quality : partout pour les alphas de phase
local function smoothstep(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Alias historiques → smoothstep (évite cuts linéaires, courbe unique)
local function easeInOut(t: number): number
	return smoothstep(t)
end

local function easeOutCubic(t: number): number
	return smoothstep(t)
end

local function easeInCubic(t: number): number
	return smoothstep(t)
end

local function easeOutQuad(t: number): number
	return smoothstep(t)
end

--[[
	Clamp StyleParams avant sample — garde la distinction visuelle sans hyper-extension.
	swingArc/anticipation plafonnés ; heavyMul reste soft (1.12).
]]
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
	Pose hierarchy R15 + HiltGrip + UpperLegs (Motor6D SaberMotor RightHand→HiltGrip).
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

	-- Ancrage corporel R15 (Dodge / Dash / Heavy)
	local rul = Instance.new("Pose")
	rul.Name = "RightUpperLeg"
	rul.Weight = 1
	rul.CFrame = joints.RightUpperLeg or CFrame.new()
	lower:AddSubPose(rul)

	local lul = Instance.new("Pose")
	lul.Name = "LeftUpperLeg"
	lul.Weight = 1
	lul.CFrame = joints.LeftUpperLeg or CFrame.new()
	lower:AddSubPose(lul)

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
	Calcule les Transforms joints pour une phase normalisée.
	phaseKind : Idle | Guard | Antici | Contact | Follow | Dodge | Dash | Focus | Stagger | Dead | Feint | Riposte
]]
local function sampleJoints(
	style: AnimationSets.StyleParams,
	phaseKind: string,
	alpha: number,
	heavy: boolean
): JointMap
	local s = sanitizeStyle(style)
	local a = math.clamp(alpha, 0, 1)
	-- Heavy soft : +12 % max (évite bras cassés sur swingArc déjà haut)
	local heavyMul = if heavy then 1.12 else 1.0
	local ant = math.min(s.anticipation * heavyMul, 1.08)
	local arc = math.min(s.swingArc * heavyMul, 1.45)
	local plane = s.planeBias -- 0 horiz, 1 vert
	local twist = s.torsoTwist
	local off = s.offhand
	local lean = s.idleLean
	-- Shoulder roll + weight-shift hips (Pass fluidité) — roll plafonné
	local shoulderRoll = clampDeg(lerpNumber(14, -18, plane) * arc, -28, 28)
	local hipShift = (if heavy then 1.05 else 0.8) * twist

	local pitch = lerpNumber(0, -78, plane)
	local yaw = lerpNumber(-95, -18, 1 - plane)
	local roll = lerpNumber(18, -8, plane)

	local joints: JointMap = {}

	if phaseKind == "Idle" then
		-- Dual channel : breath (UpperTorso) + micro-sway (phase décalée) — Animation Editor feel
		local bob = math.sin(a * math.pi * 2)
		local bobEase = smoothstep((bob + 1) * 0.5) * 2 - 1
		local breath = math.sin(a * math.pi * 2) -- inhale → exhale sur la boucle
		local breathEase = smoothstep((breath + 1) * 0.5) * 2 - 1
		local sway = math.sin(a * math.pi * 2 + 1.15)
		local swayEase = smoothstep((sway + 1) * 0.5) * 2 - 1
		joints.LowerTorso = angLim(2 + lean * 18 + breathEase * 0.8, lean * 12 + swayEase * 1.2, bobEase * 1.2, LIM.Torso)
			* CFrame.new(lean * 0.02 + swayEase * 0.008, 0.008 + breathEase * 0.014, swayEase * 0.004)
		joints.UpperTorso = angLim(-3 + breathEase * 3.2 + bobEase * 1.2, lean * 10 + swayEase * 2.5, bobEase * 3 + swayEase * 2, LIM.Torso)
		joints.Head = angLim(-4 + breathEase * 1.5, lean * -8 + swayEase * -1.5, bobEase * 1.5, LIM.Head)
		joints.RightUpperArm = angLim(-25 + bobEase * 4 + breathEase * 1.5, -15 + swayEase * 2, 20 + lean * 18 + bobEase * 2.5, LIM.UpperArm)
		joints.RightLowerArm = angLim(-35, 10, bobEase * 1.5, LIM.LowerArm)
		joints.RightHand = angLim(0, 0, 8 + bobEase * 1.5, LIM.Hand)
		joints.HiltGrip = angLim(bobEase * 4 + breathEase * 2, bobEase * 3 + swayEase * 2, bobEase * 1.5, LIM.Hilt)
		joints.LeftUpperArm = angLim(-15 + breathEase * 1.2, 20 + swayEase * 2, -off * 22, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-40, -10, 0, LIM.LowerArm)
		joints.RightUpperLeg = angLim(bobEase * 1.2 + breathEase * 0.4, swayEase * 0.8, lean * 4, LIM.Leg)
		joints.LeftUpperLeg = angLim(-bobEase * 1.2 - breathEase * 0.4, -swayEase * 0.8, -lean * 4, LIM.Leg)
	elseif phaseKind == "Guard" then
		-- a : 0 = enter (depuis Idle-ish), 1 = hold ; micro-breath en fin de boucle
		local g = smoothstep(a)
		local holdBreath = math.sin(a * math.pi * 2) * 0.35 * smoothstep(math.clamp((a - 0.55) / 0.45, 0, 1))
		local guardArmPitch = clampDeg(s.guardPitch * 58 - 18, -78, 20)
		joints.LowerTorso = angLim(4 + g * 1.2 + holdBreath * 0.6, -twist * 18 * g, hipShift * 4 * g, LIM.Torso)
			* CFrame.new(-hipShift * 0.03 * g, holdBreath * 0.008, 0)
		joints.UpperTorso = angLim(-6 * g - holdBreath * 1.2, twist * 22 * g, -shoulderRoll * 0.12 * g + holdBreath * 1.5, LIM.Torso)
		joints.Head = angLim(-8 * g, -twist * 10 * g, holdBreath * 0.8, LIM.Head)
		joints.RightUpperArm = angLim(
			lerpNumber(-25, guardArmPitch, g) + holdBreath * 2,
			lerpNumber(-15, -48, g),
			lerpNumber(20, 32 + shoulderRoll * 0.2, g),
			LIM.UpperArm
		)
		joints.RightLowerArm = angLim(lerpNumber(-35, -68, g), lerpNumber(10, 22, g), 8 * g, LIM.LowerArm)
		joints.RightHand = angLim(10 * g, 0, lerpNumber(8, -15, g), LIM.Hand)
		joints.HiltGrip = angLim(lerpNumber(0, -22, g), lerpNumber(0, 18, g), lerpNumber(0, -10, g), LIM.Hilt)
		joints.LeftUpperArm = angLim(lerpNumber(-15, -38, g), lerpNumber(20, 45, g), -off * 35 * g, LIM.UpperArm)
		joints.LeftLowerArm = angLim(lerpNumber(-40, -52, g), 0, 0, LIM.LowerArm)
		joints.RightUpperLeg = angLim(3 * g, 4 * g, 2 * g, LIM.Leg)
		joints.LeftUpperLeg = angLim(2 * g, -6 * g, -3 * g, LIM.Leg)
	elseif phaseKind == "Antici" then
		local e = smoothstep(a)
		-- Chambre réaliste : pitch ≥ -78°, yaw ≥ -68° (plus de -123° cassé)
		local chamberPitch = clampDeg(-48 - ant * 28 * plane, -78, -20)
		local chamberYaw = clampDeg(-32 - ant * 26 * (1 - plane), -68, -10)
		-- Weight shift arrière + shoulder roll chambre
		joints.LowerTorso = angLim(-3.5 * ant * e, -twist * 24 * ant * e, hipShift * 5 * e, LIM.Torso)
			* CFrame.new(hipShift * 0.035 * e, 0.018 * e, 0.025 * e)
		joints.UpperTorso = angLim(-6 * ant * e, -twist * 32 * ant * e, 4 * ant * e + shoulderRoll * 0.15 * e, LIM.Torso)
		joints.Head = angLim(5 * ant * e, twist * 12 * ant * e, 0, LIM.Head)
		joints.RightUpperArm = angLim(
			chamberPitch * e + (-25) * (1 - e),
			chamberYaw * e + (-15) * (1 - e),
			22 + ant * 12 * e + shoulderRoll * 0.28 * e,
			LIM.UpperArm
		)
		joints.RightLowerArm = angLim(-18 - ant * 22 * e, 12, 5 * e, LIM.LowerArm)
		joints.RightHand = angLim(-8 * e, -12 * e, 8 + shoulderRoll * 0.15 * e, LIM.Hand)
		joints.HiltGrip = angLim(-32 * ant * e, -24 * ant * e, 12 * ant * e, LIM.Hilt)
		joints.LeftUpperArm = angLim(-22, 28 + off * 16, -off * 26, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-42, 0, 0, LIM.LowerArm)
		if heavy then
			joints.RightUpperLeg = angLim(-5 * e, 4 * e, 3 * e, LIM.Leg)
			joints.LeftUpperLeg = angLim(7 * e, -3 * e, -5 * e, LIM.Leg)
		else
			joints.RightUpperLeg = angLim(-2 * e, 2 * e, 1 * e, LIM.Leg)
			joints.LeftUpperLeg = angLim(3 * e, -1 * e, -2 * e, LIM.Leg)
		end
	elseif phaseKind == "Contact" then
		local pMul = smoothstep(a)
		local swingPitch = clampDeg(pitch * arc * 0.35 + 22 * arc * pMul, -78, 50)
		local swingYaw = clampDeg(yaw * arc * 0.3 + 72 * arc * (1 - plane) * pMul * 0.45, -70, 65)
		local swingRoll = clampDeg(roll * arc * 0.25 + shoulderRoll * 0.45 * pMul - 12, -40, 38)
		-- Transfert poids avant / hanches
		joints.LowerTorso = angLim(5 * math.min(arc, 1.2) * pMul, twist * 36 * pMul, -hipShift * 6 * pMul, LIM.Torso)
			* CFrame.new(-hipShift * 0.04 * pMul, -0.018 * pMul, -0.035 * pMul)
		joints.UpperTorso = angLim(3.5 * math.min(arc, 1.2) * pMul, twist * 42 * pMul, -6 * pMul + shoulderRoll * 0.18 * pMul, LIM.Torso)
		joints.Head = angLim(-5, -twist * 16 * pMul, 0, LIM.Head)
		joints.RightUpperArm = angLim(swingPitch, swingYaw, swingRoll, LIM.UpperArm)
		joints.RightLowerArm = angLim(-12 + 35 * pMul, -16, -5 * pMul, LIM.LowerArm)
		joints.RightHand = angLim(12 * pMul, 20 * pMul, -16 + shoulderRoll * 0.22 * pMul, LIM.Hand)
		-- Poignet : yaw plafonné (plus de 126° hyper-rotation)
		joints.HiltGrip = angLim(24 * math.min(arc, 1.25) * pMul, 48 * math.min(arc, 1.25) * pMul * (1 - plane * 0.5), -12, LIM.Hilt)
		joints.LeftUpperArm = angLim(-28 - off * 16, 36, -off * 38 * pMul, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-48, 8, 0, LIM.LowerArm)
		if heavy then
			joints.RightUpperLeg = angLim(9 * pMul, -5 * pMul, 4 * pMul, LIM.Leg)
			joints.LeftUpperLeg = angLim(-3 * pMul, 6 * pMul, -3 * pMul, LIM.Leg)
		else
			joints.RightUpperLeg = angLim(4 * pMul, -2 * pMul, 2 * pMul, LIM.Leg)
			joints.LeftUpperLeg = angLim(-1 * pMul, 3 * pMul, -1 * pMul, LIM.Leg)
		end
	elseif phaseKind == "Follow" then
		local f = s.followThrough
		local settle = smoothstep(a)
		joints.LowerTorso = angLim(2.5 * f * (1 - settle), twist * 20 * f * (1 - settle), hipShift * 2.5 * (1 - settle), LIM.Torso)
			* CFrame.new(0, 0, -0.018 * f * (1 - settle))
		joints.UpperTorso = angLim(2 * (1 - settle), twist * 16 * (1 - settle), -3.5 * (1 - settle) + shoulderRoll * 0.08 * (1 - settle), LIM.Torso)
		joints.Head = angLim(-3, 0, 0, LIM.Head)
		joints.RightUpperArm = angLim(
			12 * f * (1 - settle) - 8 * settle,
			32 * f * (1 - settle) + 8 * settle,
			-8 + shoulderRoll * 0.12 * (1 - settle),
			LIM.UpperArm
		)
		joints.RightLowerArm = angLim(-24, 5, 0, LIM.LowerArm)
		joints.RightHand = angLim(5, 8, 0, LIM.Hand)
		joints.HiltGrip = angLim(6 * f * (1 - settle), 16 * f * (1 - settle), 0, LIM.Hilt)
		joints.LeftUpperArm = angLim(-18, 22, -off * 18, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-38, 0, 0, LIM.LowerArm)
		if heavy then
			joints.RightUpperLeg = angLim(4 * (1 - settle), -2 * (1 - settle), 2 * (1 - settle), LIM.Leg)
			joints.LeftUpperLeg = angLim(2 * (1 - settle), 3 * (1 - settle), -2 * (1 - settle), LIM.Leg)
		else
			joints.RightUpperLeg = angLim(1 * (1 - settle), 0, 0, LIM.Leg)
			joints.LeftUpperLeg = angLim(1 * (1 - settle), 0, 0, LIM.Leg)
		end
	elseif phaseKind == "Dodge" then
		local d = smoothstep(a)
		joints.LowerTorso = angLim(-7 * d, lean * 55 * d, lean * 28 * d, LIM.Torso) * CFrame.new(lean * 0.07 * d, 0.018 * d, 0)
		joints.UpperTorso = angLim(-8 * d, lean * 42 * d, lean * 22 * d, LIM.Torso)
		joints.Head = angLim(4 * d, -lean * 28 * d, 0, LIM.Head)
		joints.RightUpperArm = angLim(-45, 52, -32 + shoulderRoll * 0.15, LIM.UpperArm)
		joints.RightLowerArm = angLim(-38, 0, 0, LIM.LowerArm)
		joints.HiltGrip = angLim(-18, 32, -20, LIM.Hilt)
		joints.LeftUpperArm = angLim(-35, -26, 16, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-32, 0, 0, LIM.LowerArm)
		-- Jambes : ancrage latéral lisible
		joints.RightUpperLeg = angLim(-10 * d * math.sign(lean + 0.001), lean * 18 * d, lean * 14 * d, LIM.Leg)
		joints.LeftUpperLeg = angLim(7 * d, -lean * 16 * d, -lean * 12 * d, LIM.Leg)
	elseif phaseKind == "Dash" then
		local d = smoothstep(a)
		joints.LowerTorso = angLim(7 * d, 0, 0, LIM.Torso) * CFrame.new(0, -0.018 * d, -0.05 * d)
		joints.UpperTorso = angLim(10 * d, 0, 0, LIM.Torso)
		joints.Head = angLim(-8 * d, 0, 0, LIM.Head)
		joints.RightUpperArm = angLim(8, -22, 8, LIM.UpperArm)
		joints.RightLowerArm = angLim(-28, 0, 0, LIM.LowerArm)
		joints.HiltGrip = angLim(4, -12, 0, LIM.Hilt)
		joints.LeftUpperArm = angLim(4, 18, -8, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-22, 0, 0, LIM.LowerArm)
		-- Fente avant légère
		joints.RightUpperLeg = angLim(12 * d, -3 * d, 2 * d, LIM.Leg)
		joints.LeftUpperLeg = angLim(-7 * d, 3 * d, -2 * d, LIM.Leg)
	elseif phaseKind == "Focus" then
		local d = smoothstep(a)
		joints.LowerTorso = angLim(8 * d, 0, 0, LIM.Torso) * CFrame.new(0, 0, -0.04 * d)
		joints.UpperTorso = angLim(12 * d, 0, 0, LIM.Torso)
		joints.Head = angLim(-10 * d, 0, 0, LIM.Head)
		joints.RightUpperArm = angLim(-18, 0, shoulderRoll * 0.08, LIM.UpperArm)
		joints.RightLowerArm = angLim(-10, 0, 0, LIM.LowerArm)
		joints.HiltGrip = angLim(0, 0, 0, LIM.Hilt) * CFrame.new(0, 0, -0.12 * d)
		joints.LeftUpperArm = angLim(-22, 36, -off * 40, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-28, 0, 0, LIM.LowerArm)
		joints.RightUpperLeg = angLim(5 * d, 0, 0, LIM.Leg)
		joints.LeftUpperLeg = angLim(-3 * d, 0, 0, LIM.Leg)
	elseif phaseKind == "Stagger" then
		local d = smoothstep(a)
		joints.LowerTorso = angLim(-10 * d, -20 * d, 12 * d, LIM.Torso)
		joints.UpperTorso = angLim(-12 * d, -24 * d, 16 * d, LIM.Torso)
		joints.Head = angLim(18 * d, 12 * d, 8 * d, LIM.Head)
		joints.RightUpperArm = angLim(35 * d, -35 * d, 28 * d, LIM.UpperArm)
		joints.RightLowerArm = angLim(-18, 0, 0, LIM.LowerArm)
		joints.HiltGrip = angLim(24 * d, -16 * d, 20 * d, LIM.Hilt)
		joints.LeftUpperArm = angLim(16 * d, 26 * d, -16 * d, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-14, 0, 0, LIM.LowerArm)
		joints.RightUpperLeg = angLim(-7 * d, 8 * d, 5 * d, LIM.Leg)
		joints.LeftUpperLeg = angLim(5 * d, -7 * d, -4 * d, LIM.Leg)
	elseif phaseKind == "Dead" then
		local d = smoothstep(a)
		-- Collapse lisible mais plafonné (pas d'épaule 70°+ non clampée)
		joints.LowerTorso = angLim(-18 * d, 8 * d, 16 * d, LIM.Torso)
		joints.UpperTorso = angLim(-20 * d, 12 * d, 18 * d, LIM.Torso)
		joints.Head = angLim(28 * d, 0, 12 * d, LIM.Head)
		joints.RightUpperArm = angLim(52 * d, -16 * d, 32 * d, LIM.UpperArm)
		joints.RightLowerArm = angLim(-10, 0, 0, LIM.LowerArm)
		joints.HiltGrip = angLim(40 * d, 0, 24 * d, LIM.Hilt)
		joints.LeftUpperArm = angLim(32 * d, 20 * d, -12 * d, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-5, 0, 0, LIM.LowerArm)
		joints.RightUpperLeg = angLim(-12 * d, 6 * d, 8 * d, LIM.Leg)
		joints.LeftUpperLeg = angLim(-8 * d, -5 * d, -6 * d, LIM.Leg)
	elseif phaseKind == "Feint" then
		-- Chambre → fake peak → abort → snap Guard (plus de KF lisibles)
		if a < 0.38 then
			return sampleJoints(style, "Antici", smoothstep(a / 0.38), false)
		elseif a < 0.48 then
			-- Hold fake au pic anticipation
			return sampleJoints(style, "Antici", 1, false)
		elseif a < 0.62 then
			local antPose = sampleJoints(style, "Antici", 1, false)
			local mid = sampleJoints(style, "Guard", 0.35, false)
			return lerpJoints(antPose, mid, smoothstep((a - 0.48) / 0.14))
		end
		return sampleJoints(style, "Guard", smoothstep((a - 0.62) / 0.38), false)
	elseif phaseKind == "Riposte" then
		local e = smoothstep(a)
		joints.LowerTorso = angLim(5 * e, 0, 0, LIM.Torso) * CFrame.new(0, 0, -0.035 * e)
		joints.UpperTorso = angLim(8 * e, 0, 0, LIM.Torso)
		joints.Head = angLim(-6 * e, 0, 0, LIM.Head)
		joints.RightUpperArm = angLim(-14 + 4 * e, -5, 4 + shoulderRoll * 0.08, LIM.UpperArm)
		joints.RightLowerArm = angLim(-5 + 36 * e, 0, 0, LIM.LowerArm)
		joints.RightHand = angLim(0, 0, 0, LIM.Hand)
		joints.HiltGrip = CFrame.new(0, 0, -0.2 * e)
		joints.LeftUpperArm = angLim(-18, 22, -12, LIM.UpperArm)
		joints.LeftLowerArm = angLim(-32, 0, 0, LIM.LowerArm)
		joints.RightUpperLeg = angLim(7 * e, 0, 0, LIM.Leg)
		joints.LeftUpperLeg = angLim(-3 * e, 0, 0, LIM.Leg)
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
		local dur = 1.6 / tempo -- cycle breath un peu plus lent = lisible
		-- 12 segments + close — breathing UpperTorso + micro-sway
		for i = 0, 11 do
			local u = i / 12
			local name: string? = nil
			if i == 0 then
				name = "Idle0"
			elseif i == 3 then
				name = "IdleInhale"
			elseif i == 6 then
				name = "IdleMid"
			elseif i == 9 then
				name = "IdleExhale"
			end
			addKeyframe(seq, dur * u, sampleJoints(style, "Idle", u, false), name)
		end
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 1, false), "IdleEnd")
		return seq
	end

	if clipName == "Guard" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action, true)
		local dur = 1.05 / tempo
		--[[
			Boucle seamless (KF0 ≈ KF end) : hold + micro-breath densifié.
			Enter / exit = fadeIn 0.16 / fadeOut 0.18 (CombatAnimator) depuis/vers Idle —
			évite un pop Raise→Hold à chaque loop.
		]]
		local function guardBreath(phase: number): JointMap
			-- phase 0..1 → alpha hold 0.88..1.0 avec oscillation
			local wave = math.sin(phase * math.pi * 2)
			local alpha = 0.9 + 0.1 * smoothstep((wave + 1) * 0.5)
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
		addKeyframe(seq, dur, guardBreath(1), "GuardHoldB") -- ≈ GuardHoldA
		return seq
	end


	if clipName == "Dodge" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Movement, false)
		local dur = 0.28 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false), "DodgeFrom")
		addKeyframe(seq, dur * 0.15, sampleJoints(style, "Dodge", 0.25, false), "DodgeWind")
		addKeyframe(seq, dur * 0.4, sampleJoints(style, "Dodge", 0.85, false), "DodgePeak")
		addKeyframe(seq, dur * 0.7, sampleJoints(style, "Dodge", 0.45, false), "DodgeFall")
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 0.2, false), "DodgeOut")
		return seq
	end

	if clipName == "Dash" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Movement, false)
		local dur = 0.22 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false), "DashFrom")
		addKeyframe(seq, dur * 0.2, sampleJoints(style, "Dash", 0.4, false), "DashPush")
		addKeyframe(seq, dur * 0.45, sampleJoints(style, "Dash", 1, false), "DashPeak")
		addKeyframe(seq, dur * 0.75, sampleJoints(style, "Dash", 0.5, false), "DashCoast")
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 0.1, false), "DashOut")
		return seq
	end

	if clipName == "FocusPush" or clipName == "FocusDash" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action2, false)
		local dur = (if clipName == "FocusPush" then 0.35 else 0.28) / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Antici", 0.4, false), "FocusWind")
		addKeyframe(seq, dur * 0.25, sampleJoints(style, "Focus", 0.5, false))
		addKeyframe(seq, dur * 0.5, sampleJoints(style, "Focus", 1, false), "FocusPeak")
		addKeyframe(seq, dur * 0.75, sampleJoints(style, "Follow", 0.35, false))
		addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.6, false), "FocusOut")
		return seq
	end

	if clipName == "Stagger" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action4, false)
		local dur = 0.45 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false))
		addKeyframe(seq, dur * 0.15, sampleJoints(style, "Stagger", 0.4, false))
		addKeyframe(seq, dur * 0.35, sampleJoints(style, "Stagger", 1, false), "StaggerHit")
		addKeyframe(seq, dur * 0.7, sampleJoints(style, "Stagger", 0.85, false))
		addKeyframe(seq, dur, sampleJoints(style, "Stagger", 0.7, false))
		return seq
	end

	if clipName == "Dead" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action4, false)
		local dur = 0.7 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Stagger", 0.5, false))
		addKeyframe(seq, dur * 0.25, sampleJoints(style, "Dead", 0.35, false))
		addKeyframe(seq, dur * 0.55, sampleJoints(style, "Dead", 0.85, false), "KO")
		addKeyframe(seq, dur, sampleJoints(style, "Dead", 1, false))
		return seq
	end

	if clipName == "Feint" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action2, false)
		-- Aligné fenêtre feinte (cancel Startup Light avant Active ≈ CombatConfig.Light.Startup)
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
		local dur = 0.3 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Guard", 0.5, false), "RiposteFrom")
		addKeyframe(seq, dur * 0.18, sampleJoints(style, "Riposte", 0.2, false), "RiposteWind")
		addKeyframe(seq, dur * 0.4, sampleJoints(style, "Riposte", 0.65, false))
		addKeyframe(seq, dur * 0.58, sampleJoints(style, "Riposte", 1, false), "RiposteHit")
		addKeyframe(seq, dur * 0.8, sampleJoints(style, "Follow", 0.35, false))
		addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.5, false), "RiposteOut")
		return seq
	end

	-- Startup / Active / Recovery (Light|Heavy) — densifiés Pass fluidité
	local isStartup = string.sub(clipName, 1, 7) == "Startup"
	local isActive = string.sub(clipName, 1, 6) == "Active"
	local isRecovery = string.sub(clipName, 1, 8) == "Recovery"

	if isStartup then
		local seq = emptySequence(seqName, priority, false)
		local dur = attackPhaseDuration(clipName) -- = CombatConfig Light/Heavy.Startup
		-- Idle → Antici avec ease : pas de cut (6–7 KFs)
		local idle0 = sampleJoints(style, "Idle", 0, heavy)
		local ant025 = sampleJoints(style, "Antici", 0.25, heavy)
		local ant05 = sampleJoints(style, "Antici", 0.5, heavy)
		local ant075 = sampleJoints(style, "Antici", 0.75, heavy)
		local ant09 = sampleJoints(style, "Antici", 0.9, heavy)
		local ant1 = sampleJoints(style, "Antici", 1.0, heavy)
		addKeyframe(seq, 0, idle0, "StartFromIdle")
		addKeyframe(seq, dur * 0.12, lerpJoints(idle0, ant025, smoothstep(0.55)), "StartBlend")
		addKeyframe(seq, dur * 0.28, ant025, "AnticiEarly")
		addKeyframe(seq, dur * 0.48, ant05, "AnticiMid")
		addKeyframe(seq, dur * 0.68, ant075, "AnticiPeak")
		addKeyframe(seq, dur * 0.85, ant09, "AnticiHold")
		addKeyframe(seq, dur, ant1, "AnticiReady")
		return seq
	end

	if isActive then
		local seq = emptySequence(seqName, priority, false)
		local dur = attackPhaseDuration(clipName) -- = CombatConfig Light/Heavy.Active
		addKeyframe(seq, 0, sampleJoints(style, "Antici", 1.0, heavy), "SwingRelease")
		if style.doubleBeat then
			addKeyframe(seq, dur * 0.12, sampleJoints(style, "Contact", 0.35, heavy), "Beat1In")
			addKeyframe(seq, dur * 0.26, sampleJoints(style, "Contact", 0.9, heavy), "Beat1")
			addKeyframe(seq, dur * 0.38, sampleJoints(style, "Contact", 0.4, heavy), "Valley")
			addKeyframe(seq, dur * 0.52, sampleJoints(style, "Contact", 0.55, heavy), "Beat2In")
			addKeyframe(seq, dur * 0.68, sampleJoints(style, "Contact", 1.0, heavy), "Beat2")
			addKeyframe(seq, dur * 0.85, sampleJoints(style, "Follow", 0.2, heavy), "Through")
			addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.4, heavy), "ActiveEnd")
		else
			-- 7 KFs : release → arc → impact → overshoot → follow
			addKeyframe(seq, dur * 0.12, sampleJoints(style, "Contact", 0.2, heavy), "ArcTip")
			addKeyframe(seq, dur * 0.28, sampleJoints(style, "Contact", 0.5, heavy), "ArcIn")
			addKeyframe(seq, dur * 0.48, sampleJoints(style, "Contact", 0.85, heavy), "PreImpact")
			addKeyframe(seq, dur * 0.58, sampleJoints(style, "Contact", 1.0, heavy), "Impact")
			addKeyframe(seq, dur * 0.72, sampleJoints(style, "Follow", 0.15, heavy), "Overshoot")
			addKeyframe(seq, dur * 0.88, sampleJoints(style, "Follow", 0.35, heavy), "Through")
			addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.5, heavy), "ActiveEnd")
		end
		return seq
	end

	if isRecovery then
		local seq = emptySequence(seqName, priority, false)
		local dur = attackPhaseDuration(clipName) -- = CombatConfig Light/Heavy.Recovery
		local follow0 = sampleJoints(style, "Follow", 0.5, heavy)
		local followMid = sampleJoints(style, "Follow", 0.8, heavy)
		local idleBlend = sampleJoints(style, "Idle", 0.35, heavy)
		local idle0 = sampleJoints(style, "Idle", 0, heavy)
		addKeyframe(seq, 0, follow0, "RecStart")
		addKeyframe(seq, dur * 0.18, followMid, "RecCoast")
		addKeyframe(seq, dur * 0.4, lerpJoints(followMid, idleBlend, smoothstep(0.4)), "RecEase")
		addKeyframe(seq, dur * 0.58, idleBlend, "RecSettle")
		addKeyframe(seq, dur * 0.78, lerpJoints(idleBlend, idle0, smoothstep(0.55)), "RecSoft")
		addKeyframe(seq, dur, idle0, "RecIdle")
		return seq
	end


	local seq = emptySequence(seqName, Enum.AnimationPriority.Idle, true)
	addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false))
	addKeyframe(seq, 0.5, sampleJoints(style, "Idle", 0.5, false))
	return seq
end

--[[
	Expose sample pour ProceduralTrackPlayer (mêmes courbes sans Animator).
	Suit les phases densifiées + ease pour coller aux KeyframeSequences.
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
		-- Hold + micro-breath (enter/exit via fade CombatAnimator)
		local wave = math.sin(n * math.pi * 2)
		local alpha = 0.9 + 0.1 * smoothstep((wave + 1) * 0.5)
		return sampleJoints(style, "Guard", alpha, false)
	elseif clipName == "Dodge" then
		if n < 0.4 then
			return sampleJoints(style, "Dodge", smoothstep(n / 0.4), false)
		end
		local idle = sampleJoints(style, "Idle", 0.2, false)
		local dodge = sampleJoints(style, "Dodge", 0.85, false)
		return lerpJoints(dodge, idle, smoothstep((n - 0.4) / 0.6))
	elseif clipName == "Dash" then
		if n < 0.45 then
			return sampleJoints(style, "Dash", smoothstep(n / 0.45), false)
		end
		local idle = sampleJoints(style, "Idle", 0.1, false)
		local dash = sampleJoints(style, "Dash", 1, false)
		return lerpJoints(dash, idle, smoothstep((n - 0.45) / 0.55))
	elseif clipName == "FocusPush" or clipName == "FocusDash" then
		if n < 0.25 then
			return sampleJoints(style, "Antici", smoothstep(n / 0.25) * 0.4, false)
		elseif n < 0.55 then
			return sampleJoints(style, "Focus", smoothstep((n - 0.25) / 0.3), false)
		end
		return sampleJoints(style, "Follow", 0.35 + smoothstep((n - 0.55) / 0.45) * 0.25, false)
	elseif clipName == "Stagger" then
		return sampleJoints(style, "Stagger", math.min(1, smoothstep(n) * 1.1), false)
	elseif clipName == "Dead" then
		return sampleJoints(style, "Dead", smoothstep(n), false)
	elseif clipName == "Feint" then
		-- Courbe densifiée (fake hold + abort) — sampleJoints Feint gère les seuils
		return sampleJoints(style, "Feint", n, false)
	elseif clipName == "Riposte" then
		if n < 0.18 then
			return sampleJoints(style, "Guard", 0.5, false)
		elseif n < 0.58 then
			return sampleJoints(style, "Riposte", smoothstep((n - 0.18) / 0.4), false)
		end
		return sampleJoints(style, "Follow", 0.35 + smoothstep((n - 0.58) / 0.42) * 0.15, false)
	elseif string.sub(clipName, 1, 7) == "Startup" then
		-- Blend Idle→Antici (évite cut)
		if n < 0.15 then
			local idle = sampleJoints(style, "Idle", 0, heavy)
			local ant = sampleJoints(style, "Antici", 0.2, heavy)
			return lerpJoints(idle, ant, smoothstep(n / 0.15))
		end
		return sampleJoints(style, "Antici", smoothstep((n - 0.15) / 0.85), heavy)
	elseif string.sub(clipName, 1, 6) == "Active" then
		if style.doubleBeat then
			if n < 0.28 then
				return sampleJoints(style, "Contact", smoothstep(n / 0.28), heavy)
			elseif n < 0.42 then
				local hi = sampleJoints(style, "Contact", 0.9, heavy)
				local lo = sampleJoints(style, "Contact", 0.4, heavy)
				return lerpJoints(hi, lo, smoothstep((n - 0.28) / 0.14))
			elseif n < 0.7 then
				return sampleJoints(style, "Contact", 0.4 + smoothstep((n - 0.42) / 0.28) * 0.6, heavy)
			end
			return sampleJoints(style, "Follow", smoothstep((n - 0.7) / 0.3) * 0.4, heavy)
		end
		if n < 0.55 then
			return sampleJoints(style, "Contact", smoothstep(n / 0.55), heavy)
		end
		return sampleJoints(style, "Follow", smoothstep((n - 0.55) / 0.45) * 0.5, heavy)
	elseif string.sub(clipName, 1, 8) == "Recovery" then
		if n < 0.45 then
			return sampleJoints(style, "Follow", 0.5 + smoothstep(n / 0.45) * 0.35, heavy)
		end
		local follow = sampleJoints(style, "Follow", 0.85, heavy)
		local idle = sampleJoints(style, "Idle", 0, heavy)
		return lerpJoints(follow, idle, smoothstep((n - 0.45) / 0.55))
	end
	return sampleJoints(style, "Idle", 0, false)
end

return KeyframeFactory
