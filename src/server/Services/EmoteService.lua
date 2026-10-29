--!strict
-- Emotes : validation serveur (emote équipée, personnage vivant, phase autorisée) puis diffusion à tous les clients,
-- qui la jouent via ProceduralAnimator. En duel, seules les phases d'intro (Salut) et de fin (Victoire, Salut) l'autorisent.
-- Crée aussi les prompts « Méditer » sur Workspace.Hub.MeditationSpot_1..4.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)
local EmoteData = require(Shared.Config.EmoteData)

local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Guard)
local MatchService = require(script.Parent.MatchService)
local HubPrompts = require(script.Parent.Parent.Match.HubPrompts)
local Deps = require(script.Parent.Parent.Match.Deps)

local EmoteService = {}
EmoteService.Priority = 60

type Playing = { Id: string, Token: number }
local playing: { [Player]: Playing } = {}
local token = 0

local function alive(player: Player): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

function EmoteService.stop(player: Player)
	if playing[player] then
		playing[player] = nil
		Net.event("EmoteStopped"):FireAllClients(player)
	end
end

-- Lecture validée côté serveur. `force` contourne la vérification d'équipement (méditation du Hub).
function EmoteService.play(player: Player, id: string, force: boolean?): (boolean, string?)
	local def = EmoteData.get(id)
	if not def then
		return false, "Emote inconnue."
	end
	local profile = DataService.get(player)
	if not profile then
		return false, "Profil en cours de chargement…"
	end
	if not force and not table.find(profile.EquippedEmotes, id) then
		return false, "Emote non équipée."
	end
	if not alive(player) then
		return false, "Impossible maintenant."
	end
	local ok, reason = MatchService.emoteAllowed(player, def)
	if not ok then
		return false, reason
	end
	token += 1
	local my = token
	playing[player] = { Id = id, Token = my }
	Net.event("EmotePlayed"):FireAllClients(player, id)
	if not def.Looped then
		task.delay(def.Duration, function()
			local cur = playing[player]
			if cur and cur.Token == my then
				playing[player] = nil
			end
		end)
	end
	return true, nil
end

function EmoteService.init()
	Guard.event("PlayEmote", { "string" }, 2, 4, function(player: Player, id: string)
		local ok, reason = EmoteService.play(player, id)
		if not ok and reason then
			Net.event("Notify"):FireClient(player, { Text = reason, Kind = "Error" })
		end
	end)
	Guard.event("StopEmote", {}, 4, 8, function(player: Player)
		EmoteService.stop(player)
	end)
	MatchService.PhaseChanged:Connect(function(players: { Player }, phase: string)
		if phase == "Round" or phase == "Preparing" then
			for _, p in players do
				EmoteService.stop(p)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(newPlayer: Player)
		-- les emotes en boucle déjà en cours (méditation) sont rejouées chez le nouvel arrivant
		task.delay(3, function()
			for p, cur in playing do
				local def = EmoteData.get(cur.Id)
				if def and def.Looped and p.Parent and newPlayer.Parent then
					Net.event("EmotePlayed"):FireClient(newPlayer, p, cur.Id)
				end
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		playing[p] = nil
	end)
	local function hookCharacter(p: Player)
		p.CharacterRemoving:Connect(function()
			EmoteService.stop(p)
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, p in Players:GetPlayers() do
		hookCharacter(p)
	end
end

function EmoteService.start()
	for i = 1, 4 do
		task.spawn(function()
			local spot = HubPrompts.getPart("MeditationSpot_" .. i, 5)
			if not spot then
				return
			end
			local prompt = HubPrompts.attach(spot, {
				Action = "Meditate",
				ActionText = "Méditer",
				ObjectText = "Cercle de méditation",
				HoldDuration = 0.4,
				MaxDistance = 8,
			})
			prompt.Triggered:Connect(function(player: Player)
				if player:GetAttribute("EB_InMatch") or not HubPrompts.isNear(player, spot, 14) then
					return
				end
				if player.Character then
					Deps.teleport(player, CFrame.new(spot.Position + Vector3.new(0, 3, 0)) * spot.CFrame.Rotation)
				end
				EmoteService.play(player, "Meditation", true)
			end)
		end)
	end
end

return EmoteService
