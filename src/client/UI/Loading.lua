--!strict
-- Écran de chargement court : logo, halo pulsé, barre indéterminée, puis fondu.
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)

local C = Theme.Colors

local Loading = {}

local screen: CanvasGroup? = nil
local conn: RBXScriptConnection? = nil

function Loading.show(subtitle: string?)
	if screen then
		return
	end
	local g = Kit.new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Night,
		BorderSizePixel = 0,
		Parent = Root.gui("Loading"),
	})
	Kit.gradient(g, { Color3.fromRGB(14, 24, 56), C.Night, Color3.fromRGB(4, 4, 10) }, 90)
	local center = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 260),
		BackgroundTransparency = 1,
		Parent = g,
	})
	Root.scale(center)
	local halo = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(520, 6),
		BackgroundColor3 = C.Cyan,
		BorderSizePixel = 0,
		Parent = center,
	})
	Kit.round(halo)
	local haloGrad = Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = halo,
	})
	local title = Kit.label(center, "ETHER BLADES", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 64),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Display,
		TextSize = 52,
		TextColor3 = Color3.new(1, 1, 1),
	})
	Kit.gradient(title, { C.Cyan, Color3.new(1, 1, 1), C.Gold }, 0)
	Kit.label(center, subtitle or "Les lames s'éveillent…", {
		Position = UDim2.fromOffset(0, 130),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		TextColor3 = C.TextDim,
	})
	local track = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(300, 4),
		BackgroundColor3 = C.Panel,
		ClipsDescendants = true,
		BorderSizePixel = 0,
		Parent = center,
	})
	Kit.round(track)
	local runner = Kit.new("Frame", { Size = UDim2.new(0.3, 0, 1, 0), BackgroundColor3 = C.Gold, BorderSizePixel = 0, Parent = track })
	Kit.round(runner)
	local t0 = os.clock()
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		runner.Position = UDim2.fromScale(((t * 0.7) % 1.3) - 0.3, 0)
		haloGrad.Offset = Vector2.new(math.sin(t * 1.5) * 0.3, 0)
		halo.Size = UDim2.fromOffset(420 + math.sin(t * 2) * 100, 6)
	end)
	screen = g
end

function Loading.hide()
	local g = screen
	if not g then
		return
	end
	screen = nil
	Kit.tween(g, 0.6, { GroupTransparency = 1 })
	task.delay(0.65, function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		g:Destroy()
	end)
end

return Loading
