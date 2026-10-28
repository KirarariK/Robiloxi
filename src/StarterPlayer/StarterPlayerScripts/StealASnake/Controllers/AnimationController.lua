--!strict
--[[
	AnimationController — animations procédurales côté client (aucun asset d'animation requis).

	- Snake_Idle : chaque serpent (nids + vivariums) respire, oscille en S et tourne doucement la tête ;
	  les Cosmiques défilent en arc-en-ciel (Color3.fromHSV).
	- Player_HeavyCarry : pour TOUS les joueurs dont le personnage a l'attribut CarryWeight
	  (posé par le serveur) → bras tendus vers l'avant, buste penché en arrière, dandinement
	  d'autant plus fort que le serpent est lourd.
	- Décor : les objets marqués Float (rochers cosmiques) flottent.
	Distance d'animation limitée (perf) et mise à jour à fréquence réduite au-delà de 60 studs.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationController = {}

type SnakeAnim = { Base: CFrame, Phase: number, Rainbow: { BasePart } }

local snakes: { [Model]: SnakeAnim } = setmetatable({}, { __mode = "k" }) :: any
local floaters: { [BasePart]: { Base: CFrame, Phase: number } } = setmetatable({}, { __mode = "k" }) :: any
local poseSaved: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local ANIM_RADIUS = 160

local function registerSnake(m: Instance)
	if not m:IsA("Model") or not m:GetAttribute("IsSnake") or snakes[m] then
		return
	end
	task.defer(function()
		if not m.Parent then
			return
		end
		local rainbow = {}
		if m:GetAttribute("Mutation") == "Cosmic" then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(rainbow, d)
				end
			end
		end
		snakes[m] = { Base = m:GetPivot(), Phase = math.random() * 6.28, Rainbow = rainbow }
	end)
end

local function scanSnakes(root: Instance)
	for _, d in root:GetDescendants() do
		registerSnake(d)
	end
	root.DescendantAdded:Connect(registerSnake)
end

local function registerFloat(p: Instance)
	if p:IsA("BasePart") and p:GetAttribute("Float") and not floaters[p] then
		floaters[p] = { Base = p.CFrame, Phase = math.random() * 6.28 }
	end
end

-- Pose de portage (R15 + repli R6)
local function motor(char: Model, name: string): Motor6D?
	local m = char:FindFirstChild(name, true)
	return if m and m:IsA("Motor6D") then m else nil
end

local function setPose(m: Motor6D?, offset: CFrame?)
	if not m then
		return
	end
	if offset then
		if not poseSaved[m] then
			poseSaved[m] = m.C0
		end
		m.C0 = poseSaved[m] * offset
	elseif poseSaved[m] then
		m.C0 = poseSaved[m]
		poseSaved[m] = nil
	end
end

local function updateCarryPose(char: Model, now: number)
	local weight = char:GetAttribute("CarryWeight")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if typeof(weight) == "number" and weight > 0 and hum then
		local heavy = math.clamp(weight / 120, 0.15, 1)
		local moving = hum.MoveDirection.Magnitude > 0.1 or (char.PrimaryPart and char.PrimaryPart.AssemblyLinearVelocity.Magnitude > 2)
		local wob = if moving then math.sin(now * (6 - heavy * 2.5)) else 0
		local lean = math.rad(10 + heavy * 12)
		-- R15
		setPose(motor(char, "RightShoulder"), CFrame.Angles(math.rad(80), math.rad(-12), math.rad(8)))
		setPose(motor(char, "LeftShoulder"), CFrame.Angles(math.rad(80), math.rad(12), math.rad(-8)))
		setPose(motor(char, "RightElbow"), CFrame.Angles(math.rad(25), 0, 0))
		setPose(motor(char, "LeftElbow"), CFrame.Angles(math.rad(25), 0, 0))
		setPose(motor(char, "Waist"), CFrame.Angles(-lean, 0, math.rad(wob * 6 * heavy)))
		setPose(motor(char, "Neck"), CFrame.Angles(math.rad(8 + heavy * 6), 0, 0))
		-- R6
		setPose(motor(char, "Right Shoulder"), CFrame.Angles(0, 0, math.rad(80)))
		setPose(motor(char, "Left Shoulder"), CFrame.Angles(0, 0, math.rad(-80)))
	else
		for _, n in { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "Waist", "Neck", "Right Shoulder", "Left Shoulder" } do
			setPose(motor(char, n), nil)
		end
	end
end

function AnimationController.start()
	-- Serpents des nids
	task.spawn(function()
		scanSnakes(Workspace:WaitForChild("WildSnakes"))
	end)
	-- Serpents des vivariums
	task.spawn(function()
		local map = Workspace:WaitForChild("Map")
		local plots = map:WaitForChild("Plots")
		scanSnakes(plots)
		for _, d in plots:GetDescendants() do
			registerFloat(d)
		end
		local biomes = map:WaitForChild("Biomes")
		for _, d in biomes:GetDescendants() do
			registerFloat(d)
		end
		biomes.DescendantAdded:Connect(registerFloat)
	end)

	local frame = 0
	RunService.RenderStepped:Connect(function()
		frame += 1
		local now = os.clock()
		local cam = Workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		local hue = (now % 5) / 5

		for m, a in snakes do
			if not m.Parent then
				snakes[m] = nil
				continue
			end
			local dist = (a.Base.Position - camPos).Magnitude
			if dist > ANIM_RADIUS then
				continue
			end
			-- au-delà de 60 studs : 1 frame sur 3
			if dist > 60 and (frame % 3) ~= 0 then
				continue
			end
			local t = now + a.Phase
			local bob = math.sin(t * 2.1) * 0.12
			local sway = math.sin(t * 1.3) * math.rad(9)
			local tilt = math.sin(t * 2.6) * math.rad(3)
			m:PivotTo(a.Base * CFrame.new(0, bob, 0) * CFrame.Angles(tilt, sway, 0))
			for _, p in a.Rainbow do
				p.Color = Color3.fromHSV((hue + p.Position.Y * 0.03) % 1, 0.85, 1)
			end
		end

		if frame % 2 == 0 then
			for p, f in floaters do
				if not p.Parent then
					floaters[p] = nil
				elseif (f.Base.Position - camPos).Magnitude < 260 then
					local t = now + f.Phase
					p.CFrame = f.Base * CFrame.new(0, math.sin(t * 0.8) * 1.6, 0) * CFrame.Angles(0, t * 0.15, 0)
				end
			end
		end

		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			if char then
				updateCarryPose(char, now)
			end
		end
	end)
end

return AnimationController
