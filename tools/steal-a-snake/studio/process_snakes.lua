-- Traite les imports workspace.snakes_N : pièces, couleurs, matières, pivots, échelle → Assets.Models
local Models = game.ReplicatedStorage.StealASnake.Assets.Models
local SNAKE_SIZE = 4.2
local report = {}
local function bbox(model)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Hinge" then
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
	end
	return mn, mx
end
for _, src in workspace:GetChildren() do
	if src:IsA("Model") and src.Name:match("^snakes_%d+$") then
		for _, sp in src:GetChildren() do
			if sp:IsA("Model") then
				local id = sp.Name
				local out = Instance.new("Model")
				out.Name = id
				local biggest, bigSize = nil, 0
				for _, grp in sp:GetChildren() do
					if grp:IsA("Model") then
						local gname = grp.Name:gsub("^.-__", "")
						local g = Instance.new("Model")
						g.Name = gname
						for _, d in grp:GetDescendants() do
							if d:IsA("BasePart") then
								if d.Name:match("^Hinge") then
									d.Name = "Hinge"
									d.Transparency = 1
									d.CastShadow = false
								else
									local kind, hex = string.match(d.Name, "^([cng])_(%x%x%x%x%x%x)")
									if kind then
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
										d.CastShadow = not (hex == "1A1020" or kind == "n")
										if gname == "Body" and hex ~= "1A1020" and kind ~= "n" and d.Size.Magnitude > bigSize then
											biggest, bigSize = d, d.Size.Magnitude
										end
									end
								end
								d.Anchored = true
								d.CanCollide = false
								d.CanTouch = false
								d.CanQuery = false
								d.Parent = g
							end
						end
						g.Parent = out
					end
				end
				out.PrimaryPart = biggest
				local mn, mx = bbox(out)
				local size = mx - mn
				local center = (mn + mx) / 2
				out.WorldPivot = CFrame.new(center)
				local maxd = math.max(size.X, size.Y, size.Z)
				if maxd > 0 then
					out:ScaleTo(out:GetScale() * (SNAKE_SIZE / maxd))
				end
				out:PivotTo(CFrame.new(0, 0, 0))
				out:SetAttribute("Cartoon", true)
				local old = Models:FindFirstChild(id)
				if old then
					old:Destroy()
				end
				out.Parent = Models
				table.insert(report, id)
			end
		end
		src:Destroy()
	end
end
return #report .. " : " .. table.concat(report, ",")
