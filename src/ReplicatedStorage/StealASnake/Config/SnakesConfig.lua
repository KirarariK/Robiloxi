--!strict
--[[
	SnakesConfig — les 98 serpents de l'encyclopédie, répartis par thème dans les 15 zones (1 Secret par zone).
	GÉNÉRÉ depuis tools/steal-a-snake/blender/catalog.py (gen_snakes_config.py) : modifier le catalogue puis relancer.
	Modèles 3D : Assets.Models.<Id> (Blender, cartoon_snakes.py) avec pièces animées Body / Head / Tail / Wing* / Prop.

	Revenu et poids sont dérivés de la rareté et de la zone (formules documentées) :
	  BaseIncome = Rarity.BaseIncome × 2.6^(zone-1)
	  BaseWeight = Rarity.BaseWeight × max(1, (16 + GateSpeed(zone)^0.65) / 24)
	  → plus la zone est loin, plus les serpents rapportent ET pèsent lourd : la Vitesse reste nécessaire.

	Look : apparence procédurale (ModelFactory). Si un modèle 3D nommé comme l'Id existe dans
	ReplicatedStorage.StealASnake.Assets.Models, il est utilisé à la place.
]]
local BiomesConfig = require(script.Parent.BiomesConfig)
local RarityConfig = require(script.Parent.RarityConfig)

export type SnakeLook = {
	Body: Color3,
	Accent: Color3,
	Belly: Color3,
	Pattern: string, -- Solid | Stripes | Bands | Spots | Diamonds | Rings | Glow
	Head: string, -- Round | Viper | Cobra | Horned | Crest | Hydra | Mane | Skull | Crown
	Extras: { string },
	Material: string, -- Smooth | Neon | Glass | Foil | Ice | Slate | Marble | Velvet
	Size: number,
}

export type SnakeDef = {
	Id: string,
	DisplayName: string,
	Biome: number,
	Rarity: string,
	RarityMult: number,
	BaseWeight: number,
	WeightMin: number,
	WeightMax: number,
	BaseIncome: number,
	ModelName: string,
	Look: SnakeLook,
}

