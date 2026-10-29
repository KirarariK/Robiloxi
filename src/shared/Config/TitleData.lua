--!strict
-- Titres affichés au-dessus de la tête (BillboardGui + dégradé).
local Types = require(script.Parent.Parent.Types)

type TitleDef = Types.TitleDef

local rgb = Color3.fromRGB

local LIST: { TitleDef } = {
	{ Id = "Novice", Text = "Novice", Rarity = "Commun", Source = "Default", Requirement = 0, Gradient = { rgb(200, 205, 215), rgb(150, 160, 175) } },
	-- Rangs
	{ Id = "RangApprenti", Text = "Apprenti", Rarity = "Commun", Source = "Rank", Requirement = 1100, Gradient = { rgb(140, 230, 170), rgb(70, 170, 110) } },
	{ Id = "RangChevalier", Text = "Chevalier", Rarity = "Rare", Source = "Rank", Requirement = 1300, Gradient = { rgb(120, 190, 255), rgb(40, 110, 230) } },
	{ Id = "RangMaitre", Text = "Maître de Lame", Rarity = "Epique", Source = "Rank", Requirement = 1550, Gradient = { rgb(210, 150, 255), rgb(130, 60, 230) } },
	{ Id = "RangArchonte", Text = "Archonte", Rarity = "Legendaire", Source = "Rank", Requirement = 1800, Gradient = { rgb(255, 170, 110), rgb(230, 80, 30) } },
	{ Id = "RangGrandMaitre", Text = "Grand Maître", Rarity = "Mythique", Source = "Rank", Requirement = 2000, Gradient = { rgb(255, 235, 140), rgb(255, 170, 20) } },
	-- Victoires
	{ Id = "Victoires10", Text = "Lame Affûtée", Rarity = "Commun", Source = "Wins", Requirement = 10, Gradient = { rgb(230, 230, 240), rgb(170, 175, 190) } },
	{ Id = "Victoires50", Text = "Vétéran des Arènes", Rarity = "Rare", Source = "Wins", Requirement = 50, Gradient = { rgb(150, 200, 255), rgb(70, 130, 230) } },
	{ Id = "Victoires250", Text = "Fléau des Duels", Rarity = "Epique", Source = "Wins", Requirement = 250, Gradient = { rgb(230, 120, 255), rgb(140, 40, 210) } },
	{ Id = "Victoires1000", Text = "Légende Vivante", Rarity = "Legendaire", Source = "Wins", Requirement = 1000, Gradient = { rgb(255, 220, 120), rgb(240, 150, 20) } },
	-- Séries
	{ Id = "Serie5", Text = "Inarrêtable", Rarity = "Rare", Source = "Streak", Requirement = 5, Gradient = { rgb(255, 160, 120), rgb(230, 70, 50) } },
	{ Id = "Serie15", Text = "Tempête Incarnée", Rarity = "Legendaire", Source = "Streak", Requirement = 15, Gradient = { rgb(255, 120, 200), rgb(140, 60, 255) } },
	-- Maîtrise d'une Voie (victoires avec la Voie équipée)
	{ Id = "MaitriseOrigine", Text = "Gardien de l'Origine", Rarity = "Rare", Source = "Mastery", Requirement = 100, FormId = "Origine", Gradient = { rgb(220, 225, 235), rgb(140, 150, 170) } },
	{ Id = "MaitriseDuelliste", Text = "Fine Lame", Rarity = "Epique", Source = "Mastery", Requirement = 100, FormId = "Duelliste", Gradient = { rgb(150, 210, 255), rgb(60, 120, 230) } },
	{ Id = "MaitriseRempart", Text = "Muraille Vivante", Rarity = "Epique", Source = "Mastery", Requirement = 100, FormId = "Rempart", Gradient = { rgb(170, 230, 200), rgb(60, 160, 120) } },
	{ Id = "MaitriseFaucon", Text = "Ailes du Faucon", Rarity = "Epique", Source = "Mastery", Requirement = 100, FormId = "Faucon", Gradient = { rgb(255, 230, 150), rgb(230, 160, 40) } },
	{ Id = "MaitriseRiposte", Text = "Marteau de Riposte", Rarity = "Legendaire", Source = "Mastery", Requirement = 100, FormId = "Riposte", Gradient = { rgb(255, 170, 140), rgb(210, 70, 40) } },
	{ Id = "MaitriseEquilibre", Text = "Onde Parfaite", Rarity = "Legendaire", Source = "Mastery", Requirement = 100, FormId = "Equilibre", Gradient = { rgb(170, 255, 240), rgb(50, 180, 200) } },
	{ Id = "MaitriseTempete", Text = "Œil du Cyclone", Rarity = "Mythique", Source = "Mastery", Requirement = 100, FormId = "Tempete", Gradient = { rgb(255, 110, 150), rgb(120, 30, 200) } },
	-- Relances
	{ Id = "Chanceux", Text = "Béni des Cristaux", Rarity = "Epique", Source = "Reroll", Requirement = 0, Gradient = { rgb(255, 250, 200), rgb(120, 230, 255) } },
}

local byId: { [string]: TitleDef } = {}
for _, t in LIST do
	assert(byId[t.Id] == nil, "Titre en double : " .. t.Id)
	t.Gradient = table.freeze(t.Gradient)
	byId[t.Id] = table.freeze(t)
end

local TitleData = {}
TitleData.List = table.freeze(LIST)
TitleData.Default = "Novice"

function TitleData.get(id: string): TitleDef?
	return byId[id]
end

return table.freeze(TitleData)
