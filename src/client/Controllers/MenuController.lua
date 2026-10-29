--!strict
-- Menu principal (Relance, Atelier, Inventaire, Classements, Profil), barre du Hub (Cristaux, rang),
-- toasts `Notify` et écran de chargement. Le menu se ferme automatiquement en duel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Net = require(Shared.Net)
local RankData = require(Shared.Config.RankData)

local Client = script.Parent.Parent
local ClientState = require(Client:WaitForChild("ClientState"))
local UI = Client:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Root = require(UI.Root)
local Toast = require(UI.Toast)
local State = require(UI.State)
local Loading = require(UI.Loading)
local PageTypes = require(UI.Pages.PageTypes)

local C = Theme.Colors

local MenuController = {}
MenuController.Priority = 40

local PAGE_MODULES = { "RerollPage", "WorkshopPage", "InventoryPage", "LeaderboardPage", "ProfilePage" }

local pages: { PageTypes.Page } = {}
local byId: { [string]: PageTypes.Page } = {}
local railButtons: { [string]: TextButton } = {}
local currentId: string? = nil
local isOpen = false

local backdrop: Frame
local window: Frame
local windowScale: UIScale
local hubBar: Frame
local crystalsLbl: TextLabel
local rankLbl: TextLabel

local function profile(): { [string]: any }?
	return ClientState.getProfile()
end

local function highlight()
	for id, b in railButtons do
		local on = id == currentId
		Kit.tween(b, 0.2, {
			BackgroundColor3 = if on then C.PanelLight else C.Bg,
			BackgroundTransparency = if on then 0 else 0.4,
		})
		local bar = b:FindFirstChild("Accent")
		if bar and bar:IsA("Frame") then
			bar.Visible = on
		end
	end
end

local function showPage(id: string, sub: string?)
	local page = byId[id]
	if not page then
		return
	end
	for _, p in pages do
		if p ~= page and p.Root.Visible then
			p.Root.Visible = false
			if p.onHide then
				p.onHide()
			end
		end
	end
	currentId = id
	page.Root.Visible = true
	if page.onShow then
		page.onShow(sub)
	end
	highlight()
end

function MenuController.isOpen(): boolean
	return isOpen
end

function MenuController.open(id: string?, sub: string?)
	if State.inDuel() then
		Toast.show("Le menu est indisponible pendant un duel.", "Error")
		return
	end
	local target = id or currentId or "Profile"
	if not isOpen then
		isOpen = true
		game:GetService("Players").LocalPlayer:SetAttribute("EB_MenuOpen", true)
		backdrop.Visible = true
		window.Visible = true
		backdrop.BackgroundTransparency = 1
		Kit.tween(backdrop, 0.25, { BackgroundTransparency = 0.45 })
		windowScale.Scale = Root.factor() * 0.92
		Kit.tween(windowScale, 0.3, { Scale = Root.factor() }, Enum.EasingStyle.Back)
		Kit.sound("Open", 0.25)
	end
	showPage(target, sub)
end

function MenuController.close()
	if not isOpen then
		return
	end
	isOpen = false
	game:GetService("Players").LocalPlayer:SetAttribute("EB_MenuOpen", false)
	Kit.tween(backdrop, 0.2, { BackgroundTransparency = 1 })
	Kit.tween(windowScale, 0.2, { Scale = Root.factor() * 0.94 })
	task.delay(0.2, function()
		if not isOpen then
			backdrop.Visible = false
			window.Visible = false
			for _, p in pages do
				if p.Root.Visible then
					p.Root.Visible = false
					if p.onHide then
						p.onHide()
					end
				end
			end
		end
	end)
end

function MenuController.toggle(id: string?)
	if isOpen and (id == nil or id == currentId) then
		MenuController.close()
	else
		MenuController.open(id)
	end
end

