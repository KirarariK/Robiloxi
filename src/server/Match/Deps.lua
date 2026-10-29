--!strict
-- Accès aux services des autres équipes (Combat, AntiExploit), résolus au moment de l'appel via FindFirstChild.
-- Si un module est absent, un avertissement clair est journalisé une seule fois et un repli sûr est utilisé.
local Deps = {}

local servicesFolder: Instance = script.Parent.Parent:WaitForChild("Services")
local cache: { [string]: any } = {}
local warned: { [string]: boolean } = {}

function Deps.get(name: string): any?
	local c = cache[name]
	if c ~= nil then
		return c
	end
	local mod = servicesFolder:FindFirstChild(name)
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and type(res) == "table" then
			cache[name] = res
			return res
		end
		if not warned[name] then
			warned[name] = true
			warn(string.format("[EtherBlades] %s présent mais impossible à charger : %s", name, tostring(res)))
		end
		return nil
	end
	if not warned[name] then
		warned[name] = true
		warn(string.format("[EtherBlades] Service %s absent (équipe partenaire) : repli utilisé.", name))
	end
	return nil
end

-- Autorise un déplacement légitime (téléport vers l'arène / retour au Hub) auprès de l'anti-triche.
function Deps.allowMovement(player: Player, seconds: number)
	local ae = Deps.get("AntiExploit")
	if ae and type(ae.allowMovement) == "function" then
		local ok, err = pcall(ae.allowMovement, player, seconds)
		if not ok then
			warn("[EtherBlades] AntiExploit.allowMovement : " .. tostring(err))
		end
	end
end

-- Téléportation serveur (arène, retour au Hub) : passe par AntiExploit.teleport pour recaler l'anti-triche.
function Deps.teleport(player: Player, target: CFrame): boolean
	local ae = Deps.get("AntiExploit")
	if ae and type(ae.teleport) == "function" then
		local ok, res = pcall(ae.teleport, player, target)
		if ok then
			return res == true
		end
		warn("[EtherBlades] AntiExploit.teleport : " .. tostring(res))
	end
	local char = player.Character
	if not char then
		return false
	end
	char:PivotTo(target)
	return true
end

return Deps
