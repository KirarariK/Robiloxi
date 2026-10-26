--!strict
--[[
	Construit des KeyframeSequence R15 (+ HiltGrip) à partir des StyleParams.
	Plusieurs keyframes par swing : anticipation → contact → follow-through.
	Sources : docs Pose / KeyframeSequence / KeyframeSequenceProvider.
]]

local AnimationSets = require(script.Parent:WaitForChild("AnimationSets"))

export type JointMap = { [string]: CFrame }

local KeyframeFactory = {}

local function ang(xDeg: number, yDeg: number, zDeg: number): CFrame
	return CFrame.Angles(math.rad(xDeg), math.rad(yDeg), math.rad(zDeg))
end

--[[
	Pose hierarchy R15 + HiltGrip (Motor6D SaberMotor RightHand→HiltGrip).
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

	-- Lame EnergySaber (si Motor présent)
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

	local pitch = lerpNumber(0, -90, plane) -- vertical component
	local yaw = lerpNumber(-110, -20, 1 - plane) -- horizontal component
	local roll = lerpNumber(25, -10, plane)

	local joints: JointMap = {}

	if phaseKind == "Idle" then
		local bob = math.sin(a * math.pi * 2) * 0.04
		joints.LowerTorso = ang(2 + lean * 20, lean * 15, 0)
		joints.UpperTorso = ang(-3 + bob * 10, lean * 10, bob * 8)
		joints.Head = ang(-4, lean * -8, 0)
		joints.RightUpperArm = ang(-25 + bob * 6, -15, 20 + lean * 20)
		joints.RightLowerArm = ang(-35, 10, 0)
		joints.RightHand = ang(0, 0, 8)
		joints.HiltGrip = ang(bob * 8, bob * 6, 0)
		joints.LeftUpperArm = ang(-15, 20, -off * 25)
		joints.LeftLowerArm = ang(-40, -10, 0)
	elseif phaseKind == "Guard" then
		joints.LowerTorso = ang(4, -twist * 20, 0)
		joints.UpperTorso = ang(-6, twist * 25, 0)
		joints.Head = ang(-8, -twist * 10, 0)
		joints.RightUpperArm = ang(s.guardPitch * 70 - 20, -55, 35)
		joints.RightLowerArm = ang(-70, 25, 0)
		joints.RightHand = ang(10, 0, -15)
		joints.HiltGrip = ang(-25, 20, -10)
		joints.LeftUpperArm = ang(-40, 50, -off * 40)
		joints.LeftLowerArm = ang(-55, 0, 0)
	elseif phaseKind == "Antici" then
		-- Chambre haute / arrière selon planeBias
		local chamberPitch = -55 - ant * 40 * plane
		local chamberYaw = -40 - ant * 35 * (1 - plane)
		joints.LowerTorso = ang(-4 * ant, -twist * 30 * ant, 0)
		joints.UpperTorso = ang(-8 * ant, -twist * 40 * ant, 5 * ant)
		joints.Head = ang(6 * ant, twist * 15 * ant, 0)
		joints.RightUpperArm = ang(chamberPitch, chamberYaw, 25 + ant * 15)
		joints.RightLowerArm = ang(-20 - ant * 25, 15, 0)
		joints.RightHand = ang(-10, -15, 10)
		joints.HiltGrip = ang(-40 * ant, -30 * ant, 15 * ant)
		joints.LeftUpperArm = ang(-25, 30 + off * 20, -off * 30)
		joints.LeftLowerArm = ang(-45, 0, 0)
	elseif phaseKind == "Contact" then
		-- Pic de coupe
		local pMul = a -- 0→1 through contact window
		local swingPitch = pitch * arc * 0.4 + 25 * arc * pMul
		local swingYaw = yaw * arc * 0.35 + 90 * arc * (1 - plane) * pMul * 0.5
		local swingRoll = roll * arc * 0.3
		joints.LowerTorso = ang(6 * arc, twist * 45 * pMul, 0)
		joints.UpperTorso = ang(4 * arc, twist * 55 * pMul, -8 * pMul)
		joints.Head = ang(-5, -twist * 20 * pMul, 0)
		joints.RightUpperArm = ang(swingPitch, swingYaw, swingRoll - 15)
		joints.RightLowerArm = ang(-15 + 40 * pMul, -20, 0)
		joints.RightHand = ang(15 * pMul, 25 * pMul, -20)
		joints.HiltGrip = ang(30 * arc * pMul, 70 * arc * pMul * (1 - plane * 0.5), -15)
		joints.LeftUpperArm = ang(-30 - off * 20, 40, -off * 45 * pMul)
		joints.LeftLowerArm = ang(-50, 10, 0)
	elseif phaseKind == "Follow" then
		local f = s.followThrough
		joints.LowerTorso = ang(3 * f, twist * 25 * f * (1 - a), 0)
		joints.UpperTorso = ang(2, twist * 20 * (1 - a), -4 * (1 - a))
		joints.Head = ang(-3, 0, 0)
		joints.RightUpperArm = ang(15 * f * (1 - a) - 10 * a, 40 * f * (1 - a) + 10 * a, -10)
		joints.RightLowerArm = ang(-25, 5, 0)
		joints.RightHand = ang(5, 10, 0)
		joints.HiltGrip = ang(8 * f * (1 - a), 20 * f * (1 - a), 0)
		joints.LeftUpperArm = ang(-20, 25, -off * 20)
		joints.LeftLowerArm = ang(-40, 0, 0)
	elseif phaseKind == "Dodge" then
		joints.LowerTorso = ang(-8, lean * 80, lean * 40)
		joints.UpperTorso = ang(-10, lean * 60, lean * 30)
		joints.Head = ang(5, -lean * 40, 0)
		joints.RightUpperArm = ang(-50, 60, -40)
		joints.RightLowerArm = ang(-40, 0, 0)
		joints.HiltGrip = ang(-20, 40, -25)
		joints.LeftUpperArm = ang(-40, -30, 20)
		joints.LeftLowerArm = ang(-35, 0, 0)
	elseif phaseKind == "Dash" then
		joints.LowerTorso = ang(8, 0, 0)
		joints.UpperTorso = ang(12, 0, 0)
		joints.Head = ang(-10, 0, 0)
		joints.RightUpperArm = ang(10, -25, 10)
		joints.RightLowerArm = ang(-30, 0, 0)
		joints.HiltGrip = ang(5, -15, 0)
		joints.LeftUpperArm = ang(5, 20, -10)
		joints.LeftLowerArm = ang(-25, 0, 0)
	elseif phaseKind == "Focus" then
		joints.LowerTorso = ang(10, 0, 0)
		joints.UpperTorso = ang(15, 0, 0)
		joints.Head = ang(-12, 0, 0)
		joints.RightUpperArm = ang(-20, 0, 0)
		joints.RightLowerArm = ang(-10, 0, 0)
		joints.HiltGrip = ang(0, 0, 0) * CFrame.new(0, 0, -0.15)
		joints.LeftUpperArm = ang(-25, 40, -off * 50)
		joints.LeftLowerArm = ang(-30, 0, 0)
	elseif phaseKind == "Stagger" then
		joints.LowerTorso = ang(-12, -25, 15)
		joints.UpperTorso = ang(-15, -30, 20)
		joints.Head = ang(20, 15, 10)
		joints.RightUpperArm = ang(40, -40, 35)
		joints.RightLowerArm = ang(-20, 0, 0)
		joints.HiltGrip = ang(30, -20, 25)
		joints.LeftUpperArm = ang(20, 30, -20)
		joints.LeftLowerArm = ang(-15, 0, 0)
	elseif phaseKind == "Dead" then
		joints.LowerTorso = ang(-25, 10, 20)
		joints.UpperTorso = ang(-30, 15, 25)
		joints.Head = ang(35, 0, 15)
		joints.RightUpperArm = ang(70, -20, 40)
		joints.RightLowerArm = ang(-10, 0, 0)
		joints.HiltGrip = ang(50, 0, 30)
		joints.LeftUpperArm = ang(40, 25, -15)
		joints.LeftLowerArm = ang(-5, 0, 0)
	elseif phaseKind == "Feint" then
		-- Anticipation courte puis snap garde
		local early = a < 0.45
		if early then
			return sampleJoints(s, "Antici", a / 0.45, false)
		end
		return sampleJoints(s, "Guard", (a - 0.45) / 0.55, false)
	elseif phaseKind == "Riposte" then
		-- Estoc : bras avant linéaire
		joints.LowerTorso = ang(6 * a, 0, 0)
		joints.UpperTorso = ang(10 * a, 0, 0)
		joints.Head = ang(-8 * a, 0, 0)
		joints.RightUpperArm = ang(-15 + 5 * a, -5, 5)
		joints.RightLowerArm = ang(-5 + 40 * a, 0, 0)
		joints.RightHand = ang(0, 0, 0)
		joints.HiltGrip = CFrame.new(0, 0, -0.25 * a)
		joints.LeftUpperArm = ang(-20, 25, -15)
		joints.LeftLowerArm = ang(-35, 0, 0)
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
		-- Boucle douce 1.2s / tempo
		local dur = 1.2 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false), "Idle0")
		addKeyframe(seq, dur * 0.25, sampleJoints(style, "Idle", 0.25, false))
		addKeyframe(seq, dur * 0.5, sampleJoints(style, "Idle", 0.5, false), "IdleMid")
		addKeyframe(seq, dur * 0.75, sampleJoints(style, "Idle", 0.75, false))
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 1, false), "IdleEnd")
		return seq
	end

	if clipName == "Guard" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action, true)
		local dur = 0.9 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Guard", 0, false), "GuardIn")
		addKeyframe(seq, dur * 0.5, sampleJoints(style, "Guard", 0.5, false))
		addKeyframe(seq, dur, sampleJoints(style, "Guard", 1, false), "GuardHold")
		return seq
	end

	if clipName == "Dodge" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Movement, false)
		local dur = 0.28 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false))
		addKeyframe(seq, dur * 0.35, sampleJoints(style, "Dodge", 0.5, false), "DodgePeak")
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 0.2, false), "DodgeOut")
		return seq
	end

	if clipName == "Dash" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Movement, false)
		local dur = 0.22 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false))
		addKeyframe(seq, dur * 0.4, sampleJoints(style, "Dash", 1, false), "DashPeak")
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 0.1, false))
		return seq
	end

	if clipName == "FocusPush" or clipName == "FocusDash" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action2, false)
		local dur = (if clipName == "FocusPush" then 0.35 else 0.28) / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Antici", 0.4, false))
		addKeyframe(seq, dur * 0.45, sampleJoints(style, "Focus", 1, false), "FocusPeak")
		addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.6, false))
		return seq
	end

	if clipName == "Stagger" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action4, false)
		local dur = 0.45 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false))
		addKeyframe(seq, dur * 0.3, sampleJoints(style, "Stagger", 1, false), "StaggerHit")
		addKeyframe(seq, dur, sampleJoints(style, "Stagger", 0.7, false))
		return seq
	end

	if clipName == "Dead" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action4, false)
		local dur = 0.7 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Stagger", 0.5, false))
		addKeyframe(seq, dur * 0.5, sampleJoints(style, "Dead", 0.8, false), "KO")
		addKeyframe(seq, dur, sampleJoints(style, "Dead", 1, false))
		return seq
	end

	if clipName == "Feint" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action2, false)
		local dur = 0.32 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Feint", 0, false))
		addKeyframe(seq, dur * 0.4, sampleJoints(style, "Feint", 0.4, false), "FeintFake")
		addKeyframe(seq, dur, sampleJoints(style, "Feint", 1, false), "FeintGuard")
		return seq
	end

	if clipName == "Riposte" then
		local seq = emptySequence(seqName, Enum.AnimationPriority.Action3, false)
		local dur = 0.3 / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Guard", 0.5, false))
		addKeyframe(seq, dur * 0.25, sampleJoints(style, "Riposte", 0.3, false), "RiposteWind")
		addKeyframe(seq, dur * 0.55, sampleJoints(style, "Riposte", 1, false), "RiposteHit")
		addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.5, false))
		return seq
	end

	-- Startup / Active / Recovery (Light|Heavy)
	local isStartup = string.sub(clipName, 1, 7) == "Startup"
	local isActive = string.sub(clipName, 1, 6) == "Active"
	local isRecovery = string.sub(clipName, 1, 8) == "Recovery"

	if isStartup then
		local seq = emptySequence(seqName, priority, false)
		local dur = (if heavy then 0.38 else 0.18) / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, heavy), "StartFromIdle")
		addKeyframe(seq, dur * 0.35, sampleJoints(style, "Antici", 0.45, heavy), "AnticiMid")
		addKeyframe(seq, dur * 0.7, sampleJoints(style, "Antici", 0.85, heavy), "AnticiPeak")
		addKeyframe(seq, dur, sampleJoints(style, "Antici", 1.0, heavy), "AnticiReady")
		return seq
	end

	if isActive then
		local seq = emptySequence(seqName, priority, false)
		local dur = (if heavy then 0.16 else 0.12) / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Antici", 1.0, heavy), "SwingRelease")
		if style.doubleBeat then
			-- Rafale : deux pics de contact
			addKeyframe(seq, dur * 0.28, sampleJoints(style, "Contact", 0.85, heavy), "Beat1")
			addKeyframe(seq, dur * 0.45, sampleJoints(style, "Contact", 0.35, heavy), "Valley")
			addKeyframe(seq, dur * 0.7, sampleJoints(style, "Contact", 1.0, heavy), "Beat2")
			addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.25, heavy), "ActiveEnd")
		else
			addKeyframe(seq, dur * 0.25, sampleJoints(style, "Contact", 0.4, heavy), "ArcIn")
			addKeyframe(seq, dur * 0.55, sampleJoints(style, "Contact", 1.0, heavy), "Impact")
			addKeyframe(seq, dur * 0.8, sampleJoints(style, "Follow", 0.2, heavy), "Through")
			addKeyframe(seq, dur, sampleJoints(style, "Follow", 0.45, heavy), "ActiveEnd")
		end
		return seq
	end

	if isRecovery then
		local seq = emptySequence(seqName, priority, false)
		local dur = (if heavy then 0.48 else 0.28) / tempo
		addKeyframe(seq, 0, sampleJoints(style, "Follow", 0.5, heavy), "RecStart")
		addKeyframe(seq, dur * 0.4, sampleJoints(style, "Follow", 0.85, heavy), "RecMid")
		addKeyframe(seq, dur * 0.75, sampleJoints(style, "Idle", 0.3, heavy), "RecSettle")
		addKeyframe(seq, dur, sampleJoints(style, "Idle", 0, heavy), "RecIdle")
		return seq
	end

	-- Fallback idle
	local seq = emptySequence(seqName, Enum.AnimationPriority.Idle, true)
	addKeyframe(seq, 0, sampleJoints(style, "Idle", 0, false))
	addKeyframe(seq, 0.5, sampleJoints(style, "Idle", 0.5, false))
	return seq
