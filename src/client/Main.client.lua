--!strict
-- Point d'entrée client : récupère le profil puis démarre chaque contrôleur de Controllers
-- (`init()` puis `start()`, ordre de `Priority`, 100 par défaut). Ajouter un contrôleur = ajouter un module.
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
	if not ClientState.getProfile() then
		warn("[EtherBlades] profil introuvable après 30 s")
	end
end)

type Controller = { Priority: number?, init: (() -> ())?, start: (() -> ())? }

local loaded: { { Name: string, Mod: Controller } } = {}
local controllersFolder = script.Parent:FindFirstChild("Controllers")
for _, m in (if controllersFolder then controllersFolder:GetChildren() else {}) do
	if m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if not ok then
			warn(string.format("[EtherBlades] échec du chargement du contrôleur %s : %s", m.Name, tostring(mod)))
		elseif type(mod) == "table" then
			table.insert(loaded, { Name = m.Name, Mod = mod :: any })
		end
	end
end
table.sort(loaded, function(a, b)
	local pa, pb = a.Mod.Priority or 100, b.Mod.Priority or 100
	if pa ~= pb then
		return pa < pb
	end
	return a.Name < b.Name
end)
for _, c in loaded do
	local init = c.Mod.init
	if init then
		local ok, err = pcall(init)
		if not ok then
			warn(string.format("[EtherBlades] %s.init : %s", c.Name, tostring(err)))
		end
	end
end
for _, c in loaded do
	local start = c.Mod.start
	if start then
		task.spawn(function()
			local ok, err = pcall(start)
			if not ok then
				warn(string.format("[EtherBlades] %s.start : %s", c.Name, tostring(err)))
			end
		end)
	end
end

print(string.format("[EtherBlades] client prêt (%d contrôleurs)", #loaded))
