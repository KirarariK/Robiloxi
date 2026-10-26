--!strict
--[[
	Hooks audio combat — SoundId stubs (vides) prêts pour assets Studio.
	Appels non bloquants ; volume/pitch varient pour le feeling.
]]

local SoundService = game:GetService("SoundService")
local Theme = require(game:GetService("ReplicatedStorage"):WaitForChild("BladeConcord"):WaitForChild("Shared"):WaitForChild("Theme"))

local SoundHooks = {}

local group: SoundGroup
local cache: { [string]: Sound } = {}

local DEFS: { [string]: { vol: number, speed: number } } = {
	Hit = { vol = 0.45, speed = 1.05 },
	Clash = { vol = 0.55, speed = 0.95 },
	Perfect = { vol = 0.6, speed = 1.15 },
	GuardBreak = { vol = 0.5, speed = 0.85 },
	Dodge = { vol = 0.3, speed = 1.2 },
	Dash = { vol = 0.35, speed = 1.1 },
	FocusPush = { vol = 0.5, speed = 0.9 },
	Swing = { vol = 0.25, speed = 1 },
	Ko = { vol = 0.55, speed = 0.8 },
	Ui = { vol = 0.2, speed = 1 },
}

function SoundHooks.start()
	local existing = SoundService:FindFirstChild("BC_Combat")
	if existing and existing:IsA("SoundGroup") then
		group = existing
	else
		group = Instance.new("SoundGroup")
		group.Name = "BC_Combat"
		group.Volume = 0.85
		group.Parent = SoundService
	end

	for name, def in DEFS do
		local s = Instance.new("Sound")
		s.Name = "BC_" .. name
		s.SoundId = "" -- stub : coller asset rbxassetid:// en Studio
		s.Volume = def.vol
		s.PlaybackSpeed = def.speed
		s.SoundGroup = group
		s.Parent = SoundService
		cache[name] = s
	end

	-- Marqueur thème (debug Studio)
	local marker = Instance.new("StringValue")
	marker.Name = "BC_AudioTheme"
	marker.Value = Theme.Brand .. " — stubs prêts"
	marker.Parent = group
end

function SoundHooks.play(name: string)
	local s = cache[name]
	if not s then
		return
	end
	-- Même sans SoundId, Play() est no-op sûr ; pitch jitter
	s.PlaybackSpeed = (DEFS[name] and DEFS[name].speed or 1) * (0.94 + math.random() * 0.12)
	if s.SoundId ~= "" then
		s:Play()
	end
end

return SoundHooks
