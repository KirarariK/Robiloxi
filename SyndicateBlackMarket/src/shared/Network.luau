--!strict
--[[
	Network.luau
	Couche réseau unique du jeu.

	- Chaque remote est déclaré ici avec un schéma de champs typés. Les arguments sont
	  sérialisés dans un buffer compact (u8/u16/u32/i32/f32/f64/bool/string/vector3/cframe) ;
	  les Instances voyagent dans une table annexe et sont référencées par index u8.
	- Côté serveur, chaque payload client est décodé sous pcall et rejeté s'il est mal
	  formé (taille, types, NaN/inf, chaînes trop longues, octets en trop).
	- Limitation de débit par joueur et par remote (seau à jetons RateLimit/s, rafale Burst).
	- Un seul gestionnaire Roblox par remote ; plusieurs abonnés possibles côté Luau.

	Usage :
		Network.init()  -- serveur : crée les remotes ; client : les attend
		Network.onServerEvent("FireWeapon", function(player, origin, direction, shotTime, slot) ... end)
		Network.fireServer("FireWeapon", origin, direction, shotTime, slot)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Util.Signal)
local MathUtil = require(script.Parent.Util.MathUtil)

export type FieldKind =
	"u8"
	| "u16"
	| "u32"
	| "i32"
	| "f32"
	| "f64"
	| "bool"
	| "string"
	| "vector3"
	| "cframe"
	| "instance"
	| "instance?"

export type Schema = { FieldKind }
export type Direction = "ToServer" | "ToClient"

export type RemoteDefinition = {
	Name: string,
	Direction: Direction,
	Schema: Schema,
	Unreliable: boolean,
	RateLimit: number,
	Burst: number,
}

type Bucket = {
	Tokens: number,
	Last: number,
}

type ServerHandler = (Player, ...any) -> ()
type ClientHandler = (...any) -> ()

local FOLDER_NAME = "SBM_Remotes"
local MAX_STRING_TO_SERVER = 256
local MAX_STRING_TO_CLIENT = 65535
local MAX_INSTANCES = 255
local WAIT_TIMEOUT = 60
local VIOLATION_WARN_INTERVAL = 5

--// Déclarations

local definitions: { [string]: RemoteDefinition } = {}

local function toServer(name: string, schema: Schema, rateLimit: number, burst: number)
	assert(definitions[name] == nil, "Network : remote dupliqué " .. name)
	definitions[name] = table.freeze({
		Name = name,
		Direction = "ToServer" :: Direction,
		Schema = table.freeze(schema),
		Unreliable = false,
		RateLimit = rateLimit,
		Burst = burst,
	})
end

local function toClient(name: string, schema: Schema, unreliable: boolean)
	assert(definitions[name] == nil, "Network : remote dupliqué " .. name)
	definitions[name] = table.freeze({
		Name = name,
		Direction = "ToClient" :: Direction,
		Schema = table.freeze(schema),
		Unreliable = unreliable,
		RateLimit = 0,
		Burst = 0,
	})
end

-- Client -> Serveur (intentions uniquement ; le serveur valide tout)
toServer("ClientReady", {}, 1, 2)
toServer("FireWeapon", { "vector3", "vector3", "f64", "u8" }, 20, 6) -- origine, direction, horodatage serveur, slot
toServer("ReloadWeapon", {}, 2, 2)
toServer("EquipSlot", { "u8" }, 6, 3)
toServer("SetPosture", { "u8" }, 10, 4)
toServer("RequestSlide", { "vector3" }, 2, 2) -- direction de glissade
toServer("ThrowBag", { "vector3" }, 3, 2) -- direction caméra
toServer("PickupBag", { "instance" }, 4, 3)
toServer("Interact", { "instance" }, 6, 3)
toServer("HackPress", { "u32", "u8", "f64" }, 8, 4) -- session, palier, horodatage serveur de l'appui
toServer("DeployEMP", { "vector3" }, 1, 1)
toServer("PurchaseUpgrade", { "string" }, 3, 3)
toServer("SelectContract", { "string" }, 2, 2)
toServer("PartyInvite", { "instance" }, 2, 2)
toServer("PartyRespond", { "instance", "bool" }, 2, 2)
toServer("PartyLeave", {}, 1, 1)
toServer("PartyLaunch", {}, 1, 1)
toServer("RequestSquadRevive", {}, 1, 1)
toServer("MiningToggle", { "bool" }, 2, 2)

-- Serveur -> Client
toClient("DataSync", { "string" }, false) -- JSON de PlayerData
toClient("Notify", { "u8", "string" }, false) -- NotifyKind, texte
toClient("DetectionUpdate", { "instance?", "f32", "u8" }, true) -- source, suspicion 0..100, GuardState
toClient("HeistState", { "u8", "u8", "f32", "u32" }, false) -- phase, vague, minuteur, valeur sécurisée
toClient("CarryUpdate", { "u32", "f32", "f32" }, false) -- valeur portée, poids, poids max
toClient("HackStart", { "u32", "instance", "f32", "f32", "f64" }, false) -- session, terminal, cycles/s, largeur zone, début
toClient("HackStage", { "u32", "u8", "bool", "f32", "f32" }, false) -- session, palier, réussi, centre zone suivante, cycles/s suivant
toClient("HackEnd", { "u32", "bool" }, false)
toClient("SquadDown", { "f32", "u32" }, false) -- compte à rebours, butin en jeu
toClient("SquadRevived", {}, false)
toClient("WeaponState", { "u8", "u16", "u16", "bool" }, false) -- slot, chargeur, réserve, rechargement
toClient("HitMarker", { "vector3", "bool", "bool" }, true) -- position, tête, mortel
toClient("Damaged", { "vector3", "f32" }, true) -- origine, dégâts
toClient("PlaySound", { "string", "vector3" }, true)
toClient("PartyUpdate", { "string" }, false) -- JSON de l'escouade
toClient("LockdownLights", { "bool" }, false)
toClient("NoiseEmitted", { "vector3", "f32" }, true) -- visualisation locale du bruit
toClient("Extraction", { "f32", "bool" }, false) -- compte à rebours, actif

--// Sérialisation

local function isInteger(value: number, min: number, max: number): boolean
	return value == math.floor(value) and value >= min and value <= max
end

local function sizeOf(schema: Schema, values: { any }): number
	local size = 0
	for index, kind in schema do
		if kind == "u8" or kind == "bool" or kind == "instance" or kind == "instance?" then
			size += 1
		elseif kind == "u16" then
			size += 2
		elseif kind == "u32" or kind == "i32" or kind == "f32" then
			size += 4
		elseif kind == "f64" then
			size += 8
		elseif kind == "vector3" then
			size += 12
		elseif kind == "cframe" then
			size += 24
		elseif kind == "string" then
			size += 2 + #(values[index] :: string)
		end
	end
	return size
end

local function validateOutgoing(definition: RemoteDefinition, values: { any }, count: number)
	local schema = definition.Schema
	if count ~= #schema then
		error(`Network : {definition.Name} attend {#schema} argument(s), reçu {count}`, 4)
	end
	for index, kind in schema do
		local value = values[index]
		local valueType = typeof(value)
		local valid: boolean
		if kind == "u8" then
			valid = valueType == "number" and isInteger(value, 0, 255)
		elseif kind == "u16" then
			valid = valueType == "number" and isInteger(value, 0, 65535)
		elseif kind == "u32" then
			valid = valueType == "number" and isInteger(value, 0, 4294967295)
		elseif kind == "i32" then
			valid = valueType == "number" and isInteger(value, -2147483648, 2147483647)
		elseif kind == "f32" or kind == "f64" then
			valid = valueType == "number" and MathUtil.isFinite(value)
		elseif kind == "bool" then
			valid = valueType == "boolean"
		elseif kind == "string" then
			valid = valueType == "string" and #value <= 65535
		elseif kind == "vector3" then
			valid = valueType == "Vector3" and MathUtil.isFiniteVector(value)
		elseif kind == "cframe" then
			valid = valueType == "CFrame" and MathUtil.isFiniteVector((value :: CFrame).Position)
		elseif kind == "instance" then
			valid = valueType == "Instance"
		else
			valid = value == nil or valueType == "Instance"
		end
		if not valid then
			error(`Network : {definition.Name} argument #{index} invalide (attendu {kind}, reçu {valueType})`, 4)
		end
	end
end

local function encode(definition: RemoteDefinition, values: { any }): (buffer, { Instance })
	local schema = definition.Schema
	local buf = buffer.create(sizeOf(schema, values))
	local instances: { Instance } = {}
	local offset = 0
	for index, kind in schema do
		local value = values[index]
		if kind == "u8" then
			buffer.writeu8(buf, offset, value)
			offset += 1
		elseif kind == "u16" then
			buffer.writeu16(buf, offset, value)
			offset += 2
		elseif kind == "u32" then
			buffer.writeu32(buf, offset, value)
			offset += 4
		elseif kind == "i32" then
			buffer.writei32(buf, offset, value)
			offset += 4
		elseif kind == "f32" then
			buffer.writef32(buf, offset, value)
			offset += 4
		elseif kind == "f64" then
			buffer.writef64(buf, offset, value)
			offset += 8
		elseif kind == "bool" then
			buffer.writeu8(buf, offset, if value then 1 else 0)
			offset += 1
		elseif kind == "string" then
			local text: string = value
			buffer.writeu16(buf, offset, #text)
			buffer.writestring(buf, offset + 2, text)
			offset += 2 + #text
		elseif kind == "vector3" then
			local vector: Vector3 = value
			buffer.writef32(buf, offset, vector.X)
			buffer.writef32(buf, offset + 4, vector.Y)
			buffer.writef32(buf, offset + 8, vector.Z)
			offset += 12
		elseif kind == "cframe" then
			local cframe: CFrame = value
			local axis, angle = cframe:ToAxisAngle()
			local rotation = axis * angle
			buffer.writef32(buf, offset, cframe.X)
			buffer.writef32(buf, offset + 4, cframe.Y)
			buffer.writef32(buf, offset + 8, cframe.Z)
			buffer.writef32(buf, offset + 12, rotation.X)
			buffer.writef32(buf, offset + 16, rotation.Y)
			buffer.writef32(buf, offset + 20, rotation.Z)
			offset += 24
		else
			if value == nil then
				buffer.writeu8(buf, offset, 0)
			else
				if #instances >= MAX_INSTANCES then
					error(`Network : {definition.Name} dépasse {MAX_INSTANCES} instances`, 3)
				end
				table.insert(instances, value :: Instance)
				buffer.writeu8(buf, offset, #instances)
			end
			offset += 1
		end
	end
	return buf, instances
end

local function readFinite(buf: buffer, offset: number): number
	local value = buffer.readf32(buf, offset)
	if not MathUtil.isFinite(value) then
		error("valeur non finie")
	end
	return value
end

local function readAll(schema: Schema, buf: buffer, instances: { [number]: Instance }, maxString: number): { any }
	local values: { any } = table.create(#schema)
	local offset = 0
	for index, kind in schema do
		if kind == "u8" then
			values[index] = buffer.readu8(buf, offset)
			offset += 1
		elseif kind == "u16" then
			values[index] = buffer.readu16(buf, offset)
			offset += 2
		elseif kind == "u32" then
			values[index] = buffer.readu32(buf, offset)
			offset += 4
		elseif kind == "i32" then
			values[index] = buffer.readi32(buf, offset)
			offset += 4
		elseif kind == "f32" then
			values[index] = readFinite(buf, offset)
			offset += 4
		elseif kind == "f64" then
			local value = buffer.readf64(buf, offset)
			if not MathUtil.isFinite(value) then
				error("valeur non finie")
			end
			values[index] = value
			offset += 8
		elseif kind == "bool" then
			local raw = buffer.readu8(buf, offset)
			if raw > 1 then
				error("booléen invalide")
			end
			values[index] = raw == 1
			offset += 1
		elseif kind == "string" then
			local length = buffer.readu16(buf, offset)
			if length > maxString then
				error("chaîne trop longue")
			end
			values[index] = buffer.readstring(buf, offset + 2, length)
			offset += 2 + length
		elseif kind == "vector3" then
			values[index] = Vector3.new(readFinite(buf, offset), readFinite(buf, offset + 4), readFinite(buf, offset + 8))
			offset += 12
		elseif kind == "cframe" then
			local position = Vector3.new(readFinite(buf, offset), readFinite(buf, offset + 4), readFinite(buf, offset + 8))
			local rotation = Vector3.new(readFinite(buf, offset + 12), readFinite(buf, offset + 16), readFinite(buf, offset + 20))
			local angle = rotation.Magnitude
			if angle > 1e-6 then
				values[index] = CFrame.fromAxisAngle(rotation / angle, angle) + position
			else
				values[index] = CFrame.new(position)
			end
			offset += 24
		else
			local reference = buffer.readu8(buf, offset)
			offset += 1
			if reference == 0 then
				if kind == "instance" then
					error("instance requise")
				end
				values[index] = nil
			else
				local instance = instances[reference]
				if instance == nil and kind == "instance" then
					error("instance manquante")
				end
				values[index] = instance
			end
		end
	end
	if offset ~= buffer.len(buf) then
		error("octets en trop")
	end
	return values
end

local function sanitizeInstances(raw: unknown): { [number]: Instance }?
	local result: { [number]: Instance } = {}
	if raw == nil then
		return result
	end
	if typeof(raw) ~= "table" then
		return nil
	end
	local count = 0
	for key, value in raw :: { [any]: any } do
		count += 1
		if count > MAX_INSTANCES or typeof(key) ~= "number" or not isInteger(key, 1, MAX_INSTANCES) then
			return nil
		end
		if typeof(value) ~= "Instance" then
			return nil
		end
		result[key] = value
	end
	return result
end

local function decode(definition: RemoteDefinition, payload: unknown, rawInstances: unknown, maxString: number): { any }?
	if typeof(payload) ~= "buffer" then
		return nil
	end
	local instances = sanitizeInstances(rawInstances)
	if instances == nil then
		return nil
	end
	local ok, result = pcall(readAll, definition.Schema, payload :: buffer, instances, maxString)
	if not ok then
		return nil
	end
	return result
end

--// État

local remotes: { [string]: any } = {}
local serverHandlers: { [string]: { ServerHandler } } = {}
local clientHandlers: { [string]: { ClientHandler } } = {}
local listening: { [string]: boolean } = {}
local buckets: { [Player]: { [string]: Bucket } } = {}
local lastViolationWarn: { [Player]: number } = {}
local initialized = false

local Network = {}

Network.Definitions = table.freeze(definitions)
-- (joueur, nom du remote, raison : "rate" | "payload")
local violation: Signal.Signal<Player, string, string> = Signal.new()
Network.Violation = violation

local function getDefinition(name: string, direction: Direction): RemoteDefinition
	local definition = definitions[name]
	if definition == nil then
		error(`Network : remote inconnu « {name} »`, 3)
	end
	if definition.Direction ~= direction then
		error(`Network : « {name} » est déclaré {definition.Direction}`, 3)
	end
	return definition
end

local function getRemote(name: string): any
	if not initialized then
		error("Network : appelle Network.init() avant d'utiliser les remotes", 3)
	end
	local remote = remotes[name]
	if remote == nil then
		error(`Network : remote « {name} » introuvable`, 3)
	end
	return remote
end

local function consumeToken(player: Player, definition: RemoteDefinition): boolean
	local perPlayer = buckets[player]
	if perPlayer == nil then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[definition.Name]
	if bucket == nil then
		bucket = { Tokens = definition.Burst, Last = now }
		perPlayer[definition.Name] = bucket
	end
	bucket.Tokens = math.min(definition.Burst, bucket.Tokens + (now - bucket.Last) * definition.RateLimit)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function reportViolation(player: Player, name: string, reason: string)
	local now = os.clock()
	local last = lastViolationWarn[player]
	if last == nil or now - last >= VIOLATION_WARN_INTERVAL then
		lastViolationWarn[player] = now
		warn(`Network : {player.Name} -> {name} rejeté ({reason})`)
	end
	Network.Violation:Fire(player, name, reason)
end

local function listenServer(definition: RemoteDefinition)
	if listening[definition.Name] then
		return
	end
	listening[definition.Name] = true
	local remote = getRemote(definition.Name)
	remote.OnServerEvent:Connect(function(player: Player, payload: unknown, rawInstances: unknown)
		if not consumeToken(player, definition) then
			reportViolation(player, definition.Name, "rate")
			return
		end
		local values = decode(definition, payload, rawInstances, MAX_STRING_TO_SERVER)
		if values == nil then
			reportViolation(player, definition.Name, "payload")
			return
		end
		local count = #definition.Schema
		local handlers = serverHandlers[definition.Name]
		if handlers == nil then
			return
		end
		for _, handler in table.clone(handlers) do
			task.spawn(handler, player, table.unpack(values, 1, count))
		end
	end)
end

local function listenClient(definition: RemoteDefinition)
	if listening[definition.Name] then
		return
	end
	listening[definition.Name] = true
	local remote = getRemote(definition.Name)
	remote.OnClientEvent:Connect(function(payload: unknown, rawInstances: unknown)
		local values = decode(definition, payload, rawInstances, MAX_STRING_TO_CLIENT)
		if values == nil then
			warn(`Network : payload serveur invalide pour {definition.Name}`)
			return
		end
		local count = #definition.Schema
		local handlers = clientHandlers[definition.Name]
		if handlers == nil then
			return
		end
		for _, handler in table.clone(handlers) do
			task.spawn(handler, table.unpack(values, 1, count))
		end
	end)
end

function Network.init()
	if initialized then
		return
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing ~= nil then
			existing:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		for name, definition in definitions do
			local remote: Instance = if definition.Unreliable
				then Instance.new("UnreliableRemoteEvent")
				else Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
			remotes[name] = remote
		end
		folder.Parent = ReplicatedStorage
		Players.PlayerRemoving:Connect(function(player: Player)
			buckets[player] = nil
			lastViolationWarn[player] = nil
		end)
	else
		local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
		if folder == nil then
			error("Network : dossier des remotes introuvable (le serveur a-t-il appelé Network.init ?)")
		end
		for name in definitions do
			local remote = folder:WaitForChild(name, WAIT_TIMEOUT)
			if remote == nil or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then
				error(`Network : remote « {name} » manquant côté client`)
			end
			remotes[name] = remote
		end
	end
	initialized = true
end

function Network.isInitialized(): boolean
	return initialized
end

--// API serveur

-- Abonne un gestionnaire à un remote client -> serveur. Retourne une fonction de désabonnement.
function Network.onServerEvent(name: string, handler: ServerHandler): () -> ()
	assert(RunService:IsServer(), "Network.onServerEvent n'est disponible que sur le serveur")
	local definition = getDefinition(name, "ToServer")
	local handlers = serverHandlers[name]
	if handlers == nil then
		handlers = {}
		serverHandlers[name] = handlers
	end
	table.insert(handlers, handler)
	listenServer(definition)
	return function()
		local list = serverHandlers[name]
		if list == nil then
			return
		end
		local index = table.find(list, handler)
		if index ~= nil then
			table.remove(list, index)
		end
	end
end

function Network.fireClient(name: string, player: Player, ...: any)
	local definition = getDefinition(name, "ToClient")
	local values = { ... }
	validateOutgoing(definition, values, select("#", ...))
	local buf, instances = encode(definition, values)
	getRemote(name):FireClient(player, buf, instances)
end

function Network.fireClients(name: string, players: { Player }, ...: any)
	local definition = getDefinition(name, "ToClient")
	local values = { ... }
	validateOutgoing(definition, values, select("#", ...))
	local buf, instances = encode(definition, values)
	local remote = getRemote(name)
	for _, player in players do
		if player.Parent == Players then
			remote:FireClient(player, buf, instances)
		end
	end
end

function Network.fireAllClients(name: string, ...: any)
	local definition = getDefinition(name, "ToClient")
	local values = { ... }
	validateOutgoing(definition, values, select("#", ...))
	local buf, instances = encode(definition, values)
	getRemote(name):FireAllClients(buf, instances)
end

--// API client

function Network.onClientEvent(name: string, handler: ClientHandler): () -> ()
	assert(RunService:IsClient(), "Network.onClientEvent n'est disponible que sur le client")
	local definition = getDefinition(name, "ToClient")
	local handlers = clientHandlers[name]
	if handlers == nil then
		handlers = {}
		clientHandlers[name] = handlers
	end
	table.insert(handlers, handler)
	listenClient(definition)
	return function()
		local list = clientHandlers[name]
		if list == nil then
			return
		end
		local index = table.find(list, handler)
		if index ~= nil then
			table.remove(list, index)
		end
	end
end

function Network.fireServer(name: string, ...: any)
	local definition = getDefinition(name, "ToServer")
	local values = { ... }
	validateOutgoing(definition, values, select("#", ...))
	local buf, instances = encode(definition, values)
	getRemote(name):FireServer(buf, instances)
end

--// Utilitaires exposés pour les tests

function Network.encodeForTest(name: string, ...: any): (buffer, { Instance })
	local definition = definitions[name]
	assert(definition ~= nil, "Network : remote inconnu " .. name)
	local values = { ... }
	validateOutgoing(definition, values, select("#", ...))
	return encode(definition, values)
end

function Network.decodeForTest(name: string, payload: unknown, instances: unknown): { any }?
	local definition = definitions[name]
	assert(definition ~= nil, "Network : remote inconnu " .. name)
	return decode(definition, payload, instances, MAX_STRING_TO_CLIENT)
end

return table.freeze(Network)
