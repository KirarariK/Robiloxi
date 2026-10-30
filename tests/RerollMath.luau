--!strict
local RerollMath = require("../src/shared/Config/RerollMath")

local pity = 0
for draw = 1, 49 do
	assert(not RerollMath.shouldForce(pity, 50), "Aucune garantie avant le 50e tirage")
	pity = RerollMath.nextPity(pity, false)
end
assert(pity == 49 and RerollMath.shouldForce(pity, 50), "Le 50e tirage sans Épique+ doit être forcé")
assert(RerollMath.nextPity(pity, true) == 0, "Une rareté Épique ou mieux doit réinitialiser la garantie")

print("RerollMath : OK")
