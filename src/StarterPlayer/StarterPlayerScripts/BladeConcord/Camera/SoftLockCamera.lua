--!strict
--[[
	Caméra 3e personne lock soft adversaire (GDD §2.1).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CameraShake = require(script.Parent:WaitForChild("CameraShake"))

local SoftLockCamera = {}

local enabled = true
local opponentUserId: number? = nil

local function findOpponentRoot(): BasePart?
	if not opponentUserId then
		-- Fallback : premier autre joueur
		local localId = Players.LocalPlayer.UserId
		for _, p in Players:GetPlayers() do
			if p.UserId ~= localId and p.Character then
				local hrp = p.Character:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					return hrp
				end
			end
		end
		return nil
	end
	local p = Players:GetPlayerByUserId(opponentUserId)
	if not p or not p.Character then
		return nil
	end
	local hrp = p.Character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

function SoftLockCamera.setEnabled(value: boolean)
	enabled = value
end

function SoftLockCamera.start()
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	local remotes = Remotes.get()

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			if snap.userId ~= player.UserId then
				opponentUserId = snap.userId
				break
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not enabled then
			return
		end
		camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end

		local target = findOpponentRoot()
		local cfg = CombatConfig.Camera
		local lookAt = hrp.Position + Vector3.new(0, 2, 0)
		if target and (target.Position - hrp.Position).Magnitude <= cfg.SoftLockMaxDistance then
			lookAt = target.Position + Vector3.new(0, 2, 0)
		end

		local back = (hrp.Position - lookAt)
		local flat = Vector3.new(back.X, 0, back.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z) * -1
		end
		local desired = CFrame.new(hrp.Position + flat.Unit * cfg.Offset.Z + Vector3.new(0, cfg.Offset.Y, 0), lookAt)
		desired = CameraShake.applyTo(camera, desired)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = camera.CFrame:Lerp(desired, cfg.SoftLockLerp)
	end)
end

return SoftLockCamera
