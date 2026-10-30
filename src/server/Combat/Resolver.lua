--!strict
-- Résolution serveur des impacts : esquive (i-frames), parade parfaite, garde, coup franc, bris de garde,
-- dégâts / posture, poussées cinétiques et Saber Lock (deux lourds simultanés).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Config = require(Shared.Combat.CombatConfig)
local State = require(script.Parent.State)
local Fighter = require(script.Parent.Fighter)
local Broadcast = require(script.Parent.Broadcast)
local Validation = require(script.Parent.Validation)

type Fighter = State.Fighter
type HitInfo = State.HitInfo

local A = Config.Attr

local Resolver = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function contactPoint(a: Fighter, t: Fighter): Vector3
	return (a.Root.Position + t.Root.Position) * 0.5 + Vector3.new(0, 1.2, 0)
end

-- Le défenseur fait-il face à l'attaquant (cône de garde) ?
local function facing(t: Fighter, a: Fighter, arcDeg: number): boolean
	local to = flat(a.Root.Position - t.Root.Position)
	local look = flat(t.Root.CFrame.LookVector)
	if to.Magnitude < 0.5 or look.Magnitude < 1e-3 then
		return true
	end
	return look.Unit:Dot(to.Unit) >= math.cos(math.rad(arcDeg * 0.5))
end

-- Poussée de `t` en s'éloignant de `from` (client propriétaire ou mannequin).
function Resolver.push(from: Fighter, t: Fighter, studs: number)
	if studs <= 0 or not t.Alive then
		return
	end
	local dist = math.min(studs, Config.Push.MaxStuds)
	local dir = flat(t.Root.Position - from.Root.Position)
	if dir.Magnitude < 0.1 then
		dir = flat(from.Root.CFrame.LookVector)
	end
	if dir.Magnitude < 1e-3 then
		return
	end
	dir = dir.Unit
	local p = t.Player
	if p then
		local dur = Config.Push.Duration
		Validation.allowMovement(p, dur + 0.5)
		Broadcast.impulse(p, dir * (dist / dur), dur)
	elseif t.IsDummy then
		State.hooks.pushNpc(t, dir * dist)
	end
end

function Resolver.damage(t: Fighter, amount: number, source: Fighter?)
	if not t.Alive or amount <= 0 then
		return
	end
	t.Health = math.max(0, t.Health - amount)
	t.LastHitTaken = State.now()
	t.Model:SetAttribute(A.HealthPct, math.clamp(t.Health / t.MaxHealth, 0, 1))
	if t.Health <= 0 then
		t.Alive = false
		Fighter.cancelPending(t)
		t.BlockHeld = false
		Fighter.setState(t, "Dead")
		State.hooks.defeated(t, source)
	end
end

-- Jauge d'ultime : se remplit seulement en duel, et pas pendant l'Éveil lui-même.
local function gainUlt(f: Fighter?, amount: number)
	if not f or not f.Alive or f.MatchId == nil then
		return
	end
	local m = f.Model
	if ((m:GetAttribute("UltActiveUntil") :: number?) or 0) > workspace:GetServerTimeNow() then
		return
	end
	m:SetAttribute("Ultimate", math.min(Config.Ultimate.Max, ((m:GetAttribute("Ultimate") :: number?) or 0) + amount))
end

-- Statistiques de duel (écran de fin) : compteurs en attributs du joueur, remis à zéro au début de chaque match.
local function stat(f: Fighter?, key: string)
	local p = f and f.Player
	if p then
		p:SetAttribute(key, ((p:GetAttribute(key) :: number?) or 0) + 1)
	end
end

function Resolver.guardBreak(t: Fighter, by: Fighter?)
	stat(by, "EB_StatBreaks")
	gainUlt(by, Config.Ultimate.GainBreak)
	Fighter.cancelPending(t)
	t.Posture = 0
	t.Model:SetAttribute(A.Posture, 0)
	local dur = Config.GuardBroken.Duration
	Fighter.setState(t, "GuardBroken", dur)
	t.NextActionAt = State.now() + dur
	Broadcast.anim(t, "GuardBroken", 1, false)
	Broadcast.fx("GuardBreak", {
		Target = t.Model,
		Attacker = if by then by.Model else nil,
		Position = if by then contactPoint(by, t) else t.Root.Position + Vector3.new(0, 1.5, 0),
	})
