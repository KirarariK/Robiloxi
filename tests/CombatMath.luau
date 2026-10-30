--!strict
local LoadModule = require("./Support/LoadModule")
local Roblox = require("@lune/roblox")
local CombatMath = LoadModule.fromSource("src/shared/Combat/CombatMath.lua")
local Vector3 = Roblox.Vector3
local CFrame = Roblox.CFrame

local weapon = { AttackSpeed = 1, StaminaCost = 1, ComboLength = 3, HeavyRecovery = 0.6 }
local form = { Stats = { AttackSpeed = 1, StaminaCost = 1, DodgeSpeed = 1, ParryWindow = 1 } }
assert(CombatMath.nextCombo(1, 1, 1.1, weapon) == 2, "Le combo doit avancer avant expiration")
assert(CombatMath.nextCombo(3, 1, 1.1, weapon) == 1, "Le combo doit revenir au coup 1 après le finisher")
assert(CombatMath.nextCombo(1, 1, 2, weapon) == 1, "Le combo doit expirer")
local timing = CombatMath.lightTiming(form, weapon, 3, "Neutral", false)
assert(timing.Windup == 0.17 and math.abs(timing.Recovery - 0.44) < 1e-6, "Le timing finisher doit inclure sa récupération")
assert(CombatMath.variant(Vector3.new(0, 0, -1), Vector3.new(0, 0, -1)) == "Forward", "La direction avant doit être reconnue")
assert(CombatMath.variant(Vector3.new(0, 0, -1), Vector3.new(0, 0, 1)) == "Back", "La direction arrière doit être reconnue")
assert(CombatMath.variant(Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)) == "Side", "La direction latérale doit être reconnue")
assert(CombatMath.lightClip(2, "Forward", false, false) == "M1_2_F", "La variante directionnelle doit nommer le clip")
assert(CombatMath.dodgeLetter(CFrame.new(), Vector3.new(1, 0, 0)) == "R", "L'esquive à droite doit être reconnue")

print("CombatMath : OK")
