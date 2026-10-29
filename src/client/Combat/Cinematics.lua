--!strict
-- Cinématiques de combat (client) :
--   intro de duel (3-4 s) depuis Arena.IntroCam, gros plan sur l'adversaire à l'allumage synchronisé des lames,
--     visages éclairés par les lames, plan large, retour fluide à la caméra de jeu ;
--   Saber Lock : lames bloquées, gerbes d'étincelles, zoom + ralenti visuel pendant la durée du blocage ;
--   exécution finale (2-3 s) : plan propre à la Voie du vainqueur et à son arme, impact au ralenti.
-- Les animations sont jouées chez tous les clients qui reçoivent l'événement ; la caméra n'est prise
-- que chez les deux duellistes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Config = require(Shared.Combat.CombatConfig)
local SaberColors = require(Shared.Config.SaberColors)

local ProceduralAnimator = require(script.Parent.ProceduralAnimator)
local CameraFx = require(script.Parent.CameraFx)
local Vfx = require(script.Parent.Vfx)

local Cinematics = {}

local UP = Vector3.yAxis
local ease = CameraFx.ease

--------------------------------------------------------------------------------
-- Utilitaires

local function partOf(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function rootOf(model: Model): BasePart?
	return partOf(model, "HumanoidRootPart") or model.PrimaryPart
end

local function headOf(model: Model): BasePart?
	return partOf(model, "Head") or rootOf(model)
end

local function chestOf(model: Model): Vector3
	local t = partOf(model, "UpperTorso") or partOf(model, "Torso") or rootOf(model)
	return if t then t.Position else model:GetPivot().Position
end

local function glowOf(model: Model): Color3
	local id = model:GetAttribute(Config.Attr.Color)
	local def = if type(id) == "string" then SaberColors.get(id) else nil
	return if def then def.Glow else Color3.fromRGB(40, 120, 255)
end

local function localCharacter(): Model?
	return Players.LocalPlayer.Character
end

local function isModel(v: any): boolean
	return typeof(v) == "Instance" and (v :: Instance):IsA("Model")
end

-- Bandes noires de cinéma (ScreenGui local, retiré à la fin).
local function letterbox(duration: number)
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "EB_Cinematic"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false
	local bars: { Frame } = {}
	for i = 1, 2 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.AnchorPoint = Vector2.new(0, if i == 1 then 0 else 1)
		f.Position = UDim2.fromScale(0, if i == 1 then 0 else 1)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = gui
		table.insert(bars, f)
	end
	gui.Parent = pg
	for _, f in bars do
		TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 0.11) }):Play()
	end
	task.delay(math.max(0.4, duration - 0.35), function()
		for _, f in bars do
			TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 0) }):Play()
		end
		task.wait(0.4)
		gui:Destroy()
	end)
end

-- Lumière de visage (reflet de la lame allumée).
local function faceLight(model: Model, duration: number)
	local head = headOf(model)
	if not head then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "EB_FaceLight"
	light.Color = glowOf(model)
	light.Brightness = 0
	light.Range = 7
	light.Shadows = false
	light.Parent = head
	TweenService:Create(light, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 3 }):Play()
	task.delay(0.6, function()
		if light.Parent then
			TweenService:Create(light, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Brightness = 1.1 }):Play()
		end
	end)
	task.delay(duration, function()
		if light.Parent then
			local tw = TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Brightness = 0 })
			tw:Play()
			tw.Completed:Wait()
		end
		light:Destroy()
	end)
end

-- Plan de retour : du dernier CFrame vers la caméra de jeu derrière le personnage local.
local function returnFrom(from: CFrame, t: number, duration: number): CFrame
	local char = localCharacter()
	local root = if char then rootOf(char) else nil
	if not root then
		return from
	end
	return from:Lerp(CameraFx.gameplayCFrame(root), ease(math.clamp(t / duration, 0, 1)))
end

--------------------------------------------------------------------------------
-- Intro de duel

