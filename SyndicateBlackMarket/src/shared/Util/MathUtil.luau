--!strict
--[[
	MathUtil.luau
	Fonctions mathématiques partagées : interpolations, Bézier, angles, tests de
	chevauchement de boîtes (AABB et OBB par axes séparateurs), tirages pondérés et
	formules d'équilibrage (vitesse selon le poids, gain de détection, XP).
]]

local Constants = require(script.Parent.Parent.Constants)

local EPSILON = 1e-6

local MathUtil = {}

--// Interpolations

function MathUtil.lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

function MathUtil.inverseLerp(a: number, b: number, value: number): number
	if math.abs(b - a) < EPSILON then
		return 0
	end
	return (value - a) / (b - a)
end

function MathUtil.remap(value: number, inMin: number, inMax: number, outMin: number, outMax: number, clamp: boolean?): number
	local alpha = MathUtil.inverseLerp(inMin, inMax, value)
	if clamp then
		alpha = math.clamp(alpha, 0, 1)
	end
	return MathUtil.lerp(outMin, outMax, alpha)
end

function MathUtil.clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

-- Lissage exponentiel indépendant du framerate (sharpness en 1/s).
function MathUtil.damp(current: number, target: number, sharpness: number, deltaTime: number): number
	return MathUtil.lerp(current, target, 1 - math.exp(-sharpness * deltaTime))
end

function MathUtil.dampVector(current: Vector3, target: Vector3, sharpness: number, deltaTime: number): Vector3
	return current:Lerp(target, 1 - math.exp(-sharpness * deltaTime))
end

function MathUtil.dampAngle(current: number, target: number, sharpness: number, deltaTime: number): number
	local delta = MathUtil.wrapAngle(target - current)
	return current + delta * (1 - math.exp(-sharpness * deltaTime))
end

function MathUtil.wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

function MathUtil.roundTo(value: number, step: number): number
	if step <= 0 then
		return value
	end
	return math.round(value / step) * step
end

function MathUtil.isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function MathUtil.isFiniteVector(vector: Vector3): boolean
	return MathUtil.isFinite(vector.X) and MathUtil.isFinite(vector.Y) and MathUtil.isFinite(vector.Z)
end

--// Courbes de Bézier

