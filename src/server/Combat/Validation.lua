--!strict
-- Adaptateur vers HitValidation / AntiExploit (équipe Sécurité), résolus à l'init via FindFirstChild.
-- S'ils sont absents, une vérification locale équivalente (distance + angle) prend le relais : dégradation sûre.
local State = require(script.Parent.State)

type Fighter = State.Fighter

type HitValidationApi = {
	canHit: (Player, BasePart, number, number, number?) -> boolean,
	recordNpc: (Model) -> (),
	clearHistory: ((Model) -> ())?,
}
type AntiExploitApi = {
	allowMovement: (Player, number) -> (),
	teleport: ((Player, CFrame) -> boolean)?,
}

local LOCAL_TOLERANCE = 2.5 -- studs (corps visé + garde de la lame)
local LOCAL_ANGLE_TOLERANCE = 20 -- degrés de chaque côté

local Validation = {}

local hv: HitValidationApi? = nil
local ae: AntiExploitApi? = nil
local warned: { [string]: boolean } = {}

local function warnOnce(key: string, msg: string)
	if not warned[key] then
		warned[key] = true
		warn("[EtherBlades][Combat] " .. msg)
	end
end

local function load(folder: Instance, name: string): any?
	local m = folder:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, res = pcall(require, m)
		if ok and type(res) == "table" then
			return res
		end
		warnOnce(name, name .. " présent mais impossible à charger : " .. tostring(res))
		return nil
	end
	warnOnce(name, name .. " absent : vérification locale utilisée.")
	return nil
end

function Validation.init(servicesFolder: Instance)
	local h = load(servicesFolder, "HitValidation")
	if h and type(h.canHit) == "function" then
		hv = h :: HitValidationApi
	end
	local a = load(servicesFolder, "AntiExploit")
	if a and type(a.allowMovement) == "function" then
		ae = a :: AntiExploitApi
	end
end

local function localCheck(attacker: Fighter, target: Fighter, reach: number, arcDeg: number): boolean
	local delta = target.Root.Position - attacker.Root.Position
	if delta.Magnitude > reach + LOCAL_TOLERANCE then
		return false
	end
	if arcDeg >= 360 then
		return true
	end
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude < 2.5 then
		return true
	end
	local look = attacker.Root.CFrame.LookVector
	local lf = Vector3.new(look.X, 0, look.Z)
	if lf.Magnitude < 1e-3 then
		return true
	end
	local half = math.min(180, arcDeg * 0.5 + LOCAL_ANGLE_TOLERANCE)
	return lf.Unit:Dot(flat.Unit) >= math.cos(math.rad(half))
end

-- `reach` = portée brute de l'arme (la marge est gérée par HitValidation ou la tolérance locale).
function Validation.canHit(attacker: Fighter, target: Fighter, reach: number, arcDeg: number, clientTime: number?): boolean
	local p = attacker.Player
	local api = hv
	if p and api then
		local ok, res = pcall(api.canHit, p, target.Root, reach, arcDeg, clientTime)
		if ok then
			return res == true
		end
		warnOnce("canHit", "HitValidation.canHit a échoué : " .. tostring(res))
	end
	return localCheck(attacker, target, reach, arcDeg)
end

function Validation.recordNpc(model: Model)
	local api = hv
	if api and type(api.recordNpc) == "function" then
		local ok, err = pcall(api.recordNpc, model)
		if not ok then
			warnOnce("recordNpc", "HitValidation.recordNpc : " .. tostring(err))
		end
	end
end

function Validation.clearHistory(model: Model)
	local api = hv
	local fn = if api then api.clearHistory else nil
	if fn then
		pcall(fn, model)
	end
end

function Validation.allowMovement(player: Player?, seconds: number)
	local api = ae
	if player and api then
		local ok, err = pcall(api.allowMovement, player, seconds)
		if not ok then
			warnOnce("allowMovement", "AntiExploit.allowMovement : " .. tostring(err))
		end
	end
end

-- Toute téléportation serveur passe par AntiExploit.teleport ; repli : PivotTo.
function Validation.teleport(f: Fighter, cf: CFrame)
	local p = f.Player
	local api = ae
	local tp = if api then api.teleport else nil
	if p and tp then
		local ok, res = pcall(tp, p, cf)
		if ok and res == true then
			Validation.clearHistory(f.Model)
			return
		end
	end
	f.Model:PivotTo(cf)
	f.Root.AssemblyLinearVelocity = Vector3.zero
	Validation.clearHistory(f.Model)
end

return Validation
