--!strict
-- HitValidation : validation serveur des coups (portée, angle, ligne de vue) avec compensation de latence.
-- Le serveur échantillonne à chaque Heartbeat la position du HumanoidRootPart de chaque joueur et de chaque
-- mannequin enregistré, dans un tampon circulaire préalloué (~1,2 s d'historique, aucune allocation par frame).
-- `canHit` rembobine la cible à l'instant vu par l'attaquant (borné à 250 ms et au ping réel) puis vérifie
-- distance, arc et absence de mur entre les deux.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Maid = require(Shared.Util.Maid)

type Maid = Maid.Maid

--------------------------------------------------------------------------------
-- Réglages

local BUFFER_SIZE = 72 -- échantillons conservés (72 à 60 Hz ≈ 1,2 s)
local MIN_SAMPLE_INTERVAL = 1 / 65 -- évite de saturer le tampon si le Heartbeat tourne plus vite que 60 Hz
local MAX_REWIND = 0.25 -- s : compensation de latence maximale (contrat)
local REWIND_SLACK = 0.06 -- s : marge ajoutée au ping aller-retour avant de borner le rembobinage
local TELEPORT_RESET = 20 -- studs entre deux échantillons : téléportation, l'historique repart de zéro
local BASE_TOLERANCE = 2.5 -- studs : demi-largeur du corps visé + longueur de garde de la lame
local SPEED_TOLERANCE_FACTOR = 0.1 -- s : marge de distance proportionnelle aux vitesses cumulées
local MAX_SPEED_TOLERANCE = 4 -- studs : plafond de cette marge
local ANGLE_TOLERANCE_DEG = 20 -- ° ajoutés de chaque côté de l'arc (orientation serveur en retard sur le client)
local ANGLE_MIN_DIST = 2.5 -- studs : en dessous, les corps se chevauchent et l'angle n'a plus de sens
local HEAD_OFFSET = Vector3.new(0, 1.5, 0) -- deuxième rayon à hauteur de tête si le premier est bloqué
local ROOT_TIMEOUT = 10 -- s : attente maximale du HumanoidRootPart d'un modèle

--------------------------------------------------------------------------------
-- État

type Track = {
	Model: Model,
	Root: BasePart,
	Times: { number },
	Positions: { Vector3 },
	Head: number, -- index du dernier échantillon écrit (1..BUFFER_SIZE)
	Count: number, -- nombre d'échantillons valides
	Maid: Maid,
}

local HitValidation = {}
HitValidation.Priority = 5

local tracks: { [Model]: Track } = {}
local pendingNpcs: { [Model]: boolean } = {}
local playerMaids: { [Player]: Maid } = {}
local lastSample = -math.huge

-- Filtre des rayons de ligne de vue : tous les modèles suivis (personnages + mannequins).
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true
losParams.RespectCanCollide = true
local filterDirty = true

local function isFinite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function refreshFilter()
	if not filterDirty then
		return
	end
	filterDirty = false
	local list: { Instance } = table.create(16)
	for model in tracks do
		table.insert(list, model)
	end
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c and tracks[c] == nil then
			table.insert(list, c)
		end
	end
	losParams.FilterDescendantsInstances = list
end

--------------------------------------------------------------------------------
-- Suivi des modèles

local function removeTrack(model: Model)
	local tr = tracks[model]
	if tr then
		tracks[model] = nil
		filterDirty = true
		tr.Maid:Destroy()
	end
end

local function addTrack(model: Model, root: BasePart)
	removeTrack(model)
	local maid = Maid.new()
	local tr: Track = {
		Model = model,
		Root = root,
		Times = table.create(BUFFER_SIZE, 0),
		Positions = table.create(BUFFER_SIZE, Vector3.zero),
		Head = 0,
		Count = 0,
		Maid = maid,
	}
	tracks[model] = tr
	filterDirty = true
	-- Nettoyage automatique : modèle détruit ou retiré du jeu, racine détruite.
	maid:Give(model.Destroying:Connect(function()
		removeTrack(model)
	end))
	maid:Give(model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			removeTrack(model)
		end
	end))
	maid:Give(root.Destroying:Connect(function()
		removeTrack(model)
	end))
end

