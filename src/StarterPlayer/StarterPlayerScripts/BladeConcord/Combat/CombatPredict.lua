--!strict
--[[
	Prediction légère — trails / couleur délégués à SaberPose + CombatFx.
	Swing SFX : CombatAnimator (Active) ; ce module garde le hook FxEvent "Swing"
	pour un éventuel fire serveur spatial / multi.
]]

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("BladeConcord"):WaitForChild("Shared"):WaitForChild("Remotes"))
local SoundHooks = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("SoundHooks"))

local CombatPredict = {}

function CombatPredict.start()
	local remotes = Remotes.get()

	remotes.FxEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "Swing" then
			SoundHooks.play("Swing")
		elseif payload.kind == "Feint" then
			SoundHooks.play("Feint")
		end
	end)
end

return CombatPredict
