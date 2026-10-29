--!strict
-- Déclaration centrale des remotes. Le serveur les crée, le client les attend.
-- Un seul endroit pour les noms : aucune chaîne magique ailleurs dans le code.
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Net = {}

-- Les remotes sont déclarées par domaine dans NetDefs/*.lua (un fichier par équipe : Core, Combat, Match,
-- Progression, Security…). Chaque module renvoie { ClientEvents, ServerEvents, Functions }.
-- Net fusionne tout et refuse les doublons : chaque remote déclarée doit avoir un handler serveur.
local clientEvents: { string } = {}
local serverEvents: { string } = {}
local functions: { string } = {}
do
	local seen: { [string]: string } = {}
	local defs = script.Parent:WaitForChild("NetDefs")
	local mods = defs:GetChildren()
	table.sort(mods, function(a, b)
		return a.Name < b.Name
	end)
	for _, m in mods do
		if m:IsA("ModuleScript") then
			local d = require(m) :: any
			for listName, target in { ClientEvents = clientEvents, ServerEvents = serverEvents, Functions = functions } do
				for _, n in (d[listName] or {}) :: { string } do
					assert(seen[n] == nil, string.format("Remote %s déclarée deux fois (%s et %s)", n, tostring(seen[n]), m.Name))
					seen[n] = m.Name
					table.insert(target, n)
				end
			end
		end
	end
end

-- Client → Serveur (RemoteEvent)
Net.ClientEvents = table.freeze(clientEvents)
-- Serveur → Client (RemoteEvent)
Net.ServerEvents = table.freeze(serverEvents)
-- Requêtes avec réponse (RemoteFunction)
Net.Functions = table.freeze(functions)

local function getRoot(): Instance
	return script.Parent
end

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	local root = getRoot()
	if RunService:IsServer() then
		local f = root:FindFirstChild(FOLDER_NAME)
		if not f then
			f = Instance.new("Folder")
			f.Name = FOLDER_NAME
			f.Parent = root
		end
		folder = f :: Folder
	else
		folder = root:WaitForChild(FOLDER_NAME) :: Folder
	end
	return folder :: Folder
end

local function contains(list: { string }, name: string): boolean
	return table.find(list, name) ~= nil
end

-- Crée toutes les remotes (serveur uniquement, appelé une fois au démarrage).
function Net.init()
	assert(RunService:IsServer(), "Net.init est réservé au serveur")
	local f = getFolder()
	local function make(className: string, name: string)
		if not f:FindFirstChild(name) then
			local r = Instance.new(className)
			r.Name = name
			r.Parent = f
		end
	end
	for _, n in Net.ClientEvents do
		make("RemoteEvent", n)
	end
	for _, n in Net.ServerEvents do
		make("RemoteEvent", n)
		-- récepteur vide : sans handler, Roblox mettrait en file les envois forgés par un client (mémoire)
		(f:FindFirstChild(n) :: RemoteEvent).OnServerEvent:Connect(function() end)
	end
	for _, n in Net.Functions do
		make("RemoteFunction", n)
	end
end

function Net.event(name: string): RemoteEvent
	assert(contains(Net.ClientEvents, name) or contains(Net.ServerEvents, name), "RemoteEvent inconnu : " .. name)
	local f = getFolder()
	local r = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(r and r:IsA("RemoteEvent"), "RemoteEvent manquant : " .. name)
	return r
end

function Net.func(name: string): RemoteFunction
	assert(contains(Net.Functions, name), "RemoteFunction inconnue : " .. name)
	local f = getFolder()
	local r = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(r and r:IsA("RemoteFunction"), "RemoteFunction manquante : " .. name)
	return r
end

return Net
