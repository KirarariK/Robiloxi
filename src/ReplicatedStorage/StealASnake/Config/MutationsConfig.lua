--!strict
export type MutationId = "Normal" | "Albino" | "Venomous" | "Gold" | "Cosmic"

local MutationsConfig = {
	Order = { "Normal", "Albino", "Venomous", "Gold", "Cosmic" } :: { MutationId },
	Defs = {
		Normal = { Id = "Normal", DisplayName = "Normal", Multiplier = 1, Weight = 70, Color = Color3.fromRGB(200, 200, 200) },
		Albino = { Id = "Albino", DisplayName = "Albino", Multiplier = 2, Weight = 18, Color = Color3.fromRGB(255, 255, 255) },
		Venomous = { Id = "Venomous", DisplayName = "Venimeux", Multiplier = 4, Weight = 8, Color = Color3.fromRGB(80, 255, 70) },
		Gold = { Id = "Gold", DisplayName = "Or", Multiplier = 8, Weight = 3.2, Color = Color3.fromRGB(255, 200, 40) },
		Cosmic = { Id = "Cosmic", DisplayName = "Cosmique", Multiplier = 20, Weight = 0.8, Color = Color3.fromRGB(180, 120, 255) },
	},
	FusionNext = {
		Normal = "Albino",
		Albino = "Venomous",
		Venomous = "Gold",
		Gold = "Cosmic",
		Cosmic = "Cosmic",
	} :: { [string]: MutationId },
}

function MutationsConfig.roll(): MutationId
	local total = 0
	for _, id in MutationsConfig.Order do
		total += MutationsConfig.Defs[id].Weight
	end
	local r = math.random() * total
	local acc = 0
	for _, id in MutationsConfig.Order do
		acc += MutationsConfig.Defs[id].Weight
		if r <= acc then
			return id
		end
	end
	return "Normal"
end

return MutationsConfig
