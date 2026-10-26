--!strict
--[[
	Client — glow pulse léger sur strips tagués BC_NeonStrip (Attribute BC_GlowPulse).
	Pas de PointLight : Tween Transparency uniquement (perf mobile / Future lighting).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NeonFx = require(
	ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Visual"):WaitForChild("NeonFx")
)

local cancels: { [BasePart]: () -> () } = {}
local MAX_PULSE = 16 -- plafond pulses simultanés

local function stopPulse(part: BasePart)
	local cancel = cancels[part]
	if cancel then
		cancel()
		cancels[part] = nil
	end
end

local function tryPulse(part: BasePart)
	if cancels[part] then
		return
	end
	local count = 0
	for _ in cancels do
		count += 1
	end
	if count >= MAX_PULSE then
		return
	end
	if part:GetAttribute(NeonFx.PULSE_ATTR) ~= true then
		return
	end
	cancels[part] = NeonFx.pulseGlow(part, {
		amp = 0.1,
		period = 2.6,
		colorAmp = true,
	})
	part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			stopPulse(part)
		end
	end)
end

local function scan()
	for _, inst in CollectionService:GetTagged(NeonFx.TAG) do
		if inst:IsA("BasePart") then
			tryPulse(inst)
		end
	end
end

scan()
CollectionService:GetInstanceAddedSignal(NeonFx.TAG):Connect(function(inst)
	if inst:IsA("BasePart") then
		task.defer(tryPulse, inst)
	end
end)
CollectionService:GetInstanceRemovedSignal(NeonFx.TAG):Connect(function(inst)
	if inst:IsA("BasePart") then
		stopPulse(inst)
	end
end)

print("[BladeConcord] LobbyNeon pulse ready (BC_NeonStrip)")
