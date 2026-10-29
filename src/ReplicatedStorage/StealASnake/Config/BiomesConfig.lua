--!strict
--[[
	BiomesConfig — 15 zones alignées le long de la route (axe -Z), 220 × 220 studs chacune.

	Chaque zone définit :
	  - son décor (Theme → MapBuilder), ses matériaux de terrain (Ground / Trail / Cliff + couleur du Ground) ;
	  - son ambiance client (Mood → EnvironmentController, Particles → AmbienceController) ;
	  - son gardien Alpha (nom, vitesse, rayons, apparence Guardian → GuardianRenderer) ;
	  - plus de porte : les 15 zones sont contiguës ; GateSpeed ne sert plus qu'à calibrer la difficulté
	    (vitesse du gardien, poids des serpents).

	Courbes (documentées, ne pas casser sans raison) :
	  GateSpeed(b)  = 25 × 1.75^(b-2)          (b ≥ 2)
	  GateCash(b)   = 5 000 × 4^(b-2)          (b ≥ 2)
	  GuardianSpeed = max(22, 10 + 0.6 × (16 + GateSpeed^0.65))   → ~60 % de la vitesse d'un joueur « juste qualifié »
]]

export type GuardianLook = {
	Body: Color3,
	Belly: Color3,
	Accent: Color3,
	Eye: Color3,
	Neon: boolean,
	Feature: string, -- effets du gardien (GuardianRenderer.FX) : Nature | Sand | Venom | Frost | Tiger | Stone | Runes | Fins | Fire | Chaos | Shadow | Wings | Iron | Storm | Ultimate
}

export type Mood = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	AtmoColor: Color3,
	AtmoDecay: Color3,
	AtmoDensity: number,
	Haze: number,
	Tint: Color3,
	Saturation: number,
	Bloom: number,
}

export type BiomeDef = {
	Id: string,
	Name: string,
	Order: number,
	Theme: string,
	Center: Vector3,
	Size: Vector3,
	Ground: Enum.Material,
	GroundColor: Color3,
	Trail: Enum.Material,
	Cliff: Enum.Material,
	GateSpeed: number,
	GateCash: number,
	GuardianName: string,
	GuardianSpeed: number,
	AggroRadius: number,
	AttackRadius: number,
	Guardian: GuardianLook,
	Mood: Mood,
	Particles: string,
}

local SIZE = 220
local FIRST_CENTER_Z = -155 -- sortie de l'arène à z = -15, 30 studs de route, puis la zone (110 de demi-taille)
local SPACING = 260 -- 220 de zone + 40 de route entre deux zones

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function mood(clock: number, bright: number, amb: Color3, out: Color3, atmo: Color3, decay: Color3, density: number, haze: number, tint: Color3, sat: number, bloom: number): Mood
	return { ClockTime = clock, Brightness = bright, Ambient = amb, OutdoorAmbient = out, AtmoColor = atmo, AtmoDecay = decay, AtmoDensity = density, Haze = haze, Tint = tint, Saturation = sat, Bloom = bloom }
end

