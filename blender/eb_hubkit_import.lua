-- Ether Blades : range un FBX importe (Workspace.<SRC>) en modeles du kit (sans effacer les autres groupes).
-- ServerStorage.EtherBladesAssets.Kit.<Groupe> (pivot = centre du bas, couleur/materiau lus dans le nom).
local SS = game:GetService("ServerStorage")
local assets = SS:FindFirstChild("EtherBladesAssets") or Instance.new("Folder")
assets.Name = "EtherBladesAssets"; assets.Parent = SS
local kit = assets:FindFirstChild("Kit") or Instance.new("Folder"); kit.Name = "Kit"; kit.Parent = assets
local SRC = "EB_HubKit"
local src = workspace:FindFirstChild(SRC)
assert(src, "Workspace." .. SRC .. " absent")
local MAT = { Metal = Enum.Material.Metal, Marble = Enum.Material.Marble, Neon = Enum.Material.Neon,
  Glass = Enum.Material.Glass, Rubber = Enum.Material.SmoothPlastic, Basalt = Enum.Material.Basalt,
  Slate = Enum.Material.Slate, Rock = Enum.Material.Rock, SmoothPlastic = Enum.Material.SmoothPlastic,
  Limestone = Enum.Material.Limestone, Wood = Enum.Material.Wood, Grass = Enum.Material.Grass, LeafyGrass = Enum.Material.LeafyGrass,
  Fabric = Enum.Material.Fabric, Sandstone = Enum.Material.Sandstone }
local groups = {}
for _, p in ipairs(src:GetDescendants()) do
  if p:IsA("BasePart") then
    local grp, piece, mat, hex = p.Name:match("^([^_]+)_(.-)__(%a+)_(%x+A?)$")
    if grp and grp ~= "REF" then
      local accent = #hex == 7
      hex = hex:sub(1, 6)
      p.Name = piece
      p.Material = MAT[mat] or Enum.Material.SmoothPlastic
      p.Color = Color3.fromRGB(tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16))
      if mat == "Glass" then p.Transparency = 0.35; p.Reflectance = 0.1 end
      if mat == "Metal" then p.Reflectance = 0.15 end
      if hex:upper() == "E3B04A" then p.Reflectance = 0.22 end
      if accent then p:SetAttribute("Accent", true) end
      p.Anchored = true
      p.CanTouch = false
      p.CanCollide = mat ~= "Neon"
      p.CastShadow = mat ~= "Neon" and p.Size.Magnitude > 2
      p.DoubleSided = false
      groups[grp] = groups[grp] or {}
      table.insert(groups[grp], p)
    end
  end
end
local out = {}
for grp, parts in pairs(groups) do
  local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
  for _, p in ipairs(parts) do
    local h = p.Size / 2
    mn = mn:Min(p.Position - h); mx = mx:Max(p.Position + h)
  end
  local old = kit:FindFirstChild(grp); if old then old:Destroy() end
  local m = Instance.new("Model"); m.Name = grp
  local base = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
  for _, p in ipairs(parts) do p.Parent = m end
  m.WorldPivot = CFrame.new(base)
  m:PivotTo(CFrame.new())
  m:SetAttribute("Size", mx - mn)
  m.Parent = kit
  table.insert(out, string.format("%s %d parts %.1fx%.1fx%.1f", grp, #parts, mx.X-mn.X, mx.Y-mn.Y, mx.Z-mn.Z))
end
src:Destroy()
return table.concat(out, "\n")
