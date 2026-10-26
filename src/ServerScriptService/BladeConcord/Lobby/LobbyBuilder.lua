--!strict
--[[
	Concord Hall — construction serveur procédurale (~360×360).
	API :
	  LobbyBuilder.ensure(parentFolder) → Model ConcordLobby
	  LobbyBuilder.getSpawnCFrame() → CFrame plaza
	  LobbyBuilder.applyLobbyLighting()
	  LobbyBuilder.bindQueuePads(enqueueFn) — enqueueFn(player, mode)

	Attributs client (voir LobbyConfig header) :
	  Workspace.Arenas.ConcordLobby attributes + pads BC_QueueMode.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local RankedConfig = require(Shared:WaitForChild("RankedConfig"))
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))

local LobbyConfig = require(script.Parent:WaitForChild("LobbyConfig"))
local LobbyUtil = require(script.Parent:WaitForChild("LobbyUtil"))
local LobbyLighting = require(script.Parent:WaitForChild("LobbyLighting"))
local LobbyProps = require(script.Parent:WaitForChild("LobbyProps"))

local LobbyBuilder = {}

local built: Model? = nil
local animConn: RBXScriptConnection? = nil
local padBound = false
local leaderboardRefresh: thread? = nil

local C = LobbyConfig.Colors
local Z = LobbyConfig.Zones

local function octagonFloor(
	parent: Instance,
	radius: number,
	y: number,
	color: Color3,
	material: Enum.Material,
	thickness: number?
)
	-- Approximation : disque + 8 dalles radialement
	local t = thickness or 2
	LobbyUtil.part(
		"PlazaCore",
		Vector3.new(radius * 1.1, t, radius * 1.1),
		LobbyUtil.cf(Vector3.new(0, y, 0)),
		color,
		parent,
		material,
		{ reflectance = 0.06 }
	)
	for i = 0, 7 do
		local ang = math.rad(i * 45)
		local dist = radius * 0.72
		local px = math.sin(ang) * dist
		local pz = -math.cos(ang) * dist
		LobbyUtil.part(
			"OctTile" .. i,
			Vector3.new(radius * 0.55, t * 0.5, radius * 0.55),
			LobbyUtil.cf(Vector3.new(px, y + 0.15, pz), i * 45),
			if i % 2 == 0 then C.MarbleLite else C.Ink600,
			parent,
			if i % 2 == 0 then Enum.Material.Marble else Enum.Material.Slate,
			{ reflectance = 0.04 }
		)
	end
end

local function buildFloorShell(root: Model)
	local floor = LobbyUtil.model("HallFloor", root, "Plaza")
	-- Sol principal 360×360
	LobbyUtil.part(
		"Ground",
		Vector3.new(LobbyConfig.HallHalf * 2, 2, LobbyConfig.HallHalf * 2),
		LobbyUtil.cf(Vector3.new(0, -1, 0)),
		C.Ink800,
		floor,
		Enum.Material.Basalt
	)
	-- Anneaux de promenade
	for _, r in { 55, 70, 95, 130 } do
		LobbyUtil.part(
			"Ring" .. r,
			Vector3.new(r * 2, 0.25, r * 2),
			LobbyUtil.cf(Vector3.new(0, 0.15, 0)),
			if r == 70 then C.GoldDark else C.Ink700,
			floor,
			if r == 70 then Enum.Material.Metal else Enum.Material.Concrete,
			{ canCollide = false, transparency = if r == 70 then 0.35 else 0.55, reflectance = 0.1 }
		)
	end
	octagonFloor(floor, LobbyConfig.PlazaRadius, 0, C.Marble, Enum.Material.Marble, 2.2)

	-- Rose des vents Neon Ø30
	local rose = LobbyUtil.part(
		"CompassRose",
		Vector3.new(30, 0.3, 30),
		LobbyUtil.cf(Vector3.new(0, 1.15, 0)),
		C.Focus,
		floor,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.55, castShadow = false }
	)
	if rose then
		LobbyUtil.pointLight(rose, C.Gold, 0.6, 28)
		LobbyUtil.billboard(rose, "CONCORD HALL", C.GoldLite, Vector2.new(260, 40), 8)
	end
	local goldRing = LobbyUtil.part(
		"GoldAnnulus",
		Vector3.new(36, 0.2, 36),
		LobbyUtil.cf(Vector3.new(0, 1.18, 0)),
		C.Gold,
		floor,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.7 }
	)
	goldRing = goldRing

	-- Allées vers pads / forge / formes
	for _, lane in
		{
			{ Vector3.new(0, 0.2, -50), Vector3.new(24, 0.35, 90), 0 },
			{ Vector3.new(-55, 0.2, 40), Vector3.new(80, 0.35, 18), 35 },
			{ Vector3.new(55, 0.2, 40), Vector3.new(80, 0.35, 18), -35 },
			{ Vector3.new(-70, 0.2, -5), Vector3.new(90, 0.35, 16), 90 },
			{ Vector3.new(70, 0.2, -5), Vector3.new(90, 0.35, 16), 90 },
			{ Vector3.new(0, 0.2, 70), Vector3.new(20, 0.35, 70), 0 },
		}
	do
		LobbyUtil.part(
			"Lane",
			lane[2] :: Vector3,
			LobbyUtil.cf(lane[1] :: Vector3, lane[3] :: number),
			C.Ink600,
			floor,
			Enum.Material.Slate,
			{ canCollide = false, transparency = 0.25 }
		)
	end