-- { Id, Nom, zone, rareté (1..7), corps, accent, motif, tête, extras, matière }
local R = RarityConfig.Order
local SPECIES = {
	-- zone 1
	{ "Green_Snake", "Serpent Vert", 1, 1, "3E9A2E", "8AD24F", "Solid", "Round", "", "Smooth" },
	{ "Lime_Snake", "Serpent Citron", 1, 2, "6CC22A", "A4E03A", "Solid", "Viper", "", "Smooth" },
	{ "Jungle_Python", "Python Tacheté", 1, 3, "7DC044", "2E6E2A", "Spots", "Viper", "", "Smooth" },
	{ "Spiky_Snake", "Serpent Épineux", 1, 4, "5E9A3A", "7DC04F", "Spots", "Round", "", "Smooth" },
	{ "Leaf_Snake", "Serpent Feuillage", 1, 5, "2F7A3A", "5DAF4F", "Diamonds", "Round", "", "Smooth" },
	{ "Leafcrown_Snake", "Serpent Couronne de Feuilles", 1, 6, "4C8C3E", "8CC060", "Diamonds", "Round", "Sparkle", "Smooth" },
	{ "Emerald_Dragon", "Dragon Émeraude", 1, 7, "3A9A3A", "8ADA4A", "Diamonds", "Horned", "Sparkle", "Smooth" },
	-- zone 2
	{ "Sand_Snake", "Serpent des Sables", 2, 1, "D9C08E", "A8865A", "Spots", "Round", "", "Smooth" },
	{ "Sandstone_Snake", "Serpent de Grès Doré", 2, 2, "B8924A", "8A6428", "Spots", "Viper", "", "Smooth" },
	{ "Explorer_Snake", "Serpent Explorateur", 2, 3, "8C6440", "5E4228", "Spots", "Viper", "", "Smooth" },
	{ "Iron_Pharaoh", "Pharaon de Fer", 2, 4, "7E7A74", "B8862E", "Bands", "Viper", "", "Smooth" },
	{ "Golden_Pharaoh", "Pharaon Doré", 2, 5, "B88E3A", "7E5A22", "Diamonds", "Round", "", "Smooth" },
	{ "Blue_Pharaoh", "Pharaon Bleu", 2, 6, "5E8A98", "C8A050", "Bands", "Round", "", "Smooth" },
	{ "Sun_Pharaoh", "Pharaon Soleil", 2, 7, "D8A030", "2E5A9A", "Bands", "Round", "Sparkle", "Smooth" },
	-- zone 3
	{ "Toad_Snake", "Serpent Crapaud", 3, 1, "9A6A3E", "7A5030", "Spots", "Round", "", "Smooth" },
	{ "Grey_Ranger", "Serpent Ranger", 3, 2, "8A8A88", "5A5A58", "Spots", "Viper", "", "Smooth" },
	{ "Safari_Snake", "Serpent Safari", 3, 3, "D8603A", "F0A0A0", "Spots", "Round", "", "Smooth" },
	{ "Dapper_Snake", "Serpent Élégant", 3, 4, "3A8AB0", "2A5A80", "Spots", "Viper", "", "Smooth" },
	{ "Propeller_Snake", "Serpent Hélice", 3, 5, "3A70B8", "2A4A90", "Spots", "Round", "Sparkle", "Smooth" },
	{ "Pumpkin_Snake", "Serpent Citrouille", 3, 7, "D8701E", "7A2A08", "Bands", "Round", "Flames", "Smooth" },
	-- zone 4
	{ "Frost_Snake", "Serpent Givré", 4, 1, "9AD4F0", "5AA8D8", "Solid", "Round", "", "Smooth" },
	{ "Sapphire_Snake", "Serpent Saphir", 4, 2, "2A4E90", "6A90C8", "Spots", "Viper", "", "Smooth" },
	{ "Ice_King", "Roi des Glaces", 4, 3, "5EB8C0", "A0E0D0", "Bands", "Viper", "", "Smooth" },
	{ "Crystal_Ice_Snake", "Serpent Cristal", 4, 4, "3AA8D8", "70CCEA", "Solid", "Round", "Sparkle", "Smooth" },
	{ "Glacier_Snake", "Serpent Glacier", 4, 5, "8DDDF3", "53B8E0", "Solid", "Viper", "Sparkle", "Smooth" },
	{ "Snow_Spirit", "Esprit des Neiges", 4, 6, "70BEDF", "90DCF3", "Solid", "Round", "Ghost,Sparkle", "Smooth" },
	{ "Silver_Dragon", "Dragon d'Argent", 4, 7, "C8C8CC", "A1A2AB", "Diamonds", "Horned", "Sparkle", "Smooth" },
	-- zone 5
	{ "Pastel_Snake", "Serpent Pastel", 5, 1, "F2B8A8", "76C5B7", "Bands", "Round", "", "Smooth" },
	{ "Pastel_Rainbow", "Arc-en-ciel Pastel", 5, 2, "C9A0C8", "8AB8E0", "Bands", "Round", "", "Smooth" },
	{ "Rainbow_Snake", "Serpent Arc-en-ciel", 5, 3, "E86A6A", "6AA8E8", "Bands", "Round", "", "Smooth" },
	{ "Candy_Snake", "Serpent Sucre d'Orge", 5, 4, "F2EDEA", "E05A6A", "Stripes", "Round", "", "Smooth" },
	{ "Rainbow_Princess", "Princesse Arc-en-ciel", 5, 5, "F0A0B8", "E06A6A", "Bands", "Round", "Sparkle", "Smooth" },
	{ "Unicorn_Snake", "Serpent Licorne", 5, 7, "E8C870", "E070B0", "Spots", "Round", "Sparkle,Stars", "Smooth" },
	-- zone 6
	{ "Earth_Dragon", "Dragon de Terre", 6, 1, "7A5030", "5E3A20", "Diamonds", "Horned", "", "Smooth" },
	{ "Stone_Snake", "Serpent de Pierre", 6, 2, "8A7E72", "5E544A", "Spots", "Viper", "", "Smooth" },
	{ "Robo_Snake", "Robo-Serpent", 6, 3, "A8BCC8", "40D8E0", "Rings", "Round", "Sparkle", "Smooth" },
	{ "Knight_Snake", "Serpent Chevalier", 6, 4, "6A6062", "D07A30", "Diamonds", "Viper", "", "Smooth" },
	{ "Fang_Snake", "Serpent Crocs", 6, 5, "3A3236", "E8E4D8", "Diamonds", "Viper", "", "Smooth" },
	{ "Red_Dragon", "Dragon Rouge", 6, 7, "C83A30", "F0C080", "Diamonds", "Horned", "Flames", "Smooth" },
	-- zone 7
	{ "Pink_Snake", "Serpent Rose", 7, 1, "F2A8C0", "DA8CA7", "Solid", "Round", "", "Smooth" },
	{ "Coral_Pink_Snake", "Serpent Corail Rose", 7, 2, "E86A68", "C63F41", "Spots", "Viper", "", "Smooth" },
	{ "Party_Snake", "Serpent Fêtard", 7, 3, "EDB7C2", "C37F9D", "Spots", "Round", "", "Smooth" },
	{ "Clown_Snake", "Serpent Clown", 7, 4, "F0EBDE", "E04030", "Bands", "Round", "", "Smooth" },
	{ "Patchwork_Snake", "Serpent Patchwork", 7, 5, "C8A060", "E07030", "Spots", "Round", "", "Smooth" },
	{ "Wizard_Snake", "Serpent Sorcier", 7, 7, "C83A30", "7A3A9A", "Spots", "Round", "Sparkle,Stars", "Smooth" },
	-- zone 8
	{ "Water_Snake", "Serpent d'Eau", 8, 1, "359DC8", "73CCE2", "Solid", "Viper", "", "Smooth" },
	{ "Wave_Snake", "Serpent Vague", 8, 2, "4DACCC", "72CCE8", "Solid", "Viper", "", "Smooth" },
	{ "Coral_Snake", "Serpent Corail", 8, 3, "C84A4E", "F08AA0", "Spots", "Round", "", "Smooth" },
	{ "Mohawk_Snake", "Serpent Crête d'Algue", 8, 4, "2E8E68", "63E05C", "Bands", "Round", "", "Smooth" },
	{ "Tidal_Snake", "Serpent Raz-de-Marée", 8, 5, "2685A9", "60CFE3", "Solid", "Viper", "Bubbles", "Smooth" },
	{ "Octopus", "Pieuvre Mystique", 8, 6, "9A62C8", "5E3B83", "Spots", "Round", "Bubbles", "Smooth" },
	{ "Sea_Hydra", "Hydre des Mers", 8, 7, "3A8A6A", "71BB88", "Diamonds", "Horned", "Bubbles,Sparkle", "Smooth" },
	-- zone 9
	{ "Ember_Snake", "Serpent Braise", 9, 1, "D85625", "A4240A", "Glow", "Viper", "", "Smooth" },
	{ "Flamehorn_Snake", "Serpent Cornes de Feu", 9, 2, "C8402E", "F0A030", "Diamonds", "Round", "Flames", "Smooth" },
	{ "Lava_Rock_Snake", "Serpent Roche-Lave", 9, 3, "5E4A48", "ED8F34", "Glow", "Viper", "Flames", "Smooth" },
	{ "Baby_Fire_Dragon", "Bébé Dragon de Feu", 9, 4, "CF4729", "DD7C48", "Diamonds", "Horned", "Flames", "Smooth" },
	{ "Fire_Dragon", "Dragon de Feu", 9, 5, "D0502A", "F08A30", "Glow", "Horned", "Flames", "Smooth" },
	{ "Magma_Snake", "Serpent de Magma", 9, 6, "2A1A18", "EC8940", "Glow", "Viper", "Flames", "Smooth" },
	{ "Living_Flame", "Flamme Vivante", 9, 7, "E8641E", "F8E070", "Glow", "Viper", "Flames,Sparkle", "Smooth" },
	-- zone 10
	{ "Patch_King", "Roi Patchwork", 10, 1, "CBC08B", "5273A4", "Spots", "Round", "", "Smooth" },
	{ "Glitter_Snake", "Serpent Paillettes", 10, 2, "D8A848", "E070A0", "Spots", "Round", "Sparkle", "Smooth" },
	{ "Blossom_Snake", "Serpent Fleuri", 10, 3, "7AB848", "F08AB8", "Spots", "Round", "", "Smooth" },
	{ "Lavender_Snake", "Serpent Lavande", 10, 4, "A884D0", "F07890", "Bands", "Round", "", "Smooth" },
	{ "Flower_King", "Roi des Fleurs", 10, 5, "5AAA48", "E070A0", "Spots", "Round", "Sparkle", "Smooth" },
	{ "Golden_Crown_Snake", "Serpent d'Or Couronné", 10, 7, "E8A830", "B36E20", "Diamonds", "Round", "Sparkle", "Smooth" },
	-- zone 11
	{ "Mummy_Snake", "Serpent Momie", 11, 1, "EAD7AB", "98855B", "Rings", "Round", "", "Smooth" },
	{ "Bandaged_Snake", "Serpent Bandelettes", 11, 2, "E6D8B4", "9D8F6E", "Rings", "Round", "", "Smooth" },
	{ "Bone_Serpent", "Serpent d'Os", 11, 3, "D8D4B0", "9F9A70", "Diamonds", "Skull", "", "Smooth" },
	{ "Skeleton_Snake", "Serpent Squelette", 11, 4, "E3DDC2", "6E6455", "Rings", "Skull", "Ghost", "Smooth" },
	{ "Ancient_Skeleton", "Squelette Ancien", 11, 5, "D0D9B3", "46623C", "Rings", "Skull", "Ghost,Sparkle", "Smooth" },
	{ "Shadow_Gangster", "Gangster de l'Ombre", 11, 6, "3A1A5A", "AD57D9", "Solid", "Viper", "Ghost", "Neon" },
	{ "Shadow_Dragon", "Dragon des Ténèbres", 11, 7, "281040", "AF5BDB", "Solid", "Horned", "Ghost,Sparkle", "Smooth" },
	-- zone 12
	{ "Cream_King", "Roi Crème", 12, 1, "E8C898", "9A5A3A", "Spots", "Round", "", "Smooth" },
	{ "Green_King", "Roi Vert", 12, 2, "3E8A48", "B8A860", "Spots", "Viper", "", "Smooth" },
	{ "Turquoise_King", "Roi Turquoise", 12, 3, "4AA88A", "2E7A68", "Diamonds", "Round", "", "Smooth" },
	{ "Sparkle_King", "Roi Étincelant", 12, 4, "6EA83A", "B8E060", "Spots", "Viper", "Sparkle", "Smooth" },
	{ "Temple_Pharaoh", "Pharaon du Temple", 12, 5, "5A8A98", "C89A40", "Bands", "Round", "Sparkle", "Smooth" },
	{ "Mage_Snake", "Serpent Mage", 12, 6, "7A5A98", "4A3A88", "Solid", "Round", "Stars", "Smooth" },
	{ "Treasure_Snake", "Serpent Trésor", 12, 7, "F2C83A", "CA8F1D", "Solid", "Round", "Sparkle", "Smooth" },
	-- zone 13
	{ "Pixel_Snake", "Serpent Pixel", 13, 1, "4BB43D", "1B751F", "Solid", "Round", "", "Smooth" },
	{ "Bigeye_Snake", "Serpent Gros Yeux", 13, 2, "5AB838", "2F7613", "Solid", "Round", "", "Smooth" },
	{ "Slime_Snake", "Serpent Gluant", 13, 3, "62DD2B", "1C9109", "Glow", "Viper", "Bubbles", "Smooth" },
	{ "Toxic_Snake", "Serpent Toxique", 13, 4, "4A9A30", "82DA2D", "Spots", "Viper", "Bubbles", "Smooth" },
	{ "Slime_Blob", "Blob Visqueux", 13, 5, "6ACF32", "2B8B19", "Glow", "Round", "Bubbles", "Smooth" },
	{ "Moss_Dragon", "Dragon des Mousses", 13, 6, "48A033", "86DF3A", "Diamonds", "Horned", "Bubbles", "Smooth" },
	{ "Toxic_Robot", "Robot Toxique", 13, 7, "8A9A98", "40E070", "Rings", "Round", "Bubbles,Sparkle", "Smooth" },
	-- zone 14
	{ "Thunder_Snake", "Serpent Éclair", 14, 1, "7888B7", "F0F070", "Spots", "Viper", "Sparkle", "Smooth" },
	{ "Thunder_Dragon", "Dragon du Tonnerre", 14, 2, "3A9A6A", "E07A30", "Diamonds", "Horned", "Sparkle", "Smooth" },
	{ "Phoenix", "Phénix", 14, 3, "C83A2A", "F0A040", "Diamonds", "Crest", "Flames", "Smooth" },
	{ "Golden_Phoenix", "Phénix Doré", 14, 4, "E06A2A", "F8D060", "Diamonds", "Crest", "Flames,Sparkle", "Smooth" },
	{ "Storm_Hydra", "Hydre de l'Orage", 14, 5, "6070A0", "8895C1", "Diamonds", "Horned", "Sparkle", "Smooth" },
	{ "Silver_Flame_King", "Roi d'Argent", 14, 7, "8A8680", "E0A030", "Diamonds", "Viper", "Flames,Sparkle", "Smooth" },
	-- zone 15
	{ "Void_Snake", "Serpent du Vide", 15, 1, "1A0A2A", "B04CD6", "Solid", "Round", "Ghost", "Neon" },
	{ "Night_Dragon", "Dragon de la Nuit", 15, 2, "2A1040", "C065ED", "Solid", "Horned", "Ghost", "Smooth" },
	{ "Eclipse_Dragon", "Dragon Éclipse", 15, 3, "301050", "AE52DC", "Solid", "Horned", "Ghost,Sparkle", "Smooth" },
	{ "Galaxy_Queen", "Reine Galaxie", 15, 4, "2A2470", "B060F0", "Glow", "Round", "Stars", "Smooth" },
	{ "Twin_Shadow", "Hydre Jumelle", 15, 5, "3A2A50", "A047CF", "Diamonds", "Horned", "Ghost,Stars", "Smooth" },
	{ "Galaxy_King", "Roi Galaxie", 15, 7, "352978", "8A9AF0", "Glow", "Round", "Stars,Sparkle", "Smooth" },
}

