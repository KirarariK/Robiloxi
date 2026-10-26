--!strict
--[[
	Catalogue des ≥20 sets d'animations Blade Concord (28 au Pass fluidité).
	Un set = Idle combat + Startup + Active + Recovery (+ Guard).
	Sélection runtime : forme × rareté, ou set nommé (riposte, focus, KO…).
]]

export type ClipName =
	"Idle"
	| "StartupLight"
	| "ActiveLight"
	| "RecoveryLight"
	| "StartupHeavy"
	| "ActiveHeavy"
	| "RecoveryHeavy"
	| "Guard"
	| "Dodge"
	| "Dash"
	| "FocusPush"
	| "FocusDash"
	| "Stagger"
	| "Dead"
	| "Feint"
	| "Riposte"

export type StyleParams = {
	-- Anticipation (startup) — amplitude épaule / torsade
	anticipation: number,
	-- Arc de coupe (active) en radians relatifs
	swingArc: number,
	-- Bias plan : 0 = horizontal, 1 = vertical, 0.5 = diagonal
	planeBias: number,
	-- Follow-through recovery
	followThrough: number,
	-- Hauteur de garde (négatif = haute)
	guardPitch: number,
	-- Lean idle
	idleLean: number,
	-- Twist torse
	torsoTwist: number,
	-- Contrebalancement bras gauche
	offhand: number,
	-- Tempo lecture (1 = nominal)
	tempo: number,
	-- Overshoot Active (Rafale = double pic)
	doubleBeat: boolean,
	-- Priorité AnimationTrack
	priority: Enum.AnimationPriority,
}

export type AnimationSetDef = {
	id: string,
	index: number,
	displayName: string,
	formId: string?,
	rarity: string?,
	tags: { string },
	covers: string,
	style: StyleParams,
}

local function style(partial: {
	anticipation: number,
	swingArc: number,
	planeBias: number,
	followThrough: number,
	guardPitch: number,
	idleLean: number,
	torsoTwist: number,
	offhand: number,
	tempo: number,
	doubleBeat: boolean?,
	priority: Enum.AnimationPriority?,
}): StyleParams
	return {
		anticipation = partial.anticipation,
		swingArc = partial.swingArc,
		planeBias = partial.planeBias,
		followThrough = partial.followThrough,
		guardPitch = partial.guardPitch,
		idleLean = partial.idleLean,
		torsoTwist = partial.torsoTwist,
		offhand = partial.offhand,
		tempo = partial.tempo,
		doubleBeat = partial.doubleBeat == true,
		priority = partial.priority or Enum.AnimationPriority.Action,
	}
end