end

local function buildColonnade(root: Model)
	local colo = LobbyUtil.model("Colonnade", root)
	local R = LobbyConfig.ColonnadeRadius
	local n = LobbyConfig.ColumnCount
	for i = 0, n - 1 do
		local ang = (i / n) * math.pi * 2
		local x = math.sin(ang) * R
		local z = -math.cos(ang) * R
		LobbyProps.column(colo, Vector3.new(x, 0, z), LobbyConfig.ColumnHeight, math.deg(ang))
		-- Bannières entre colonnes (1 sur 2)
		if i % 2 == 0 then
			local midAng = ((i + 0.5) / n) * math.pi * 2
			local bx = math.sin(midAng) * (R - 4)
			local bz = -math.cos(midAng) * (R - 4)
			local col = if i % 4 == 0 then C.Dawn else C.Dusk
			LobbyProps.banner(colo, Vector3.new(bx, 0, bz), col, 22, math.deg(midAng))
		end
	end
	-- Arches nord (vers pads / galerie)
	LobbyProps.arch(colo, Vector3.new(0, 0, -118), 36, 28, 0)
	LobbyProps.arch(colo, Vector3.new(-90, 0, -40), 28, 24, 55)
	LobbyProps.arch(colo, Vector3.new(90, 0, -40), 28, 24, -55)
end

local function makeQueuePad(
	parent: Instance,
	localPos: Vector3,
	mode: "Casual" | "Ranked",
	color: Color3,
	label: string
): BasePart?
	local zone = LobbyUtil.model("Pad_" .. mode, parent, "Pads")
	LobbyProps.stairs(zone, localPos + Vector3.new(0, 0, 12), 3, 16, 0)

	local platform = LobbyUtil.part(
		"Platform",
		Vector3.new(LobbyConfig.PadRadius * 2, 1.2, LobbyConfig.PadRadius * 2),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 0.6, 0)),
		C.Ink700,
		zone,
		Enum.Material.Slate,
		{ reflectance = 0.08 }
	)
	local pad = LobbyUtil.part(
		"QueuePad",
		Vector3.new(LobbyConfig.PadRadius * 1.7, 0.35, LobbyConfig.PadRadius * 1.7),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 1.25, 0)),
		color,
		zone,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.35, castShadow = false }
	)
	if not pad then
		return nil
	end
	pad:SetAttribute("BC_QueueMode", mode)
	LobbyUtil.tag(pad, LobbyConfig.Tags.QueuePad)

	local ring = LobbyUtil.part(
		"Ring",
		Vector3.new(LobbyConfig.PadRadius * 2.1, 0.2, LobbyConfig.PadRadius * 2.1),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 1.3, 0)),
		color,
		zone,
		Enum.Material.Neon,
		{ canCollide = false, transparency = 0.65 }
	)
	ring = ring

	local beam = LobbyUtil.part(
		"LightColumn",
		Vector3.new(2.5, 40, 2.5),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 22, 0)),
		color,
		zone,
		Enum.Material.ForceField,
		{ canCollide = false, transparency = 0.72, castShadow = false }
	)
	if beam then
		LobbyUtil.pointLight(beam, color, 1.6, 36)
		LobbyUtil.tag(beam, LobbyConfig.Tags.PortalPulse)
	end

	LobbyUtil.emitter(pad, "PadEnergy", {
		rate = 6,
		lifetime = NumberRange.new(1, 2.2),
		speed = NumberRange.new(1, 3),
		accel = Vector3.new(0, 6, 0),
		color = ColorSequence.new(color, C.Bone),
		lightEmission = 0.8,
	})

	LobbyUtil.billboard(pad, label, color, Vector2.new(200, 40), 6)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QueuePrompt"
	prompt.ActionText = if mode == "Casual" then "File Amical" else "File Classé"
	prompt.ObjectText = label
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = pad

	-- Volume touch (mobile)
	local touch = LobbyUtil.part(
		"TouchVolume",
		Vector3.new(LobbyConfig.PadRadius * 2.2, 6, LobbyConfig.PadRadius * 2.2),
		LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 3.5, 0)),
		color,
		zone,
		Enum.Material.ForceField,
		{ canCollide = false, transparency = 1, castShadow = false }
	)
	if touch then
		touch:SetAttribute("BC_QueueMode", mode)
		LobbyUtil.tag(touch, LobbyConfig.Tags.QueuePad)
	end

	if platform then
		LobbyUtil.part(
			"AccentInlay",
			Vector3.new(6, 0.2, 6),
			LobbyUtil.cf(localPos + Vector3.new(0, LobbyConfig.PadRaise + 1.35, 0)),
			C.Gold,
			zone,
			Enum.Material.Metal,
			{ canCollide = false, reflectance = 0.35, transparency = 0.2 }
		)
	end
	return pad
end

local function buildPads(root: Model)
	makeQueuePad(root, Z.PadCasual, "Casual", C.Focus, "AMICAL")
	makeQueuePad(root, Z.PadRanked, "Ranked", C.Gold, "CLASSÉ — Fair Kit")
