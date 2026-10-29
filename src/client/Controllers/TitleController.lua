--!strict
-- Plaques au-dessus de la tête : titre équipé (dégradé TitleDef.Gradient + reflet animé qui balaie le texte),
-- nom du joueur (police Michroma), rang coloré + Elo. Lit les attributs Player posés par TitleService :
-- EB_Title, EB_Rank, EB_Elo, EB_WorldRank. Les plaques vivent dans le PlayerGui (Adornee = tête).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local TitleData = require(Shared.Config.TitleData)
local RankData = require(Shared.Config.RankData)
local Maid = require(Shared.Util.Maid)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local TitleController = {}
TitleController.Priority = 70

type Plate = {
	Gui: BillboardGui,
	Title: TextLabel,
	TitleGrad: UIGradient,
	Shine: TextLabel,
	ShineGrad: UIGradient,
	Name: TextLabel,
	Rank: TextLabel,
	Speed: number,
	Phase: number,
}

local plates: { [Player]: Plate } = {}
local maids: { [Player]: Maid.Maid } = {}

local function seq(colors: { Color3 }): ColorSequence
	local kps = {}
	for i, c in colors do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), c))
	end
	if #kps == 1 then
		table.insert(kps, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return ColorSequence.new(kps)
end

local function tierOf(id: any): any
	for _, t in RankData.Tiers do
		if t.Id == id then
			return t
		end
	end
	return RankData.Tiers[1]
end

local function refresh(p: Player)
	local plate = plates[p]
	if not plate then
		return
	end
	local titleId = p:GetAttribute("EB_Title")
	local def = TitleData.get(if type(titleId) == "string" then titleId else TitleData.Default)
	local text = if def then def.Text else ""
	plate.Title.Text = text
	plate.Shine.Text = text
	plate.Title.Visible = text ~= ""
	plate.Shine.Visible = text ~= ""
	if def then
		plate.TitleGrad.Color = seq(def.Gradient)
		-- plus le titre est rare, plus le reflet est vif et fréquent
		plate.Speed = 0.25 + Theme.rarityOrder(def.Rarity) * 0.12
	end
	plate.Name.Text = p.DisplayName
	local tier = tierOf(p:GetAttribute("EB_Rank"))
	local elo = p:GetAttribute("EB_Elo")
	local wr = p:GetAttribute("EB_WorldRank")
	local suffix = if type(wr) == "number" and wr > 0 and wr <= 50 then string.format("  #%d", wr) else ""
	plate.Rank.Text = string.format("◆ %s · %s%s", tier.Name, if type(elo) == "number" then tostring(elo) else "—", suffix)
	plate.Rank.TextColor3 = tier.Color
end

local function build(p: Player, head: BasePart): Plate
	local gui = Kit.new("BillboardGui", {
		Name = "EB_Nameplate_" .. p.UserId,
		Adornee = head,
		Size = UDim2.new(7, 0, 2.1, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0),
		MaxDistance = 90,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}) :: BillboardGui
	local title = Kit.label(gui, "", {
		Size = UDim2.fromScale(1, 0.36),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.6,
		TextWrapped = false,
	})
	local titleGrad = Kit.new("UIGradient", { Rotation = 0, Parent = title }) :: UIGradient
	-- reflet : copie blanche du texte, masquée par un dégradé de transparence qui défile
	local shine = Kit.label(gui, "", {
		Size = UDim2.fromScale(1, 0.36),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 1,
		TextWrapped = false,
		ZIndex = 2,
	})
	local shineGrad = Kit.new("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine,
	}) :: UIGradient
	local name = Kit.label(gui, p.DisplayName, {
		Position = UDim2.fromScale(0, 0.38),
		Size = UDim2.fromScale(1, 0.34),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextScaled = true,
		TextStrokeTransparency = 0.5,
		TextWrapped = false,
	})
	local rank = Kit.label(gui, "", {
		Position = UDim2.fromScale(0, 0.74),
		Size = UDim2.fromScale(1, 0.24),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Title,
		TextScaled = true,
		TextStrokeTransparency = 0.6,
		TextWrapped = false,
	})
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		Gui = gui,
		Title = title,
		TitleGrad = titleGrad,
		Shine = shine,
		ShineGrad = shineGrad,
		Name = name,
		Rank = rank,
		Speed = 0.4,
		Phase = math.random(),
	}
end

local function onCharacter(p: Player, char: Model)
	local maid = maids[p]
	if not maid then
		return
	end
	local head = char:WaitForChild("Head", 10)
	if not head or not head:IsA("BasePart") or p.Character ~= char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local plate = build(p, head)
	plates[p] = plate
	maid:Set("plate", function()
		plate.Gui:Destroy()
		if plates[p] == plate then
			plates[p] = nil
		end
	end)
	refresh(p)
end

local function track(p: Player)
	if maids[p] then
		return
	end
	local maid = Maid.new()
	maids[p] = maid
	for _, attr in { "EB_Title", "EB_Rank", "EB_Elo", "EB_WorldRank" } do
		maid:Give(p:GetAttributeChangedSignal(attr):Connect(function()
			refresh(p)
		end))
	end
	maid:Give(p.CharacterAdded:Connect(function(char)
		onCharacter(p, char)
	end))
	maid:Give(p.CharacterRemoving:Connect(function()
		maid:Set("plate", nil)
	end))
	if p.Character then
		task.spawn(onCharacter, p, p.Character)
	end
end

function TitleController.init()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(p: Player)
		local maid = maids[p]
		if maid then
			maids[p] = nil
			maid:Clean()
		end
	end)
	for _, p in Players:GetPlayers() do
		track(p)
	end
	-- reflet balayant (une seule boucle pour toutes les plaques)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, plate in plates do
			local x = ((t * plate.Speed + plate.Phase) % 1.6) - 0.8
			plate.ShineGrad.Offset = Vector2.new(x * 1.6, 0)
		end
	end)
end

return TitleController
