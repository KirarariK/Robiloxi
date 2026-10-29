--!strict
-- Calculs partagés client / serveur : vitesses, timings, variantes de direction, noms de clips.
-- Le serveur fait autorité ; le client utilise les mêmes formules pour sa prédiction d'animation.
local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.CombatConfig)

type FormDef = Types.FormDef
type WeaponDef = Types.WeaponDef

local CombatMath = {}

function CombatMath.attackSpeed(form: FormDef, weapon: WeaponDef): number
	return math.max(0.2, weapon.AttackSpeed * form.Stats.AttackSpeed)
end

function CombatMath.staminaMult(form: FormDef, weapon: WeaponDef): number
	return weapon.StaminaCost * form.Stats.StaminaCost
end

-- Classe une direction de déplacement (monde) par rapport à l'orientation du personnage.
function CombatMath.variant(look: Vector3, dir: Vector3?): Config.Variant
	if dir == nil then
		return "Neutral"
	end
	local d = Vector3.new(dir.X, 0, dir.Z)
	if d.Magnitude < 0.2 then
		return "Neutral"
	end
	d = d.Unit
	local l = Vector3.new(look.X, 0, look.Z)
	if l.Magnitude < 1e-3 then
		return "Neutral"
	end
	l = l.Unit
	local fwd = l:Dot(d)
	if fwd >= Config.VariantThreshold then
		return "Forward"
	elseif fwd <= -Config.VariantThreshold then
		return "Back"
	end
	return "Side"
end

-- Lettre de direction d'esquive (F / B / L / R) dans le repère du personnage.
function CombatMath.dodgeLetter(cf: CFrame, dir: Vector3): string
	local lcl = cf:VectorToObjectSpace(dir)
	if math.abs(lcl.Z) >= math.abs(lcl.X) then
		return if lcl.Z < 0 then "F" else "B"
	end
	return if lcl.X > 0 then "R" else "L"
end

export type LightTiming = { Windup: number, Recovery: number, Speed: number }

function CombatMath.lightTiming(form: FormDef, weapon: WeaponDef, index: number, variant: Config.Variant, counter: boolean): LightTiming
	local speed = CombatMath.attackSpeed(form, weapon)
	local mods = Config.Variants[variant]
	local windup = Config.Light.Windup * mods.WindupMult / speed
	if counter then
		windup *= Config.Counter.WindupMult
	end
	local recovery = Config.Light.Recovery / speed
	if index >= weapon.ComboLength then
		recovery += Config.Light.FinisherExtraRecovery / speed
	end
	return { Windup = windup, Recovery = recovery, Speed = speed }
end

-- Index du prochain coup du combo.
function CombatMath.nextCombo(current: number, lastEnd: number, now: number, weapon: WeaponDef): number
	if current >= weapon.ComboLength or now - lastEnd > Config.Light.ComboResetTime then
		return 1
	end
	return current + 1
end

function CombatMath.lightClip(index: number, variant: Config.Variant, airborne: boolean, counter: boolean): string
	if counter then
		return "Counter"
	elseif airborne then
		return "M1_Air"
	end
	return "M1_" .. tostring(index) .. Config.Variants[variant].Suffix
end

export type HeavyTiming = { Windup: number, Recovery: number, Factor: number, Speed: number }

-- `held` = durée de charge ; la frappe ne part jamais avant MinCharge.
function CombatMath.heavyTiming(form: FormDef, weapon: WeaponDef, held: number): HeavyTiming
	local h = Config.Heavy
	local speed = CombatMath.attackSpeed(form, weapon)
	local wait = math.max(0, h.MinCharge - held)
	local k = math.clamp((math.max(held, h.MinCharge) - h.MinCharge) / (h.MaxCharge - h.MinCharge), 0, 1)
	return {
		Windup = h.StrikeWindup / speed + wait,
		Recovery = weapon.HeavyRecovery / speed,
		Factor = h.MinChargeFactor + (1 - h.MinChargeFactor) * k,
		Speed = speed,
	}
end

function CombatMath.dodgeDuration(form: FormDef): number
	return Config.Dodge.Duration / math.max(0.3, form.Stats.DodgeSpeed)
end

function CombatMath.parryWindow(form: FormDef): number
	return Config.Parry.BaseWindow * form.Stats.ParryWindow
end

return table.freeze(CombatMath)
