--!strict
--[[
	Identité serveur = nom du jeu (Blade Concord).
	Attributs DataModel + marqueur Workspace pour HUD / debug Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared"):WaitForChild("Theme"))

local SERVER_NAME = Theme.Brand -- "Blade Concord"

game:SetAttribute("GameName", SERVER_NAME)
game:SetAttribute("ServerName", SERVER_NAME)
game:SetAttribute("PlaceDisplayName", SERVER_NAME)

local marker = workspace:FindFirstChild("BC_ServerName")
if marker == nil then
	marker = Instance.new("StringValue")
	marker.Name = "BC_ServerName"
	marker.Parent = workspace
end
marker.Value = SERVER_NAME

print(string.format("[BladeConcord] Nom de serveur = %s", SERVER_NAME))
