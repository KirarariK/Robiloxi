--!strict
--[[
	MonetizationConfig — boutique Steal A Snake (game passes, produits développeur, récompenses gratuites).

	⚠️ IDs : remplace chaque `Id = 0` par l'ID créé sur le Creator Hub
	   (create.roblox.com → ton expérience → Monetization → Passes / Developer Products).
	   Tant qu'un ID vaut 0 : en Studio l'achat est SIMULÉ (pour tester), en jeu publié il affiche « bientôt ».

	Choix (étude marché Roblox 2025-2026, Steal a Brainrot / Grow a Garden / Pet Sim) :
	  - passes permanents à fort volume : 2× Argent, VIP, Auto-collecte, Entraînement 2× ;
	  - produits répétables : boosts temporaires, CHANCE SERVEUR (achat visible par tout le serveur),
	    packs d'argent indexés sur le revenu du joueur (restent utiles à tout niveau) ;
	  - pack de démarrage très rentable, limité 24 h, achetable une seule fois ;
	  - rétention gratuite : récompense quotidienne (série 7 j), cadeaux de temps de jeu, codes, bonus Premium.
]]

export type Pass = {
	Key: string,
	Id: number,
	Name: string,
	Icon: string,
	Desc: string,
	Price: number,
	Color: Color3,
	Tag: string?,
}

export type Product = {
	Key: string,
	Id: number,
	Name: string,
	Icon: string,
	Desc: string,
	Price: number,
	Color: Color3,
	Kind: string, -- "Boost" | "Cash" | "ServerLuck" | "Starter"
	Boost: string?, -- clé de boost (Money2x, Shield, Train2x)
	Duration: number?, -- secondes
	CashSeconds: number?, -- packs : secondes de revenu offertes
	CashMin: number?, -- packs : minimum garanti
	Tag: string?,
}

local M = {}

M.Passes = {
	{ Key = "Money2x", Id = 0, Name = "2× ARGENT", Icon = "💰", Desc = "Double TOUT ton revenu, pour toujours.", Price = 399, Color = Color3.fromRGB(70, 210, 100), Tag = "POPULAIRE" },
	{ Key = "VIP", Id = 0, Name = "VIP", Icon = "👑", Desc = "+25% revenu, tag doré, récompenses quotidiennes ×2.", Price = 249, Color = Color3.fromRGB(255, 195, 50) },
	{ Key = "AutoCollect", Id = 0, Name = "AUTO-COLLECTE", Icon = "🧲", Desc = "Ton argent arrive tout seul, même loin de ta base.", Price = 149, Color = Color3.fromRGB(80, 170, 255) },
	{ Key = "Train2x", Id = 0, Name = "ENTRAÎNEMENT 2×", Icon = "⚡", Desc = "Les tapis donnent 2× plus de vitesse.", Price = 199, Color = Color3.fromRGB(255, 120, 60) },
} :: { Pass }

M.Products = {
	{ Key = "Starter", Id = 0, Name = "PACK DÉBUTANT", Icon = "🎁", Desc = "1 h de revenu + 2× Argent 30 min + Bouclier 10 min.", Price = 99, Color = Color3.fromRGB(255, 90, 170), Kind = "Starter", CashSeconds = 3600, CashMin = 25000, Tag = "−80%" },
	{ Key = "ServerLuck", Id = 0, Name = "CHANCE SERVEUR", Icon = "🍀", Desc = "15 min : serpents Épiques+ ×2 pour TOUT le serveur.", Price = 149, Color = Color3.fromRGB(80, 230, 140), Kind = "ServerLuck", Duration = 900, Tag = "TOUT LE SERVEUR" },
	{ Key = "Boost2x", Id = 0, Name = "BOOST 2× ARGENT", Icon = "💸", Desc = "Double ton revenu pendant 15 min (cumulable).", Price = 49, Color = Color3.fromRGB(90, 220, 120), Kind = "Boost", Boost = "Money2x", Duration = 900 },
	{ Key = "Shield", Id = 0, Name = "BOUCLIER", Icon = "🛡️", Desc = "5 min : les gardiens t'ignorent complètement.", Price = 39, Color = Color3.fromRGB(110, 190, 255), Kind = "Boost", Boost = "Shield", Duration = 300 },
	{ Key = "TrainBoost", Id = 0, Name = "TURBO TAPIS", Icon = "🏃", Desc = "Entraînement 3× pendant 10 min.", Price = 29, Color = Color3.fromRGB(255, 140, 70), Kind = "Boost", Boost = "Train3x", Duration = 600 },
	{ Key = "CashS", Id = 0, Name = "SAC D'ARGENT", Icon = "💵", Desc = "10 min de revenu instantané.", Price = 25, Color = Color3.fromRGB(120, 210, 120), Kind = "Cash", CashSeconds = 600, CashMin = 2500 },
	{ Key = "CashM", Id = 0, Name = "COFFRE D'ARGENT", Icon = "💰", Desc = "1 h de revenu instantané.", Price = 99, Color = Color3.fromRGB(90, 220, 110), Kind = "Cash", CashSeconds = 3600, CashMin = 15000, Tag = "POPULAIRE" },
	{ Key = "CashL", Id = 0, Name = "TRÉSOR", Icon = "🏆", Desc = "6 h de revenu instantané.", Price = 399, Color = Color3.fromRGB(255, 200, 60), Kind = "Cash", CashSeconds = 21600, CashMin = 90000, Tag = "MEILLEURE OFFRE" },
	{ Key = "CashXL", Id = 0, Name = "MONTAGNE D'OR", Icon = "💎", Desc = "24 h de revenu instantané.", Price = 999, Color = Color3.fromRGB(120, 220, 255), Kind = "Cash", CashSeconds = 86400, CashMin = 400000 },
} :: { Product }

