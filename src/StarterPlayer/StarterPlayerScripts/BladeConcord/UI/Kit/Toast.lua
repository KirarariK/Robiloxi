--!strict
--[[
	Toast haut-centre — slide + fade, 3 s.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))

local Toast = {}

local host: Frame? = nil
local token = 0

function Toast.bind(parent: Instance)
	local f = Instance.new("Frame")
	f.Name = "ToastHost"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0.08, 0)
	f.Size = UDim2.fromOffset(340, 60)
	f.ZIndex = 90
	f.Parent = parent
	host = f
end

function Toast.show(text: string, color: Color3?, duration: number?)
	if not host then
		return
	end
	token += 1
	local my = token
	host:ClearAllChildren()

	local banner = Util.glassPanel(host, "Toast")
	banner.Size = UDim2.fromOffset(320, 56)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -40)
	banner.BackgroundTransparency = 0.08
	local st = banner:FindFirstChild("OuterStroke") :: UIStroke?
	if st then
		st.Color = color or Theme.Focus
		st.Transparency = 0.25
	end

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -24, 1, 0)
	label.Position = UDim2.fromOffset(12, 0)
	Theme.applyFont(label, "Body")
	label.TextSize = 14
	label.TextWrapped = true
	label.TextColor3 = Theme.Bone
	label.Text = text
	label.Parent = banner

	TweenService:Create(banner, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 0),
	}):Play()

	task.delay(duration or 3, function()
		if my ~= token or not banner.Parent then
			return
		end
		TweenService:Create(banner, TweenInfo.new(0.22), {
			Position = UDim2.new(0.5, 0, 0, -40),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.25, function()
			if banner.Parent then
				banner:Destroy()
			end
		end)
	end)
end

return Toast