function Cinematics.intro(data: { [string]: any })
	local a, b = data.A, data.B
	if not isModel(a) or not isModel(b) then
		return
	end
	local ma, mb = a :: Model, b :: Model
	local duration = if type(data.Duration) == "number" then data.Duration else Config.Intro.Duration
	local igniteAt = if type(data.IgniteAt) == "number" then data.IgniteAt else Config.Intro.IgniteAt
	local introCam: CFrame = if typeof(data.IntroCam) == "CFrame" then data.IntroCam else ma:GetPivot() * CFrame.new(10, 4, 0)

	ProceduralAnimator.play(ma, "Intro")
	ProceduralAnimator.play(mb, "Intro")
	task.delay(igniteAt, function()
		faceLight(ma, duration - igniteAt + 0.6)
		faceLight(mb, duration - igniteAt + 0.6)
	end)

	local me = localCharacter()
	if me ~= ma and me ~= mb then
		return
	end
	local opp = if me == ma then mb else ma
	letterbox(duration)

	local ret = Config.Intro.ReturnTime
	local closeTime = math.min(0.95, math.max(0.3, (duration - igniteAt - ret) * 0.5))
	local wideStart = igniteAt + closeTime
	local wideLen = math.max(0.1, duration - ret - wideStart)
	local push = introCam * CFrame.new(0, 0, -3.5)
	local lastCf = introCam

	local function wide(k: number): CFrame
		local pa, pb = ma:GetPivot().Position, mb:GetPivot().Position
		local mid = (pa + pb) * 0.5 + Vector3.new(0, 1.6, 0)
		local axis = pb - pa
		local side = axis:Cross(UP)
		side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
		local ang = math.rad(-18 + 36 * k)
		local dir = CFrame.fromAxisAngle(UP, ang):VectorToWorldSpace(side)
		local dist = math.max(11, axis.Magnitude * 0.9)
		return CFrame.lookAt(mid + dir * dist + Vector3.new(0, 3.2 - k, 0), mid)
	end

	local owned = CameraFx.runShot(duration, function(t: number, _dt: number): CFrame
		local cf: CFrame
		if t < igniteAt then
			cf = introCam:Lerp(push, ease(t / igniteAt))
		elseif t < wideStart then
			local k = (t - igniteAt) / closeTime
			local head = headOf(opp)
			if head then
				local hcf = head.CFrame
				local dist = 3.6 - 0.7 * k
				local eye = hcf.Position + hcf.LookVector * dist + hcf.RightVector * 1.1 + Vector3.new(0, 0.25, 0)
				cf = CFrame.lookAt(eye, hcf.Position + Vector3.new(0, 0.05, 0))
			else
				cf = push
			end
		elseif t < duration - ret then
			cf = wide((t - wideStart) / wideLen)
			lastCf = cf
		else
			cf = returnFrom(lastCf, t - (duration - ret), ret)
		end
		return cf
	end)
	if owned then
		CameraFx.release() -- sauf si une autre cinématique a pris la main entre-temps
	end
end

--------------------------------------------------------------------------------
-- Saber Lock

function Cinematics.saberLock(a: Model, b: Model, point: Vector3, duration: number)
	local stopA = ProceduralAnimator.play(a, "SaberLock", { Looped = true })
	local stopB = ProceduralAnimator.play(b, "SaberLock", { Looped = true })
	local ca, cb = glowOf(a), glowOf(b)
	Vfx.clash(point, ca:Lerp(cb, 0.5), true)
	local me = localCharacter()
	local involved = me == a or me == b
	local near = involved or (workspace.CurrentCamera.CFrame.Position - point).Magnitude <= Config.Camera.LockRange
	if near then
		CameraFx.fovPunch(Config.Camera.LockFov, 0.25, math.max(0, duration - 0.6), 0.35)
		ProceduralAnimator.slowMotion(Config.Camera.LockTimeScale, duration)
		CameraFx.colorPulse(Color3.fromRGB(255, 236, 220), 0.25, 0.25, 0.04, duration)
		CameraFx.shake(0.35)
	end
	task.spawn(function()
		local elapsed = 0
		local flashClock = 0
		while elapsed < duration and a.Parent and b.Parent do
			local dt = task.wait(0.09)
			elapsed += dt
			flashClock += dt
			Vfx.sparks(point, if math.random() < 0.5 then ca else cb, 7, 16)
			if flashClock >= 0.3 then
				flashClock = 0
				Vfx.flash(point, ca:Lerp(cb, math.random()), 2, 0.2)
				if near then
					CameraFx.shake(0.08)
				end
			end
		end
		stopA()
		stopB()
		Vfx.shockwave(point - Vector3.new(0, 1.4, 0), ca:Lerp(cb, 0.5), 7, 0.4)
		Vfx.clash(point, ca:Lerp(cb, 0.5), true)
		if near then
			CameraFx.shake(0.5)
		end
	end)
end

--------------------------------------------------------------------------------
-- Exécution finale

type ShotStyle = { Radius: number, Height: number, Sweep: number, LookUp: number, Handheld: boolean, Side: number }

