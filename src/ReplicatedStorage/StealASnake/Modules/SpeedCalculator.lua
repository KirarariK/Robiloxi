--!strict
local SpeedCalculator = {}

function SpeedCalculator.normalSpeed(playerSpeedStat: number, rebirths: number, rebirthSpeedBonus: number): number
	return 16 + (playerSpeedStat ^ 0.65) + (rebirths * rebirthSpeedBonus)
end

function SpeedCalculator.carrySpeed(normalSpeed: number, snakeWeight: number): number
	return math.clamp(normalSpeed - (snakeWeight * 0.35), 5, normalSpeed)
end

function SpeedCalculator.income(
	baseIncome: number,
	rarityMult: number,
	weight: number,
	baseWeight: number,
	mutationMult: number,
	rebirthMult: number
): number
	return math.floor(baseIncome * rarityMult * (weight / baseWeight) * mutationMult * rebirthMult)
end

return SpeedCalculator
