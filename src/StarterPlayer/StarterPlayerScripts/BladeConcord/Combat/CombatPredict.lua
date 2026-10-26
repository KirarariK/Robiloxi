--!strict
--[[
	Prediction visuelle : lit CombatState.actionId et applique feedback local (couleur lame / print stub).
	Aucun crédit de dégâts local.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CombatPredict = {}

local lastAction: { [number]: string } = {}

local ACTION_COLOR = {
	Idle = Color3.fromRGB(120, 200, 255),
	Guard = Color3.fromRGB(80, 160, 255),
	Startup = Color3.fromRGB(255, 220, 100),
	Active = Color3.fromRGB(255, 80, 80),
	Recovery = Color3.fromRGB(180, 180, 180),
	Stagger = Color3.fromRGB(255, 140, 40),
	RiposteLock = Color3.fromRGB(200, 100, 255),
	Dead = Color3.fromRGB(40, 40, 40),
}

local function findBlade(userId: number): BasePart?
	local player = Players:GetPlayerByUserId(userId)
	if not player or not player.Character then
		return nil
	end
	for _, inst in CollectionService:GetTagged(CombatConfig.Tags.SaberBlade) do
		if inst:IsDescendantOf(player.Character) and inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

function CombatPredict.start()
	local remotes = Remotes.get()

	remotes.CombatState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.fighters) ~= "table" then
			return
		end
		for _, snap in payload.fighters do
			local actionId = snap.actionId
			local userId = snap.userId
			if lastAction[userId] ~= actionId then
				lastAction[userId] = actionId
				local blade = findBlade(userId)
				if blade then
					blade.Color = ACTION_COLOR[actionId] or ACTION_COLOR.Idle
				end
			end
		end
	end)

	remotes.HitResolved.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		-- VFX stub : trail flash via couleur temporaire déjà gérée ; log debug local
		if payload.result == "Perfect" then
			-- hook HUD via Bindable éventuel ; CombatHud écoute aussi HitResolved
		end
	end)
end

return CombatPredict
