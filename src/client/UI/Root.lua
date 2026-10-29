--!strict
-- ScreenGuis d'Ether Blades (une par couche) et mise à l'échelle responsive (UIScale selon la fenêtre).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Root = {}

local REF = Vector2.new(1280, 760)
local guis: { [string]: ScreenGui } = {}
local scales: { UIScale } = {}

local ORDER = {
	Hud = 5, -- HUD de duel, barre du Hub, file d'attente
	Menu = 10, -- menu principal
	Wheel = 15, -- roue d'emotes
	Overlay = 20, -- fin de match, révélation de relance, défis
	Toast = 30,
	Loading = 50,
}

local function playerGui(): PlayerGui
	local lp = Players.LocalPlayer
	return lp:WaitForChild("PlayerGui") :: PlayerGui
end

-- Facteur d'échelle courant (0.55 sur petit téléphone → 1.25 sur grand écran).
function Root.factor(): number
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else REF
	return math.clamp(math.min(vp.X / REF.X, vp.Y / REF.Y), 0.55, 1.25)
end

function Root.isSmall(): boolean
	local cam = Workspace.CurrentCamera
	return cam ~= nil and math.min(cam.ViewportSize.X, cam.ViewportSize.Y) < 500
end

local function apply()
	local f = Root.factor()
	for i = #scales, 1, -1 do
		local s = scales[i]
		if s.Parent then
			s.Scale = f
		else
			table.remove(scales, i) -- UIScale détruit avec son conteneur
		end
	end
end

function Root.gui(layer: string): ScreenGui
	local g = guis[layer]
	if g and g.Parent then
		return g
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "EtherBlades_" .. layer
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = (ORDER :: any)[layer] or 1
	sg.Parent = playerGui()
	guis[layer] = sg
	return sg
end

-- Ajoute un UIScale synchronisé avec la taille d'écran à un conteneur (taille en pixels de référence 1280×760).
function Root.scale(obj: GuiObject): UIScale
	local s = Instance.new("UIScale")
	s.Scale = Root.factor()
	s.Parent = obj
	table.insert(scales, s)
	return s
end

do
	local function hook()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		end
		apply()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	hook()
end

return Root
