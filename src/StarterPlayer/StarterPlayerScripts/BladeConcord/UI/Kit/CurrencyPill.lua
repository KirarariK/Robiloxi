--!strict
--[[
	Chip monnaie — Crédits (or) / Éclats (cyan) + bouton « + ».
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Util = require(script.Parent:WaitForChild("Util"))
local Icons = require(script.Parent:WaitForChild("Icons"))

local CurrencyPill = {}

export type Handle = {
	root: Frame,
	setAmount: (self: Handle, n: number, animate: boolean?) -> (),
}

function CurrencyPill.create(
	parent: Instance,
	opts: {
		kind: "credits" | "shards",
		amount: number?,
		position: UDim2?,
		layoutOrder: number?,
		onPlus: (() -> ())?,
	}
): Handle
	local isCredits = opts.kind == "credits"
	local accent = if isCredits then Theme.Gold else Theme.Focus

	local root = Instance.new("Frame")
	root.Name = if isCredits then "CreditsPill" else "ShardsPill"
	root.Size = UDim2.fromOffset(168, 34)
	root.BackgroundColor3 = Theme.Ink800
	root.BackgroundTransparency = 0.08
	root.BorderSizePixel = 0
	if opts.position then
		root.Position = opts.position
	end
	if opts.layoutOrder then
		root.LayoutOrder = opts.layoutOrder
	end
	root.Parent = parent
	Util.corner(root, Theme.RadiusPill)
	Util.stroke(root, accent, 1.25, 0.35)

	local iconWrap = Instance.new("Frame")
	iconWrap.BackgroundTransparency = 1
	iconWrap.Size = UDim2.fromOffset(28, 28)
	iconWrap.Position = UDim2.fromOffset(4, 3)
	iconWrap.Parent = root
	Icons.compose(iconWrap, if isCredits then "Coin" else "Shard", accent)

	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.BackgroundTransparency = 1
	amount.Position = UDim2.fromOffset(36, 0)
	amount.Size = UDim2.new(1, -72, 1, 0)
	Theme.applyFont(amount, "Hud")
	amount.TextSize = 15
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.TextColor3 = Theme.Bone
	amount.Text = Util.formatNumber(opts.amount or 0)
	amount.Parent = root

	local plus = Instance.new("TextButton")
	plus.Name = "Plus"
	plus.AnchorPoint = Vector2.new(1, 0.5)
	plus.Position = UDim2.new(1, -4, 0.5, 0)
	plus.Size = UDim2.fromOffset(28, 28)
	plus.BackgroundColor3 = accent
	plus.BorderSizePixel = 0
	plus.Text = "+"
	plus.TextColor3 = Theme.Ink900
	plus.TextSize = 18
	Theme.applyFont(plus, "Hud")
	plus.AutoButtonColor = false
	plus.Parent = root
	Util.corner(plus, 99)
	Util.focusable(plus)

	plus.MouseButton1Click:Connect(function()
		if opts.onPlus then
			opts.onPlus()
		end
	end)

	local displayed = opts.amount or 0
	local handle: Handle
	handle = {
		root = root,
		setAmount = function(_self, n: number, animate: boolean?)
			local target = math.floor(n + 0.5)
			if not animate then
				displayed = target
				amount.Text = Util.formatNumber(displayed)
				return
			end
			local start = displayed
			local t0 = os.clock()
			local dur = 0.6
			task.spawn(function()
				while true do
					local a = math.clamp((os.clock() - t0) / dur, 0, 1)
					-- Cubic Out
					local e = 1 - (1 - a) ^ 3
					displayed = math.floor(start + (target - start) * e + 0.5)
					amount.Text = Util.formatNumber(displayed)
					if a >= 1 then
						break
					end
					task.wait()
				end
			end)
			TweenService:Create(root, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()
			task.delay(0.2, function()
				TweenService:Create(root, TweenInfo.new(0.25), { BackgroundTransparency = 0.08 }):Play()
			end)
		end,
	}
	return handle
end

return CurrencyPill
