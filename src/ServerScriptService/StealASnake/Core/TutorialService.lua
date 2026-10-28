--!strict
--[[
	TutorialService — onboarding en 4 étapes (première partie) :
	1 voler un serpent · 2 le déposer · 3 récolter l'argent · 4 s'entraîner sur le tapis.
	L'étape est stockée dans les données du joueur (TutorialStep, 5 = terminé) et répliquée en
	attribut joueur par DataManager.push : le client s'en sert pour l'objectif et le rayon guide.
]]
local DataManager = require(script.Parent.DataManager)
local Network = require(game.ReplicatedStorage.StealASnake.Modules.Network)

local TutorialService = {}

TutorialService.DONE = 5

local NEXT_MESSAGE: { [number]: string } = {
	[2] = "✅ Bien joué ! Ramène vite le serpent sur la zone verte de ta base",
	[3] = "✅ Serpent sécurisé ! Il te rapporte de l'argent chaque seconde",
	[4] = "✅ Argent récolté ! Entraîne-toi sur ton tapis pour courir plus vite",
	[5] = "🎉 Tutoriel terminé ! Les serpents rares t'attendent dans les biomes suivants",
}

-- Passe à l'étape suivante seulement si le joueur est exactement à `fromStep`.
function TutorialService.advance(player: Player, fromStep: number)
	local d = DataManager.get(player)
	if d.TutorialStep ~= fromStep then
		return
	end
	d.TutorialStep = fromStep + 1
	DataManager.markDirty(player)
	DataManager.push(player)
	local msg = NEXT_MESSAGE[d.TutorialStep]
	if msg then
		Network.event("Alert"):FireClient(player, msg)
	end
end

return TutorialService
