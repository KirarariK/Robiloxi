--!strict
-- Hub : réagit aux ProximityPrompts (autel de relance, atelier, cercle des défis), mode « choisir un adversaire »
-- (clic / toucher sur un joueur, ou liste), demandes de défi reçues.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)
local Maid = require(Shared.Util.Maid)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Root = require(UI.Root)
local Remote = require(UI.Remote)
local Toast = require(UI.Toast)
local State = require(UI.State)
local ChallengeDialog = require(UI.ChallengeDialog)

local C = Theme.Colors

local HubController = {}
HubController.Priority = 80

local PICK_DURATION = 25

local pickMaid = Maid.new()
local picking = false
local spectatorConnection: RBXScriptConnection? = nil
local spectatorGui: ScreenGui? = nil
local spectatorArena: Model? = nil

local function stopObserving()
	if spectatorConnection then
		spectatorConnection:Disconnect()
		spectatorConnection = nil
	end
	if spectatorGui then
		spectatorGui:Destroy()
		spectatorGui = nil
	end
	spectatorArena = nil
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function observeArena(arena: Model)
	if spectatorArena == arena then
		stopObserving()
		return
	end
	if State.inDuel() then
		Toast.show("Tu ne peux pas observer pendant un duel.", "Info")
		return
	end
	if arena:GetAttribute("MatchActive") ~= true then
		Toast.show("Aucun duel en cours dans cette arène.", "Info")
		return
	end
	local center = arena:FindFirstChild("Center", true)
	if not center or not center:IsA("BasePart") then
		warn("[EtherBlades] repère Center absent de l'arène observée.")
		return
	end
	stopObserving()
	spectatorArena = arena

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable

	local gui = Instance.new("ScreenGui")
	gui.Name = "EB_Spectator"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	spectatorGui = gui

	local button = Instance.new("TextButton")
	button.Name = "StopObserving"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 48)
	button.Size = UDim2.fromOffset(210, 42)
	button.BackgroundColor3 = C.Panel
	button.BorderSizePixel = 0
	button.FontFace = Theme.Fonts.Bold
	button.Text = "ARRÊTER D'OBSERVER"
	button.TextColor3 = C.Gold
	button.TextSize = 14
	button.AutoButtonColor = true
	button.Parent = gui
	Kit.corner(button, 10)
	Kit.stroke(button, C.Gold, 1.2, 0.25)
	button.Activated:Connect(stopObserving)

	local elapsed = 0
	spectatorConnection = RunService.RenderStepped:Connect(function(dt: number)
		if not arena.Parent or arena:GetAttribute("MatchActive") ~= true or State.inDuel() then
			stopObserving()
			return
		end
		elapsed += dt * 0.18
		local target = center.Position + Vector3.new(0, 2, 0)
		local position = center.Position + Vector3.new(math.cos(elapsed) * 29, 15, math.sin(elapsed) * 29)
		camera.CFrame = CFrame.lookAt(position, target)
	end)
end

local function menu(): any?
	local m = script.Parent:FindFirstChild("MenuController")
	if m and m:IsA("ModuleScript") then
		return require(m) :: any
	end
	return nil
end

local function sendChallenge(target: Player)
	HubController.stopPicking()
	local ok = Remote.call("ChallengePlayer", false, target.UserId)
	if ok then
		Toast.show("Défi envoyé à " .. target.DisplayName .. ".", "Success")
	end
end

local function playerFromHit(inst: Instance?): Player?
	local node = inst
	while node and node ~= Workspace do
		if node:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(node)
			if p then
				return p
			end
		end
		node = node.Parent
	end
	return nil
end

function HubController.stopPicking()
	if not picking then
		return
	end
	picking = false
	pickMaid:Clean()
end