local SETS: { AnimationSetDef } = {
	-- 1–4 Astra
	{
		id = "Astra_Common_Neutral",
		index = 1,
		displayName = "Astra · Neutre",
		formId = "Astra",
		rarity = "Common",
		tags = { "form", "balanced" },
		covers = "Idle / Startup / Active / Recovery / Guard — tempo neutre, diagonale classique",
		style = style({
			anticipation = 0.85,
			swingArc = 1.15,
			planeBias = 0.45,
			followThrough = 0.55,
			guardPitch = -0.55,
			idleLean = 0.04,
			torsoTwist = 0.22,
			offhand = 0.35,
			tempo = 1.0,
		}),
	},
	{
		id = "Astra_Rare_Starline",
		index = 2,
		displayName = "Astra · Ligne d'Astre",
		formId = "Astra",
		rarity = "Rare",
		tags = { "form", "clean" },
		covers = "Garde haute propre, coupe diagonale nette, recovery courte",
		style = style({
			anticipation = 0.95,
			swingArc = 1.25,
			planeBias = 0.55,
			followThrough = 0.42,
			guardPitch = -0.72,
			idleLean = 0.02,
			torsoTwist = 0.28,
			offhand = 0.4,
			tempo = 1.05,
		}),
	},
	{
		id = "Astra_Epic_ClashSurge",
		index = 3,
		displayName = "Astra · Surge de Clash",
		formId = "Astra",
		rarity = "Epic",
		tags = { "form", "clash" },
		covers = "Large twist torse, anticipation longue, rebound Active",
		style = style({
			anticipation = 1.15,
			swingArc = 1.45,
			planeBias = 0.4,
			followThrough = 0.75,
			guardPitch = -0.5,
			idleLean = 0.06,
			torsoTwist = 0.48,
			offhand = 0.55,
			tempo = 0.95,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	{
		id = "Astra_Legendary_FluxCut",
		index = 4,
		displayName = "Astra · Coupe Flux",
		formId = "Astra",
		rarity = "Legendary",
		tags = { "form", "whip" },
		covers = "Whip rapide, anticipation courte, follow-through fluide",
		style = style({
			anticipation = 0.7,
			swingArc = 1.55,
			planeBias = 0.35,
			followThrough = 0.9,
			guardPitch = -0.6,
			idleLean = 0.05,
			torsoTwist = 0.38,
			offhand = 0.5,
			tempo = 1.18,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	-- 5–8 Duelant
	{
		id = "Duelant_Common_Control",
		index = 5,
		displayName = "Duelant · Contrôle",
		formId = "Duelant",
		rarity = "Common",
		tags = { "form", "thrust" },
		covers = "Idle pointe avant, arcs thrust-biasés, garde étroite",
		style = style({
			anticipation = 0.65,
			swingArc = 0.95,
			planeBias = 0.25,
			followThrough = 0.35,
			guardPitch = -0.4,
			idleLean = 0.08,
			torsoTwist = 0.15,
			offhand = 0.25,
			tempo = 1.08,
		}),
	},
	{
		id = "Duelant_Rare_PerfectEdge",
		index = 6,
		displayName = "Duelant · Tranchant Parfait",
		formId = "Duelant",
		rarity = "Rare",
		tags = { "form", "precise" },
		covers = "Arcs compacts précis, peu de lean, recovery snappy",
		style = style({
			anticipation = 0.75,
			swingArc = 1.05,
			planeBias = 0.5,
			followThrough = 0.28,
			guardPitch = -0.58,
			idleLean = 0.01,
			torsoTwist = 0.18,
			offhand = 0.3,
			tempo = 1.12,
		}),
	},
	{
		id = "Duelant_Epic_ChipWard",
		index = 7,
		displayName = "Duelant · Garde d'Éclat",
		formId = "Duelant",
		rarity = "Epic",
		tags = { "form", "guard" },
		covers = "Garde très haute, Active angulaire, torsade modérée",
		style = style({
			anticipation = 0.9,
			swingArc = 1.1,
			planeBias = 0.6,
			followThrough = 0.45,
			guardPitch = -0.95,
			idleLean = 0.03,
			torsoTwist = 0.25,
			offhand = 0.45,
			tempo = 1.0,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	{
		id = "Duelant_Legendary_FineBlade",
		index = 8,
		displayName = "Duelant · Lame Fine",
		formId = "Duelant",
		rarity = "Legendary",
		tags = { "form", "vertical" },
		covers = "Coupes verticales fines, anticipation haute, Active descendante",
		style = style({
			anticipation = 1.2,
			swingArc = 1.35,
			planeBias = 0.92,
			followThrough = 0.5,
			guardPitch = -0.7,
			idleLean = 0.02,
			torsoTwist = 0.12,
			offhand = 0.28,
			tempo = 1.15,
			priority = Enum.AnimationPriority.Action3,
		}),
	},
	-- 9–12 Aegis
	{
		id = "Aegis_Common_Bastion",
		index = 9,
		displayName = "Aegis · Bastion",
		formId = "Aegis",
		rarity = "Common",
		tags = { "form", "tank" },
		covers = "Stance basse large, swings lourds, garde plaque",
		style = style({
			anticipation = 1.0,
			swingArc = 1.2,
			planeBias = 0.35,
			followThrough = 0.7,
			guardPitch = -0.35,
			idleLean = -0.05,
			torsoTwist = 0.3,
			offhand = 0.65,
			tempo = 0.88,
		}),
	},
	{
		id = "Aegis_Rare_Plate",
		index = 10,
		displayName = "Aegis · Plaque",
		formId = "Aegis",
		rarity = "Rare",
		tags = { "form", "heavy" },
		covers = "Épaules lourdes, tempo lent, Active massive horizontale",
		style = style({
			anticipation = 1.25,
			swingArc = 1.4,
			planeBias = 0.2,
			followThrough = 0.85,
			guardPitch = -0.3,
			idleLean = -0.08,
			torsoTwist = 0.4,
			offhand = 0.75,
			tempo = 0.8,
		}),
	},
	{
		id = "Aegis_Epic_Wall",
		index = 11,
		displayName = "Aegis · Mur",
		formId = "Aegis",
		rarity = "Epic",
		tags = { "form", "horizontal" },
		covers = "Bouclier-like : Idle large, Active balayage horizontal",
		style = style({
			anticipation = 1.1,
			swingArc = 1.5,
			planeBias = 0.08,
			followThrough = 0.8,
			guardPitch = -0.25,
			idleLean = -0.06,
			torsoTwist = 0.55,
			offhand = 0.85,
			tempo = 0.85,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	{
		id = "Aegis_Legendary_Mur",
		index = 12,
		displayName = "Aegis · Mur Légendaire",
		formId = "Aegis",
		rarity = "Legendary",
		tags = { "form", "counter" },
		covers = "Absorb (anticipation contractée) puis counter-arc explosif",
		style = style({
			anticipation = 0.55,
			swingArc = 1.65,
			planeBias = 0.3,
			followThrough = 1.0,
			guardPitch = -0.2,
			idleLean = -0.04,
			torsoTwist = 0.6,
			offhand = 0.9,
			tempo = 0.92,
			priority = Enum.AnimationPriority.Action3,
		}),
	},
	-- 13–16 Zephyr
	{
		id = "Zephyr_Common_Sidestep",
		index = 13,
		displayName = "Zephyr · Pas de Côté",
		formId = "Zephyr",
		rarity = "Common",
		tags = { "form", "lateral" },
		covers = "Lean latéral, arcs transverses, recovery mobile",
		style = style({
			anticipation = 0.7,
			swingArc = 1.1,
			planeBias = 0.3,
			followThrough = 0.5,
			guardPitch = -0.48,
			idleLean = 0.12,
			torsoTwist = 0.35,
			offhand = 0.4,
			tempo = 1.15,
		}),
	},
	{
		id = "Zephyr_Rare_Gale",
		index = 14,
		displayName = "Zephyr · Rafale",
		formId = "Zephyr",
		rarity = "Rare",
		tags = { "form", "circular" },
		covers = "Flourish circulaire, twist fort, Active en arc",
		style = style({
			anticipation = 0.8,
			swingArc = 1.35,
			planeBias = 0.4,
			followThrough = 0.65,
			guardPitch = -0.55,
			idleLean = 0.1,
			torsoTwist = 0.7,
			offhand = 0.55,
			tempo = 1.2,
		}),
	},
	{
		id = "Zephyr_Epic_Rush",
		index = 15,
		displayName = "Zephyr · Ruée",
		formId = "Zephyr",
		rarity = "Epic",
		tags = { "form", "lunge" },
		covers = "Fente avant, Active projetée, peu de follow bas",
		style = style({
			anticipation = 0.6,
			swingArc = 1.2,
			planeBias = 0.35,
			followThrough = 0.4,
			guardPitch = -0.45,
			idleLean = 0.15,
			torsoTwist = 0.25,
			offhand = 0.35,
			tempo = 1.28,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	{
		id = "Zephyr_Legendary_Rafale",
		index = 16,
		displayName = "Zephyr · Double Rafale",
		formId = "Zephyr",
		rarity = "Legendary",
		tags = { "form", "doubleBeat" },
		covers = "Double-beat Active (deux pics), tempo très élevé",
		style = style({
			anticipation = 0.55,
			swingArc = 1.3,
			planeBias = 0.42,
			followThrough = 0.55,
			guardPitch = -0.5,
			idleLean = 0.14,
			torsoTwist = 0.45,
			offhand = 0.5,
			tempo = 1.35,
			doubleBeat = true,
			priority = Enum.AnimationPriority.Action3,
		}),
	},
	-- 17–24 Concord universels / situations
	{
		id = "Concord_LightSlash",
		index = 17,
		displayName = "Concord · Entaille Légère",
		formId = nil,
		rarity = nil,
		tags = { "universal", "light" },
		covers = "Kit léger universel — diagonale vive, recovery courte",
		style = style({
			anticipation = 0.8,
			swingArc = 1.2,
			planeBias = 0.48,
			followThrough = 0.4,
			guardPitch = -0.5,
			idleLean = 0.03,
			torsoTwist = 0.25,
			offhand = 0.38,
			tempo = 1.1,
		}),
	},
	{
		id = "Concord_HeavyCleaver",
		index = 18,
		displayName = "Concord · Fendoir Lourd",
		formId = nil,
		rarity = nil,
		tags = { "universal", "heavy" },
		covers = "Overhead lourd — anticipation haute, Active descendante massive",
		style = style({
			anticipation = 1.4,
			swingArc = 1.7,
			planeBias = 0.95,
			followThrough = 1.05,
			guardPitch = -0.45,
			idleLean = 0.0,
			torsoTwist = 0.2,
			offhand = 0.6,
			tempo = 0.78,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	{
		id = "Concord_FeintSnap",
		index = 19,
		displayName = "Concord · Feinte Sec",
		formId = nil,
		rarity = nil,
		tags = { "universal", "feint" },
		covers = "Startup abrégée + snap vers Guard — lisible pour feinte",
		style = style({
			anticipation = 0.95,
			swingArc = 0.7,
			planeBias = 0.5,
			followThrough = 0.2,
			guardPitch = -0.65,
			idleLean = 0.04,
			torsoTwist = 0.3,
			offhand = 0.4,
			tempo = 1.4,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	{
		id = "Concord_RiposteThrust",
		index = 20,
		displayName = "Concord · Riposte Estoc",
		formId = nil,
		rarity = nil,
		tags = { "universal", "riposte" },
		covers = "Estoc linéaire post-perfect — Active avant, recovery courte",
		style = style({
			anticipation = 0.45,
			swingArc = 0.85,
			planeBias = 0.15,
			followThrough = 0.25,
			guardPitch = -0.55,
			idleLean = 0.1,
			torsoTwist = 0.1,
			offhand = 0.2,
			tempo = 1.25,
			priority = Enum.AnimationPriority.Action3,
		}),
	},
	{
		id = "Concord_FocusPulse",
		index = 21,
		displayName = "Concord · Pulsation Focus",
		formId = nil,
		rarity = nil,
		tags = { "universal", "focus" },
		covers = "Poussée / Dash Focus — extension avant + rebound",
		style = style({
			anticipation = 0.5,
			swingArc = 0.9,
			planeBias = 0.2,
			followThrough = 0.6,
			guardPitch = -0.4,
			idleLean = 0.08,
			torsoTwist = 0.15,
			offhand = 0.7,
			tempo = 1.05,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	{
		id = "Concord_MobilityWeave",
		index = 22,
		displayName = "Concord · Tissage Mobilité",
		formId = nil,
		rarity = nil,
		tags = { "universal", "mobility" },
		covers = "Dodge / Dash — lame latérale puis ramassage",
		style = style({
			anticipation = 0.4,
			swingArc = 0.75,
			planeBias = 0.25,
			followThrough = 0.35,
			guardPitch = -0.4,
			idleLean = 0.18,
			torsoTwist = 0.5,
			offhand = 0.45,
			tempo = 1.3,
			priority = Enum.AnimationPriority.Movement,
		}),
	},
	{
		id = "Concord_StaggerBreak",
		index = 23,
		displayName = "Concord · Rupture",
		formId = nil,
		rarity = nil,
		tags = { "universal", "stagger" },
		covers = "Stagger / GuardBreak — ouverture et déstabilisation",
		style = style({
			anticipation = 0.3,
			swingArc = 0.5,
			planeBias = 0.4,
			followThrough = 0.9,
			guardPitch = 0.2,
			idleLean = -0.15,
			torsoTwist = -0.35,
			offhand = 0.2,
			tempo = 0.9,
			priority = Enum.AnimationPriority.Action4,
		}),
	},
	{
		id = "Concord_KOCollapse",
		index = 24,
		displayName = "Concord · Effondrement",
		formId = nil,
		rarity = nil,
		tags = { "universal", "ko" },
		covers = "Dead / KO — chute de garde, lame basse",
		style = style({
			anticipation = 0.2,
			swingArc = 0.3,
			planeBias = 0.6,
			followThrough = 1.2,
			guardPitch = 0.5,
			idleLean = -0.25,
			torsoTwist = 0.1,
			offhand = 0.1,
			tempo = 0.7,
			priority = Enum.AnimationPriority.Action4,
		}),
	},
	-- 25–28 Pass fluidité — situations / lectures distinctes
	{
		id = "Concord_ClashRebound",
		index = 25,
		displayName = "Concord · Rebond de Clash",
		formId = nil,
		rarity = nil,
		tags = { "universal", "clash" },
		covers = "Rebond post-clash — anticipation contractée, Active whip courte, torsade forte",
		style = style({
			anticipation = 0.5,
			swingArc = 1.35,
			planeBias = 0.38,
			followThrough = 0.7,
			guardPitch = -0.55,
			idleLean = 0.06,
			torsoTwist = 0.65,
			offhand = 0.55,
			tempo = 1.22,
			priority = Enum.AnimationPriority.Action2,
		}),
	},
	{
		id = "Concord_ParryBrace",
		index = 26,
		displayName = "Concord · Parade Brace",
		formId = nil,
		rarity = nil,
		tags = { "universal", "parry" },
		covers = "Garde ultra-haute brace — Idle compact, Guard pitch extrême, peu de swing",
		style = style({
			anticipation = 0.7,
			swingArc = 0.65,
			planeBias = 0.55,
			followThrough = 0.3,
			guardPitch = -1.05,
			idleLean = 0.02,
			torsoTwist = 0.2,
			offhand = 0.5,
			tempo = 1.0,
			priority = Enum.AnimationPriority.Action,
		}),
	},
	{
		id = "Concord_EdgePressure",
		index = 27,
		displayName = "Concord · Pression de Fil",
		formId = nil,
		rarity = nil,
		tags = { "universal", "pressure" },
		covers = "Pression avant — lean fort, arcs courts répétés, recovery snappy",
		style = style({
			anticipation = 0.55,
			swingArc = 0.95,
			planeBias = 0.42,
			followThrough = 0.32,
			guardPitch = -0.5,
			idleLean = 0.16,
			torsoTwist = 0.28,
			offhand = 0.35,
			tempo = 1.32,
		}),
	},
	{
		id = "Concord_CounterStep",
		index = 28,
		displayName = "Concord · Pas de Contre",
		formId = nil,
		rarity = nil,
		tags = { "universal", "counter", "mobility" },
		covers = "Contre-pas — Dodge/Dash hybrides, lean inverse, Active latérale courte",
		style = style({
			anticipation = 0.45,
			swingArc = 1.05,
			planeBias = 0.28,
			followThrough = 0.4,
			guardPitch = -0.42,
			idleLean = -0.12,
			torsoTwist = 0.55,
			offhand = 0.4,
			tempo = 1.25,
			priority = Enum.AnimationPriority.Movement,
		}),
	},
}

local byId: { [string]: AnimationSetDef } = {}
local byFormRarity: { [string]: AnimationSetDef } = {}

for _, def in SETS do
	byId[def.id] = def
	if def.formId and def.rarity then
		byFormRarity[def.formId .. "_" .. def.rarity] = def
	end
end

local AnimationSets = {
	Sets = SETS,
	Count = #SETS,
	ClipNames = {
		"Idle",
		"StartupLight",
		"ActiveLight",
		"RecoveryLight",
		"StartupHeavy",
		"ActiveHeavy",
		"RecoveryHeavy",
		"Guard",
		"Dodge",
		"Dash",
		"FocusPush",
		"FocusDash",
		"Stagger",
		"Dead",
		"Feint",
		"Riposte",
	} :: { ClipName },
}

function AnimationSets.get(id: string): AnimationSetDef?
	return byId[id]
end

function AnimationSets.getByForm(formId: string?, rarity: string?): AnimationSetDef
	if formId and rarity then
		local hit = byFormRarity[formId .. "_" .. rarity]
		if hit then
			return hit
		end
	end
	return byId.Astra_Common_Neutral
end

function AnimationSets.resolveForSnapshot(snap: {
	actionId: string?,
	attackKind: string?,
	formId: string?,
	formRarity: string?,
	flags: { riposteBuff: boolean?, stagger: boolean? }?,
}): (AnimationSetDef, ClipName)
	local actionId = snap.actionId or "Idle"
	local formSet = AnimationSets.getByForm(snap.formId, snap.formRarity)

	-- Situations spéciales → sets Concord dédiés
	if actionId == "Dead" then
		return byId.Concord_KOCollapse, "Dead"
	end
	if actionId == "Stagger" or (snap.flags and snap.flags.stagger) then
		return byId.Concord_StaggerBreak, "Stagger"
	end
	if actionId == "FocusPush" then
		return byId.Concord_FocusPulse, "FocusPush"
	end
	if actionId == "FocusDash" then
		return byId.Concord_FocusPulse, "FocusDash"
	end
	if actionId == "Dodge" then
		-- Contre-pas si lean négatif côté forme Zephyr-like déjà couvert ; CounterStep = dodge reverse
		if snap.flags and snap.flags.riposteBuff then
			return byId.Concord_CounterStep, "Dodge"
		end
		return byId.Concord_MobilityWeave, "Dodge"
	end
	if actionId == "Dash" then
		return byId.Concord_MobilityWeave, "Dash"
	end
	if actionId == "RiposteLock" or (snap.flags and snap.flags.riposteBuff and actionId == "Startup") then
		if snap.flags and snap.flags.riposteBuff then
			return byId.Concord_RiposteThrust, "Riposte"
		end
	end

	local heavy = snap.attackKind == "Heavy"
	-- Clash rebound : Active Heavy Epic → lecture rebond distincte
	if actionId == "Active" and heavy and snap.formRarity == "Epic" then
		local clash = byId.Concord_ClashRebound
		if clash then
			return clash, "ActiveHeavy"
		end
	end
	-- Pression de fil : Startup Light Legendary (tempo/lean distincts de la forme)
	if actionId == "Startup" and not heavy and snap.formRarity == "Legendary" then
		local pressure = byId.Concord_EdgePressure
		if pressure then
			return pressure, "StartupLight"
		end
	end

	if actionId == "Startup" then
		return formSet, if heavy then "StartupHeavy" else "StartupLight"
	elseif actionId == "Active" then
		return formSet, if heavy then "ActiveHeavy" else "ActiveLight"
	elseif actionId == "Recovery" then
		return formSet, if heavy then "RecoveryHeavy" else "RecoveryLight"
	elseif actionId == "Guard" then
		-- Parade brace : Duelant Epic garde déjà ChipWard ; ParryBrace pour Guard + stagger flag clear
		if snap.formId == "Duelant" and snap.formRarity == "Legendary" then
			local brace = byId.Concord_ParryBrace
			if brace then
				return brace, "Guard"
			end
		end
		return formSet, "Guard"
	elseif actionId == "Idle" then
		return formSet, "Idle"
	end

	return formSet, "Idle"
end

function AnimationSets.listIds(): { string }
	local ids = {}
	for _, def in SETS do
		table.insert(ids, def.id)
	end
	return ids
end

return AnimationSets
