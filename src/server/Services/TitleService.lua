--!strict
-- Titres : déblocage (rang, victoires, séries, maîtrise de Voie) et attributs répliqués lus par
-- TitleController pour le BillboardGui au-dessus de la tête.
-- Attributs posés sur le Player : EB_Title (Id du titre équipé), EB_Rank (Id du rang), EB_Elo, EB_WorldRank (0 = hors top).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local TitleData = require(Shared.Config.TitleData)
local RankData = require(Shared.Config.RankData)

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)

type Profile = Types.Profile

local TitleService = {}
TitleService.Priority = 31

local function meets(def: Types.TitleDef, p: Profile, worldRank: number?): boolean
	if def.Source == "Default" then
		return true
	elseif def.Source == "Rank" then
		if def.Id == "RangGrandMaitre" then
			return RankData.tierFor(p.Elo, worldRank).Id == "GrandMaitre"
		end
		return p.PeakElo >= def.Requirement
	elseif def.Source == "Wins" then
		return p.Wins >= def.Requirement
	elseif def.Source == "Streak" then
		return p.BestStreak >= def.Requirement
	elseif def.Source == "Mastery" then
		local f = def.FormId
		return f ~= nil and (p.FormMastery[f] or 0) >= def.Requirement
	end
	return false -- « Reroll » : débloqué directement par RerollService
end

-- Débloque dans `p` les titres dont les conditions sont remplies. Pur (aucun yield) : utilisable dans DataService.update.
function TitleService.evaluate(p: Profile, worldRank: number?): { string }
	local unlocked: { string } = {}
	for _, def in TitleData.List do
		if not p.OwnedTitles[def.Id] and meets(def, p, worldRank) then
			p.OwnedTitles[def.Id] = true
			table.insert(unlocked, def.Id)
		end
	end
	return unlocked
end

function TitleService.notifyUnlocked(player: Player, ids: { string })
	for _, id in ids do
		local def = TitleData.get(id)
		if def then
			Net.event("Notify"):FireClient(player, { Text = "Titre débloqué : « " .. def.Text .. " »", Kind = "Title" })
		end
	end
end

-- Met à jour les attributs affichés par les autres clients.
function TitleService.refresh(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local wr = LeaderboardService.getWorldRank(player.UserId)
	player:SetAttribute("EB_Title", p.EquippedTitle)
	player:SetAttribute("EB_Rank", RankData.tierFor(p.Elo, wr).Id)
	player:SetAttribute("EB_Elo", p.Elo)
	player:SetAttribute("EB_WorldRank", wr or 0)
end

-- Vérifie les déblocages, notifie, rafraîchit. Retourne les nouveaux titres.
function TitleService.check(player: Player): { string }
	local wr = LeaderboardService.getWorldRank(player.UserId)
	local unlocked: { string } = {}
	DataService.update(player, function(p)
		unlocked = TitleService.evaluate(p, wr)
	end)
	TitleService.notifyUnlocked(player, unlocked)
	TitleService.refresh(player)
	return unlocked
end

function TitleService.init()
	DataService.ProfileLoaded:Connect(function(player: Player)
		TitleService.check(player)
	end)
	LeaderboardService.RanksUpdated:Connect(function()
		for _, player in Players:GetPlayers() do
			if DataService.get(player) then
				TitleService.check(player)
			end
		end
	end)
end

return TitleService
