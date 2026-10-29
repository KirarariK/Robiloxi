--!strict
-- Point d'entrée serveur d'Ether Blades.
-- 1) crée les remotes ; 2) charge chaque ModuleScript de Services ; 3) appelle `init()` puis `start()`
-- dans l'ordre de `Priority` (plus petit d'abord, 100 par défaut). Ajouter un service = ajouter un module.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)

Net.init()

type Service = { Priority: number?, init: (() -> ())?, start: (() -> ())? }

local loaded: { { Name: string, Mod: Service } } = {}
for _, m in script.Parent:WaitForChild("Services"):GetChildren() do
	if m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if not ok then
			warn(string.format("[EtherBlades] échec du chargement du service %s : %s", m.Name, tostring(mod)))
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

for _, s in loaded do
	local init = s.Mod.init
	if init then
		local ok, err = pcall(init)
		if not ok then
			warn(string.format("[EtherBlades] %s.init : %s", s.Name, tostring(err)))
		end
	end
end
for _, s in loaded do
	local start = s.Mod.start
	if start then
		task.spawn(function()
			local ok, err = pcall(start)
			if not ok then
				warn(string.format("[EtherBlades] %s.start : %s", s.Name, tostring(err)))
			end
		end)
	end
end

-- Toute remote client → serveur déclarée doit avoir un handler (sinon les envois s'accumulent en file).
task.delay(5, function()
	local Guard = require(script.Parent.Services.Guard) :: any
	local missing = Guard.missingHandlers()
	if #missing > 0 then
		warn("[EtherBlades] remotes sans handler : " .. table.concat(missing, ", "))
	end
end)

print(string.format("[EtherBlades] serveur prêt (%d services)", #loaded))
