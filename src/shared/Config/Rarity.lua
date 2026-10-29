--!strict
local Types = require(script.Parent.Parent.Types)

export type RarityInfo = {
	Id: Types.Rarity,
	Label: string,
	Order: number,
	Color: Color3,
}

local Rarity: { [Types.Rarity]: RarityInfo } = {
	Commun = { Id = "Commun", Label = "Commun", Order = 1, Color = Color3.fromRGB(176, 184, 196) },
	Rare = { Id = "Rare", Label = "Rare", Order = 2, Color = Color3.fromRGB(72, 156, 255) },
	Epique = { Id = "Epique", Label = "Épique", Order = 3, Color = Color3.fromRGB(176, 92, 255) },
	Legendaire = { Id = "Legendaire", Label = "Légendaire", Order = 4, Color = Color3.fromRGB(255, 184, 48) },
	Mythique = { Id = "Mythique", Label = "Mythique", Order = 5, Color = Color3.fromRGB(255, 64, 112) },
}

return table.freeze(Rarity)
