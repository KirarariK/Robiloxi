--!strict
--[[
	Construit des KeyframeSequence R15 (+ HiltGrip + jambes) à partir des StyleParams.
	Pass fluidité : densification Active/Startup/Recovery, ease curves, shoulder roll,
	weight shift LowerTorso, ancrage RightUpperLeg/LeftUpperLeg (Dodge/Dash/Heavy).
	Pass continue : Idle breathing, Guard enter/exit densifiés, Feint 8 KF,
	Track Length = CombatConfig Light/Heavy (frame data).
	Sources : docs Pose / KeyframeSequence / KeyframeSequenceProvider.
]]

local Shared = script.Parent.Parent:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local AnimationSets = require(script.Parent:WaitForChild("AnimationSets"))

export type JointMap = { [string]: CFrame }

local KeyframeFactory = {}

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

local function ang(xDeg: number, yDeg: number, zDeg: number): CFrame
	return CFrame.Angles(math.rad(xDeg), math.rad(yDeg), math.rad(zDeg))
end

-- Ease curves (smoothstep / cubic) pour éviter les cuts linéaires
local function easeInOut(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOutCubic(t: number): number
	local x = 1 - math.clamp(t, 0, 1)
	return 1 - x * x * x
end

local function easeInCubic(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * x
end

local function easeOutQuad(t: number): number
	local x = math.clamp(t, 0, 1)
	return 1 - (1 - x) * (1 - x)
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
	local s = style
	local a = math.clamp(alpha, 0, 1)
	local heavyMul = if heavy then 1.25 else 1.0
	local ant = s.anticipation * heavyMul
	local arc = s.swingArc * heavyMul
	local plane = s.planeBias -- 0 horiz, 1 vert
	local twist = s.torsoTwist
	local off = s.offhand
	local lean = s.idleLean
	-- Shoulder roll + weight-shift hips (Pass fluidité)
	local shoulderRoll = lerpNumber(18, -22, plane) * arc
	local hipShift = (if heavy then 1.15 else 0.85) * twist

	local pitch = lerpNumber(0, -90, plane)
	local yaw = lerpNumber(-110, -20, 1 - plane)
	local roll = lerpNumber(25, -10, plane)

	local joints: JointMap = {}

	if phaseKind == "Idle" then
		-- Dual channel : breath (UpperTorso) + micro-sway (phase décalée) — Animation Editor feel
		local bob = math.sin(a * math.pi * 2)
		local bobEase = easeInOut((bob + 1) * 0.5) * 2 - 1
		local breath = math.sin(a * math.pi * 2) -- inhale → exhale sur la boucle
		local breathEase = easeInOut((breath + 1) * 0.5) * 2 - 1
		local sway = math.sin(a * math.pi * 2 + 1.15)
		local swayEase = easeInOut((sway + 1) * 0.5) * 2 - 1
		joints.LowerTorso = ang(2 + lean * 20 + breathEase * 0.8, lean * 15 + swayEase * 1.2, bobEase * 1.2)
			* CFrame.new(lean * 0.02 + swayEase * 0.008, 0.008 + breathEase * 0.014, swayEase * 0.004)
		joints.UpperTorso = ang(-3 + breathEase * 3.2 + bobEase * 1.2, lean * 10 + swayEase * 2.5, bobEase * 3 + swayEase * 2)
		joints.Head = ang(-4 + breathEase * 1.5, lean * -8 + swayEase * -1.5, bobEase * 1.5)
		joints.RightUpperArm = ang(-25 + bobEase * 4 + breathEase * 1.5, -15 + swayEase * 2, 20 + lean * 20 + bobEase * 2.5)
		joints.RightLowerArm = ang(-35, 10, bobEase * 1.5)
		joints.RightHand = ang(0, 0, 8 + bobEase * 1.5)
		joints.HiltGrip = ang(bobEase * 4 + breathEase * 2, bobEase * 3 + swayEase * 2, bobEase * 1.5)
		joints.LeftUpperArm = ang(-15 + breathEase * 1.2, 20 + swayEase * 2, -off * 25)
		joints.LeftLowerArm = ang(-40, -10, 0)
		joints.RightUpperLeg = ang(bobEase * 1.2 + breathEase * 0.4, swayEase * 0.8, lean * 4)
		joints.LeftUpperLeg = ang(-bobEase * 1.2 - breathEase * 0.4, -swayEase * 0.8, -lean * 4)
	elseif phaseKind == "Guard" then
		-- a : 0 = enter (depuis Idle-ish), 1 = hold ; micro-breath en fin de boucle
		local g = easeOutCubic(a)
		local holdBreath = math.sin(a * math.pi * 2) * 0.35 * easeInOut(math.clamp((a - 0.55) / 0.45, 0, 1))
		joints.LowerTorso = ang(4 + g * 1.2 + holdBreath * 0.6, -twist * 20 * g, hipShift * 4 * g)
			* CFrame.new(-hipShift * 0.03 * g, holdBreath * 0.008, 0)
		joints.UpperTorso = ang(-6 * g - holdBreath * 1.2, twist * 25 * g, -shoulderRoll * 0.15 * g + holdBreath * 1.5)
		joints.Head = ang(-8 * g, -twist * 10 * g, holdBreath * 0.8)
		joints.RightUpperArm = ang(
			lerpNumber(-25, s.guardPitch * 70 - 20, g) + holdBreath * 2,
			lerpNumber(-15, -55, g),
			lerpNumber(20, 35 + shoulderRoll * 0.25, g)
		)
		joints.RightLowerArm = ang(lerpNumber(-35, -70, g), lerpNumber(10, 25, g), 8 * g)
		joints.RightHand = ang(10 * g, 0, lerpNumber(8, -15, g))
		joints.HiltGrip = ang(lerpNumber(0, -25, g), lerpNumber(0, 20, g), lerpNumber(0, -10, g))
		joints.LeftUpperArm = ang(lerpNumber(-15, -40, g), lerpNumber(20, 50, g), -off * 40 * g)
		joints.LeftLowerArm = ang(lerpNumber(-40, -55, g), 0, 0)
		joints.RightUpperLeg = ang(3 * g, 4 * g, 2 * g)
		joints.LeftUpperLeg = ang(2 * g, -6 * g, -3 * g)
	elseif phaseKind == "Antici" then
		local e = easeInCubic(a)
		local chamberPitch = -55 - ant * 40 * plane
		local chamberYaw = -40 - ant * 35 * (1 - plane)
		-- Weight shift arrière + shoulder roll chambre
		joints.LowerTorso = ang(-4 * ant * e, -twist * 30 * ant * e, hipShift * 6 * e)
			* CFrame.new(hipShift * 0.04 * e, 0.02 * e, 0.03 * e)
		joints.UpperTorso = ang(-8 * ant * e, -twist * 40 * ant * e, 5 * ant * e + shoulderRoll * 0.2 * e)
		joints.Head = ang(6 * ant * e, twist * 15 * ant * e, 0)
		joints.RightUpperArm = ang(chamberPitch * e + (-25) * (1 - e), chamberYaw * e + (-15) * (1 - e), 25 + ant * 15 * e + shoulderRoll * 0.35 * e)
		joints.RightLowerArm = ang(-20 - ant * 25 * e, 15, 6 * e)
		joints.RightHand = ang(-10 * e, -15 * e, 10 + shoulderRoll * 0.2 * e)
		joints.HiltGrip = ang(-40 * ant * e, -30 * ant * e, 15 * ant * e)
		joints.LeftUpperArm = ang(-25, 30 + off * 20, -off * 30)
		joints.LeftLowerArm = ang(-45, 0, 0)
		if heavy then
			joints.RightUpperLeg = ang(-6 * e, 5 * e, 4 * e)
			joints.LeftUpperLeg = ang(8 * e, -4 * e, -6 * e)
		else
			joints.RightUpperLeg = ang(-2 * e, 2 * e, 1 * e)
			joints.LeftUpperLeg = ang(3 * e, -1 * e, -2 * e)
		end
	elseif phaseKind == "Contact" then
		local pMul = easeOutCubic(a)
		local swingPitch = pitch * arc * 0.4 + 25 * arc * pMul
		local swingYaw = yaw * arc * 0.35 + 90 * arc * (1 - plane) * pMul * 0.5
		local swingRoll = roll * arc * 0.3 + shoulderRoll * 0.55 * pMul
		-- Transfert poids avant / hanches
		joints.LowerTorso = ang(6 * arc * pMul, twist * 45 * pMul, -hipShift * 8 * pMul)
			* CFrame.new(-hipShift * 0.05 * pMul, -0.02 * pMul, -0.04 * pMul)
		joints.UpperTorso = ang(4 * arc * pMul, twist * 55 * pMul, -8 * pMul + shoulderRoll * 0.25 * pMul)
		joints.Head = ang(-5, -twist * 20 * pMul, 0)
		joints.RightUpperArm = ang(swingPitch, swingYaw, swingRoll - 15)
		joints.RightLowerArm = ang(-15 + 40 * pMul, -20, -6 * pMul)
		joints.RightHand = ang(15 * pMul, 25 * pMul, -20 + shoulderRoll * 0.3 * pMul)
		joints.HiltGrip = ang(30 * arc * pMul, 70 * arc * pMul * (1 - plane * 0.5), -15)
		joints.LeftUpperArm = ang(-30 - off * 20, 40, -off * 45 * pMul)
		joints.LeftLowerArm = ang(-50, 10, 0)
		if heavy then
			joints.RightUpperLeg = ang(10 * pMul, -6 * pMul, 5 * pMul)
			joints.LeftUpperLeg = ang(-4 * pMul, 8 * pMul, -4 * pMul)
		else
			joints.RightUpperLeg = ang(4 * pMul, -2 * pMul, 2 * pMul)
			joints.LeftUpperLeg = ang(-1 * pMul, 3 * pMul, -1 * pMul)
		end
	elseif phaseKind == "Follow" then
		local f = s.followThrough
		local settle = easeInOut(a)
		joints.LowerTorso = ang(3 * f * (1 - settle), twist * 25 * f * (1 - settle), hipShift * 3 * (1 - settle))
			* CFrame.new(0, 0, -0.02 * f * (1 - settle))
		joints.UpperTorso = ang(2 * (1 - settle), twist * 20 * (1 - settle), -4 * (1 - settle) + shoulderRoll * 0.1 * (1 - settle))
		joints.Head = ang(-3, 0, 0)
		joints.RightUpperArm = ang(15 * f * (1 - settle) - 10 * settle, 40 * f * (1 - settle) + 10 * settle, -10 + shoulderRoll * 0.15 * (1 - settle))
		joints.RightLowerArm = ang(-25, 5, 0)
		joints.RightHand = ang(5, 10, 0)
		joints.HiltGrip = ang(8 * f * (1 - settle), 20 * f * (1 - settle), 0)
		joints.LeftUpperArm = ang(-20, 25, -off * 20)
		joints.LeftLowerArm = ang(-40, 0, 0)
		if heavy then
			joints.RightUpperLeg = ang(5 * (1 - settle), -2 * (1 - settle), 2 * (1 - settle))
			joints.LeftUpperLeg = ang(2 * (1 - settle), 3 * (1 - settle), -2 * (1 - settle))
		else
			joints.RightUpperLeg = ang(1 * (1 - settle), 0, 0)
			joints.LeftUpperLeg = ang(1 * (1 - settle), 0, 0)
		end
	elseif phaseKind == "Dodge" then
		local d = easeOutCubic(a)
		joints.LowerTorso = ang(-8 * d, lean * 80 * d, lean * 40 * d) * CFrame.new(lean * 0.08 * d, 0.02 * d, 0)
		joints.UpperTorso = ang(-10 * d, lean * 60 * d, lean * 30 * d)
		joints.Head = ang(5 * d, -lean * 40 * d, 0)
		joints.RightUpperArm = ang(-50, 60, -40 + shoulderRoll * 0.2)
		joints.RightLowerArm = ang(-40, 0, 0)
		joints.HiltGrip = ang(-20, 40, -25)
		joints.LeftUpperArm = ang(-40, -30, 20)
		joints.LeftLowerArm = ang(-35, 0, 0)
		-- Jambes : ancrage latéral lisible
		joints.RightUpperLeg = ang(-12 * d * math.sign(lean + 0.001), lean * 25 * d, lean * 18 * d)
		joints.LeftUpperLeg = ang(8 * d, -lean * 20 * d, -lean * 14 * d)
	elseif phaseKind == "Dash" then
		local d = easeOutCubic(a)
		joints.LowerTorso = ang(8 * d, 0, 0) * CFrame.new(0, -0.02 * d, -0.06 * d)
		joints.UpperTorso = ang(12 * d, 0, 0)
		joints.Head = ang(-10 * d, 0, 0)
		joints.RightUpperArm = ang(10, -25, 10)
		joints.RightLowerArm = ang(-30, 0, 0)
		joints.HiltGrip = ang(5, -15, 0)
		joints.LeftUpperArm = ang(5, 20, -10)
		joints.LeftLowerArm = ang(-25, 0, 0)
		-- Fente avant légère
		joints.RightUpperLeg = ang(14 * d, -4 * d, 3 * d)
		joints.LeftUpperLeg = ang(-8 * d, 4 * d, -2 * d)
	elseif phaseKind == "Focus" then
		local d = easeOutQuad(a)
		joints.LowerTorso = ang(10 * d, 0, 0) * CFrame.new(0, 0, -0.05 * d)
		joints.UpperTorso = ang(15 * d, 0, 0)
		joints.Head = ang(-12 * d, 0, 0)
		joints.RightUpperArm = ang(-20, 0, shoulderRoll * 0.1)
		joints.RightLowerArm = ang(-10, 0, 0)
		joints.HiltGrip = ang(0, 0, 0) * CFrame.new(0, 0, -0.15 * d)
		joints.LeftUpperArm = ang(-25, 40, -off * 50)
		joints.LeftLowerArm = ang(-30, 0, 0)
		joints.RightUpperLeg = ang(6 * d, 0, 0)
		joints.LeftUpperLeg = ang(-3 * d, 0, 0)
	elseif phaseKind == "Stagger" then
		local d = easeOutCubic(a)
		joints.LowerTorso = ang(-12 * d, -25 * d, 15 * d)
		joints.UpperTorso = ang(-15 * d, -30 * d, 20 * d)
		joints.Head = ang(20 * d, 15 * d, 10 * d)
		joints.RightUpperArm = ang(40 * d, -40 * d, 35 * d)
		joints.RightLowerArm = ang(-20, 0, 0)
		joints.HiltGrip = ang(30 * d, -20 * d, 25 * d)
		joints.LeftUpperArm = ang(20 * d, 30 * d, -20 * d)
		joints.LeftLowerArm = ang(-15, 0, 0)
		joints.RightUpperLeg = ang(-8 * d, 10 * d, 6 * d)
		joints.LeftUpperLeg = ang(6 * d, -8 * d, -5 * d)
	elseif phaseKind == "Dead" then
		local d = easeInOut(a)
		joints.LowerTorso = ang(-25 * d, 10 * d, 20 * d)
		joints.UpperTorso = ang(-30 * d, 15 * d, 25 * d)
		joints.Head = ang(35 * d, 0, 15 * d)
		joints.RightUpperArm = ang(70 * d, -20 * d, 40 * d)
		joints.RightLowerArm = ang(-10, 0, 0)
		joints.HiltGrip = ang(50 * d, 0, 30 * d)
		joints.LeftUpperArm = ang(40 * d, 25 * d, -15 * d)
		joints.LeftLowerArm = ang(-5, 0, 0)
		joints.RightUpperLeg = ang(-15 * d, 8 * d, 10 * d)
		joints.LeftUpperLeg = ang(-10 * d, -6 * d, -8 * d)
	elseif phaseKind == "Feint" then
		-- Chambre → fake peak → abort → snap Guard (plus de KF lisibles)
		if a < 0.38 then
			return sampleJoints(s, "Antici", easeOutQuad(a / 0.38), false)
		elseif a < 0.48 then
			-- Hold fake au pic anticipation
			return sampleJoints(s, "Antici", 1, false)
		elseif a < 0.62 then
			local ant = sampleJoints(s, "Antici", 1, false)
			local mid = sampleJoints(s, "Guard", 0.35, false)
			return lerpJoints(ant, mid, easeInCubic((a - 0.48) / 0.14))
		end
		return sampleJoints(s, "Guard", easeOutCubic((a - 0.62) / 0.38), false)
	elseif phaseKind == "Riposte" then
		local e = easeOutCubic(a)
		joints.LowerTorso = ang(6 * e, 0, 0) * CFrame.new(0, 0, -0.04 * e)
		joints.UpperTorso = ang(10 * e, 0, 0)
		joints.Head = ang(-8 * e, 0, 0)
		joints.RightUpperArm = ang(-15 + 5 * e, -5, 5 + shoulderRoll * 0.1)
		joints.RightLowerArm = ang(-5 + 40 * e, 0, 0)
		joints.RightHand = ang(0, 0, 0)
		joints.HiltGrip = CFrame.new(0, 0, -0.25 * e)
		joints.LeftUpperArm = ang(-20, 25, -15)
		joints.LeftLowerArm = ang(-35, 0, 0)
		joints.RightUpperLeg = ang(8 * e, 0, 0)
		joints.LeftUpperLeg = ang(-4 * e, 0, 0)
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
			local alpha = 0.9 + 0.1 * easeInOut((wave + 1) * 0.5)
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
		addKeyframe(seq, dur * 0.12, lerpJoints(idle0, ant025, easeInOut(0.55)), "StartBlend")
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
		addKeyframe(seq, dur * 0.4, lerpJoints(followMid, idleBlend, easeInOut(0.4)), "RecEase")
		addKeyframe(seq, dur * 0.58, idleBlend, "RecSettle")
		addKeyframe(seq, dur * 0.78, lerpJoints(idleBlend, idle0, easeOutQuad(0.55)), "RecSoft")
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
		local alpha = 0.9 + 0.1 * easeInOut((wave + 1) * 0.5)
		return sampleJoints(style, "Guard", alpha, false)
	elseif clipName == "Dodge" then


		if n < 0.4 then
			return sampleJoints(style, "Dodge", easeOutCubic(n / 0.4), false)
		end
		local idle = sampleJoints(style, "Idle", 0.2, false)
		local dodge = sampleJoints(style, "Dodge", 0.85, false)
		return lerpJoints(dodge, idle, easeInOut((n - 0.4) / 0.6))
	elseif clipName == "Dash" then
		if n < 0.45 then
			return sampleJoints(style, "Dash", easeOutCubic(n / 0.45), false)
		end
		local idle = sampleJoints(style, "Idle", 0.1, false)
		local dash = sampleJoints(style, "Dash", 1, false)
		return lerpJoints(dash, idle, easeInOut((n - 0.45) / 0.55))
	elseif clipName == "FocusPush" or clipName == "FocusDash" then
		if n < 0.25 then
			return sampleJoints(style, "Antici", (n / 0.25) * 0.4, false)
		elseif n < 0.55 then
			return sampleJoints(style, "Focus", easeOutQuad((n - 0.25) / 0.3), false)
		end
		return sampleJoints(style, "Follow", 0.35 + (n - 0.55) / 0.45 * 0.25, false)
	elseif clipName == "Stagger" then
		return sampleJoints(style, "Stagger", math.min(1, easeOutCubic(n) * 1.15), false)
	elseif clipName == "Dead" then
		return sampleJoints(style, "Dead", easeInOut(n), false)
	elseif clipName == "Feint" then
		-- Courbe densifiée (fake hold + abort) — sampleJoints Feint gère les seuils
		return sampleJoints(style, "Feint", n, false)
	elseif clipName == "Riposte" then
		if n < 0.18 then
			return sampleJoints(style, "Guard", 0.5, false)
		elseif n < 0.58 then
			return sampleJoints(style, "Riposte", easeOutCubic((n - 0.18) / 0.4), false)
		end
		return sampleJoints(style, "Follow", 0.35 + (n - 0.58) / 0.42 * 0.15, false)
	elseif string.sub(clipName, 1, 7) == "Startup" then
		-- Blend Idle→Antici (évite cut)
		if n < 0.15 then
			local idle = sampleJoints(style, "Idle", 0, heavy)
			local ant = sampleJoints(style, "Antici", 0.2, heavy)
			return lerpJoints(idle, ant, easeInOut(n / 0.15))
		end
		return sampleJoints(style, "Antici", easeInCubic((n - 0.15) / 0.85), heavy)
	elseif string.sub(clipName, 1, 6) == "Active" then
		if style.doubleBeat then
			if n < 0.28 then
				return sampleJoints(style, "Contact", easeOutCubic(n / 0.28), heavy)
			elseif n < 0.42 then
				local hi = sampleJoints(style, "Contact", 0.9, heavy)
				local lo = sampleJoints(style, "Contact", 0.4, heavy)
				return lerpJoints(hi, lo, easeInOut((n - 0.28) / 0.14))
			elseif n < 0.7 then
				return sampleJoints(style, "Contact", 0.4 + easeOutCubic((n - 0.42) / 0.28) * 0.6, heavy)
			end
			return sampleJoints(style, "Follow", easeInOut((n - 0.7) / 0.3) * 0.4, heavy)
		end
		if n < 0.55 then
			return sampleJoints(style, "Contact", easeOutCubic(n / 0.55), heavy)
		end
		return sampleJoints(style, "Follow", easeInOut((n - 0.55) / 0.45) * 0.5, heavy)
	elseif string.sub(clipName, 1, 8) == "Recovery" then
		if n < 0.45 then
			return sampleJoints(style, "Follow", 0.5 + easeOutQuad(n / 0.45) * 0.35, heavy)
		end
		local follow = sampleJoints(style, "Follow", 0.85, heavy)
		local idle = sampleJoints(style, "Idle", 0, heavy)
		return lerpJoints(follow, idle, easeInOut((n - 0.45) / 0.55))
	end
	return sampleJoints(style, "Idle", 0, false)
end

return KeyframeFactory