end

local function buildSpawns(root: Model)
	local spawns = LobbyUtil.model("Spawns", root, "Plaza")
	local spots = {
		Vector3.new(0, 2, 2),
		Vector3.new(6, 2, -2),
		Vector3.new(-6, 2, -2),
		Vector3.new(0, 2, -6),
	}
	for i, pos in spots do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = if i == 1 then "LobbySpawn" else ("LobbySpawnReserve" .. (i - 1))
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = LobbyUtil.cf(pos) * CFrame.Angles(0, math.rad(180), 0) -- face nord (pads)
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 4 -- ForceField
		spawn.Neutral = true
		spawn.Enabled = true
		spawn.Parent = spawns
	end
end

local function buildFaction(root: Model, side: "Dawn" | "Dusk")
	local isDawn = side == "Dawn"
	local center = if isDawn then Z.Dawn else Z.Dusk
	local accent = if isDawn then C.Dawn else C.Dusk
	local deep = if isDawn then C.DawnDeep else C.DuskDeep
	local title = if isDawn then "ORDRE DE L'AUBE" else "VOIE DU CRÉPUSCULE"
	local zone = LobbyUtil.model("Faction_" .. side, root, side)

	LobbyUtil.part(
		"AlcovesFloor",
		Vector3.new(55, 1.5, 55),
		LobbyUtil.cf(center + Vector3.new(0, 0.2, 0)),
		deep,
		zone,
		Enum.Material.Slate
	)
	-- Statue (soleil / croissant simplifié)
	if isDawn then
		local sun = LobbyUtil.part(
			"SunStatue",
			Vector3.new(10, 10, 3),
			LobbyUtil.cf(center + Vector3.new(-8, 12, 0)),
			accent,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, shape = Enum.PartType.Cylinder, transparency = 0.15 }
		)
		if sun then
			sun.CFrame = LobbyUtil.cf(center + Vector3.new(-8, 12, 0), 90) * CFrame.Angles(0, 0, math.rad(90))
			LobbyUtil.pointLight(sun, accent, 1.3, 30)
		end
	else
		local moon = LobbyUtil.part(
			"MoonStatue",
			Vector3.new(9, 9, 2.5),
			LobbyUtil.cf(center + Vector3.new(8, 12, 0)),
			accent,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, shape = Enum.PartType.Ball, transparency = 0.2 }
		)
		if moon then
			LobbyUtil.pointLight(moon, accent, 1.2, 28)
			LobbyUtil.part(
				"CrescentCut",
				Vector3.new(6, 6, 3),
				LobbyUtil.cf(center + Vector3.new(10, 13, 0)),
				deep,
				zone,
				Enum.Material.SmoothPlastic,
				{ canCollide = false, shape = Enum.PartType.Ball }
			)
		end
	end

	LobbyProps.banner(
		zone,
		center + Vector3.new(if isDawn then 10 else -10, 0, -18),
		accent,
		26,
		if isDawn then 90 else -90
	)
	LobbyProps.banner(
		zone,
		center + Vector3.new(if isDawn then 10 else -10, 0, 18),
		accent,
		26,
		if isDawn then 90 else -90
	)
	LobbyProps.column(zone, center + Vector3.new(if isDawn then 18 else -18, 0, -22), 28)
	LobbyProps.column(zone, center + Vector3.new(if isDawn then 18 else -18, 0, 22), 28)

	local host = LobbyUtil.part(
		"FactionLabel",
		Vector3.new(1, 1, 1),
		LobbyUtil.cf(center + Vector3.new(0, 8, 0)),
		accent,
		zone,
		Enum.Material.ForceField,
		{ transparency = 1, canCollide = false }
	)
	if host then
		LobbyUtil.billboard(host, title, accent, Vector2.new(280, 40), 0)
	end

	-- Barre Score de Guerre (SurfaceGui simple)
	local board = LobbyUtil.part(
		"WarScoreBoard",
		Vector3.new(18, 8, 0.6),
		LobbyUtil.cf(center + Vector3.new(if isDawn then 5 else -5, 8, -28), if isDawn then 20 else -20),
		C.Ink700,
		zone,
		Enum.Material.Metal
	)
	if board and LobbyUtil.noteSurfaceGui() then
		local sg = Instance.new("SurfaceGui")
		sg.Name = "WarScoreGui"
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 20
		sg.Parent = board
		board:SetAttribute("BC_LeaderboardKind", "Faction")
		local frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = C.Ink900
		frame.BackgroundTransparency = 0.2
		frame.Parent = sg
		local titleLbl = Instance.new("TextLabel")
		titleLbl.Name = "Title"
		titleLbl.Size = UDim2.new(1, -16, 0, 36)
		titleLbl.Position = UDim2.fromOffset(8, 8)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextSize = 22
		titleLbl.TextColor3 = accent
		titleLbl.Text = "Score de Guerre"
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Parent = frame
		local scoreLbl = Instance.new("TextLabel")
		scoreLbl.Name = "Score"
		scoreLbl.Size = UDim2.new(1, -16, 0, 48)
		scoreLbl.Position = UDim2.fromOffset(8, 50)
		scoreLbl.BackgroundTransparency = 1
		scoreLbl.Font = Enum.Font.GothamBlack
		scoreLbl.TextSize = 36
		scoreLbl.TextColor3 = C.Bone
		scoreLbl.Text = "—"
		scoreLbl.TextXAlignment = Enum.TextXAlignment.Left
		scoreLbl.Parent = frame
	end