-- Multiplicateurs
M.VIPIncome = 0.25
M.PremiumIncome = 0.10 -- abonnés Roblox Premium (augmente aussi les Premium Payouts)
M.LuckWeightMult = { [4] = 2, [5] = 2.5, [6] = 3, [7] = 3 } -- par rang de rareté pendant la chance serveur

-- Pack débutant : offre limitée après la 1re connexion
M.StarterWindow = 24 * 3600

-- Récompense quotidienne (série de 7 jours, en minutes de revenu ; minimum garanti)
M.Daily = {
	{ Minutes = 5, Min = 500 },
	{ Minutes = 10, Min = 1000 },
	{ Minutes = 15, Min = 2000, Boost = "Shield", Duration = 180 },
	{ Minutes = 20, Min = 3500 },
	{ Minutes = 30, Min = 5000, Boost = "Train3x", Duration = 300 },
	{ Minutes = 45, Min = 8000 },
	{ Minutes = 60, Min = 15000, Boost = "Money2x", Duration = 900 },
}

-- Cadeaux de temps de jeu (par session, en minutes jouées)
M.Gifts = {
	{ At = 5, Icon = "💵", Label = "5 min de revenu", Minutes = 5, Min = 750 },
	{ At = 12, Icon = "🛡️", Label = "Bouclier 2 min", Boost = "Shield", Duration = 120 },
	{ At = 25, Icon = "💰", Label = "15 min de revenu", Minutes = 15, Min = 3000 },
	{ At = 45, Icon = "💸", Label = "2× Argent 10 min", Boost = "Money2x", Duration = 600 },
}

-- Codes (à annoncer sur le groupe / Discord / description du jeu)
M.Codes = {
	SNAKE = { Minutes = 10, Min = 2000, Label = "10 min de revenu" },
	SSSS = { Boost = "Money2x", Duration = 600, Label = "2× Argent 10 min" },
	VIPERE = { Boost = "Shield", Duration = 300, Label = "Bouclier 5 min" },
}

-- Libellés des boosts (HUD)
M.BoostInfo = {
	Money2x = { Icon = "💸", Name = "2× Argent", Color = Color3.fromRGB(90, 220, 120) },
	Shield = { Icon = "🛡️", Name = "Bouclier", Color = Color3.fromRGB(110, 190, 255) },
	Train3x = { Icon = "🏃", Name = "Turbo tapis", Color = Color3.fromRGB(255, 140, 70) },
}

function M.pass(key: string): Pass?
	for _, p in M.Passes do
		if p.Key == key then
			return p
		end
	end
	return nil
end

function M.product(key: string): Product?
	for _, p in M.Products do
		if p.Key == key then
			return p
		end
	end
	return nil
end

function M.productById(id: number): Product?
	if id == 0 then
		return nil
	end
	for _, p in M.Products do
		if p.Id == id then
			return p
		end
	end
	return nil
end

function M.passById(id: number): Pass?
	if id == 0 then
		return nil
	end
	for _, p in M.Passes do
		if p.Id == id then
			return p
		end
	end
	return nil
end

-- Multiplicateur de revenu total (partagé serveur/HUD) : passes × boosts × Premium.
function M.incomeMult(passes: { [string]: boolean }?, boosts: { [string]: number }?, now: number, premium: boolean?): number
	local m = 1
	if passes and passes.Money2x then
		m *= 2
	end
	if passes and passes.VIP then
		m *= 1 + M.VIPIncome
	end
	if premium then
		m *= 1 + M.PremiumIncome
	end
	if boosts and (boosts.Money2x or 0) > now then
		m *= 2
	end
	return m
end

function M.trainMult(passes: { [string]: boolean }?, boosts: { [string]: number }?, now: number): number
	local m = 1
	if passes and passes.Train2x then
		m *= 2
	end
	if boosts and (boosts.Train3x or 0) > now then
		m *= 3
	end
	return m
end

-- Montant d'un pack d'argent selon le revenu/s du joueur
function M.cashFor(incomePerSec: number, seconds: number, minimum: number): number
	return math.floor(math.max(minimum, incomePerSec * seconds))
end

return M
