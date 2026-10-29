--!strict
-- Mannequins d'entraînement du Hub (Workspace.Hub.Dummy_1..3) : générés en code, parent / bloquent parfois,
-- suivent du regard le joueur le plus proche, encaissent les poussées et se réinitialisent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Config = require(Shared.Combat.CombatConfig)
local CombatMath = require(Shared.Combat.CombatMath)
local State = require(script.Parent.State)
local Fighter = require(script.Parent.Fighter)
local Broadcast = require(script.Parent.Broadcast)
local Validation = require(script.Parent.Validation)
local Actions = require(script.Parent.Actions)

type Fighter = State.Fighter

local A = Config.Attr
local DC = Config.Dummy

local Dummies = {}

type DummyData = {
	Home: CFrame,
	Offset: Vector3,
	Yaw: number,
	BaseYaw: number,
	Respawning: boolean,
}

local data: { [Fighter]: DummyData } = {}
local rng = Random.new()
local folder: Folder? = nil

local BODY = Color3.fromRGB(64, 70, 84)
local ACCENT = Color3.fromRGB(150, 120, 70)

--------------------------------------------------------------------------------
-- Construction du modèle

local function buildR15(): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = ACCENT
	desc.TorsoColor = BODY
	desc.LeftArmColor = BODY
	desc.RightArmColor = BODY
	desc.LeftLegColor = BODY
	desc.RightLegColor = BODY
	local ok, res = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if ok and typeof(res) == "Instance" and res:IsA("Model") then
		return res
	end
	return nil
end

