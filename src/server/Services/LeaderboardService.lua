--!strict
-- Classements mondiaux (OrderedDataStore) : Elo, Victoires, Meilleure série.
-- Toutes les 60 s : écrit les scores des joueurs présents, relit le top 50, met à jour les panneaux 3D du Hub
-- (SurfaceGui sur Workspace.Hub.Leaderboard_*, face Front) et pousse `LeaderboardData` aux clients.
-- En Studio sans accès API : classement en mémoire (joueurs vus pendant la session).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)
local RankData = require(Shared.Config.RankData)

local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Guard)
local HubPrompts = require(script.Parent.Parent.Match.HubPrompts)

export type Entry = { Rank: number, UserId: number, Name: string, Value: number }
export type Snapshot = { Boards: { [string]: { Entry } }, UpdatedAt: number }

type Board = { Id: string, Store: string, Field: string, Part: string, Title: string, Unit: string }

local BOARDS: { Board } = {
	{ Id = "Elo", Store = "EtherBlades_LB_Elo_v1", Field = "Elo", Part = "Leaderboard_Elo", Title = "CLASSEMENT · ELO", Unit = "Elo" },
	{ Id = "Wins", Store = "EtherBlades_LB_Wins_v1", Field = "Wins", Part = "Leaderboard_Wins", Title = "VICTOIRES", Unit = "V" },
	{ Id = "Streak", Store = "EtherBlades_LB_Streak_v1", Field = "BestStreak", Part = "Leaderboard_Streak", Title = "MEILLEURE SÉRIE", Unit = "" },
}
local TOP = 50
local PANEL_ROWS = 10
local PERIOD = 60

local LeaderboardService = {}
LeaderboardService.Priority = 30

local ranksEvent = Instance.new("BindableEvent")
LeaderboardService.RanksUpdated = ranksEvent.Event

local stores: { [string]: OrderedDataStore } = {}
local useMemory = false
local memoryScores: { [string]: { [number]: number } } = {}
local lastWritten: { [string]: { [number]: number } } = {}
local cache: { [string]: { Entry } } = {}
local worldRank: { [number]: number } = {}
local names: { [number]: string } = {}
local updatedAt = 0
local panelRows: { [string]: { { Rank: TextLabel, Name: TextLabel, Value: TextLabel } } } = {}

for _, b in BOARDS do
	memoryScores[b.Id] = {}
	lastWritten[b.Id] = {}
	cache[b.Id] = {}
end

local function nameOf(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.Name
		return p.Name
	end
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, res = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local n = if ok and type(res) == "string" then res else ("Joueur " .. userId)
	names[userId] = n
	return n
end

local function writeScores()
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player) :: any
		if profile then
			for _, b in BOARDS do
				local v = math.floor(tonumber(profile[b.Field]) or 0)
				if useMemory then
					memoryScores[b.Id][player.UserId] = v
				elseif lastWritten[b.Id][player.UserId] ~= v then
					local ok, err = pcall(function()
						stores[b.Id]:SetAsync(tostring(player.UserId), v)
					end)
					if ok then
						lastWritten[b.Id][player.UserId] = v
					else
						warn(string.format("[EtherBlades] classement %s : écriture refusée (%s)", b.Id, tostring(err)))
					end
				end
			end
		end
	end
end

local function readBoard(b: Board): { Entry }?
	local raw: { { UserId: number, Value: number } } = {}
	if useMemory then
		for uid, v in memoryScores[b.Id] do
			table.insert(raw, { UserId = uid, Value = v })
		end
		table.sort(raw, function(x, y)
			if x.Value ~= y.Value then
				return x.Value > y.Value
			end
			return x.UserId < y.UserId
		end)
	else
		local ok, res = pcall(function()
			local pages = stores[b.Id]:GetSortedAsync(false, TOP)
			return pages:GetCurrentPage()
		end)
		if not ok then
			warn(string.format("[EtherBlades] classement %s : lecture refusée (%s)", b.Id, tostring(res)))
			return nil
		end
		for _, item in res :: { any } do
			local uid = tonumber(item.key)
			if uid then
				table.insert(raw, { UserId = uid, Value = tonumber(item.value) or 0 })
			end
		end
	end
	local out: { Entry } = {}
	for i, r in raw do
		if i > TOP then
			break
		end
		table.insert(out, { Rank = i, UserId = r.UserId, Name = nameOf(r.UserId), Value = r.Value })
	end
	return out
end

