--!strict
--[[
	WeaponDatabase.luau
	Statistiques des armes (dégâts, cadence, recul, portée sonore) et des outils.

	Dégâts à distance d :
		d <= FalloffStart           -> Damage
		FalloffStart < d < MaxRange -> interpolation linéaire vers Damage * MinDamageMultiplier
		d >= MaxRange               -> 0 (hors portée)
	Multiplié par HeadshotMultiplier pour un tir à la tête.
]]

local Types = require(script.Parent.Types)

type WeaponDefinition = Types.WeaponDefinition
type ToolDefinition = Types.ToolDefinition
type RecoilProfile = Types.RecoilProfile

local WEAPONS: { WeaponDefinition } = {
	table.freeze({
		Id = "USP_Tactical",
		DisplayName = "USP Tactique (silencieux)",
		ModelName = "Weapon_USP_Tactical",
		Automatic = false,
		Damage = 34,
		HeadshotMultiplier = 2.2,
		FireRate = 420,
		MagazineSize = 12,
		ReserveAmmo = 60,
		ReloadTime = 1.6,
		MaxRange = 220,
		FalloffStart = 60,
		MinDamageMultiplier = 0.55,
		HipSpread = 1.8,
		AimSpread = 0.35,
		Recoil = table.freeze({ Vertical = 1.6, Horizontal = 0.5, Recovery = 9, Kick = 0.12 } :: RecoilProfile),
		NoiseRadius = 12,
		NoiseIntensity = 0.3,
		Suppressed = true,
		Price = 0,
		AimFov = 60,
	} :: WeaponDefinition),
	table.freeze({
		Id = "SubmachineGun",
		DisplayName = "PMG Vector-X",
		ModelName = "Weapon_SubmachineGun",
		Automatic = true,
		Damage = 22,
		HeadshotMultiplier = 1.8,
		FireRate = 900,
		MagazineSize = 25,
		ReserveAmmo = 150,
		ReloadTime = 2.1,
		MaxRange = 160,
		FalloffStart = 35,
		MinDamageMultiplier = 0.45,
		HipSpread = 3.2,
		AimSpread = 1.1,
		Recoil = table.freeze({ Vertical = 0.9, Horizontal = 0.8, Recovery = 12, Kick = 0.08 } :: RecoilProfile),
		NoiseRadius = 90,
		NoiseIntensity = 1,
		Suppressed = false,
		Price = 6500,
		AimFov = 55,
	} :: WeaponDefinition),
}

local TOOLS: { ToolDefinition } = {
	table.freeze({
		Id = "CyberDeck",
		DisplayName = "CyberDeck",
		ModelName = "Tool_CyberDeck",
		Price = 0,
		Cooldown = 1,
		Radius = 10,
		Duration = 0,
		Charges = -1,
		NoiseRadius = 0,
	} :: ToolDefinition),
	table.freeze({
		Id = "EMP_Jammer",
		DisplayName = "Brouilleur IEM",
		ModelName = "Tool_EMP_Jammer",
		Price = 3000,
		Cooldown = 30,
		Radius = 22,
		Duration = 8,
		Charges = 2,
		NoiseRadius = 8,
	} :: ToolDefinition),
}

local weaponsById: { [string]: WeaponDefinition } = {}
for _, weapon in WEAPONS do
	assert(weaponsById[weapon.Id] == nil, "WeaponDatabase : arme dupliquée " .. weapon.Id)
	weaponsById[weapon.Id] = weapon
end

local toolsById: { [string]: ToolDefinition } = {}
for _, tool in TOOLS do
	assert(toolsById[tool.Id] == nil, "WeaponDatabase : outil dupliqué " .. tool.Id)
	toolsById[tool.Id] = tool
end

local WeaponDatabase = {}

WeaponDatabase.Weapons = table.freeze(WEAPONS)
WeaponDatabase.Tools = table.freeze(TOOLS)
WeaponDatabase.StarterWeapon = "USP_Tactical"
WeaponDatabase.StarterTool = "CyberDeck"

function WeaponDatabase.getWeapon(id: string): WeaponDefinition?
	return weaponsById[id]
end

function WeaponDatabase.getTool(id: string): ToolDefinition?
	return toolsById[id]
end

function WeaponDatabase.isEquipment(id: string): boolean
	return weaponsById[id] ~= nil or toolsById[id] ~= nil
end

function WeaponDatabase.priceOf(id: string): number?
	local weapon = weaponsById[id]
	if weapon then
		return weapon.Price
	end
	local tool = toolsById[id]
	if tool then
		return tool.Price
	end
	return nil
end

function WeaponDatabase.fireInterval(weapon: WeaponDefinition): number
	return 60 / weapon.FireRate
end

function WeaponDatabase.damageAt(weapon: WeaponDefinition, distance: number, headshot: boolean): number
	if distance >= weapon.MaxRange then
		return 0
	end
	local base: number
	if distance <= weapon.FalloffStart then
		base = weapon.Damage
	else
		local alpha = (distance - weapon.FalloffStart) / (weapon.MaxRange - weapon.FalloffStart)
		base = weapon.Damage * (1 + (weapon.MinDamageMultiplier - 1) * alpha)
	end
	if headshot then
		base *= weapon.HeadshotMultiplier
	end
	return base
end

-- Dispersion en radians selon la visée et la posture.
function WeaponDatabase.spreadRadians(weapon: WeaponDefinition, aiming: boolean, crouching: boolean, moving: boolean): number
	local degrees = if aiming then weapon.AimSpread else weapon.HipSpread
	if crouching then
		degrees *= 0.7
	end
	if moving then
		degrees *= 1.5
	end
	return math.rad(degrees)
end

return table.freeze(WeaponDatabase)
