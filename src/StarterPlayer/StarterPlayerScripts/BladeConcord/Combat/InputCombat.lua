--!strict
--[[
	PC + mobile : Attaque / Guard / Dodge / Dash / Feinte / Focus / DoubleJump.
	Bindings kit :
	  LMB Attaque · RMB Parade · Shift Dash · F Force Push · Space (air) Double saut
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
local lastDoubleJumpSend = 0
local DOUBLE_JUMP_CLIENT_CD = 0.2

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

local function isLocalAirborne(): boolean
	local character = Players.LocalPlayer.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		return true
	end
	return humanoid.FloorMaterial == Enum.Material.Air
end

local function tryFireDoubleJump()
	if not enabled then
		return
	end
	local now = os.clock()
	if now - lastDoubleJumpSend < DOUBLE_JUMP_CLIENT_CD then
		return
	end
	if not isLocalAirborne() then
		return
	end
	lastDoubleJumpSend = now
	fireMobility("DoubleJump", moveDir())
end

function InputCombat.setEnabled(value: boolean)
	enabled = value
	if not value then
		fireGuard(false)
	end
end

--[[
	Layout tactile bas-droite (pouce) — Focus/Dash plus grands, non empilés.
	Colonnes : primaire (Attaque/Parade) | mobilité | Focus.
]]
local MOBILE_LAYOUT = {
	BC_Attack = { title = "Attaque", pos = UDim2.new(1, -78, 1, -118), size = UDim2.fromOffset(72, 72) },
	BC_Guard = { title = "Parade", pos = UDim2.new(1, -168, 1, -118), size = UDim2.fromOffset(68, 68) },
	BC_Dodge = { title = "Esquive", pos = UDim2.new(1, -78, 1, -218), size = UDim2.fromOffset(64, 64) },
	BC_Dash = { title = "Dash", pos = UDim2.new(1, -168, 1, -218), size = UDim2.fromOffset(72, 72) },
	BC_Push = { title = "Poussée", pos = UDim2.new(1, -78, 1, -318), size = UDim2.fromOffset(76, 76) },
	BC_FocusDash = { title = "Dash Focus", pos = UDim2.new(1, -178, 1, -318), size = UDim2.fromOffset(84, 84) },
}

local function bindMobileButton(name: string, handler)
	local spec = MOBILE_LAYOUT[name]
	local title = if spec then spec.title else name
	ContextActionService:BindAction(name, handler, true)
	ContextActionService:SetTitle(name, title)
	pcall(function()
		if spec then
			ContextActionService:SetPosition(name, spec.pos)
		end
	end)
	-- Agrandir Focus/Dash (et le reste) pour cibles tactiles utilisables
	task.defer(function()
		pcall(function()
			local btn = ContextActionService:GetButton(name)
			if btn and spec then
				btn.Size = spec.size
				btn.AnchorPoint = Vector2.new(0.5, 0.5)
			end
		end)
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
			-- Force Push (FocusService.tryPush serveur)
			fireFocus("Push")
		elseif input.KeyCode == Enum.KeyCode.G then
			fireFocus("DashFocus")
		elseif input.KeyCode == Enum.KeyCode.Space then
			-- Space au sol = saut Humanoid natif ; en l’air = double saut serveur
			tryFireDoubleJump()
		end
	end)

	-- JumpRequest couvre pads / mobile jump button
	UserInputService.JumpRequest:Connect(function()
		if not enabled then
			return
		end
		tryFireDoubleJump()
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

		bindMobileButton("BC_Attack", mobileAttack)
		bindMobileButton("BC_Guard", mobileGuard)
		bindMobileButton("BC_Dodge", mobileDodge)
		bindMobileButton("BC_Dash", mobileDash)
		bindMobileButton("BC_Push", mobilePush)
		bindMobileButton("BC_FocusDash", mobileFocusDash)
	end

	player.CharacterRemoving:Connect(function()
		fireGuard(false)
	end)
end

return InputCombat
