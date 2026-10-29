--!strict
-- Bibliothèque des clips procéduraux : résolution (clipId, AnimSet de Voie, arme) → Clip, générés à la
-- demande puis mis en cache (aucun coût au démarrage, aucune génération par frame).
-- Les clips sont des keyframes de poses (CFrame par Motor6D R15) ; ProceduralAnimator les joue.
local Core = require(script.Parent.AnimLibraryCore)
local Styles = require(script.Parent.AnimLibraryStyles)
local CombatClips = require(script.Parent.AnimLibraryCombat)
local EmoteClips = require(script.Parent.AnimLibraryEmotes)
local WeaponData = require(script.Parent.Parent.Config.WeaponData)

export type Pose = Core.Pose
export type Clip = Core.Clip
export type Keyframe = Core.Keyframe
export type Marker = Core.Marker

local AnimLibrary = {}

AnimLibrary.Joints = Core.Joints
AnimLibrary.Layers = Core.Layers
AnimLibrary.sample = Core.sample

local cache: { [string]: Clip | false } = {}

-- Renvoie le clip `clipId` pour la Voie `animSet` et l'arme `weapon` (nil si ce clip n'existe pas
-- pour cette combinaison, ex. « Jump » hors Faucon ou « M1_5 » hors Lames Jumelles).
function AnimLibrary.resolve(clipId: string, animSet: string?, weapon: string?): Clip?
	local style = Styles.get(animSet)
	local w = if weapon and WeaponData.isValid(weapon) then weapon else WeaponData.Default
	local key = style.Id .. "|" .. w .. "|" .. clipId
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

function AnimLibrary.has(clipId: string, animSet: string?, weapon: string?): boolean
	return AnimLibrary.resolve(clipId, animSet, weapon) ~= nil
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
