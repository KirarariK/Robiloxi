--!strict
--[[
	Résout / crée les RemoteEvents sous ReplicatedStorage.BladeConcord.Remotes.Combat
	Création côté serveur uniquement ; le client WaitForChild.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"AttackIntent",
	"GuardIntent",
	"CombatState",
	"HitResolved",
	"RoundEnded",
}

export type CombatRemotes = {
	AttackIntent: RemoteEvent,
	GuardIntent: RemoteEvent,
	CombatState: RemoteEvent,
	HitResolved: RemoteEvent,
	RoundEnded: RemoteEvent,
}

local function getBladeRoot(): Folder
	local root = ReplicatedStorage:FindFirstChild("BladeConcord")
	if not root then
		if RunService:IsServer() then
			root = Instance.new("Folder")
			root.Name = "BladeConcord"
			root.Parent = ReplicatedStorage
		else
			root = ReplicatedStorage:WaitForChild("BladeConcord")
		end
	end
	return root :: Folder
end

local function getCombatFolder(): Folder
	local blade = getBladeRoot()
	local remotes = blade:FindFirstChild("Remotes")
	if not remotes then
		if RunService:IsServer() then
			remotes = Instance.new("Folder")
			remotes.Name = "Remotes"
			remotes.Parent = blade
		else
			remotes = blade:WaitForChild("Remotes")
		end
	end
	local combat = remotes:FindFirstChild("Combat")
	if not combat then
		if RunService:IsServer() then
			combat = Instance.new("Folder")
			combat.Name = "Combat"
			combat.Parent = remotes
		else
			combat = remotes:WaitForChild("Combat")
		end
	end
	return combat :: Folder
end

local function ensureRemote(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if RunService:IsClient() then
		return folder:WaitForChild(name) :: RemoteEvent
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {}

function Remotes.get(): CombatRemotes
	local folder = getCombatFolder()
	local map: any = {}
	for _, name in REMOTE_NAMES do
		map[name] = ensureRemote(folder, name)
	end
	return map :: CombatRemotes
end

Remotes.Names = REMOTE_NAMES

return Remotes
