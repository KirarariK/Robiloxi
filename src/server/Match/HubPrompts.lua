--!strict
-- Crée les ProximityPrompts du Hub (pods de file, autel de relance, établi, méditation).
-- Chaque prompt porte l'attribut `EB_Action` lu par le client (HubController) et/ou le serveur.
local Workspace = game:GetService("Workspace")

local HubPrompts = {}

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, msg: string)
	if not warned[key] then
		warned[key] = true
		warn("[EtherBlades] " .. msg)
	end
end

function HubPrompts.getHub(timeout: number?): Instance?
	local hub = Workspace:FindFirstChild("Hub") or Workspace:WaitForChild("Hub", timeout or 20)
	if not hub then
		warnOnce("hub", "Workspace.Hub introuvable : les prompts et panneaux du Hub ne sont pas créés (assets de l'équipe Modélisation).")
	end
	return hub
end

function HubPrompts.getPart(name: string, timeout: number?): BasePart?
	local hub = HubPrompts.getHub(timeout)
	if not hub then
		return nil
	end
	local inst = hub:FindFirstChild(name, true) or hub:WaitForChild(name, timeout or 10)
	if inst and inst:IsA("BasePart") then
		return inst
	end
	if inst and inst:IsA("Model") and inst.PrimaryPart then
		return inst.PrimaryPart
	end
	warnOnce(name, string.format("Workspace.Hub.%s introuvable (ou pas une Part) : fonction associée désactivée.", name))
	return nil
end

export type PromptOpts = {
	Action: string,
	ActionText: string,
	ObjectText: string,
	HoldDuration: number?,
	MaxDistance: number?,
	Key: Enum.KeyCode?,
}

function HubPrompts.attach(part: BasePart, opts: PromptOpts): ProximityPrompt
	local existing = part:FindFirstChild("EB_Prompt")
	if existing and existing:IsA("ProximityPrompt") then
		existing:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EB_Prompt"
	prompt.ActionText = opts.ActionText
	prompt.ObjectText = opts.ObjectText
	prompt.HoldDuration = opts.HoldDuration or 0
	prompt.MaxActivationDistance = opts.MaxDistance or 12
	prompt.KeyboardKeyCode = opts.Key or Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt:SetAttribute("EB_Action", opts.Action)
	prompt.Parent = part
	return prompt
end

-- Joueur suffisamment proche d'une Part (vérification serveur des actions déclenchées par prompt).
function HubPrompts.isNear(player: Player, part: BasePart, maxDist: number): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - part.Position).Magnitude <= maxDist
end

return HubPrompts
