--!strict
--[[
	Mode Showcase (BC_Showcase) — touche P.
	Cycle auto des 32 sets d'animations avec Billboard labels.
	Prêt enregistrement clip : caméra 3/4 figée, combat input coupé.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blade = ReplicatedStorage:WaitForChild("BladeConcord")
local Shared = Blade:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local AnimationSets = require(Blade:WaitForChild("Animation"):WaitForChild("AnimationSets"))

local CombatAnimator = require(script.Parent:WaitForChild("CombatAnimator"))
local InputCombat = require(script.Parent:WaitForChild("InputCombat"))
local SoftLockCamera = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("SoftLockCamera"))

local AnimationShowcase = {}

local active = false
local generation = 0
local billboardGui: BillboardGui? = nil
local hudGui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local setTitleLabel: TextLabel? = nil
local setSubLabel: TextLabel? = nil

-- Clips démo par set (ordre lecture pour le clip)
local DEMO_CLIPS: { string } = {
	"Idle",
	"StartupLight",
	"ActiveLight",
	"RecoveryLight",
	"Guard",
	"StartupHeavy",
	"ActiveHeavy",
	"RecoveryHeavy",
}

local function clipHold(clipName: string): number
	local light = CombatConfig.Light
	local heavy = CombatConfig.Heavy
	if clipName == "Idle" then
		return 0.55
	elseif clipName == "Guard" then
		return 0.45
	elseif clipName == "StartupLight" then
		return light.Startup + 0.02
	elseif clipName == "ActiveLight" then
		return light.Active + 0.02
	elseif clipName == "RecoveryLight" then
		return light.Recovery + 0.02
	elseif clipName == "StartupHeavy" then
		return heavy.Startup + 0.02
	elseif clipName == "ActiveHeavy" then
		return heavy.Active + 0.02
	elseif clipName == "RecoveryHeavy" then
		return heavy.Recovery + 0.02
	elseif clipName == "Dodge" or clipName == "Dash" then
		return 0.35
	elseif clipName == "Feint" then
		return 0.28
	elseif clipName == "Dead" or clipName == "Stagger" then
		return 0.5
	elseif clipName == "FocusPush" or clipName == "FocusDash" then
		return 0.4
	elseif clipName == "Riposte" then
		return light.Startup + 0.05
	end
	return 0.4
end

local function ensureBillboard(character: Model): BillboardGui
	local existing = character:FindFirstChild("BC_ShowcaseBillboard")
	if existing and existing:IsA("BillboardGui") then
		billboardGui = existing
		return existing
	end

	local adorn = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	local gui = Instance.new("BillboardGui")
	gui.Name = "BC_ShowcaseBillboard"
	gui.Size = UDim2.fromOffset(320, 72)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	if adorn and adorn:IsA("BasePart") then
		gui.Adornee = adorn
		gui.Parent = adorn
	else
		gui.Parent = character
	end

	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Theme.Ink
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.new(0, 8, 0, 8)
	title.Font = Theme.FontTitle
	title.TextSize = 18
	title.TextColor3 = Theme.Bone
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "—"
	title.Parent = bg

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -16, 0, 22)
	sub.Position = UDim2.new(0, 8, 0, 38)
	sub.Font = Theme.FontBody
	sub.TextSize = 13
	sub.TextColor3 = Theme.Accent
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = ""
	sub.Parent = bg

	billboardGui = gui
	setTitleLabel = title
	setSubLabel = sub
	return gui
end

local function ensureHud(): ScreenGui
	local player = Players.LocalPlayer
	local existing = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("BC_Showcase")
	if existing and existing:IsA("ScreenGui") then
		hudGui = existing
		statusLabel = existing:FindFirstChild("Status") :: TextLabel?
		return existing
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BC_Showcase"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 18)
	banner.Size = UDim2.new(0, 420, 0, 56)
	banner.BackgroundColor3 = Theme.Ink
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = banner
	local s = Instance.new("UIStroke")
	s.Color = Theme.Accent
	s.Thickness = 1.5
	s.Parent = banner

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Size = UDim2.new(1, -20, 0, 22)
	brand.Position = UDim2.new(0, 10, 0, 6)
	brand.Font = Theme.FontTitle
	brand.TextSize = 16
	brand.TextColor3 = Theme.Accent
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.Text = Theme.Brand .. " — SHOWCASE"
	brand.Parent = banner

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -20, 0, 20)
	status.Position = UDim2.new(0, 10, 0, 30)
	status.Font = Theme.FontBody
	status.TextSize = 13
	status.TextColor3 = Theme.Muted
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = "P pour quitter · cycle auto des sets"
	status.Parent = banner

	hudGui = gui
	statusLabel = status
	return gui