local function buildPanel(b: Board)
	local part = HubPrompts.getPart(b.Part, 5)
	if not part then
		return
	end
	local old = part:FindFirstChild("EB_Leaderboard")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "EB_Leaderboard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(800, 1000)
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.ResetOnSpawn = false

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(8, 12, 26)
	bg.BackgroundTransparency = 0.08
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(20, 34, 70), Color3.fromRGB(6, 8, 18))
	grad.Rotation = 90
	grad.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 220, 255)
	stroke.Thickness = 6
	stroke.Transparency = 0.2
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -40, 0, 110)
	title.Position = UDim2.fromOffset(20, 10)
	title.Font = Enum.Font.GothamBlack
	title.Text = b.Title
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 110)
	title.Parent = bg

	local rows = {}
	for i = 1, PANEL_ROWS do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -40, 0, 80)
		row.Position = UDim2.fromOffset(20, 130 + (i - 1) * 86)
		row.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(18, 28, 54) else Color3.fromRGB(12, 20, 40)
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.Parent = bg
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row
		local function cell(x: number, w: number, align: Enum.TextXAlignment, color: Color3): TextLabel
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.new(x, 10, 0, 8)
			l.Size = UDim2.new(w, -20, 1, -16)
			l.Font = Enum.Font.GothamBold
			l.TextScaled = true
			l.TextXAlignment = align
			l.TextColor3 = color
			l.Text = ""
			l.Parent = row
			return l
		end
		local podium = if i == 1 then Color3.fromRGB(255, 205, 60) elseif i == 2 then Color3.fromRGB(210, 220, 235) elseif i == 3 then Color3.fromRGB(215, 140, 80) else Color3.fromRGB(120, 200, 255)
		table.insert(rows, {
			Rank = cell(0, 0.14, Enum.TextXAlignment.Left, podium),
			Name = cell(0.14, 0.58, Enum.TextXAlignment.Left, Color3.fromRGB(235, 240, 255)),
			Value = cell(0.72, 0.28, Enum.TextXAlignment.Right, Color3.fromRGB(110, 235, 255)),
		})
	end
	panelRows[b.Id] = rows
	gui.Parent = part
end

local function refreshPanels()
	for _, b in BOARDS do
		local rows = panelRows[b.Id]
		if rows then
			local entries = cache[b.Id]
			for i, row in rows do
				local e = entries[i]
				if e then
					row.Rank.Text = "#" .. e.Rank
					row.Name.Text = e.Name
					row.Value.Text = tostring(e.Value) .. (if b.Unit ~= "" then " " .. b.Unit else "")
				else
					row.Rank.Text = "#" .. i
					row.Name.Text = "—"
					row.Value.Text = ""
				end
			end
		end
	end
end

local function snapshot(): Snapshot
	return { Boards = cache, UpdatedAt = updatedAt }
end

local function refresh()
	writeScores()
	for _, b in BOARDS do
		local entries = readBoard(b)
		if entries then
			cache[b.Id] = entries
		end
	end
	table.clear(worldRank)
	for _, e in cache.Elo do
		worldRank[e.UserId] = e.Rank
	end
	updatedAt = os.time()
	refreshPanels()
	Net.event("LeaderboardData"):FireAllClients(snapshot())
	ranksEvent:Fire()
end

-- Position mondiale au classement Elo (nil si hors top 50). Sert au rang Grand Maître.
function LeaderboardService.getWorldRank(userId: number): number?
	return worldRank[userId]
end

-- Rang affiché d'un joueur présent.
function LeaderboardService.tierOf(player: Player): any
	local p = DataService.get(player)
	return RankData.tierFor(if p then p.Elo else RankData.StartElo, worldRank[player.UserId])
end

-- Rafraîchissement anticipé (après un match), au plus une fois toutes les 10 s.
local lastForced = 0
function LeaderboardService.requestRefresh()
	if os.clock() - lastForced < 10 then
		return
	end
	lastForced = os.clock()
	task.spawn(refresh)
end

function LeaderboardService.init()
	useMemory = DataService.isMemoryMode()
	if not useMemory then
		for _, b in BOARDS do
			local ok, ds = pcall(function()
				return DataStoreService:GetOrderedDataStore(b.Store)
			end)
			if ok then
				stores[b.Id] = ds
			else
				useMemory = true
			end
		end
		if not useMemory and RunService:IsStudio() then
			local probeOk = pcall(function()
				stores.Elo:GetSortedAsync(false, 1)
			end)
			useMemory = not probeOk
		end
	end
	if useMemory then
		warn("[EtherBlades] OrderedDataStore indisponible : classements en mémoire pour cette session.")
	end
	Guard.func("GetLeaderboard", {}, 1, 4, function(_player: Player)
		return { Ok = true, Data = snapshot() }
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		for _, b in BOARDS do
			lastWritten[b.Id][p.UserId] = nil
		end
	end)
end

function LeaderboardService.start()
	for _, b in BOARDS do
		task.spawn(buildPanel, b)
	end
	task.wait(5) -- laisse le temps aux premiers profils de se charger
	while true do
		local ok, err = pcall(refresh)
		if not ok then
			warn("[EtherBlades] rafraîchissement des classements : " .. tostring(err))
		end
		task.wait(PERIOD)
	end
end

return LeaderboardService
