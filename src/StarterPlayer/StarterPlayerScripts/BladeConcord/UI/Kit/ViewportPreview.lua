--!strict
--[[
	ViewportFrame + WorldModel — clone avatar / mannequin + sabre, drag pour tourner.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))

local ViewportPreview = {}

export type Handle = {
	root: ViewportFrame,
	setAccent: (Color3) -> (),
	destroy: () -> (),
}

local function buildMannequin(parent: Instance, accent: Color3): Model
	local model = Instance.new("Model")
	model.Name = "PreviewFighter"
	model.Parent = parent

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = CFrame.new(0, 3, 0)
	root.Parent = model
	model.PrimaryPart = root

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = Color3.fromRGB(28, 32, 48)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = true
	torso.CanCollide = false
	torso.CFrame = CFrame.new(0, 3.2, 0)
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = Color3.fromRGB(220, 200, 180)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.CFrame = CFrame.new(0, 4.6, 0)
	head.Parent = model

	local function limb(name: string, size: Vector3, cf: CFrame, color: Color3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CFrame = cf
		p.Parent = model
		return p
	end

	limb("LeftArm", Vector3.new(0.6, 1.8, 0.6), CFrame.new(-1.4, 3.2, 0), Color3.fromRGB(40, 44, 60))
	limb(
		"RightArm",
		Vector3.new(0.6, 1.8, 0.6),
		CFrame.new(1.4, 3.2, 0) * CFrame.Angles(math.rad(-25), 0, math.rad(15)),
		Color3.fromRGB(40, 44, 60)
	)
	limb("LeftLeg", Vector3.new(0.7, 2, 0.7), CFrame.new(-0.45, 1.2, 0), Color3.fromRGB(22, 24, 36))
	limb("RightLeg", Vector3.new(0.7, 2, 0.7), CFrame.new(0.45, 1.2, 0), Color3.fromRGB(22, 24, 36))

	-- Sabre
	local blade = Instance.new("Part")
	blade.Name = "PreviewBlade"
	blade.Size = Vector3.new(0.25, 0.25, 3.2)
	blade.Color = accent
	blade.Material = Enum.Material.Neon
	blade.Anchored = true
	blade.CanCollide = false
	blade.CFrame = CFrame.new(1.6, 3.6, -1.2) * CFrame.Angles(math.rad(70), math.rad(10), 0)
	blade.Parent = model

	local light = Instance.new("PointLight")
	light.Color = accent
	light.Brightness = 2
	light.Range = 12
	light.Parent = blade

	-- Piédestal
	local ped = Instance.new("Part")
	ped.Name = "Pedestal"
	ped.Size = Vector3.new(4, 0.4, 4)
	ped.Color = Color3.fromRGB(40, 48, 64)
	ped.Material = Enum.Material.Slate
	ped.Anchored = true
	ped.CanCollide = false
	ped.CFrame = CFrame.new(0, 0.1, 0)
	ped.Parent = model
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Size = Vector3.new(3.2, 0.12, 3.2)
	ring.Color = accent
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CFrame = CFrame.new(0, 0.35, 0)
	ring.Parent = model

	return model
end

function ViewportPreview.create(
	parent: Instance,
	opts: {
		size: UDim2?,
		position: UDim2?,
		anchor: Vector2?,
		accent: Color3?,
	}
): Handle
	local accent = opts.accent or Theme.Focus
	local vp = Instance.new("ViewportFrame")
	vp.Name = "FormViewport"
	vp.BackgroundColor3 = Theme.Ink900
	vp.BackgroundTransparency = 0.15
	vp.BorderSizePixel = 0
	vp.Size = opts.size or UDim2.fromScale(0.34, 0.56)
	if opts.position then
		vp.Position = opts.position
	end
	if opts.anchor then
		vp.AnchorPoint = opts.anchor
	end
	vp.Ambient = Color3.fromRGB(40, 48, 70)
	vp.LightColor = accent
	vp.LightDirection = Vector3.new(-0.4, -1, -0.3)
	vp.Parent = parent
	Util.corner(vp, 12)
	Util.stroke(vp, accent, 1.5, 0.45)

	local world = Instance.new("WorldModel")
	world.Parent = vp

	local model = buildMannequin(world, accent)

	-- Try clone local character if available
	task.defer(function()
		local player = Players.LocalPlayer
		local char = player.Character
		if char and char:FindFirstChildOfClass("Humanoid") then
			local ok, clone = pcall(function()
				char.Archivable = true
				local c = char:Clone()
				char.Archivable = false
				return c
			end)
			if ok and clone then
				for _, d in clone:GetDescendants() do
					if d:IsA("LocalScript") or d:IsA("Script") or d:IsA("Animator") then
						d:Destroy()
					end
				end
				local animate = clone:FindFirstChild("Animate")
				if animate then
					animate:Destroy()
				end
				model:Destroy()
				clone.Name = "PreviewFighter"
				clone.Parent = world
				local hrp = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					hrp.Anchored = true
					clone:PivotTo(CFrame.new(0, 3, 0))
				end
				model = clone
				-- Pedestal under clone
				local ped = Instance.new("Part")
				ped.Size = Vector3.new(4, 0.4, 4)
				ped.Color = Color3.fromRGB(40, 48, 64)
				ped.Material = Enum.Material.Slate
				ped.Anchored = true
				ped.CanCollide = false
				ped.CFrame = CFrame.new(0, 0.1, 0)
				ped.Parent = world
			end
		end
	end)

	local cam = Instance.new("Camera")
	cam.Parent = vp
	vp.CurrentCamera = cam
	local yaw = 25
	local dist = 7.5
	local function updateCam()
		local focus = Vector3.new(0, 3.2, 0)
		local cf = CFrame.new(focus) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(0, 1.2, dist)
		cam.CFrame = CFrame.lookAt(cf.Position, focus)
	end
	updateCam()

	local dragging = false
	local lastX = 0
	local conns: { RBXScriptConnection } = {}

	table.insert(
		conns,
		vp.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				lastX = input.Position.X
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				local dx = input.Position.X - lastX
				lastX = input.Position.X
				yaw -= dx * 0.35
				updateCam()
			end
		end)
	)
	-- Idle orbit léger
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function(dt)
			if dragging or not vp.Parent then
				return
			end
			yaw += 8 * dt
			updateCam()
		end)
	)

	return {
		root = vp,
		setAccent = function(c: Color3)
			vp.LightColor = c
			local st = vp:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = c
			end
			for _, d in world:GetDescendants() do
				if d.Name == "PreviewBlade" or d.Name == "Ring" then
					(d :: BasePart).Color = c
				elseif d:IsA("PointLight") then
					d.Color = c
				end
			end
		end,
		destroy = function()
			for _, c in conns do
				c:Disconnect()
			end
			vp:Destroy()
		end,
	}
end

return ViewportPreview
