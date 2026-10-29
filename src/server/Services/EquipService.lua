--!strict
-- Équipement et inventaire : Voie (possédée), arme (3 types toujours disponibles), cristal de lame (possédé),
-- titre (possédé), 8 emplacements d'emotes. Achat des cristaux de lame avec les Cristaux (prix par rareté).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local FormData = require(Shared.Config.FormData)
local WeaponData = require(Shared.Config.WeaponData)
local SaberColors = require(Shared.Config.SaberColors)
local TitleData = require(Shared.Config.TitleData)
local EmoteData = require(Shared.Config.EmoteData)

local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Guard)
local TitleService = require(script.Parent.TitleService)
local HubPrompts = require(script.Parent.Parent.Match.HubPrompts)

type Result = Guard.Result

local EquipService = {}
EquipService.Priority = 35

-- Prix des cristaux de lame (en Cristaux) selon la rareté. Partagé avec l'UI via l'attribut du dossier Config.
EquipService.ColorPrices = table.freeze({
	Commun = 150,
	Rare = 400,
	Epique = 900,
	Legendaire = 2000,
	Mythique = 4500,
} :: { [Types.Rarity]: number })

local function inDuel(player: Player): boolean
	return player:GetAttribute("EB_InMatch") == true
end

local function equipEmote(p: Types.Profile, slot: number, id: string): Result
	if slot ~= math.floor(slot) or slot < 1 or slot > EmoteData.Slots then
		return { Ok = false, Err = "Emplacement invalide." }
	end
	local list = p.EquippedEmotes
	if id == "" then
		if list[slot] then
			table.remove(list, slot)
		end
		return { Ok = true }
	end
	if not EmoteData.get(id) then
		return { Ok = false, Err = "Emote inconnue." }
	end
	local existing = table.find(list, id)
	if existing == slot then
		return { Ok = true }
	end
	if existing then
		-- déjà équipée ailleurs : on échange les deux emplacements
		if list[slot] then
			list[existing], list[slot] = list[slot], list[existing]
		else
			table.remove(list, existing)
			table.insert(list, id)
		end
		return { Ok = true }
	end
	if list[slot] then
		list[slot] = id
	elseif #list < EmoteData.Slots then
		table.insert(list, id)
	else
		return { Ok = false, Err = "Roue d'emotes pleine." }
	end
	return { Ok = true }
end

local function equip(player: Player, kind: string, id: string, slot: number?): Result
	local profile = DataService.get(player)
	if not profile then
		return { Ok = false, Err = "Profil en cours de chargement…" }
	end
	if (kind == "Form" or kind == "Weapon" or kind == "Color") and inDuel(player) then
		return { Ok = false, Err = "Impossible de changer d'équipement pendant un duel." }
	end
	local res: Result = { Ok = false, Err = "Requête invalide." }
	if kind == "Form" then
		if not FormData.isValid(id) then
			return { Ok = false, Err = "Voie inconnue." }
		end
		if not profile.OwnedForms[id :: Types.FormId] then
			return { Ok = false, Err = "Tu ne possèdes pas cette Voie." }
		end
		DataService.update(player, function(p)
			p.EquippedForm = id :: Types.FormId
		end)
		res = { Ok = true }
	elseif kind == "Weapon" then
		if not WeaponData.isValid(id) then
			return { Ok = false, Err = "Arme inconnue." }
		end
		DataService.update(player, function(p)
			p.EquippedWeapon = id :: Types.WeaponType
		end)
		res = { Ok = true }
	elseif kind == "Color" then
		if not SaberColors.isValid(id) then
			return { Ok = false, Err = "Cristal inconnu." }
		end
		if not profile.OwnedColors[id] then
			return { Ok = false, Err = "Tu ne possèdes pas ce cristal." }
		end
		DataService.update(player, function(p)
			p.EquippedColor = id
		end)
		res = { Ok = true }
	elseif kind == "Title" then
		if not TitleData.get(id) then
			return { Ok = false, Err = "Titre inconnu." }
		end
		if not profile.OwnedTitles[id] then
			return { Ok = false, Err = "Titre non débloqué." }
		end
		DataService.update(player, function(p)
			p.EquippedTitle = id
		end)
		TitleService.refresh(player)
		res = { Ok = true }
	elseif kind == "Emote" then
		if slot == nil then
			return { Ok = false, Err = "Emplacement manquant." }
		end
		local s = slot :: number
		DataService.update(player, function(p)
			res = equipEmote(p, s, id)
		end)
	end
	if res.Ok and (kind == "Form" or kind == "Weapon" or kind == "Color") then
		-- la lame et la Voie en main changent tout de suite (hors duel)
		local combat = script.Parent:FindFirstChild("CombatService")
		if combat and combat:IsA("ModuleScript") then
			local cs = require(combat) :: any
			if type(cs.refreshLoadout) == "function" then
				pcall(cs.refreshLoadout, player)
			end
		end
	end
	return res
end

local function buyColor(player: Player, id: string): Result
	local profile = DataService.get(player)
	if not profile then
		return { Ok = false, Err = "Profil en cours de chargement…" }
	end
	local def = SaberColors.get(id)
	if not def then
		return { Ok = false, Err = "Cristal inconnu." }
	end
	if profile.OwnedColors[id] then
		return { Ok = false, Err = "Tu possèdes déjà ce cristal." }
	end
	local price = EquipService.ColorPrices[def.Rarity]
	if profile.Crystals < price then
		return { Ok = false, Err = string.format("Il te faut %d Cristaux.", price) }
	end
	DataService.update(player, function(p)
		p.Crystals -= price
		p.OwnedColors[id] = true
		if not inDuel(player) then
			p.EquippedColor = id
		end
	end)
	return { Ok = true, Data = { ColorId = id, Price = price } }
end

function EquipService.init()
	Guard.func("Equip", { "string", "string", "number?" }, 4, 10, equip)
	Guard.func("BuyColor", { "string" }, 1, 3, buyColor)
	-- prix lisibles par l'UI (attributs répliqués du dossier partagé)
	local cfg = Shared:FindFirstChild("Config")
	if cfg then
		for rarity, price in EquipService.ColorPrices do
			cfg:SetAttribute("ColorPrice_" .. rarity, price)
		end
	end
end

function EquipService.start()
	local bench = HubPrompts.getPart("SaberBench")
	if bench then
		HubPrompts.attach(bench, {
			Action = "OpenWorkshop",
			ActionText = "Ouvrir l'Atelier",
			ObjectText = "Atelier de lame",
			MaxDistance = 12,
		})
	end
end

return EquipService
