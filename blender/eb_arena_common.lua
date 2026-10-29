-- ModuleScript temporaire (ServerStorage.EB_ArenaLib) utilise pendant la construction des arenes, puis supprime.
-- A.base(id, index, opts) : cree Workspace.EB_Build_<id> a x = 2000 + index*600 avec Markers
--   (Center = PrimaryPart, PivotOffset identite ; SpawnA/SpawnB a 24 studs face a face ; IntroCam ; KillY)
--   et le Folder Lighting (attributs + Atmosphere/Sky/ColorCorrection/Bloom/SunRays clonables).
-- A.preview(m) : applique ce Folder Lighting a game.Lighting (apercu en edition).
-- Une fois l'arene finie : renommer en <id> et ranger dans ServerStorage.EtherBladesAssets.Arenas.
local L = require(game.ServerStorage.EB_BuildLib)
local A = {}
function A.base(id, index, opts)
	local O = Vector3.new(2000 + index * 600, 0, 0)
	local old = workspace:FindFirstChild("EB_Build_" .. id); if old then old:Destroy() end
	local m = Instance.new("Model"); m.Name = "EB_Build_" .. id
	m:SetAttribute("ArenaId", id)
	local mk = L.model(m, "Markers")
	local center = L.marker(mk, "Center", CFrame.new(O + Vector3.new(0, 3, 0)), Vector3.new(2, 2, 2))
	L.marker(mk, "SpawnA", CFrame.lookAt(O + Vector3.new(0, 3, -12), O + Vector3.new(0, 3, 12)), Vector3.new(2, 2, 2))
	L.marker(mk, "SpawnB", CFrame.lookAt(O + Vector3.new(0, 3, 12), O + Vector3.new(0, 3, -12)), Vector3.new(2, 2, 2))
	local ic = opts.introCam or Vector3.new(30, 10, 0)
	L.marker(mk, "IntroCam", CFrame.lookAt(O + ic, O + Vector3.new(0, 4, 0)), Vector3.new(1, 1, 1))
	L.marker(mk, "KillY", CFrame.new(O + Vector3.new(0, opts.killY or -40, 0)), Vector3.new(2, 2, 2))
	m.PrimaryPart = center
	center.PivotOffset = CFrame.new()
	local lf = L.folder(m, "Lighting")
	for k, v in pairs(opts.lighting) do lf:SetAttribute(k, v) end
	for cls, props in pairs(opts.fx) do
		local o = Instance.new(cls); o.Name = (cls:gsub("Effect$", ""))
		for k, v in pairs(props) do o[k] = v end
		o.Parent = lf
	end
	m.Parent = workspace
	return m, O
end
function A.preview(m)
	local Lg = game.Lighting
	local lf = m:FindFirstChild("Lighting")
	for k, v in pairs(lf:GetAttributes()) do pcall(function() Lg[k] = v end) end
	for _, c in ipairs(Lg:GetChildren()) do if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then c:Destroy() end end
	for _, c in ipairs(lf:GetChildren()) do c:Clone().Parent = Lg end
end
return A
