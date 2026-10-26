--!strict
--[[
	Caméra 3e personne lock soft adversaire (GDD §2.1).
	Pass 3 : hitstop court, ConcordBot as target, restore propre post-KO.
	Vague 6 : soft spectate quand mort (jusqu'au reset manche / countdown).
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
local spectatorActive = false
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

function SoftLockCamera.setSpectator(value: boolean)
	spectatorActive = value
end

function SoftLockCamera.isSpectator(): boolean
	return spectatorActive
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
		local localDead = false
		for _, snap in payload.fighters do
			if snap.userId ~= player.UserId then
				opponentUserId = snap.userId
			elseif snap.userId == player.UserId then
				local hp = if typeof(snap.hp) == "number" then snap.hp else 1
				local actionId = tostring(snap.actionId or "")
				localDead = hp <= 0 or actionId == "Dead"
			end
		end
		-- Soft spectate tant que mort (RoundEnd / MatchEnd) ; clear si vivant
		if localDead then
			spectatorActive = true
		end
	end)

	remotes.MatchState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local phase = tostring(payload.phase)
		-- Reset manche / lobby → fin spectate
		if phase == "Countdown" or phase == "Fighting" or phase == "Lobby" then
			spectatorActive = false
		end
	end)

	remotes.RoundEnded.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		-- Perdant : soft spectate jusqu'au prochain countdown
		if payload.winnerUserId ~= nil and payload.winnerUserId ~= player.UserId then
			spectatorActive = true
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
		local target = findOpponentRoot()
		local cfg = CombatConfig.Camera

		if spectatorActive then
			-- Soft spectate : ancre sur adversaire (ou cadavre local) , offset haut, lerp doux
			local anchor = if target then target else hrp
			if not anchor then
				return
			end
			local lookAt = anchor.Position + Vector3.new(0, 2 + (cfg.SpectatorHeightBias or 1.2), 0)
			local off = cfg.SpectatorOffset or Vector3.new(0, 6.5, 14)
			local flatLook = Vector3.new(anchor.CFrame.LookVector.X, 0, anchor.CFrame.LookVector.Z)
			if flatLook.Magnitude < 1e-3 then
				flatLook = Vector3.new(0, 0, 1)
			end
			flatLook = flatLook.Unit
			local side = Vector3.new(-flatLook.Z, 0, flatLook.X)
			local desiredPos = lookAt - flatLook * off.Z + side * off.X + Vector3.new(0, off.Y, 0)
			local desired = CFrame.lookAt(desiredPos, lookAt)
			desired = CameraShake.applyTo(camera, desired)
			camera.CameraType = Enum.CameraType.Scriptable
			local lerp = cfg.SpectatorLerp or 0.07
			camera.CFrame = camera.CFrame:Lerp(desired, lerp)
			return
		end

		if not hrp then
			return
		end

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
