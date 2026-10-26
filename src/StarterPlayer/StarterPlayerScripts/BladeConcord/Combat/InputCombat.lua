--!strict
--[[
	Bindings PC LMB / RMB → AttackIntent / GuardIntent.
	Stubs mobile via ContextActionService (boutons placeholder).
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

local function nextSeq(): number
	seq += 1
	return seq
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

function InputCombat.setEnabled(value: boolean)
	enabled = value
	if not value then
		fireGuard(false)
	end
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

	-- Stubs mobile
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

	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		ContextActionService:BindAction("BC_Attack", mobileAttack, true, Enum.KeyCode.ButtonR2)
		ContextActionService:BindAction("BC_Guard", mobileGuard, true, Enum.KeyCode.ButtonL2)
		ContextActionService:SetTitle("BC_Attack", "Attaque")
		ContextActionService:SetTitle("BC_Guard", "Parade")
	end

	player.CharacterRemoving:Connect(function()
		fireGuard(false)
	end)
end

return InputCombat
