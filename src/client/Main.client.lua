--!strict
-- Point d'entrée client : récupère le profil et le garde à jour pour les contrôleurs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

Net.event("ProfileUpdated").OnClientEvent:Connect(function(view: any)
	if type(view) == "table" then
		ClientState.setProfile(view)
	end
end)

-- Le profil peut arriver avant ou après cet appel : on réessaie tant que le serveur charge.
task.spawn(function()
	for _ = 1, 30 do
		if ClientState.getProfile() then
			break
		end
		local ok, res = pcall(function()
			return Net.func("GetProfile"):InvokeServer()
		end)
		if ok and type(res) == "table" and res.Ok and type(res.Data) == "table" then
			ClientState.setProfile(res.Data)
			break
		end
		task.wait(1)
	end
	local p = ClientState.getProfile()
	if p then
		print(string.format("[EtherBlades] client prêt — Elo %d, Voie %s, lame %s", p.Elo, p.EquippedForm, p.EquippedColor))
	else
		warn("[EtherBlades] profil introuvable après 30 s")
	end
end)
