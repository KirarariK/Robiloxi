-- Arene 1 : Sanctuaire du Temple (marbre, colonnes, vitraux au couchant)
local m, O = arenaBase("Sanctuaire", 0, {
	introCam = Vector3.new(26, 12, 26),
	killY = -40,
	lighting = { ClockTime = 17.6, Ambient = Color3.fromRGB(120, 96, 80), OutdoorAmbient = Color3.fromRGB(200, 150, 110),
		FogColor = Color3.fromRGB(240, 190, 140), FogEnd = 900, Brightness = 2.6, GeographicLatitude = 20, ExposureCompensation = 0.1,
		EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 1 },
	fx = {
		Atmosphere = { Density = 0.34, Offset = 0.2, Color = Color3.fromRGB(255, 200, 150), Decay = Color3.fromRGB(190, 110, 80), Glare = 1.2, Haze = 2 },
		Sky = { StarCount = 0, SunAngularSize = 18, CelestialBodiesShown = true },
		ColorCorrectionEffect = { Brightness = 0.03, Contrast = 0.12, Saturation = 0.15, TintColor = Color3.fromRGB(255, 236, 220) },
		BloomEffect = { Intensity = 0.7, Size = 28, Threshold = 1.6 },
		SunRaysEffect = { Intensity = 0.2, Spread = 0.8 },
	},
})
local function at(x, y, z) return CFrame.new(O + Vector3.new(x, y, z)) end
local GOLD, MARBLE, MARBLE2, ROSE = "FFB050", "EDE6DA", "D8CDBD", "B86B5A"
local env = L.model(m, "Environment")
-- sol
L.part(env, "Floor", Vector3.new(112, 4, 112), at(0, -2, 0), MARBLE, M.Marble, { Reflectance = 0.08 })
L.cyl(env, "MosaicGold", 42, 0.1, at(0, 0.03, 0), GOLD, M.Foil, { CanCollide = false })
L.cyl(env, "Mosaic", 40.6, 0.12, at(0, 0.05, 0), "CDBBA2", M.Marble, { CanCollide = false, Reflectance = 0.1 })
L.cyl(env, "MosaicRose", 26, 0.1, at(0, 0.08, 0), ROSE, M.Marble, { CanCollide = false })
L.cyl(env, "MosaicInner", 24.6, 0.12, at(0, 0.1, 0), "E9E0D0", M.Marble, { CanCollide = false, Reflectance = 0.12 })
L.cyl(env, "Medallion", 6, 0.1, at(0, 0.14, 0), GOLD, M.Foil, { CanCollide = false })
for i = 0, 15 do
	local a = i * math.pi / 8
	L.part(env, "MosaicRay", Vector3.new(i % 2 == 0 and 1.2 or 0.5, 0.1, 7.8), CFrame.new(O) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.13, -16.4), i % 2 == 0 and GOLD or ROSE, i % 2 == 0 and M.Foil or M.Marble, { CanCollide = false })
end
for k = -4, 4 do
	if k ~= 0 then
		for _, rot in ipairs({ 0, math.pi / 2 }) do
			local cf = CFrame.new(O) * CFrame.Angles(0, rot, 0) * CFrame.new(k * 11, 0.04, 0)
			L.part(env, "GridGold", Vector3.new(0.25, 0.08, 92), cf, "C79A55", M.Foil, { CanCollide = false })
		end
	end
end
-- estrade de la colonnade (marche)
for _, s in ipairs({ { 0, -52, 112, 16 }, { 0, 52, 112, 16 }, { 52, 0, 16, 80 } }) do
	L.part(env, "Stylobate", Vector3.new(s[3], 1.2, s[4]), at(s[1], 0.6, s[2]), MARBLE2, M.Marble)
end
-- colonnes (ouest ouvert vers le couchant)
local cols = L.model(m, "Colonnade")
local function column(x, z) L.kit(cols, "Column", at(x, 1.2, z), { scale = 1.4, accent = "FF9A4A" }) end
for k = -4, 4 do
	column(k * 11.5, -47); column(k * 11.5, 47)
	if math.abs(k) < 4 then column(47, k * 11.5) end
	if math.abs(k) < 4 and math.abs(k) > 1 then column(-47, k * 11.5) end
end
-- entablement
local TOP = 1.2 + 28
for _, s in ipairs({ { 0, -47, 100, 5 }, { 0, 47, 100, 5 }, { 47, 0, 5, 100 } }) do
	L.part(cols, "Architrave", Vector3.new(s[3], 2.4, s[4]), at(s[1], TOP + 1.2, s[2]), MARBLE, M.Marble)
	L.part(cols, "Frieze", Vector3.new(s[3] + 0.2, 0.5, s[4] + 0.2), at(s[1], TOP + 2.6, s[2]), GOLD, M.Foil)
	L.part(cols, "Cornice", Vector3.new(s[3] + 1.6, 1.4, s[4] + 1.6), at(s[1], TOP + 3.5, s[2]), MARBLE2, M.Marble)
end
-- plafond du portique
for _, s in ipairs({ { 0, -52, 112, 14 }, { 0, 52, 112, 14 }, { 52, 0, 14, 90 } }) do
	L.part(cols, "PorticoRoof", Vector3.new(s[3], 1.5, s[4]), at(s[1], TOP + 4.6, s[2]), "CFC4B2", M.Marble)
end
-- murs a vitraux (nord, sud, est)
local walls = L.model(m, "StainedWalls")
local glassCols = { "FF7A2E", "C8324A", "FFC23C", "7A3CC8", "2E8BFF" }
local function wallSide(cf)
	-- cf : centre du mur, LookVector vers l'interieur
	L.part(walls, "WallBack", Vector3.new(112, 46, 2), cf * CFrame.new(0, 23, -1.2), "D9D0C0", M.Marble)
	for w = -2, 1 do
		local x = w * 26 + 13
		local wcf = cf * CFrame.new(x, 1.2, 1.2)
		L.kit(walls, "Window", wcf, { scale = 1.6 })
		-- verre colore (neon translucide) : 3 lancettes + rosace
		for j = -1, 1 do
			local c = glassCols[((w + j + 5) % #glassCols) + 1]
			local pane = L.part(walls, "Glass", Vector3.new(2.9, 15.6, 0.2), cf * CFrame.new(x + j * 2.75, 1.2 + 8.2, 0.1), c, M.Neon, { Transparency = 0.25, CanCollide = false })
			if j == 0 then L.light(pane, "SurfaceLight", c, 1.6, 34, { Face = Enum.NormalId.Back, Angle = 70 }) end
		end
		L.part(walls, "GlassTop", Vector3.new(8.6, 7, 0.2), cf * CFrame.new(x, 1.2 + 19.5, 0.05), "FF9A4A", M.Neon, { Transparency = 0.3, CanCollide = false })
		L.cyl(walls, "Rose", 5.6, 0.2, cf * CFrame.new(x, 1.2 + 21.1, 0.15) * CFrame.Angles(math.pi / 2, 0, 0), "FFD27A", M.Neon, { Transparency = 0.2, CanCollide = false })
	end
end
wallSide(CFrame.new(O + Vector3.new(0, 0, -58)))
wallSide(CFrame.new(O + Vector3.new(0, 0, 58)) * CFrame.Angles(0, math.pi, 0))
wallSide(CFrame.new(O + Vector3.new(58, 0, 0)) * CFrame.Angles(0, -math.pi / 2, 0))
return #m:GetDescendants()
