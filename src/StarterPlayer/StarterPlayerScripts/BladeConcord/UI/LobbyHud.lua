--!strict
--[[
	UI Salon Concord — Casual / Classé / Jouer / Quitter file.
	Visible uniquement en phase Lobby. Forme équipée + crédits.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))
local FormConfig = require(Shared:WaitForChild("FormConfig"))
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))

local LobbyHud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local root: Frame
local creditsLabel: TextLabel
local formLabel: TextLabel
local statusLabel: TextLabel
local playButton: TextButton
local casualBtn: TextButton
local rankedBtn: TextButton
local leaveBtn: TextButton
local selectedMode: "Casual" | "Ranked" = "Casual"
local inQueue = false
local soloMatchmaking = false
local visible = true
local profile: any = nil

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = 0.35
	s.Parent = parent
	return s
end

local function formDisplayName(formId: string): string
	local def = FormConfig.Forms[formId]
	if def and typeof(def.displayName) == "string" then
		return def.displayName
	end
	return formId
end

local function refreshModeButtons()
	if selectedMode == "Casual" then
		casualBtn.BackgroundColor3 = Theme.Accent
		casualBtn.TextColor3 = Theme.Ink
		rankedBtn.BackgroundColor3 = Theme.InkSoft
		rankedBtn.TextColor3 = Theme.Bone
	else
		rankedBtn.BackgroundColor3 = Theme.Success
		rankedBtn.TextColor3 = Theme.Ink
		casualBtn.BackgroundColor3 = Theme.InkSoft
		casualBtn.TextColor3 = Theme.Bone
	end
end

local function refreshPlayLabel()
	if soloMatchmaking then
		playButton.Text = "RECHERCHE…"
		playButton.BackgroundColor3 = Theme.InkSoft
		playButton.TextColor3 = Theme.Muted
		statusLabel.Text = "Matchmaking Amical · adversaire IA sous peu"
		leaveBtn.Visible = true
	elseif inQueue then
		playButton.Text = "EN FILE…"
		playButton.BackgroundColor3 = Theme.InkSoft
		playButton.TextColor3 = Theme.Muted
		statusLabel.Text = if selectedMode == "Ranked"
			then "File Classé · " .. RankedConfig.FairKitBadge
			else "File Amical · en attente d'un adversaire"
		leaveBtn.Visible = true
	else
		playButton.Text = "JOUER"
		playButton.BackgroundColor3 = Theme.Accent
		playButton.TextColor3 = Theme.Ink
		statusLabel.Text = if selectedMode == "Ranked"
			then "Classé · stats Fair Kit (plafond Rare)"
			else "Amical · stats full · bot si solo"
		leaveBtn.Visible = false
	end
end

local function refreshProfile()
	if not profile then
		creditsLabel.Text = "Crédits —"
		formLabel.Text = "Forme —"
		return
	end
	creditsLabel.Text = string.format("Crédits  %d", profile.credits or 0)
	local fname = formDisplayName(tostring(profile.equippedFormId or "?"))
	local rar = tostring(profile.equippedFormRarity or "")
	formLabel.Text = string.format("Forme  %s · %s", fname, rar)
end

local function setVisible(v: boolean)
	visible = v
	root.Visible = v
end

