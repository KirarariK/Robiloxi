--!strict
--[[
	Formes + gacha banner + pity + Ranked fair-kit (Rare cap).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local FormConfig = require(Shared:WaitForChild("FormConfig"))
local EconomyConfig = require(Shared:WaitForChild("EconomyConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlayerDataService = require(script.Parent.Parent.Data:WaitForChild("PlayerDataService"))
local FighterState = require(script.Parent.Parent.Combat:WaitForChild("FighterState"))

local FormService = {}

local FORM_IDS = { "Astra", "Duelant", "Aegis", "Zephyr" }
local RARITIES = FormConfig.RarityOrder

local function rollRarity(profile): string
	-- Pity
	if profile.pityLegendary + 1 >= FormConfig.PityLegendary then
		profile.pityLegendary = 0
		profile.pityEpic = 0
		return "Legendary"
	end
	if profile.pityEpic + 1 >= FormConfig.PityEpic then
		profile.pityEpic = 0
		return "Epic"
	end

	local r = math.random()
	local acc = 0
	local rates = FormConfig.DropRates
	local order = { "Legendary", "Epic", "Rare", "Common" }
	for _, rarity in order do
		acc += rates[rarity]
		if r <= acc then
			if rarity == "Legendary" then
				profile.pityLegendary = 0
				profile.pityEpic = 0
			elseif rarity == "Epic" then
				profile.pityEpic = 0
				profile.pityLegendary += 1
			else
				profile.pityEpic += 1
				profile.pityLegendary += 1
			end
			return rarity
		end
	end
	profile.pityEpic += 1
	profile.pityLegendary += 1
	return "Common"
end

local function addForm(profile, formId: string, rarity: string): (boolean, number)
	for _, owned in profile.ownedForms do
		if owned.formId == formId and owned.rarity == rarity then
			owned.count += 1
			-- Duplicate → fragments
			local frags = if rarity == "Legendary" then 40 elseif rarity == "Epic" then 15 elseif rarity == "Rare" then 5 else 2
			profile.fragments += frags
			return true, frags
		end
	end
	table.insert(profile.ownedForms, { formId = formId, rarity = rarity, count = 1 })
	return false, 0
end

local function rarityIndex(r: string): number
	for i, name in RARITIES do
		if name == r then
			return i
		end
	end
	return 1
end

local function cappedRarity(rarity: string, mode: string): string
	if mode == "Ranked" then
		local maxIdx = rarityIndex(FormConfig.RankedMaxRarityForStats)
		return RARITIES[math.min(rarityIndex(rarity), maxIdx)]
	end
	return rarity
end

function FormService.clearFormAttributes(player: Player)
	for _, name in {
		"BC_StaminaRegenMult",
		"BC_RiposteDamageMult",
		"BC_GuardDrainMult",
		"BC_DodgeCostMult",
		"BC_PerfectWindowBonus",
		"BC_ChipTakenMult",
		"BC_FocusDashCdBonus",
		"BC_DodgeIFramesBonus",
		"BC_GuardBreakResist",
	} do
		player:SetAttribute(name, nil)
	end
end

function FormService.applyToFighter(player: Player, mode: string)
	local profile = PlayerDataService.get(player)
	local fighter = FighterState.get(player)
	if not profile or not fighter then
		return
	end

	FormService.clearFormAttributes(player)
	local formId = profile.equippedFormId
	local rarity = profile.equippedFormRarity
	local effective = cappedRarity(rarity, mode)

	fighter.formId = formId
	fighter.formRarity = if mode == "Ranked" then effective else rarity
	-- En Ranked, les uniques Légendaires sont cosmetics-only → rarity effective pour uniques
	if mode == "Ranked" then
		fighter.formRarity = effective
	end

	local def = FormConfig.Forms[formId]
	if not def then
		return
	end
	local mods = def.statMods[effective :: any]
	if mods then
		if mods.staminaRegenMult then
			player:SetAttribute("BC_StaminaRegenMult", mods.staminaRegenMult)
		end
		if mods.riposteDamageMult then
			player:SetAttribute("BC_RiposteDamageMult", mods.riposteDamageMult)
		end
		if mods.guardDrainMult then
			player:SetAttribute("BC_GuardDrainMult", mods.guardDrainMult)
		end
		if mods.dodgeCostMult then
			player:SetAttribute("BC_DodgeCostMult", mods.dodgeCostMult)
		end
		if mods.perfectWindowBonus then
			player:SetAttribute("BC_PerfectWindowBonus", mods.perfectWindowBonus)
		end
		if mods.chipTakenMult then
			player:SetAttribute("BC_ChipTakenMult", mods.chipTakenMult)
		end
		if mods.focusDashCdBonus and mode ~= "Ranked" then
			-- Epic Zephyr CD — Ranked cap Rare n'a pas ce mod
			player:SetAttribute("BC_FocusDashCdBonus", mods.focusDashCdBonus)
		elseif mods.focusDashCdBonus and effective == "Epic" then
			player:SetAttribute("BC_FocusDashCdBonus", mods.focusDashCdBonus)
		end
	end

	-- Rare Zephyr i-frames +20 ms
	if formId == "Zephyr" and rarityIndex(effective) >= rarityIndex("Rare") then
		player:SetAttribute("BC_DodgeIFramesBonus", 0.020)
	end
	-- Aegis Epic guard break resist (Casual full / Ranked capped away)
	if formId == "Aegis" and mode ~= "Ranked" and rarityIndex(rarity) >= rarityIndex("Epic") then
		player:SetAttribute("BC_GuardBreakResist", 0.15)
	end

	player:SetAttribute("BC_FairKit", mode == "Ranked")
	player:SetAttribute("BC_FormDisplay", formId .. " (" .. (if mode == "Ranked" then effective .. " cap" else rarity) .. ")")
end

function FormService.pull(player: Player, count: number, usePremium: boolean): { [string]: any }
	local profile = PlayerDataService.get(player)
	if not profile then
		return { ok = false, error = "no_profile" }
	end
	count = math.clamp(math.floor(count), 1, 10)

	local week = tonumber(os.date("%W")) or 0
	if not usePremium and count == 10 then
		if profile.freeTicketWeek == week then
			return { ok = false, error = "no_free_ticket" }
		end
		profile.freeTicketWeek = week
	elseif usePremium then
		local cost = if count == 10 then EconomyConfig.BannerTenPullPremium else math.ceil(EconomyConfig.BannerTenPullPremium / 10)
		if profile.shards < cost then
			return { ok = false, error = "not_enough_shards" }
		end
		profile.shards -= cost
	else
		-- Soft currency single pull stub
		local softCost = 300 * count
		if profile.credits < softCost then
			return { ok = false, error = "not_enough_credits" }
		end
		profile.credits -= softCost
	end

	local results = {}
	for _ = 1, count do
		local formId = FORM_IDS[math.random(1, #FORM_IDS)]
		local rarity = rollRarity(profile)
		local dup, frags = addForm(profile, formId, rarity)
		profile.bannerPulls += 1
		table.insert(results, {
			formId = formId,
			rarity = rarity,
			duplicate = dup,
			fragments = frags,
		})
	end

	PlayerDataService.save(player)
	return {
		ok = true,
		results = results,
		pityEpic = profile.pityEpic,
		pityLegendary = profile.pityLegendary,
	}
end

function FormService.equip(player: Player, formId: string, rarity: string): boolean
	local profile = PlayerDataService.get(player)
	if not profile then
		return false
	end
	local found = false
	for _, owned in profile.ownedForms do
		if owned.formId == formId and owned.rarity == rarity then
			found = true
			break
		end
	end
	if not found then
		return false
	end
	profile.equippedFormId = formId
	profile.equippedFormRarity = rarity
	PlayerDataService.save(player)
	return true
end

function FormService.start()
	local meta = Remotes.getMeta()
	meta.GachaPull.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		local count = payload.count or 1
		local usePremium = payload.premium == true
		local result = FormService.pull(player, count, usePremium)
		local profile = PlayerDataService.get(player)
		meta.MetaState:FireClient(player, {
			kind = "GachaResult",
			data = result,
			profile = if profile then PlayerDataService.toClientSnapshot(profile) else nil,
		})
	end)

	meta.EquipLoadout.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.formId and payload.rarity then
			FormService.equip(player, tostring(payload.formId), tostring(payload.rarity))
		end
		local profile = PlayerDataService.get(player)
		if not profile then
			return
		end
		meta.MetaState:FireClient(player, {
			kind = "Profile",
			profile = PlayerDataService.toClientSnapshot(profile),
		})
	end)
end

return FormService