function MathUtil.quadraticBezier(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

function MathUtil.cubicBezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
end

function MathUtil.cubicBezierTangent(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local u = 1 - t
	return (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t)
end

function MathUtil.bezierLength(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, segments: number?): number
	local count = math.max(segments or 16, 1)
	local length = 0
	local previous = p0
	for index = 1, count do
		local point = MathUtil.cubicBezier(p0, p1, p2, p3, index / count)
		length += (point - previous).Magnitude
		previous = point
	end
	return length
end

--// Angles

-- Angle non signé entre deux vecteurs, en radians (stable même pour de petits angles).
function MathUtil.angleBetween(a: Vector3, b: Vector3): number
	if a.Magnitude < EPSILON or b.Magnitude < EPSILON then
		return 0
	end
	return math.atan2(a:Cross(b).Magnitude, a:Dot(b))
end

-- Angle signé de a vers b autour d'un axe, en radians.
function MathUtil.signedAngle(a: Vector3, b: Vector3, axis: Vector3): number
	local angle = MathUtil.angleBetween(a, b)
	if axis:Dot(a:Cross(b)) < 0 then
		return -angle
	end
	return angle
end

-- Vrai si direction est dans un cône (fovDegrees = ouverture totale) autour de forward.
function MathUtil.isInCone(forward: Vector3, direction: Vector3, fovDegrees: number): boolean
	if direction.Magnitude < EPSILON or forward.Magnitude < EPSILON then
		return false
	end
	return forward.Unit:Dot(direction.Unit) >= math.cos(math.rad(fovDegrees * 0.5))
end

-- Fait tourner un vecteur aléatoirement dans un cône (dispersion des tirs).
function MathUtil.randomInCone(direction: Vector3, halfAngle: number, rng: Random): Vector3
	if halfAngle <= 0 or direction.Magnitude < EPSILON then
		return direction
	end
	local unit = direction.Unit
	local cosAngle = 1 - rng:NextNumber() * (1 - math.cos(halfAngle))
	local sinAngle = math.sqrt(math.max(1 - cosAngle * cosAngle, 0))
	local phi = rng:NextNumber() * 2 * math.pi
	local helper = if math.abs(unit.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local right = unit:Cross(helper).Unit
	local up = right:Cross(unit).Unit
	local rotated = unit * cosAngle + (right * math.cos(phi) + up * math.sin(phi)) * sinAngle
	return rotated * direction.Magnitude
end

--// Boîtes

function MathUtil.aabbOverlap(minA: Vector3, maxA: Vector3, minB: Vector3, maxB: Vector3): boolean
	return minA.X < maxB.X and maxA.X > minB.X
		and minA.Y < maxB.Y and maxA.Y > minB.Y
		and minA.Z < maxB.Z and maxA.Z > minB.Z
end

function MathUtil.aabbFromBox(cframe: CFrame, size: Vector3): (Vector3, Vector3)
	local half = size * 0.5
	local right = cframe.RightVector
	local up = cframe.UpVector
	local back = cframe.ZVector
	local extent = Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(back.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
	)
	local center = cframe.Position
	return center - extent, center + extent
end

-- Chevauchement de deux boîtes orientées (OBB) par théorème des axes séparateurs (15 axes).
-- Le contact exact (faces jointives) n'est pas considéré comme un chevauchement.
function MathUtil.boxOverlap(cframeA: CFrame, sizeA: Vector3, cframeB: CFrame, sizeB: Vector3): boolean
	local axesA: { Vector3 } = { cframeA.RightVector, cframeA.UpVector, cframeA.ZVector }
	local axesB: { Vector3 } = { cframeB.RightVector, cframeB.UpVector, cframeB.ZVector }
	local halfA: { number } = { sizeA.X * 0.5, sizeA.Y * 0.5, sizeA.Z * 0.5 }
	local halfB: { number } = { sizeB.X * 0.5, sizeB.Y * 0.5, sizeB.Z * 0.5 }
	local offset = cframeB.Position - cframeA.Position

	local function separatedOn(axis: Vector3): boolean
		if axis.Magnitude < EPSILON then
			return false
		end
		local unit = axis.Unit
		local projectionA = math.abs(axesA[1]:Dot(unit)) * halfA[1]
			+ math.abs(axesA[2]:Dot(unit)) * halfA[2]
			+ math.abs(axesA[3]:Dot(unit)) * halfA[3]
		local projectionB = math.abs(axesB[1]:Dot(unit)) * halfB[1]
			+ math.abs(axesB[2]:Dot(unit)) * halfB[2]
			+ math.abs(axesB[3]:Dot(unit)) * halfB[3]
		return math.abs(offset:Dot(unit)) >= projectionA + projectionB
	end

	for index = 1, 3 do
		if separatedOn(axesA[index]) or separatedOn(axesB[index]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separatedOn(axesA[i]:Cross(axesB[j])) then
				return false
			end
		end
	end
	return true
end

function MathUtil.pointInBox(cframe: CFrame, size: Vector3, point: Vector3): boolean
	local localPoint = cframe:PointToObjectSpace(point)
	local half = size * 0.5
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

--// Tirages

function MathUtil.weightedPick<T>(items: { T }, weightOf: (T) -> number, rng: Random): T?
	local total = 0
	for _, item in items do
		total += math.max(weightOf(item), 0)
	end
	if total <= 0 then
		return nil
	end
	local pick = rng:NextNumber() * total
	for _, item in items do
		local weight = math.max(weightOf(item), 0)
		pick -= weight
		if pick <= 0 and weight > 0 then
			return item
		end
	end
	return items[#items]
end

function MathUtil.shuffle<T>(items: { T }, rng: Random): { T }
	local copy = table.clone(items)
	for index = #copy, 2, -1 do
		local swap = rng:NextInteger(1, index)
		copy[index], copy[swap] = copy[swap], copy[index]
	end
	return copy
end

--// Formules d'équilibrage

-- Vitesse de marche selon l'encombrement (voir Constants.Weight).
function MathUtil.walkSpeedForWeight(baseSpeed: number, weight: number, maxWeight: number): number
	if maxWeight <= 0 then
		return baseSpeed
	end
	local load = math.clamp(weight / maxWeight, 0, 1)
	local settings = Constants.Weight
	local multiplier = math.max(settings.MinSpeedMultiplier, 1 - settings.MaxPenalty * load ^ settings.PenaltyExponent)
	return baseSpeed * multiplier
end

-- Gain de suspicion par seconde pour une cible visible (voir Constants.Detection).
function MathUtil.detectionGainPerSecond(postureMultiplier: number, distance: number, viewDistance: number, visibility: number): number
	local settings = Constants.Detection
	local alpha = math.clamp(distance / math.max(viewDistance, EPSILON), 0, 1)
	local distanceFactor = MathUtil.lerp(settings.NearFactor, settings.FarFactor, alpha)
	return settings.BaseDetectionPerSecond * postureMultiplier * distanceFactor * math.clamp(visibility, 0, 1)
end

-- Atténuation d'un bruit perçu à une distance donnée (0 hors rayon).
function MathUtil.noiseFalloff(intensity: number, radius: number, distance: number): number
	if radius <= 0 or distance >= radius then
		return 0
	end
	return intensity * (1 - distance / radius)
end

-- XP nécessaire pour passer du niveau `level` au suivant.
function MathUtil.xpForLevel(level: number): number
	local settings = Constants.Progression
	return math.round(settings.XpBase * math.max(level, 1) ^ settings.XpExponent)
end

-- Applique de l'XP et retourne (niveau, xp restante, niveaux gagnés).
function MathUtil.applyXp(level: number, xp: number, gained: number): (number, number, number)
	local currentLevel = math.max(level, 1)
	local currentXp = math.max(xp, 0) + math.max(gained, 0)
	local levelsGained = 0
	while currentXp >= MathUtil.xpForLevel(currentLevel) do
		currentXp -= MathUtil.xpForLevel(currentLevel)
		currentLevel += 1
		levelsGained += 1
	end
	return currentLevel, currentXp, levelsGained
end

-- Formate un montant : 14500 -> "$14,500".
function MathUtil.formatMoney(amount: number): string
	local rounded = math.floor(math.abs(amount) + 0.5)
	local digits = tostring(rounded)
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (if amount < 0 then "-$" else "$") .. formatted
end

return table.freeze(MathUtil)
