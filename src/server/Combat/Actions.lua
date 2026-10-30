--!strict
-- Machine à états serveur : traitement des intentions (Light, Heavy, BlockStart, BlockEnd, Parry, Dodge),
-- timings, cooldowns, endurance, fins d'états temporisés et régénérations (appelé à chaque Heartbeat).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Config = require(Shared.Combat.CombatConfig)
local CombatMath = require(Shared.Combat.CombatMath)
local State = require(script.Parent.State)
local Fighter = require(script.Parent.Fighter)
local Broadcast = require(script.Parent.Broadcast)
local Validation = require(script.Parent.Validation)
local Resolver = require(script.Parent.Resolver)

type Fighter = State.Fighter
type HitInfo = State.HitInfo

local A = Config.Attr

local Actions = {}

local function reject(f: Fighter, action: string, reason: string, seq: number?)
	Broadcast.reject(f.Player, action, reason, seq)
end

local function busy(f: Fighter): boolean
	local st = f.State
	return st == "Stunned" or st == "GuardBroken" or st == "Dodging" or st == "Parrying" or st == "Dead"
end

--------------------------------------------------------------------------------
-- Coups légers

local function startLight(f: Fighter, dir: Vector3?, clientTime: number?, seq: number?)
	local now = State.now()
	if busy(f) or f.ChargeStart or f.Pending or not State.canAct(f) then
		reject(f, "Light", "busy", seq)
		return
	end
	local counter = now <= f.CounterUntil
	if not Fighter.spendStamina(f, Config.Light.StaminaCost * Fighter.staminaMult(f)) then
		reject(f, "Light", "stamina", seq)
		return
	end
	local idx = CombatMath.nextCombo(f.ComboIndex, f.LastLightEnd, now, f.Weapon)
	local airborne = Fighter.isAirborne(f)
	local variant = CombatMath.variant(f.Root.CFrame.LookVector, dir)
	local timing = CombatMath.lightTiming(f.Form, f.Weapon, idx, variant, counter)
	local finisher = idx >= f.Weapon.ComboLength
	local stats = f.Form.Stats
	local mods = Config.Variants[variant]
	local aerial = if airborne then stats.AerialBonus else 1

	f.ComboIndex = idx
	f.Model:SetAttribute(A.Combo, idx)
	if counter then
		f.CounterUntil = 0
	end
	f.BlockHeld = false
	Fighter.setState(f, "Attacking", timing.Windup + timing.Recovery)
	f.NextActionAt = now + timing.Windup + timing.Recovery
	f.LastLightEnd = f.NextActionAt
	Broadcast.anim(f, CombatMath.lightClip(idx, variant, airborne, counter), timing.Speed, true)

	local info: HitInfo = {
		Kind = if counter then "Counter" else "Light",
		Damage = f.Weapon.LightDamage
			* mods.DamageMult
			* aerial
			* (if finisher then Config.Light.FinisherDamageMult else 1)
			* (if counter then Config.Counter.DamageMult else 1),
		Posture = Config.Light.PostureDamage
			* stats.PostureDamage
			* aerial
			* (if finisher then Config.Light.FinisherPostureMult else 1),
		Push = stats.KineticPush * (if finisher then 1 else Config.Light.ComboPushFraction),
		Reach = f.Weapon.Reach,
		Arc = if f.Weapon.Arc >= 360 then 360 else math.clamp(f.Weapon.Arc + mods.ArcBonus, 30, 360),
		Unblockable = counter and Config.Counter.Unblockable,
		ClientTime = if clientTime then clientTime + timing.Windup else nil,
		ComboFinisher = finisher,
	}
	f.PendingKind = info.Kind
	f.PendingAt = now + timing.Windup
	f.Pending = task.delay(timing.Windup, Resolver.strike, f, info)
	State.hooks.attackStarted(f, timing.Windup, info.Kind)
end

local function light(f: Fighter, dir: Vector3?, clientTime: number?, seq: number?)
	if f.ChargeStart or busy(f) then
		reject(f, "Light", "busy", seq)
		return
	end
	if f.Buffered then
		reject(f, "Light", "buffer", seq)
		return
	end
	local wait = f.NextActionAt - State.now()
	if wait > 0 then
		if wait <= Config.Input.Buffer then
			f.Buffered = task.delay(wait, function()
				f.Buffered = nil
				startLight(f, dir, if clientTime then clientTime + wait else nil, seq)
			end)
			return
		end
		reject(f, "Light", "cooldown", seq)
		return
	end
	startLight(f, dir, clientTime, seq)
