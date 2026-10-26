--!strict
--[[
	Caméra 3e personne lock soft adversaire (GDD §2.1).
	Pass 3 : hitstop court, ConcordBot as target, restore propre post-KO.
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
local cinematicActive = false
local hitstopUntil = 0
local frozenCFrame: CFrame? = nil
local opponentUserId: number? = nil

local function botRoot(): BasePart?
	local bot = Workspace:FindFirstChild("ConcordBot")
	if bot and bot:IsA("Model") then
		local hrp = bot:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return hrp
		end
	end
	return nil
end

local function findOpponentRoot(): BasePart?
	if opponentUserId == -9001 then
		return botRoot()
	end
	if opponentUserId then
		local p = Players:GetPlayerByUserId(opponentUserId)
		if p and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				return hrp
			end
		end
		return nil
	end
	-- Fallback : autre joueur, sinon ConcordBot (solo)
	local localId = Players.LocalPlayer.UserId
	for _, p in Players:GetPlayers() do
		if p.UserId ~= localId and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				return hrp
			end
		end
	end
	return botRoot()
end

function SoftLockCamera.setEnabled(value: boolean)
	enabled = value
end

--[[ Pause soft-lock pendant une cinématique client (KO). ]]
function SoftLockCamera.beginCinematic()
	cinematicActive = true
	frozenCFrame = nil
end

function SoftLockCamera.endCinematic()
	cinematicActive = false
	frozenCFrame = nil
	hitstopUntil = 0
	local camera = Workspace.CurrentCamera
	if camera then
		-- Soft-lock reprend immédiatement en Scriptable (évite Custom / stuck)
		camera.CameraType = Enum.CameraType.Scriptable
	end
end

function SoftLockCamera.isCinematic(): boolean
	return cinematicActive
end

--[[ Hitstop client : fige le CFrame caméra ~2–4 frames. ]]
function SoftLockCamera.hitstop(seconds: number)
	local camera = Workspace.CurrentCamera
	if camera then
		frozenCFrame = camera.CFrame
	end
	local untilT = os.clock() + seconds
	if untilT > hitstopUntil then
		hitstopUntil = untilT
	end
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
		if not enabled or cinematicActive then
			return
		end
		camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		-- Hitstop : hold last frame
		if os.clock() < hitstopUntil and frozenCFrame then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CameraShake.applyTo(camera, frozenCFrame)
			return
		end
		frozenCFrame = nil

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