end

-- Applique une perte de posture et gère le bris de garde.
function Resolver.postureHit(t: Fighter, amount: number, by: Fighter?): boolean
	local broke = Fighter.losePosture(t, amount)
	if broke then
		Resolver.guardBreak(t, by)
	end
	return broke
end

local function perfectParry(a: Fighter, t: Fighter, info: HitInfo)
	stat(t, "EB_StatParries")
	gainUlt(t, Config.Ultimate.GainParry)
	local now = State.now()
	local stun = if info.Kind == "Heavy" then Config.Parry.AttackerStunHeavy else Config.Parry.AttackerStun
	Fighter.cancelPending(a)
	Fighter.setState(a, "Stunned", stun)
	a.NextActionAt = now + stun
	a.ComboIndex = 0
	Broadcast.anim(a, "Stunned", Config.Parry.AttackerStun / stun, false)

	local reflect = info.Posture * t.Form.Stats.ParryReflect
	t.Posture = math.min(t.MaxPosture, t.Posture + Config.Parry.PostureRefund)
	t.NextActionAt = now
	t.ParryReadyAt = now
	local cw = t.Form.Stats.CounterWindow
	t.CounterUntil = if cw > 0 then now + cw else 0
	Fighter.setState(t, if t.BlockHeld then "Blocking" else "Idle")

	Broadcast.fx("Parry", {
		Attacker = a.Model,
		Target = t.Model,
		Position = contactPoint(a, t),
		Reflect = reflect > 0,
		CounterWindow = cw,
		Heavy = info.Kind == "Heavy",
	})
	Resolver.postureHit(a, Config.Parry.PostureDamageToAttacker + reflect, t)
end

local function blocked(a: Fighter, t: Fighter, info: HitInfo)
	local mult = if info.Kind == "Heavy" then Config.Block.HeavyMult else Config.Block.LightMult
	local cost = info.Posture * mult * t.Weapon.BlockCostMultiplier * t.Form.Stats.BlockPostureCost
	local broke = Resolver.postureHit(t, cost, a)
	if info.Kind == "Heavy" then
		Resolver.damage(t, info.Damage * Config.Block.HeavyChip, a)
	end
	local recoil = Config.Block.AttackerRecoil
	a.NextActionAt += recoil
	if a.StateUntil > 0 then
		a.StateUntil += recoil
	end
	Resolver.push(a, t, info.Push * Config.Block.PushFraction)
	Broadcast.fx("Block", {
		Attacker = a.Model,
		Target = t.Model,
		Position = contactPoint(a, t),
		Heavy = info.Kind == "Heavy",
		Broke = broke,
	})
	if not broke and t.Alive then
		Broadcast.anim(t, "BlockHit", 1, false)
	end
end

local function cleanHit(a: Fighter, t: Fighter, info: HitInfo)
	local now = State.now()
	local mult = 1
	if t.State == "GuardBroken" then
		mult = Config.GuardBroken.DamageMult
	elseif t.State == "Stunned" then
		mult = Config.Stunned.DamageMult
	end
	local wasBroken = t.State == "GuardBroken"
	local dmg = info.Damage * mult
	if info.Kind == "Counter" then
		stat(a, "EB_StatCounters")
	end
	gainUlt(a, Config.Ultimate.GainHit)
	gainUlt(t, Config.Ultimate.GainHurt)
	Broadcast.fx("Hit", {
		Attacker = a.Model,
		Target = t.Model,
		Position = contactPoint(a, t),
		Heavy = info.Kind == "Heavy",
		Damage = dmg,
		Finisher = info.ComboFinisher,
		Counter = info.Kind == "Counter",
	})
	Resolver.damage(t, dmg, a)
	if not t.Alive then
		return
	end
	if not wasBroken then
		local pf = if info.Kind == "Heavy" then Config.Heavy.HitPostureFraction else 0.5
		if Resolver.postureHit(t, info.Posture * pf, a) then
			Resolver.push(a, t, info.Push)
			return
		end
	end
	-- vacillement, sauf armure (coup lourd en charge / en frappe) et états déjà subis
	local armored = t.ChargeStart ~= nil or t.PendingKind == "Heavy"
	if not armored and t.State ~= "GuardBroken" and t.State ~= "Stunned" and t.State ~= "Dead" then
		Fighter.cancelPending(t)
		Fighter.setState(t, "Stunned", Config.Light.HitStun)
		t.NextActionAt = math.max(t.NextActionAt, now + Config.Light.HitStun)
		Broadcast.anim(t, "Flinch", 1, false)
	end
	Resolver.push(a, t, info.Push)
