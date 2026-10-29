--!strict
-- Combattant serveur : stats dérivées (arme × Voie), attributs répliqués, changements d'état, ressources.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local Maid = require(Shared.Util.Maid)
local FormData = require(Shared.Config.FormData)
local WeaponData = require(Shared.Config.WeaponData)
local SaberColors = require(Shared.Config.SaberColors)
local Config = require(Shared.Combat.CombatConfig)
local CombatMath = require(Shared.Combat.CombatMath)
local State = require(script.Parent.State)

type Fighter = State.Fighter
type CombatState = State.CombatState

local A = Config.Attr

local Fighter = {}

local function defaultForm(): Types.FormDef
	return FormData.get(FormData.Default) :: Types.FormDef
end

local function defaultWeapon(): Types.WeaponDef
	return WeaponData.get(WeaponData.Default) :: Types.WeaponDef
end

function Fighter.new(model: Model, humanoid: Humanoid, root: BasePart, player: Player?, isDummy: boolean): Fighter
	local weapon = defaultWeapon()
	local f: Fighter = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Player = player,
		IsDummy = isDummy,
		Form = defaultForm(),
		Weapon = weapon,
		ColorId = SaberColors.Default,

		State = "Idle",
		StateUntil = 0,
		Alive = true,

		Health = Config.Health.Max,
		MaxHealth = Config.Health.Max,
		Posture = weapon.MaxPosture,
		MaxPosture = weapon.MaxPosture,
		Stamina = Config.Stamina.Max,
		MaxStamina = Config.Stamina.Max,
		LastPostureLoss = 0,
		LastStaminaUse = 0,
		LastHitTaken = 0,

		ComboIndex = 0,
		LastLightEnd = 0,
		NextActionAt = 0,

		Pending = nil,
		PendingKind = nil,
		PendingAt = 0,
		Buffered = nil,
		ChargeStart = nil,
		ChargeThread = nil,
		HeavyReleasedAt = -math.huge,
		AutoReleasedAt = -math.huge,

		BlockHeld = false,
		ParryStart = 0,
		ParryWindow = 0,
		ParryReadyAt = 0,
		IFramesUntil = 0,
		DodgeReadyAt = 0,
		CounterUntil = 0,

		Frozen = false,
		SaberOn = isDummy,
		LastCombatAt = 0,
		MatchId = nil,
		Opponent = nil,

		AttrClock = 0,
		Maid = Maid.new(),
	}
	model:SetAttribute(A.InDuel, false)
	model:SetAttribute(A.SaberOn, f.SaberOn)
	model:SetAttribute(A.Frozen, false)
	model:SetAttribute(A.SaberLock, false)
	model:SetAttribute(A.Dummy, isDummy)
	model:SetAttribute(A.Combo, 0)
	model:SetAttribute(A.MaxStamina, f.MaxStamina)
	Fighter.applyLoadout(f, f.Form.Id, weapon.Id, f.ColorId)
	Fighter.writeAttributes(f)
	model:SetAttribute(A.State, "Idle")
	CollectionService:AddTag(model, Config.FighterTag)
	return f
end

-- Applique Voie / arme / cristal (valeurs validées ; repli sur les défauts).
function Fighter.applyLoadout(f: Fighter, formId: string, weaponId: string, colorId: string)
	local form = FormData.get(formId) or defaultForm()
	local weapon = WeaponData.get(weaponId) or defaultWeapon()
	local color = if SaberColors.isValid(colorId) then colorId else SaberColors.Default
	local weaponChanged = weapon ~= f.Weapon
	f.Form = form
	f.Weapon = weapon
	f.ColorId = color
	f.MaxPosture = weapon.MaxPosture
	if weaponChanged then
		f.Posture = math.min(f.Posture, f.MaxPosture)
	end
	f.Model:SetAttribute(A.Form, form.Id)
	f.Model:SetAttribute(A.Weapon, weapon.Id)
	f.Model:SetAttribute(A.Color, color)
	f.Model:SetAttribute(A.MaxPosture, f.MaxPosture)
	Fighter.updateMovement(f)
	Fighter.writeAttributes(f)
end

function Fighter.attackSpeed(f: Fighter): number
	return CombatMath.attackSpeed(f.Form, f.Weapon)
end

function Fighter.staminaMult(f: Fighter): number
	return CombatMath.staminaMult(f.Form, f.Weapon)
end

local function round1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

function Fighter.writeAttributes(f: Fighter)
	local m = f.Model
	m:SetAttribute(A.Posture, round1(f.Posture))
	m:SetAttribute(A.Stamina, round1(f.Stamina))
	m:SetAttribute(A.HealthPct, math.clamp(f.Health / f.MaxHealth, 0, 1))
end

