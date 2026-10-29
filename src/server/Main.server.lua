--!strict
-- Point d'entrée serveur d'Ether Blades : crée les remotes, démarre les services, branche les handlers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)

local Services = script.Parent:WaitForChild("Services")
local Guard = require(Services.Guard)
local DataService = require(Services.DataService)

Net.init()
DataService.init()

Guard.func("GetProfile", {}, 2, 6, function(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return { Ok = false, Err = "Chargement du profil…" }
	end
	return { Ok = true, Data = DataService.publicView(profile) }
end)

print(string.format("[EtherBlades] serveur prêt (données : %s)", if DataService.isMemoryMode() then "mémoire" else "DataStore"))
