--!strict
--[[
	Concord Lobby — allée principale + slots 1v1 (ArtPass 8).
	Repère local : origine = (0,0,0) au début d’allée (spawn) ; −Z = nord (descente allée).
	Monde : Origin décale loin des arènes de match.

	Attributs / tags (monde) :
	- Model ConcordLobby : ArtPass, DisplayName, BC_LobbyOrigin, BC_Layout = "AlleySlots"
	- Slots 1v1 : Attribute BC_DuelSlot = number (1..N), tag BC_DuelSlotPad
	  → claim : ProximityPrompt + Touched (voir LobbyBuilder.bindDuelSlots)
	- Pads legacy file : BC_QueueMode = "Casual"|"Ranked", tag BC_QueuePad (fin d’allée)
	- Zones : BC_ZoneId, tag BC_LobbyZone
	- SpawnLocation.Duration > 0 (ForceField)

	Contrat Match / Combat (World lobby n’implémente PAS MatchService) :
	  LobbyBuilder.bindDuelSlots(function(player, slotIndex) … end)
	  1er joueur claim slot → attendre 2e sur même BC_DuelSlot → enqueue slot-scoped → arène.
	  Solo Studio : Combat peut lancer bot si 1 claim resté seul (documenté côté Match).
]]

local LobbyConfig = {}

LobbyConfig.ArtPass = 8
LobbyConfig.Name = "ConcordLobby"
LobbyConfig.DisplayName = "Concord Hall"
LobbyConfig.Layout = "AlleySlots"

-- Loin des arènes de match
LobbyConfig.Origin = Vector3.new(0, 0, 700)

LobbyConfig.Budget = {
	MaxParts = 6000,
	MaxLights = 20,
	MaxEmitters = 30,
	MaxSurfaceGuis = 12, -- 8 slots + marge
}

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
	Success = Color3.fromRGB(76, 224, 138),
	Alley = Color3.fromRGB(36, 40, 52),
	AlleyEdge = Color3.fromRGB(48, 52, 68),
	RingMatA = Color3.fromRGB(90, 40, 48),
	RingMatB = Color3.fromRGB(40, 55, 95),
}

--[[
	Allée : spawn Z≈0 face −Z ; slots le long de −Z.
	Chaque entrée : index, centre ring (X,Z), côté "Left"|"Right", couleur pad.
]]
LobbyConfig.Alley = {
	Width = 40,
	Length = 280, -- Z de +20 derrière spawn → −260
	SpawnLocal = Vector3.new(0, 4, 8), -- début d’allée, face nord
	FloorY = 0,
}

-- 8 slots (4 paires G/D) — ≥6 demandé
LobbyConfig.DuelSlots = {
	{ index = 1, x = -52, z = -36, side = "Left", colorKey = "Focus" },
	{ index = 2, x = 52, z = -36, side = "Right", colorKey = "Success" },
	{ index = 3, x = -52, z = -88, side = "Left", colorKey = "Arcane" },
	{ index = 4, x = 52, z = -88, side = "Right", colorKey = "Dawn" },
	{ index = 5, x = -52, z = -140, side = "Left", colorKey = "Gold" },
	{ index = 6, x = 52, z = -140, side = "Right", colorKey = "Mirage" },
	{ index = 7, x = -52, z = -192, side = "Left", colorKey = "Focus" },
	{ index = 8, x = 52, z = -192, side = "Right", colorKey = "Arcane" },
}

LobbyConfig.SlotRingSize = Vector3.new(28, 1.2, 28)
LobbyConfig.SlotPadSize = Vector3.new(12, 0.4, 10)

-- Pads file legacy (fin d’allée) — MatchService actuel
LobbyConfig.Zones = {
	Plaza = Vector3.new(0, 0, 0),
	PadCasual = Vector3.new(-18, 0, -240),
	PadRanked = Vector3.new(18, 0, -240),
	AlleyEnd = Vector3.new(0, 0, -250),
}

LobbyConfig.PadRadius = 7
LobbyConfig.PadRaise = 0.4

LobbyConfig.Tags = {
	QueuePad = "BC_QueuePad",
	DuelSlotPad = "BC_DuelSlotPad",
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
