--!strict
local Workspace = game:GetService("Workspace")

local BiomesConfig = require(game.ReplicatedStorage.StealASnake.Config.BiomesConfig)
local SnakesConfig = require(game.ReplicatedStorage.StealASnake.Config.SnakesConfig)
local MutationsConfig = require(game.ReplicatedStorage.StealASnake.Config.MutationsConfig)
local ModelFactory = require(game.ServerStorage.StealASnake.Templates.ModelFactory)
local CarrySystem = require(script.Parent.Parent.Core.CarrySystem)
local VFXFactory = require(game.ReplicatedStorage.StealASnake.Modules.VFXFactory)
local FormatNumber = require(game.ReplicatedStorage.StealASnake.Modules.FormatNumber)
local SpeedCalculator = require(game.ReplicatedStorage.StealASnake.Modules.SpeedCalculator)

local NestSpawner = {}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 195, 205),
	Uncommon = Color3.fromRGB(90, 220, 110),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
}
local RARITY_FR: { [string]: string } = {
	Common = "Commun",
	Uncommon = "Peu commun",
	Rare = "Rare",
	Epic = "Épique",
	Legendary = "Légendaire",
	Mythic = "Mythique",
}
local folder: Folder? = nil

local function wildFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "WildSnakes"
	folder.Parent = Workspace
	return folder
end

local function countInBiome(biomeId: string): number
	local n = 0
	for _, m in wildFolder():GetChildren() do
		if m:GetAttribute("BiomeId") == biomeId then
			n += 1
		end
	end
	return n
end

-- Poids d'apparition par rareté (RNG pondérée) : plus c'est rare, moins ça sort.
local RARITY_SPAWN_WEIGHT: { [string]: number } = {
	Common = 100,
	Uncommon = 55,
	Rare = 25,
	Epic = 10,
	Legendary = 3,
	Mythic = 1,
}

local function pickSpecies(biomeOrder: number): string
	local list = SnakesConfig.listForBiome(biomeOrder)
	if #list == 0 then
		return "Viper_Green"
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id -- ordre stable (itération de table non déterministe)
	end)
	local total = 0
	for _, def in list do
		total += RARITY_SPAWN_WEIGHT[def.Rarity] or 10
	end
	local roll = math.random() * total
	for _, def in list do
		roll -= RARITY_SPAWN_WEIGHT[def.Rarity] or 10
		if roll <= 0 then
			return def.Id
		end
	end
	return list[#list].Id
end

function NestSpawner.spawnAt(biomeCfg: any, spawnPart: BasePart)
	if countInBiome(biomeCfg.Id) >= 10 then
		return
	end
	local speciesId = pickSpecies(biomeCfg.Order)
	local def = SnakesConfig.get(speciesId)
	if not def then
		return
	end
	local mutation = MutationsConfig.roll()
	local weight = def.WeightMin + math.random() * (def.WeightMax - def.WeightMin)
	local model = ModelFactory.coiledSnake(def.ModelName, 0.9 + math.random() * 0.4)
	model:SetAttribute("SpeciesId", speciesId)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Weight", weight)
	model:SetAttribute("BiomeId", biomeCfg.Id)
	model:SetAttribute("IsWild", true)
	-- posé sur le nid (bas du modèle au point d'apparition), tête tournée vers l'extérieur
	local _, msize = model:GetBoundingBox()
	model:PivotTo(spawnPart.CFrame * CFrame.new(0, msize.Y / 2 - 0.3, 0))
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end

	VFXFactory.applyMutation(model, mutation, nil)

	local mutDef = MutationsConfig.Defs[mutation] or MutationsConfig.Defs.Normal
	local incomePreview = SpeedCalculator.income(def.BaseIncome, def.RarityMult, weight, def.BaseWeight, mutDef.Multiplier, 1)

	-- Étiquette 3 lignes : [MUTATION] Nom (couleur mutation) · Rareté (couleur rareté) · poids | revenu
	local _, bbSize = model:GetBoundingBox()
	local bb = Instance.new("BillboardGui")
	bb.Name = "SnakeBillboard"
	bb.Size = UDim2.fromOffset(190, 66)
	bb.StudsOffsetWorldSpace = Vector3.new(0, bbSize.Y / 2 + 1.6, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 28 -- lisible en s'approchant du nid, sans empiler toutes les étiquettes
	bb.LightInfluence = 0
	bb.Parent = model.PrimaryPart
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
	card.BackgroundTransparency = 0.25
	card.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card
	local rarityColor = RARITY_COLORS[def.Rarity] or Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke")
	st.Color = rarityColor
	st.Thickness = 2
	st.Parent = card
	local lines = {
		{ if mutation == "Normal" then def.DisplayName else ("✨ [" .. string.upper(mutDef.DisplayName) .. "] " .. def.DisplayName), if mutation == "Normal" then Color3.new(1, 1, 1) else mutDef.Color, 0.36 },
		{ RARITY_FR[def.Rarity] or def.Rarity, rarityColor, 0.28 },
		{ string.format("⚖️ %.1f kg  ·  💰 $%s/s", weight, FormatNumber.short(incomePreview)), Color3.fromRGB(200, 255, 200), 0.3 },
	}
	local y = 0.03
	for _, l in lines do
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Position = UDim2.fromScale(0.04, y)
		tl.Size = UDim2.fromScale(0.92, l[3])
		tl.Text = l[1]
		tl.TextColor3 = l[2]
		tl.TextScaled = true
		tl.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
		tl.Parent = card
		local ts = Instance.new("UIStroke")
		ts.Thickness = 1.5
		ts.Parent = tl
		y += l[3] + 0.01
	end

	model.Parent = wildFolder()

	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			CarrySystem.steal(player, model)
		end)
	end
end

function NestSpawner.start()
	task.spawn(function()
		while true do
			local biomes = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Biomes")
			if biomes then
				for _, cfg in BiomesConfig do
					local biome = biomes:FindFirstChild(cfg.Id)
					local nest = biome and biome:FindFirstChild("Nest")
					local sps = nest and nest:FindFirstChild("SpawnPoints")
					if sps then
						local points = sps:GetChildren()
						if #points > 0 and countInBiome(cfg.Id) < 8 then
							local sp = points[math.random(1, #points)]
							if sp:IsA("BasePart") then
								NestSpawner.spawnAt(cfg, sp)
							end
						end
					end
				end
			end
			task.wait(4)
		end
	end)
end

return NestSpawner
