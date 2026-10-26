--!strict
--[[
	Helpers VFX néon réutilisables — hall croiseur + armes / sabres.
	- ParticleEmitter strips (tag BC_NeonStrip)
	- Trail armes (attachments stables)
	- Glow pulse léger (Tween Transparency / Color — pas de flood PointLight)

	Budget emitters : le caller injecte remaining/note (ex. LobbyUtil) pour rester ≤30 total hall.
	Identité Focus cyan / Arcane / Gold via Theme.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))

local NeonFx = {}

NeonFx.TAG = "BC_NeonStrip"
NeonFx.EMITTER_NAME = "NeonStripFx"
NeonFx.TRAIL_NAME = "WeaponTrail"
NeonFx.PULSE_ATTR = "BC_GlowPulse"

-- Cap strips hall depuis le budget restant (laisse marge pads / forge / slots)
NeonFx.HallStripEmitterCap = 12

export type BudgetHooks = {
	remaining: () -> number,
	note: () -> boolean,
}

export type StripOpts = {
	rate: number?,
	lifetime: NumberRange?,
	speed: NumberRange?,
	spread: Vector2?,
	size: NumberSequence?,
	color: Color3?,
}

export type TrailOpts = {
	lifetime: number?,
	minLength: number?,
	maxLength: number?,
	enabled: boolean?,
	width: number?, -- demi-écart attachments
	lengthFrac: number?, -- fraction Size.Z pour placer les att
}

export type PulseOpts = {
	amp: number?, -- delta Transparency
	period: number?, -- secondes aller-retour
	colorAmp: boolean?, -- léger lerp Color vers blanc
}

local function ensureAttachment(parent: Instance, name: string, position: Vector3?): Attachment
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local att = Instance.new("Attachment")
	att.Name = name
	if position then
		att.Position = position
	end
	att.Parent = parent
	return att
end

local function defaultStripColor(color: Color3?): Color3
	return color or Theme.Focus or Theme.Accent
end

function NeonFx.tagStrip(part: BasePart)
	CollectionService:AddTag(part, NeonFx.TAG)
	part:SetAttribute(NeonFx.PULSE_ATTR, true)
end

--[[
	Emitter drift léger le long d’un strip Neon (Rate bas, lifetime courte — mobile OK).
	Idempotent : ne recrée pas si NeonStripFx existe déjà.
]]
function NeonFx.attachStripEmitter(part: BasePart, color: Color3?, opts: StripOpts?, hooks: BudgetHooks?): ParticleEmitter?
	local found = part:FindFirstChild(NeonFx.EMITTER_NAME, true)
	if found and found:IsA("ParticleEmitter") then
		return found
	end
	if hooks and hooks.remaining() <= 0 then
		return nil
	end
	if hooks and not hooks.note() then
		return nil
	end

	local o = opts or {}
	local col = defaultStripColor(o.color or color)
	local att = ensureAttachment(part, "NeonStripAtt", Vector3.zero)

	local pe = Instance.new("ParticleEmitter")
	pe.Name = NeonFx.EMITTER_NAME
	pe.Rate = o.rate or 3
	pe.Lifetime = o.lifetime or NumberRange.new(0.55, 1.1)
	pe.Speed = o.speed or NumberRange.new(0.05, 0.35)
	pe.SpreadAngle = o.spread or Vector2.new(8, 180)
	pe.Acceleration = Vector3.new(0, 0.15, 0)
	pe.Drag = 1.5
	pe.Size = o.size
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.4, 0.12),
			NumberSequenceKeypoint.new(1, 0.02),
		})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.25, 0.35),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, col),
		ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, col),
	})
	pe.LightEmission = 0.85
	pe.LightInfluence = 0
	pe.LockedToPart = true
	pe.Enabled = true
	pe.Parent = att
	return pe
end

--[[
	Trail arme / sabre : deux attachments le long de +Z local (LookVector lame).
	N’écrase pas SaberTrail existant — crée WeaponTrail si absent.
]]
function NeonFx.attachWeaponTrail(host: BasePart, color: Color3?, opts: TrailOpts?): Trail?
	local existing = host:FindFirstChild(NeonFx.TRAIL_NAME)
	if existing and existing:IsA("Trail") then
		return existing
	end
	-- Respect sabre combat déjà équipé
	if host:FindFirstChild("SaberTrail") or host:FindFirstChild("SaberTrailStub") then
		local saber = host:FindFirstChild("SaberTrail") or host:FindFirstChild("SaberTrailStub")
		if saber and saber:IsA("Trail") then
			return saber
		end
	end

	local o = opts or {}
	local col = defaultStripColor(color)
	local halfW = o.width or 0.1
	local frac = o.lengthFrac or 0.38
	local halfLen = host.Size.Z * frac

	local a0 = ensureAttachment(host, "WeaponTrailA", Vector3.new(0, halfW, halfLen))
	local a1 = ensureAttachment(host, "WeaponTrailB", Vector3.new(0, -halfW, -halfLen))

	local trail = Instance.new("Trail")
	trail.Name = NeonFx.TRAIL_NAME
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = o.lifetime or 0.22
	trail.MinLength = o.minLength or 0.04
	trail.MaxLength = o.maxLength or 5
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, col),
		ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, col),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.55, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Enabled = if o.enabled == nil then false else o.enabled
	trail.Parent = host
	return trail
