--!strict
-- Appels RemoteFunction protégés côté client : affiche l'erreur serveur en toast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("EtherBlades"):WaitForChild("Net"))
local Toast = require(script.Parent.Toast)

local Remote = {}

-- Retourne (ok, data). `silent` évite le toast d'erreur.
function Remote.call(name: string, silent: boolean?, ...: any): (boolean, any)
	local args = table.pack(...)
	local ok, res = pcall(function()
		return Net.func(name):InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok or type(res) ~= "table" then
		if not silent then
			Toast.show("Le serveur ne répond pas, réessaie.", "Error")
		end
		return false, nil
	end
	if not res.Ok then
		if not silent and type(res.Err) == "string" then
			Toast.show(res.Err, "Error")
		end
		return false, res.Err
	end
	return true, res.Data
end

function Remote.fire(name: string, ...: any)
	Net.event(name):FireServer(...)
end

return Remote
