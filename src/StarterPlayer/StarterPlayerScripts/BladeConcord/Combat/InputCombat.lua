--!strict
--[[
	PC + mobile : Attaque / Guard / Dodge / Dash / Feinte / Focus.
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local InputCombat = {}

local remotes: Remotes.CombatRemotes
local seq = 0
local heavyHoldStart: number? = nil
local HEAVY_HOLD_THRESHOLD = 0.22
local guardHolding = false
local enabled = true
local lastGuardSend = 0
local GUARD_THROTTLE = 1 / 20
local lastA = 0
local lastD = 0
local DOUBLE_TAP = 0.28

local function nextSeq(): number
	seq += 1
	return seq
end

local function moveDir(): Vector3
	local player = Players.LocalPlayer
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return Vector3.new(0, 0, -1)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		return humanoid.MoveDirection
	end
	local look = hrp.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z)
end

local function fireAttack(kind: string)
	if not enabled then
		return
	end
	remotes.AttackIntent:FireServer({
		kind = kind,
		seq = nextSeq(),
		clientTime = os.clock(),
	})
end

local function fireGuard(holding: boolean)
	if not enabled then
		return
	end
	local now = os.clock()
	if now - lastGuardSend < GUARD_THROTTLE and holding == guardHolding then
		return
	end
	lastGuardSend = now
	guardHolding = holding
	remotes.GuardIntent:FireServer({
		holding = holding,
		seq = nextSeq(),
	})
end

local function fireMobility(kind: string, dir: Vector3?)
	if not enabled then
		return
	end
	local d = dir or moveDir()
	remotes.MobilityIntent:FireServer({
		kind = kind,
		seq = nextSeq(),
		dir = { X = d.X, Y = d.Y, Z = d.Z },
	})
end

local function fireFocus(kind: string)
	if not enabled then
		return
	end
	local d = moveDir()
	remotes.FocusIntent:FireServer({
		kind = kind,
		seq = nextSeq(),
		dir = { X = d.X, Y = d.Y, Z = d.Z },
	})
end

function InputCombat.setEnabled(value: boolean)
	enabled = value
	if not value then
		fireGuard(false)
	end
end

local function bindMobileButton(name: string, title: string, handler)
	ContextActionService:BindAction(name, handler, true)
	ContextActionService:SetTitle(name, title)
	pcall(function()
		ContextActionService:SetPosition(name, UDim2.new(1, -90, 1, -180))
	end)
end

function InputCombat.start()
	remotes = Remotes.get()
	local player = Players.LocalPlayer

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not enabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			heavyHoldStart = os.clock()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			fireGuard(true)
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.E then
			local side = if input.KeyCode == Enum.KeyCode.Q then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				side = hrp.CFrame:VectorToWorldSpace(side)
			end
			fireMobility("Dodge", side)
		elseif input.KeyCode == Enum.KeyCode.A then
			local now = os.clock()
			if now - lastA <= DOUBLE_TAP then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local dir = if hrp then hrp.CFrame:VectorToWorldSpace(Vector3.new(-1, 0, 0)) else Vector3.new(-1, 0, 0)
				fireMobility("Dodge", dir)
			end
			lastA = now
		elseif input.KeyCode == Enum.KeyCode.D then
			local now = os.clock()
			if now - lastD <= DOUBLE_TAP then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local dir = if hrp then hrp.CFrame:VectorToWorldSpace(Vector3.new(1, 0, 0)) else Vector3.new(1, 0, 0)
				fireMobility("Dodge", dir)
			end
			lastD = now
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			fireMobility("Dash", moveDir())
		elseif input.KeyCode == Enum.KeyCode.F then
			fireFocus("Push")
		elseif input.KeyCode == Enum.KeyCode.G then
			fireFocus("DashFocus")
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _processed)
		if not enabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local start = heavyHoldStart
			heavyHoldStart = nil
			if not start then
				return
			end
			local held = os.clock() - start
			if held >= HEAVY_HOLD_THRESHOLD then
				fireAttack("Heavy")
			else
				fireAttack("Light")
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			fireGuard(false)
		end
	end)

	-- Mobile / touch UI boutons
	local touch = UserInputService.TouchEnabled
	if touch then
		local function mobileAttack(_name, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				heavyHoldStart = os.clock()
			elseif state == Enum.UserInputState.End then
				local start = heavyHoldStart
				heavyHoldStart = nil
				if start and os.clock() - start >= HEAVY_HOLD_THRESHOLD then
					fireAttack("Heavy")
				else
					fireAttack("Light")
				end
			end
			return Enum.ContextActionResult.Sink
		end
		local function mobileGuard(_name, state: Enum.UserInputState)
			fireGuard(state == Enum.UserInputState.Begin)
			return Enum.ContextActionResult.Sink
		end
		local function mobileDodge(_name, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				fireMobility("Dodge", moveDir())
			end
			return Enum.ContextActionResult.Sink
		end
		local function mobileDash(_name, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				fireMobility("Dash", moveDir())
			end
			return Enum.ContextActionResult.Sink
		end
		local function mobilePush(_name, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				fireFocus("Push")
			end
			return Enum.ContextActionResult.Sink
		end
		local function mobileFocusDash(_name, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				fireFocus("DashFocus")
			end
			return Enum.ContextActionResult.Sink
		end

		bindMobileButton("BC_Attack", "Attaque", mobileAttack)
		bindMobileButton("BC_Guard", "Parade", mobileGuard)
		bindMobileButton("BC_Dodge", "Esquive", mobileDodge)
		bindMobileButton("BC_Dash", "Dash", mobileDash)
		bindMobileButton("BC_Push", "Poussée", mobilePush)
		bindMobileButton("BC_FocusDash", "Dash Focus", mobileFocusDash)
	end

	player.CharacterRemoving:Connect(function()
		fireGuard(false)
	end)
end

return InputCombat