end

local function buildLeaderboardWall(root: Model)
	local zone = LobbyUtil.model("Leaderboards", root, "Leaderboard")
	for _, spec in
		{
			{ pos = Z.LeaderboardElo, kind = "Elo", title = "CLASSEMENT ELO", color = C.Focus },
			{ pos = Z.LeaderboardFaction, kind = "FactionTop", title = "SCORE FACTION", color = C.Arcane },
		}
	do
		local wall = LobbyUtil.part(
			"Board_" .. spec.kind,
			Vector3.new(28, 18, 1.2),
			LobbyUtil.cf(spec.pos + Vector3.new(0, 12, 0), if spec.pos.X < 0 then 35 else -35),
			C.Ink700,
			zone,
			Enum.Material.Metal,
			{ reflectance = 0.1 }
		)
		if not wall then
			continue
		end
		local neon = LobbyUtil.part(
			"FrameNeon",
			Vector3.new(29, 19, 0.3),
			wall.CFrame * CFrame.new(0, 0, -0.6),
			spec.color,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, transparency = 0.4 }
		)
		if neon then
			LobbyUtil.pointLight(neon, spec.color, 0.5, 16)
		end
		if LobbyUtil.noteSurfaceGui() then
			local sg = Instance.new("SurfaceGui")
			sg.Name = "LeaderboardGui"
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 25
			sg.Parent = wall
			wall:SetAttribute("BC_LeaderboardKind", spec.kind)
			local frame = Instance.new("Frame")
			frame.Name = "Frame"
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = C.Ink900
			frame.BackgroundTransparency = 0.15
			frame.Parent = sg
			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.Size = UDim2.new(1, -20, 0, 40)
			title.Position = UDim2.fromOffset(10, 8)
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.GothamBlack
			title.TextSize = 26
			title.TextColor3 = spec.color
			title.Text = spec.title
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = frame
			local list = Instance.new("TextLabel")
			list.Name = "Rows"
			list.Size = UDim2.new(1, -20, 1, -60)
			list.Position = UDim2.fromOffset(10, 52)
			list.BackgroundTransparency = 1
			list.Font = Enum.Font.GothamMedium
			list.TextSize = 18
			list.TextColor3 = C.Bone
			list.TextXAlignment = Enum.TextXAlignment.Left
			list.TextYAlignment = Enum.TextYAlignment.Top
			list.Text = "Chargement…"
			list.Parent = frame
		end
		LobbyProps.stairs(zone, spec.pos + Vector3.new(0, 0, 14), 3, 20, 0)
	end
end

local function buildForms(root: Model)
	local zone = LobbyUtil.model("FormsShowcase", root, "Forms")
	LobbyUtil.part(
		"Floor",
		Vector3.new(60, 1.5, 50),
		LobbyUtil.cf(Z.Forms + Vector3.new(0, 0.2, 0)),
		C.Ink700,
		zone,
		Enum.Material.Marble
	)
	LobbyProps.neonPortal(zone, Z.Forms + Vector3.new(0, 0, -22), C.Arcane, "VITRINE DES FORMES", 0)
	local spacing = 12
	local startX = -spacing * 1.5
	for i, form in LobbyConfig.FormsShowcase do
		local pos = Z.Forms + Vector3.new(startX + (i - 1) * spacing, 0, 4)
		LobbyProps.pedestalSaber(zone, pos, form.id, form.color)
	end
	LobbyProps.crystal(zone, Z.Forms + Vector3.new(-22, 0, -8), C.Focus, 1.2)
	LobbyProps.crystal(zone, Z.Forms + Vector3.new(22, 0, -8), C.Arcane, 1.2)
end

local function buildForge(root: Model)
	local zone = LobbyUtil.model("Forge", root, "Forge")
	LobbyUtil.part(
		"Floor",
		Vector3.new(60, 1.5, 50),
		LobbyUtil.cf(Z.Forge + Vector3.new(0, 0.2, 0)),
		C.DawnDeep,
		zone,
		Enum.Material.Basalt
	)
	LobbyUtil.part(
		"Anvil",
		Vector3.new(5, 2.5, 3),
		LobbyUtil.cf(Z.Forge + Vector3.new(0, 2, 0)),
		C.Steel,
		zone,
		Enum.Material.Metal,
		{ reflectance = 0.25 }
	)
	LobbyProps.brazier(zone, Z.Forge + Vector3.new(-14, 0, 8), C.Forge, true)
	LobbyProps.brazier(zone, Z.Forge + Vector3.new(14, 0, 8), C.Forge, false)
	LobbyProps.brazier(zone, Z.Forge + Vector3.new(0, 0, -14), C.Lava, false)

	-- Rack de sabres
	for i = 1, 5 do
		local x = -16 + i * 6
		LobbyUtil.part(
			"RackBlade" .. i,
			Vector3.new(0.3, 4.5, 0.15),
			LobbyUtil.cf(Z.Forge + Vector3.new(x, 5, 18)),
			if i % 2 == 0 then C.Focus else C.Gold,
			zone,
			Enum.Material.Neon,
			{ canCollide = false }
		)
		LobbyUtil.part(
			"RackHilt" .. i,
			Vector3.new(0.4, 1.2, 0.4),
			LobbyUtil.cf(Z.Forge + Vector3.new(x, 2.5, 18)),
			C.Steel,
			zone,
			Enum.Material.Metal,
			{ canCollide = false }
		)
	end

	local counter = LobbyUtil.part(
		"ForgeCounter",
		Vector3.new(16, 3, 4),
		LobbyUtil.cf(Z.Forge + Vector3.new(0, 2, -18)),
		C.Ink600,
		zone,
		Enum.Material.Wood
	)
	if counter then
		LobbyUtil.billboard(counter, "LA FORGE — Cosmétiques", C.Forge, Vector2.new(260, 36), 4)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ouvrir La Forge"
		prompt.ObjectText = "Boutique"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = counter
		counter:SetAttribute("BC_OpenPanel", "Forge")
	end
	LobbyProps.column(zone, Z.Forge + Vector3.new(-24, 0, -18), 22)
	LobbyProps.column(zone, Z.Forge + Vector3.new(24, 0, -18), 22)