-- Anciennes espèces (avant l'encyclopédie) → nouvelle espèce de même zone et rareté (migration des sauvegardes)
local LEGACY: { [string]: string } = {
	Viper_Green = "Green_Snake",
	Leaf_Viper = "Green_Snake",
	Emerald_Boa = "Lime_Snake",
	Jungle_Krait = "Lime_Snake",
	Python_Royal = "Jungle_Python",
	Moss_Python = "Jungle_Python",
	Liana_Boa = "Spiky_Snake",
	Orchid_Viper = "Leaf_Snake",
	Jaguar_Python = "Leafcrown_Snake",
	Ancient_Emerald = "Emerald_Dragon",
	Sand_Asp = "Sand_Snake",
	Scarab_Viper = "Sand_Snake",
	Dune_Sidewinder = "Sandstone_Snake",
	Horned_Rattler = "Explorer_Snake",
	Cobra_Royal = "Iron_Pharaoh",
	Pharaoh_Asp = "Golden_Pharaoh",
	Mirage_Cobra = "Blue_Pharaoh",
	Sphinx_Serpent = "Sun_Pharaoh",
	Bog_Adder = "Toad_Snake",
	Toxic_Mamba = "Grey_Ranger",
	Mire_Moccasin = "Safari_Snake",
	Anaconda_Spiked = "Dapper_Snake",
	Swamp_Hydra = "Propeller_Snake",
	Witch_Serpent = "Pumpkin_Snake",
	Croak_Basilisk = "Pumpkin_Snake",
	Frost_Adder = "Frost_Snake",
	Snow_Python = "Sapphire_Snake",
	Glacier_Krait = "Ice_King",
	Aurora_Boa = "Crystal_Ice_Snake",
	Yeti_Cobra = "Glacier_Snake",
	Blizzard_Wyrm = "Snow_Spirit",
	Frozen_Heart = "Silver_Dragon",
	Bamboo_Viper = "Pastel_Snake",
	Lotus_Snake = "Pastel_Rainbow",
	Panda_Python = "Rainbow_Snake",
	Lantern_Krait = "Candy_Snake",
	Jade_Naga = "Rainbow_Princess",
	Lunar_Dragon = "Unicorn_Snake",
	Spirit_Koi = "Unicorn_Snake",
	Dust_Racer = "Earth_Dragon",
	Red_Rattler = "Stone_Snake",
	Mesa_Kingsnake = "Robo_Snake",
	Bandit_Cobra = "Knight_Snake",
	Thunder_Rattler = "Fang_Snake",
	Gold_Rush_Python = "Red_Dragon",
	Canyon_Phantom = "Red_Dragon",
	Spore_Adder = "Pink_Snake",
	Truffle_Boa = "Coral_Pink_Snake",
	Glowcap_Viper = "Party_Snake",
	Fungal_Hydra = "Clown_Snake",
	Myco_Naga = "Patchwork_Snake",
	Toadstool_King = "Wizard_Snake",
	Mycelium_Mind = "Wizard_Snake",
	Sea_Krait = "Water_Snake",
	Clownfish_Snake = "Wave_Snake",
	Coral_Viper = "Coral_Snake",
	Eel_Serpent = "Mohawk_Snake",
	Pearl_Naga = "Tidal_Snake",
	Kraken_Serpent = "Octopus",
	Atlantis_Leviathan = "Sea_Hydra",
	Ash_Cobra = "Ember_Snake",
	Cinder_Viper = "Flamehorn_Snake",
	Lava_Python = "Lava_Rock_Snake",
	Obsidian_Asp = "Baby_Fire_Dragon",
	Magma_Serpent = "Fire_Dragon",
	Phoenix_Serpent = "Magma_Snake",
	Volcano_Heart = "Living_Flame",
	Quartz_Viper = "Patch_King",
	Amethyst_Boa = "Glitter_Snake",
	Geode_Python = "Blossom_Snake",
	Prism_Krait = "Lavender_Snake",
	Diamond_Cobra = "Flower_King",
	Crystal_Serpent = "Golden_Crown_Snake",
	Opal_Eternal = "Golden_Crown_Snake",
	Bone_Adder = "Mummy_Snake",
	Grave_Python = "Bandaged_Snake",
	Wisp_Viper = "Bone_Serpent",
	Lich_Cobra = "Skeleton_Snake",
	Banshee_Serpent = "Ancient_Skeleton",
	Reaper_Naga = "Shadow_Gangster",
	Headless_Horror = "Shadow_Dragon",
	Glyph_Viper = "Cream_King",
	Sun_Python = "Green_King",
	Idol_Serpent = "Turquoise_King",
	Feathered_Boa = "Sparkle_King",
	Gold_Mask_Cobra = "Temple_Pharaoh",
	Quetzal_Sovereign = "Mage_Snake",
	El_Dorado = "Treasure_Snake",
	Sludge_Adder = "Pixel_Snake",
	Barrel_Python = "Bigeye_Snake",
	Mutant_Krait = "Slime_Snake",
	Two_Headed_Viper = "Toxic_Snake",
	Rad_Cobra = "Slime_Blob",
	Nuclear_Hydra = "Moss_Dragon",
	Patient_Zero = "Toxic_Robot",
	Cloud_Viper = "Thunder_Snake",
	Breeze_Boa = "Thunder_Dragon",
	Feather_Krait = "Phoenix",
	Angel_Python = "Golden_Phoenix",
	Seraph_Cobra = "Storm_Hydra",
	Storm_Dragon = "Silver_Flame_King",
	Archangel_Serpent = "Silver_Flame_King",
	Comet_Adder = "Void_Snake",
	Meteor_Python = "Night_Dragon",
	Nebula_Viper = "Eclipse_Dragon",
	Void_Krait = "Galaxy_Queen",
	Star_Naga = "Twin_Shadow",
	Celestial_Ouroboros = "Galaxy_King",
	Rainbow_Ouro = "Galaxy_King",
	Galaxy_Eater = "Galaxy_King",
}

local function hex(s: string): Color3
	local clean = string.gsub(s, "%s", "")
	return Color3.fromHex(clean)
end

local function split(s: string): { string }
	local out = {}
	for w in string.gmatch(s, "[^,]+") do
		table.insert(out, w)
	end
	return out
end

local SnakesConfig: { [string]: SnakeDef } = {}

for _, e in SPECIES do
	local id = e[1] :: string
	local zone = e[3] :: number
	local rarity = RarityConfig.get(R[e[4] :: number])
	local biome = BiomesConfig[zone]
	local weightMul = math.max(1, (16 + biome.GateSpeed ^ 0.65) / 24)
	local baseWeight = math.floor(rarity.BaseWeight * weightMul * 10 + 0.5) / 10
	local body = hex(e[5] :: string)
	local accent = hex(e[6] :: string)
	SnakesConfig[id] = {
		Id = id,
		DisplayName = e[2] :: string,
		Biome = zone,
		Rarity = rarity.Id,
		RarityMult = rarity.RarityMult,
		BaseWeight = baseWeight,
		WeightMin = math.floor(baseWeight * 0.65 * 10 + 0.5) / 10,
		WeightMax = math.floor(baseWeight * 1.6 * 10 + 0.5) / 10,
		BaseIncome = math.floor(rarity.BaseIncome * 2.6 ^ (zone - 1) + 0.5),
		ModelName = id,
		Look = {
			Body = body,
			Accent = accent,
			Belly = body:Lerp(Color3.new(1, 1, 1), 0.55),
			Pattern = e[7] :: string,
			Head = e[8] :: string,
			Extras = split(e[9] :: string),
			Material = e[10] :: string,
			Size = 1 + (rarity.Rank - 1) * 0.07,
		},
	}
end

local Api = {}

-- Id d'une espèce d'avant l'encyclopédie → espèce actuelle (sauvegardes anciennes)
function Api.migrate(id: string): string
	if SnakesConfig[id] then
		return id
	end
	return LEGACY[id] or id
end

function Api.get(id: string): SnakeDef?
	return SnakesConfig[id]
end

function Api.listForBiome(biomeOrder: number): { SnakeDef }
	local out = {}
	for _, def in SnakesConfig do
		if def.Biome == biomeOrder then
			table.insert(out, def)
		end
	end
	table.sort(out, function(a, b)
		return a.Id < b.Id
	end)
	return out
end

function Api.all(): { [string]: SnakeDef }
	return SnakesConfig
end

return Api
