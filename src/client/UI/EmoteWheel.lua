--!strict
-- Roue radiale des emotes (8 emplacements = EquippedEmotes). Sélection à la souris (angle), au stick ou au toucher.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local EmoteData = require(Shared.Config.EmoteData)
local Maid = require(Shared.Util.Maid)

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Root = require(script.Parent.Root)

local C = Theme.Colors

local RADIUS = 150
local SLOT = 104

export type Wheel = {
	open: (ids: { string }) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	hovered: () -> number?,
	setStick: (v: Vector2) -> (),
}

local EmoteWheel = {}

function EmoteWheel.new(onPick: (slot: number) -> ()): Wheel
	local gui = Root.gui("Wheel")
	local holder = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RADIUS * 2 + SLOT + 20, RADIUS * 2 + SLOT + 20),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local scale = Root.scale(holder)
	local ring = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RADIUS * 2 + 30, RADIUS * 2 + 30),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.35,
		Parent = holder,
	})
	Kit.round(ring)
	Kit.stroke(ring, C.Cyan, 2, 0.5)
	local hub = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.05,
		ZIndex = 2,
		Parent = holder,
	})
	Kit.round(hub)
	Kit.stroke(hub, C.Gold, 2, 0.3)
	local hubName = Kit.label(hub, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(130, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 15,
		ZIndex = 3,
	})
	Kit.label(hub, "ÉMOTES", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(130, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Title,
		TextSize = 10,
		TextColor3 = C.Gold,
		ZIndex = 3,
	})

	type Slot = { Button: TextButton, Name: TextLabel, Stroke: UIStroke, Scale: UIScale }
	local slots: { Slot } = {}
	local ids: { string } = {}
	local hoveredSlot: number? = nil
	local stick = Vector2.zero
	local opened = false
	local maid = Maid.new()

	for i = 1, EmoteData.Slots do
		local a = (i - 1) / EmoteData.Slots * math.pi * 2
		local b = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(a) * RADIUS, 0.5, -math.cos(a) * RADIUS),
			Size = UDim2.fromOffset(SLOT, SLOT * 0.62),
			BackgroundColor3 = C.Panel,
			ZIndex = 4,
			Parent = holder,
		})
		Kit.corner(b, 12)
		local st = Kit.stroke(b, C.Cyan, 1.5, 0.5)
		local sc = Kit.new("UIScale", { Parent = b })
		Kit.label(b, tostring(i), {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(16, 14),
			FontFace = Theme.Fonts.Title,
			TextSize = 10,
			TextColor3 = C.Gold,
			ZIndex = 5,
		})
		local name = Kit.label(b, "", {
			Position = UDim2.fromOffset(4, 12),
			Size = UDim2.new(1, -8, 1, -14),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = Theme.Fonts.Bold,
			TextSize = 12,
			ZIndex = 5,
		})
		b.Activated:Connect(function()
			if opened and ids[i] then
				onPick(i)
			end
		end)
		b.MouseEnter:Connect(function()
			hoveredSlot = i
		end)
		table.insert(slots, { Button = b, Name = name, Stroke = st, Scale = sc })
	end

	local function render()
		for i, s in slots do
			local def = ids[i] and EmoteData.get(ids[i])
			s.Name.Text = if def then def.Name else "—"
			s.Name.TextColor3 = if def then C.Text else C.TextDim
			local on = i == hoveredSlot and def ~= nil
			s.Stroke.Color = if on then C.Gold else C.Cyan
			s.Stroke.Transparency = if on then 0 else 0.5
			s.Button.BackgroundColor3 = if on then C.PanelLight else C.Panel
			s.Scale.Scale = if on then 1.12 else 1
		end
		local hdef = hoveredSlot and ids[hoveredSlot :: number] and EmoteData.get(ids[hoveredSlot :: number])
		hubName.Text = if hdef then hdef.Name else "Choisis une emote"
	end

	local function sectorFrom(v: Vector2): number
		local ang = math.atan2(v.X, -v.Y) -- 0 = haut, sens horaire
		if ang < 0 then
			ang += math.pi * 2
		end
		local step = math.pi * 2 / EmoteData.Slots
		return (math.floor((ang + step / 2) / step) % EmoteData.Slots) + 1
	end

	local function track()
		local prev = hoveredSlot
		if stick.Magnitude > 0.5 then
			hoveredSlot = sectorFrom(Vector2.new(stick.X, -stick.Y))
		elseif not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
			local center = holder.AbsolutePosition + holder.AbsoluteSize / 2
			local m = UserInputService:GetMouseLocation()
			local v = m - center
			if v.Magnitude > 40 * scale.Scale then
				hoveredSlot = sectorFrom(v)
			end
		end
		if hoveredSlot ~= prev then
			Kit.sound("Click", 0.15, 1.6)
			render()
		end
	end

	local wheel: Wheel = {
		open = function(list: { string })
			ids = list
			hoveredSlot = nil
			stick = Vector2.zero
			opened = true
			holder.Visible = true
			render()
			scale.Scale = Root.factor() * 0.8
			Kit.tween(scale, 0.18, { Scale = Root.factor() }, Enum.EasingStyle.Back)
			maid:Set("track", RunService.RenderStepped:Connect(track))
		end,
		close = function()
			if not opened then
				return
			end
			opened = false
			maid:Set("track", nil)
			holder.Visible = false
		end,
		isOpen = function()
			return opened
		end,
		hovered = function()
			return if hoveredSlot and ids[hoveredSlot :: number] then hoveredSlot else nil
		end,
		setStick = function(v: Vector2)
			stick = v
		end,
	}
	return wheel
end

return EmoteWheel
