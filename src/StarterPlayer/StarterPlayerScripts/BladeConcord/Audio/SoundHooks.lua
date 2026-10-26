--!strict
--[[
	Audio combat jouable — IDs Creator Store / library Roblox (pas Disney).
	Documentés dans docs/visual-polish-notes.md Pass 2 / Pass 3.

	IDs (rbxassetid) :
	  Swing      12222216     swordslash.wav (classic Roblox)
	  Clash      8917041751   Metal Hit Sound
	  Hit        1469323642   Shield-Hit
	  Perfect    6895079853   UI Click (pitch up)
	  GuardBreak 9120828958   Wood Crash 1 (PSE library)
	  Dodge      9119741050   Swoosh Pack High End
	  Dash       9114323612   Energy Cloud Whooshing By Very Fast 1
	  FocusPush  9114324017   Energy Cloud Whooshing By Very Fast 2
	  Ko         9126102562   Time Warp Big Explosion (dramatic sting)
	  Ui         6895079853   UI Click
	  Hum        9114323612   Energy whoosh soft loop
	  Ambient*   loops légers par map (Pass 3) — swap Studio si privé
]]

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SoundHooks = {}

-- Catalogue public documenté (swap en Studio si un ID devient privé)
SoundHooks.AssetIds = {
	Swing = "rbxassetid://12222216",
	Clash = "rbxassetid://8917041751",
	Hit = "rbxassetid://1469323642",
	Perfect = "rbxassetid://6895079853",
	GuardBreak = "rbxassetid://9120828958",
	Dodge = "rbxassetid://9119741050",
	Dash = "rbxassetid://9114323612",
	FocusPush = "rbxassetid://9114324017",
	Ko = "rbxassetid://9126102562",
	Ui = "rbxassetid://6895079853",
	-- Amp-style electric hum ; si mute en playtest → remplacer via SoundHooks.AssetIds.Hum
	Hum = "rbxassetid://9114323612",
	-- Ambiance arènes (library publics — volume bas, loop)
	AmbientObsidian = "rbxassetid://9113839759", -- fire / ember crackle style
	AmbientSanctum = "rbxassetid://9114221256", -- soft wind
	AmbientEclipse = "rbxassetid://9116395309", -- low drone / buzz
	AmbientMirage = "rbxassetid://9114221571", -- water / breeze adjacent
}

local AMBIENT_BY_ARENA: { [string]: string } = {
	ObsidianPit = "AmbientObsidian",
	SanctumAstres = "AmbientSanctum",
	TroneEclipse = "AmbientEclipse",
	QuaiMirage = "AmbientMirage",
}

local group: SoundGroup
local ambientGroup: SoundGroup
local cache: { [string]: Sound } = {}
local humSound: Sound? = nil
local ambientSound: Sound? = nil
local currentAmbientKey: string? = nil

local DEFS: { [string]: { vol: number, speed: number, loop: boolean? } } = {
	Hit = { vol = 0.45, speed = 1.05 },
	Clash = { vol = 0.55, speed = 0.95 },
	Perfect = { vol = 0.55, speed = 1.35 },
	GuardBreak = { vol = 0.5, speed = 0.85 },
	Dodge = { vol = 0.32, speed = 1.25 },
	Dash = { vol = 0.38, speed = 1.05 },
	FocusPush = { vol = 0.5, speed = 0.88 },
	Swing = { vol = 0.28, speed = 1.05 },
	Ko = { vol = 0.6, speed = 0.78 },
	Ui = { vol = 0.22, speed = 1 },
	Hum = { vol = 0.08, speed = 0.55, loop = true },
	AmbientObsidian = { vol = 0.12, speed = 0.9, loop = true },
	AmbientSanctum = { vol = 0.1, speed = 0.85, loop = true },
	AmbientEclipse = { vol = 0.11, speed = 0.7, loop = true },
	AmbientMirage = { vol = 0.1, speed = 0.95, loop = true },
}

function SoundHooks.setArenaAmbient(arenaId: string?)
	local key = if arenaId then AMBIENT_BY_ARENA[arenaId] else nil
	if key == currentAmbientKey then
		return
	end
	if ambientSound and ambientSound.IsPlaying then
		ambientSound:Stop()
	end
	currentAmbientKey = key
	ambientSound = if key then cache[key] else nil
	if ambientSound and ambientSound.SoundId ~= "" then
		ambientSound:Play()
	end
end

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

	local ambExisting = SoundService:FindFirstChild("BC_Ambient")
	if ambExisting and ambExisting:IsA("SoundGroup") then
		ambientGroup = ambExisting
	else
		ambientGroup = Instance.new("SoundGroup")
		ambientGroup.Name = "BC_Ambient"
		ambientGroup.Volume = 0.55
		ambientGroup.Parent = SoundService
	end

	local toPreload: { Instance } = {}
	for name, def in DEFS do
		local s = Instance.new("Sound")
		s.Name = "BC_" .. name
		s.SoundId = SoundHooks.AssetIds[name] or ""
		s.Volume = def.vol
		s.PlaybackSpeed = def.speed
		s.Looped = def.loop == true
		local isAmbient = string.sub(name, 1, 7) == "Ambient"
		s.SoundGroup = if isAmbient then ambientGroup else group
		s.RollOffMaxDistance = 80
		s.Parent = SoundService
		cache[name] = s
		table.insert(toPreload, s)
		if name == "Hum" then
			humSound = s
		end
	end

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(toPreload)
		end)
	end)

	local marker = Instance.new("StringValue")
	marker.Name = "BC_AudioTheme"
	marker.Value = Theme.Brand .. " — Pass3 audio + ambient loops"
	marker.Parent = group

	-- Switch ambient on MatchState arenaId
	task.defer(function()
		local remotes = Remotes.get()
		remotes.MatchState.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and typeof(payload.arenaId) == "string" then
				SoundHooks.setArenaAmbient(payload.arenaId)
			end
		end)
	end)
end

function SoundHooks.play(name: string)
	local s = cache[name]
	if not s then
		return
	end
	local def = DEFS[name]
	s.PlaybackSpeed = (def and def.speed or 1) * (0.94 + math.random() * 0.12)
	if s.SoundId ~= "" then
		if s.IsPlaying and not s.Looped then
			s.TimePosition = 0
		end
		s:Play()
	end
end

function SoundHooks.startHum()
	if humSound and humSound.SoundId ~= "" and not humSound.IsPlaying then
		humSound:Play()
	end
end

function SoundHooks.stopHum()
	if humSound and humSound.IsPlaying then
		humSound:Stop()
	end
end

return SoundHooks
