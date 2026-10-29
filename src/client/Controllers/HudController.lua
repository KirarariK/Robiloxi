--!strict
-- HUD : duel (n'apparaît qu'en duel), écran de fin de match, indicateur de file, ambiance lumineuse de l'arène.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local ArenaData = require(Shared.Config.ArenaData)

local UI = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UI.Kit)
local State = require(UI.State)
local DuelHud = require(UI.DuelHud)
local MatchEnd = require(UI.MatchEnd)
local QueueIndicator = require(UI.QueueIndicator)

local HudController = {}
HudController.Priority = 45

local hud: DuelHud.DuelHud? = nil
local pendingResult: { [string]: any }? = nil
local savedLighting: { [string]: any }? = nil

local LIGHT_PROPS = {
	"Ambient",
	"OutdoorAmbient",
	"ClockTime",
	"FogColor",
	"FogEnd",
	"Brightness",
	"ExposureCompensation",
	"GeographicLatitude",
}
local EFFECT_CLASSES = { "Atmosphere", "Sky", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect" }

-- effets du Hub retirés le temps du duel, et effets d'arène ajoutés (clones locaux, invisibles pour les autres)
local parkedEffects: { Instance } = {}
local arenaEffects: { Instance } = {}

-- Arène du match en cours : clone dans Workspace.EB_Arenas nommé « <ArenaId>_<id> », la plus proche du joueur.
local function findArena(arenaId: string): Model?
	local folder = workspace:WaitForChild("EB_Arenas", 5)
	if not folder then
		return nil
	end
	local char = game:GetService("Players").LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local best: Model? = nil
	local bestDist = math.huge
	for _ = 1, 20 do
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and string.sub(m.Name, 1, #arenaId + 1) == arenaId .. "_" then
				local d = if root and root:IsA("BasePart") then (m:GetPivot().Position - root.Position).Magnitude else 0
				if d < bestDist then
					best, bestDist = m, d
				end
			end
		end
		if best then
			return best
		end
		task.wait(0.25)
	end
	return nil
end

local function saveLighting()
	if savedLighting then
		return
	end
	local saved: { [string]: any } = {}
	for _, k in LIGHT_PROPS do
		saved[k] = (Lighting :: any)[k]
	end
	savedLighting = saved
end

local function applyArenaLighting(arenaId: string?)
	if not arenaId then
		return
	end
	saveLighting()
	local arena = findArena(arenaId)
	local folder = arena and arena:FindFirstChild("Lighting")
	if folder then
		-- réglages fournis par l'arène elle-même (attributs + effets à cloner)
		local goals: { [string]: any } = {}
		for _, k in LIGHT_PROPS do
			local v = folder:GetAttribute(k)
			if v ~= nil then
				if k == "ClockTime" or k == "GeographicLatitude" then
					(Lighting :: any)[k] = v
				else
					goals[k] = v
				end
			end
		end
		Kit.tween(Lighting, 1.2, goals, Enum.EasingStyle.Sine)
		for _, child in folder:GetChildren() do
			if table.find(EFFECT_CLASSES, child.ClassName) then
				for _, existing in Lighting:GetChildren() do
					if existing.ClassName == child.ClassName and not table.find(arenaEffects, existing) then
						existing.Parent = nil
						table.insert(parkedEffects, existing)
					end
				end
				local c = child:Clone()
				c.Parent = Lighting
				table.insert(arenaEffects, c)
			end
		end
		return
	end
	local def = ArenaData.get(arenaId)
	if not def then
		return
	end
	Lighting.ClockTime = def.ClockTime
	Kit.tween(Lighting, 1.2, {
		Ambient = def.Ambient,
		OutdoorAmbient = def.OutdoorAmbient,
		FogColor = def.FogColor,
		FogEnd = def.FogEnd,
	}, Enum.EasingStyle.Sine)
end

local function restoreLighting()
	for _, e in arenaEffects do
		e:Destroy()
	end
	table.clear(arenaEffects)
	for _, e in parkedEffects do
		e.Parent = Lighting
	end
	table.clear(parkedEffects)
	local saved = savedLighting
	if not saved then
		return
	end
	savedLighting = nil
	local goals: { [string]: any } = {}
	for _, k in LIGHT_PROPS do
		if k == "ClockTime" or k == "GeographicLatitude" then
			(Lighting :: any)[k] = saved[k]
		else
			goals[k] = saved[k]
		end
	end
	Kit.tween(Lighting, 1.2, goals, Enum.EasingStyle.Sine)
end

local function flushResult()
	local r = pendingResult
	if r then
		pendingResult = nil
		MatchEnd.show(r)
	end
end

local function onMatch(view: State.MatchView, prev: State.MatchView?)
	if view.Active then
		if not hud then
			hud = DuelHud.new()
			MatchEnd.close()
		end
		local h = hud :: DuelHud.DuelHud
		h.update(view, prev)
		if not prev or not prev.Active or prev.ArenaId ~= view.ArenaId then
			task.spawn(applyArenaLighting, view.ArenaId)
		end
		if view.Phase == "Victory" and pendingResult then
			task.delay(1.2, flushResult)
		end
	else
		if hud then
			hud.destroy()
			hud = nil
		end
		restoreLighting()
		flushResult()
	end
	QueueIndicator.set(State.queue, view.Active)
end

function HudController.init()
	State.init()
	State.MatchChanged:Connect(onMatch)
	State.QueueChanged:Connect(function(q: { [string]: any })
		QueueIndicator.set(q, State.inDuel())
	end)
	State.MatchResult:Connect(function(r: { [string]: any })
		pendingResult = r
		if State.match.Phase == "Victory" or not State.inDuel() then
			task.delay(1.2, flushResult)
		else
			-- garde-fou : l'écran apparaît même si la phase Victoire n'arrive pas
			task.delay(8, flushResult)
		end
	end)
end

function HudController.start()
	if State.match.Active then
		onMatch(State.match, nil)
	end
end

return HudController
