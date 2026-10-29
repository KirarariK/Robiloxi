--!strict
-- Aperçu 3D d'une lame dans un ViewportFrame : construit via Combat.SaberVisual.build (équipe Combat),
-- caméra cadrée sur la poignée, rotation à la souris / au doigt, rotation lente au repos.
-- Si SaberVisual est absent, un modèle de repli (poignée + lame néon) est construit ici.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local SaberColors = require(Shared.Config.SaberColors)
local Maid = require(Shared.Util.Maid)

local Kit = require(script.Parent.Kit)

export type Preview = {
	Frame: ViewportFrame,
	set: (weapon: string, colorId: string) -> (),
	destroy: () -> (),
}

local SaberPreview = {}

local warned = false
local function saberVisual(): any?
	local folder = script.Parent.Parent:FindFirstChild("Combat")
	local mod = folder and folder:FindFirstChild("SaberVisual")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and type(res) == "table" and type(res.build) == "function" then
			return res
		end
	end
	if not warned then
		warned = true
		warn("[EtherBlades] Combat.SaberVisual absent : aperçu de lame de repli dans l'Atelier.")
	end
	return nil
end

local function fallbackBlade(model: Model, colorId: string, offset: CFrame, dir: number)
	local def = SaberColors.get(colorId)
	local hilt = Instance.new("Part")
	hilt.Name = "Grip"
	hilt.Shape = Enum.PartType.Cylinder
	hilt.Size = Vector3.new(1.1, 0.28, 0.28)
	hilt.Material = Enum.Material.Metal
	hilt.Color = Color3.fromRGB(70, 74, 86)
	hilt.CFrame = offset * CFrame.Angles(0, 0, math.rad(90))
	hilt.Anchored = true
	hilt.Parent = model
	local core = Instance.new("Part")
	core.Name = "Blade"
	core.Shape = Enum.PartType.Cylinder
	core.Size = Vector3.new(3.6, 0.16, 0.16)
	core.Material = Enum.Material.Neon
	core.Color = if def then def.Glow else Color3.fromRGB(40, 120, 255)
	core.CFrame = offset * CFrame.new(0, dir * 2.35, 0) * CFrame.Angles(0, 0, math.rad(90))
	core.Anchored = true
	core.Parent = model
	local inner = core:Clone()
	inner.Name = "Core"
	inner.Size = Vector3.new(3.62, 0.08, 0.08)
	inner.Color = if def then def.Core else Color3.new(1, 1, 1)
	inner.Parent = model
	if not model.PrimaryPart then
		model.PrimaryPart = hilt
	end
end

local function buildFallback(weapon: string, colorId: string): Model
	local m = Instance.new("Model")
	m.Name = "PreviewSaber"
	if weapon == "Staff" then
		fallbackBlade(m, colorId, CFrame.new(), 1)
		fallbackBlade(m, colorId, CFrame.new(0, -1.1, 0), -1)
	elseif weapon == "Dual" then
		fallbackBlade(m, colorId, CFrame.new(-0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(-12)), 1)
		fallbackBlade(m, colorId, CFrame.new(0.6, 0, 0) * CFrame.Angles(0, 0, math.rad(12)), 1)
	else
		fallbackBlade(m, colorId, CFrame.new(), 1)
	end
	return m
end

function SaberPreview.new(parent: Instance, size: UDim2, position: UDim2?): Preview
	local maid = Maid.new()
	local vp = Kit.new("ViewportFrame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundColor3 = Color3.fromRGB(4, 6, 14),
		BackgroundTransparency = 0.1,
		Ambient = Color3.fromRGB(140, 150, 180),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -0.6),
		Parent = parent,
	}) :: ViewportFrame
	Kit.corner(vp, 14)
	Kit.stroke(vp, Color3.fromRGB(70, 220, 255), 1.5, 0.5)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.Parent = vp
	vp.CurrentCamera = cam
	maid:Give(vp)

	local model: Model? = nil
	local focus = Vector3.zero
	local distance = 6
	local yaw, pitch = math.rad(30), math.rad(-12)
	local dragging = false
	local lastInput = 0
	local lastPos = Vector2.zero
	local animColor: { BasePart } = {}
	local colorDef: any = nil

	local function updateCamera()
		local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		cam.CFrame = CFrame.lookAt(focus + rot:VectorToWorldSpace(Vector3.new(0, 0, distance)), focus)
	end

	local function setModel(m: Model)
		if model then
			model:Destroy()
		end
		model = m
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		m:PivotTo(CFrame.new())
		m.Parent = vp
		local cf, sz = m:GetBoundingBox()
		local gripInst = m.PrimaryPart or m:FindFirstChild("Grip", true)
		local grip = if gripInst and gripInst:IsA("BasePart") then gripInst.Position else cf.Position
		-- cadrage sur la poignée, en gardant le début de la lame dans le champ
		focus = grip:Lerp(cf.Position, 0.35)
		distance = math.clamp(sz.Magnitude * 0.62, 2.6, 14)
		table.clear(animColor)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
				table.insert(animColor, d)
			end
		end
		updateCamera()
	end

	local function set(weapon: string, colorId: string)
		colorDef = SaberColors.get(colorId)
		local sv = saberVisual()
		local built: Model? = nil
		if sv then
			local ok, res = pcall(sv.build, weapon, colorId)
			if ok and typeof(res) == "Instance" and res:IsA("Model") then
				built = res
			elseif not ok then
				warn("[EtherBlades] SaberVisual.build : " .. tostring(res))
			end
		end
		setModel(built or buildFallback(weapon, colorId))
	end

	maid:Give(vp.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			lastPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end))
	maid:Give(UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			lastInput = os.clock()
		end
	end))
	maid:Give(UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			local d = pos - lastPos
			lastPos = pos
			yaw -= d.X * 0.012
			pitch = math.clamp(pitch - d.Y * 0.008, math.rad(-70), math.rad(70))
			lastInput = os.clock()
			updateCamera()
		end
	end))
	maid:Give(RunService.RenderStepped:Connect(function(dt: number)
		if not vp.Visible or not model then
			return
		end
		if not dragging and os.clock() - lastInput > 2 then
			yaw += dt * 0.5
			updateCamera()
		end
		-- les ViewportFrames ne rendent pas le néon lumineux : on anime au moins la teinte des effets variables
		if colorDef and (colorDef.Effect == "Prism" or colorDef.Effect == "Nebula") then
			local c = SaberColors.glowAt(colorDef, os.clock())
			for _, p in animColor do
				if p.Name ~= "Core" then
					p.Color = c
				end
			end
		end
	end))

	local preview: Preview = {
		Frame = vp,
		set = set,
		destroy = function()
			maid:Clean()
		end,
	}
	return preview
end

return SaberPreview
