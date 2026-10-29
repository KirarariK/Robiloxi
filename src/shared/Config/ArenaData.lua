--!strict
-- Les 5 arènes de duel : ambiance d'éclairage et danger éventuel.
local Types = require(script.Parent.Parent.Types)

type ArenaDef = Types.ArenaDef

local rgb = Color3.fromRGB

local LIST: { ArenaDef } = {
	{
		Id = "Sanctuaire",
		Name = "Sanctuaire du Temple",
		Description = "Colonnes de marbre et soleil couchant à travers les vitraux.",
		Ambient = rgb(120, 96, 80),
		OutdoorAmbient = rgb(200, 150, 110),
		ClockTime = 17.6,
		FogColor = rgb(240, 190, 140),
		FogEnd = 900,
		Hazard = "None",
	},
	{
		Id = "Forge",
		Name = "Forge Volcanique",
		Description = "Plateforme suspendue au-dessus d'un fleuve de lave, pluie de cendres.",
		Ambient = rgb(90, 30, 16),
		OutdoorAmbient = rgb(150, 50, 20),
		ClockTime = 0.5,
		FogColor = rgb(80, 22, 10),
		FogEnd = 420,
		Hazard = "Lava",
	},
	{
		Id = "Ruines",
		Name = "Ruines sous l'Orage",
		Description = "Pierres moussues, obélisques brisés, éclairs et flaques sous la pluie.",
		Ambient = rgb(40, 48, 62),
		OutdoorAmbient = rgb(60, 72, 92),
		ClockTime = 0,
		FogColor = rgb(30, 36, 48),
		FogEnd = 380,
		Hazard = "None",
	},
	{
		Id = "Reacteur",
		Name = "Chambre du Réacteur",
		Description = "Passerelles sans garde-fou devant des faisceaux d'énergie géants.",
		Ambient = rgb(30, 40, 60),
		OutdoorAmbient = rgb(40, 60, 90),
		ClockTime = 0,
		FogColor = rgb(10, 16, 28),
		FogEnd = 700,
		Hazard = "Void",
	},
	{
		Id = "Cristaux",
		Name = "Canyon de Cristal",
		Description = "Caverne nocturne hérissée de cristaux bioluminescents.",
		Ambient = rgb(30, 50, 80),
		OutdoorAmbient = rgb(50, 70, 120),
		ClockTime = 22,
		FogColor = rgb(20, 30, 60),
		FogEnd = 500,
		Hazard = "None",
	},
}

local byId: { [string]: ArenaDef } = {}
for _, a in LIST do
	byId[a.Id] = table.freeze(a)
end

local ArenaData = {}
ArenaData.List = table.freeze(LIST)

function ArenaData.get(id: string): ArenaDef?
	return byId[id]
end

return table.freeze(ArenaData)
