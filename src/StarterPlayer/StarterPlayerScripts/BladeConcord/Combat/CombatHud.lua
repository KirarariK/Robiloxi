--!strict
--[[
	HUD combat : HP / stamina / score BO3 / CDs Focus / flash feedback.
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
local scoreLabel: TextLabel
local arenaLabel: TextLabel
local cdLabel: TextLabel
local fairKitLabel: TextLabel

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
	flashLabel.Size = UDim2.new(0.5, 0, 0, 40)
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
	statusLabel.Size = UDim2.new(0.45, 0, 0, 20)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 14
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	statusLabel.Text = "Blade Concord"
	statusLabel.Parent = root

	cdLabel = Instance.new("TextLabel")
	cdLabel.Name = "Cooldowns"
	cdLabel.Position = UDim2.new(0.02, 0, 0, 116)
	cdLabel.Size = UDim2.new(0.5, 0, 0, 18)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Font = Enum.Font.Gotham
	cdLabel.TextSize = 12
	cdLabel.TextXAlignment = Enum.TextXAlignment.Left
	cdLabel.TextColor3 = Color3.fromRGB(180, 200, 220)
	cdLabel.Text = ""
	cdLabel.Parent = root

	scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "Score"
	scoreLabel.AnchorPoint = Vector2.new(0.5, 0)
	scoreLabel.Position = UDim2.fromScale(0.5, 0.02)
	scoreLabel.Size = UDim2.new(0.4, 0, 0, 28)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.TextSize = 22
	scoreLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
	scoreLabel.Text = "BO3 — 0 : 0"
	scoreLabel.Parent = root

	arenaLabel = Instance.new("TextLabel")
	arenaLabel.Name = "Arena"
	arenaLabel.AnchorPoint = Vector2.new(0.5, 0)
	arenaLabel.Position = UDim2.fromScale(0.5, 0.055)
	arenaLabel.Size = UDim2.new(0.5, 0, 0, 18)
	arenaLabel.BackgroundTransparency = 1
	arenaLabel.Font = Enum.Font.Gotham
	arenaLabel.TextSize = 13
	arenaLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
	arenaLabel.Text = ""
	arenaLabel.Parent = root

	fairKitLabel = Instance.new("TextLabel")
	fairKitLabel.Name = "FairKit"
	fairKitLabel.AnchorPoint = Vector2.new(1, 0)
	fairKitLabel.Position = UDim2.new(0.98, 0, 0, 20)
	fairKitLabel.Size = UDim2.new(0.3, 0, 0, 20)
	fairKitLabel.BackgroundTransparency = 1
	fairKitLabel.Font = Enum.Font.GothamBold
	fairKitLabel.TextSize = 12
	fairKitLabel.TextXAlignment = Enum.TextXAlignment.Right
	fairKitLabel.TextColor3 = Color3.fromRGB(120, 220, 180)
	fairKitLabel.Text = ""
	fairKitLabel.Parent = root

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
				local formBit = ""
				if snap.formId then
					formBit = string.format(" · %s %s", tostring(snap.formId), tostring(snap.formRarity or ""))
				end
				statusLabel.Text = string.format(
					"HP %d · Stamina %d · %s%s",
					math.floor(snap.hp + 0.5),
					math.floor(snap.stamina + 0.5),
					tostring(snap.actionId),
					formBit
				)
				if snap.cooldowns then
					cdLabel.Text = string.format(
						"Esquive %.1fs · Dash %.1fs · Poussée %.1fs · Dash Focus %.1fs",
						snap.cooldowns.dodge or 0,
						snap.cooldowns.dash or 0,
						snap.cooldowns.focusPush or 0,
						snap.cooldowns.focusDash or 0
					)
				end
			end
		end
	end)

	remotes.MatchState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local myWins, theirWins = 0, 0
		if typeof(payload.scores) == "table" then
			for _, row in payload.scores do
				if row.userId == player.UserId then
					myWins = row.wins or 0
				else
					theirWins = row.wins or 0
				end
			end
		end
		local phase = tostring(payload.phase or "")
		local mode = tostring(payload.mode or "Casual")
		scoreLabel.Text = string.format("%s · Round %d · %d : %d (FT%d)", mode, payload.roundNumber or 0, myWins, theirWins, payload.firstTo or 2)
		arenaLabel.Text = tostring(payload.arenaName or payload.arenaId or "")
		if payload.fairKit then
			fairKitLabel.Text = "Fair Kit · STATS: RARE CAP"
		else
			fairKitLabel.Text = ""
		end
		if phase == "Countdown" and payload.countdown then
			flashLabel.Text = string.format("%.0f", math.ceil(payload.countdown))
			flashLabel.TextTransparency = 0
			flashLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
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
		elseif payload.riposte then
			flash("RIPOSTE", Color3.fromRGB(255, 180, 80))
		elseif payload.guardBreak then
			flash("GUARD BREAK", Color3.fromRGB(255, 100, 60))
		elseif payload.clash then
			flash("CLASH", Color3.fromRGB(200, 220, 255))
		elseif payload.dodged then
			flash("ESQUIVE", Color3.fromRGB(120, 255, 200))
		elseif payload.critical then
			flash("CRITICAL", Color3.fromRGB(255, 80, 100))
		end
	end)

	remotes.RoundEnded.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.matchOver then
			if payload.winnerUserId == player.UserId then
				flash("MATCH GAGNÉ", Color3.fromRGB(120, 255, 160))
			else
				flash("MATCH PERDU", Color3.fromRGB(255, 90, 90))
			end
		elseif payload.winnerUserId == player.UserId then
			flash("ROUND", Color3.fromRGB(120, 255, 160))
		elseif payload.winnerUserId == nil then
			flash("ÉGALITÉ", Color3.fromRGB(200, 200, 200))
		else
			flash("ROUND PERDU", Color3.fromRGB(255, 90, 90))
		end
	end)

	remotes.FxEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "FocusPushParried" then
			flash("POUSSÉE RENVOYÉE", Color3.fromRGB(200, 160, 255))
		elseif payload.kind == "FocusPush" then
			flash("POUSSÉE FOCUS", Color3.fromRGB(180, 140, 255))
		elseif payload.kind == "FocusDash" then
			flash("DASH FOCUS", Color3.fromRGB(140, 255, 220))
		end
	end)
end

return CombatHud