end

local function setLabels(index: number, total: number, displayName: string, setId: string, clipName: string)
	if setTitleLabel then
		setTitleLabel.Text = string.format("%d / %d  ·  %s", index, total, displayName)
	end
	if setSubLabel then
		setSubLabel.Text = string.format("%s  ·  %s", setId, clipName)
	end
	if statusLabel then
		statusLabel.Text = string.format("Set %d/%d · %s · clip %s · P quitter", index, total, displayName, clipName)
	end
end

local function destroyUi()
	if billboardGui then
		billboardGui:Destroy()
		billboardGui = nil
	end
	setTitleLabel = nil
	setSubLabel = nil
	if hudGui then
		hudGui:Destroy()
		hudGui = nil
	end
	statusLabel = nil
end

local function placeShowcaseCamera(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = Workspace.CurrentCamera
	if not hrp or not camera then
		return
	end
	SoftLockCamera.beginCinematic()
	-- Angle 3/4 face — lecture arcs de lame lisibles pour clip
	local focus = hrp.Position + Vector3.new(0, 1.6, 0)
	local offset = hrp.CFrame:VectorToWorldSpace(Vector3.new(5.5, 2.8, 7.5))
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(hrp.Position + offset, focus)
end

local function restoreCamera()
	SoftLockCamera.endCinematic()
end

local function runCycle(myGen: number)
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		warn("[BladeConcord] BC_Showcase: pas de Character")
		AnimationShowcase.stop()
		return
	end

	ensureHud()
	ensureBillboard(character)
	placeShowcaseCamera(character)

	local sets = AnimationSets.Sets
	local total = #sets
	print(string.format("[BladeConcord] BC_Showcase ON — %d sets · P pour quitter", total))

	while active and myGen == generation do
		for i, setDef in sets do
			if not active or myGen ~= generation then
				return
			end
			character = player.Character
			if not character then
				AnimationShowcase.stop()
				return
			end
			-- Refresh billboard si respawn mid-cycle
			ensureBillboard(character)
			placeShowcaseCamera(character)

			for _, clipName in DEMO_CLIPS do
				if not active or myGen ~= generation then
					return
				end
				setLabels(i, total, setDef.displayName, setDef.id, clipName)
				CombatAnimator.playDirect(character, setDef.id, clipName)
				local hold = clipHold(clipName)
				local t0 = os.clock()
				while os.clock() - t0 < hold do
					if not active or myGen ~= generation then
						return
					end
					RunService.Heartbeat:Wait()
				end
			end

			-- Pause courte entre sets (lisibilité labels)
			local gap = 0.25
			local tGap = os.clock()
			while os.clock() - tGap < gap do
				if not active or myGen ~= generation then
					return
				end
				RunService.Heartbeat:Wait()
			end
		end
		-- Boucle continue pour takes longs
		if statusLabel then
			statusLabel.Text = "Boucle terminée — restart auto · P quitter"
		end
	end
end

function AnimationShowcase.isActive(): boolean
	return active
end

function AnimationShowcase.start()
	if active then
		return
	end
	active = true
	generation += 1
	local myGen = generation

	CombatAnimator.setPaused(true)
	InputCombat.setEnabled(false)

	task.spawn(function()
		local player = Players.LocalPlayer
		local character = player.Character
		if not character then
			-- CharacterAdded race : attendre spawn avant cycle (évite stop immédiat)
			character = player.CharacterAdded:Wait()
		end
		if not active or myGen ~= generation then
			return
		end
		character:WaitForChild("Humanoid", 8)
		character:WaitForChild("HumanoidRootPart", 5)
		if character.Parent then
			character:SetAttribute("BC_Showcase", true)
		end
		runCycle(myGen)
	end)
end

function AnimationShowcase.stop()
	if not active then
		return
	end
	active = false
	generation += 1

	local character = Players.LocalPlayer.Character
	if character then
		character:SetAttribute("BC_Showcase", false)
	end

	destroyUi()
	restoreCamera()
	CombatAnimator.setPaused(false)
	InputCombat.setEnabled(true)
	print("[BladeConcord] BC_Showcase OFF")
end

function AnimationShowcase.toggle()
	if active then
		AnimationShowcase.stop()
	else
		AnimationShowcase.start()
	end
end

function AnimationShowcase.bind()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.P then
			AnimationShowcase.toggle()
		end
	end)
end

return AnimationShowcase