end

local function buildQuests(root: Model)
	local zone = LobbyUtil.model("Quests", root, "Quests")
	local board = LobbyUtil.part(
		"QuestBoard",
		Vector3.new(22, 12, 1),
		LobbyUtil.cf(Z.Quests + Vector3.new(0, 8, 0)),
		Color3.fromRGB(90, 60, 40),
		zone,
		Enum.Material.Wood
	)
	if board then
		LobbyUtil.billboard(board, "QUÊTES", C.Gold, Vector2.new(160, 32), 8)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Voir les quêtes"
		prompt.ObjectText = "Tableau"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = board
		board:SetAttribute("BC_OpenPanel", "Quests")
	end
	local chest = LobbyUtil.part(
		"DailyChest",
		Vector3.new(4, 3, 3),
		LobbyUtil.cf(Z.Quests + Vector3.new(12, 2, 6)),
		C.GoldDark,
		zone,
		Enum.Material.Metal,
		{ reflectance = 0.2 }
	)
	if chest then
		LobbyUtil.part(
			"ChestGlow",
			Vector3.new(3.2, 0.4, 2.2),
			LobbyUtil.cf(Z.Quests + Vector3.new(12, 3.4, 6)),
			C.Gold,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, transparency = 0.3 }
		)
	end
end

local function buildTraining(root: Model)
	local zone = LobbyUtil.model("TrainingYard", root, "Training")
	LobbyUtil.part(
		"YardFloor",
		Vector3.new(80, 1.5, 50),
		LobbyUtil.cf(Z.Training + Vector3.new(0, 0.2, 0)),
		C.Ink700,
		zone,
		Enum.Material.Concrete
	)
	for i = 1, 4 do
		local x = -24 + (i - 1) * 16
		LobbyProps.mannequin(zone, Z.Training + Vector3.new(x, 0, 0), if i % 2 == 0 then C.Focus else C.Dawn)
	end
	local trainLabel = LobbyUtil.part(
		"TrainLabel",
		Vector3.new(1, 1, 1),
		LobbyUtil.cf(Z.Training + Vector3.new(0, 6, -18)),
		C.Bone,
		zone,
		Enum.Material.ForceField,
		{ transparency = 1, canCollide = false }
	)
	if trainLabel then
		LobbyUtil.billboard(trainLabel, "COUR D'ENTRAÎNEMENT", C.Muted, Vector2.new(280, 32), 0)
	end
end