end

--------------------------------------------------------------------------------
-- Coup lourd : premier « Heavy » = charge, second = relâchement (sinon frappe automatique)

local function releaseHeavy(f: Fighter, clientTime: number?)
	local start = f.ChargeStart
	if not start then
		return
	end
	f.ChargeStart = nil
	local ct = f.ChargeThread
	f.ChargeThread = nil
	if ct and ct ~= coroutine.running() and coroutine.status(ct) ~= "dead" then
		pcall(task.cancel, ct)
	end
	if not State.canAct(f) or f.State ~= "Attacking" then
		Fighter.updateMovement(f)
		return
	end
	local now = State.now()
	local timing = CombatMath.heavyTiming(f.Form, f.Weapon, now - start)
	local airborne = Fighter.isAirborne(f)
	local stats = f.Form.Stats
	local aerial = if airborne then stats.AerialBonus else 1
	f.HeavyReleasedAt = now

	-- Saber Lock : l'adversaire a relâché un lourd il y a moins de Clash.Window et l'impact n'a pas eu lieu
	local o = f.Opponent
	if o and o.Alive and o.MatchId == f.MatchId and o.PendingKind == "Heavy" and o.Pending and now - o.HeavyReleasedAt <= Config.Clash.Window then
		local range = math.max(f.Weapon.Reach, o.Weapon.Reach) + Config.Clash.ExtraRange
		if (o.Root.Position - f.Root.Position).Magnitude <= range then
			Resolver.saberLock(f, o)
			return
		end
	end

	Fighter.setState(f, "Attacking", timing.Windup + timing.Recovery)
	f.NextActionAt = now + timing.Windup + timing.Recovery
	f.ComboIndex = 0
	f.Model:SetAttribute(A.Combo, 0)
	Broadcast.anim(f, "M2_Strike", timing.Speed, true)
	local info: HitInfo = {
		Kind = "Heavy",
		Damage = f.Weapon.HeavyDamage * timing.Factor * aerial,
		Posture = f.Weapon.HeavyPostureDamage * stats.PostureDamage * timing.Factor * aerial,
		Push = Config.Heavy.BasePush + stats.KineticPush,
		Reach = f.Weapon.Reach,
		Arc = f.Weapon.Arc,
		Unblockable = false,
		ClientTime = if clientTime then clientTime + timing.Windup else nil,
		ComboFinisher = false,
	}
	f.PendingKind = "Heavy"
	f.PendingAt = now + timing.Windup
	f.Pending = task.delay(timing.Windup, Resolver.strike, f, info)
	State.hooks.attackStarted(f, timing.Windup, "Heavy")
end

local function heavy(f: Fighter, clientTime: number?, seq: number?)
	local now = State.now()
	if f.ChargeStart then
		releaseHeavy(f, clientTime)
		return
	end
	if now - f.AutoReleasedAt < Config.Heavy.StaleReleaseGrace then
		return -- relâchement arrivé après la frappe automatique
	end
	if busy(f) or f.Pending or f.Buffered then
		reject(f, "Heavy", "busy", seq)
		return
	end
	if now < f.NextActionAt then
		reject(f, "Heavy", "cooldown", seq)
		return
	end
	if not Fighter.spendStamina(f, Config.Heavy.StaminaCost * Fighter.staminaMult(f)) then
		reject(f, "Heavy", "stamina", seq)
		return
	end
	f.BlockHeld = false
	f.ChargeStart = now
	Fighter.setState(f, "Attacking")
	Broadcast.anim(f, "M2_Charge", 1, true)
	local start = now
	f.ChargeThread = task.delay(Config.Heavy.MaxCharge + Config.Heavy.AutoReleaseSlack, function()
		if f.ChargeStart == start then
			f.ChargeThread = nil
			f.AutoReleasedAt = State.now()
			releaseHeavy(f, nil)
		end
	end)
end

--------------------------------------------------------------------------------
-- Garde, parade, esquive

local function blockStart(f: Fighter)
	f.BlockHeld = true
	if f.State == "Idle" and State.now() >= f.NextActionAt - 0.05 then
		Fighter.setState(f, "Blocking")
	end
