--!strict
--[[
	Hitbox serveur : capsule lame vs hurtboxes pendant Active ; clash ; applique dmg via Guard.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BladeConcord"):WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CombatTypes = require(Shared:WaitForChild("CombatTypes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FighterState = require(script.Parent:WaitForChild("FighterState"))
local GuardService = require(script.Parent:WaitForChild("GuardService"))
local StaminaService = require(script.Parent:WaitForChild("StaminaService"))

local HitService = {}

local remotes: Remotes.CombatRemotes? = nil

local function getRemotes(): Remotes.CombatRemotes
	if not remotes then
		remotes = Remotes.get()
	end
	return remotes :: Remotes.CombatRemotes
end

local function bladeParams(kind: CombatTypes.AttackKind?)
	if kind == CombatTypes.AttackKind.Heavy then
		return CombatConfig.Heavy.BladeLength, CombatConfig.Heavy.BladeRadius, CombatConfig.Heavy.Damage, true
	end
	return CombatConfig.Light.BladeLength, CombatConfig.Light.BladeRadius, CombatConfig.Light.Damage, false
end

local function capsuleOverlap(blade: BasePart, hurtbox: BasePart, length: number, radius: number): boolean
	-- Approximation : distance point→segment le long de la lame (LookVector * length)
	local origin = blade.Position - blade.CFrame.LookVector * (length * 0.5)
	local tip = blade.Position + blade.CFrame.LookVector * (length * 0.5)
	local point = hurtbox.Position
	local ab = tip - origin
	local t = math.clamp((point - origin):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	local closest = origin + ab * t
	local dist = (point - closest).Magnitude
	local hurtRadius = math.max(hurtbox.Size.X, hurtbox.Size.Y, hurtbox.Size.Z) * 0.5
	return dist <= (radius + hurtRadius)
end

local function withinDistance(attacker: FighterState.Fighter, defender: FighterState.Fighter, length: number, radius: number): boolean
	local aHrp = attacker.character and attacker.character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local dHrp = defender.character and defender.character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not aHrp or not dHrp then
		return false
	end
	local maxDist = length + 2 + CombatConfig.AntiCheat.MaxHitDistanceMargin + radius
	return (aHrp.Position - dHrp.Position).Magnitude <= maxDist
end

local function fireHit(attacker: Player, defender: Player, result: string, damage: number, flags: { [string]: any })
	local payload = {
		attackerUserId = attacker.UserId,
		defenderUserId = defender.UserId,
		result = result,
		damage = damage,
		perfect = flags.perfect == true,
		guardBreak = flags.guardBreak == true,
		clash = flags.clash == true,
		critical = flags.critical == true,
	}
	getRemotes().HitResolved:FireAllClients(payload)
end

local function applyDamage(defender: FighterState.Fighter, amount: number, isHeavy: boolean)
	defender.hp = math.max(0, defender.hp - amount)
	local humanoid = defender.character and defender.character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Miroir optionnel ; canon = FighterState.hp
		humanoid.Health = math.clamp(defender.hp, 0, CombatConfig.MaxHp)
	end
	if defender.hp <= 0 then
		defender.actionId = CombatTypes.ActionId.Dead
		defender.guardHolding = false
	elseif isHeavy and defender.hp < CombatConfig.Heavy.KnockdownHpThreshold then
		defender.staggerUntil = os.clock() + CombatConfig.Guard.GuardBreakStagger
		defender.actionId = CombatTypes.ActionId.Stagger
	end
end

local function resolveBodyHit(attacker: FighterState.Fighter, defender: FighterState.Fighter, isHeavy: boolean, baseDamage: number, isHead: boolean)
	local contactClock = os.clock()
	local resolution = GuardService.resolveIncomingHit(defender, attacker, contactClock)

	local damage = baseDamage
	if isHead then
		damage *= CombatConfig.Light.HeadMultiplier
	end
	if os.clock() < attacker.riposteBuffUntil and attacker.attackKind == CombatTypes.AttackKind.Light then
		damage *= (1 + CombatConfig.Guard.RiposteLightDamageBonus)
	end
	damage *= resolution.damageMultiplier
	damage = math.floor(damage + 0.5)

	if resolution.applyRiposteLockToAttacker then
		attacker.riposteLockUntil = os.clock() + CombatConfig.Guard.RiposteLockDuration
		defender.riposteBuffUntil = os.clock() + CombatConfig.Guard.RiposteBuffDuration
	end
	if resolution.applyStaggerToDefender then
		defender.staggerUntil = os.clock() + CombatConfig.Guard.GuardBreakStagger
		defender.actionId = CombatTypes.ActionId.Stagger
		defender.guardHolding = false
	end

	local result: string = CombatTypes.HitResult.Full
	if resolution.guardResult == CombatTypes.GuardResult.Perfect then
		result = CombatTypes.HitResult.Perfect
	elseif resolution.guardResult == CombatTypes.GuardResult.Break then
		result = CombatTypes.HitResult.GuardBreak
	elseif resolution.guardResult == CombatTypes.GuardResult.Normal then
		result = CombatTypes.HitResult.Chip
	end

	if damage > 0 then
		applyDamage(defender, damage, isHeavy)
		if result == CombatTypes.HitResult.Full and not isHeavy then
			-- flinch soft : petit lock via phaseTimer non nécessaire ; flag côté client via HitResolved
		end
	end

	fireHit(attacker.player, defender.player, result, damage, {
		perfect = result == CombatTypes.HitResult.Perfect,
		guardBreak = result == CombatTypes.HitResult.GuardBreak,
		critical = isHead,
	})
end

local function tryClash(a: FighterState.Fighter, b: FighterState.Fighter): boolean
	if a.actionId ~= CombatTypes.ActionId.Active or b.actionId ~= CombatTypes.ActionId.Active then
		return false
	end
	if not a.bladePart or not b.bladePart then
		return false
	end
	local lenA = select(1, bladeParams(a.attackKind))
	local radA = select(2, bladeParams(a.attackKind))
	local lenB = select(1, bladeParams(b.attackKind))
	local radB = select(2, bladeParams(b.attackKind))
	-- Capsules se chevauchent ?
	local midA = a.bladePart.Position
	local midB = b.bladePart.Position
	if (midA - midB).Magnitude > (lenA + lenB) * 0.5 + radA + radB then
		return false
	end

	StaminaService.tryConsume(a, CombatConfig.Clash.StaminaPenalty)
	StaminaService.tryConsume(b, CombatConfig.Clash.StaminaPenalty)

	-- Micro-KB
	local function knock(f: FighterState.Fighter, awayFrom: Vector3)
		local hrp = f.character and f.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and not hrp.Anchored then
			local dir = Vector3.new(hrp.Position.X - awayFrom.X, 0, hrp.Position.Z - awayFrom.Z)
			if dir.Magnitude > 1e-3 then
				hrp.AssemblyLinearVelocity = dir.Unit * CombatConfig.Clash.MicroKnockbackStuds * 10
			end
		end
	end
	knock(a, midB)
	knock(b, midA)

	-- Pas de double-hit corps sur la même frame de clash
	a.hitThisSwing[b.player.UserId] = true
	b.hitThisSwing[a.player.UserId] = true

	fireHit(a.player, b.player, CombatTypes.HitResult.Clash, 0, { clash = true })
	fireHit(b.player, a.player, CombatTypes.HitResult.Clash, 0, { clash = true })
	return true
end

function HitService.step(_dt: number)
	local fighters = FighterState.getAll()
	-- Clash pairs
	for i = 1, #fighters do
		for j = i + 1, #fighters do
			tryClash(fighters[i], fighters[j])
		end
	end

	for _, attacker in fighters do
		if attacker.actionId ~= CombatTypes.ActionId.Active then
			continue
		end
		if not attacker.bladePart then
			continue
		end
		local length, radius, damage, isHeavy = bladeParams(attacker.attackKind)

		for _, defender in fighters do
			if defender.player == attacker.player then
				continue
			end
			if defender.actionId == CombatTypes.ActionId.Dead then
				continue
			end
			if attacker.hitThisSwing[defender.player.UserId] then
				continue
			end
			if not withinDistance(attacker, defender, length, radius) then
				-- Reject hors distance (anti-cheat)
				continue
			end

			local hitHurtbox: BasePart? = nil
			local isHead = false
			for _, hb in defender.hurtboxes do
				if capsuleOverlap(attacker.bladePart, hb, length, radius) then
					hitHurtbox = hb
					isHead = string.lower(hb.Name):find("head") ~= nil
					break
				end
			end
			-- Fallback : HumanoidRootPart si pas de hurtbox taguée
			if not hitHurtbox and defender.character then
				local hrp = defender.character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and capsuleOverlap(attacker.bladePart, hrp, length, radius) then
					hitHurtbox = hrp
				end
			end

			if hitHurtbox then
				attacker.hitThisSwing[defender.player.UserId] = true
				resolveBodyHit(attacker, defender, isHeavy, damage, isHead)
			end
		end
	end
end

return HitService
