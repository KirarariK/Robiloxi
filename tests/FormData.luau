--!strict
local LoadModule = require("./Support/LoadModule")
local FormData = LoadModule.fromSource("src/shared/Config/FormData.lua")

assert(math.abs(FormData.TotalWeight - 100) < 1e-6, "Les poids doivent totaliser 100")
assert(FormData.pick(0).Id == "Origine", "La borne basse doit choisir la première Voie")
assert(FormData.pick(99.999).Id == "Tempete", "La borne haute doit choisir la dernière Voie")
assert(FormData.pick(40).Id == "Duelliste", "Une borne de tranche doit choisir la Voie suivante")

local counts: { [string]: number } = {}
local sampleCount = 100000
for i = 0, sampleCount - 1 do
	local form = FormData.pick((i + 0.5) * FormData.TotalWeight / sampleCount)
	counts[form.Id] = (counts[form.Id] or 0) + 1
end
for _, form in FormData.List do
	local observed = (counts[form.Id] or 0) * 100 / sampleCount
	assert(math.abs(observed - form.Weight) <= 0.3, form.Id .. " : écart de poids supérieur à 0,3 %")
end

print("FormData : OK (100 000 tirages)")