end

local function blockEnd(f: Fighter)
	f.BlockHeld = false
	if f.State == "Blocking" then
		Fighter.setState(f, "Idle")
	end
end

-- Exposé pour les mannequins.
function Actions.parry(f: Fighter, seq: number?): boolean
	local now = State.now()
	local st = f.State
	if st ~= "Idle" and st ~= "Blocking" then
		reject(f, "Parry", "busy", seq)
		return false
	end
	if now < f.ParryReadyAt or (st ~= "Blocking" and now < f.NextActionAt - 0.05) then
		reject(f, "Parry", "cooldown", seq)
		return false
	end
	if not Fighter.spendStamina(f, Config.Parry.StaminaCost * Fighter.staminaMult(f)) then
		reject(f, "Parry", "stamina", seq)
		return false
	end
	local window = CombatMath.parryWindow(f.Form)
	f.ParryStart = now
	f.ParryWindow = window
	f.ParryReadyAt = now + window + Config.Parry.WhiffCooldown
	Fighter.setState(f, "Parrying", window)
	Broadcast.anim(f, "Parry", 1, true)
	return true
end

function Actions.block(f: Fighter, on: boolean)
	if on then
		blockStart(f)
	else
		blockEnd(f)
	end
end

-- Ultime « Éveil de l'Éther » (jauge pleine, en duel uniquement)
local function ultimate(f: Fighter, seq: number?)
	local m = f.Model
	if f.MatchId == nil then
		reject(f, "Ultimate", "hub", seq)
		return
	end
	if ((m:GetAttribute("Ultimate") :: number?) or 0) < Config.Ultimate.Max then
		reject(f, "Ultimate", "gauge", seq)
		return
	end
	if f.State ~= "Idle" and f.State ~= "Blocking" then
		reject(f, "Ultimate", "busy", seq)
		return
	end
	local dur = Config.Ultimate.Duration
	m:SetAttribute("Ultimate", 0)
	m:SetAttribute("UltActiveUntil", workspace:GetServerTimeNow() + dur)
	f.Posture = f.MaxPosture
	f.Stamina = f.MaxStamina
	Fighter.writeAttributes(f)
	local hl = Instance.new("Highlight")
	hl.Name = "EveilEther"
	hl.FillColor = Config.Ultimate.Color
	hl.FillTransparency = 0.75
	hl.OutlineColor = Config.Ultimate.Color
	hl.Parent = m
	task.delay(dur, function()
		hl:Destroy()
	end)
	Broadcast.fx("Ultimate", { Target = m, Position = f.Root.Position, Duration = dur })
	Broadcast.anim(f, "Ignite", 1, true)
end

local function dodge(f: Fighter, dir: Vector3?, seq: number?)
	local now = State.now()
	if busy(f) then
		reject(f, "Dodge", "busy", seq)
		return
	end
	if f.State == "Attacking" and (f.Pending ~= nil or f.ChargeStart ~= nil) then
		reject(f, "Dodge", "busy", seq)
		return
	end
	if now < f.DodgeReadyAt then
		reject(f, "Dodge", "cooldown", seq)
		return
	end
	if not Fighter.spendStamina(f, Config.Dodge.StaminaCost * Fighter.staminaMult(f)) then
		reject(f, "Dodge", "stamina", seq)
		return
	end
	local v = if dir then Vector3.new(dir.X, 0, dir.Z) else Vector3.zero
	if v.Magnitude < 0.2 then
		local look = f.Root.CFrame.LookVector
		v = -Vector3.new(look.X, 0, look.Z)
	end
	if v.Magnitude < 1e-3 then
		v = Vector3.new(0, 0, 1)
	end
	v = v.Unit
	local dur = CombatMath.dodgeDuration(f.Form)
	Fighter.cancelPending(f)
	Fighter.setState(f, "Dodging", dur)
	f.IFramesUntil = now + math.min(dur, Config.Dodge.IFrames)
	f.DodgeReadyAt = now + dur + Config.Dodge.Cooldown
	f.NextActionAt = now + dur
	Validation.allowMovement(f.Player, dur + 0.3)
	local letter = CombatMath.dodgeLetter(f.Root.CFrame, v)
	Broadcast.anim(f, "Dodge_" .. letter, Config.Dodge.Duration / dur, true)
	Broadcast.fx("Dodge", { Target = f.Model, Position = f.Root.Position, Direction = v })
	if f.IsDummy then
		State.hooks.pushNpc(f, v * Config.Dodge.Distance * 0.4)
	end
