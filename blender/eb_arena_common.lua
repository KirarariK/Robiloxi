-- Prefixe commun des scripts d'arene (colle en tete de chaque construction).
local L = require(game.ServerStorage.EB_BuildLib)
local M = Enum.Material
local function arenaBase(id, index, opts)
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
	-- dossier Lighting (attributs + instances clonables)
	local lf = L.folder(m, "Lighting")
	for k, v in pairs(opts.lighting) do lf:SetAttribute(k, v) end
	for cls, props in pairs(opts.fx) do
		local o = Instance.new(cls); o.Name = cls:gsub("Effect$", "")
		for k, v in pairs(props) do o[k] = v end
		o.Parent = lf
	end
	m.Parent = workspace
	return m, O
end
