--!strict
-- Notifications toast (remote `Notify` et messages locaux) empilées en haut de l'écran.
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)

local C = Theme.Colors

local Toast = {}

local holder: Frame? = nil
local count = 0

local KIND_COLOR: { [string]: Color3 } = {
	Info = C.Cyan,
	Success = C.Success,
	Error = C.Danger,
	Title = C.Gold,
	Reward = C.Gold,
}

local function getHolder(): Frame
	if holder and holder.Parent then
		return holder
	end
	local h = Kit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(460, 400),
		BackgroundTransparency = 1,
		Parent = Root.gui("Toast"),
	})
	Kit.list(h, false, 8, Enum.HorizontalAlignment.Center)
	Root.scale(h)
	holder = h
	return h
end

function Toast.show(text: string, kind: string?)
	local k = kind or "Info"
	local color = KIND_COLOR[k] or C.Cyan
	count += 1
	local h = getHolder()
	local item = Kit.new("Frame", {
		Size = UDim2.fromOffset(440, 46),
		BackgroundTransparency = 1,
		LayoutOrder = count,
		Parent = h,
	})
	local card = Kit.new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, -16),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.08,
		GroupTransparency = 1,
		BorderSizePixel = 0,
		Parent = item,
	})
	Kit.corner(card, 10)
	Kit.stroke(card, color, 1.5, 0.3)
	Kit.new("Frame", {
		Size = UDim2.new(0, 4, 1, -14),
		Position = UDim2.fromOffset(8, 7),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = card,
	})
	Kit.label(card, text, {
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -32, 1, 0),
		FontFace = Theme.Fonts.Bold,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Kit.tween(card, 0.3, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	if k == "Error" then
		Kit.sound("Error", 0.25)
	elseif k == "Title" or k == "Reward" then
		Kit.sound("Ping", 0.5)
	end
	task.delay(if k == "Title" then 5 else 3.5, function()
		if card.Parent then
			Kit.tween(card, 0.35, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -10) })
			task.wait(0.36)
			item:Destroy()
		end
	end)
end

return Toast
