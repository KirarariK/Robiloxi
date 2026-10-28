--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)
local BiomesConfig = require(game.ReplicatedStorage.StealASnake.Config.BiomesConfig)

local SoundController = {}

-- Built-in / widely available; empty id skips play
local SFX = {
	Cash = "rbxasset://sounds/electronicpingshort.wav",
	Alert = "rbxasset://sounds/switch.wav",
	Upgrade = "rbxasset://sounds/button.wav",
}

function SoundController.start()
	local folder = Instance.new("Folder")
	folder.Name = "SAS_Sounds"
	folder.Parent = SoundService

	local chase = Instance.new("Sound")
	chase.Name = "ChasePulse"
	chase.Looped = true
	chase.Volume = 0
	chase.PlaybackSpeed = 1
	chase.SoundId = "rbxasset://sounds/impact_water.mp3"
	chase.Parent = folder
	pcall(function()
		chase:Play()
	end)

	local chasing = false
	local lastAlertAt = 0

	local function oneShot(id: string, vol: number?)
		if id == "" then
			return
		end
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = vol or 0.4
		s.Parent = folder
		local ok = pcall(function()
			s:Play()
		end)
		if ok then
			task.delay(2, function()
				s:Destroy()
			end)
		else
			s:Destroy()
		end
	end

	Network.event("Alert").OnClientEvent:Connect(function(msg)
		local now = tick()
		if now - lastAlertAt < 2.5 then
			return
		end
		lastAlertAt = now
		if typeof(msg) == "string" and string.find(string.upper(msg), "POURSUIT") then
			chasing = true
			oneShot(SFX.Alert, 0.5)
		else
			oneShot(SFX.Upgrade, 0.35)
		end
	end)

	Network.event("GuardianAggro").OnClientEvent:Connect(function(active: boolean, intensity: number?)
		chasing = active == true
		if chasing then
			chase.Volume = math.clamp((intensity or 0.5) * 0.55, 0.15, 0.6)
			chase.PlaybackSpeed = 0.9 + (intensity or 0.5) * 0.5
		else
			chase.Volume = 0
		end
	end)

	Network.event("VFX").OnClientEvent:Connect(function(kind)
		if kind == "CashBurst" then
			oneShot(SFX.Cash, 0.45)
		end
	end)

	local lastBiome = -1
	RunService.Heartbeat:Connect(function()
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			return
		end
		local biomeOrder = 0
		for _, cfg in BiomesConfig do
			local half = cfg.Size.Z * 0.5
			if math.abs(hrp.Position.Z - cfg.Center.Z) <= half and math.abs(hrp.Position.X - cfg.Center.X) <= cfg.Size.X * 0.5 then
				biomeOrder = cfg.Order
				break
			end
		end
		if biomeOrder ~= lastBiome then
			lastBiome = biomeOrder
		end
		if not chasing then
			chase.Volume = math.max(0, chase.Volume - 0.03)
		end
	end)
end

return SoundController
