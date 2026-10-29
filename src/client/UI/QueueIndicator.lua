--!strict
-- Indicateur de file d'attente (haut centre) : mode, temps écoulé, statut, bouton Annuler.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)
local Remote = require(script.Parent.Remote)

local C = Theme.Colors

local QueueIndicator = {}

local frame: Frame? = nil
local modeLbl: TextLabel
local timeLbl: TextLabel
local statusLbl: TextLabel
local dot: Frame
local since = 0
local active = false

local function build(): Frame
	local f = Kit.panel(Root.gui("Hud"), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(380, 58),
		BackgroundColor3 = C.Night,
		Visible = false,
	})
	Root.scale(f)
	dot = Kit.new("Frame", { Position = UDim2.fromOffset(16, 23), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.Cyan, Parent = f })
	Kit.round(dot)
	modeLbl = Kit.label(f, "", { Position = UDim2.fromOffset(38, 6), Size = UDim2.new(1, -170, 0, 22), FontFace = Theme.Fonts.Bold, TextSize = 15 })
	statusLbl = Kit.label(f, "", { Position = UDim2.fromOffset(38, 30), Size = UDim2.new(1, -170, 0, 18), TextSize = 12, TextColor3 = C.TextDim })
	timeLbl = Kit.label(f, "0:00", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -116, 0, 0),
		Size = UDim2.fromOffset(60, 58),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Theme.Fonts.Display,
		TextSize = 18,
		TextColor3 = C.Cyan,
	})
	Kit.button(f, "ANNULER", {
		Size = UDim2.fromOffset(96, 34),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		TextSize = 12,
		Accent = C.Danger,
	}, function()
		Remote.call("LeaveQueue", false)
	end)
	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local t = math.max(0, Workspace:GetServerTimeNow() - since)
		timeLbl.Text = string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
		dot.BackgroundTransparency = 0.5 + math.sin(os.clock() * 5) * 0.5
	end)
	frame = f
	return f
end

function QueueIndicator.set(q: { [string]: any }, hidden: boolean)
	local f = frame or build()
	active = q.InQueue == true
	if active then
		since = tonumber(q.Since) or Workspace:GetServerTimeNow()
		modeLbl.Text = if q.Mode == "Ranked" then "File classée · BO5" else "File amicale · BO3"
		statusLbl.Text = tostring(q.Status or "Recherche d'un adversaire…")
		dot.BackgroundColor3 = if q.Mode == "Ranked" then C.Gold else C.Cyan
	end
	local show = active and not hidden
	if show and not f.Visible then
		f.Visible = true
		f.Position = UDim2.new(0.5, 0, 0, -70)
		Kit.tween(f, 0.35, { Position = UDim2.new(0.5, 0, 0, 14) }, Enum.EasingStyle.Back)
	elseif not show then
		f.Visible = false
	end
end

return QueueIndicator
