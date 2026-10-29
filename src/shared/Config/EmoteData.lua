--!strict
-- Emotes de la roue radiale (8 emplacements équipables).
local Types = require(script.Parent.Parent.Types)

type EmoteDef = Types.EmoteDef

local LIST: { EmoteDef } = {
	{ Id = "Salut", Name = "Salut respectueux", Category = "Salut", Duration = 2.2, Looped = false },
	{ Id = "SalutLame", Name = "Salut de la lame", Category = "Salut", Duration = 2.6, Looped = false },
	{ Id = "Meditation", Name = "Méditation flottante", Category = "Meditation", Duration = 0, Looped = true },
	{ Id = "Moulinet", Name = "Moulinet", Category = "Flourish", Duration = 2.4, Looped = false },
	{ Id = "Tourbillon", Name = "Tourbillon", Category = "Flourish", Duration = 2.8, Looped = false },
	{ Id = "Viens", Name = "Approche, si tu l'oses", Category = "Provocation", Duration = 1.8, Looped = false },
	{ Id = "Bailler", Name = "Bâillement", Category = "Provocation", Duration = 2.2, Looped = false },
	{ Id = "Triomphe", Name = "Lame levée", Category = "Victoire", Duration = 3, Looped = false },
	{ Id = "Genou", Name = "Genou à terre", Category = "Victoire", Duration = 3, Looped = false },
}

local byId: { [string]: EmoteDef } = {}
for _, e in LIST do
	byId[e.Id] = table.freeze(e)
end

local EmoteData = {}
EmoteData.List = table.freeze(LIST)
EmoteData.Slots = 8
EmoteData.Default = table.freeze({ "Salut", "Meditation", "Moulinet", "Viens", "Triomphe" })

function EmoteData.get(id: string): EmoteDef?
	return byId[id]
end

return table.freeze(EmoteData)