function LobbyHud.start()
	local remotes = Remotes.get()
	local metaRemotes = Remotes.getMeta()

	gui = Instance.new("ScreenGui")
	gui.Name = "BladeConcordLobby"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 22
	gui.Parent = player:WaitForChild("PlayerGui")

	root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	-- Panneau bas-centre (composition claire, pas dashboard)
	local panel = Instance.new("Frame")
	panel.Name = "LobbyPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -36)
	panel.Size = UDim2.new(0, 420, 0, 210)
	panel.BackgroundColor3 = Theme.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = root
	corner(panel, 14)
	stroke(panel, Theme.PanelEdge, 1.4)

	local topAccent = Instance.new("Frame")
	topAccent.Size = UDim2.new(1, 0, 0, 3)
	topAccent.BackgroundColor3 = Theme.Accent
	topAccent.BorderSizePixel = 0
	topAccent.Parent = panel

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Position = UDim2.new(0, 20, 0, 14)
	brand.Size = UDim2.new(1, -40, 0, 24)
	brand.Font = Theme.FontTitle
	brand.TextSize = 20
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.TextColor3 = Theme.Bone
	brand.Text = Theme.Brand
	brand.Parent = panel

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 20, 0, 38)
	sub.Size = UDim2.new(1, -40, 0, 16)
	sub.Font = Theme.FontBody
	sub.TextSize = 12
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Theme.Muted
	sub.Text = "Salon · choisis un mode puis Jouer"
	sub.Parent = panel

	creditsLabel = Instance.new("TextLabel")
	creditsLabel.BackgroundTransparency = 1
	creditsLabel.Position = UDim2.new(0, 20, 0, 58)
	creditsLabel.Size = UDim2.new(0.48, 0, 0, 16)
	creditsLabel.Font = Theme.FontBody
	creditsLabel.TextSize = 12
	creditsLabel.TextXAlignment = Enum.TextXAlignment.Left
	creditsLabel.TextColor3 = Theme.Accent
	creditsLabel.Text = "Crédits —"
	creditsLabel.Parent = panel

	formLabel = Instance.new("TextLabel")
	formLabel.BackgroundTransparency = 1
	formLabel.Position = UDim2.new(0.48, 0, 0, 58)
	formLabel.Size = UDim2.new(0.48, -12, 0, 16)
	formLabel.Font = Theme.FontBody
	formLabel.TextSize = 12
	formLabel.TextXAlignment = Enum.TextXAlignment.Right
	formLabel.TextColor3 = Theme.Muted
	formLabel.Text = "Forme —"
	formLabel.Parent = panel

	casualBtn = Instance.new("TextButton")
	casualBtn.Name = "Casual"
	casualBtn.Position = UDim2.new(0, 20, 0, 84)
	casualBtn.Size = UDim2.new(0.5, -26, 0, 36)
	casualBtn.BackgroundColor3 = Theme.Accent
	casualBtn.BorderSizePixel = 0
	casualBtn.Font = Theme.FontTitle
	casualBtn.TextSize = 14
	casualBtn.TextColor3 = Theme.Ink
	casualBtn.Text = "AMICAL"
	casualBtn.AutoButtonColor = true
	casualBtn.Parent = panel
	corner(casualBtn, 8)

	rankedBtn = Instance.new("TextButton")
	rankedBtn.Name = "Ranked"
	rankedBtn.Position = UDim2.new(0.5, 6, 0, 84)
	rankedBtn.Size = UDim2.new(0.5, -26, 0, 36)
	rankedBtn.BackgroundColor3 = Theme.InkSoft
	rankedBtn.BorderSizePixel = 0
	rankedBtn.Font = Theme.FontTitle
	rankedBtn.TextSize = 14
	rankedBtn.TextColor3 = Theme.Bone
	rankedBtn.Text = "CLASSÉ"
	rankedBtn.AutoButtonColor = true
	rankedBtn.Parent = panel
	corner(rankedBtn, 8)

	playButton = Instance.new("TextButton")
	playButton.Name = "Play"
	playButton.Position = UDim2.new(0, 20, 0, 130)
	playButton.Size = UDim2.new(1, -40, 0, 40)
	playButton.BackgroundColor3 = Theme.Accent
	playButton.BorderSizePixel = 0
	playButton.Font = Theme.FontTitle
	playButton.TextSize = 18
	playButton.TextColor3 = Theme.Ink
	playButton.Text = "JOUER"
	playButton.AutoButtonColor = true
	playButton.Parent = panel
	corner(playButton, 10)
	stroke(playButton, Theme.Bone, 1.2).Transparency = 0.55

	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.new(0, 20, 0, 174)
	statusLabel.Size = UDim2.new(1, -120, 0, 22)
	statusLabel.Font = Theme.FontBody
	statusLabel.TextSize = 12
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Theme.Muted
	statusLabel.Text = "Amical · stats full · bot si solo"
	statusLabel.Parent = panel

	leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveQueue"
	leaveBtn.AnchorPoint = Vector2.new(1, 0)
	leaveBtn.Position = UDim2.new(1, -20, 0, 174)
	leaveBtn.Size = UDim2.new(0, 88, 0, 22)
	leaveBtn.BackgroundColor3 = Theme.InkSoft
	leaveBtn.BorderSizePixel = 0
	leaveBtn.Font = Theme.FontBody
	leaveBtn.TextSize = 11
	leaveBtn.TextColor3 = Theme.Danger
	leaveBtn.Text = "QUITTER"
	leaveBtn.Visible = false
	leaveBtn.AutoButtonColor = true
	leaveBtn.Parent = panel
	corner(leaveBtn, 6)

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -252)
	hint.Size = UDim2.new(0, 360, 0, 18)
	hint.Font = Theme.FontBody
	hint.TextSize = 12
	hint.TextColor3 = Theme.Muted
	hint.Text = "M · méta  ·  Premier à 2 manches"
	hint.Parent = root

	casualBtn.MouseButton1Click:Connect(function()
		if inQueue or soloMatchmaking then
			return
		end
		selectedMode = "Casual"
		refreshModeButtons()
		refreshPlayLabel()
	end)

	rankedBtn.MouseButton1Click:Connect(function()
		if inQueue or soloMatchmaking then
			return
		end
		selectedMode = "Ranked"
		refreshModeButtons()
		refreshPlayLabel()
	end)

	playButton.MouseButton1Click:Connect(function()
		if inQueue or soloMatchmaking then
			return
		end
		playButton.Text = "…"
		TweenService:Create(playButton, TweenInfo.new(0.12), {
			Size = UDim2.new(1, -48, 0, 38),
		}):Play()
		task.delay(0.12, function()
			playButton.Size = UDim2.new(1, -40, 0, 40)
		end)
		metaRemotes.QueueMatch:FireServer({ mode = selectedMode })
	end)

	leaveBtn.MouseButton1Click:Connect(function()
		metaRemotes.LeaveQueue:FireServer()
		inQueue = false
		soloMatchmaking = false
		refreshPlayLabel()
	end)

	refreshModeButtons()
	refreshPlayLabel()

	metaRemotes.MetaState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.profile then
			profile = payload.profile
			refreshProfile()
		end
	end)

	remotes.MatchState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local phase = tostring(payload.phase)
		setVisible(phase == "Lobby")

		if phase ~= "Lobby" then
			inQueue = false
			soloMatchmaking = false
			return
		end

		soloMatchmaking = payload.soloMatchmaking == true
		local queued = false
		if typeof(payload.queuedUserIds) == "table" then
			for _, uid in payload.queuedUserIds do
				if uid == player.UserId then
					queued = true
					break
				end
			end
		end
		inQueue = queued or soloMatchmaking
		if typeof(payload.mode) == "string" and (payload.mode == "Casual" or payload.mode == "Ranked") then
			if inQueue then
				selectedMode = payload.mode
				refreshModeButtons()
			end
		end
		refreshPlayLabel()
	end)
end

return LobbyHud
