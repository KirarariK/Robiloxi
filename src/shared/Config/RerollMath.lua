--!strict
-- Calculs purs de la garantie de relance.
local RerollMath = {}

function RerollMath.shouldForce(pity: number, pityLimit: number): boolean
	return pity >= pityLimit - 1
end

function RerollMath.nextPity(pity: number, highRarity: boolean): number
	return if highRarity then 0 else pity + 1
end

return table.freeze(RerollMath)