-- { Id, Nom, Thème, Ground, couleur Ground, Trail, Cliff, Gardien, Look, Mood, Particules }
local THEMES = {
	{ "1_Jungle", "Jungle Émeraude", "Jungle", Enum.Material.LeafyGrass, rgb(58, 140, 60), Enum.Material.Ground, Enum.Material.Rock, "Gardien de la Nature",
		{ Body = rgb(94, 158, 58), Belly = rgb(200, 224, 122), Accent = rgb(138, 90, 48), Eye = rgb(240, 224, 64), Neon = false, Feature = "Nature" },
		mood(13, 2.4, rgb(70, 100, 70), rgb(110, 150, 110), rgb(190, 235, 200), rgb(80, 140, 90), 0.36, 1.8, rgb(235, 255, 235), 0.28, 0.4), "Jungle" },
	{ "2_Desert", "Désert des Dunes", "Desert", Enum.Material.Sand, rgb(230, 196, 120), Enum.Material.Sandstone, Enum.Material.Sandstone, "Gardien du Voyageur",
		{ Body = rgb(216, 184, 128), Belly = rgb(242, 226, 184), Accent = rgb(46, 154, 160), Eye = rgb(240, 160, 48), Neon = false, Feature = "Sand" },
		mood(12, 3.2, rgb(130, 110, 85), rgb(180, 155, 120), rgb(255, 225, 170), rgb(220, 160, 90), 0.34, 2.2, rgb(255, 240, 215), 0.15, 0.35), "Desert" },
	{ "3_Swamp", "Marais Venimeux", "Swamp", Enum.Material.Mud, rgb(70, 82, 50), Enum.Material.Ground, Enum.Material.Rock, "Gardien du Venin",
		{ Body = rgb(138, 203, 58), Belly = rgb(216, 240, 138), Accent = rgb(122, 58, 160), Eye = rgb(240, 240, 64), Neon = true, Feature = "Venom" },
		mood(17.4, 1.4, rgb(60, 75, 60), rgb(85, 105, 85), rgb(150, 185, 140), rgb(70, 95, 70), 0.52, 3, rgb(215, 245, 215), 0.05, 0.5), "Swamp" },
	{ "4_Tundra", "Toundra Gelée", "Tundra", Enum.Material.Snow, rgb(235, 245, 255), Enum.Material.Ice, Enum.Material.Glacier, "Gardien des Glaces",
		{ Body = rgb(154, 216, 240), Belly = rgb(232, 248, 255), Accent = rgb(216, 244, 255), Eye = rgb(96, 232, 255), Neon = true, Feature = "Frost" },
		mood(10, 2.6, rgb(120, 140, 170), rgb(170, 190, 220), rgb(220, 235, 255), rgb(140, 170, 210), 0.4, 2.4, rgb(230, 245, 255), -0.05, 0.6), "Snow" },
	{ "5_Bamboo", "Bambouseraie Brumeuse", "Bamboo", Enum.Material.Grass, rgb(120, 175, 80), Enum.Material.Ground, Enum.Material.Rock, "Gardien des Jungles",
		{ Body = rgb(232, 134, 42), Belly = rgb(248, 240, 224), Accent = rgb(58, 138, 58), Eye = rgb(96, 192, 64), Neon = false, Feature = "Tiger" },
		mood(7.5, 1.9, rgb(100, 120, 100), rgb(150, 170, 140), rgb(220, 235, 215), rgb(150, 170, 150), 0.5, 2.8, rgb(245, 255, 240), 0.1, 0.4), "Petals" },
	{ "6_Canyon", "Canyon Rouge", "Canyon", Enum.Material.Sandstone, rgb(196, 110, 70), Enum.Material.Ground, Enum.Material.Sandstone, "Gardien de Pierre",
		{ Body = rgb(122, 122, 114), Belly = rgb(154, 152, 140), Accent = rgb(240, 192, 48), Eye = rgb(240, 192, 48), Neon = true, Feature = "Stone" },
		mood(16.5, 2.8, rgb(140, 95, 75), rgb(190, 130, 100), rgb(255, 200, 160), rgb(200, 110, 70), 0.32, 2, rgb(255, 230, 210), 0.2, 0.35), "Desert" },
	{ "7_Mushroom", "Forêt Champignon", "Mushroom", Enum.Material.Limestone, rgb(120, 80, 150), Enum.Material.Ground, Enum.Material.Rock, "Gardien des Runes",
		{ Body = rgb(122, 74, 184), Belly = rgb(176, 138, 224), Accent = rgb(216, 168, 255), Eye = rgb(240, 192, 255), Neon = true, Feature = "Runes" },
		mood(20, 1.5, rgb(90, 60, 120), rgb(120, 90, 160), rgb(200, 160, 240), rgb(110, 70, 160), 0.45, 2.4, rgb(240, 225, 255), 0.35, 0.8), "Spores" },
	{ "8_Reef", "Récif Corallien", "Reef", Enum.Material.Salt, rgb(250, 220, 190), Enum.Material.Sand, Enum.Material.Rock, "Gardien des Océans",
		{ Body = rgb(46, 176, 208), Belly = rgb(240, 224, 184), Accent = rgb(240, 106, 122), Eye = rgb(58, 106, 208), Neon = false, Feature = "Fins" },
		mood(15, 2.7, rgb(90, 140, 160), rgb(140, 190, 210), rgb(190, 235, 255), rgb(80, 170, 210), 0.3, 1.6, rgb(225, 250, 255), 0.3, 0.45), "Bubbles" },
	{ "9_Volcano", "Caldeira Volcanique", "Volcano", Enum.Material.Basalt, rgb(45, 38, 40), Enum.Material.Basalt, Enum.Material.Basalt, "Gardien de Magma",
		{ Body = rgb(42, 30, 28), Belly = rgb(74, 42, 32), Accent = rgb(255, 122, 32), Eye = rgb(255, 176, 48), Neon = true, Feature = "Fire" },
		mood(18.6, 1.2, rgb(110, 55, 40), rgb(140, 70, 50), rgb(255, 130, 80), rgb(120, 40, 20), 0.45, 2.6, rgb(255, 215, 195), 0.25, 0.7), "Embers" },
	{ "10_Crystal", "Grotte de Cristal", "Crystal", Enum.Material.Glacier, rgb(110, 200, 230), Enum.Material.Slate, Enum.Material.Slate, "Gardien du Chaos",
		{ Body = rgb(58, 48, 54), Belly = rgb(90, 42, 48), Accent = rgb(240, 32, 64), Eye = rgb(255, 48, 64), Neon = true, Feature = "Chaos" },
		mood(22, 1.3, rgb(60, 90, 130), rgb(80, 120, 170), rgb(150, 210, 255), rgb(60, 100, 170), 0.42, 1.8, rgb(220, 240, 255), 0.3, 1), "Crystal" },
	{ "11_Graveyard", "Cimetière Hanté", "Graveyard", Enum.Material.Slate, rgb(70, 72, 80), Enum.Material.Ground, Enum.Material.Slate, "Gardien de l'Ombre",
		{ Body = rgb(58, 26, 96), Belly = rgb(106, 58, 160), Accent = rgb(176, 96, 255), Eye = rgb(224, 160, 255), Neon = true, Feature = "Shadow" },
		mood(0, 1.1, rgb(60, 70, 90), rgb(70, 80, 110), rgb(120, 150, 170), rgb(40, 60, 80), 0.55, 3, rgb(210, 230, 235), -0.2, 0.6), "Ghost" },
	{ "12_Temple", "Temple Aztèque", "Temple", Enum.Material.Brick, rgb(170, 140, 90), Enum.Material.Cobblestone, Enum.Material.Rock, "Gardien des Cieux",
		{ Body = rgb(244, 242, 236), Belly = rgb(255, 248, 232), Accent = rgb(232, 184, 64), Eye = rgb(74, 160, 224), Neon = false, Feature = "Wings" },
		mood(9, 2.5, rgb(110, 110, 80), rgb(160, 160, 120), rgb(230, 230, 180), rgb(150, 150, 100), 0.38, 2, rgb(255, 250, 225), 0.25, 0.4), "Leaves" },
	{ "13_Toxic", "Terres Toxiques", "Toxic", Enum.Material.Pavement, rgb(90, 100, 60), Enum.Material.Ground, Enum.Material.Rock, "Gardien de Fer",
		{ Body = rgb(138, 140, 148), Belly = rgb(106, 108, 116), Accent = rgb(192, 138, 58), Eye = rgb(255, 42, 42), Neon = true, Feature = "Iron" },
		mood(16, 1.3, rgb(80, 100, 50), rgb(110, 130, 70), rgb(190, 230, 100), rgb(90, 120, 40), 0.55, 2.8, rgb(230, 255, 200), 0.1, 0.8), "Toxic" },
	{ "14_Sky", "Royaume Céleste", "Sky", Enum.Material.Ice, rgb(255, 235, 245), Enum.Material.Marble, Enum.Material.Ice, "Gardien de la Tempête",
		{ Body = rgb(36, 58, 122), Belly = rgb(240, 208, 64), Accent = rgb(248, 224, 64), Eye = rgb(248, 240, 96), Neon = true, Feature = "Storm" },
		mood(8, 3, rgb(160, 150, 190), rgb(210, 200, 240), rgb(255, 235, 250), rgb(220, 200, 255), 0.3, 1.4, rgb(255, 245, 255), 0.2, 0.9), "Feathers" },
	{ "15_Cosmic", "Néant Cosmique", "Cosmic", Enum.Material.Asphalt, rgb(40, 32, 78), Enum.Material.Asphalt, Enum.Material.Slate, "L'Ultime Destructeur",
		{ Body = rgb(42, 34, 32), Belly = rgb(90, 32, 16), Accent = rgb(255, 106, 16), Eye = rgb(255, 192, 64), Neon = true, Feature = "Ultimate" },
		mood(0.5, 1.6, rgb(70, 60, 130), rgb(80, 70, 150), rgb(120, 110, 220), rgb(40, 30, 100), 0.32, 1.5, rgb(220, 215, 255), 0.35, 0.9), "Stars" },
}

