--!strict
-- ProceduralAnimator : lecture des clips procéduraux (AnimLibrary) sur les Motor6D d'un personnage.
-- Les poses sont écrites dans Motor6D.Transform à PreSimulation, c'est-à-dire APRÈS l'Animator :
-- la pose de l'Animator (marche, saut…) sert de base et chaque clip actif la remplace, pondéré par
-- son fondu, couche par couche (0 = posture, 1 = actions, 2 = réactions, 3 = emotes / cinématiques).
-- Compatible R15 (15 articulations) et R6 (racine, cou, épaules, hanches, repères convertis).
-- Aucune table n'est allouée par frame : chaque piste réutilise sa table de pose.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local AnimLibrary = require(Shared.Combat.AnimLibrary)
local Config = require(Shared.Combat.CombatConfig)

type Clip = AnimLibrary.Clip
type Pose = AnimLibrary.Pose

export type PlayOpts = {
	Looped: boolean?,
	Speed: number?,
	Weight: number?, -- poids maximal (1 par défaut)
	Layer: number?, -- remplace la couche du clip
	FadeIn: number?,
	FadeOut: number?,
	AnimSet: string?, -- Voie (sinon attribut CombatForm du personnage)
	Weapon: string?, -- arme (sinon attribut CombatWeapon du personnage)
	OnMarker: ((name: string) -> ())?, -- marqueurs du clip (« Impact », « Swing », « Ignite »…)
}

type Joint = {
	Name: string,
	Motor: Motor6D,
	Rot: CFrame?, -- rotation de C0 (R6) : les poses sont converties dans le repère du moteur
	InvRot: CFrame?,
	Last: CFrame,
	Written: boolean,
}

type Track = {
	Id: number,
	Clip: Clip,
	Time: number,
	Speed: number,
	Looped: boolean,
	Weight: number,
	Target: number,
	FadeIn: number,
	FadeOut: number,
	Stopping: boolean,
	Layer: number,
	Pose: Pose,
	MarkerIdx: number,
	OnMarker: ((string) -> ())?,
}

type Rig = {
	Model: Model,
	Joints: { Joint },
	Tracks: { Track },
	TimeScale: number,
	FreezeUntil: number,
	Active: boolean, -- au moins une articulation écrite à la frame précédente
	Conns: { RBXScriptConnection },
}

local ProceduralAnimator = {}

-- Articulations R15 : nom logique → (pièce enfant, nom du Motor6D)
local R15: { [string]: { string } } = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	RightWrist = { "RightHand", "RightWrist" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
	LeftWrist = { "LeftHand", "LeftWrist" },
	RightHip = { "RightUpperLeg", "RightHip" },
	RightKnee = { "RightLowerLeg", "RightKnee" },
	RightAnkle = { "RightFoot", "RightAnkle" },
	LeftHip = { "LeftUpperLeg", "LeftHip" },
	LeftKnee = { "LeftLowerLeg", "LeftKnee" },
	LeftAnkle = { "LeftFoot", "LeftAnkle" },
}

-- Articulations R6 : nom logique → (pièce parente, nom du Motor6D)
local R6: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	RightShoulder = { "Torso", "Right Shoulder" },
	LeftShoulder = { "Torso", "Left Shoulder" },
	RightHip = { "Torso", "Right Hip" },
	LeftHip = { "Torso", "Left Hip" },
}

local rigs: { [Model]: Rig } = {}
local nextId = 0
local globalScale = 1
local globalScaleUntil = 0

--------------------------------------------------------------------------------
-- Rig

local function findMotor(model: Model, partName: string, motorName: string): Motor6D?
	local part = model:FindFirstChild(partName)
	if not part then
		return nil
	end
	local m = part:FindFirstChild(motorName)
	if m and m:IsA("Motor6D") then
		return m
	end
	return nil
end

local function removeRig(model: Model)
	local rig = rigs[model]
	if not rig then
		return
	end
	rigs[model] = nil
	for _, c in rig.Conns do
		c:Disconnect()
	end
	for _, j in rig.Joints do
		if j.Written and j.Motor.Parent then
			j.Motor.Transform = CFrame.identity
		end
	end
	table.clear(rig.Tracks)
end

local function buildJoints(model: Model): { Joint }
	local hum = model:FindFirstChildOfClass("Humanoid")
	local isR6 = hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6
	local map = if isR6 then R6 else R15
	local out: { Joint } = {}
	for name, spec in map do
		local motor = findMotor(model, spec[1], spec[2])
		if motor then
			local rot = motor.C0.Rotation
			local trivial = rot:FuzzyEq(CFrame.identity, 1e-3)
			table.insert(out, {
				Name = name,
				Motor = motor,
				Rot = if trivial then nil else rot,
				InvRot = if trivial then nil else rot:Inverse(),
				Last = CFrame.identity,
				Written = false,
			})
		end
	end
	return out
