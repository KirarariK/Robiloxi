--!strict
--[[
	Concord Hall — constantes de layout (studs), palette, budgets perf.
	Repère local : origine plaza = (0,0,0) ; −Z = nord (pads) ; Y = haut.
	Monde : LobbyConfig.Origin décale le hall loin des arènes de match (X≥0).

	Attributs / tags exposés au client (monde) :
	- Model ConcordLobby : ArtPass, DisplayName, BC_LobbyOrigin (Vector3)
	- Pads : Attribute BC_QueueMode = "Casual"|"Ranked", tag BC_QueuePad
	- Zones : Attribute BC_ZoneId (Plaza|Pads|Gallery|Leaderboard|Dawn|Dusk|Forms|Forge|Quests|Training|Diorama*)
	- SpawnLocation.Duration > 0 (ForceField)
	- SurfaceGui Leaderboard : Attribute BC_LeaderboardKind = "Elo"|"Faction"|"FactionTop"
	- ProximityPrompt : file Amical / Classé ; Forge / Formes / Quêtes (UI client)

	Son ambiance : SoundHooks.AssetIds.AmbientLobby (placeholder configurable).
]]

local LobbyConfig = {}

-- ArtPass 7 = densification maquette (colonnes/arches/sol/DoF off)
LobbyConfig.ArtPass = 7
LobbyConfig.Name = "ConcordLobby"
LobbyConfig.DisplayName = "Concord Hall"

-- Loin des arènes de match (Obsidian à X=0 … Quai à X=360, Z≈0)
LobbyConfig.Origin = Vector3.new(0, 0, 700)

LobbyConfig.Budget = {
	MaxParts = 6000,
	MaxLights = 20,
	MaxEmitters = 30,
	MaxSurfaceGuis = 6,
}

-- Palette « cathédrale de duel au crépuscule » (ui-lobby-direction §3.3)
LobbyConfig.Colors = {
	Ink900 = Color3.fromRGB(7, 11, 20),
	Ink800 = Color3.fromRGB(13, 20, 36),
	Ink700 = Color3.fromRGB(20, 29, 51),
	Ink600 = Color3.fromRGB(29, 42, 71),
	Marble = Color3.fromRGB(42, 50, 72),
	MarbleLite = Color3.fromRGB(78, 88, 118),
	MarblePolish = Color3.fromRGB(58, 66, 92),
	Gold = Color3.fromRGB(232, 196, 104),
	GoldLite = Color3.fromRGB(255, 233, 168),
	GoldDark = Color3.fromRGB(184, 137, 43),
	Focus = Color3.fromRGB(54, 224, 255),
	FocusDark = Color3.fromRGB(14, 143, 179),
	Arcane = Color3.fromRGB(155, 107, 255),
	Dawn = Color3.fromRGB(255, 154, 60),
	DawnDeep = Color3.fromRGB(59, 30, 10),
	Dusk = Color3.fromRGB(106, 76, 255),
	DuskDeep = Color3.fromRGB(21, 15, 59),
	Forge = Color3.fromRGB(255, 138, 61),
	Lava = Color3.fromRGB(255, 90, 30),
	Sanctum = Color3.fromRGB(210, 205, 195),
	Mirage = Color3.fromRGB(55, 140, 150),
	Steel = Color3.fromRGB(72, 88, 110),
	Bone = Color3.fromRGB(242, 245, 250),
	Muted = Color3.fromRGB(154, 167, 189),
}

-- Centres de zones (X, Z) locaux — spec §5.1
LobbyConfig.Zones = {
	Plaza = Vector3.new(0, 0, 0),
	PadCasual = Vector3.new(-26, 0, -96),
	PadRanked = Vector3.new(26, 0, -96),
	Gallery = Vector3.new(0, 0, -140),
	DioramaObsidian = Vector3.new(-105, -12, -215),
	DioramaSanctum = Vector3.new(0, -12, -235),
	DioramaMirage = Vector3.new(105, -12, -215),
	LeaderboardElo = Vector3.new(-64, 0, -64),
	LeaderboardFaction = Vector3.new(64, 0, -64),
	Dawn = Vector3.new(-135, 0, -10),
	Dusk = Vector3.new(135, 0, -10),
	Forms = Vector3.new(-95, 0, 80),
	Forge = Vector3.new(95, 0, 80),
	Quests = Vector3.new(0, 0, 105),
	Training = Vector3.new(0, 0, 170),
}

LobbyConfig.HallHalf = 180 -- ±180 → ~360×360
LobbyConfig.PlazaRadius = 70
LobbyConfig.InnerColonnadeRadius = 92
LobbyConfig.ColonnadeRadius = 170
LobbyConfig.ColumnCount = 16
LobbyConfig.InnerColumnCount = 12
LobbyConfig.ColumnHeight = 42

LobbyConfig.PadRadius = 9
LobbyConfig.PadRaise = 0.6

LobbyConfig.Tags = {
	QueuePad = "BC_QueuePad",
	Zone = "BC_LobbyZone",
	CrystalSpin = "BC_CrystalSpin",
	PortalPulse = "BC_PortalPulse",
	AmbientHost = "BC_LobbyAmbient",
}

LobbyConfig.AmbientSoundIds = {
	Hall = "rbxassetid://9114221256",
	Forge = "rbxassetid://9113839759",
	Fountain = "rbxassetid://9114221571",
}

LobbyConfig.FormsShowcase = {
	{ id = "Astra", color = Color3.fromRGB(90, 190, 255) },
	{ id = "Duelant", color = Color3.fromRGB(255, 196, 120) },
	{ id = "Aegis", color = Color3.fromRGB(120, 200, 160) },
	{ id = "Zephyr", color = Color3.fromRGB(180, 140, 255) },
}

return LobbyConfig