local BiomesConfig: { BiomeDef } = {}

for i, t in THEMES do
	local gateSpeed = if i == 1 then 0 else math.floor(25 * 1.75 ^ (i - 2) + 0.5)
	local gateCash = if i == 1 then 0 else 5000 * 4 ^ (i - 2)
	local qualified = 16 + gateSpeed ^ 0.65
	table.insert(BiomesConfig, {
		Id = t[1] :: string,
		Name = t[2] :: string,
		Order = i,
		Theme = t[3] :: string,
		Center = Vector3.new(0, 2, FIRST_CENTER_Z - (i - 1) * SPACING),
		Size = Vector3.new(SIZE, 40, SIZE),
		Ground = t[4] :: Enum.Material,
		GroundColor = t[5] :: Color3,
		Trail = t[6] :: Enum.Material,
		Cliff = t[7] :: Enum.Material,
		GateSpeed = gateSpeed,
		GateCash = gateCash,
		GuardianName = t[8] :: string,
		GuardianSpeed = math.max(22, math.floor(10 + 0.6 * qualified)),
		AggroRadius = 55 + (i - 1) * 3.5,
		AttackRadius = 7 + (i - 1) * 0.5,
		Guardian = t[9] :: GuardianLook,
		Mood = t[10] :: Mood,
		Particles = t[11] :: string,
	})
end

return BiomesConfig
