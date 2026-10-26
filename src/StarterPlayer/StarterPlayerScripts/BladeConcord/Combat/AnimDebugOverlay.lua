--!strict
--[[
	Overlay debug optionnel : set + clip courants (BC_AnimSet / BC_AnimClip).
	Activation :
	  • attribut LocalPlayer ou Character `BC_AnimDebug` = true
	  • touche F8 (toggle)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local AnimDebugOverlay = {}

local gui: ScreenGui? = nil
local label: TextLabel? = nil
local heartbeatConn: RBXScriptConnection? = nil
local inputConn: RBXScriptConnection? = nil
local visibleForced: boolean? = nil -- nil = follow attribute ; true/false = F8 override

local function isWanted(): boolean
	if visibleForced ~= nil then
		return visibleForced
	end
	local lp = Players.LocalPlayer
	if not lp then
		return false
	end
	if lp:GetAttribute("BC_AnimDebug") == true then
		return true
	end
	local char = lp.Character
	if char and char:GetAttribute("BC_AnimDebug") == true then
		return true
	end
	return false
end

local function ensureGui(): TextLabel
	local lp = Players.LocalPlayer
	assert(lp, "LocalPlayer required")
	local pg = lp:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("BC_AnimDebugOverlay")
	if existing and existing:IsA("ScreenGui") then
		gui = existing
		local t = existing:FindFirstChild("Label")
		if t and t:IsA("TextLabel") then
			label = t
			return t
		end
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "BC_AnimDebugOverlay"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 80
	screen.Enabled = false
	screen.Parent = pg

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 12, 1, -12)
	frame.Size = UDim2.fromOffset(320, 56)
	frame.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
	frame.BackgroundTransparency = 0.28
	frame.BorderSizePixel = 0
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.Code
	text.TextSize = 14
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextColor3 = Color3.fromRGB(220, 235, 245)
	text.Text = "BC anim —"
	text.Parent = frame

	gui = screen
	label = text
	return text
end

local function refresh()
	local lp = Players.LocalPlayer
	if not lp then
		return
	end
	local wanted = isWanted()
	local text = ensureGui()
	if gui then
		gui.Enabled = wanted
	end
	if not wanted then
		return
	end
	local char = lp.Character
	local setId = if char then tostring(char:GetAttribute("BC_AnimSet") or "—") else "—"
	local clip = if char then tostring(char:GetAttribute("BC_AnimClip") or "—") else "—"
	text.Text = string.format("set  %s\nclip %s\n(F8 / BC_AnimDebug)", setId, clip)
end

local function bindCharacter(char: Model)
	char:GetAttributeChangedSignal("BC_AnimSet"):Connect(refresh)
	char:GetAttributeChangedSignal("BC_AnimClip"):Connect(refresh)
	char:GetAttributeChangedSignal("BC_AnimDebug"):Connect(refresh)
	refresh()
end

function AnimDebugOverlay.start()
	if heartbeatConn then
		return
	end
	ensureGui()

	local acc = 0.0
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		refresh()
	end)

	inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F8 then
			local currently = isWanted()
			visibleForced = not currently
			local lp = Players.LocalPlayer
			if lp then
				lp:SetAttribute("BC_AnimDebug", visibleForced == true)
			end
			refresh()
		end
	end)

	local lp = Players.LocalPlayer
	if lp then
		lp:GetAttributeChangedSignal("BC_AnimDebug"):Connect(function()
			local v = lp:GetAttribute("BC_AnimDebug")
			if v == true then
				visibleForced = true
			elseif v == false then
				visibleForced = false
			end
			refresh()
		end)
		lp.CharacterAdded:Connect(bindCharacter)
		if lp.Character then
			bindCharacter(lp.Character)
		end
	end

	refresh()
	print("[BladeConcord] AnimDebugOverlay: F8 ou attribut BC_AnimDebug")
end

return AnimDebugOverlay
