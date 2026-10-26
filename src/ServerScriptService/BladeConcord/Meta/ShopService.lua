--!strict
--[[
	Boutique cosmétiques — soft Crédits d'Arène + premium Éclats Focus (stub).
	Aucun item n'accorde de stats.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Visual = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Visual")
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SaberBuilder = require(Visual:WaitForChild("SaberBuilder"))
local PlayerDataService = require(script.Parent.Parent.Data:WaitForChild("PlayerDataService"))

local ShopService = {}

local function owns(profile, itemId: string): boolean
	for _, id in profile.ownedCosmetics do
		if id == itemId then
			return true
		end
	end
	return false
end

local function findItem(itemId: string)
	for _, item in EconomyConfig.Shop do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

function ShopService.purchase(player: Player, itemId: string, usePremium: boolean): { [string]: any }
	local profile = PlayerDataService.get(player)
	if not profile then
		return { ok = false, error = "no_profile" }
	end
	local item = findItem(itemId)
	if not item then
		return { ok = false, error = "unknown_item" }
	end
	if not item.cosmeticOnly then
		return { ok = false, error = "not_cosmetic" }
	end
	if owns(profile, itemId) then
		return { ok = false, error = "already_owned" }
	end

	if usePremium then
		local price = item.premiumPrice
		if not price then
			return { ok = false, error = "no_premium_price" }
		end
		if profile.shards < price then
			return { ok = false, error = "not_enough_shards" }
		end
		profile.shards -= price
	else
		local price = item.softPrice
		if not price then
			return { ok = false, error = "no_soft_price" }
		end
		if profile.credits < price then
			return { ok = false, error = "not_enough_credits" }
		end
		profile.credits -= price
	end

	table.insert(profile.ownedCosmetics, itemId)
	-- Auto-equip
	if item.category == "BladeColor" then
		profile.equippedCosmetics.bladeColor = itemId
	elseif item.category == "Hilt" then
		profile.equippedCosmetics.hilt = itemId
	elseif item.category == "Aura" then
		profile.equippedCosmetics.aura = itemId
	elseif item.category == "Skin" then
		profile.equippedCosmetics.skin = itemId
	elseif item.category == "Emote" then
		profile.equippedCosmetics.emote = itemId
	elseif item.category == "Finisher" then
		profile.equippedCosmetics.finisher = itemId
	end

	-- Appliquer immédiatement sur le sabre runtime (évite wait respawn)
	local character = player.Character
	if character then
		SaberBuilder.applyCosmeticsFromModel(character, profile.equippedCosmetics)
	end

	PlayerDataService.save(player)
	return { ok = true, itemId = itemId }
end

function ShopService.grantWinRewards(player: Player, won: boolean, weekendMult: number)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local base = if won then EconomyConfig.WinCredits else EconomyConfig.LossCredits
	profile.credits += math.floor(base * weekendMult)
	PlayerDataService.save(player)
end

--[[
	Stub premium : grant Éclats Focus (Developer Product pattern — IDs non hardcodés).
]]
function ShopService.grantShardStub(player: Player, amount: number?)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	profile.shards += amount or EconomyConfig.FocusShardStubGrant
	PlayerDataService.save(player)
end

function ShopService.start()
	local meta = Remotes.getMeta()
	meta.ShopPurchase.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.stubShards == true then
			ShopService.grantShardStub(player, nil)
			meta.MetaState:FireClient(player, {
				kind = "Profile",
				profile = PlayerDataService.toClientSnapshot(PlayerDataService.get(player)),
			})
			return
		end
		local result = ShopService.purchase(player, tostring(payload.itemId), payload.premium == true)
		meta.MetaState:FireClient(player, {
			kind = "ShopResult",
			data = result,
			profile = PlayerDataService.toClientSnapshot(PlayerDataService.get(player)),
			catalog = EconomyConfig.Shop,
		})
	end)
end

return ShopService