end

local function igniteHub(f: Fighter)
	Fighter.setSaber(f, true)
	f.NextActionAt = State.now() + Config.Hub.IgniteLock
	Broadcast.anim(f, "Ignite", 1, true)
end

--------------------------------------------------------------------------------
-- Entrée principale (intention déjà validée en types par Guard)

function Actions.input(f: Fighter, action: string, dir: Vector3?, clientTime: number?, seq: number?)
	if action == "BlockEnd" then
		blockEnd(f)
		return
	end
	if not State.canAct(f) then
		reject(f, action, "locked", seq)
		return
	end
	f.LastCombatAt = State.now()
	if not f.SaberOn then
		if f.MatchId == nil and action ~= "BlockEnd" then
			igniteHub(f) -- dans le Hub, la première intention allume la lame
		else
			reject(f, action, "saber", seq)
		end
		return
	end
	if action == "Light" then
		light(f, dir, clientTime, seq)
	elseif action == "Heavy" then
		heavy(f, clientTime, seq)
	elseif action == "BlockStart" then
		blockStart(f)
	elseif action == "Parry" then
		Actions.parry(f, seq)
	elseif action == "Dodge" then
		dodge(f, dir, seq)
	elseif action == "Ultimate" then
		ultimate(f, seq)
	end
end

--------------------------------------------------------------------------------
-- Tick (Heartbeat) : fins d'états, régénérations, drain de garde, extinction auto dans le Hub

local function exitState(f: Fighter, now: number)
	local prev = f.State
	f.StateUntil = 0
	if prev == "Dead" or f.ChargeStart then
		return
	end
	if prev == "GuardBroken" then
		f.Posture = math.max(f.Posture, f.MaxPosture * Config.Posture.BrokenRecoverFraction)
		f.Model:SetAttribute(A.Posture, math.floor(f.Posture * 10 + 0.5) / 10)
	elseif prev == "Parrying" then
		-- parade dans le vide (une parade réussie change l'état avant la fin du minuteur)
		f.NextActionAt = math.max(f.NextActionAt, now + Config.Parry.WhiffRecovery)
	end
	Fighter.setState(f, if f.BlockHeld then "Blocking" else "Idle")
end

function Actions.tick(f: Fighter, now: number, dt: number)
	if f.StateUntil > 0 and now >= f.StateUntil then
		exitState(f, now)
	end
	if not f.Alive or f.State == "Dead" then
		return
	end
	local dirty = false
	-- endurance
	if f.State ~= "Dodging" and f.Stamina < f.MaxStamina and now - f.LastStaminaUse >= Config.Stamina.RegenDelay then
		local rate = Config.Stamina.RegenPerSec * (if f.State == "Blocking" then Config.Stamina.BlockRegenFactor else 1)
		f.Stamina = math.min(f.MaxStamina, f.Stamina + rate * dt)
		dirty = true
	end
	-- posture : drain en garde, sinon régénération après délai
	if f.State == "Blocking" then
		local floor = f.MaxPosture * Config.Posture.DrainFloor
		if f.Posture > floor then
			local drain = Config.Posture.BlockHoldDrainPerSec * f.Weapon.BlockCostMultiplier * f.Form.Stats.BlockPostureCost
			f.Posture = math.max(floor, f.Posture - drain * dt)
			dirty = true
		end
	elseif f.State ~= "GuardBroken" and f.Posture < f.MaxPosture and now - f.LastPostureLoss >= Config.Posture.RegenDelay then
		f.Posture = math.min(f.MaxPosture, f.Posture + f.Weapon.PostureRegen * dt)
		dirty = true
	end
	if dirty and now - f.AttrClock >= 1 / Config.Net.AttrRate then
		f.AttrClock = now
		Fighter.writeAttributes(f)
	end
	-- Hub : la lame s'éteint après une longue inactivité
	if f.MatchId == nil and not f.IsDummy and f.SaberOn and f.State == "Idle" and now - f.LastCombatAt > Config.Hub.AutoExtinguish then
		Fighter.setSaber(f, false)
	end
end

return Actions
