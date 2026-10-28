--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)

local VFXController = {}

local player = Players.LocalPlayer
local sweat: ParticleEmitter? = nil
local trails: { Trail } = {}
local beamPart: BasePart? = nil
local beam: Beam? = nil
local carrying = false
local lastWalk = 16

local function ensureSweat(head: BasePart)
	if sweat and sweat.Parent then
		return
	end
	local att = head:FindFirstChild("SweatAtt") :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = "SweatAtt"
		att.Position = Vector3.new(0, 0.6, 0)
		att.Parent = head
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "HeavySweat"
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(2, 4)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
	pe.Size = NumberSequence.new(0.12, 0)
	pe.Acceleration = Vector3.new(0, -18, 0)
	pe.Parent = att
	sweat = pe
end

local function ensureSpeedLines(char: Model)
	if #trails > 0 then
		return
	end
	for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local a0 = Instance.new("Attachment")
			a0.Parent = part
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, 0, 1)
			a1.Parent = part
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.2
			trail.WidthScale = NumberSequence.new(0.5, 0)
			trail.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255), Color3.fromRGB(70, 150, 255))
			trail.Enabled = false
			trail.Parent = part
			table.insert(trails, trail)
		end
	end
end

local function cashBurst(at: Vector3?)
	local pos = at
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not pos and hrp and hrp:IsA("BasePart") then
		pos = hrp.Position
	end
	if not pos then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Parent = Workspace
	local att = Instance.new("Attachment")
	att.Parent = p
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.4, 0.9)
	pe.Speed = NumberRange.new(8, 18)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Color = ColorSequence.new(Color3.fromRGB(80, 255, 120), Color3.fromRGB(255, 230, 80))
	pe.Size = NumberSequence.new(0.5, 0)
	pe.Parent = att
	pe:Emit(36)
	task.delay(1.1, function()
		p:Destroy()
	end)
end

-- Élément de MA parcelle (panneau du propriétaire = mon DisplayName) : DropZone, CollectPad, TreadmillSpot…
local function myPlotPart(plots: Instance, name: string): BasePart?
	for _, plot in plots:GetChildren() do
		local sign = plot:FindFirstChild("OwnerSign")
		local label = sign and sign:FindFirstChild("OwnerLabel", true)
		if label and label:IsA("TextLabel") and label.Text == player.DisplayName then
			local p = plot:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				return p
			end
		end
	end
	return nil
end

function VFXController.start()
	Network.event("VFX").OnClientEvent:Connect(function(kind, pos)
		if kind == "CashBurst" then
			cashBurst(if typeof(pos) == "Vector3" then pos else nil)
		end
	end)

	Network.event("CarryState").OnClientEvent:Connect(function(state)
		carrying = state ~= nil
	end)

	player.CharacterAdded:Connect(function(char)
		trails = {}
		sweat = nil
		task.wait(0.3)
		local head = char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			ensureSweat(head)
		end
		ensureSpeedLines(char)
	end)
	if player.Character then
		task.defer(function()
			local char = player.Character
			if not char then
				return
			end
			local head = char:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				ensureSweat(head)
			end
			ensureSpeedLines(char)
		end)
	end

	-- (l'arc-en-ciel des Cosmiques est géré par AnimationController, sans parcourir tout le Workspace)
	RunService.RenderStepped:Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not hrp or not hrp:IsA("BasePart") then
			return
		end
		lastWalk = hum.WalkSpeed
		if sweat then
			sweat.Rate = if lastWalk < 10 and carrying then 18 else 0
		end
		local fast = lastWalk >= 40 or (hum.MoveDirection.Magnitude > 0.1 and lastWalk >= 28)
		for _, t in trails do
			t.Enabled = fast
		end

		if not beamPart then
			beamPart = Instance.new("Part")
			beamPart.Name = "SAS_GuideAnchor"
			beamPart.Anchored = true
			beamPart.CanCollide = false
			beamPart.Transparency = 1
			beamPart.Size = Vector3.new(1, 1, 1)
			beamPart.Parent = Workspace
			local att0 = Instance.new("Attachment")
			att0.Name = "GuideA0"
			att0.Parent = hrp
			local att1 = Instance.new("Attachment")
			att1.Parent = beamPart
			beam = Instance.new("Beam")
			beam.Attachment0 = att0
			beam.Attachment1 = att1
			beam.Width0 = 0.7
			beam.Width1 = 0.7
			beam.FaceCamera = true
			beam.TextureSpeed = 2
			beam.Color = ColorSequence.new(Color3.fromRGB(80, 255, 160))
			beam.Parent = hrp
		else
			local a0 = hrp:FindFirstChild("GuideA0")
			if not a0 then
				local att0 = Instance.new("Attachment")
				att0.Name = "GuideA0"
				att0.Parent = hrp
				if beam then
					beam.Attachment0 = att0
				end
			end
		end

		local target: Vector3? = nil
		local step = player:GetAttribute("TutorialStep") or 5
		if beam then
			-- rayon plus épais pendant le tutoriel
			local w = if step < 5 then 1.3 else 0.7
			beam.Width0 = w
			beam.Width1 = w
		end
		if carrying then
			local plots = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Plots")
			local dz = plots and myPlotPart(plots, "DropZone")
			if dz then
				target = dz.Position
			end
			if beam then
				beam.Color = ColorSequence.new(Color3.fromRGB(80, 255, 120))
			end
		elseif step == 3 or step == 4 then
			-- tutoriel : récolte puis tapis de course
			local plots = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Plots")
			local p = plots and myPlotPart(plots, if step == 3 then "CollectPad" else "TreadmillSpot")
			if p then
				target = p.Position
			end
			if beam then
				beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
			end
		else
			local best = math.huge
			local wild = Workspace:FindFirstChild("WildSnakes")
			if wild then
				for _, s in wild:GetChildren() do
					if s:IsA("Model") and s.PrimaryPart then
						local d = (s.PrimaryPart.Position - hrp.Position).Magnitude
						if d < best then
							best = d
							target = s.PrimaryPart.Position
						end
					end
				end
			end
			if beam then
				beam.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
			end
		end
		if target and beamPart and beam then
			beamPart.Position = target
			beam.Enabled = true
		elseif beam then
			beam.Enabled = false
		end
	end)
end

return VFXController