local function buildDiorama(parent: Instance, name: string, localPos: Vector3, kind: string)
	local zone = LobbyUtil.model("Diorama_" .. name, parent, "Diorama" .. name)
	local floorCol = C.Ink800
	local accent = C.Lava
	if kind == "Sanctum" then
		floorCol = C.Sanctum
		accent = C.Gold
	elseif kind == "Mirage" then
		floorCol = C.Mirage
		accent = Color3.fromRGB(140, 220, 230)
	end

	LobbyUtil.part(
		"PitFloor",
		Vector3.new(48, 2, 48),
		LobbyUtil.cf(localPos),
		floorCol,
		zone,
		if kind == "Sanctum" then Enum.Material.Marble else Enum.Material.Basalt
	)
	-- Murs bas
	for _, xz in
		{
			Vector3.new(0, 0, -25),
			Vector3.new(0, 0, 25),
			Vector3.new(-25, 0, 0),
			Vector3.new(25, 0, 0),
		}
	do
		local isX = math.abs(xz.X) > 1
		LobbyUtil.part(
			"Wall",
			if isX then Vector3.new(2, 10, 48) else Vector3.new(48, 10, 2),
			LobbyUtil.cf(localPos + Vector3.new(xz.X, 5, xz.Z)),
			C.Ink700,
			zone,
			Enum.Material.Rock
		)
	end

	if kind == "Obsidian" then
		local lava = LobbyUtil.part(
			"Lava",
			Vector3.new(56, 1, 56),
			LobbyUtil.cf(localPos + Vector3.new(0, -2, 0)),
			C.Lava,
			zone,
			Enum.Material.Neon,
			{ canCollide = false, transparency = 0.2 }
		)
		if lava then
			LobbyUtil.pointLight(lava, C.Lava, 1.5, 40)
			LobbyUtil.emitter(lava, "Ash", {
				rate = 5,
				color = ColorSequence.new(C.Lava, Color3.fromRGB(40, 20, 10)),
				accel = Vector3.new(0, 2, 0),
			})
		end
		for _, c in
			{ Vector3.new(-16, 4, -16), Vector3.new(16, 4, -16), Vector3.new(-16, 4, 16), Vector3.new(16, 4, 16) }
		do
			LobbyUtil.part(
				"Pillar",
				Vector3.new(3, 8, 3),
				LobbyUtil.cf(localPos + c),
				C.Ink600,
				zone,
				Enum.Material.Rock
			)
		end
	elseif kind == "Sanctum" then
		local sun = LobbyUtil.part(
			"Astre",
			Vector3.new(4, 4, 4),
			LobbyUtil.cf(localPos + Vector3.new(-8, 14, 0)),
			C.GoldLite,
			zone,
			Enum.Material.Neon,
			{ shape = Enum.PartType.Ball, canCollide = false }
		)
		local moon = LobbyUtil.part(
			"Astre2",
			Vector3.new(3.2, 3.2, 3.2),
			LobbyUtil.cf(localPos + Vector3.new(8, 13, 0)),
			C.Focus,
			zone,
			Enum.Material.Neon,
			{ shape = Enum.PartType.Ball, canCollide = false }
		)
		if sun then
			LobbyUtil.pointLight(sun, C.Gold, 1.2, 28)
		end
		if moon then
			LobbyUtil.pointLight(moon, C.Focus, 0.9, 24)
		end
		for z = -12, 12, 12 do
			LobbyProps.column(zone, localPos + Vector3.new(-18, 12, z) - Vector3.new(0, 12, 0), 16)
			LobbyProps.column(zone, localPos + Vector3.new(18, 12, z) - Vector3.new(0, 12, 0), 16)
		end
	else -- Mirage
		local water = LobbyUtil.part(
			"Water",
			Vector3.new(60, 1, 50),
			LobbyUtil.cf(localPos + Vector3.new(0, -1.5, 0)),
			accent,
			zone,
			Enum.Material.Glass,
			{ canCollide = false, transparency = 0.4 }
		)
		if water then
			LobbyUtil.pointLight(water, accent, 0.8, 30)
		end
		for x = -18, 18, 12 do
			LobbyUtil.part(
				"Pier",
				Vector3.new(1.2, 5, 1.2),
				LobbyUtil.cf(localPos + Vector3.new(x, 0, -20)),
				Color3.fromRGB(90, 70, 50),
				zone,
				Enum.Material.Wood
			)
		end
	end

	local labelHost = LobbyUtil.part(
		"DioramaTitle",
		Vector3.new(1, 1, 1),
		LobbyUtil.cf(localPos + Vector3.new(0, 16, 0)),
		accent,
		zone,
		Enum.Material.ForceField,
		{ transparency = 1, canCollide = false }
	)
	if labelHost then
		local titles = {
			Obsidian = "Creuset de Lave",
			Sanctum = "Sanctum des Deux Astres",
			Mirage = "Quai Mirage",
		}
		LobbyUtil.billboard(labelHost, titles[kind] or name, accent, Vector2.new(240, 32), 0)
	end
end

local function buildGalleryAndDioramas(root: Model)
	local gallery = LobbyUtil.model("ArenaGallery", root, "Gallery")
	LobbyUtil.part(
		"Balcony",
		Vector3.new(200, 1.5, 18),
		LobbyUtil.cf(Z.Gallery + Vector3.new(0, 8, 0)),
		C.Marble,
		gallery,
		Enum.Material.Marble
	)
	LobbyProps.railing(gallery, Z.Gallery + Vector3.new(-95, 8, -8), Z.Gallery + Vector3.new(95, 8, -8), 3.5)
	local galLabel = LobbyUtil.part(
		"GalLabel",
		Vector3.new(1, 1, 1),
		LobbyUtil.cf(Z.Gallery + Vector3.new(0, 14, 4)),
		C.Bone,
		gallery,
		Enum.Material.ForceField,
		{ transparency = 1, canCollide = false }
	)
	if galLabel then
		LobbyUtil.billboard(galLabel, "GALERIE DES ARÈNES", C.GoldLite, Vector2.new(280, 32), 0)
	end

	local dios = LobbyUtil.model("Dioramas", root)
	buildDiorama(dios, "Obsidian", Z.DioramaObsidian, "Obsidian")
	buildDiorama(dios, "Sanctum", Z.DioramaSanctum, "Sanctum")
	buildDiorama(dios, "Mirage", Z.DioramaMirage, "Mirage")
end

