--!strict
-- Déclaration centrale des remotes. Le serveur les crée, le client les attend.
-- Un seul endroit pour les noms : aucune chaîne magique ailleurs dans le code.
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Net = {}

-- Les listes grandissent avec les étapes : chaque remote déclarée ici a un handler serveur.

-- Client → Serveur (RemoteEvent)
Net.ClientEvents = table.freeze({} :: { string })

-- Serveur → Client (RemoteEvent)
Net.ServerEvents = table.freeze({
	"ProfileUpdated", -- vue du profil (après chargement et à chaque changement)
	"Notify", -- message toast { Text: string, Kind: string }
})

-- Requêtes avec réponse (RemoteFunction, toujours validées côté serveur)
Net.Functions = table.freeze({
	"GetProfile",
})

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
