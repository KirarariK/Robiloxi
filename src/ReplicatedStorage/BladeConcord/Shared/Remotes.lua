--!strict
--[[
	Résout / crée les RemoteEvents sous ReplicatedStorage.BladeConcord.Remotes.*
	Création côté serveur uniquement ; le client WaitForChild.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local COMBAT_REMOTE_NAMES = {
	"AttackIntent",
	"GuardIntent",
	"MobilityIntent",
	"FocusIntent",
	"CombatState",
	"HitResolved",
	"RoundEnded",
	"MatchState",
	"FxEvent",
}

local META_REMOTE_NAMES = {
	"MetaState",
	"ShopPurchase",
	"GachaPull",
	"EquipLoadout",
	"SelectFaction",
	"QueueMatch",
	"ClaimQuest",
}

export type CombatRemotes = {
	AttackIntent: RemoteEvent,
	GuardIntent: RemoteEvent,
	MobilityIntent: RemoteEvent,
	FocusIntent: RemoteEvent,
	CombatState: RemoteEvent,
	HitResolved: RemoteEvent,
	RoundEnded: RemoteEvent,
	MatchState: RemoteEvent,
	FxEvent: RemoteEvent,
}

export type MetaRemotes = {
	MetaState: RemoteEvent,
	ShopPurchase: RemoteEvent,
	GachaPull: RemoteEvent,
	EquipLoadout: RemoteEvent,
	SelectFaction: RemoteEvent,
	QueueMatch: RemoteEvent,
	ClaimQuest: RemoteEvent,
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

local function getFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if RunService:IsServer() then
		if existing then
			existing:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		return folder
	end
	return parent:WaitForChild(name) :: Folder
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

local function mapRemotes(folder: Folder, names: { string }): any
	local map: any = {}
	for _, name in names do
		map[name] = ensureRemote(folder, name)
	end
	return map
end

local Remotes = {}

function Remotes.get(): CombatRemotes
	local blade = getBladeRoot()
	local remotes = getFolder(blade, "Remotes")
	local combat = getFolder(remotes, "Combat")
	return mapRemotes(combat, COMBAT_REMOTE_NAMES) :: CombatRemotes
end

function Remotes.getMeta(): MetaRemotes
	local blade = getBladeRoot()
	local remotes = getFolder(blade, "Remotes")
	local meta = getFolder(remotes, "Meta")
	return mapRemotes(meta, META_REMOTE_NAMES) :: MetaRemotes
end

Remotes.CombatNames = COMBAT_REMOTE_NAMES
Remotes.MetaNames = META_REMOTE_NAMES

return Remotes
