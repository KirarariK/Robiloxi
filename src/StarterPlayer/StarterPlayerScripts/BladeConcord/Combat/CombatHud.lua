--!strict
--[[
	HUD stub : barres HP / stamina + flash perfect / guard break.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CombatHud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local hpFill: Frame
local staminaFill: Frame
local flashLabel: TextLabel
local statusLabel: TextLabel

local function makeBar(parent: Instance, name: string, y: number, color: Color3): Frame
	local bg = Instance.new("Frame")
	bg.Name = name .. "Bg"
	bg.Size = UDim2.new(0.28, 0, 0, 18)
	bg.Position = UDim2.new(0.02, 0, 0, y)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	bg.BorderSizePixel = 0
	bg.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = name
	label.Parent = bg

	return fill
end

function CombatHud.start()
	local remotes = Remotes.get()

	gui = Instance.new("ScreenGui")
	gui.Name = "BladeConcordHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	hpFill = makeBar(root, "HP", 48, Color3.fromRGB(200, 60, 70))
	staminaFill = makeBar(root, "Stamina", 72, Color3.fromRGB(70, 160, 220))

	flashLabel = Instance.new("TextLabel")
	flashLabel.Name = "Flash"
	flashLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	flashLabel.Position = UDim2.fromScale(0.5, 0.35)
	flashLabel.Size = UDim2.new(0.4, 0, 0, 40)
	flashLabel.BackgroundTransparency = 1
	flashLabel.Font = Enum.Font.GothamBlack
	flashLabel.TextSize = 28
	flashLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	flashLabel.TextTransparency = 1
	flashLabel.Text = ""
	flashLabel.Parent = root

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Position = UDim2.new(0.02, 0, 0, 96)
	statusLabel.Size = UDim2.new(0.4, 0, 0, 20)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 14
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	statusLabel.Text = "Blade Concord — Obsidian Pit"
	statusLabel.Parent = root

	local brand = Instance.new("TextLabel")
	brand.Name = "Brand"
	brand.Position = UDim2.new(0.02, 0, 0, 20)
	brand.Size = UDim2.new(0.4, 0, 0, 24)
	brand.BackgroundTransparency = 1
	brand.Font = Enum.Font.GothamBold
	brand.TextSize = 18
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.TextColor3 = Color3.fromRGB(230, 230, 240)
	brand.Text = "Blade Concord"
	brand.Parent = root

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			if snap.userId == player.UserId then
				local hpFrac = math.clamp(snap.hp / CombatConfig.MaxHp, 0, 1)
				local staFrac = math.clamp(snap.stamina / CombatConfig.Stamina.Max, 0, 1)
				hpFill.Size = UDim2.new(hpFrac, 0, 1, 0)
				staminaFill.Size = UDim2.new(staFrac, 0, 1, 0)
				if snap.flags and snap.flags.exhausted then
					staminaFill.BackgroundColor3 = Color3.fromRGB(220, 80, 60)
				else
					staminaFill.BackgroundColor3 = Color3.fromRGB(70, 160, 220)
				end
				statusLabel.Text = string.format(
					"HP %d · Stamina %d · %s",
					math.floor(snap.hp + 0.5),
					math.floor(snap.stamina + 0.5),
					tostring(snap.actionId)
				)
			end
		end
	end)

	local function flash(text: string, color: Color3)
		flashLabel.Text = text
		flashLabel.TextColor3 = color
		flashLabel.TextTransparency = 0
		TweenService:Create(flashLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		}):Play()
	end

	remotes.HitResolved.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local involvesMe = payload.attackerUserId == player.UserId or payload.defenderUserId == player.UserId
		if not involvesMe then
			return
		end
		if payload.perfect then
			flash("PERFECT", Color3.fromRGB(255, 230, 120))
		elseif payload.guardBreak then
			flash("GUARD BREAK", Color3.fromRGB(255, 100, 60))
		elseif payload.clash then
			flash("CLASH", Color3.fromRGB(200, 220, 255))
		elseif payload.critical then
			flash("CRITICAL", Color3.fromRGB(255, 80, 100))
		end
	end)

	remotes.RoundEnded.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.winnerUserId == player.UserId then
			flash("VICTOIRE", Color3.fromRGB(120, 255, 160))
		elseif payload.winnerUserId == nil then
			flash("ÉGALITÉ", Color3.fromRGB(200, 200, 200))
		else
			flash("DÉFAITE", Color3.fromRGB(255, 90, 90))
		end
	end)
end

return CombatHud