-- Vitesse de marche / hauteur de saut selon l'état (le serveur fait autorité sur le Humanoid).
function Fighter.updateMovement(f: Fighter)
	local h = f.Humanoid
	if f.IsDummy then
		h.WalkSpeed = 0
		h.JumpHeight = 0
		return
	end
	local mv = Config.Movement
	local speed = mv.Base
	local canJump = true
	local st = f.State
	if f.Frozen or st == "Dead" then
		speed, canJump = 0, false
	elseif f.ChargeStart then
		speed = mv.Charging
	elseif st == "Attacking" then
		speed = mv.Attacking
	elseif st == "Blocking" or st == "Parrying" then
		speed = mv.Blocking
	elseif st == "Stunned" or st == "GuardBroken" then
		speed, canJump = mv.Stunned, false
	end
	h.WalkSpeed = speed
	h.UseJumpPower = false
	h.JumpHeight = if canJump then mv.JumpHeight * f.Form.Stats.JumpPower else 0
end

function Fighter.setState(f: Fighter, st: CombatState, duration: number?)
	f.State = st
	f.StateUntil = if duration and duration > 0 then State.now() + duration else 0
	f.Model:SetAttribute(A.State, st)
	Fighter.updateMovement(f)
end

-- Annule un thread programmé sans jamais annuler le thread courant.
local function cancelThread(t: thread?)
	if t and t ~= coroutine.running() and coroutine.status(t) ~= "dead" then
		pcall(task.cancel, t)
	end
end

function Fighter.cancelPending(f: Fighter)
	cancelThread(f.Pending)
	cancelThread(f.Buffered)
	cancelThread(f.ChargeThread)
	f.Pending = nil
	f.Buffered = nil
	f.ChargeThread = nil
	f.PendingKind = nil
	f.ChargeStart = nil
end

function Fighter.spendStamina(f: Fighter, amount: number): boolean
	if f.Stamina < amount then
		return false
	end
	f.Stamina -= amount
	f.LastStaminaUse = State.now()
	f.Model:SetAttribute(A.Stamina, round1(f.Stamina))
	return true
end

-- Perte de posture ; renvoie vrai si la garde vient d'être brisée.
function Fighter.losePosture(f: Fighter, amount: number): boolean
	if amount <= 0 or f.State == "GuardBroken" or f.State == "Dead" then
		return false
	end
	f.Posture = math.max(0, f.Posture - amount)
	f.LastPostureLoss = State.now()
	f.Model:SetAttribute(A.Posture, round1(f.Posture))
	return f.Posture <= 0
end

function Fighter.setFrozen(f: Fighter, frozen: boolean)
	f.Frozen = frozen
	f.Model:SetAttribute(A.Frozen, frozen)
	if not f.IsDummy then
		f.Root.Anchored = frozen
	end
	if frozen then
		Fighter.cancelPending(f)
		f.BlockHeld = false
	end
	Fighter.updateMovement(f)
end

function Fighter.setSaber(f: Fighter, on: boolean)
	f.SaberOn = on
	f.Model:SetAttribute(A.SaberOn, on)
end

function Fighter.resetVitals(f: Fighter)
	Fighter.cancelPending(f)
	f.Alive = true
	f.Health = f.MaxHealth
	f.Posture = f.MaxPosture
	f.Stamina = f.MaxStamina
	f.ComboIndex = 0
	f.LastLightEnd = 0
	f.NextActionAt = 0
	f.IFramesUntil = 0
	f.CounterUntil = 0
	f.ParryReadyAt = 0
	f.DodgeReadyAt = 0
	f.BlockHeld = false
	f.LastHitTaken = 0
	f.Model:SetAttribute(A.SaberLock, false)
	f.Model:SetAttribute(A.Combo, 0)
	Fighter.setState(f, "Idle")
	Fighter.writeAttributes(f)
end

-- Vrai si le combattant est en l'air (rayon vers le sol, personnages ignorés).
local airParams = RaycastParams.new()
airParams.FilterType = Enum.RaycastFilterType.Exclude
airParams.RespectCanCollide = true
airParams.IgnoreWater = false

function Fighter.isAirborne(f: Fighter): boolean
	if f.IsDummy then
		return false
	end
	local list: { Instance } = {}
	for model in State.fighters do
		table.insert(list, model)
	end
	airParams.FilterDescendantsInstances = list
	local probe = Config.Movement.AirProbe + f.Humanoid.HipHeight
	local hit = workspace:Raycast(f.Root.Position, Vector3.new(0, -probe, 0), airParams)
	return hit == nil
end

function Fighter.destroy(f: Fighter)
	Fighter.cancelPending(f)
	f.Maid:Clean()
	if f.Model.Parent then
		CollectionService:RemoveTag(f.Model, Config.FighterTag)
	end
end

return Fighter
