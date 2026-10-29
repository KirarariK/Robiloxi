--!strict
-- État client partagé (profil reçu du serveur) avec un signal de changement.
local ClientState = {}

local profile: { [string]: any }? = nil
local changed = Instance.new("BindableEvent")

ClientState.ProfileChanged = changed.Event -- (profile)

function ClientState.getProfile(): { [string]: any }?
	return profile
end

function ClientState.setProfile(view: { [string]: any })
	profile = view
	changed:Fire(view)
end

return ClientState