function HubController.startPicking()
	if picking or State.inDuel() then
		return
	end
	local lp = Players.LocalPlayer
	local others: { Player } = {}
	for _, p in Players:GetPlayers() do
		if p ~= lp then
			table.insert(others, p)
		end
	end
	if #others == 0 then
		Toast.show("Personne à défier sur ce serveur pour l'instant.", "Info")
		return
	end
	picking = true

	-- surbrillance des duellistes défiables
	for _, p in others do
		local char = p.Character
		if char then
			pickMaid:Give(Kit.new("Highlight", {
				Adornee = char,
				FillColor = C.Gold,
				FillTransparency = 0.8,
				OutlineColor = C.Gold,
				OutlineTransparency = 0.1,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				Parent = char,
			}))
		end
	end

	-- bandeau + liste (utile sur mobile)
	local panel = Kit.panel(Root.gui("Overlay"), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(560, 190),
		BackgroundColor3 = C.Bg,
	})
	Root.scale(panel)
	pickMaid:Give(panel)
	Kit.padding(panel, 12)
	Kit.label(panel, "CHOISIS TON ADVERSAIRE", { FontFace = Theme.Fonts.Title, TextSize = 14, TextColor3 = C.Gold })
	Kit.label(panel, "Clique sur un joueur dans le Hub ou choisis-le ci-dessous.", { Position = UDim2.fromOffset(0, 22), TextSize = 12, TextColor3 = C.TextDim })
	Kit.button(panel, "ANNULER", {
		Size = UDim2.fromOffset(100, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		TextSize = 12,
		Accent = C.Danger,
	}, function()
		HubController.stopPicking()
	end)
	local list = Kit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	Kit.list(list, true, 8)
	for i, p in others do
		local b = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(110, 112),
			BackgroundColor3 = C.Panel,
			LayoutOrder = i,
			Parent = list,
		})
		Kit.corner(b, 10)
		Kit.stroke(b, C.Gold, 1.2, 0.5)
		Kit.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(60, 60),
			BackgroundTransparency = 1,
			Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60", p.UserId),
			Parent = b,
		})
		Kit.label(b, p.DisplayName, {
			Position = UDim2.fromOffset(4, 72),
			Size = UDim2.new(1, -8, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = Theme.Fonts.Bold,
			TextSize = 12,
		})
		b.Activated:Connect(function()
			Kit.sound("Click", 0.4)
			sendChallenge(p)
		end)
	end

	-- clic / toucher dans le monde
	pickMaid:Give(UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local ray = cam:ViewportPointToRay(input.Position.X, input.Position.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { lp.Character :: Instance }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		local target = hit and playerFromHit(hit.Instance)
		if target and target ~= lp then
			sendChallenge(target)
		end
	end))
	pickMaid:Give(task.delay(PICK_DURATION, function()
		HubController.stopPicking()
	end))
end

function HubController.init()
	State.init()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if player ~= Players.LocalPlayer then
			return
		end
		local action = prompt:GetAttribute("EB_Action")
		if action == "OpenReroll" then
			local m = menu()
			if m then
				m.open("Reroll")
			end
		elseif action == "OpenWorkshop" then
			local m = menu()
			if m then
				m.open("Workshop")
			end
		elseif action == "ChallengePick" then
			if picking then
				HubController.stopPicking()
			else
				HubController.startPicking()
			end
		elseif action == "ObserveArena" then
			local arena = prompt:FindFirstAncestorOfClass("Model")
			if arena and arena:GetAttribute("HubArenaSlot") ~= nil then
				observeArena(arena)
			end
		end
	end)
	Net.event("ChallengeReceived").OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" or type(data.Id) ~= "string" then
			return
		end
		if State.inDuel() then
			Remote.call("RespondChallenge", true, data.Id, false)
			return
		end
		local id = data.Id :: string
		ChallengeDialog.show(data, function(accept: boolean)
			Remote.call("RespondChallenge", false, id, accept)
		end)
	end)
	State.MatchChanged:Connect(function(view: State.MatchView)
		if view.Active then
			HubController.stopPicking()
			stopObserving()
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(stopObserving)
end

return HubController
