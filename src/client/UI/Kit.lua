--!strict
-- Petits constructeurs d'interface : instances, coins, contours, dégradés, boutons animés, sons, tweens.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local C = Theme.Colors

local Kit = {}

-- Crée une instance, applique les propriétés puis les enfants, et enfin le parent.
function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className) :: any
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(parent: Instance, radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Corner), Parent = parent })
end

function Kit.round(parent: Instance): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

function Kit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or C.Cyan,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Kit.gradient(parent: Instance, colors: { Color3 }, rotation: number?): UIGradient
	local seq: ColorSequence
	if #colors == 1 then
		seq = ColorSequence.new(colors[1])
	else
		local kps = {}
		for i, c in colors do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
		end
		seq = ColorSequence.new(kps)
	end
	return Kit.new("UIGradient", { Color = seq, Rotation = rotation or 90, Parent = parent })
end

function Kit.padding(parent: Instance, px: number, py: number?): UIPadding
	local y = py or px
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
		Parent = parent,
	})
end

function Kit.list(parent: Instance, horizontal: boolean?, gap: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

function Kit.grid(parent: Instance, cell: Vector2, gap: number?): UIGridLayout
	return Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(gap or 8, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Kit.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local soundCache: { [string]: Sound } = {}
function Kit.sound(key: string, volume: number?, pitch: number?)
	local id = (Theme.Sounds :: any)[key] or key
	local s = soundCache[id .. tostring(pitch)]
	if not s then
		s = Kit.new("Sound", { SoundId = id, Volume = volume or 0.5, PlaybackSpeed = pitch or 1, Parent = SoundService })
		soundCache[id .. tostring(pitch)] = s :: Sound
	end
	local snd = s :: Sound
	snd.Volume = volume or 0.5
	SoundService:PlayLocalSound(snd)
end

-- Ombre portée douce (cadre décalé derrière l'élément).
function Kit.shadow(target: GuiObject)
	local sh = Kit.new("Frame", {
		Name = "Shadow",
		AnchorPoint = target.AnchorPoint,
		Position = target.Position + UDim2.fromOffset(0, 6),
		Size = target.Size + UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = 0.6,
		ZIndex = math.max(target.ZIndex - 1, 0),
		Parent = target.Parent,
	})
	Kit.corner(sh, Theme.Corner + 4)
	target:GetPropertyChangedSignal("Visible"):Connect(function()
		sh.Visible = target.Visible
	end)
	return sh
end

-- Panneau « éther » standard.
function Kit.panel(parent: Instance, props: { [string]: any }?): Frame
	local p: { [string]: any } = {
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = parent,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	local f = Kit.new("Frame", p)
	Kit.corner(f)
	Kit.stroke(f, C.Cyan, 1.2, 0.65)
	Kit.gradient(f, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 185, 220) }, 90)
	return f
end

function Kit.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = C.Text,
		FontFace = Theme.Fonts.Body,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = parent,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.new("TextLabel", p)
end

export type ButtonOpts = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Accent: Color3?,
	Primary: boolean?,
	TextSize: number?,
	LayoutOrder: number?,
	Font: Font?,
}

-- Bouton animé (survol, appui, son). `onClick` est protégé contre les doubles clics rapides.
function Kit.button(parent: Instance, text: string, opts: ButtonOpts?, onClick: (() -> ())?): TextButton
	local o: ButtonOpts = opts or {}
	local accent = o.Accent or C.Cyan
	local primary = o.Primary == true
	local b = Kit.new("TextButton", {
		AutoButtonColor = false,
		Text = text,
		FontFace = o.Font or Theme.Fonts.Bold,
		TextSize = o.TextSize or 16,
		TextColor3 = if primary then C.Night else C.Text,
		BackgroundColor3 = if primary then accent else C.PanelLight,
		BackgroundTransparency = if primary then 0 else 0.15,
		Size = o.Size or UDim2.fromOffset(160, 42),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.zero,
		LayoutOrder = o.LayoutOrder or 0,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Kit.corner(b, 10)
	local stroke = Kit.stroke(b, accent, 1.5, if primary then 0.2 else 0.5)
	if primary then
		Kit.gradient(b, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 210, 230) }, 90)
	end
	local scale = Kit.new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		Kit.tween(scale, 0.15, { Scale = 1.04 })
		Kit.tween(stroke, 0.15, { Transparency = 0 })
	end)
	b.MouseLeave:Connect(function()
		Kit.tween(scale, 0.2, { Scale = 1 })
		Kit.tween(stroke, 0.2, { Transparency = if primary then 0.2 else 0.5 })
	end)
	b.MouseButton1Down:Connect(function()
		Kit.tween(scale, 0.08, { Scale = 0.96 })
	end)
	b.MouseButton1Up:Connect(function()
		Kit.tween(scale, 0.12, { Scale = 1.02 })
	end)
	if onClick then
		local last = 0
		b.Activated:Connect(function()
			if os.clock() - last < 0.2 then
				return
			end
			last = os.clock()
			Kit.sound("Click", 0.45)
			onClick()
		end)
	end
	return b
end

-- Barre de progression (fond + remplissage + texte optionnel).
export type Bar = { Root: Frame, Fill: Frame, Text: TextLabel, set: (pct: number, label: string?) -> () }
function Kit.bar(parent: Instance, color: Color3, props: { [string]: any }?): Bar
	local p: { [string]: any } = {
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.25,
		Size = UDim2.new(1, 0, 0, 14),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	local root = Kit.new("Frame", p)
	Kit.round(root)
	Kit.stroke(root, color, 1, 0.6)
	local fill = Kit.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = root,
	})
	Kit.round(fill)
	Kit.gradient(fill, { Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190) }, 90)
	local text = Kit.label(root, "", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.Fonts.Bold,
		TextSize = 11,
		TextStrokeTransparency = 0.5,
		ZIndex = fill.ZIndex + 1,
	})
	local bar: Bar = {
		Root = root,
		Fill = fill,
		Text = text,
		set = function(pct: number, label: string?)
			fill.Size = UDim2.fromScale(math.clamp(pct, 0, 1), 1)
			if label then
				text.Text = label
			end
		end,
	}
	return bar
end

-- Formate un nombre avec espaces fines (1 234 567).
function Kit.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local neg = string.sub(s, 1, 1) == "-"
	if neg then
		s = string.sub(s, 2)
	end
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	out = string.gsub(out, "^ ", "")
	return (if neg then "-" else "") .. out
end

function Kit.clear(container: Instance, keepLayouts: boolean?)
	for _, c in container:GetChildren() do
		if not (keepLayouts and (c:IsA("UIGridStyleLayout") or c:IsA("UIPadding") or c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient"))) then
			c:Destroy()
		end
	end
end

return Kit