local SHOTS: { [string]: ShotStyle } = {
	Origine = { Radius = 9, Height = 2.6, Sweep = 70, LookUp = 0, Handheld = false, Side = 1 },
	Duelliste = { Radius = 7.5, Height = 1.6, Sweep = 18, LookUp = 0, Handheld = false, Side = 1 },
	Rempart = { Radius = 10.5, Height = 3.6, Sweep = 12, LookUp = -0.5, Handheld = false, Side = 0.25 },
	Faucon = { Radius = 8, Height = 0.4, Sweep = 55, LookUp = 3, Handheld = false, Side = -1 },
	Riposte = { Radius = 5.5, Height = 2.4, Sweep = 28, LookUp = 0.4, Handheld = false, Side = -0.6 },
	Equilibre = { Radius = 11, Height = 5.5, Sweep = 110, LookUp = -0.6, Handheld = false, Side = 1 },
	Tempete = { Radius = 6.5, Height = 2, Sweep = 60, LookUp = 0, Handheld = true, Side = -1 },
}

function Cinematics.finisher(data: { [string]: any })
	local w, l = data.Winner, data.Loser
	if not isModel(w) or not isModel(l) then
		return
	end
	local winner, loser = w :: Model, l :: Model
	local duration = if type(data.Duration) == "number" then data.Duration else Config.Finisher.Duration
	local strikeAt = if type(data.StrikeAt) == "number" then data.StrikeAt else Config.Finisher.StrikeAt
	local formAttr = winner:GetAttribute(Config.Attr.Form)
	local weaponAttr = winner:GetAttribute(Config.Attr.Weapon)
	local form = if type(formAttr) == "string" then formAttr else "Origine"
	local weapon = if type(weaponAttr) == "string" then weaponAttr else "Single"
	local shot = SHOTS[form] or SHOTS.Origine
	local color = glowOf(winner)

	-- l'exécution démarre légèrement après la réception : le serveur vient de replacer le perdant
	ProceduralAnimator.stopAll(winner)
	ProceduralAnimator.stopAll(loser)
	ProceduralAnimator.play(winner, "Finisher")
	ProceduralAnimator.play(loser, "Finisher_Victim")

	local me = localCharacter()
	local involved = me == winner or me == loser
	local near = involved or (workspace.CurrentCamera.CFrame.Position - chestOf(loser)).Magnitude <= Config.Camera.LockRange

	if weapon == "Dual" then
		task.delay(math.max(0, strikeAt - 0.16), function()
			local pos = chestOf(loser)
			Vfx.impact(pos, color, false)
		end)
	end
	task.delay(strikeAt, function()
		local pos = chestOf(loser)
		Vfx.impact(pos, color, true)
		Vfx.flash(pos, color, 8, 0.45)
		Vfx.shockwave(pos - Vector3.new(0, 1.5, 0), color, if weapon == "Staff" then 11 else 8, 0.5)
		if near then
			ProceduralAnimator.slowMotion(0.25, 0.45)
			CameraFx.shake(0.65)
			CameraFx.colorPulse(color:Lerp(Color3.new(1, 1, 1), 0.6), -0.35, 0.3, 0.08, 0.9)
		end
	end)

	if not involved then
		return
	end
	letterbox(duration)
	local ret = 0.5
	local radius = shot.Radius + (if weapon == "Staff" then 1.5 else 0)
	local wp, lp = winner:GetPivot().Position, loser:GetPivot().Position
	local mid = (wp + lp) * 0.5 + Vector3.new(0, 1.4, 0)
	local axis = lp - wp
	local side = axis:Cross(UP)
	side = if side.Magnitude > 1e-3 then side.Unit * shot.Side else Vector3.xAxis
	if side.Magnitude < 1e-3 then
		side = Vector3.xAxis
	end
	local lastCf = CFrame.lookAt(mid + side.Unit * radius, mid)
	local handClock = 0

	local owned = CameraFx.runShot(duration, function(t: number, dt: number): CFrame
		if t >= duration - ret then
			return returnFrom(lastCf, t - (duration - ret), ret)
		end
		local k = t / (duration - ret)
		-- léger rapprochement au moment du coup
		local punch = if t > strikeAt - 0.2 and t < strikeAt + 0.5 then 1 - math.abs(t - strikeAt) / 0.5 else 0
		local ang = math.rad(-shot.Sweep * 0.5 + shot.Sweep * ease(k))
		local dir = CFrame.fromAxisAngle(UP, ang):VectorToWorldSpace(side.Unit)
		local dist = radius * (1 - 0.18 * math.max(0, punch))
		local eye = mid + dir * dist + Vector3.new(0, shot.Height, 0)
		local cf = CFrame.lookAt(eye, mid + Vector3.new(0, shot.LookUp * 0.3, 0))
		if shot.Handheld then
			handClock += dt
			if handClock > 0.18 then
				handClock = 0
				CameraFx.shake(0.06)
			end
		end
		lastCf = cf
		return cf
	end)
	if owned then
		CameraFx.release() -- sauf si une autre cinématique a pris la main entre-temps
	end
end

return Cinematics
