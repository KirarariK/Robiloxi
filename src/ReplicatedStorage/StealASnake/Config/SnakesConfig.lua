--!strict
--[[
	SnakesConfig — 110 espèces réparties dans les 15 zones (7 raretés, dont 1 Secret par zone).

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
	-- 1 · Jungle Émeraude
	{ "Viper_Green", "Vipère Verte", 1, 1, "2EA84A", "6FE36A", "Stripes", "Viper", "", "Smooth" },
	{ "Leaf_Viper", "Vipère Feuille", 1, 1, "4FBF3A", "1E6E2A", "Diamonds", "Viper", "Leaves", "Smooth" },
	{ "Emerald_Boa", "Boa Émeraude", 1, 2, "0F9D58", "E8F5A0", "Bands", "Round", "", "Smooth" },
	{ "Jungle_Krait", "Krait Jungle", 1, 2, "1B1B1B", "F2E14C", "Rings", "Round", "", "Smooth" },
	{ "Python_Royal", "Python Royal", 1, 3, "8C5A23", "DCAA46", "Spots", "Round", "", "Smooth" },
	{ "Moss_Python", "Python Mousse", 1, 3, "5E7D3A", "9CCB5A", "Spots", "Round", "Leaves", "Velvet" },
	{ "Liana_Boa", "Boa Liane", 1, 4, "6B8E23", "A0522D", "Bands", "Crest", "Leaves,Flowers", "Smooth" },
	{ "Orchid_Viper", "Vipère Orchidée", 1, 5, "E07BE0", "FFFFFF", "Spots", "Crest", "Flowers,Sparkle", "Smooth" },
	{ "Jaguar_Python", "Python Jaguar", 1, 6, "F0B030", "2A1A0A", "Spots", "Mane", "Tusks", "Velvet" },
	{ "Ancient_Emerald", "Émeraude Ancestrale", 1, 7, "00FF88", "FFD700", "Glow", "Crown", "Halo,Sparkle", "Glass" },
	-- 2 · Désert des Dunes
	{ "Sand_Asp", "Aspic des Sables", 2, 1, "D8B470", "A07840", "Bands", "Viper", "", "Smooth" },
	{ "Scarab_Viper", "Vipère Scarabée", 2, 1, "2C5F6F", "7FD1C9", "Diamonds", "Viper", "", "Foil" },
	{ "Dune_Sidewinder", "Sidewinder", 2, 2, "E2C48A", "8A6A3A", "Diamonds", "Horned", "", "Smooth" },
	{ "Horned_Rattler", "Crotale Cornu", 2, 3, "B4783A", "E6A046", "Diamonds", "Horned", "Rattle", "Smooth" },
	{ "Cobra_Royal", "Cobra Royal", 2, 4, "C8962A", "F5D246", "Bands", "Cobra", "", "Smooth" },
	{ "Pharaoh_Asp", "Aspic Pharaon", 2, 5, "1E3A8A", "FFD24A", "Bands", "Cobra", "Halo", "Foil" },
	{ "Mirage_Cobra", "Cobra Mirage", 2, 6, "FFB36B", "FF5E9A", "Glow", "Cobra", "Sparkle", "Glass" },
	{ "Sphinx_Serpent", "Serpent Sphinx", 2, 7, "E8C27A", "3B2A12", "Rings", "Crown", "Wings,Halo", "Marble" },
	-- 3 · Marais Venimeux
	{ "Bog_Adder", "Vipère du Marais", 3, 1, "4E5D3A", "8EA05A", "Spots", "Viper", "", "Smooth" },
	{ "Toxic_Mamba", "Mamba Toxique", 3, 2, "7CFF3A", "1A3A0A", "Stripes", "Viper", "Bubbles", "Neon" },
	{ "Mire_Moccasin", "Mocassin des Tourbières", 3, 3, "3A3226", "C8B48A", "Bands", "Round", "Bubbles", "Slate" },
	{ "Anaconda_Spiked", "Anaconda Épineux", 3, 4, "46783A", "8C32AA", "Spots", "Horned", "Spikes", "Smooth" },
	{ "Swamp_Hydra", "Hydre Marécage", 3, 5, "2F5A3A", "B4FF5A", "Stripes", "Hydra", "Spikes", "Smooth" },
	{ "Witch_Serpent", "Serpent Sorcière", 3, 6, "4B1E6E", "9CFF3A", "Glow", "Crown", "Mushrooms,Sparkle", "Velvet" },
	{ "Croak_Basilisk", "Basilic Croassant", 3, 7, "1E2E1E", "FF3A3A", "Rings", "Skull", "Spikes,Bones", "Slate" },
	-- 4 · Toundra Gelée
	{ "Frost_Adder", "Vipère Givrée", 4, 1, "BFE4F5", "5AA0D2", "Bands", "Viper", "Frost", "Smooth" },
	{ "Snow_Python", "Python des Neiges", 4, 2, "F5FAFF", "9AA8B8", "Spots", "Round", "", "Velvet" },
	{ "Glacier_Krait", "Krait Glaciaire", 4, 3, "4FA0D8", "E6F7FF", "Rings", "Round", "Frost", "Ice" },
	{ "Aurora_Boa", "Boa Aurore", 4, 4, "3AE0B4", "B45AFF", "Glow", "Crest", "Sparkle", "Neon" },
	{ "Yeti_Cobra", "Cobra Yéti", 4, 5, "E8EEF2", "6A7A8A", "Solid", "Cobra", "Tusks,Frost", "Velvet" },
	{ "Blizzard_Wyrm", "Wyrm Blizzard", 4, 6, "9AD8FF", "FFFFFF", "Stripes", "Horned", "Wings,Frost", "Ice" },
	{ "Frozen_Heart", "Cœur Gelé", 4, 7, "D2F4FF", "00B4FF", "Glow", "Crown", "Crystals,Halo", "Glass" },
	-- 5 · Bambouseraie Brumeuse
	{ "Bamboo_Viper", "Vipère Bambou", 5, 1, "8DBE3A", "3A6A1A", "Bands", "Viper", "Leaves", "Smooth" },
	{ "Lotus_Snake", "Serpent Lotus", 5, 2, "FFB4D2", "FFFFFF", "Spots", "Round", "Flowers", "Smooth" },
	{ "Panda_Python", "Python Panda", 5, 3, "F2F2F2", "1A1A1A", "Bands", "Round", "", "Velvet" },
	{ "Lantern_Krait", "Krait Lanterne", 5, 4, "D2281E", "FFC83A", "Rings", "Crest", "Sparkle", "Neon" },
	{ "Jade_Naga", "Naga de Jade", 5, 5, "3AB48C", "E6D28C", "Diamonds", "Mane", "Halo", "Glass" },
	{ "Lunar_Dragon", "Dragon Lunaire", 5, 6, "E6E6FF", "C83232", "Stripes", "Mane", "Antlers", "Marble" },
	{ "Spirit_Koi", "Serpent Koï Esprit", 5, 7, "FF8C3A", "FFFFFF", "Spots", "Crest", "Fins,Ghost", "Glass" },
	-- 6 · Canyon Rouge
	{ "Dust_Racer", "Coureur de Poussière", 6, 1, "C88250", "8A5030", "Stripes", "Viper", "", "Smooth" },
	{ "Red_Rattler", "Crotale Rouge", 6, 2, "B4462A", "F0C896", "Diamonds", "Horned", "Rattle", "Smooth" },
	{ "Mesa_Kingsnake", "Serpent-Roi Mesa", 6, 3, "D2321E", "F0F0F0", "Rings", "Round", "", "Smooth" },
	{ "Bandit_Cobra", "Cobra Bandit", 6, 4, "3A3A3A", "D2321E", "Bands", "Cobra", "", "Slate" },
	{ "Thunder_Rattler", "Crotale Tonnerre", 6, 5, "FFD23A", "3A5AFF", "Glow", "Horned", "Rattle,Sparkle", "Neon" },
	{ "Gold_Rush_Python", "Python Ruée vers l'Or", 6, 6, "FFC83A", "8A5A1A", "Spots", "Round", "Sparkle", "Foil" },
	{ "Canyon_Phantom", "Fantôme du Canyon", 6, 7, "F0B48C", "FFFFFF", "Glow", "Skull", "Ghost,Bones", "Glass" },
	-- 7 · Forêt Champignon
	{ "Spore_Adder", "Vipère Spore", 7, 1, "8A5AA0", "F0C8E6", "Spots", "Viper", "Mushrooms", "Smooth" },
	{ "Truffle_Boa", "Boa Truffe", 7, 2, "5A3A2A", "C8A078", "Spots", "Round", "", "Velvet" },
	{ "Glowcap_Viper", "Vipère Lumicap", 7, 3, "2A1E46", "5AFFC8", "Glow", "Crest", "Mushrooms", "Neon" },
	{ "Fungal_Hydra", "Hydre Fongique", 7, 4, "B43A5A", "FFF0C8", "Spots", "Hydra", "Mushrooms", "Smooth" },
	{ "Myco_Naga", "Naga Myco", 7, 5, "6A3AB4", "FF5AA0", "Stripes", "Mane", "Mushrooms,Sparkle", "Velvet" },
	{ "Toadstool_King", "Roi Amanite", 7, 6, "E61E1E", "FFFFFF", "Spots", "Crown", "Mushrooms,Halo", "Smooth" },
	{ "Mycelium_Mind", "Esprit Mycélien", 7, 7, "C8F0FF", "B45AFF", "Glow", "Crest", "Mushrooms,Ghost", "Glass" },
	-- 8 · Récif Corallien
	{ "Sea_Krait", "Tricot Rayé", 8, 1, "3A8CC8", "1A1A2A", "Rings", "Round", "Fins", "Smooth" },
	{ "Clownfish_Snake", "Serpent Poisson-Clown", 8, 2, "FF7A1E", "FFFFFF", "Bands", "Round", "Fins", "Smooth" },
	{ "Coral_Viper", "Vipère Corail", 8, 3, "FF6E8C", "FFD2A0", "Spots", "Viper", "Spikes", "Smooth" },
	{ "Eel_Serpent", "Serpent Anguille", 8, 4, "2A5A46", "8CFFC8", "Glow", "Crest", "Fins,Bubbles", "Neon" },
	{ "Pearl_Naga", "Naga Perle", 8, 5, "F0E6F5", "A0C8FF", "Solid", "Crown", "Bubbles,Sparkle", "Marble" },
	{ "Kraken_Serpent", "Serpent Kraken", 8, 6, "6A1E5A", "FF8CB4", "Spots", "Hydra", "Tusks,Fins", "Smooth" },
	{ "Atlantis_Leviathan", "Léviathan d'Atlantide", 8, 7, "1E6EFF", "5AFFFF", "Glow", "Crown", "Fins,Halo", "Glass" },
	-- 9 · Caldeira Volcanique
	{ "Ash_Cobra", "Cobra de Cendre", 9, 1, "5A5050", "A0968C", "Bands", "Cobra", "", "Slate" },
	{ "Cinder_Viper", "Vipère Braise", 9, 2, "3A2A28", "FF7A1E", "Stripes", "Viper", "Lava", "Slate" },
	{ "Lava_Python", "Python de Lave", 9, 3, "8C1E0A", "FFA03A", "Glow", "Round", "Lava", "Neon" },
	{ "Obsidian_Asp", "Aspic Obsidienne", 9, 4, "141414", "B45AFF", "Diamonds", "Viper", "Crystals", "Glass" },
	{ "Magma_Serpent", "Serpent de Magma", 9, 5, "5A190F", "F55A14", "Glow", "Horned", "Flames,Lava", "Slate" },
	{ "Phoenix_Serpent", "Serpent Phénix", 9, 6, "FF5A1E", "FFD23A", "Glow", "Crest", "Wings,Flames", "Neon" },
	{ "Volcano_Heart", "Cœur de Volcan", 9, 7, "FF2A00", "FFFF5A", "Glow", "Crown", "Flames,Halo", "Neon" },
	-- 10 · Grotte de Cristal
	{ "Quartz_Viper", "Vipère Quartz", 10, 1, "F0F0FF", "C8C8E6", "Diamonds", "Viper", "Crystals", "Glass" },
	{ "Amethyst_Boa", "Boa Améthyste", 10, 2, "9A5AD2", "E6C8FF", "Diamonds", "Round", "Crystals", "Glass" },
	{ "Geode_Python", "Python Géode", 10, 3, "6E5A50", "5AC8FF", "Spots", "Round", "Crystals", "Slate" },
	{ "Prism_Krait", "Krait Prisme", 10, 4, "FFFFFF", "FF5AC8", "Rings", "Crest", "Crystals,Sparkle", "Glass" },
	{ "Diamond_Cobra", "Cobra Diamant", 10, 5, "C8F5FF", "FFFFFF", "Glow", "Cobra", "Crystals,Sparkle", "Glass" },
	{ "Crystal_Serpent", "Serpent Cristal", 10, 6, "5AE6FF", "E65AFF", "Glow", "Horned", "Crystals,Halo", "Glass" },
	{ "Opal_Eternal", "Opale Éternelle", 10, 7, "FFE6F5", "5AFFE6", "Glow", "Crown", "Crystals,Wings", "Glass" },
	-- 11 · Cimetière Hanté
	{ "Bone_Adder", "Vipère d'Os", 11, 1, "E6DCC8", "8C8278", "Rings", "Skull", "Bones", "Marble" },
	{ "Grave_Python", "Python des Tombes", 11, 2, "46464E", "8C8C96", "Spots", "Round", "", "Slate" },
	{ "Wisp_Viper", "Vipère Feu-Follet", 11, 3, "5AFFB4", "1E3A2E", "Glow", "Viper", "Ghost", "Neon" },
	{ "Lich_Cobra", "Cobra Liche", 11, 4, "2A1E3A", "5AFF8C", "Bands", "Cobra", "Bones,Halo", "Velvet" },
	{ "Banshee_Serpent", "Serpent Banshee", 11, 5, "D2F0FF", "5A8CFF", "Glow", "Mane", "Ghost", "Glass" },
	{ "Reaper_Naga", "Naga Faucheuse", 11, 6, "1A1A1E", "B4FFE6", "Solid", "Skull", "Wings,Bones", "Velvet" },
	{ "Headless_Horror", "L'Horreur Sans-Tête", 11, 7, "0A0A0A", "FF6E00", "Glow", "Skull", "Flames,Ghost", "Slate" },
	-- 12 · Temple Aztèque
	{ "Glyph_Viper", "Vipère Glyphe", 12, 1, "B49A5A", "3A6E5A", "Diamonds", "Viper", "", "Smooth" },
	{ "Sun_Python", "Python Solaire", 12, 2, "FFB43A", "C8461E", "Bands", "Round", "Halo", "Smooth" },
	{ "Idol_Serpent", "Serpent Idole", 12, 3, "3AA078", "FFD23A", "Diamonds", "Crest", "", "Marble" },
	{ "Feathered_Boa", "Boa à Plumes", 12, 4, "1EB48C", "FF3A3A", "Stripes", "Crest", "Feathers", "Velvet" },
	{ "Gold_Mask_Cobra", "Cobra Masque d'Or", 12, 5, "FFD23A", "1E1E1E", "Solid", "Cobra", "Feathers,Sparkle", "Foil" },
	{ "Quetzal_Sovereign", "Souverain Quetzal", 12, 6, "00C88C", "FF5A1E", "Glow", "Mane", "Wings,Feathers", "Velvet" },
	{ "El_Dorado", "El Dorado", 12, 7, "FFE65A", "FFFFFF", "Glow", "Crown", "Wings,Halo,Sparkle", "Foil" },
	-- 13 · Terres Toxiques
	{ "Sludge_Adder", "Vipère Boue", 13, 1, "5A6E3A", "B4FF3A", "Spots", "Viper", "Bubbles", "Smooth" },
	{ "Barrel_Python", "Python Baril", 13, 2, "E6C81E", "1E1E1E", "Bands", "Round", "", "Smooth" },
	{ "Mutant_Krait", "Krait Mutant", 13, 3, "8CFF1E", "6A1EB4", "Rings", "Horned", "Spikes", "Neon" },
	{ "Two_Headed_Viper", "Vipère à Deux Têtes", 13, 4, "3A5A1E", "C8FF5A", "Stripes", "Hydra", "", "Smooth" },
	{ "Rad_Cobra", "Cobra Radioactif", 13, 5, "1E1E1E", "C8FF1E", "Glow", "Cobra", "Bubbles,Sparkle", "Neon" },
	{ "Nuclear_Hydra", "Hydre Nucléaire", 13, 6, "B4FF1E", "1E3A0A", "Glow", "Hydra", "Spikes,Bubbles", "Neon" },
	{ "Patient_Zero", "Patient Zéro", 13, 7, "C8C8C8", "5AFF1E", "Glow", "Skull", "Spikes,Ghost", "Glass" },
	-- 14 · Royaume Céleste
	{ "Cloud_Viper", "Vipère Nuage", 14, 1, "F5F5FF", "B4C8FF", "Spots", "Viper", "", "Velvet" },
	{ "Breeze_Boa", "Boa Brise", 14, 2, "B4E6FF", "FFFFFF", "Stripes", "Round", "Feathers", "Smooth" },
	{ "Feather_Krait", "Krait Plume", 14, 3, "FFE6B4", "FFB43A", "Rings", "Crest", "Feathers", "Velvet" },
	{ "Angel_Python", "Python Ange", 14, 4, "FFFFFF", "FFD23A", "Solid", "Round", "Wings,Halo", "Marble" },
	{ "Seraph_Cobra", "Cobra Séraphin", 14, 5, "FFF0C8", "FFB43A", "Glow", "Cobra", "Wings,Halo", "Foil" },
	{ "Storm_Dragon", "Dragon de l'Orage", 14, 6, "3A4AA0", "FFFF5A", "Stripes", "Mane", "Wings,Sparkle", "Neon" },
	{ "Archangel_Serpent", "Serpent Archange", 14, 7, "FFFFFF", "5AE6FF", "Glow", "Crown", "Wings,Halo,Sparkle", "Glass" },
	-- 15 · Néant Cosmique
	{ "Comet_Adder", "Vipère Comète", 15, 1, "2A2A5A", "8CC8FF", "Stripes", "Viper", "Stars", "Smooth" },
	{ "Meteor_Python", "Python Météore", 15, 2, "5A463A", "FF8C3A", "Spots", "Round", "Flames", "Slate" },
	{ "Nebula_Viper", "Vipère Nébuleuse", 15, 3, "5A3AB4", "FF5AC8", "Glow", "Viper", "Stars", "Neon" },
	{ "Void_Krait", "Krait du Vide", 15, 4, "0A0A14", "8C5AFF", "Rings", "Crest", "Stars", "Glass" },
	{ "Star_Naga", "Naga Stellaire", 15, 5, "1E2A6E", "FFFFFF", "Spots", "Mane", "Stars,Halo", "Neon" },
	{ "Celestial_Ouroboros", "Serpent Céleste", 15, 6, "283796", "8CC8FF", "Glow", "Horned", "Stars,Wings", "Neon" },
	{ "Rainbow_Ouro", "Ouro Arc-en-ciel", 15, 6, "FF5A5A", "5AFFFF", "Glow", "Crest", "Stars,Sparkle", "Neon" },
	{ "Galaxy_Eater", "Dévoreur de Galaxies", 15, 7, "000000", "B45AFF", "Glow", "Hydra", "Stars,Halo,Wings", "Glass" },
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
