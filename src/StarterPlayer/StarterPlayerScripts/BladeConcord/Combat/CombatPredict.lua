--!strict
--[[
	Prediction légère — trails / couleur délégués à SaberPose + CombatFx.
	Conserve hooks HitResolved pour compat ; pas de crédit dégâts local.
]]

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("BladeConcord"):WaitForChild("Shared"):WaitForChild("Remotes"))
local SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))

local CombatPredict = {}

function CombatPredict.start()
	local remotes = Remotes.get()

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		-- Swing audio sur transition Startup locale
		for _, snap in payload.fighters do
			if snap.actionId == "Startup" or snap.actionId == "Active" then
				-- SoundHooks no-op sans asset — feeling hook
			end
		end
	end)

	remotes.FxEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "Swing" then
			SoundHooks.play("Swing")
		end
	end)
end

return CombatPredict