end

local function getRig(model: Model): Rig?
	local rig = rigs[model]
	if rig then
		-- personnage reconstruit (moteurs remplacés) : on relit les articulations
		local stale = #rig.Joints == 0
		for _, j in rig.Joints do
			if j.Motor.Parent == nil then
				stale = true
				break
			end
		end
		if stale then
			rig.Joints = buildJoints(model)
		end
		return rig
	end
	local joints = buildJoints(model)
	if #joints == 0 then
		return nil
	end
	local r: Rig = {
		Model = model,
		Joints = joints,
		Tracks = {},
		TimeScale = 1,
		FreezeUntil = 0,
		Active = false,
		Conns = {},
	}
	table.insert(r.Conns, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(game) then
			removeRig(model)
		end
	end))
	table.insert(r.Conns, model.Destroying:Connect(function()
		removeRig(model)
	end))
	rigs[model] = r
	return r
end

--------------------------------------------------------------------------------
-- Pistes

local function stopTrack(t: Track)
	t.Stopping = true
	if t.FadeOut <= 0 then
		t.Weight = 0
	end
end

local function sortTracks(rig: Rig)
	table.sort(rig.Tracks, function(a, b)
		if a.Layer ~= b.Layer then
			return a.Layer < b.Layer
		end
		return a.Id < b.Id
	end)
end

local function fireMarkers(t: Track, upTo: number)
	local markers = t.Clip.Markers
	local cb = t.OnMarker
	while t.MarkerIdx <= #markers and markers[t.MarkerIdx].Time <= upTo do
		local name = markers[t.MarkerIdx].Name
		t.MarkerIdx += 1
		if cb then
			task.spawn(cb, name)
		end
	end
end

-- Joue `clipId` sur `character`. Renvoie une fonction d'arrêt (fondu de sortie du clip).
function ProceduralAnimator.play(character: Model, clipId: string, opts: PlayOpts?): () -> ()
	local o: PlayOpts = opts or {}
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return function() end
	end
	local animSet = o.AnimSet or character:GetAttribute(Config.Attr.Form)
	local weapon = o.Weapon or character:GetAttribute(Config.Attr.Weapon)
	local clip = AnimLibrary.resolve(clipId, if type(animSet) == "string" then animSet else nil, if type(weapon) == "string" then weapon else nil)
	if not clip then
		return function() end
	end
	local rig = getRig(character)
	if not rig then
		return function() end
	end
	local layer = o.Layer or clip.Layer
	-- une seule piste active par couche : les précédentes s'effacent en fondu
	for _, t in rig.Tracks do
		if t.Layer == layer and not t.Stopping then
			stopTrack(t)
		end
	end
	nextId += 1
	local speed = o.Speed or 1
	if speed ~= speed or speed <= 0 then
		speed = 1
	end
	local fadeIn = o.FadeIn or clip.FadeIn
	local track: Track = {
		Id = nextId,
		Clip = clip,
		Time = 0,
		Speed = speed,
		Looped = if o.Looped ~= nil then o.Looped else clip.Looped,
		Weight = if fadeIn <= 0 then 1 else 0,
		Target = math.clamp(o.Weight or 1, 0, 1),
		FadeIn = fadeIn,
		FadeOut = o.FadeOut or clip.FadeOut,
		Stopping = false,
		Layer = layer,
		Pose = {},
		MarkerIdx = 1,
		OnMarker = o.OnMarker,
	}
	if track.Weight > track.Target then
		track.Weight = track.Target
	end
	AnimLibrary.sample(clip, 0, track.Pose)
	table.insert(rig.Tracks, track)
	sortTracks(rig)
	return function()
		stopTrack(track)
	end
end

-- Arrête les pistes d'un personnage (toutes, ou celles d'une couche).
function ProceduralAnimator.stopAll(character: Model, layer: number?)
	local rig = rigs[character]
	if not rig then
		return
	end
	for _, t in rig.Tracks do
		if layer == nil or t.Layer == layer then
			stopTrack(t)
		end
	end
end

-- Arrête les pistes jouant `clipId`.
function ProceduralAnimator.stop(character: Model, clipId: string)
	local rig = rigs[character]
	if not rig then
		return
	end
	for _, t in rig.Tracks do
		if t.Clip.Id == clipId then
			stopTrack(t)
		end
	end
end

