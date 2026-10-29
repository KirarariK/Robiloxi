--!strict
-- CombatService : combat serveur-autoritaire d'Ether Blades (contrat « Combat » de docs/CONTRACTS.md).
-- Le client n'envoie que des intentions (remote CombatInput) ; ce service valide timings, cooldowns,
-- endurance, portée, puis applique. Actif en duel (1v1) et dans le Hub contre les mannequins (pas de PvP).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Config = require(Shared.Combat.CombatConfig)
local Guard = require(script.Parent.Guard)
local DataService = require(script.Parent.DataService)

local CombatFolder = script.Parent.Parent:WaitForChild("Combat")
local State = require(CombatFolder.State)
local Fighter = require(CombatFolder.Fighter)
local Validation = require(CombatFolder.Validation)
local Actions = require(CombatFolder.Actions)
local Dummies = require(CombatFolder.Dummies)
local Duels = require(CombatFolder.Duels)

type Fighter = State.Fighter

local CombatService = {}
CombatService.Priority = 20 -- après HitValidation (5) et AntiExploit (6), avant Match (100)

-- (matchId: string, winner: Player, loser: Player)
CombatService.RoundEnded = Duels.RoundEnded

--------------------------------------------------------------------------------
-- Équipement depuis le profil

type Loadout = { Form: string, Weapon: string, Color: string }

local function loadoutOf(player: Player): Loadout?
	local p = DataService.get(player)
	if not p then
		return nil
	end
	return { Form = p.EquippedForm, Weapon = p.EquippedWeapon, Color = p.EquippedColor }
end

local function applyProfileLoadout(f: Fighter)
	local p = f.Player
	if not p then
		return
	end
	local lo = loadoutOf(p)
	if lo and (lo.Form ~= f.Form.Id or lo.Weapon ~= f.Weapon.Id or lo.Color ~= f.ColorId) then
		Fighter.applyLoadout(f, lo.Form, lo.Weapon, lo.Color)
	end
end

-- Appelable par l'équipe UI (EquipService) après un changement d'équipement ; sinon relu toutes les secondes.
-- En duel, l'équipement est figé jusqu'à la fin du match.
function CombatService.refreshLoadout(player: Player)
	local f = State.byPlayer[player]
	if f and f.MatchId == nil then
		applyProfileLoadout(f)
	end
end

--------------------------------------------------------------------------------
-- Personnages

local function unbind(f: Fighter)
	State.remove(f)
	Validation.clearHistory(f.Model)
	Fighter.destroy(f)
end

local function bindCharacter(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not (hum and hum:IsA("Humanoid") and root and root:IsA("BasePart")) then
		warn("[EtherBlades][Combat] personnage incomplet pour " .. player.Name)
		return
	end
	if player.Character ~= character then
		return
	end
	local old = State.byPlayer[player]
	if old then
		unbind(old)
	end
	local f = Fighter.new(character, hum :: Humanoid, root :: BasePart, player, false)
	applyProfileLoadout(f)
	State.add(f)
	f.Maid:Give((hum :: Humanoid).Died:Connect(function()
		if f.MatchId then
			Duels.onDefeated(f)
		end
		f.Alive = false
	end))
	f.Maid:Give(character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) and State.fighters[character] == f then
			unbind(f)
		end
	end))
	Duels.onCharacterBound(f)
end

local function onPlayer(player: Player)
	if player.Character then
		task.spawn(bindCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(c: Model)
		bindCharacter(player, c)
	end)
end

--------------------------------------------------------------------------------
-- Intentions client : (action, dir?, clientTime?, seq?) — arguments plats uniquement

local function isFiniteVec(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < math.huge and math.abs(v.Y) < math.huge and math.abs(v.Z) < math.huge
end

local function onInput(player: Player, action: string, dir: Vector3?, clientTime: number?, seq: number?)
	if not Config.ActionSet[action] then
		return
	end
	local f = State.byPlayer[player]
	if not f or f.Model ~= player.Character then
		return
	end
	local d: Vector3? = nil
	if dir then
		if not isFiniteVec(dir) or dir.Magnitude > Config.Net.MaxDirMagnitude then
			return
		end
		d = dir
	end
	local ct: number? = nil
	if clientTime and math.abs(workspace:GetServerTimeNow() - clientTime) <= Config.Net.MaxClientSkew then
		ct = clientTime
	end
	local s: number? = if seq and seq >= 0 and seq < 2 ^ 31 then math.floor(seq) else nil
	Actions.input(f, action, d, ct, s)
end

--------------------------------------------------------------------------------
-- API du contrat (utilisée par l'équipe Match)

function CombatService.beginDuel(matchId: string, a: Player, b: Player, arena: Model)
	Duels.begin(matchId, a, b, arena)
end

function CombatService.playIntro(matchId: string)
	Duels.playIntro(matchId)
end

function CombatService.startRound(matchId: string)
	Duels.startRound(matchId)
end

function CombatService.playFinisher(matchId: string, winner: Player, loser: Player)
	Duels.playFinisher(matchId, winner, loser)
end

function CombatService.endDuel(matchId: string)
	Duels.endDuel(matchId)
end

-- Lecture seule pour d'autres services (ex. emotes : refuser pendant une attaque).
function CombatService.getState(player: Player): string?
	local f = State.byPlayer[player]
	return if f then f.State else nil
end

--------------------------------------------------------------------------------
-- Cycle de vie

function CombatService.init()
	Validation.init(script.Parent)
	Duels.setLoadoutProvider(applyProfileLoadout)
	State.hooks.attackStarted = function(attacker: Fighter, windup: number, _kind: string)
		Dummies.onAttackStarted(attacker, windup)
	end
	State.hooks.defeated = function(f: Fighter, _source: Fighter?)
		if f.IsDummy then
			Dummies.onDefeated(f)
		elseif f.MatchId then
			Duels.onDefeated(f)
		end
	end
	State.hooks.pushNpc = function(f: Fighter, offset: Vector3)
		Dummies.push(f, offset)
	end

	Guard.event("CombatInput", { "string", "Vector3?", "number?", "number?" }, Config.Net.InputRate, Config.Net.InputBurst, onInput)

	DataService.ProfileLoaded:Connect(function(player: Player)
		CombatService.refreshLoadout(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		Duels.onPlayerLeaving(player)
		local f = State.byPlayer[player]
		if f then
			unbind(f)
		end
		State.playerDuel[player] = nil
	end)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

function CombatService.start()
	local pollClock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local now = State.now()
		for _, f in State.fighters do
			Actions.tick(f, now, dt)
		end
		Duels.tick()
		Dummies.tick(now, dt)
		pollClock += dt
		if pollClock >= Config.Hub.LoadoutPoll then
			pollClock = 0
			for p, f in State.byPlayer do
				if f.MatchId == nil then
					applyProfileLoadout(f)
				end
			end
		end
	end)
	Dummies.start()
end

return CombatService