-- Racine d'un modèle : HumanoidRootPart, sinon PrimaryPart. Peut attendre (à appeler dans un thread).
local function resolveRoot(model: Model, timeout: number): BasePart?
	local found = model:FindFirstChild("HumanoidRootPart")
	if found == nil then
		found = model:WaitForChild("HumanoidRootPart", timeout)
	end
	if found and found:IsA("BasePart") then
		return found :: BasePart
	end
	return model.PrimaryPart
end

--------------------------------------------------------------------------------
-- Échantillonnage (Heartbeat) : aucune allocation, Vector3 est un type valeur.

local function sample()
	local now = workspace:GetServerTimeNow()
	if now - lastSample < MIN_SAMPLE_INTERVAL then
		return
	end
	lastSample = now
	for _, tr in tracks do
		local root = tr.Root
		if root.Parent ~= nil then
			local pos = root.Position
			local head = tr.Head
			if tr.Count > 0 and (pos - tr.Positions[head]).Magnitude > TELEPORT_RESET then
				tr.Count = 0 -- téléportation (spawn d'arène, remise en place) : l'ancien historique est caduc
			end
			head = head % BUFFER_SIZE + 1
			tr.Head = head
			tr.Times[head] = now
			tr.Positions[head] = pos
			if tr.Count < BUFFER_SIZE then
				tr.Count += 1
			end
		end
	end
end

-- Position interpolée d'une piste à l'instant `t` (temps serveur). Jamais au-delà du dernier échantillon.
local function positionAt(tr: Track, t: number): Vector3
	local count = tr.Count
	if count == 0 then
		return tr.Root.Position
	end
	local idx = tr.Head
	local newerT = tr.Times[idx]
	local newerP = tr.Positions[idx]
	if t >= newerT then
		return tr.Root.Position
	end
	for _ = 2, count do
		idx = (idx - 2) % BUFFER_SIZE + 1
		local olderT = tr.Times[idx]
		local olderP = tr.Positions[idx]
		if olderT <= t then
			local span = newerT - olderT
			local alpha = if span > 1e-6 then (t - olderT) / span else 1
			return olderP:Lerp(newerP, alpha)
		end
		newerT = olderT
		newerP = olderP
	end
	return newerP -- plus ancien échantillon disponible
end

-- Ligne de vue entre deux points : rien de collidable hors personnages / mannequins.
local function clearLine(from: Vector3, to: Vector3, targetModel: Instance?): boolean
	local dir = to - from
	if dir.Magnitude < 1e-3 then
		return true
	end
	local hit = workspace:Raycast(from, dir, losParams)
	if hit == nil then
		return true
	end
	return targetModel ~= nil and hit.Instance:IsDescendantOf(targetModel)
end

local function hasLineOfSight(from: Vector3, to: Vector3, targetModel: Instance?): boolean
	return clearLine(from, to, targetModel) or clearLine(from + HEAD_OFFSET, to + HEAD_OFFSET, targetModel)
end

--------------------------------------------------------------------------------
-- API publique

-- Vrai si `attacker` peut légitimement toucher `targetRoot` avec une arme de portée `reach` (studs)
-- couvrant `arcDeg` degrés (360 = tout autour). `clientTime` = workspace:GetServerTimeNow() côté client
-- au moment du coup ; sans lui, la position actuelle de la cible est utilisée.
function HitValidation.canHit(attacker: Player, targetRoot: BasePart, reach: number, arcDeg: number, clientTime: number?): boolean
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
		return false
	end
	if typeof(targetRoot) ~= "Instance" or not targetRoot:IsA("BasePart") then
		return false
	end
	if type(reach) ~= "number" or not isFinite(reach) or reach <= 0 then
		return false
	end
	if type(arcDeg) ~= "number" or not isFinite(arcDeg) or arcDeg <= 0 then
		return false
	end
	local character = attacker.Character
	if character == nil or character.Parent == nil then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local rootInst = character:FindFirstChild("HumanoidRootPart")
	if rootInst == nil or not rootInst:IsA("BasePart") then
		return false
	end
	local attackerRoot = rootInst :: BasePart
	if targetRoot:IsDescendantOf(character) or not targetRoot:IsDescendantOf(workspace) then
		return false
	end

	-- Instant visé : borné par la compensation maximale et par le ping réel, jamais dans le futur.
	local now = workspace:GetServerTimeNow()
	local t = now
	if type(clientTime) == "number" and isFinite(clientTime) then
		local maxRewind = math.min(MAX_REWIND, attacker:GetNetworkPing() * 2 + REWIND_SLACK)
		t = math.clamp(clientTime, now - maxRewind, now)
	end

	local parent = targetRoot.Parent
	local targetModel: Model? = if parent and parent:IsA("Model") then parent :: Model else nil
	local tr = if targetModel then tracks[targetModel] else nil
	local targetPos = if tr and tr.Root == targetRoot then positionAt(tr, t) else targetRoot.Position
	local attackerPos = attackerRoot.Position

	-- Distance : portée + tolérance qui croît avec les vitesses (interpolation, retard de l'attaquant).
	local speeds = attackerRoot.AssemblyLinearVelocity.Magnitude + targetRoot.AssemblyLinearVelocity.Magnitude
	local maxDist = reach + BASE_TOLERANCE + math.min(MAX_SPEED_TOLERANCE, speeds * SPEED_TOLERANCE_FACTOR)
	local delta = targetPos - attackerPos
	if delta.Magnitude > maxDist then
		return false
	end

	-- Angle : arc horizontal centré sur le LookVector de l'attaquant.
	if arcDeg < 360 then
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local flatDist = flat.Magnitude
		if flatDist > ANGLE_MIN_DIST then
			local halfDeg = arcDeg * 0.5 + ANGLE_TOLERANCE_DEG
			if halfDeg < 180 then
				local look = attackerRoot.CFrame.LookVector
				local lookFlat = Vector3.new(look.X, 0, look.Z)
				local lookMag = lookFlat.Magnitude
				if lookMag > 1e-3 then
					local cosAngle = lookFlat:Dot(flat) / (lookMag * flatDist)
					if cosAngle < math.cos(math.rad(halfDeg)) then
						return false
					end
				end
			end
		end
	end

	-- Ligne de vue : vers la position rembobinée ou, à défaut, vers la position actuelle.
	refreshFilter()
	if hasLineOfSight(attackerPos, targetPos, targetModel) then
		return true
	end
	return hasLineOfSight(attackerPos, targetRoot.Position, targetModel)
end

-- Suit aussi un mannequin (ou tout PNJ). Sans effet si le modèle est déjà suivi.
function HitValidation.recordNpc(model: Model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	if tracks[model] or pendingNpcs[model] then
		return
	end
	pendingNpcs[model] = true
	task.spawn(function()
		local root = resolveRoot(model, ROOT_TIMEOUT)
		pendingNpcs[model] = nil
		if root and model.Parent ~= nil and root:IsDescendantOf(model) then
			addTrack(model, root)
		else
			warn(string.format("[EtherBlades][HitValidation] mannequin %s sans racine : non suivi", model:GetFullName()))
		end
	end)
end

-- Oublie l'historique d'un modèle (après une téléportation scriptée par exemple).
function HitValidation.clearHistory(model: Model)
	local tr = tracks[model]
	if tr then
		tr.Count = 0
	end
end

--------------------------------------------------------------------------------
-- Cycle de vie

local function onPlayerAdded(player: Player)
	if playerMaids[player] then
		return
	end
	local maid = Maid.new()
	playerMaids[player] = maid

	local function onCharacter(character: Model)
		maid:Set("Track", nil) -- retire la piste de l'ancien personnage
		maid:Set("Wait", task.spawn(function()
			local root = resolveRoot(character, ROOT_TIMEOUT)
			if root and player.Character == character then
				addTrack(character, root)
				maid:Set("Track", function()
					removeTrack(character)
				end)
			end
		end))
	end

	maid:Give(player.CharacterAdded:Connect(onCharacter))
	maid:Give(player.CharacterRemoving:Connect(function()
		maid:Set("Wait", nil)
		maid:Set("Track", nil)
	end))
	local current = player.Character
	if current then
		onCharacter(current)
	end
end

local function onPlayerRemoving(player: Player)
	local maid = playerMaids[player]
	if maid then
		playerMaids[player] = nil
		maid:Destroy()
	end
	filterDirty = true
end

function HitValidation.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
	RunService.Heartbeat:Connect(sample)
end

return HitValidation
