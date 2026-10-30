--!strict
-- CombatController : entrées de combat, prédiction légère, lames de tous les combattants, animations
-- répliquées, effets visuels et cinématiques.
--   M1 (clic gauche / R2 / bouton tactile) : coup léger (combo de WeaponData.ComboLength, variantes directionnelles)
--   M2 maintenu puis relâché (clic droit / L2) : coup lourd chargé brise-garde
--   F maintenu (L1) : garde ; R (R1) ou clic pendant la garde : parade parfaite
--   Q ou Ctrl gauche (X) : esquive dans la direction de déplacement (en arrière à l'arrêt)
-- Le serveur fait autorité : le client n'envoie que des intentions et annule sa prédiction en cas de refus.
-- Désactivé quand un menu est ouvert (attribut EB_MenuOpen du LocalPlayer ou MenuController.isOpen()).
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Maid = require(Shared.Util.Maid)
local FormData = require(Shared.Config.FormData)
local WeaponData = require(Shared.Config.WeaponData)
local SaberColors = require(Shared.Config.SaberColors)
local Config = require(Shared.Combat.CombatConfig)
local CombatMath = require(Shared.Combat.CombatMath)

local ProceduralAnimator = require(script.Parent.Parent.Combat.ProceduralAnimator)
local SaberVisual = require(script.Parent.Parent.Combat.SaberVisual)
local CameraFx = require(script.Parent.Parent.Combat.CameraFx)
local Vfx = require(script.Parent.Parent.Combat.Vfx)
local Cinematics = require(script.Parent.Parent.Combat.Cinematics)

local A = Config.Attr
local LAYER_ACTION = 1
local LAYER_EMOTE = 3

local CombatController = {}
CombatController.Priority = 40

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- Vues des combattants (lames + animations de posture)

type View = {
	Model: Model,
	Root: BasePart?,
	Humanoid: Humanoid?,
	Saber: SaberVisual.Saber?,
	SaberKey: string,
	Base: string?, -- clip de posture en cours (Idle / Run)
	BaseStop: (() -> ())?,
	StateStop: (() -> ())?, -- clip piloté par l'état (Block / Defeated)
	StateClip: string?,
	LastJump: number,
	IsLocal: boolean,
	Maid: Maid.Maid,
}

local views: { [Model]: View } = {}

local function attrString(m: Instance, name: string, default: string): string
	local v = m:GetAttribute(name)
	return if type(v) == "string" then v else default
end

local function attrNumber(m: Instance, name: string, default: number): number
	local v = m:GetAttribute(name)
	return if type(v) == "number" and v == v then v else default
end

local function formOf(m: Model): Types.FormDef
	return FormData.get(attrString(m, A.Form, FormData.Default)) or (FormData.get(FormData.Default) :: Types.FormDef)
end

local function weaponOf(m: Model): Types.WeaponDef
	return WeaponData.get(attrString(m, A.Weapon, WeaponData.Default)) or (WeaponData.get(WeaponData.Default) :: Types.WeaponDef)
end

local function glowOf(m: Instance?): Color3
	if m then
		local def = SaberColors.get(attrString(m, A.Color, SaberColors.Default))
		if def then
			return def.Glow
		end
	end
	return Color3.fromRGB(40, 120, 255)
end

local function rebuildSaber(v: View)
	local m = v.Model
	local weapon = attrString(m, A.Weapon, WeaponData.Default)
	local color = attrString(m, A.Color, SaberColors.Default)
	local key = weapon .. "|" .. color
	if v.Saber and v.SaberKey == key then
		return
	end
	local old = v.Saber
	if old then
		old:destroy()
		v.Saber = nil
	end
	v.SaberKey = key
	local s = SaberVisual.attach(m, weapon, color)
	if s then
		s:setOn(m:GetAttribute(A.SaberOn) == true, true)
		v.Saber = s
	end
end

local function setStateClip(v: View, clip: string?)
	if v.StateClip == clip then
		return
	end
	local stop = v.StateStop
	if stop then
		stop()
	end
	v.StateStop = nil
	v.StateClip = clip
	if clip then
		v.StateStop = ProceduralAnimator.play(v.Model, clip, { Looped = true })
	end
end

local function onState(v: View)
	local st = attrString(v.Model, A.State, "Idle")
	if st == "Blocking" then
		if not ProceduralAnimator.isPlaying(v.Model, "Block") then
			v.StateClip = nil
		end
		setStateClip(v, "Block")
	elseif st == "Dead" then
		setStateClip(v, "Defeated")
	else
		setStateClip(v, nil)
	end
end

local function removeView(m: Model)
	local v = views[m]
	if not v then
		return
	end
	views[m] = nil
	v.Maid:Clean()
	local s = v.Saber
	if s then
		s:destroy()
	end
	ProceduralAnimator.release(m)
end

local function addView(m: Model)
	if views[m] or not m:IsA("Model") then
		return
	end
	local maid = Maid.new()
	local v: View = {
		Model = m,
		Root = nil,
		Humanoid = nil,
		Saber = nil,
		SaberKey = "",
		Base = nil,
		BaseStop = nil,
		StateStop = nil,
		StateClip = nil,
		LastJump = 0,
		IsLocal = m == player.Character,
		Maid = maid,
	}
	views[m] = v
	maid:Give(task.spawn(function()
		-- attendre le rig (mains) avant de souder les lames
		local hum0 = m:FindFirstChildOfClass("Humanoid") or m:WaitForChild("Humanoid", 5)
		local r6 = hum0 ~= nil and hum0:IsA("Humanoid") and hum0.RigType == Enum.HumanoidRigType.R6
		local hand = m:FindFirstChild(if r6 then "Right Arm" else "RightHand") or m:WaitForChild(if r6 then "Right Arm" else "RightHand", 5)
		local root = m:WaitForChild("HumanoidRootPart", 5)
		if views[m] ~= v then
			return
		end
		v.Root = if root and root:IsA("BasePart") then root else nil
		v.Humanoid = m:FindFirstChildOfClass("Humanoid")
		if hand then
			rebuildSaber(v)
		end
		onState(v)
	end))
	local function changed(name: string, fn: () -> ())
		maid:Give(m:GetAttributeChangedSignal(name):Connect(fn))
	end
	changed(A.Weapon, function()
		rebuildSaber(v)
		v.Base = nil
	end)
	changed(A.Color, function()
		rebuildSaber(v)
	end)
	changed(A.Form, function()
		v.Base = nil
	end)
	changed(A.SaberOn, function()
		local s = v.Saber
		if s then
			s:setOn(m:GetAttribute(A.SaberOn) == true, false)
		end
	end)
	changed(A.State, function()
		onState(v)
	end)
	maid:Give(m.AncestryChanged:Connect(function()
		if not m:IsDescendantOf(game) then
			removeView(m)
		end
	end))
end

-- Postures (Idle / Run selon la Voie), saut acrobatique du Faucon : 10 Hz.
local postureClock = 0
local function updatePostures(dt: number)
	postureClock += dt
	if postureClock < 0.1 then
		return
	end
	postureClock = 0
	local now = os.clock()
	for m, v in views do
		local root = v.Root
		local on = m:GetAttribute(A.SaberOn) == true
		local st = attrString(m, A.State, "Idle")
		local want: string? = nil
		local vy = 0
		if on and root and st ~= "Dead" then
			local vel = root.AssemblyLinearVelocity
			vy = vel.Y
			local moving: boolean
			local hum = v.Humanoid
			if v.IsLocal and hum then
				moving = hum.MoveDirection.Magnitude > 0.1
			else
				moving = Vector3.new(vel.X, 0, vel.Z).Magnitude > 3
			end
			want = if moving then "Run" else "Idle"
		end
		if want ~= v.Base or (want ~= nil and v.BaseStop == nil) then
			local stop = v.BaseStop
			if stop then
				stop()
			end
			v.BaseStop = if want then ProceduralAnimator.play(m, want) else nil
			v.Base = want
		end
		if on and vy > 14 and now - v.LastJump > 0.8 and attrString(m, A.Form, "") == "Faucon" and st ~= "Attacking" then
			v.LastJump = now
			ProceduralAnimator.play(m, "Jump")
		end
	end
end

--------------------------------------------------------------------------------
-- Déplacements locaux (esquive prédite, poussées serveur)

local motionMaid = Maid.new()

local function applyMotion(velocity: Vector3, duration: number)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or duration <= 0 then
		return
	end
	local att = root:FindFirstChild("RootAttachment")
	local created = false
	if not (att and att:IsA("Attachment")) then
		local a = Instance.new("Attachment")
		a.Name = "EB_MotionAttachment"
		a.Parent = root
		att = a
		created = true
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "EB_CombatMotion"
	lv.Attachment0 = att :: Attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(1e5, 0, 1e5)
	lv.VectorVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	lv.Parent = root
	motionMaid:Clean()
	motionMaid:Give(lv)
	if created then
		motionMaid:Give(att :: Instance)
	end
	motionMaid:Give(task.delay(duration, function()
		motionMaid:Clean()
	end))
end

--------------------------------------------------------------------------------
-- Entrées et prédiction

type Pred = { Action: string, Stop: (() -> ())?, At: number, PrevCombo: number, PrevLightEnd: number }

local seq = 0
local preds: { [number]: Pred } = {}
local comboIndex = 0
local lastLightEnd = 0
local nextActionAt = 0
local parryReadyAt = 0
local dodgeReadyAt = 0
local counterUntil = 0
local chargeStart: number? = nil
local chargeStop: (() -> ())? = nil
local chargeSeq = 0
local blockHeld = false
local blockStop: (() -> ())? = nil
local menuController: any = nil
local menuLookup = false

local function menuOpen(): boolean
	if player:GetAttribute("EB_MenuOpen") == true then
		return true
	end
	if not menuLookup then
		menuLookup = true
		local mod = script.Parent:FindFirstChild("MenuController")
		if mod and mod:IsA("ModuleScript") then
			local ok, res = pcall(require, mod)
			if ok and type(res) == "table" and type((res :: any).isOpen) == "function" then
				menuController = res
			end
		end
	end
	local mc = menuController
	if mc then
		local ok, res = pcall(mc.isOpen)
		return ok and res == true
	end
	return false
end

local function myView(): View?
	local c = player.Character
	return if c then views[c] else nil
end

local function myRoot(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- Peut-on envoyer une intention ? (le serveur revérifie tout)
local function canInput(): boolean
	local c = player.Character
	if not c or not views[c] or menuOpen() then
		return false
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	if c:GetAttribute(A.Frozen) == true or c:GetAttribute(A.SaberLock) == true then
		return false
	end
	local st = attrString(c, A.State, "Idle")
	return st ~= "Dead"
end

local function busyState(c: Model): boolean
	local st = attrString(c, A.State, "Idle")
	return st == "Stunned" or st == "GuardBroken" or st == "Dodging" or st == "Parrying" or st == "Dead"
end

local function send(action: string, dir: Vector3?): number
	seq = (seq + 1) % 2 ^ 30
	Net.event("CombatInput"):FireServer(action, dir, workspace:GetServerTimeNow(), seq)
	return seq
end

local function remember(s: number, action: string, stop: (() -> ())?)
	preds[s] = { Action = action, Stop = stop, At = os.clock(), PrevCombo = comboIndex, PrevLightEnd = lastLightEnd }
end

local function stopLocalEmote(c: Model)
	if ProceduralAnimator.current(c, LAYER_EMOTE) ~= nil then
		ProceduralAnimator.stopAll(c, LAYER_EMOTE)
		Net.event("StopEmote"):FireServer()
	end
end

local function moveDir(): Vector3?
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum and hum.MoveDirection.Magnitude > 0.1 then
		return hum.MoveDirection.Unit
	end
	return nil
end

-- Lame éteinte : dans le Hub, la première intention l'allume (consommée par le serveur).
local function needsIgnite(c: Model): boolean
	if c:GetAttribute(A.SaberOn) == true then
		return false
	end
	if c:GetAttribute(A.InDuel) ~= true then
		local now = os.clock()
		if now >= nextActionAt then
			nextActionAt = now + Config.Hub.IgniteLock
			send("Light", nil)
			ProceduralAnimator.play(c, "Ignite")
		end
	end
	return true
end

local function doUltimate()
	local c = player.Character
	if not c or not canInput() then
		return
	end
	if attrNumber(c, "Ultimate", 0) < Config.Ultimate.Max then
		return
	end
	send("Ultimate", nil)
end

local function doParry()
	local c = player.Character
	if not c or not canInput() or needsIgnite(c) then
		return
	end
	local now = os.clock()
	local st = attrString(c, A.State, "Idle")
	if now < parryReadyAt or (st ~= "Blocking" and st ~= "Idle") then
		return
	end
	local form, weapon = formOf(c), weaponOf(c)
	if attrNumber(c, A.Stamina, 100) < Config.Parry.StaminaCost * CombatMath.staminaMult(form, weapon) then
		return
	end
	stopLocalEmote(c)
	parryReadyAt = now + CombatMath.parryWindow(form) + Config.Parry.WhiffCooldown
	local stop = ProceduralAnimator.play(c, "Parry")
	remember(send("Parry", nil), "Parry", stop)
end

local function doLight()
	local c = player.Character
	if not c or not canInput() then
		return
	end
	if blockHeld then
		doParry() -- clic pendant la garde = parade
		return
	end
	if needsIgnite(c) or chargeStart ~= nil or busyState(c) then
		return
	end
	local now = os.clock()
	if now < nextActionAt - Config.Input.Buffer then
		return
	end
	local form, weapon = formOf(c), weaponOf(c)
	if attrNumber(c, A.Stamina, 100) < Config.Light.StaminaCost * CombatMath.staminaMult(form, weapon) then
		return
	end
	stopLocalEmote(c)
	local root = myRoot()
	local dir = moveDir()
	local counter = now <= counterUntil
	local delayS = math.max(0, nextActionAt - now)
	local idx = CombatMath.nextCombo(comboIndex, lastLightEnd, now + delayS, weapon)
	local variant = CombatMath.variant(if root then root.CFrame.LookVector else Vector3.new(0, 0, -1), dir)
	local hum = c:FindFirstChildOfClass("Humanoid")
	local airborne = hum ~= nil and hum.FloorMaterial == Enum.Material.Air
	local timing = CombatMath.lightTiming(form, weapon, idx, variant, counter)
	local s = send("Light", dir)
	remember(s, "Light", nil)
	comboIndex = idx
	if counter then
		counterUntil = 0
	end
	nextActionAt = now + delayS + timing.Windup + timing.Recovery
	lastLightEnd = nextActionAt
	local clip = CombatMath.lightClip(idx, variant, airborne, counter)
	local function start()
		local pred = preds[s]
		if pred == nil then
			return -- refusé entre-temps
		end
		pred.Stop = ProceduralAnimator.play(c, clip, { Speed = timing.Speed })
	end
	if delayS > 0 then
		task.delay(delayS, start)
	else
		start()
	end
end

local function releaseHeavy(auto: boolean)
	local c = player.Character
	local start = chargeStart
	if not c or not start then
		return
	end
	chargeStart = nil
	local cs = chargeStop
	chargeStop = nil
	if cs then
		cs()
	end
	if not auto and not canInput() then
		send("Heavy", nil)
		return
	end
	local now = os.clock()
	local form, weapon = formOf(c), weaponOf(c)
	local timing = CombatMath.heavyTiming(form, weapon, now - start)
	nextActionAt = now + timing.Windup + timing.Recovery
	comboIndex = 0
	local s = send("Heavy", nil)
	local stop = ProceduralAnimator.play(c, "M2_Strike", { Speed = timing.Speed })
	remember(s, "HeavyRelease", stop)
end

local function heavyBegin()
	local c = player.Character
	if not c or not canInput() or needsIgnite(c) or chargeStart ~= nil or busyState(c) then
		return
	end
	local now = os.clock()
	if now < nextActionAt then
		return
	end
	local form, weapon = formOf(c), weaponOf(c)
	if attrNumber(c, A.Stamina, 100) < Config.Heavy.StaminaCost * CombatMath.staminaMult(form, weapon) then
		return
	end
	stopLocalEmote(c)
	if blockHeld then
		blockHeld = false
		send("BlockEnd", nil)
		local bs = blockStop
		blockStop = nil
		if bs then
			bs()
		end
	end
	chargeStart = now
	local stop = ProceduralAnimator.play(c, "M2_Charge", { Looped = true })
	chargeStop = stop
	local s = send("Heavy", nil)
	chargeSeq = s
	remember(s, "HeavyCharge", stop)
	task.delay(Config.Heavy.MaxCharge, function()
		if chargeStart == now then
			releaseHeavy(true)
		end
	end)
end

local function heavyEnd()
	if chargeStart ~= nil then
		releaseHeavy(false)
	end
end

local function blockBegin()
	local c = player.Character
	if not c or not canInput() or needsIgnite(c) then
		return
	end
	blockHeld = true
	stopLocalEmote(c)
	send("BlockStart", nil)
	if chargeStart == nil and not busyState(c) and os.clock() >= nextActionAt - 0.05 then
		local bs = blockStop
		if bs then
			bs()
		end
		blockStop = ProceduralAnimator.play(c, "Block", { Looped = true })
	end
end

local function blockEnd()
	if not blockHeld then
		return
	end
	blockHeld = false
	send("BlockEnd", nil)
	local bs = blockStop
	blockStop = nil
	if bs then
		bs()
	end
	local c = player.Character
	if c then
		local v = views[c]
		if v and v.StateClip == "Block" then
			setStateClip(v, nil)
		end
	end
end

local function doDodge()
	local c = player.Character
	if not c or not canInput() or needsIgnite(c) or busyState(c) or chargeStart ~= nil then
		return
	end
	local now = os.clock()
	if now < dodgeReadyAt then
		return
	end
	local form, weapon = formOf(c), weaponOf(c)
	if attrNumber(c, A.Stamina, 100) < Config.Dodge.StaminaCost * CombatMath.staminaMult(form, weapon) then
		return
	end
	local root = myRoot()
	if not root then
		return
	end
	stopLocalEmote(c)
	local dir = moveDir()
	local v: Vector3
	if dir then
		v = dir
	else
		local look = root.CFrame.LookVector
		v = -Vector3.new(look.X, 0, look.Z)
		v = if v.Magnitude > 1e-3 then v.Unit else Vector3.new(0, 0, 1)
	end
	local dur = CombatMath.dodgeDuration(form)
	dodgeReadyAt = now + dur + Config.Dodge.Cooldown
	nextActionAt = math.max(nextActionAt, now + dur)
	local letter = CombatMath.dodgeLetter(root.CFrame, v)
	local stop = ProceduralAnimator.play(c, "Dodge_" .. letter, { Speed = Config.Dodge.Duration / dur })
	applyMotion(v * (Config.Dodge.Distance / dur), dur)
	remember(send("Dodge", v), "Dodge", stop)
end

-- Refus serveur : annule la prédiction correspondante.
local function onReject(action: any, reason: any, s: any)
	if type(s) ~= "number" then
		return
	end
	local p = preds[s]
	if not p then
		return
	end
	preds[s] = nil
	local stop = p.Stop
	if stop then
		stop()
	end
	if p.Action == "Light" then
		comboIndex = p.PrevCombo
		lastLightEnd = p.PrevLightEnd
		nextActionAt = os.clock()
	elseif p.Action == "Dodge" then
		motionMaid:Clean()
		dodgeReadyAt = os.clock()
	elseif p.Action == "HeavyCharge" then
		if chargeSeq == s then
			chargeStart = nil
			chargeStop = nil
		end
		nextActionAt = os.clock()
	elseif p.Action == "Parry" then
		parryReadyAt = os.clock() + 0.1
	end
	if reason == "stamina" then
		CameraFx.shake(0.05)
	end
end

-- Liaison des actions (clavier, souris, manette, boutons tactiles).
type Handler = (Enum.UserInputState) -> ()

local function bind(name: string, title: string, handler: Handler, position: UDim2, ...: Enum.KeyCode | Enum.UserInputType)
	local inputs = { ... }
	ContextActionService:BindActionAtPriority(name, function(_n: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		local mouse = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
		if state == Enum.UserInputState.Begin and not canInput() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin or state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			handler(state)
		end
		-- les clics souris continuent vers la caméra et l'interface
		return if mouse then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
	end, UserInputService.TouchEnabled, Enum.ContextActionPriority.Default.Value, table.unpack(inputs))
	if UserInputService.TouchEnabled then
		ContextActionService:SetTitle(name, title)
		ContextActionService:SetPosition(name, position)
	end
end

local function bindInputs()
	bind("EB_Light", "Frappe", function(s: Enum.UserInputState)
		if s == Enum.UserInputState.Begin then
			doLight()
		end
	end, UDim2.new(1, -95, 1, -150), Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	bind("EB_Heavy", "Lourd", function(s: Enum.UserInputState)
		if s == Enum.UserInputState.Begin then
			heavyBegin()
		else
			heavyEnd()
		end
	end, UDim2.new(1, -170, 1, -110), Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	bind("EB_Block", "Garde", function(s: Enum.UserInputState)
		if s == Enum.UserInputState.Begin then
			blockBegin()
		else
			blockEnd()
		end
	end, UDim2.new(1, -170, 1, -190), Enum.KeyCode.F, Enum.KeyCode.ButtonL1)
	bind("EB_Parry", "Parade", function(s: Enum.UserInputState)
		if s == Enum.UserInputState.Begin then
			doParry()
		end
	end, UDim2.new(1, -95, 1, -225), Enum.KeyCode.R, Enum.KeyCode.ButtonR1)
	bind("EB_Ultimate", "Ultime", function(s: Enum.UserInputState)
		if s == Enum.UserInputState.Begin then
			doUltimate()
		end
	end, UDim2.new(1, -245, 1, -230), Enum.KeyCode.G, Enum.KeyCode.ButtonY)
	bind("EB_Dodge", "Esquive", function(s: Enum.UserInputState)
		if s == Enum.UserInputState.Begin then
			doDodge()
		end
	end, UDim2.new(1, -245, 1, -150), Enum.KeyCode.Q, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonX)
end

--------------------------------------------------------------------------------
-- Événements serveur

local function asModel(v: any): Model?
	if typeof(v) == "Instance" and (v :: Instance):IsA("Model") then
		return v :: Model
	end
	return nil
end

local function involvesMe(...: any): boolean
	local c = player.Character
	if not c then
		return false
	end
	for _, m in { ... } do
		if m == c then
			return true
		end
	end
	return false
end

local function onAnim(model: any, clipId: any, speed: any)
	local m = asModel(model)
	if not m or type(clipId) ~= "string" then
		return
	end
	local sp = if type(speed) == "number" and speed == speed and speed > 0 and speed < 10 then speed else 1
	if ProceduralAnimator.current(m, LAYER_EMOTE) ~= nil then
		ProceduralAnimator.stopAll(m, LAYER_EMOTE) -- toute action interrompt une emote
	end
	local looped = clipId == "M2_Charge"
	if clipId == "Flinch" then
		ProceduralAnimator.stopAll(m, LAYER_ACTION) -- le coup en cours est annulé par le serveur
	end
	ProceduralAnimator.play(m, clipId, { Speed = sp, Looped = if looped then true else nil })
	if m == player.Character then
		-- l'état subi interrompt la prédiction locale (le clip a déjà remplacé la couche d'action)
		local now = os.clock()
		if clipId == "Stunned" or clipId == "GuardBroken" then
			chargeStart = nil
			chargeStop = nil
			nextActionAt = now + (if clipId == "Stunned" then Config.Parry.AttackerStun / sp else Config.GuardBroken.Duration)
		elseif clipId == "Flinch" then
			nextActionAt = math.max(nextActionAt, now + Config.Light.HitStun)
		end
	end
end

local function hitStop(models: { Model }, seconds: number)
	for _, m in models do
		ProceduralAnimator.hitStop(m, seconds)
	end
end

local function onFx(kind: any, data: any)
	if type(kind) ~= "string" or type(data) ~= "table" then
		return
	end
	local pos = data.Position
	if typeof(pos) ~= "Vector3" then
		return
	end
	local attacker = asModel(data.Attacker)
	local target = asModel(data.Target)
	local color = glowOf(attacker or target)
	local mine = involvesMe(attacker, target)
	local heavy = data.Heavy == true
	local cam = Config.Camera
	local both: { Model } = {}
	if attacker then
		table.insert(both, attacker)
	end
	if target then
		table.insert(both, target)
	end
	if kind == "Hit" then
		Vfx.impact(pos, color, heavy)
		hitStop(both, if heavy then cam.HitStopHeavy else cam.HitStopLight)
		if mine then
			CameraFx.shake(if heavy then cam.ShakeHeavy else cam.ShakeLight)
			if target == player.Character then
				CameraFx.colorPulse(Color3.fromRGB(255, 190, 190), 0, 0.1, 0, 0.25)
			end
		end
		if data.Finisher == true or data.Counter == true then
			Vfx.shockwave(pos - Vector3.new(0, 1, 0), color, 4, 0.3)
		end
	elseif kind == "Block" then
		Vfx.clash(pos, color:Lerp(glowOf(target), 0.5), heavy)
		hitStop(both, if heavy then cam.HitStopHeavy * 0.7 else cam.HitStopLight)
		if mine then
			CameraFx.shake(if heavy then cam.ShakeHeavy * 0.6 else cam.ShakeLight * 0.6)
		end
	elseif kind == "Parry" then
		Vfx.parry(pos, glowOf(target))
		hitStop(both, cam.HitStopParry)
		if mine then
			CameraFx.shake(cam.ShakeParry)
			CameraFx.fovPunch(62, 0.06, 0.05, 0.25)
		end
		if target == player.Character then
			local cw = data.CounterWindow
			if type(cw) == "number" and cw > 0 then
				counterUntil = os.clock() + cw
			end
			parryReadyAt = os.clock()
			nextActionAt = os.clock()
		end
	elseif kind == "GuardBreak" then
		Vfx.guardBreak(pos, glowOf(attacker or target))
		if mine then
			CameraFx.shake(cam.ShakeGuardBreak)
			CameraFx.colorPulse(Color3.fromRGB(255, 220, 200), -0.3, 0.2, 0.05, 0.5)
		end
	elseif kind == "Evade" then
		Vfx.sound(Config.Sounds.Lunge, pos, 0.4, 1.4)
	elseif kind == "Dodge" then
		Vfx.dodge(pos, color)
	elseif kind == "KO" then
		Vfx.ko(pos, color)
		if mine then
			CameraFx.shake(0.5)
		end
	elseif kind == "Respawn" then
		Vfx.flash(pos, color, 4, 0.4)
	end
end

local function onImpulse(velocity: any, duration: any)
	if typeof(velocity) ~= "Vector3" or type(duration) ~= "number" then
		return
	end
	if velocity.Magnitude > 200 or duration <= 0 or duration > 2 then
		return
	end
	applyMotion(velocity, duration)
end

local function onSaberLock(a: any, b: any, point: any, duration: any)
	local ma, mb = asModel(a), asModel(b)
	if not ma or not mb or typeof(point) ~= "Vector3" or type(duration) ~= "number" then
		return
	end
	if involvesMe(ma, mb) then
		chargeStart = nil
		chargeStop = nil
		blockStop = nil
		nextActionAt = os.clock() + duration + Config.Clash.RecoveryAfter
	end
	Cinematics.saberLock(ma, mb, point, math.clamp(duration, 0.2, 4))
end

local function onCinematic(kind: any, data: any)
	if type(data) ~= "table" then
		return
	end
	if kind == "Intro" then
		task.spawn(Cinematics.intro, data)
	elseif kind == "Finisher" then
		task.spawn(Cinematics.finisher, data)
	end
end

--------------------------------------------------------------------------------
-- Cycle de vie

function CombatController.init()
	for _, m in CollectionService:GetTagged(Config.FighterTag) do
		if m:IsA("Model") then
			addView(m)
		end
	end
	CollectionService:GetInstanceAddedSignal(Config.FighterTag):Connect(function(m: Instance)
		if m:IsA("Model") then
			addView(m)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(Config.FighterTag):Connect(function(m: Instance)
		if m:IsA("Model") then
			removeView(m)
		end
	end)
	player.CharacterAdded:Connect(function(c: Model)
		-- nouveau personnage : on repart de zéro côté prédiction
		comboIndex, lastLightEnd, nextActionAt = 0, 0, 0
		chargeStart, chargeStop, blockStop = nil, nil, nil
		blockHeld = false
		table.clear(preds)
		motionMaid:Clean()
		local v = views[c]
		if v then
			v.IsLocal = true
		end
	end)

	Net.event("CombatAnim").OnClientEvent:Connect(onAnim)
	Net.event("CombatFx").OnClientEvent:Connect(onFx)
	Net.event("CombatImpulse").OnClientEvent:Connect(onImpulse)
	Net.event("CombatReject").OnClientEvent:Connect(onReject)
	Net.event("CombatSaberLock").OnClientEvent:Connect(onSaberLock)
	Net.event("CombatCinematic").OnClientEvent:Connect(onCinematic)

	RunService.Heartbeat:Connect(function(dt: number)
		updatePostures(dt)
		-- oubli des prédictions trop anciennes (aucun refus reçu = acceptée)
		local now = os.clock()
		for s, p in preds do
			if now - p.At > 2 then
				preds[s] = nil
			end
		end
		-- garde relâchée hors fenêtre (menu ouvert, perte de focus)
		if blockHeld and menuOpen() then
			blockEnd()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		blockEnd()
		heavyEnd()
	end)
end

function CombatController.start()
	bindInputs()
end

return CombatController
