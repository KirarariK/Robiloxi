--!strict
local RebirthsConfig = {
	BaseCost = 100000,
	CostGrowth = 2.4,
	IncomeMultPerRebirth = 0.25, -- +25% income each rebirth
	SpeedBonusPerRebirth = 3,
	KeepSpeedPercent = 0.15,
}

function RebirthsConfig.costFor(rebirths: number): number
	return math.floor(RebirthsConfig.BaseCost * (RebirthsConfig.CostGrowth ^ rebirths))
end

return RebirthsConfig
