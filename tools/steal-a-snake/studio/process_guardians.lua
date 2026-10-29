-- Traite les imports workspace.guardian_heads / workspace.guardian_kits → Assets.Models (GuardianHead_n, GuardianKit_n)
local Models = game.ReplicatedStorage.StealASnake.Assets.Models
local HEAD_SIZE = 6.5
local RING_WIDTH = 4
local report = {}

local function bbox(parts)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in parts do
		local h = d.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = d.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
					mn = mn:Min(p)
					mx = mx:Max(p)
				end
			end
		end
	end
	return mn, mx
end

-- couleur / matière depuis le nom c_/n_/g_RRGGBB ; renvoie true si c'est une charnière
local function look(d: BasePart): (boolean, string?)
	d.Anchored = true
	d.CanCollide = false
	d.CanTouch = false
	d.CanQuery = false
	if d.Name:match("^Hinge") then
		d.Transparency = 1
		d.CastShadow = false
		return true, nil
	end
	local kind, hex = string.match(d.Name, "^([cng])_(%x%x%x%x%x%x)")
	if not kind then
		return false, nil
	end
	d.Color = Color3.fromHex(hex)
	d.Name = kind .. "_" .. hex
	if kind == "n" then
		d.Material = Enum.Material.Neon
	elseif kind == "g" then
		d.Material = Enum.Material.Glass
		d.Transparency = 0.3
	else
		d.Material = Enum.Material.SmoothPlastic
	end
	d.CastShadow = not (string.upper(hex) == "1A1020" or kind == "n")
	return false, string.upper(hex)
end

local function place(out: Model, name: string)
	local old = Models:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	out.Name = name
	out.Parent = Models
	table.insert(report, name)
end

-- Têtes
local heads = workspace:FindFirstChild("guardian_heads")
if heads then
	for _, src in heads:GetChildren() do
		local n = src:IsA("Model") and tonumber(src.Name:match("^GuardianHead_(%d+)"))
		if n then
			local out = Instance.new("Model")
			local all, biggest, big = {}, nil, 0
			for _, grp in src:GetChildren() do
				local gname = grp.Name:gsub("^.-__", "")
				for _, d in grp:GetDescendants() do
					if d:IsA("BasePart") then
						local hinge, hex = look(d)
						if hinge then
							d.Name = "JawHinge"
						elseif gname == "Jaw" then
							d.Name = "jaw_" .. d.Name
							table.insert(all, d)
						else
							d.Name = "skull_" .. d.Name
							table.insert(all, d)
							if hex ~= "1A1020" and not string.find(d.Name, "^skull_n_") and d.Size.Magnitude > big then
								biggest, big = d, d.Size.Magnitude
							end
						end
						d.Parent = out
					end
				end
			end
			-- l'import FBX couche la tête (haut Blender → -Z) : on la redresse (les kits, eux, arrivent droits)
			for _, d in out:GetChildren() do
				if d:IsA("BasePart") then
					d.CFrame = CFrame.Angles(math.rad(90), 0, 0) * d.CFrame
				end
			end
			local mn, mx = bbox(all)
			local size = mx - mn
			out.WorldPivot = CFrame.new((mn + mx) / 2)
			local maxd = math.max(size.X, size.Y, size.Z)
			if maxd > 0 then
				out:ScaleTo(out:GetScale() * (HEAD_SIZE / maxd))
			end
			out:PivotTo(CFrame.new())
			-- PrimaryPart après coup : sinon WorldPivot / PivotTo gardent l'orientation de la pièce
			out.PrimaryPart = biggest
			if biggest then
				biggest.PivotOffset = biggest.CFrame:Inverse()
			end
			out:SetAttribute("Cartoon", true)
			place(out, "GuardianHead_" .. n)
		end
	end
	heads:Destroy()
end

-- Kits
local kits = workspace:FindFirstChild("guardian_kits")
if kits then
	for _, src in kits:GetChildren() do
		local n = src:IsA("Model") and tonumber(src.Name:match("^GuardianKit_(%d+)"))
		if n then
			local out = Instance.new("Model")
			local groups = {}
			for _, grp in src:GetChildren() do
				local gname = grp.Name:gsub("^.-__", ""):gsub("^K%d+_", "")
				local g = Instance.new("Model")
				g.Name = gname
				local parts = {}
				for _, d in grp:GetDescendants() do
					if d:IsA("BasePart") then
						local hinge = look(d)
						if hinge then
							d:Destroy()
						else
							d.Parent = g
							table.insert(parts, d)
						end
					end
				end
				if #parts > 0 then
					groups[gname] = { Model = g, Parts = parts }
					g.Parent = out
				else
					g:Destroy()
				end
			end
			-- échelle commune : largeur de l'anneau Body = RING_WIDTH
			local body = groups.Body
			if body then
				local mn, mx = bbox(body.Parts)
				local k = RING_WIDTH / (mx.X - mn.X)
				out.WorldPivot = CFrame.new((mn + mx) / 2)
				out:ScaleTo(out:GetScale() * k)
				local bmn, bmx = bbox(body.Parts)
				local bodyCenterX = (bmn.X + bmx.X) / 2
				for gname, info in groups do
					local gmn, gmx = bbox(info.Parts)
					local c = (gmn + gmx) / 2
					local pivot
					if gname == "Body" or gname == "BodyAlt" then
						pivot = Vector3.new(c.X, gmn.Y + RING_WIDTH * 0.45, c.Z) -- centre de l'anneau (hors crinière / pics)
						info.Model:SetAttribute("BodyLen", gmx.Z - gmn.Z)
					elseif gname == "Tail" then
						pivot = Vector3.new(c.X, c.Y, gmn.Z)
						info.Model:SetAttribute("TailLen", gmx.Z - gmn.Z)
					else
						-- Wing / Hood / Fin : charnière au bord intérieur ; Side d'après la position réelle
						local nameSide = if string.sub(gname, -1) == "R" then 1 else -1
						local side = nameSide
						if string.find(gname, "^Wing") or string.find(gname, "^Fin") or string.find(gname, "^Hood") then
							-- Blender +X peut devenir -X à l'import : on se fie à la géométrie de la paire
							local otherName = string.sub(gname, 1, -2) .. (if nameSide == 1 then "L" else "R")
							local other = groups[otherName]
							if other then
								local omn, omx = bbox(other.Parts)
								side = if c.X > (omn.X + omx.X) / 2 then 1 else -1
							end
						end
						info.Model:SetAttribute("Side", side)
						pivot = Vector3.new(if side == 1 then gmn.X else gmx.X, c.Y, c.Z)
					end
					info.Model.WorldPivot = CFrame.new(pivot)
				end
				out:SetAttribute("BodyCenterX", bodyCenterX)
			end
			out:SetAttribute("Cartoon", true)
			place(out, "GuardianKit_" .. n)
		end
	end
	kits:Destroy()
end
return #report .. " : " .. table.concat(report, ",")
