--!strict
--[[
	Shake caméra léger — superposition sur SoftLock (offset RenderStepped).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraShake = {}

local trauma = 0 -- 0..1
local seed = 0

function CameraShake.shake(intensity: number, duration: number)
	trauma = math.clamp(trauma + intensity, 0, 1)
	task.delay(duration, function()
		trauma = math.max(0, trauma - intensity * 0.65)
	end)
end

function CameraShake.getOffset(): CFrame
	if trauma < 0.01 then
		return CFrame.new()
	end
	local shake = trauma * trauma
	seed += 1
	local t = os.clock() * 28
	local yaw = math.noise(seed, t, 0) * shake * 0.045
	local pitch = math.noise(0, seed, t) * shake * 0.035
	local roll = math.noise(t, 0, seed) * shake * 0.02
	local ox = math.noise(t * 1.3, seed, 2) * shake * 0.35
	local oy = math.noise(seed, t * 1.1, 4) * shake * 0.25
	return CFrame.new(ox, oy, 0) * CFrame.Angles(pitch, yaw, roll)
end

function CameraShake.start()
	RunService.RenderStepped:Connect(function(dt)
		if trauma > 0 then
			trauma = math.max(0, trauma - dt * 1.8)
		end
		-- SoftLock applique l'offset via CameraShake.getOffset()
	end)
end

-- Expose pour SoftLock
function CameraShake.applyTo(camera: Camera, base: CFrame): CFrame
	return base * CameraShake.getOffset()
end

return CameraShake
