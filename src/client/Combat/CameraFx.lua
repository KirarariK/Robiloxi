--!strict
-- CameraFx : tremblement de caméra (modèle à « trauma »), coups de zoom (FOV), pulsations de couleur et de flou,
-- et prise de contrôle de la caméra pour les cinématiques (plans scriptés, retour fluide à la caméra de jeu).
-- Une seule liaison de rendu pour le tremblement, appliquée APRÈS la caméra par défaut et les plans scriptés.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraFx = {}

local SHAKE_DECAY = 1.7 -- trauma perdu par seconde
local MAX_ANGLE = math.rad(2.4)
local MAX_OFFSET = 0.35
local NOISE_SPEED = 22

local trauma = 0
local seed = math.random() * 1000
local baseFov = 70
local fovTween: Tween? = nil
local fovToken = 0

local function camera(): Camera
	return workspace.CurrentCamera
end

local colorFx: ColorCorrectionEffect = Instance.new("ColorCorrectionEffect")
colorFx.Name = "EB_CombatColor"
colorFx.Enabled = false
colorFx.Parent = Lighting

local blurFx: BlurEffect = Instance.new("BlurEffect")
blurFx.Name = "EB_CombatBlur"
blurFx.Size = 0
blurFx.Enabled = false
blurFx.Parent = Lighting

--------------------------------------------------------------------------------
-- Tremblement

function CameraFx.shake(amount: number)
	if amount > 0 then
		trauma = math.min(1, trauma + amount)
	end
end

RunService:BindToRenderStep("EB_CameraShake", Enum.RenderPriority.Camera.Value + 20, function(dt: number)
	if trauma <= 0 then
		return
	end
	local cam = camera()
	local s = trauma * trauma
	local t = os.clock() * NOISE_SPEED
	local rx = math.noise(seed, t) * MAX_ANGLE * s
	local ry = math.noise(seed + 10, t) * MAX_ANGLE * s
	local rz = math.noise(seed + 20, t) * MAX_ANGLE * s * 0.6
	local ox = math.noise(seed + 30, t) * MAX_OFFSET * s
	local oy = math.noise(seed + 40, t) * MAX_OFFSET * s
	cam.CFrame = cam.CFrame * CFrame.new(ox, oy, 0) * CFrame.Angles(rx, ry, rz)
	trauma = math.max(0, trauma - SHAKE_DECAY * dt)
end)

--------------------------------------------------------------------------------
-- Champ de vision

-- Zoom vers `fov` en `inTime`, maintien `hold`, retour à la valeur de base en `outTime`.
function CameraFx.fovPunch(fov: number, inTime: number, hold: number, outTime: number)
	local cam = camera()
	fovToken += 1
	local my = fovToken
	if fovTween then
		fovTween:Cancel()
	end
	local tIn = TweenService:Create(cam, TweenInfo.new(inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov })
	fovTween = tIn
	tIn:Play()
	task.delay(inTime + hold, function()
		if fovToken ~= my then
			return
		end
		local tOut = TweenService:Create(cam, TweenInfo.new(outTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FieldOfView = baseFov })
		fovTween = tOut
		tOut:Play()
	end)
end

function CameraFx.resetFov()
	fovToken += 1
	if fovTween then
		fovTween:Cancel()
		fovTween = nil
	end
	camera().FieldOfView = baseFov
end

--------------------------------------------------------------------------------
-- Couleur et flou

local colorToken = 0
-- Teinte / saturation / contraste temporaires (ralenti, exécution, coups lourds).
function CameraFx.colorPulse(tint: Color3, saturation: number, contrast: number, brightness: number, duration: number)
	colorToken += 1
	local my = colorToken
	colorFx.Enabled = true
	colorFx.TintColor = tint
	colorFx.Saturation = saturation
	colorFx.Contrast = contrast
	colorFx.Brightness = brightness
	local tw = TweenService:Create(colorFx, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		TintColor = Color3.new(1, 1, 1),
		Saturation = 0,
		Contrast = 0,
		Brightness = 0,
	})
	tw:Play()
	task.delay(duration + 0.05, function()
		if colorToken == my then
			colorFx.Enabled = false
		end
	end)
end

local blurToken = 0
function CameraFx.blurPulse(size: number, duration: number)
	blurToken += 1
	local my = blurToken
	blurFx.Enabled = true
	blurFx.Size = math.max(blurFx.Size, size)
	local tw = TweenService:Create(blurFx, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 })
	tw:Play()
	task.delay(duration + 0.05, function()
		if blurToken == my then
			blurFx.Enabled = false
		end
	end)
end

--------------------------------------------------------------------------------
-- Cinématiques : plans scriptés

export type ShotFn = (t: number, dt: number) -> CFrame

local shotToken = 0
local SHOT_BIND = "EB_CinematicCamera"

-- Prend la main sur la caméra pendant `duration` s ; `fn(t, dt)` renvoie le CFrame (t de 0 à duration).
-- Rend la main (CameraType.Custom) à la fin, sauf si un autre plan a commencé entre-temps. Bloquant.
function CameraFx.runShot(duration: number, fn: ShotFn): boolean
	shotToken += 1
	local my = shotToken
	local cam = camera()
	cam.CameraType = Enum.CameraType.Scriptable
	local elapsed = 0
	pcall(function()
		RunService:UnbindFromRenderStep(SHOT_BIND)
	end)
	local done = false
	RunService:BindToRenderStep(SHOT_BIND, Enum.RenderPriority.Camera.Value + 10, function(dt: number)
		if shotToken ~= my then
			return
		end
		elapsed = math.min(duration, elapsed + dt)
		local ok, cf = pcall(fn, elapsed, dt)
		if ok and typeof(cf) == "CFrame" then
			cam.CFrame = cf
			cam.Focus = cf * CFrame.new(0, 0, -8)
		end
		if elapsed >= duration then
			done = true
		end
	end)
	while not done and shotToken == my do
		task.wait()
	end
	if shotToken == my then
		RunService:UnbindFromRenderStep(SHOT_BIND)
	end
	return shotToken == my
end

-- Termine tout plan scripté et rend la caméra au joueur.
function CameraFx.release()
	shotToken += 1
	pcall(function()
		RunService:UnbindFromRenderStep(SHOT_BIND)
	end)
	local cam = camera()
	cam.CameraType = Enum.CameraType.Custom
	CameraFx.resetFov()
end

-- Vrai si aucun autre plan n'a démarré depuis `token` (voir CameraFx.token()).
function CameraFx.token(): number
	return shotToken
end

-- CFrame de la caméra de jeu par défaut derrière un personnage (point d'arrivée des retours fluides).
function CameraFx.gameplayCFrame(root: BasePart): CFrame
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	local focus = root.Position + Vector3.new(0, 1.8, 0)
	return CFrame.lookAt(focus - flat * 11 + Vector3.new(0, 3, 0), focus)
end

local function easeInOut(x: number): number
	return x * x * (3 - 2 * x)
end
CameraFx.ease = easeInOut

return CameraFx