end

local function resolveOn(a: Fighter, t: Fighter, info: HitInfo)
	local now = State.now()
	if now < t.IFramesUntil then
		Broadcast.fx("Evade", { Attacker = a.Model, Target = t.Model, Position = t.Root.Position })
		return
	end
	if t.State == "Parrying" then
		local grace = 0
		local tp = t.Player
		if tp then
			grace = math.min(tp:GetNetworkPing(), Config.Parry.MaxLatencyGrace)
		end
		if now <= t.ParryStart + t.ParryWindow + grace then
			perfectParry(a, t, info)
			return
		end
	end
	if (t.State == "Blocking" or t.State == "Parrying") and not info.Unblockable and facing(t, a, Config.Block.ArcDeg) then
		blocked(a, t, info)
		return
	end
	cleanHit(a, t, info)
end

-- Impact d'un coup programmé : cherche les cibles valides et résout chacune.
function Resolver.strike(a: Fighter, info: HitInfo)
	a.Pending = nil
	if not a.Alive or a.State ~= "Attacking" or a.Frozen then
		a.PendingKind = nil
		return
	end
	if ((a.Model:GetAttribute("UltActiveUntil") :: number?) or 0) > workspace:GetServerTimeNow() then
		-- Éveil de l'Éther actif : coups renforcés
		info = table.clone(info)
		info.Damage *= Config.Ultimate.DamageMult
		info.Posture *= Config.Ultimate.PostureMult
	end
	local targets = table.clone(State.targetsFor(a))
	local count = 0
	for _, t in targets do
		if t ~= a and t.Alive and t.State ~= "Dead" and not t.Frozen then
			if Validation.canHit(a, t, info.Reach, info.Arc, info.ClientTime) then
				resolveOn(a, t, info)
				count += 1
				if count >= Config.Light.MaxTargets or not a.Alive or a.State ~= "Attacking" then
					break
				end
			end
		end
	end
	a.PendingKind = nil
end

-- Saber Lock : les deux lames se bloquent, gel 1,5 s puis séparation.
function Resolver.saberLock(a: Fighter, b: Fighter)
	local dur = Config.Clash.Duration
	for _, f in { a, b } do
		Fighter.cancelPending(f)
		Fighter.setFrozen(f, true)
		Fighter.setState(f, "Attacking")
		f.Model:SetAttribute(A.SaberLock, true)
	end
	local point = (a.Root.Position + b.Root.Position) * 0.5 + Vector3.new(0, 1.6, 0)
	Broadcast.saberLock(a, b, point, dur)
	task.delay(dur, function()
		local now = State.now()
		for _, f in { a, b } do
			if f.Model:GetAttribute(A.SaberLock) == true then
				f.Model:SetAttribute(A.SaberLock, false)
				if f.Alive and f.Model.Parent and State.canActIgnoringFreeze(f) then
					Fighter.setFrozen(f, false)
					Fighter.setState(f, "Idle")
					f.NextActionAt = now + Config.Clash.RecoveryAfter
				end
			end
		end
		if a.Alive and b.Alive and not a.Frozen and not b.Frozen then
			local studs = Config.Clash.PushSpeed * Config.Clash.PushDuration
			Resolver.push(b, a, studs)
			Resolver.push(a, b, studs)
			Resolver.postureHit(a, Config.Clash.PostureDamage, b)
			Resolver.postureHit(b, Config.Clash.PostureDamage, a)
		end
	end)
end

return Resolver