function ProceduralAnimator.isPlaying(character: Model, clipId: string): boolean
	local rig = rigs[character]
	if not rig then
		return false
	end
	for _, t in rig.Tracks do
		if t.Clip.Id == clipId and not t.Stopping then
			return true
		end
	end
	return false
end

-- Clip actif (non arrêté) le plus récent d'une couche.
function ProceduralAnimator.current(character: Model, layer: number): string?
	local rig = rigs[character]
	if not rig then
		return nil
	end
	local best: Track? = nil
	for _, t in rig.Tracks do
		if t.Layer == layer and not t.Stopping and (best == nil or t.Id > (best :: Track).Id) then
			best = t
		end
	end
	return if best then best.Clip.Id else nil
end

function ProceduralAnimator.has(character: Model, clipId: string): boolean
	local animSet = character:GetAttribute(Config.Attr.Form)
	local weapon = character:GetAttribute(Config.Attr.Weapon)
	return AnimLibrary.has(clipId, if type(animSet) == "string" then animSet else nil, if type(weapon) == "string" then weapon else nil)
end

-- Arrêt sur image (hit stop) d'un personnage pendant `seconds`.
function ProceduralAnimator.hitStop(character: Model, seconds: number)
	local rig = rigs[character]
	if rig then
		rig.FreezeUntil = math.max(rig.FreezeUntil, os.clock() + seconds)
	end
end

-- Vitesse d'un personnage (ralenti local).
function ProceduralAnimator.setTimeScale(character: Model, scale: number)
	local rig = rigs[character]
	if rig then
		rig.TimeScale = math.max(0, scale)
	end
end

-- Ralenti global de toutes les animations procédurales pendant `seconds` (Saber Lock, exécution).
function ProceduralAnimator.slowMotion(scale: number, seconds: number)
	globalScale = math.clamp(scale, 0.05, 1)
	globalScaleUntil = os.clock() + seconds
end

function ProceduralAnimator.timeScale(): number
	return if os.clock() < globalScaleUntil then globalScale else 1
end

-- Oublie un personnage (remet ses articulations au repos).
function ProceduralAnimator.release(character: Model)
	removeRig(character)
end

--------------------------------------------------------------------------------
-- Boucle

local function stepRig(rig: Rig, dt: number, now: number)
	local tracks = rig.Tracks
	local scale = if now < rig.FreezeUntil then 0 else rig.TimeScale * ProceduralAnimator.timeScale()
	-- avance des pistes et fondus
	local i = 1
	while i <= #tracks do
		local t = tracks[i]
		local clip = t.Clip
		t.Time += dt * scale * t.Speed
		if t.Time >= clip.Duration then
			if t.Looped then
				fireMarkers(t, clip.Duration)
				t.Time %= clip.Duration
				t.MarkerIdx = 1
			else
				t.Time = clip.Duration
				if not t.Stopping then
					stopTrack(t)
				end
			end
		end
		fireMarkers(t, t.Time)
		if t.Stopping then
			t.Weight = if t.FadeOut > 0 then t.Weight - dt / t.FadeOut else 0
		elseif t.Weight < t.Target then
			t.Weight = if t.FadeIn > 0 then math.min(t.Target, t.Weight + dt / t.FadeIn) else t.Target
		end
		if t.Weight <= 0 and t.Stopping then
			table.remove(tracks, i)
		else
			AnimLibrary.sample(clip, t.Time, t.Pose)
			i += 1
		end
	end
	-- composition par articulation
	local any = false
	for _, j in rig.Joints do
		local motor = j.Motor
		local cur = motor.Transform
		-- si l'Animator n'a pas réécrit l'articulation, la valeur courante est la nôtre : base = repos
		local base = if j.Written and cur == j.Last then CFrame.identity else cur
		local result = base
		local touched = false
		local name = j.Name
		for _, t in tracks do
			local p = t.Pose[name]
			if p and t.Weight > 0 then
				local target = p
				local rot = j.Rot
				if rot then
					target = (j.InvRot :: CFrame) * p * rot
				end
				result = if t.Weight >= 1 then target else result:Lerp(target, t.Weight)
				touched = true
			end
		end
		if touched then
			motor.Transform = result
			j.Last = result
			j.Written = true
			any = true
		elseif j.Written then
			motor.Transform = base
			j.Written = false
		end
	end
	rig.Active = any
end

RunService.PreSimulation:Connect(function(dt: number)
	local now = os.clock()
	for model, rig in rigs do
		if model.Parent == nil then
			removeRig(model)
		elseif #rig.Tracks > 0 or rig.Active then
			stepRig(rig, dt, now)
		end
	end
end)

return ProceduralAnimator