end

function NeonFx.setTrailEnabled(host: BasePart, on: boolean)
	local trail = host:FindFirstChild(NeonFx.TRAIL_NAME)
		or host:FindFirstChild("SaberTrail")
		or host:FindFirstChild("SaberTrailStub")
	if trail and trail:IsA("Trail") then
		trail.Enabled = on
	end
	local rim = host:FindFirstChild("SaberTrailRim")
	if rim and rim:IsA("Trail") then
		rim.Enabled = on
	end
end

--[[
	Pulse Transparency léger (et optionnellement Color). Client-friendly.
	Retourne une fonction cancel().
]]
function NeonFx.pulseGlow(part: BasePart, opts: PulseOpts?): () -> ()
	local o = opts or {}
	local amp = o.amp or 0.12
	local period = o.period or 2.4
	local baseT = part.Transparency
	local hiT = math.clamp(baseT + amp, 0, 0.92)
	local baseColor = part.Color
	local hiColor = baseColor:Lerp(Color3.new(1, 1, 1), 0.22)

	local cancelled = false
	local current: Tween? = nil

	local function run(toHi: boolean)
		if cancelled or not part.Parent then
			return
		end
		local goal: { [string]: any } = { Transparency = if toHi then hiT else baseT }
		if o.colorAmp then
			goal.Color = if toHi then hiColor else baseColor
		end
		local tw = TweenService:Create(
			part,
			TweenInfo.new(period * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			goal
		)
		current = tw
		tw.Completed:Once(function()
			if not cancelled then
				run(not toHi)
			end
		end)
		tw:Play()
	end

	run(true)

	return function()
		cancelled = true
		if current then
			current:Cancel()
			current = nil
		end
		if part.Parent then
			part.Transparency = baseT
			part.Color = baseColor
		end
	end
end

--[[
	Parcourt CollectionService BC_NeonStrip (scope optionnel) et attache emitters sous budget.
	Idempotent. Retourne le nombre d’emitters créés cette passe.
]]
function NeonFx.bindTaggedStrips(scope: Instance?, hooks: BudgetHooks?, maxEmitters: number?): number
	local cap = maxEmitters or NeonFx.HallStripEmitterCap
	local created = 0
	local tagged = CollectionService:GetTagged(NeonFx.TAG)
	for _, inst in tagged do
		if created >= cap then
			break
		end
		if not inst:IsA("BasePart") then
			continue
		end
		if scope and not inst:IsDescendantOf(scope) then
			continue
		end
		if inst:FindFirstChild(NeonFx.EMITTER_NAME, true) then
			continue
		end
		if hooks and hooks.remaining() <= 0 then
			break
		end
		local pe = NeonFx.attachStripEmitter(inst, inst.Color, nil, hooks)
		if pe then
			created += 1
		end
	end
	return created
end

--[[
	Hook InstanceAdded — pour strips posés plus tard par World / LobbyProps.
]]
function NeonFx.watchTaggedStrips(scope: Instance?, hooks: BudgetHooks?, maxEmitters: number?): RBXScriptConnection
	local cap = maxEmitters or NeonFx.HallStripEmitterCap
	local live = 0
	-- seed
	live += NeonFx.bindTaggedStrips(scope, hooks, cap)
	return CollectionService:GetInstanceAddedSignal(NeonFx.TAG):Connect(function(inst)
		if live >= cap then
			return
		end
		if not inst:IsA("BasePart") then
			return
		end
		if scope and not inst:IsDescendantOf(scope) then
			return
		end
		if hooks and hooks.remaining() <= 0 then
			return
		end
		local pe = NeonFx.attachStripEmitter(inst, inst.Color, nil, hooks)
		if pe then
			live += 1
		end
	end)
end

function NeonFx.hooksFromCounters(remainingFn: () -> number, noteFn: () -> boolean): BudgetHooks
	return {
		remaining = remainingFn,
		note = noteFn,
	}
end

return NeonFx
