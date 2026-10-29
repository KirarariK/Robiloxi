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

local LIGHT_PROPS = { "Ambient", "OutdoorAmbient", "ClockTime", "FogColor", "FogEnd" }

local function applyArenaLighting(arenaId: string?)
	local def = arenaId and ArenaData.get(arenaId)
	if not def then
		return
	end
	if not savedLighting then
		local saved: { [string]: any } = {}
		for _, k in LIGHT_PROPS do
			saved[k] = (Lighting :: any)[k]
		end
		savedLighting = saved
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
	local saved = savedLighting
	if not saved then
		return
	end
	savedLighting = nil
	Lighting.ClockTime = saved.ClockTime
	Kit.tween(Lighting, 1.2, {
		Ambient = saved.Ambient,
		OutdoorAmbient = saved.OutdoorAmbient,
		FogColor = saved.FogColor,
		FogEnd = saved.FogEnd,
	}, Enum.EasingStyle.Sine)
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
			applyArenaLighting(view.ArenaId)
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
