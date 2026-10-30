--!strict
-- Relances des Voies (gacha) : coût en Cristaux, tirage serveur pondéré, pitié, titre « Chanceux ».
-- Champ de profil ajouté : `RerollPity` (number) = tirages consécutifs sans Voie Épique ou mieux.
-- Il est créé à la volée ((profile :: any).RerollPity) ; DataService le conserve (clés hors schéma préservées).
-- Fournit aussi le barème des Cristaux gagnés après chaque duel (`duelReward`).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local FormData = require(Shared.Config.FormData)
local Rarity = require(Shared.Config.Rarity)
local TitleData = require(Shared.Config.TitleData)
local RerollMath = require(Shared.Config.RerollMath)

local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Guard)
local HubPrompts = require(script.Parent.Parent.Match.HubPrompts)

local RerollService = {}
RerollService.Priority = 35
local shrinePart: BasePart? = nil

RerollService.Cost = 100
RerollService.PityLimit = 50 -- le 50e tirage sans Épique+ est garanti Épique ou mieux
RerollService.DuplicateRefund = 25 -- Cristaux rendus quand la Voie est déjà possédée
RerollService.LuckyTitle = "Chanceux"

local rng = Random.new()

local function isHigh(r: Types.Rarity): boolean
	return Rarity[r].Order >= Rarity.Epique.Order
end

local function isJackpot(r: Types.Rarity): boolean
	return Rarity[r].Order >= Rarity.Legendaire.Order
end

-- Tirage pondéré ; `forceHigh` restreint au pool Épique+ (pitié), en respectant les poids relatifs.
local function draw(forceHigh: boolean): Types.FormDef
	if not forceHigh then
		return FormData.pick(rng:NextNumber() * FormData.TotalWeight)
	end
	local total = 0
	for _, f in FormData.List do
		if isHigh(f.Rarity) then
			total += f.Weight
		end
	end
	local roll = rng:NextNumber() * total
	local acc = 0
	local last: Types.FormDef? = nil
	for _, f in FormData.List do
		if isHigh(f.Rarity) then
			acc += f.Weight
			last = f
			if roll < acc then
				return f
			end
		end
	end
	return last :: Types.FormDef
end

local function pityOf(profile: Types.Profile): number
	local v = (profile :: any).RerollPity
	return if type(v) == "number" and v >= 0 then math.floor(v) else 0
end

-- Cristaux gagnés après un duel (le serveur appelle ceci, jamais le client).
function RerollService.duelReward(won: boolean, mode: string, roundsWon: number, leaver: boolean): number
	if leaver then
		return 0
	end
	local base = if won then 60 else 20
	if mode == "Ranked" then
		base += if won then 40 else 10
	elseif mode == "Challenge" then
		base = math.floor(base * 0.5) -- défis directs : moins rentables pour limiter l'entente entre amis
	end
	return base + 5 * math.clamp(roundsWon, 0, 5)
end

local function doReroll(player: Player): Guard.Result
	if player:GetAttribute("EB_InMatch") then
		return { Ok = false, Err = "Impossible de relancer pendant un duel." }
	end
	if not shrinePart or not HubPrompts.isNear(player, shrinePart, 14) then
		return { Ok = false, Err = "Approche-toi de l'Autel des Cristaux pour relancer." }
	end
	local profile = DataService.get(player)
	if not profile then
		return { Ok = false, Err = "Profil en cours de chargement…" }
	end
	if profile.Crystals < RerollService.Cost then
		return { Ok = false, Err = string.format("Il te faut %d Cristaux (tu en as %d).", RerollService.Cost, profile.Crystals) }
	end
	local result: { [string]: any } = {}
	local luckyUnlocked = false
	DataService.update(player, function(p)
		local pity = pityOf(p)
		local forced = RerollMath.shouldForce(pity, RerollService.PityLimit)
		local form = draw(forced)
		p.Crystals -= RerollService.Cost
		p.Rerolls += 1
		local duplicate = p.OwnedForms[form.Id] == true
		local refund = 0
		if duplicate then
			refund = RerollService.DuplicateRefund
			p.Crystals += refund
		else
			p.OwnedForms[form.Id] = true
		end
		local newPity = RerollMath.nextPity(pity, isHigh(form.Rarity))
		;(p :: any).RerollPity = newPity
		if isJackpot(form.Rarity) and not p.OwnedTitles[RerollService.LuckyTitle] and TitleData.get(RerollService.LuckyTitle) then
			p.OwnedTitles[RerollService.LuckyTitle] = true
			luckyUnlocked = true
		end
		result = {
			FormId = form.Id,
			Rarity = form.Rarity,
			Duplicate = duplicate,
			Refund = refund,
			Forced = forced,
			Pity = newPity,
			PityLimit = RerollService.PityLimit,
			Crystals = p.Crystals,
		}
	end)
	if luckyUnlocked then
		local def = TitleData.get(RerollService.LuckyTitle)
		if def then
			-- notification différée : la révélation de la roulette passe d'abord
			task.delay(4.5, function()
				if player.Parent then
					Net.event("Notify"):FireClient(player, { Text = "Titre débloqué : « " .. def.Text .. " »", Kind = "Title" })
				end
			end)
		end
	end
	return { Ok = true, Data = result }
end

function RerollService.init()
	Guard.func("Reroll", {}, 1, 3, doReroll)
end

function RerollService.start()
	shrinePart = HubPrompts.getPart("RerollShrine")
	if shrinePart then
		-- le client ouvre la page de relance ; le serveur ne fait rien de plus ici
		HubPrompts.attach(shrinePart, {
			Action = "OpenReroll",
			ActionText = "Relancer ta Voie",
			ObjectText = "Autel des Cristaux",
			MaxDistance = 12,
		})
	end
end

return RerollService
