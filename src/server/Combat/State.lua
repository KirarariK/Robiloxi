--!strict
-- Registre serveur des combattants (joueurs + mannequins) et des duels, et types partagés du combat.
-- Aucun module de combat n'en requiert un autre en boucle : ils passent tous par ce registre et ses hooks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Types = require(Shared.Types)
local Maid = require(Shared.Util.Maid)
local CombatConfig = require(Shared.Combat.CombatConfig)

export type CombatState = CombatConfig.CombatState

export type Fighter = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Player: Player?,
	IsDummy: boolean,
	Form: Types.FormDef,
	Weapon: Types.WeaponDef,
	ColorId: string,

	State: CombatState,
	StateUntil: number, -- fin de l'état temporisé courant (0 = aucun)
	Alive: boolean,

	Health: number,
	MaxHealth: number,
	Posture: number,
	MaxPosture: number,
	Stamina: number,
	MaxStamina: number,
	LastPostureLoss: number,
	LastStaminaUse: number,
	LastHitTaken: number,

	ComboIndex: number,
	LastLightEnd: number,
	NextActionAt: number,

	Pending: thread?, -- impact programmé
	PendingKind: string?, -- "Light" | "Heavy" | "Counter"
	PendingAt: number,
	Buffered: thread?, -- léger tamponné
	ChargeStart: number?, -- coup lourd en charge
	ChargeThread: thread?,
	HeavyReleasedAt: number,
	AutoReleasedAt: number,

	BlockHeld: boolean,
	ParryStart: number,
	ParryWindow: number,
	ParryReadyAt: number,
	IFramesUntil: number,
	DodgeReadyAt: number,
	CounterUntil: number,

	Frozen: boolean,
	SaberOn: boolean,
	LastCombatAt: number,
	MatchId: string?,
	Opponent: Fighter?,

	AttrClock: number, -- dernière écriture des attributs de régénération
	Maid: Maid.Maid,
}

export type HitInfo = {
	Kind: string, -- "Light" | "Heavy" | "Counter"
	Damage: number,
	Posture: number,
	Push: number,
	Reach: number,
	Arc: number,
	Unblockable: boolean,
	ClientTime: number?,
	ComboFinisher: boolean,
}

export type Duel = {
	Id: string,
	A: Player,
	B: Player,
	Arena: Model,
	SpawnA: CFrame,
	SpawnB: CFrame,
	IntroCam: CFrame,
	KillY: number?,
	Active: boolean,
	RoundOver: boolean,
	Maid: Maid.Maid,
}

export type Hooks = {
	-- un coup part : les mannequins peuvent réagir (parade / garde)
	attackStarted: (attacker: Fighter, windup: number, kind: string) -> (),
	-- PV à zéro
	defeated: (f: Fighter, source: Fighter?) -> (),
	-- poussée d'un combattant sans client propriétaire (mannequin)
	pushNpc: (f: Fighter, offset: Vector3) -> (),
}

local State = {}

State.fighters = {} :: { [Model]: Fighter }
State.byPlayer = {} :: { [Player]: Fighter }
State.dummies = {} :: { Fighter }
State.duels = {} :: { [string]: Duel }
State.playerDuel = {} :: { [Player]: string }

local function noop() end

State.hooks = {
	attackStarted = function(_a: Fighter, _w: number, _k: string)
		noop()
	end,
	defeated = function(_f: Fighter, _s: Fighter?)
		noop()
	end,
	pushNpc = function(_f: Fighter, _o: Vector3)
		noop()
	end,
} :: Hooks

function State.now(): number
	return os.clock()
end

function State.add(f: Fighter)
	State.fighters[f.Model] = f
	if f.Player then
		State.byPlayer[f.Player] = f
	end
	if f.IsDummy then
		table.insert(State.dummies, f)
	end
end

function State.remove(f: Fighter)
	if State.fighters[f.Model] == f then
		State.fighters[f.Model] = nil
	end
	local p = f.Player
	if p and State.byPlayer[p] == f then
		State.byPlayer[p] = nil
	end
	local i = table.find(State.dummies, f)
	if i then
		table.remove(State.dummies, i)
	end
end

function State.duelOf(f: Fighter): Duel?
	local id = f.MatchId
	return if id then State.duels[id] else nil
end

-- Le combattant peut-il agir ? (vivant, non gelé, et round actif s'il est en duel)
function State.canAct(f: Fighter): boolean
	if not f.Alive or f.Frozen or f.State == "Dead" then
		return false
	end
	if f.MatchId then
		local d = State.duelOf(f)
		return d ~= nil and d.Active and not d.RoundOver
	end
	return true
end

-- Comme canAct, sans tenir compte du gel (sortie d'un Saber Lock).
function State.canActIgnoringFreeze(f: Fighter): boolean
	if not f.Alive or f.State == "Dead" then
		return false
	end
	if f.MatchId then
		local d = State.duelOf(f)
		return d ~= nil and d.Active and not d.RoundOver
	end
	return true
end

-- Cibles possibles : l'adversaire en duel, les mannequins dans le Hub (pas de PvP hors duel).
function State.targetsFor(f: Fighter): { Fighter }
	if f.MatchId then
		local o = f.Opponent
		if o and o.MatchId == f.MatchId and o.Alive then
			return { o }
		end
		return {}
	end
	if f.IsDummy then
		return {}
	end
	return State.dummies
end

return State