end

--[[
	Expose sample pour ProceduralTrackPlayer (même courbes sans Animator).
]]
function KeyframeFactory.samplePose(
	setDef: AnimationSets.AnimationSetDef,
	clipName: AnimationSets.ClipName,
	normalizedTime: number
): JointMap
	local seq = KeyframeFactory.buildClip(setDef, clipName)
	local keyframes = seq:GetKeyframes()
	table.sort(keyframes, function(a, b)
		return a.Time < b.Time
	end)
	local length = 0
	for _, kf in keyframes do
		if kf.Time > length then
			length = kf.Time
		end
	end
	if length <= 0 then
		seq:Destroy()
		return sampleJoints(setDef.style, "Idle", 0, false)
	end
	local t = math.clamp(normalizedTime, 0, 1) * length
	-- Trouver bracketing — pour procedural on re-sample phase approx
	seq:Destroy()

	local heavy = string.find(clipName, "Heavy") ~= nil
	local style = setDef.style
	if clipName == "Idle" then
		return sampleJoints(style, "Idle", normalizedTime, false)
	elseif clipName == "Guard" then
		return sampleJoints(style, "Guard", normalizedTime, false)
	elseif clipName == "Dodge" then
		return sampleJoints(style, "Dodge", normalizedTime, false)
	elseif clipName == "Dash" then
		return sampleJoints(style, "Dash", normalizedTime, false)
	elseif clipName == "FocusPush" or clipName == "FocusDash" then
		if normalizedTime < 0.45 then
			return sampleJoints(style, "Antici", normalizedTime / 0.45 * 0.4, false)
		elseif normalizedTime < 0.7 then
			return sampleJoints(style, "Focus", 1, false)
		end
		return sampleJoints(style, "Follow", 0.6, false)
	elseif clipName == "Stagger" then
		return sampleJoints(style, "Stagger", math.min(1, normalizedTime * 1.2), false)
	elseif clipName == "Dead" then
		return sampleJoints(style, "Dead", normalizedTime, false)
	elseif clipName == "Feint" then
		return sampleJoints(style, "Feint", normalizedTime, false)
	elseif clipName == "Riposte" then
		return sampleJoints(style, "Riposte", normalizedTime, false)
	elseif string.sub(clipName, 1, 7) == "Startup" then
		return sampleJoints(style, "Antici", normalizedTime, heavy)
	elseif string.sub(clipName, 1, 6) == "Active" then
		if style.doubleBeat then
			if normalizedTime < 0.35 then
				return sampleJoints(style, "Contact", normalizedTime / 0.35, heavy)
			elseif normalizedTime < 0.5 then
				return sampleJoints(style, "Contact", 0.35, heavy)
			elseif normalizedTime < 0.75 then
				return sampleJoints(style, "Contact", (normalizedTime - 0.5) / 0.25, heavy)
			end
			return sampleJoints(style, "Follow", 0.3, heavy)
		end
		if normalizedTime < 0.55 then
			return sampleJoints(style, "Contact", normalizedTime / 0.55, heavy)
		end
		return sampleJoints(style, "Follow", (normalizedTime - 0.55) / 0.45 * 0.5, heavy)
	elseif string.sub(clipName, 1, 8) == "Recovery" then
		if normalizedTime < 0.6 then
			return sampleJoints(style, "Follow", 0.5 + normalizedTime * 0.5, heavy)
		end
		return sampleJoints(style, "Idle", (normalizedTime - 0.6) / 0.4, heavy)
	end
	return sampleJoints(style, "Idle", 0, false)
end

return KeyframeFactory
