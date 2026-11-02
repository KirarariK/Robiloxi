--!strict
-- Bibliothèque des clips procéduraux : résolution (clipId, AnimSet de Voie, arme) → Clip, générés à la
-- demande puis mis en cache (aucun coût au démarrage, aucune génération par frame).
-- Les clips sont des keyframes de poses (CFrame par Motor6D R15) ; ProceduralAnimator les joue.
local Core = require(script.Parent.AnimLibraryCore)
local Styles = require(script.Parent.AnimLibraryStyles)
local CombatClips = require(script.Parent.AnimLibraryCombat)
local EmoteClips = require(script.Parent.AnimLibraryEmotes)
local WeaponData = require(script.Parent.Parent.Config.WeaponData)
local Workspace = game:GetService("Workspace")

export type Pose = Core.Pose
export type Clip = Core.Clip
export type Keyframe = Core.Keyframe
export type Marker = Core.Marker

local AnimLibrary = {}

AnimLibrary.Joints = Core.Joints
AnimLibrary.Layers = Core.Layers
AnimLibrary.sample = Core.sample

local cache: { [string]: Clip | false } = {}
local importedCache: { [string]: Clip } = {}
local warned: { [string]: boolean } = {}

local PACK_NAME = "R6 30+ Weapon Models & Animations"

type ImportedSet = {
	Folder: string,
	Sequences: { [string]: string },
}

local IMPORTED_SETS: { [string]: ImportedSet } = {
	Single = {
		Folder = "Sabre Animations",
		Sequences = {
			IdleOneHand = "One-hand Idle",
			IdleTwoHand = "Two-hand Idle",
			Run = "Sprint",
			Block = "Block",
			Parry = "Parry1",
		},
	},
	Dual = {
		Folder = "Dagger #2 Animations",
		Sequences = {
			Idle = "Idle",
			Block = "Block",
		},
	},
	Staff = {
		Folder = "[NEW] Spear Animations",
		Sequences = {
			Idle = "Idle",
			Run = "Run",
			Block = "Block",
			Parry = "Parry Attempt",
			Heavy = "Heavy",
		},
	},
}

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[EtherBlades] " .. message)
end

local function sequenceName(clipId: string, style: Styles.Style, weapon: string): (ImportedSet?, string?)
	local set = IMPORTED_SETS[weapon]
	if not set then
		return nil, nil
	end
	if clipId == "Idle" then
		local idleName = if weapon == "Single" then (if style.TwoHanded then "IdleTwoHand" else "IdleOneHand") else "Idle"
		return set, set.Sequences[idleName]
	elseif clipId == "Run" then
		return set, set.Sequences.Run
	elseif clipId == "Block" then
		return set, set.Sequences.Block
	elseif clipId == "Parry" then
		return set, set.Sequences.Parry
	elseif clipId == "M2_Strike" then
		return set, set.Sequences.Heavy
	end

	local index, suffix = string.match(clipId, "^M1_(%d)(.*)$")
	local number = if index then tonumber(index) else nil
	if number and number >= 1 and number <= 4 and (suffix == "" or suffix == "_F" or suffix == "_S" or suffix == "_B") then
		return set, "M" .. tostring(number)
	end
	return nil, nil
end

local function findSequence(set: ImportedSet, name: string): KeyframeSequence?
	local pack = Workspace:FindFirstChild(PACK_NAME)
	if not pack then
		warnOnce("pack", `Pack d'animations R6 introuvable dans Workspace ; animations procédurales utilisées.`)
		return nil
	end
	local sourceWorkspace = pack:FindFirstChild("Workspace")
	local animations = sourceWorkspace and sourceWorkspace:FindFirstChild("Animations")
	local group = animations and animations:FindFirstChild(set.Folder)
	local saves = group and group:FindFirstChild("AnimSaves")
	local sequence = saves and saves:FindFirstChild(name)
	if sequence and sequence:IsA("KeyframeSequence") then
		return sequence
	end
	warnOnce(set.Folder .. "/" .. name, `Séquence R6 manquante ({set.Folder}/AnimSaves/{name}) ; animation procédurale utilisée.`)
	return nil
end

local function importedClip(clipId: string, style: Styles.Style, weapon: string, key: string): Clip?
	local set, name = sequenceName(clipId, style, weapon)
	if not set or not name then
		return nil
	end
	local cached = importedCache[key]
	if cached then
		return cached
	end
	local sequence = findSequence(set, name)
	if not sequence then
		return nil
	end

	local fallback = CombatClips.build(clipId, style, weapon)
	local loopingBase = clipId == "Idle" or clipId == "Run"
	local durationOverride = if loopingBase or clipId == "Block" then nil else if fallback then fallback.Duration else nil
	local clip = Core.fromKeyframeSequence(clipId, sequence, {
		Looped = loopingBase,
		Layer = if loopingBase then Core.Layers.Base else Core.Layers.Action,
		FadeIn = if loopingBase then 0.18 else 0.04,
		FadeOut = if loopingBase then 0.18 else 0.1,
	}, durationOverride)
	if not clip then
		warnOnce(set.Folder .. "/" .. name, `Séquence R6 invalide ({set.Folder}/AnimSaves/{name}) ; animation procédurale utilisée.`)
		return nil
	end
	importedCache[key] = clip
	return clip
end

-- Renvoie le clip `clipId` pour la Voie `animSet` et l'arme `weapon` (nil si ce clip n'existe pas
-- pour cette combinaison, ex. « Jump » hors Faucon ou « M1_5 » hors Lames Jumelles).
function AnimLibrary.resolve(clipId: string, animSet: string?, weapon: string?, useImported: boolean?): Clip?
	local style = Styles.get(animSet)
	local w = if weapon and WeaponData.isValid(weapon) then weapon else WeaponData.Default
	local key = style.Id .. "|" .. w .. "|" .. clipId
	if useImported then
		local imported = importedClip(clipId, style, w, key)
		if imported then
			return imported
		end
	end
	local hit = cache[key]
	if hit ~= nil then
		return if hit == false then nil else hit
	end
	local clip = CombatClips.build(clipId, style, w) or EmoteClips.build(clipId, style, w)
	if clip == nil and string.find(clipId, "^M1_%d_") then
		-- variante de direction absente : retombe sur le coup de base
		clip = CombatClips.build(string.sub(clipId, 1, 4), style, w)
	end
	cache[key] = clip or false
	return clip
end

function AnimLibrary.has(clipId: string, animSet: string?, weapon: string?, useImported: boolean?): boolean
	return AnimLibrary.resolve(clipId, animSet, weapon, useImported) ~= nil
end

-- Liste indicative des clips disponibles (outils de test, aperçus).
function AnimLibrary.clipIds(weapon: string?): { string }
	local w = WeaponData.get(weapon or WeaponData.Default)
	local combo = if w then w.ComboLength else 4
	local out: { string } = {
		"Idle",
		"Run",
		"Jump",
		"Ignite",
		"M1_Air",
		"Counter",
		"M2_Charge",
		"M2_Strike",
		"Block",
		"BlockHit",
		"Parry",
		"Dodge_F",
		"Dodge_B",
		"Dodge_L",
		"Dodge_R",
		"Stunned",
		"Flinch",
		"GuardBroken",
		"Defeated",
		"SaberLock",
		"Intro",
		"Finisher",
		"Finisher_Victim",
	}
	for i = 1, combo do
		for _, sfx in { "", "_F", "_S", "_B" } do
			table.insert(out, "M1_" .. i .. sfx)
		end
	end
	for _, id in EmoteClips.ids() do
		table.insert(out, id)
	end
	return out
end

return table.freeze(AnimLibrary)
