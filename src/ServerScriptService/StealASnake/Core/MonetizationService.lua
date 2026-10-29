--!strict
--[[
	MonetizationService — achats Robux (game passes + produits développeur) et récompenses gratuites.

	Sécurité :
	  - le client n'envoie qu'une CLÉ d'offre ; le serveur résout l'ID et ouvre lui-même l'invite d'achat ;
	  - ProcessReceipt est idempotent (PurchaseId mémorisé dans la sauvegarde) et ne rend PurchaseGranted
	    qu'une fois la sauvegarde effectuée ;
	  - ID = 0 : achat simulé UNIQUEMENT dans Studio (tests), refusé en jeu publié.
	  - limites de fréquence par joueur sur tous les remotes.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.StealASnake.Modules.Network)
local FormatNumber = require(ReplicatedStorage.StealASnake.Modules.FormatNumber)
local M = require(ReplicatedStorage.StealASnake.Config.MonetizationConfig)
local DataManager = require(script.Parent.DataManager)

local MonetizationService = {}

local IS_STUDIO = RunService:IsStudio()
local MAX_RECEIPTS = 100
local root = ReplicatedStorage:WaitForChild("StealASnake")

local lastCall: { [number]: number } = {}
local function throttled(player: Player, gap: number): boolean
	local now = os.clock()
	local last = lastCall[player.UserId]
	if last and now - last < gap then
		return true
	end
	lastCall[player.UserId] = now
	return false
end

--[[ ───────────── Effets ───────────── ]]
local function rawIncome(player: Player): number
	local total = 0
	for _, s in DataManager.get(player).Vivariums do
		if s then
			total += s.Income
		end
	end
	return total
end

function MonetizationService.incomeMult(player: Player): number
	local d = DataManager.get(player)
	return M.incomeMult(d.Passes, d.Boosts, os.time(), d.Premium)
end

function MonetizationService.trainMult(player: Player): number
	local d = DataManager.get(player)
	return M.trainMult(d.Passes, d.Boosts, os.time())
end

function MonetizationService.incomePerSec(player: Player): number
	return rawIncome(player) * MonetizationService.incomeMult(player)
end

function MonetizationService.hasPass(player: Player, key: string): boolean
	return DataManager.get(player).Passes[key] == true
end

function MonetizationService.hasShield(player: Player): boolean
	return (DataManager.get(player).Boosts.Shield or 0) > os.time()
end

function MonetizationService.luckActive(): boolean
	return (root:GetAttribute("ServerLuckUntil") or 0) > os.time()
end

-- Poids d'apparition modifié par la chance serveur
function MonetizationService.luckWeight(rank: number, weight: number): number
	if not MonetizationService.luckActive() then
		return weight
	end
	return weight * (M.LuckWeightMult[rank] or 1)
end

local function addBoost(player: Player, key: string, seconds: number)
	local d = DataManager.get(player)
	local now = os.time()
	d.Boosts[key] = math.max(now, d.Boosts[key] or 0) + seconds
end

local function giveCash(player: Player, amount: number)
	local d = DataManager.get(player)
	d.Cash += amount
	Network.event("VFX"):FireClient(player, "CashBurst", nil)
end

-- Récompense générique : { Minutes, Min } et/ou { Boost, Duration }
local function grantReward(player: Player, r: any, mult: number?): string
	local parts = {}
	local k = mult or 1
	if r.Minutes then
		local amount = M.cashFor(MonetizationService.incomePerSec(player), r.Minutes * 60, r.Min or 0) * k
		giveCash(player, amount)
		table.insert(parts, "+$" .. FormatNumber.short(amount))
	end
	if r.Boost and r.Duration then
		addBoost(player, r.Boost, r.Duration * k)
		local info = M.BoostInfo[r.Boost]
		table.insert(parts, (if info then info.Icon .. " " .. info.Name else r.Boost) .. " " .. math.floor(r.Duration * k / 60) .. " min")
	end
	DataManager.markDirty(player)
	return table.concat(parts, "  ·  ")
end

--[[ ───────────── Tag VIP au-dessus de la tête ───────────── ]]
local function applyTag(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("SAS_VipTag")
	if old then
		old:Destroy()
	end
	if not MonetizationService.hasPass(player, "VIP") then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "SAS_VipTag"
	bb.Size = UDim2.fromOffset(120, 34)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "👑 VIP"
	t.TextScaled = true
	t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	t.TextColor3 = Color3.fromRGB(255, 210, 70)
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Color3.fromRGB(90, 50, 0)
	st.Parent = t
	t.Parent = bb
	bb.Parent = head
end

--[[ ───────────── Achats ───────────── ]]
local function feed(msg: string)
	Network.event("ShopFeed"):FireAllClients(msg)
end

local function grantProduct(player: Player, p: M.Product)
	local d = DataManager.get(player)
	if p.Kind == "Cash" then
		local amount = M.cashFor(MonetizationService.incomePerSec(player), p.CashSeconds or 600, p.CashMin or 0)
		giveCash(player, amount)
		Network.event("Alert"):FireClient(player, "💰 " .. p.Name .. " : +$" .. FormatNumber.short(amount) .. " !")
		if p.Price >= 399 then
			feed("💎 " .. player.DisplayName .. " a acheté " .. p.Name .. " !")
		end
	elseif p.Kind == "Boost" and p.Boost then
		addBoost(player, p.Boost, p.Duration or 600)
		Network.event("Alert"):FireClient(player, p.Icon .. " " .. p.Name .. " activé !")
	elseif p.Kind == "ServerLuck" then
		local now = os.time()
		local untilT = math.max(now, root:GetAttribute("ServerLuckUntil") or 0) + (p.Duration or 900)
		root:SetAttribute("ServerLuckUntil", untilT)
		root:SetAttribute("ServerLuckBy", player.DisplayName)
		feed("🍀 " .. player.DisplayName .. " a activé la CHANCE SERVEUR ! Épiques+ ×2 pour tout le monde !")
	elseif p.Kind == "Starter" then
		d.StarterBought = true
		local amount = M.cashFor(MonetizationService.incomePerSec(player), p.CashSeconds or 3600, p.CashMin or 0)
		giveCash(player, amount)
		addBoost(player, "Money2x", 1800)
		addBoost(player, "Shield", 600)
		Network.event("Alert"):FireClient(player, "🎁 Pack débutant : +$" .. FormatNumber.short(amount) .. " + 2× Argent 30 min + Bouclier !")
		feed("🎁 " .. player.DisplayName .. " a pris le PACK DÉBUTANT !")
	end
	DataManager.markDirty(player)
	DataManager.push(player)
end

local function grantPass(player: Player, p: M.Pass)
	local d = DataManager.get(player)
	if d.Passes[p.Key] then
		return
	end
	d.Passes[p.Key] = true
	applyTag(player)
	Network.event("Alert"):FireClient(player, p.Icon .. " " .. p.Name .. " débloqué, merci !")
	feed(p.Icon .. " " .. player.DisplayName .. " a débloqué " .. p.Name .. " !")
	Network.event("VFX"):FireClient(player, "CashBurst", nil)
	DataManager.push(player)
end

local function onBuy(player: Player, key: any)
	if typeof(key) ~= "string" or #key > 32 or throttled(player, 0.6) then
		return
	end
	local pass = M.pass(key)
	if pass then
		if MonetizationService.hasPass(player, key) then
			return
		end
		if pass.Id == 0 then
			if IS_STUDIO then
				grantPass(player, pass) -- test Studio
			else
				Network.event("Alert"):FireClient(player, "Bientôt disponible !")
			end
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return
	end
	local product = M.product(key)
	if not product then
		return
	end
	local d = DataManager.get(player)
	if product.Kind == "Starter" and (d.StarterBought or os.time() > d.StarterOfferEnds) then
		Network.event("Alert"):FireClient(player, "Cette offre n'est plus disponible.")
		return
	end
	if product.Id == 0 then
		if IS_STUDIO then
			grantProduct(player, product) -- test Studio
		else
			Network.event("Alert"):FireClient(player, "Bientôt disponible !")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player or player:GetAttribute("TutorialStep") == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- pas (encore) chargé : Roblox réessaiera
	end
	local product = M.productById(info.ProductId)
	if not product then
		warn("[StealASnake] produit inconnu " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = DataManager.get(player)
	local pid = tostring(info.PurchaseId)
	if table.find(d.Receipts, pid) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local ok, err = pcall(grantProduct, player, product)
	if not ok then
		warn("[StealASnake] grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(d.Receipts, pid)
	while #d.Receipts > MAX_RECEIPTS do
		table.remove(d.Receipts, 1)
	end
	if not DataManager.saveNow(player) then
		-- accordé en mémoire et mémorisé : un nouvel essai ne le redonnera pas
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--[[ ───────────── Gratuit : quotidien, cadeaux, codes ───────────── ]]
local function today(): number
	return os.time() // 86400
end

local function onDaily(player: Player)
	if throttled(player, 1) then
		return
	end
	local d = DataManager.get(player)
	local day = today()
	if d.DailyLast == day then
		return
	end
	if d.DailyLast == day - 1 then
		d.DailyStreak = (d.DailyStreak % #M.Daily) + 1
	else
		d.DailyStreak = 1
	end
	d.DailyLast = day
	local mult = if MonetizationService.hasPass(player, "VIP") then 2 else 1
	local label = grantReward(player, M.Daily[d.DailyStreak], mult)
	Network.event("Alert"):FireClient(player, "📅 Jour " .. d.DailyStreak .. " : " .. label)
	DataManager.push(player)
end

local function onGift(player: Player, index: any)
	if typeof(index) ~= "number" or throttled(player, 0.5) then
		return
	end
	local g = M.Gifts[index]
	local d = DataManager.get(player)
	if not g or d.GiftsClaimed[index] then
		return
	end
	if os.time() - d.SessionStart < g.At * 60 then
		return
	end
	d.GiftsClaimed[index] = true
	Network.event("Alert"):FireClient(player, "🎁 Cadeau : " .. grantReward(player, g))
	DataManager.push(player)
end

local function onCode(player: Player, code: any): string
	if typeof(code) ~= "string" or #code > 24 or throttled(player, 1.5) then
		return "Patiente un instant…"
	end
	local key = string.upper((string.gsub(code, "%s", "")))
	local c = M.Codes[key]
	if not c then
		return "❌ Code invalide"
	end
	local d = DataManager.get(player)
	if d.Codes[key] then
		return "Code déjà utilisé"
	end
	d.Codes[key] = true
	local label = grantReward(player, c)
	DataManager.push(player)
	return "✅ " .. label
end

--[[ ───────────── Démarrage ───────────── ]]
local function setupPlayer(player: Player)
	-- attendre la fin du chargement DataStore (DataManager.push pose TutorialStep)
	local t0 = os.clock()
	while player.Parent and player:GetAttribute("TutorialStep") == nil and os.clock() - t0 < 30 do
		task.wait(0.2)
	end
	if not player.Parent then
		return
	end
	local d = DataManager.get(player)
	d.SessionStart = os.time()
	d.GiftsClaimed = {}
	d.Premium = player.MembershipType == Enum.MembershipType.Premium
	if d.StarterOfferEnds == 0 then
		d.StarterOfferEnds = os.time() + M.StarterWindow
		DataManager.markDirty(player)
	end
	for _, p in M.Passes do
		if p.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.Id)
			end)
			if ok and owns then
				d.Passes[p.Key] = true
			end
		end
	end
	applyTag(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 5)
		applyTag(player)
	end)
	DataManager.push(player)
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local p = M.passById(passId)
			if p then
				grantPass(player, p)
			end
		end
	end)
	Players.PlayerMembershipChanged:Connect(function(player)
		DataManager.get(player).Premium = player.MembershipType == Enum.MembershipType.Premium
		DataManager.push(player)
	end)

	Network.event("ShopBuy").OnServerEvent:Connect(onBuy)
	Network.event("ClaimDaily").OnServerEvent:Connect(onDaily)
	Network.event("ClaimGift").OnServerEvent:Connect(onGift)
	Network.func("RedeemCode").OnServerInvoke = onCode

	Players.PlayerAdded:Connect(setupPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(setupPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player.UserId] = nil
	end)
end

return MonetizationService