local function buildAmbience(root: Model)
	local amb = LobbyUtil.model("Ambience", root)
	-- Bassins plaza
	LobbyProps.basin(amb, Vector3.new(-40, 0, 40), 10, C.FocusDark)
	LobbyProps.basin(amb, Vector3.new(40, 0, 40), 10, C.Dusk)
	-- Cristaux flottants épars
	for i, pos in
		{
			Vector3.new(-50, 2, -40),
			Vector3.new(50, 2, -40),
			Vector3.new(-20, 1, 50),
			Vector3.new(20, 1, 50),
			Vector3.new(0, 2, -60),
		}
	do
		LobbyProps.crystal(amb, pos, if i % 2 == 0 then C.Focus else C.Arcane, 0.9 + (i % 3) * 0.15)
	end
	-- Poussière / god-ray host
	local dustHost = LobbyUtil.part(
		"DustHost",
		Vector3.new(80, 1, 80),
		LobbyUtil.cf(Vector3.new(0, 12, 0)),
		C.Bone,
		amb,
		Enum.Material.ForceField,
		{ transparency = 1, canCollide = false, castShadow = false }
	)
	if dustHost then
		LobbyUtil.tag(dustHost, LobbyConfig.Tags.AmbientHost)
		LobbyUtil.emitter(dustHost, "DustMotes", {
			rate = 8,
			lifetime = NumberRange.new(5, 9),
			speed = NumberRange.new(0.1, 0.5),
			spread = Vector2.new(180, 180),
			accel = Vector3.new(0.1, 0.2, 0.1),
			color = ColorSequence.new(Color3.fromRGB(220, 210, 255), Color3.fromRGB(180, 160, 120)),
			lightEmission = 0.25,
		})
	end

	-- Sons ambiants (placeholders)
	local soundHost = LobbyUtil.part(
		"AmbientSoundHost",
		Vector3.new(2, 2, 2),
		LobbyUtil.cf(Vector3.new(0, 8, 0)),
		C.Ink900,
		amb,
		Enum.Material.ForceField,
		{ transparency = 1, canCollide = false }
	)
	if soundHost then
		local s = Instance.new("Sound")
		s.Name = "HallAmbient"
		s.SoundId = LobbyConfig.AmbientSoundIds.Hall
		s.Volume = 0.08
		s.Looped = true
		s.RollOffMaxDistance = 400
		s.Parent = soundHost
		s:Play()
	end
end

local function startAnims(root: Model)
	if animConn then
		animConn:Disconnect()
		animConn = nil
	end
	local crystals = {}
	local portals = {}
	for _, inst in CollectionService:GetTagged(LobbyConfig.Tags.CrystalSpin) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(root) then
			table.insert(crystals, inst)
		end
	end
	for _, inst in CollectionService:GetTagged(LobbyConfig.Tags.PortalPulse) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(root) then
			table.insert(portals, { part = inst, baseT = inst.Transparency })
		end
	end

	local t0 = os.clock()
	animConn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		for _, p in crystals do
			if p.Parent then
				local spd = (p:GetAttribute("BC_SpinSpeed") :: number?) or 20
				p.CFrame = p.CFrame * CFrame.Angles(0, math.rad(spd) * (1 / 60), 0)
			end
		end
		for _, entry in portals do
			local p = entry.part
			if p.Parent then
				local pulse = 0.35 + 0.2 * math.sin(t * 2.2)
				p.Transparency = math.clamp(entry.baseT + pulse * 0.25, 0.2, 0.85)
				local light = p:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = 0.8 + 0.6 * (0.5 + 0.5 * math.sin(t * 2.2))
				end
			end
		end
	end)
end

