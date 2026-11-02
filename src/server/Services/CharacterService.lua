--!strict
-- Builds every player character as R6 so the combat animations use their intended rig.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CharacterService = {}
CharacterService.Priority = 0

local loading: { [Player]: boolean } = {}
local warned: { [string]: boolean } = {}
local rng = Random.new()
local loadWithRetry: (Player, boolean?) -> ()

local function warnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[EtherBlades] " .. message)
end

local function defaultSpawnCFrame(): CFrame
	local hub = Workspace:FindFirstChild("Hub")
	local hubSpawn = hub and hub:FindFirstChild("HubSpawn", true)
	if hubSpawn and hubSpawn:IsA("BasePart") then
		local offset = Vector3.new(rng:NextNumber(-6, 6), 4, rng:NextNumber(-6, 6))
		return CFrame.new(hubSpawn.Position + offset) * hubSpawn.CFrame.Rotation
	end

	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawnLocation then
		return spawnLocation.CFrame + Vector3.new(0, 4, 0)
	end

	warnOnce("spawn", "Point de réapparition R6 introuvable ; position de secours utilisée.")
	return CFrame.new(0, 8, 0)
end

local function isAliveR6(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6 and humanoid.Health > 0
end

local function loadCharacter(player: Player, spawnCFrame: CFrame?, forceReload: boolean): (boolean, string?)
	if player.Parent ~= Players then
		return false, "Le joueur a quitté le serveur."
	end
	if loading[player] then
		return false, "Le chargement du personnage est déjà en cours."
	end
	if not forceReload and isAliveR6(player) then
		return true, nil
	end

	loading[player] = true
	local okDescription, descriptionOrError = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, player.UserId)
	if not okDescription then
		loading[player] = nil
		return false, "Impossible de charger l'apparence : " .. tostring(descriptionOrError)
	end

	local description = descriptionOrError :: HumanoidDescription
	local okModel, modelOrError = pcall(
		Players.CreateHumanoidModelFromDescriptionAsync,
		Players,
		description,
		Enum.HumanoidRigType.R6
	)
	description:Destroy()
	if not okModel then
		loading[player] = nil
		return false, "Impossible de créer le personnage R6 : " .. tostring(modelOrError)
	end

	local character = modelOrError :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 or not (root and root:IsA("BasePart")) then
		character:Destroy()
		loading[player] = nil
		return false, "Roblox a renvoyé un personnage incomplet au lieu d'un rig R6."
	end
	if player.Parent ~= Players then
		character:Destroy()
		loading[player] = nil
		return false, "Le joueur a quitté le serveur pendant la création du personnage."
	end

	character.Name = player.Name
	character:PivotTo(spawnCFrame or defaultSpawnCFrame())
	humanoid.DisplayName = player.DisplayName
	humanoid.Died:Connect(function()
		task.delay(Players.RespawnTime, function()
			if player.Parent == Players and player.Character == character and player:GetAttribute("EB_InMatch") ~= true then
				task.spawn(loadWithRetry, player, true)
			end
		end)
	end)

	local previousCharacter = player.Character
	character.Parent = Workspace
	player.Character = character
	if previousCharacter and previousCharacter ~= character then
		previousCharacter:Destroy()
	end
	loading[player] = nil
	return true, nil
end

function CharacterService.loadCharacter(player: Player, spawnCFrame: CFrame?, forceReload: boolean?): (boolean, string?)
	return loadCharacter(player, spawnCFrame, forceReload == true)
end

loadWithRetry = function(player: Player, forceReload: boolean?)
	for attempt = 1, 3 do
		if player.Parent ~= Players then
			return
		end
		local ok, reason = CharacterService.loadCharacter(player, nil, forceReload)
		if ok then
			return
		end
		if reason then
			warn(string.format("[EtherBlades] Chargement R6 de %s (%d/3) : %s", player.Name, attempt, reason))
		end
		if attempt < 3 then
			task.wait(2)
		end
	end
end

local function onPlayerAdded(player: Player)
	task.spawn(loadWithRetry, player)
end

function CharacterService.init()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		loading[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CharacterService
