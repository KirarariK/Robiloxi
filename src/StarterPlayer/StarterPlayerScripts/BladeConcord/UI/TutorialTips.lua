--!strict
--[[
	Tips première session — 1–2 tooltips FR (LMB/RMB · P/M).
	Non-intrusif (bas d’écran), dismiss ou auto-avance ; une fois par join.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local TutorialTips = {}

local ATTR = "BC_TipsSeen"
local AUTO_ADVANCE = 5.5
local SHOW_DELAY = 1.8

local TIPS = {
	{
		title = "Combat",
		body = "LMB attaquer · RMB parer (hold)",
	},
	{
		title = "Menus",
		body = "P showcase anim · M panneau méta",
	},
}

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local tipIndex = 0
local dismissed = false
local hideToken = 0

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = 0.4
	s.Parent = parent
	return s
end

local function markSeen()
	player:SetAttribute(ATTR, true)
	dismissed = true
end

local function destroyGui()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

local function showTip(index: number)
	if dismissed or index > #TIPS then
		markSeen()
		destroyGui()
		return
	end
	tipIndex = index
	hideToken += 1
	local token = hideToken
	local tip = TIPS[index]

	if not gui then
		local g = Instance.new("ScreenGui")
		g.Name = "BC_TutorialTips"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 35
		g.Parent = player:WaitForChild("PlayerGui")
		gui = g
	end
	assert(gui)

	local old = gui:FindFirstChild("TipCard")
	if old then
		old:Destroy()
	end

	local card = Instance.new("Frame")
	card.Name = "TipCard"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -28)
	card.Size = UDim2.new(0, 320, 0, 56)
	card.BackgroundColor3 = Theme.Panel
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.Parent = gui
	corner(card, 10)
	stroke(card, Theme.Accent, 1.2)

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 3, 1, -12)
	accent.Position = UDim2.new(0, 8, 0, 6)
	accent.BackgroundColor3 = Theme.Accent
	accent.BorderSizePixel = 0
	accent.Parent = card
	corner(accent, 2)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 18, 0, 6)
	title.Size = UDim2.new(1, -56, 0, 18)
	title.Font = Theme.FontTitle
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Accent
	title.Text = string.format("%s · %d/%d", tip.title, index, #TIPS)
	title.Parent = card

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 18, 0, 26)
	body.Size = UDim2.new(1, -56, 0, 22)
	body.Font = Theme.FontBody
	body.TextSize = 14
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextColor3 = Theme.Bone
	body.Text = tip.body
	body.Parent = card

	local dismiss = Instance.new("TextButton")
	dismiss.Name = "Dismiss"
	dismiss.AnchorPoint = Vector2.new(1, 0.5)
	dismiss.Position = UDim2.new(1, -8, 0.5, 0)
	dismiss.Size = UDim2.new(0, 28, 0, 28)
	dismiss.BackgroundColor3 = Theme.InkSoft
	dismiss.BackgroundTransparency = 0.25
	dismiss.BorderSizePixel = 0
	dismiss.Font = Theme.FontTitle
	dismiss.TextSize = 16
	dismiss.TextColor3 = Theme.Muted
	dismiss.Text = "×"
	dismiss.AutoButtonColor = true
	dismiss.Parent = card
	corner(dismiss, 6)

	card.BackgroundTransparency = 1
	title.TextTransparency = 1
	body.TextTransparency = 1
	dismiss.TextTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.12,
	}):Play()
	TweenService:Create(title, TweenInfo.new(0.28), { TextTransparency = 0 }):Play()
	TweenService:Create(body, TweenInfo.new(0.28), { TextTransparency = 0 }):Play()
	TweenService:Create(dismiss, TweenInfo.new(0.28), { TextTransparency = 0 }):Play()

	local function advanceOrClose(allDone: boolean)
		if token ~= hideToken or dismissed then
			return
		end
		if allDone or index >= #TIPS then
			markSeen()
			TweenService:Create(card, TweenInfo.new(0.22), { BackgroundTransparency = 1 }):Play()
			task.delay(0.25, destroyGui)
			return
		end
		TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
		task.delay(0.2, function()
			if token == hideToken and not dismissed then
				showTip(index + 1)
			end
		end)
	end

	dismiss.MouseButton1Click:Connect(function()
		advanceOrClose(true)
	end)

	-- Esc / clic hors zone = dismiss all (non-bloquant)
	local escConn: RBXScriptConnection? = nil
	escConn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if escConn then
				escConn:Disconnect()
			end
			advanceOrClose(true)
		end
	end)

	task.delay(AUTO_ADVANCE, function()
		if escConn then
			escConn:Disconnect()
		end
		advanceOrClose(false)
	end)
end

function TutorialTips.start()
	if player:GetAttribute(ATTR) == true then
		return
	end
	-- Mobile : tips clavier peu utiles — skip silencieux
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		markSeen()
		return
	end
	task.delay(SHOW_DELAY, function()
		if player:GetAttribute(ATTR) == true or dismissed then
			return
		end
		showTip(1)
	end)
end

return TutorialTips