local function buildWindow()
	local gui = Root.gui("Menu")
	backdrop = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	backdrop.Activated:Connect(function()
		MenuController.close()
	end)
	window = Kit.panel(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1080, 640),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.06,
		Visible = false,
		Active = true,
	})
	windowScale = Root.scale(window)

	local rail = Kit.new("Frame", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(0, 170, 1, -28),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.3,
		Parent = window,
	})
	Kit.corner(rail, 12)
	Kit.padding(rail, 10)
	Kit.list(rail, false, 6)
	Kit.label(rail, "ETHER BLADES", {
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 15,
		TextColor3 = C.Gold,
		LayoutOrder = 0,
	})

	local content = Kit.new("Frame", {
		Position = UDim2.fromOffset(200, 24),
		Size = UDim2.new(1, -224, 1, -48),
		BackgroundTransparency = 1,
		Parent = window,
	})

	local close = Kit.button(window, "✕", {
		Size = UDim2.fromOffset(36, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		TextSize = 16,
		Accent = C.Danger,
	}, function()
		MenuController.close()
	end)
	close.ZIndex = 10

	local ctx: PageTypes.Ctx = {
		open = function(id: string, sub: string?)
			MenuController.open(id, sub)
		end,
		close = function()
			MenuController.close()
		end,
		profile = profile,
	}
	for i, name in PAGE_MODULES do
		local mod = UI.Pages:FindFirstChild(name)
		if mod and mod:IsA("ModuleScript") then
			local ok, res = pcall(function()
				local frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
				local page = (require(mod) :: any).build(frame, ctx) :: PageTypes.Page
				page.Root = frame
				frame.Visible = false
				return page
			end)
			if ok then
				local page = res :: PageTypes.Page
				table.insert(pages, page)
				byId[page.Id] = page
				local b = Kit.new("TextButton", {
					Text = "",
					AutoButtonColor = false,
					Size = UDim2.new(1, 0, 0, 48),
					BackgroundColor3 = C.Bg,
					BackgroundTransparency = 0.4,
					LayoutOrder = i,
					Parent = rail,
				})
				Kit.corner(b, 10)
				local accent = Kit.new("Frame", {
					Name = "Accent",
					Size = UDim2.new(0, 3, 1, -16),
					Position = UDim2.fromOffset(4, 8),
					BackgroundColor3 = C.Cyan,
					BorderSizePixel = 0,
					Visible = false,
					Parent = b,
				})
				Kit.round(accent)
				Kit.label(b, page.Icon, {
					Position = UDim2.fromOffset(14, 0),
					Size = UDim2.new(0, 26, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextSize = 18,
					TextColor3 = C.Cyan,
				})
				Kit.label(b, page.Title, {
					Position = UDim2.fromOffset(46, 0),
					Size = UDim2.new(1, -50, 1, 0),
					FontFace = Theme.Fonts.Bold,
					TextSize = 14,
				})
				b.Activated:Connect(function()
					Kit.sound("Click", 0.35)
					showPage(page.Id)
				end)
				railButtons[page.Id] = b
			else
				warn(string.format("[EtherBlades] page %s : %s", name, tostring(res)))
			end
		end
	end
end

local function pill(parent: Instance, order: number, width: number, color: Color3): (Frame, TextLabel)
	local f = Kit.new("Frame", {
		Size = UDim2.fromOffset(width, 40),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.corner(f, 20)
	Kit.stroke(f, color, 1.5, 0.35)
	local l = Kit.label(f, "", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 15,
		TextColor3 = color,
	})
	return f, l
end

local function buildHubBar()
	hubBar = Kit.new("Frame", {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(700, 44),
		BackgroundTransparency = 1,
		Parent = Root.gui("Hud"),
	})
	local sc = Root.scale(hubBar)
	sc.Name = "HubScale"
	Kit.list(hubBar, true, 10)
	-- décale sous les boutons Roblox (coin supérieur gauche)
	Kit.new("Frame", { Size = UDim2.fromOffset(if UserInputService.TouchEnabled then 96 else 60, 1), BackgroundTransparency = 1, LayoutOrder = 0, Parent = hubBar })
	Kit.button(hubBar, "☰  MENU", { Size = UDim2.fromOffset(120, 40), LayoutOrder = 1, Primary = true }, function()
		MenuController.toggle()
	end)
	local _, c = pill(hubBar, 2, 140, C.Gold)
	crystalsLbl = c
	local _, r = pill(hubBar, 3, 220, C.Cyan)
	rankLbl = r
end

local function refreshHubBar()
	local p = profile()
	if not p then
		return
	end
	crystalsLbl.Text = "◆ " .. Kit.formatNumber(p.Crystals or 0)
	local wr = Players.LocalPlayer:GetAttribute("EB_WorldRank")
	local tier = RankData.tierFor(p.Elo or RankData.StartElo, if type(wr) == "number" and wr > 0 then wr else nil)
	rankLbl.Text = string.format("%s · %s Elo", tier.Name, Kit.formatNumber(p.Elo or 0))
	rankLbl.TextColor3 = tier.Color
end

function MenuController.init()
	State.init()
	Loading.show()
	buildWindow()
	buildHubBar()
	Net.event("Notify").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and type(data.Text) == "string" then
			Toast.show(data.Text, if type(data.Kind) == "string" then data.Kind else "Info")
		end
	end)
	local lastCrystals: number? = nil
	ClientState.ProfileChanged:Connect(function(p: { [string]: any })
		refreshHubBar()
		if lastCrystals and type(p.Crystals) == "number" and p.Crystals > lastCrystals then
			Kit.tween(crystalsLbl, 0.1, { TextSize = 19 })
			task.delay(0.15, function()
				Kit.tween(crystalsLbl, 0.3, { TextSize = 15 })
			end)
		end
		lastCrystals = p.Crystals
		for _, page in pages do
			if page.onProfile then
				local ok, err = pcall(page.onProfile, p)
				if not ok then
					warn("[EtherBlades] page " .. page.Id .. " : " .. tostring(err))
				end
			end
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("EB_WorldRank"):Connect(refreshHubBar)
	State.MatchChanged:Connect(function(view: State.MatchView)
		if view.Active then
			MenuController.close()
		end
		hubBar.Visible = not view.Active
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			MenuController.toggle()
		end
	end)
end

function MenuController.start()
	local deadline = os.clock() + 8
	while not profile() and os.clock() < deadline do
		task.wait(0.1)
	end
	task.wait(0.4)
	refreshHubBar()
	Loading.hide()
end

return MenuController
