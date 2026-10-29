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
local MonetizationService = require(script.Parent.Parent.Core.MonetizationService)
local RarityConfig = require(game.ReplicatedStorage.StealASnake.Config.RarityConfig)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)

local NestSpawner = {}

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

-- Plafond de serpents sauvages par zone (perf : 15 zones × 8 serpents procéduraux)
local MAX_PER_BIOME = 8
local REFILL_BELOW = 6

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
		local r = RarityConfig.get(def.Rarity)
		total += MonetizationService.luckWeight(r.Rank, r.SpawnWeight)
	end
	local roll = math.random() * total
	for _, def in list do
		local r = RarityConfig.get(def.Rarity)
		roll -= MonetizationService.luckWeight(r.Rank, r.SpawnWeight)
		if roll <= 0 then
			return def.Id
		end
	end
	return list[#list].Id
end

function NestSpawner.spawnAt(biomeCfg: any, spawnPart: BasePart)
	if countInBiome(biomeCfg.Id) >= MAX_PER_BIOME then
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

	-- Étiquette « bonbon » (style UIKit) : bandeau de rareté, nom contouré, pastilles poids / revenu
	local _, bbSize = model:GetBoundingBox()
	local rarityColor = RarityConfig.color(def.Rarity)
	local INK = Color3.fromRGB(14, 10, 28)
	local FREDOKA = Font.new("rbxasset://fonts/families/FredokaOne.json")
	local bb = Instance.new("BillboardGui")
	bb.Name = "SnakeBillboard"
	bb.Size = UDim2.fromOffset(210, 92)
	bb.StudsOffsetWorldSpace = Vector3.new(0, bbSize.Y / 2 + 2, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 30 -- lisible en s'approchant du nid, sans empiler toutes les étiquettes
	bb.LightInfluence = 0
	bb.Parent = model.PrimaryPart
	local function stroke(inst: Instance, th: number, border: boolean)
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = th
		st.LineJoinMode = Enum.LineJoinMode.Round
		if border then
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		end
		st.Parent = inst
	end
	local function rounded(inst: Instance, r: number)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r)
		c.Parent = inst
	end
	local function txt(parent: Instance, text: string, color: Color3, pos: UDim2, size: UDim2)
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Position = pos
		tl.Size = size
		tl.Text = text
		tl.TextColor3 = color
		tl.TextScaled = true
		tl.FontFace = FREDOKA
		tl.Parent = parent
		stroke(tl, 2, false)
		return tl
	end
	-- nom (mutation incluse)
	local nameText = if mutation == "Normal" then def.DisplayName else ("✨ " .. mutDef.DisplayName .. " " .. def.DisplayName)
	txt(bb, nameText, if mutation == "Normal" then Color3.new(1, 1, 1) else mutDef.Color:Lerp(Color3.new(1, 1, 1), 0.25), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.34))
	-- pastille de rareté
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.36)
	pill.Size = UDim2.fromScale(0.6, 0.26)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = bb
	rounded(pill, 99)
	stroke(pill, 2.5, true)
	local pg = Instance.new("UIGradient")
	pg.Color = ColorSequence.new(rarityColor:Lerp(Color3.new(1, 1, 1), 0.3), Color3.new(rarityColor.R * 0.6, rarityColor.G * 0.6, rarityColor.B * 0.6))
	pg.Rotation = 90
	pg.Parent = pill
	txt(pill, RarityConfig.name(def.Rarity), Color3.new(1, 1, 1), UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.84))
	-- poids · revenu
	local stats = Instance.new("Frame")
	stats.AnchorPoint = Vector2.new(0.5, 0)
	stats.Position = UDim2.fromScale(0.5, 0.66)
	stats.Size = UDim2.fromScale(0.96, 0.32)
	stats.BackgroundColor3 = Color3.fromRGB(28, 22, 50)
	stats.BackgroundTransparency = 0.15
	stats.Parent = bb
	rounded(stats, 99)
	stroke(stats, 2, true)
	txt(stats, string.format("⚖️ %.1f kg   💰 $%s/s", weight, FormatNumber.short(incomePreview)), Color3.fromRGB(190, 255, 190), UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.8))

	model.Parent = wildFolder()

	-- Annonce serveur pour les raretés Légendaire / Mythique / Secret (comme les œufs secrets de Steal An Egg)
	local rarity = RarityConfig.get(def.Rarity)
	if rarity.Announce then
		local mutText = if mutation == "Normal" then "" else " " .. mutDef.DisplayName
		Network.event("Alert"):FireAllClients(string.format("✨ %s : %s%s est apparu dans %s !", rarity.DisplayName, def.DisplayName, mutText, biomeCfg.Name))
	end

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
						if #points > 0 and countInBiome(cfg.Id) < REFILL_BELOW then
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