local function makePart(model: Model, name: string, size: Vector3, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Metal
	p.Transparency = transparency
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function makeMotor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
end

-- Repli : rig R6 en blocs (si CreateHumanoidModelFromDescription échoue).
local function buildR6(): Model
	local model = Instance.new("Model")
	local root = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), BODY, 1)
	local torso = makePart(model, "Torso", Vector3.new(2, 2, 1), BODY, 0)
	local head = makePart(model, "Head", Vector3.new(2, 1, 1), ACCENT, 0)
	local ra = makePart(model, "Right Arm", Vector3.new(1, 2, 1), BODY, 0)
	local la = makePart(model, "Left Arm", Vector3.new(1, 2, 1), BODY, 0)
	local rl = makePart(model, "Right Leg", Vector3.new(1, 2, 1), BODY, 0)
	local ll = makePart(model, "Left Leg", Vector3.new(1, 2, 1), BODY, 0)
	local rootRot = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	makeMotor("RootJoint", root, torso, rootRot, rootRot)
	makeMotor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	makeMotor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	makeMotor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	makeMotor("Right Hip", torso, rl, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	makeMotor("Left Hip", torso, ll, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.Parent = model
	model.PrimaryPart = root
	return model
end

local function addBillboard(model: Model, f: Fighter)
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "DummyInfo"
	gui.Size = UDim2.fromOffset(170, 38)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 225, 200)
	label.TextStrokeTransparency = 0.5
	label.Text = "Mannequin d'entraînement"
	label.Parent = gui
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0.1, 0, 0, 24)
	bar.Size = UDim2.new(0.8, 0, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 70, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	gui.Parent = head
	f.Maid:Give(model:GetAttributeChangedSignal(A.HealthPct):Connect(function()
		local pct = model:GetAttribute(A.HealthPct)
		fill.Size = UDim2.fromScale(if type(pct) == "number" then math.clamp(pct, 0, 1) else 1, 1)
	end))
end

local function homeFor(anchor: BasePart, hum: Humanoid, root: BasePart): CFrame
	local h = if hum.RigType == Enum.HumanoidRigType.R6 then 3 else hum.HipHeight + root.Size.Y * 0.5
	local pos = anchor.Position + Vector3.new(0, anchor.Size.Y * 0.5 + h, 0)
	return CFrame.new(pos) * anchor.CFrame.Rotation
end

local function spawnDummy(index: number, anchor: BasePart)
	local model = buildR15() or buildR6()
	model.Name = "Mannequin_" .. index
	local hum = model:FindFirstChildOfClass("Humanoid")
	local rootInst = model:FindFirstChild("HumanoidRootPart")
	if not hum or not (rootInst and rootInst:IsA("BasePart")) then
		model:Destroy()
		warn("[EtherBlades][Combat] mannequin " .. index .. " : rig invalide")
		return
	end
	local root = rootInst :: BasePart
	model.PrimaryPart = root
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = 1e6
	hum.Health = 1e6
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy() -- pas de script Animate / Health sur un mannequin
		end
	end
	root.Anchored = true
	local home = homeFor(anchor, hum, root)
	model:PivotTo(home)
	model.Parent = folder

	local f = Fighter.new(model, hum, root, nil, true)
	local lo = DC.Loadouts[((index - 1) % #DC.Loadouts) + 1]
	Fighter.applyLoadout(f, lo.Form, lo.Weapon, lo.Color)
	f.MaxHealth = DC.Health
	Fighter.resetVitals(f)
	Fighter.setSaber(f, true)
	State.add(f)
	Validation.recordNpc(model)
	addBillboard(model, f)
	local _, yaw, _ = home:ToOrientation()
	data[f] = { Home = home, Offset = Vector3.zero, Yaw = yaw, BaseYaw = yaw, Respawning = false }
	f.Maid:Give(model)
end

--------------------------------------------------------------------------------
-- Hooks

local function react(attacker: Fighter, windup: number)
	if attacker.IsDummy or attacker.MatchId then
		return
	end
	for _, d in State.dummies do
		local dd = data[d]
		if dd and not dd.Respawning and d.Alive and d.State == "Idle" then
			local dist = (d.Root.Position - attacker.Root.Position).Magnitude
			if dist <= attacker.Weapon.Reach + DC.ReactRange then
				local r = rng:NextNumber()
				if r < DC.ParryChance then
					local delay = math.max(0, windup - CombatMath.parryWindow(d.Form) * 0.5 - 0.02)
					task.delay(delay, function()
						if d.Alive and d.State == "Idle" then
							Actions.parry(d, nil)
						end
					end)
				elseif r < DC.ParryChance + DC.BlockChance then
					Actions.block(d, true)
					task.delay(DC.BlockHold, function()
						Actions.block(d, false)
					end)
				end
			end
		end
	end
end

local function onDefeated(f: Fighter)
	local dd = data[f]
	if not dd or dd.Respawning then
		return
	end
	dd.Respawning = true
	Broadcast.fx("KO", { Target = f.Model, Position = f.Root.Position })
	task.delay(DC.RespawnDelay, function()
		if data[f] ~= dd or f.Model.Parent == nil then
			return
		end
		dd.Respawning = false
		dd.Offset = Vector3.zero
		Fighter.resetVitals(f)
		Fighter.setSaber(f, true)
		f.Model:PivotTo(dd.Home)
		Validation.clearHistory(f.Model)
		Broadcast.fx("Respawn", { Target = f.Model, Position = f.Root.Position })
	end)
end

function Dummies.isDummy(f: Fighter): boolean
	return data[f] ~= nil
end

function Dummies.onDefeated(f: Fighter)
	onDefeated(f)
end

function Dummies.onAttackStarted(attacker: Fighter, windup: number)
	react(attacker, windup)
end

function Dummies.push(f: Fighter, offset: Vector3)
	local dd = data[f]
	if dd then
		local o = dd.Offset + offset
		if o.Magnitude > 6 then
			o = o.Unit * 6
		end
		dd.Offset = o
	end
end

--------------------------------------------------------------------------------
-- Tick

local function angleLerp(a: number, b: number, t: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

function Dummies.tick(now: number, dt: number)
	for f, dd in data do
		if f.Model.Parent == nil then
			data[f] = nil
			State.remove(f)
			Fighter.destroy(f)
			continue
		end
		-- réinitialisation après une période sans coup
		if f.Alive and not dd.Respawning and f.Health < f.MaxHealth and now - f.LastHitTaken > DC.IdleReset then
			f.Health = f.MaxHealth
			f.Posture = f.MaxPosture
			Fighter.writeAttributes(f)
		end
		-- orientation vers le joueur le plus proche
		local best: BasePart? = nil
		local bestDist = DC.FaceRange
		for _, pf in State.byPlayer do
			local d = (pf.Root.Position - dd.Home.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = pf.Root
			end
		end
		local targetYaw = dd.BaseYaw
		if best and f.Alive then
			local dir = best.Position - f.Root.Position
			if Vector3.new(dir.X, 0, dir.Z).Magnitude > 0.5 then
				targetYaw = math.atan2(-dir.X, -dir.Z)
			end
		end
		local newYaw = angleLerp(dd.Yaw, targetYaw, math.min(1, DC.TurnSpeed * dt))
		local newOffset = dd.Offset:Lerp(Vector3.zero, math.min(1, DC.PushReturn * dt))
		if math.abs(newYaw - dd.Yaw) > 1e-4 or (newOffset - dd.Offset).Magnitude > 1e-4 then
			dd.Yaw = newYaw
			dd.Offset = if newOffset.Magnitude < 0.01 then Vector3.zero else newOffset
			f.Model:PivotTo(CFrame.new(dd.Home.Position + dd.Offset) * CFrame.Angles(0, dd.Yaw, 0))
		end
	end
end

function Dummies.start()
	task.spawn(function()
		local hub = workspace:WaitForChild("Hub", 60)
		if not hub then
			warn("[EtherBlades][Combat] Workspace.Hub introuvable : pas de mannequins d'entraînement")
			return
		end
		local f = Instance.new("Folder")
		f.Name = "CombatDummies"
		f.Parent = workspace
		folder = f
		for i = 1, 3 do
			local name = "Dummy_" .. i
			local anchor = hub:FindFirstChild(name, true) or hub:WaitForChild(name, 10)
			if anchor and anchor:IsA("BasePart") then
				spawnDummy(i, anchor)
			else
				warn("[EtherBlades][Combat] Workspace.Hub." .. name .. " introuvable : mannequin non créé")
			end
		end
	end)
end

return Dummies
