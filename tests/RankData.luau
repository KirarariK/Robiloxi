--!strict
local LoadModule = require("./Support/LoadModule")
local RankData = LoadModule.fromSource("src/shared/Config/RankData.lua")

for _, pair in { { 1000, 1000 }, { 1450, 1300 }, { 1700, 1600 } } do
	local a, b = pair[1], pair[2]
	assert(RankData.delta(a, b, 1, 10) == -RankData.delta(b, a, 0, 10), "delta doit être symétrique")
end
assert(RankData.tierFor(1099).Id == "Initie", "Le seuil initial doit rester au rang Initié")
assert(RankData.tierFor(1100).Id == "Apprenti", "Le seuil Apprenti doit être inclusif")
assert(RankData.tierFor(2000, 50).Id == "GrandMaitre", "La 50e place doit accéder au Grand Maître")
assert(RankData.tierFor(2000, 51).Id == "Archonte", "La 51e place ne doit pas accéder au Top 50")
assert(RankData.tierFor(2000).Id == "Archonte", "Un rang mondial inconnu ne compte pas dans le Top 50")

print("RankData : OK")
