--!strict
--[[
	Modale CanvasGroup — scrim + panneau verre + flou profondeur + cascade.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))
local Button = require(script.Parent:WaitForChild("Button"))

local Modal = {}

export type Handle = {
	root: CanvasGroup,
	panel: Frame,
	content: Frame,
	close: () -> (),
	setTitle: (string) -> (),
}

function Modal.open(
	parent: Instance,
	opts: {
		title: string?,
		subtitle: string?,
		size: UDim2?,
		onClose: (() -> ())?,
		showClose: boolean?,
		fullscreen: boolean?,
	}
): Handle
	Util.setMenuBlur(true)

	local root = Instance.new("CanvasGroup")
	root.Name = "BC_Modal"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	root.BorderSizePixel = 0
	root.ZIndex = 100
	root.Parent = parent

	local scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BackgroundTransparency = 0.55
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.ZIndex = 100
	scrim.Parent = root

	local panel = Util.glassPanel(root, "Panel")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = opts.size or UDim2.fromScale(0.72, 0.78)
	panel.ZIndex = 101
	panel.BackgroundTransparency = 0.06

	local panelScale = Instance.new("UIScale")
	panelScale.Scale = 0.94
	panelScale.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 24, 0, 16)
	title.Size = UDim2.new(1, -80, 0, 36)
	Theme.applyFont(title, "Display")
	title.TextSize = 28
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Gold
	title.Text = opts.title or ""
	title.ZIndex = 102
	title.Parent = panel

	if opts.subtitle and opts.subtitle ~= "" then
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.new(0, 24, 0, 50)
		sub.Size = UDim2.new(1, -80, 0, 20)
		Theme.applyFont(sub, "Body")
		sub.TextSize = 13
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Theme.Muted
		sub.Text = opts.subtitle
		sub.ZIndex = 102
		sub.Parent = panel
	end

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, 16, 0, if opts.subtitle then 78 else 60)
	content.Size = UDim2.new(1, -32, 1, if opts.subtitle then -94 else -76)
	content.ZIndex = 102
	content.Parent = panel

	local closed = false
	local escConn: RBXScriptConnection? = nil
	local function close()
		if closed then
			return
		end
		closed = true
		if escConn then
			escConn:Disconnect()
		end
		TweenService:Create(root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(panelScale, TweenInfo.new(0.18), { Scale = 0.94 }):Play()
		Util.setMenuBlur(false)
		task.delay(0.2, function()
			root:Destroy()
		end)
		if opts.onClose then
			opts.onClose()
		end
	end

	if opts.showClose ~= false then
		Button.create({
			parent = panel,
			text = "✕",
			style = "ghost",
			name = "Close",
			size = UDim2.fromOffset(44, 44),
			position = UDim2.new(1, -56, 0, 12),
			textSize = 18,
			onClick = close,
		}).ZIndex =
			103
	end

	scrim.MouseButton1Click:Connect(close)
	escConn = Util.escapeCloses(close)

	TweenService:Create(root, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
		BackgroundTransparency = 0.45,
	}):Play()
	TweenService:Create(panelScale, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	-- Cascade enfants (max 8)
	task.defer(function()
		local kids = {}
		for _, ch in content:GetChildren() do
			if ch:IsA("GuiObject") then
				table.insert(kids, ch)
			end
		end
		for i, ch in kids do
			if i > 8 then
				break
			end
			local g = ch.BackgroundTransparency
			ch.BackgroundTransparency = 1
			task.delay(0.04 * i, function()
				if ch.Parent then
					TweenService:Create(ch, TweenInfo.new(0.22), { BackgroundTransparency = g }):Play()
				end
			end)
		end
	end)

	return {
		root = root,
		panel = panel,
		content = content,
		close = close,
		setTitle = function(t: string)
			title.Text = t
		end,
	}
end

return Modal
