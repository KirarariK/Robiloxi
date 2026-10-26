--!strict
--[[
	Concord Lobby — croiseur intérieur + baie Glass + 2 slots (ArtPass 9).
	Repère local : spawn (0,0,0) zone ; −Z = vers baie / arènes.
	Monde : Origin = (0,0,700).

	Attributs :
	- ConcordLobby : ArtPass, BC_Layout=CruiserBay, BC_LobbyOrigin, BC_DuelSlotCount=2
	- Slots : BC_DuelSlot 1|2, tag BC_DuelSlotPad (Prompt + Touched)
	- Spawn : tag BC_LobbySpawn (si CombatConfig.Tags.LobbySpawn)

	Contrat Match : LobbyBuilder.bindDuelSlots(claimFn) — SlotMatchService.
	8 arènes : offsets dans ArenaLayout (L1–4 / R1–4) — ArenaService.
]]

local LobbyConfig = {}

LobbyConfig.ArtPass = 9
LobbyConfig.Name = "ConcordLobby"
LobbyConfig.DisplayName = "Concord Hall"
LobbyConfig.Layout = "CruiserBay"

LobbyConfig.Origin = Vector3.new(0, 0, 700)

LobbyConfig.Budget = {
	MaxParts = 6000,
	MaxLights = 20,
	MaxEmitters = 30,
	MaxSurfaceGuis = 8,
}

LobbyConfig.Colors = {
	Ink900 = Color3.fromRGB(7, 11, 20),
	Ink800 = Color3.fromRGB(13, 20, 36),
	Ink700 = Color3.fromRGB(20, 29, 51),
	Ink600 = Color3.fromRGB(29, 42, 71),
	Hull = Color3.fromRGB(24, 28, 38),
	HullLite = Color3.fromRGB(38, 44, 58),
	Metal = Color3.fromRGB(72, 82, 98),
	MetalDark = Color3.fromRGB(48, 54, 68),
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
	Glass = Color3.fromRGB(120, 170, 210),
	RingMatA = Color3.fromRGB(90, 40, 48),
	RingMatB = Color3.fromRGB(40, 55, 95),
	Alley = Color3.fromRGB(28, 32, 44),
	AlleyEdge = Color3.fromRGB(42, 48, 62),
	Marble = Color3.fromRGB(42, 50, 72),
	MarbleLite = Color3.fromRGB(78, 88, 118),
	MarblePolish = Color3.fromRGB(58, 66, 92),
}

--[[ Hall croiseur : spawn sud → baie nord (−Z). ]]
LobbyConfig.Hall = {
	Width = 56,
	Length = 140,
	Height = 28,
	SpawnLocal = Vector3.new(0, 4, 40), -- début hall, face baie (−Z)
	BayZ = -85, -- paroi Glass face arènes
	BayWidth = 72,
	BayHeight = 22,
	FloorY = 0,
}

-- Exactement 2 slots devant la baie
LobbyConfig.DuelSlots = {
	{ index = 1, x = -16, z = -58, side = "Left", colorKey = "Focus" },
	{ index = 2, x = 16, z = -58, side = "Right", colorKey = "Dawn" },
}

LobbyConfig.SlotRingSize = Vector3.new(22, 1.0, 22)
LobbyConfig.SlotPadSize = Vector3.new(11, 0.4, 9)

--[[
	8 arènes vastes (monde studs) — 4 gauche / 4 droite du hall.
	Hall origin monde ≈ (0,0,700) ; baie regarde −Z vers ces floors.
]]
LobbyConfig.ArenaLayout = {
	{ id = "ObsidianPit", displayName = "Creuset d'Obsidienne", side = "Left", index = 1, ox = -380, oz = 450 },
	{ id = "SanctumAstres", displayName = "Sanctum des Deux Astres", side = "Left", index = 2, ox = -380, oz = 280 },
	{ id = "TroneEclipse", displayName = "Trône d'Éclipse", side = "Left", index = 3, ox = -380, oz = 110 },
	{ id = "QuaiMirage", displayName = "Quai Mirage", side = "Left", index = 4, ox = -380, oz = -60 },
	{ id = "ForgeAube", displayName = "Forge de l'Aube", side = "Right", index = 5, ox = 380, oz = 450 },
	{ id = "SpireCrepuscule", displayName = "Flèche du Crépuscule", side = "Right", index = 6, ox = 380, oz = 280 },
	{ id = "RecifNeant", displayName = "Récif du Néant", side = "Right", index = 7, ox = 380, oz = 110 },
	{ id = "CourCristal", displayName = "Cour de Cristal", side = "Right", index = 8, ox = 380, oz = -60 },
}

LobbyConfig.ArenaFloorSize = 120 -- studs (dash + Force)
LobbyConfig.ArenaSpawnSep = 32 -- demi-distance spawns A/B

-- Legacy queue pads (optionnels, fond du hall)
LobbyConfig.Zones = {
	Plaza = Vector3.new(0, 0, 40),
	PadCasual = Vector3.new(-20, 0, 55),
	PadRanked = Vector3.new(20, 0, 55),
	Bay = Vector3.new(0, 0, -85),
}

LobbyConfig.PadRadius = 6
LobbyConfig.PadRaise = 0.35

LobbyConfig.Tags = {
	QueuePad = "BC_QueuePad",
	DuelSlotPad = "BC_DuelSlotPad",
	Zone = "BC_LobbyZone",
	CrystalSpin = "BC_CrystalSpin",
	PortalPulse = "BC_PortalPulse",
	AmbientHost = "BC_LobbyAmbient",
	LobbySpawn = "BC_LobbySpawn",
	-- VFX polish : strips néon hall → NeonFx.bindTaggedStrips (budget emitters partagé)
	NeonStrip = "BC_NeonStrip",
}

-- Placeholders Audio only — IDs non-Audio (ex. 9114221256) provoquent erreur rouge Play.
LobbyConfig.AmbientSoundIds = {
	Hall = "",
	Forge = "",
	Fountain = "",
}

LobbyConfig.FormsShowcase = {
	{ id = "Astra", color = Color3.fromRGB(90, 190, 255) },
	{ id = "Duelant", color = Color3.fromRGB(255, 196, 120) },
	{ id = "Aegis", color = Color3.fromRGB(120, 200, 160) },
	{ id = "Zephyr", color = Color3.fromRGB(180, 140, 255) },
}

return LobbyConfig
