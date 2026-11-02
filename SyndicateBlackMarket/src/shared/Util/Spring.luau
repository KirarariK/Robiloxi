--!strict
--[[
	Spring.luau
	Ressort physique amorti (loi de Hooke) sur Vector3, intégré en Euler semi-implicite
	avec des sous-pas fixes pour rester stable quel que soit le framerate.

		accélération = (-raideur * (position - cible) - amortissement * vitesse) / masse

	Construction par fréquence (Hz) et taux d'amortissement ζ :
		raideur       = masse * (2π f)²
		amortissement = 2 ζ masse (2π f)
	ζ < 1 : rebond, ζ = 1 : critique, ζ > 1 : sur-amorti.
	Pour un scalaire, utiliser la composante X (newScalar / getScalar / setScalarTarget).
]]

local SUBSTEP = 1 / 240
local MAX_SUBSTEPS = 16

type SpringData = {
	Position: Vector3,
	Velocity: Vector3,
	Target: Vector3,
	Stiffness: number,
	Damping: number,
	Mass: number,
}

local SpringMethods = {}
SpringMethods.__index = SpringMethods

export type Spring = typeof(setmetatable({} :: SpringData, SpringMethods))

local Spring = {}

function Spring.fromConstants(initial: Vector3, stiffness: number, damping: number, mass: number?): Spring
	local data: SpringData = {
		Position = initial,
		Velocity = Vector3.zero,
		Target = initial,
		Stiffness = math.max(stiffness, 0),
		Damping = math.max(damping, 0),
		Mass = math.max(mass or 1, 1e-4),
	}
	return setmetatable(data, SpringMethods)
end

function Spring.new(initial: Vector3, frequency: number, dampingRatio: number): Spring
	local omega = 2 * math.pi * math.max(frequency, 0)
	return Spring.fromConstants(initial, omega * omega, 2 * math.max(dampingRatio, 0) * omega, 1)
end

function Spring.newScalar(initial: number, frequency: number, dampingRatio: number): Spring
	return Spring.new(Vector3.new(initial, 0, 0), frequency, dampingRatio)
end

function SpringMethods.SetFrequency(self: Spring, frequency: number, dampingRatio: number)
	local omega = 2 * math.pi * math.max(frequency, 0)
	self.Stiffness = self.Mass * omega * omega
	self.Damping = 2 * math.max(dampingRatio, 0) * self.Mass * omega
end

function SpringMethods.SetTarget(self: Spring, target: Vector3)
	self.Target = target
end

function SpringMethods.SetScalarTarget(self: Spring, target: number)
	self.Target = Vector3.new(target, 0, 0)
end

-- Ajoute une vitesse instantanée (secousse, recul, atterrissage).
function SpringMethods.Impulse(self: Spring, velocity: Vector3)
	self.Velocity += velocity
end

function SpringMethods.Reset(self: Spring, position: Vector3)
	self.Position = position
	self.Target = position
	self.Velocity = Vector3.zero
end

function SpringMethods.Update(self: Spring, deltaTime: number): Vector3
	if deltaTime <= 0 then
		return self.Position
	end
	local steps = math.min(math.ceil(deltaTime / SUBSTEP), MAX_SUBSTEPS)
	local h = deltaTime / steps
	local position = self.Position
	local velocity = self.Velocity
	local target = self.Target
	local stiffness = self.Stiffness
	local damping = self.Damping
	local inverseMass = 1 / self.Mass
	for _ = 1, steps do
		local acceleration = (-(position - target) * stiffness - velocity * damping) * inverseMass
		velocity += acceleration * h
		position += velocity * h
	end
	self.Position = position
	self.Velocity = velocity
	return position
end

function SpringMethods.GetPosition(self: Spring): Vector3
	return self.Position
end

function SpringMethods.GetScalar(self: Spring): number
	return self.Position.X
end

function SpringMethods.GetVelocity(self: Spring): Vector3
	return self.Velocity
end

function SpringMethods.IsResting(self: Spring, epsilon: number?): boolean
	local limit = epsilon or 1e-3
	return (self.Position - self.Target).Magnitude < limit and self.Velocity.Magnitude < limit
end

return table.freeze(Spring)
