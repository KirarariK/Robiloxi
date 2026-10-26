--!strict
--[[
	HUD combat soigné — HP / stamina / score BO3 / CDs Focus / flash feedback.
	Identité Blade Concord (Theme), pas le look default Roblox.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))

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
local vignette: Frame

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = 0.35
	s.Parent = parent
end

local function makeBar(parent: Instance, name: string, y: number, color: Color3): Frame
	local wrap = Instance.new("Frame")
	wrap.Name = name .. "Wrap"
	wrap.Size = UDim2.new(0.3, 0, 0, 22)
	wrap.Position = UDim2.new(0.02, 0, 0, y)
	wrap.BackgroundColor3 = Theme.InkSoft
	wrap.BackgroundTransparency = 0.15
	wrap.BorderSizePixel = 0
	wrap.Parent = parent
	corner(wrap, 6)
	stroke(wrap, Theme.PanelEdge, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = wrap
	corner(fill, 6)

	local glow = Instance.new("Frame")
	glow.Name = "Sheen"
	glow.Size = UDim2.new(1, 0, 0.35, 0)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = 0.75
	glow.BorderSizePixel = 0
	glow.Parent = fill
	corner(glow, 6)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.Font = Theme.FontBody
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Bone
	label.Text = name
	label.ZIndex = 2
	label.Parent = wrap

	return fill
end

function CombatHud.start()
	local remotes = Remotes.get()

	gui = Instance.new("ScreenGui")
	gui.Name = "BladeConcordHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	-- Vignette douce
	vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Theme.Ink
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 50
	vignette.Parent = root

	local brand = Instance.new("TextLabel")
	brand.Name = "Brand"
	brand.Position = UDim2.new(0.02, 0, 0, 14)
	brand.Size = UDim2.new(0.4, 0, 0, 26)
	brand.BackgroundTransparency = 1
	brand.Font = Theme.FontTitle
	brand.TextSize = 20
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.TextColor3 = Theme.Bone
	brand.Text = Theme.Brand
	brand.Parent = root

	local brandAccent = Instance.new("Frame")
	brandAccent.Size = UDim2.new(0, 48, 0, 3)
	brandAccent.Position = UDim2.new(0.02, 0, 0, 40)
	brandAccent.BackgroundColor3 = Theme.Accent
	brandAccent.BorderSizePixel = 0
	brandAccent.Parent = root
	corner(brandAccent, 2)

	hpFill = makeBar(root, "VITALITÉ", 52, Theme.Danger)
	staminaFill = makeBar(root, "ENDURANCE", 80, Theme.Stamina)

	flashLabel = Instance.new("TextLabel")
	flashLabel.Name = "Flash"
	flashLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	flashLabel.Position = UDim2.fromScale(0.5, 0.38)
	flashLabel.Size = UDim2.new(0.6, 0, 0, 48)
	flashLabel.BackgroundTransparency = 1
	flashLabel.Font = Theme.FontTitle
	flashLabel.TextSize = 34
	flashLabel.TextColor3 = Theme.Perfect
	flashLabel.TextTransparency = 1
	flashLabel.TextStrokeTransparency = 0.5
	flashLabel.Text = ""
	flashLabel.Parent = root

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Position = UDim2.new(0.02, 0, 0, 110)
	statusLabel.Size = UDim2.new(0.48, 0, 0, 18)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Theme.FontMono
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Theme.Muted
	statusLabel.Text = Theme.Brand
	statusLabel.Parent = root

	cdLabel = Instance.new("TextLabel")
	cdLabel.Name = "Cooldowns"
	cdLabel.Position = UDim2.new(0.02, 0, 0, 130)
	cdLabel.Size = UDim2.new(0.55, 0, 0, 16)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Font = Theme.FontMono
	cdLabel.TextSize = 11
	cdLabel.TextXAlignment = Enum.TextXAlignment.Left
	cdLabel.TextColor3 = Theme.Accent
	cdLabel.Text = ""
	cdLabel.Parent = root

	local scorePlate = Instance.new("Frame")
	scorePlate.Name = "ScorePlate"
	scorePlate.AnchorPoint = Vector2.new(0.5, 0)
	scorePlate.Position = UDim2.fromScale(0.5, 0.018)
	scorePlate.Size = UDim2.new(0, 320, 0, 52)
	scorePlate.BackgroundColor3 = Theme.Panel
	scorePlate.BackgroundTransparency = 0.2
	scorePlate.BorderSizePixel = 0
	scorePlate.Parent = root
	corner(scorePlate, 10)
	stroke(scorePlate, Theme.PanelEdge, 1.2)

	scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "Score"
	scoreLabel.Size = UDim2.new(1, 0, 0, 28)
	scoreLabel.Position = UDim2.new(0, 0, 0, 4)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Font = Theme.FontTitle
	scoreLabel.TextSize = 20
	scoreLabel.TextColor3 = Theme.Bone
	scoreLabel.Text = "BO3 — 0 : 0"
	scoreLabel.Parent = scorePlate

	arenaLabel = Instance.new("TextLabel")
	arenaLabel.Name = "Arena"
	arenaLabel.Size = UDim2.new(1, 0, 0, 18)
	arenaLabel.Position = UDim2.new(0, 0, 0, 30)
	arenaLabel.BackgroundTransparency = 1
	arenaLabel.Font = Theme.FontBody
	arenaLabel.TextSize = 12
	arenaLabel.TextColor3 = Theme.Muted
	arenaLabel.Text = ""
	arenaLabel.Parent = scorePlate

	fairKitLabel = Instance.new("TextLabel")
	fairKitLabel.Name = "FairKit"
	fairKitLabel.AnchorPoint = Vector2.new(1, 0)
	fairKitLabel.Position = UDim2.new(0.98, 0, 0, 18)
	fairKitLabel.Size = UDim2.new(0.28, 0, 0, 22)
	fairKitLabel.BackgroundColor3 = Theme.InkSoft
	fairKitLabel.BackgroundTransparency = 0.25
	fairKitLabel.BorderSizePixel = 0
	fairKitLabel.Font = Theme.FontBody
	fairKitLabel.TextSize = 11
	fairKitLabel.TextColor3 = Theme.Success
	fairKitLabel.Text = ""
	fairKitLabel.Parent = root
	corner(fairKitLabel, 6)

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			if snap.userId == player.UserId then
				local hpFrac = math.clamp(snap.hp / CombatConfig.MaxHp, 0, 1)
				local staFrac = math.clamp(snap.stamina / CombatConfig.Stamina.Max, 0, 1)
				TweenService:Create(hpFill, TweenInfo.new(0.12), { Size = UDim2.new(hpFrac, 0, 1, 0) }):Play()
				TweenService:Create(staminaFill, TweenInfo.new(0.1), { Size = UDim2.new(staFrac, 0, 1, 0) }):Play()
				if snap.flags and snap.flags.exhausted then
					staminaFill.BackgroundColor3 = Theme.Danger
				else
					staminaFill.BackgroundColor3 = Theme.Stamina
				end
				local formBit = ""
				if snap.formId then
					formBit = string.format(" · %s %s", tostring(snap.formId), tostring(snap.formRarity or ""))
				end
				statusLabel.Text = string.format(
					"%d PV · %d END · %s%s",
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
		local mode = tostring(payload.mode or "Casual")
		scoreLabel.Text = string.format("%s · R%d · %d : %d (FT%d)", mode, payload.roundNumber or 0, myWins, theirWins, payload.firstTo or 2)
		arenaLabel.Text = tostring(payload.arenaName or payload.arenaId or "")
		if payload.fairKit then
			fairKitLabel.Text = "  Fair Kit · Rare cap  "
			fairKitLabel.BackgroundTransparency = 0.15
		else
			fairKitLabel.Text = ""
			fairKitLabel.BackgroundTransparency = 1
		end
		if tostring(payload.phase) == "Countdown" and payload.countdown then
			flashLabel.Text = string.format("%.0f", math.ceil(payload.countdown))
			flashLabel.TextTransparency = 0
			flashLabel.TextColor3 = Theme.Bone
		end
	end)

	local function flash(text: string, color: Color3)
		flashLabel.Text = text
		flashLabel.TextColor3 = color
		flashLabel.TextTransparency = 0
		flashLabel.TextStrokeTransparency = 0.35
		vignette.BackgroundTransparency = 0.82
		TweenService:Create(flashLabel, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
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
			flash("PARADE PARFAITE", Theme.Perfect)
		elseif payload.riposte then
			flash("RIPOSTE", Theme.AccentHot)
		elseif payload.guardBreak then
			flash("GARDE BRISÉE", Theme.Danger)
		elseif payload.clash then
			flash("CLASH", Theme.Clash)
		elseif payload.dodged then
			flash("ESQUIVE", Theme.Success)
		elseif payload.critical then
			flash("CRITIQUE", Theme.Danger)
		end
	end)

	remotes.RoundEnded.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.matchOver then
			if payload.winnerUserId == player.UserId then
				flash("CONCORDANCE — VICTOIRE", Theme.Success)
			else
				flash("DÉFAITE", Theme.Danger)
			end
		elseif payload.winnerUserId == player.UserId then
			flash("ROUND GAGNÉ", Theme.Success)
		elseif payload.winnerUserId == nil then
			flash("ÉGALITÉ", Theme.Muted)
		else
			flash("ROUND PERDU", Theme.Danger)
		end
	end)

	remotes.FxEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "FocusPushParried" then
			flash("POUSSÉE RENVOYÉE", Theme.Focus)
		elseif payload.kind == "FocusPush" then
			flash("POUSSÉE FOCUS", Theme.Focus)
		elseif payload.kind == "FocusDash" then
			flash("DASH FOCUS", Theme.BladeFocus)
		end
	end)
end

return CombatHud
