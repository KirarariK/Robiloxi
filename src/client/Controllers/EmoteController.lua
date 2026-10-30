--!strict
-- Emotes : roue radiale (touche B maintenue, DPad bas à la manette, bouton ✦ sur mobile), demande au serveur,
-- lecture des emotes de tous les joueurs via Combat.ProceduralAnimator, annulation au déplacement.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)
local EmoteData = require(Shared.Config.EmoteData)

local Client = script.Parent.Parent
local ClientState = require(Client:WaitForChild("ClientState"))
local UI = Client:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Root = require(UI.Root)
local Toast = require(UI.Toast)
local State = require(UI.State)
local EmoteWheel = require(UI.EmoteWheel)

local C = Theme.Colors

local EmoteController = {}
EmoteController.Priority = 60

type Playing = { Stop: () -> (), Token: number }
local playing: { [Player]: Playing } = {}
local token = 0
local wheel: EmoteWheel.Wheel
local mobileButton: TextButton? = nil
local lastStopSent = 0

local warnedAnimator = false
local function animator(): any?
	local folder = Client:FindFirstChild("Combat")
	local mod = folder and folder:FindFirstChild("ProceduralAnimator")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and type(res) == "table" and type(res.play) == "function" then
			return res
		end
	end
	if not warnedAnimator then
		warnedAnimator = true
		warn("[EtherBlades] Combat.ProceduralAnimator absent : les emotes ne sont pas animées.")
	end
	return nil
end

local function stopFor(p: Player)
	local cur = playing[p]
	if cur then
		playing[p] = nil
		local ok, err = pcall(cur.Stop)
		if not ok then
			warn("[EtherBlades] arrêt d'emote : " .. tostring(err))
		end
	end
end

local function playFor(p: Player, id: string)
	local def = EmoteData.get(id)
	local char = p.Character
	if not def or not char then
		return
	end
	stopFor(p)
	local anim = animator()
	if not anim then
		return
	end
	local ok, stop = pcall(anim.play, char, "Emote_" .. id, { Looped = def.Looped, Speed = 1 })
	if not ok or type(stop) ~= "function" then
		warn("[EtherBlades] ProceduralAnimator.play(Emote_" .. id .. ") : " .. tostring(stop))
		return
	end
	token += 1
	local my = token
	playing[p] = { Stop = stop, Token = my }
	if not def.Looped then
		task.delay(def.Duration + 0.1, function()
			local cur = playing[p]
			if cur and cur.Token == my then
				stopFor(p)
			end
		end)
	end
end

local function canUseWheel(): boolean
	local m = State.match
	if m.Active and m.Phase ~= "Intro" and m.Phase ~= "Preparing" and m.Phase ~= "Victory" then
		Toast.show("Pas d'emote pendant le combat.", "Error")
		return false
	end
	return true
end

local function equipped(): { string }
	local p = ClientState.getProfile()
	return if p and type(p.EquippedEmotes) == "table" then p.EquippedEmotes else {}
end

local function pick(slot: number)
	local ids = equipped()
	local id = ids[slot]
	EmoteController.closeWheel()
	if id then
		Net.event("PlayEmote"):FireServer(id)
	end
end

local function sinkAction(_name: string, inputState: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if input.KeyCode == Enum.KeyCode.ButtonA or input.UserInputType == Enum.UserInputType.MouseButton1 then
		local h = wheel.hovered()
		if h then
			pick(h)
		end
	end
	EmoteController.closeWheel()
	return Enum.ContextActionResult.Sink
end

function EmoteController.openWheel()
	if wheel.isOpen() or not canUseWheel() then
		return
	end
	if #equipped() == 0 then
		Toast.show("Aucune emote équipée (Menu → Inventaire → Emotes).", "Info")
		return
	end
	wheel.open(equipped())
	ContextActionService:BindActionAtPriority("EB_EmoteWheel", sinkAction, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.UserInputType.MouseButton1)
end

function EmoteController.closeWheel()
	ContextActionService:UnbindAction("EB_EmoteWheel")
	wheel.close()
end

local function buildMobileButton()
	if not UserInputService.TouchEnabled then
		return
	end
	local holder = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -200, 1, -40),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Parent = Root.gui("Hud"),
	})
	Root.scale(holder)
	local b = Kit.button(holder, "✦", { Size = UDim2.fromScale(1, 1), TextSize = 28, Accent = C.Gold }, function()
		if wheel.isOpen() then
			EmoteController.closeWheel()
		else
			EmoteController.openWheel()
		end
	end)
	Kit.round(b)
	mobileButton = b
end

function EmoteController.init()
	State.init()
	wheel = EmoteWheel.new(pick)
	Net.event("EmotePlayed").OnClientEvent:Connect(function(p: any, id: any)
		if typeof(p) == "Instance" and p:IsA("Player") and type(id) == "string" then
			playFor(p, id)
		end
	end)
	Net.event("EmoteStopped").OnClientEvent:Connect(function(p: any)
		if typeof(p) == "Instance" and p:IsA("Player") then
			stopFor(p)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.DPadDown then
			if wheel.isOpen() then
				EmoteController.closeWheel()
			else
				EmoteController.openWheel()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		-- B maintenu puis relâché : joue l'emote survolée
		if input.KeyCode == Enum.KeyCode.B and wheel.isOpen() then
			local h = wheel.hovered()
			if h then
				pick(h)
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 and wheel.isOpen() then
			wheel.setStick(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	-- annulation de sa propre emote dès qu'on bouge ou saute
	RunService.Heartbeat:Connect(function()
		local lp = Players.LocalPlayer
		if not playing[lp] then
			return
		end
		local char = lp.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and (hum.MoveDirection.Magnitude > 0.1 or hum.Jump) then
			stopFor(lp)
			if os.clock() - lastStopSent > 0.5 then
				lastStopSent = os.clock()
				Net.event("StopEmote"):FireServer()
			end
		end
	end)
	State.MatchChanged:Connect(function(view: State.MatchView)
		if view.Active and (view.Phase == "Round" or view.Phase == "Preparing") then
			EmoteController.closeWheel()
			stopFor(Players.LocalPlayer)
			if view.OpponentUserId then
				local opp = Players:GetPlayerByUserId(view.OpponentUserId)
				if opp then
					stopFor(opp)
				end
			end
		end
		if mobileButton then
			mobileButton.Visible = not view.Active or view.Phase == "Intro" or view.Phase == "Victory"
		end
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		stopFor(p)
	end)
	local function hook(p: Player)
		p.CharacterRemoving:Connect(function()
			stopFor(p)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	buildMobileButton()
end

return EmoteController
