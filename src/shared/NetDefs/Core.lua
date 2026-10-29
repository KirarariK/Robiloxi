--!strict
-- Remotes du socle (profil, notifications). Chaque domaine a son propre fichier dans NetDefs.
return {
	ClientEvents = {} :: { string },
	ServerEvents = {
		"ProfileUpdated", -- vue du profil (après chargement et à chaque changement)
		"Notify", -- message toast { Text: string, Kind: string }
	},
	Functions = {
		"GetProfile",
	},
}