local function refreshLeaderboards(root: Model)
	local rowsElo = {}
	for _, player in Players:GetPlayers() do
		local mmr = player:GetAttribute("BC_MMR")
		if typeof(mmr) ~= "number" then
			mmr = RankedConfig.StartingMMR
		end
		local rank = RankedConfig.rankFromMmr(mmr :: number)
		table.insert(rowsElo, {
			name = player.DisplayName ~= "" and player.DisplayName or player.Name,
			mmr = mmr :: number,
			rank = rank,
		})
	end
	table.sort(rowsElo, function(a, b)
		return a.mmr > b.mmr
	end)
	-- Placeholders si peu de joueurs
	local placeholders = {
		{ name = "LameDuCiel", mmr = 1520, rank = "Diamond" },
		{ name = "AstraNova", mmr = 1380, rank = "Platinum" },
		{ name = "DuelantOr", mmr = 1210, rank = "Platinum" },
		{ name = "AegisMur", mmr = 1105, rank = "Gold" },
		{ name = "ZephyrVent", mmr = 980, rank = "Silver" },
	}
	for _, p in placeholders do
		if #rowsElo >= 10 then
			break
		end
		table.insert(rowsElo, p)
	end

	local function formatElo(): string
		local lines = {}
		for i = 1, math.min(10, #rowsElo) do
			local r = rowsElo[i]
			table.insert(lines, string.format("%2d  %s  ·  %s  (%d)", i, r.name, r.rank, r.mmr))
		end
		return table.concat(lines, "\n")
	end

	local dawn = QuestConfig.Factions.Dawn.displayName
	local dusk = QuestConfig.Factions.Dusk.displayName
	local function formatFaction(): string
		return string.format(
			"%s  vs  %s\n(mise à jour live via MetaState)\n\nJoueurs connectés : %d",
			dawn,
			dusk,
			#Players:GetPlayers()
		)
	end

	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = d:GetAttribute("BC_LeaderboardKind")
			local sg = d:FindFirstChildOfClass("SurfaceGui")
			if not sg then
				continue
			end
			local rows = sg:FindFirstChild("Rows", true)
				or (sg:FindFirstChild("Frame") and sg.Frame:FindFirstChild("Rows"))
			local score = sg:FindFirstChild("Score", true)
			if kind == "Elo" and rows and rows:IsA("TextLabel") then
				rows.Text = formatElo()
			elseif kind == "FactionTop" and rows and rows:IsA("TextLabel") then
				rows.Text = formatFaction()
			elseif kind == "Faction" and score and score:IsA("TextLabel") then
				score.Text = "Aube ↔ Crépuscule"
			end
		end
	end
end

local function tryRequirePlayerData(): any?
	local ok, mod = pcall(function()
		return require(script.Parent.Parent.Data:WaitForChild("PlayerDataService"))
	end)
	if ok then
		return mod
	end
	return nil
end

local function syncPlayerLeaderboardAttrs()
	local PDS = tryRequirePlayerData()
	if not PDS then
		return
	end
	for _, player in Players:GetPlayers() do
		local profile = PDS.get(player)
		if profile then
			player:SetAttribute("BC_MMR", profile.mmr or RankedConfig.StartingMMR)
			player:SetAttribute("BC_Faction", profile.faction)
			player:SetAttribute("BC_WarScore", profile.warScoreContribution or 0)
		end
	end
end

function LobbyBuilder.getSpawnCFrame(): CFrame
	-- Face nord (−Z) vers les pads
	return LobbyUtil.cf(Vector3.new(0, 4, 4)) * CFrame.Angles(0, math.rad(180), 0)
end

function LobbyBuilder.applyLobbyLighting()
	LobbyLighting.applyHall()
end

function LobbyBuilder.ensure(parent: Instance): Model
	if built and built.Parent then
		return built
	end
	local existing = parent:FindFirstChild(LobbyConfig.Name)
	if existing and existing:IsA("Model") and existing:GetAttribute("ArtPass") == LobbyConfig.ArtPass then
		built = existing
		return existing
	end
	if existing then
		existing:Destroy()
	end

	LobbyUtil.resetBudget()
	local root = Instance.new("Model")
	root.Name = LobbyConfig.Name
	root.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	root:SetAttribute("DisplayName", LobbyConfig.DisplayName)
	root:SetAttribute("ArtPass", LobbyConfig.ArtPass)
	root:SetAttribute("BC_LobbyOrigin", LobbyConfig.Origin)
	root:SetAttribute("OffsetX", LobbyConfig.Origin.X)
	root:SetAttribute("OffsetZ", LobbyConfig.Origin.Z)
	root.Parent = parent

	pcall(function()
		workspace.StreamingEnabled = true
	end)

	buildFloorShell(root)
	buildColonnade(root)
	buildSpawns(root)
	buildPads(root)
	buildLeaderboardWall(root)
	buildFaction(root, "Dawn")
	buildFaction(root, "Dusk")
	buildForms(root)
	buildForge(root)
	buildQuests(root)
	buildTraining(root)
	buildGalleryAndDioramas(root)
	buildAmbience(root)

	-- PrimaryPart pour Pivot
	local primary = root:FindFirstChild("CompassRose", true)
	if primary and primary:IsA("BasePart") then
		root.PrimaryPart = primary
	end

	built = root
	LobbyBuilder.applyLobbyLighting()
	startAnims(root)
	LobbyUtil.warnBudget("ConcordHall")

	if leaderboardRefresh then
		task.cancel(leaderboardRefresh)
	end
	leaderboardRefresh = task.spawn(function()
		while built and built.Parent do
			syncPlayerLeaderboardAttrs()
			refreshLeaderboards(root)
			task.wait(60)
		end
	end)

	return root
end

function LobbyBuilder.bindQueuePads(enqueueFn: (Player, string) -> ())
	if padBound then
		return
	end
	padBound = true

	local debounce: { [Player]: number } = {}

	local function tryEnqueue(player: Player, modeAttr: any)
		if typeof(modeAttr) ~= "string" then
			return
		end
		if modeAttr ~= "Casual" and modeAttr ~= "Ranked" then
			return
		end
		local now = os.clock()
		if debounce[player] and now - debounce[player] < 1.2 then
			return
		end
		debounce[player] = now
		enqueueFn(player, modeAttr)
	end

	local function hookPad(pad: BasePart)
		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				tryEnqueue(player, pad:GetAttribute("BC_QueueMode"))
			end)
		end
		pad.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				tryEnqueue(player, pad:GetAttribute("BC_QueueMode"))
			end
		end)
	end

	local function scan(root: Instance)
		for _, inst in CollectionService:GetTagged(LobbyConfig.Tags.QueuePad) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(root) then
				hookPad(inst)
			end
		end
	end

	if built then
		scan(built)
	end
	CollectionService:GetInstanceAddedSignal(LobbyConfig.Tags.QueuePad):Connect(function(inst)
		if inst:IsA("BasePart") and built and inst:IsDescendantOf(built) then
			hookPad(inst)
		end
	end)
end

function LobbyBuilder.getBuilt(): Model?
	return built
end

return LobbyBuilder
