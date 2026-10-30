--!strict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local LoadModule = {}

function LoadModule.fromSource(path: string, extra: { [string]: any }?): any
	local typesMarker = {}
	local configMarker = {}
	local config = luau.load(fs.readFile("src/shared/Combat/CombatConfig.lua"), {
		environment = {
			script = {},
			require = function()
				return {}
			end,
		},
	})()
	local moduleScript = {
		Parent = {
			Parent = { Types = typesMarker },
			CombatConfig = configMarker,
		},
	}
	local environment: { [string]: any } = {
		script = moduleScript,
		require = function(dependency)
			if dependency == typesMarker then
				return {}
			elseif dependency == configMarker then
				return config
			end
			error("Dépendance inattendue dans " .. path)
		end,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
	}
	for key, value in extra or {} do
		environment[key] = value
	end
	return luau.load(fs.readFile(path), { environment = environment })()
end

return LoadModule
