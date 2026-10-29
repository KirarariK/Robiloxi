--!strict
-- Duels 1v1 : préparation (lames, spawns, gel), intro, rounds, exécution finale, fin de duel, abandons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("EtherBlades")
local Maid = require(Shared.Util.Maid)
local Config = require(Shared.Combat.CombatConfig)
local State = require(script.Parent.State)
local Fighter = require(script.Parent.Fighter)
local Broadcast = require(script.Parent.Broadcast)
local Validation = require(script.Parent.Validation)

type Fighter = State.Fighter
type Duel = State.Duel

local A = Config.Attr

local Duels = {}

local roundEnded = Instance.new("BindableEvent")
Duels.RoundEnded = roundEnded.Event -- (matchId: string, winner: Player, loser: Player)

-- Fournie par CombatService : relit l'équipement du profil.
local loadoutFn: (Fighter) -> () = function(_f: Fighter) end

function Duels.setLoadoutProvider(fn: (Fighter) -> ())
	loadoutFn = fn
end

local function findPart(arena: Model, name: string): BasePart?
	local p = arena:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

-- Position debout au-dessus d'une Part de spawn, orientée comme elle.
local function standOn(spawnCf: CFrame, spawnHeight: number, f: Fighter): CFrame
	local h = if f.Humanoid.RigType == Enum.HumanoidRigType.R6 then 3 else f.Humanoid.HipHeight + f.Root.Size.Y * 0.5
	return CFrame.new(spawnCf.Position + Vector3.new(0, spawnHeight * 0.5 + h, 0)) * spawnCf.Rotation
end

local function fighterOf(p: Player): Fighter?
	return State.byPlayer[p]
end

local function waitFighter(p: Player, timeout: number): Fighter?
	local deadline = os.clock() + timeout
	local f = fighterOf(p)
	while f == nil and p.Parent and os.clock() < deadline do
		task.wait(0.1)
		f = fighterOf(p)
	end
	return f
end

local function spawnHeight(arena: Model, name: string): number
	local part = findPart(arena, name)
	return if part then part.Size.Y else 0
end

local function placeAtSpawn(d: Duel, f: Fighter, isA: boolean)
	local cf = if isA then d.SpawnA else d.SpawnB
	local target = standOn(cf, spawnHeight(d.Arena, if isA then "SpawnA" else "SpawnB"), f)
	Validation.allowMovement(f.Player, 2)
	Validation.teleport(f, target)
end

local function linkOpponents(d: Duel)
	local fa, fb = fighterOf(d.A), fighterOf(d.B)
	if fa then
		fa.Opponent = fb
	end
	if fb then
		fb.Opponent = fa
	end
end

-- Prépare un combattant pour le duel (aussi appelé si son personnage réapparaît pendant le duel).
local function prepare(d: Duel, f: Fighter, isA: boolean)
	f.MatchId = d.Id
	f.Model:SetAttribute(A.InDuel, true)
	loadoutFn(f)
	Fighter.resetVitals(f)
	Fighter.setSaber(f, false)
	Fighter.setFrozen(f, true)
	placeAtSpawn(d, f, isA)
	linkOpponents(d)
end

function Duels.get(matchId: string): Duel?
	return State.duels[matchId]
end

function Duels.begin(matchId: string, a: Player, b: Player, arena: Model)
	assert(State.duels[matchId] == nil, "Duel déjà commencé : " .. matchId)
	local sa = findPart(arena, "SpawnA")
	local sb = findPart(arena, "SpawnB")
	local pivot = arena:GetPivot()
	local spawnA = if sa then sa.CFrame else pivot * CFrame.new(0, 0, 12) * CFrame.Angles(0, 0, 0)
	local spawnB = if sb then sb.CFrame else pivot * CFrame.new(0, 0, -12) * CFrame.Angles(0, math.pi, 0)
	if not sa then
		spawnA = CFrame.lookAt(spawnA.Position, spawnB.Position)
	end
	if not sb then
		spawnB = CFrame.lookAt(spawnB.Position, spawnA.Position)
	end
	local camPart = findPart(arena, "IntroCam")
	local mid = (spawnA.Position + spawnB.Position) * 0.5
	local side = (spawnB.Position - spawnA.Position):Cross(Vector3.yAxis)
	local fallbackCam = CFrame.lookAt(mid + (if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis) * 14 + Vector3.new(0, 5, 0), mid + Vector3.new(0, 2, 0))
	local killPart = findPart(arena, "KillY")
	local d: Duel = {
		Id = matchId,
		A = a,
		B = b,
		Arena = arena,
		SpawnA = spawnA,
		SpawnB = spawnB,
		IntroCam = if camPart then camPart.CFrame else fallbackCam,
		KillY = if killPart then killPart.Position.Y else nil,
		Active = false,
		RoundOver = false,
		Maid = Maid.new(),
	}
	State.duels[matchId] = d
	State.playerDuel[a] = matchId
	State.playerDuel[b] = matchId
	for i, p in { a, b } do
		local f = waitFighter(p, 6)
		if f and State.duels[matchId] == d then
			prepare(d, f, i == 1)
		end
	end
end

function Duels.playIntro(matchId: string)
	local d = State.duels[matchId]
	if not d then
		return
	end
	local fa, fb = fighterOf(d.A), fighterOf(d.B)
	if not fa or not fb then
		return
	end
	-- envoyé à tous : chacun voit l'animation, seuls les deux duellistes prennent la caméra
	Broadcast.cinematic(Players:GetPlayers(), "Intro", {
		MatchId = matchId,
		A = fa.Model,
		B = fb.Model,
		IntroCam = d.IntroCam,
		Duration = Config.Intro.Duration,
		IgniteAt = Config.Intro.IgniteAt,
	})
	task.wait(Config.Intro.IgniteAt)
	if State.duels[matchId] ~= d then
		return
	end
	for _, p in { d.A, d.B } do
		local f = fighterOf(p)
		if f then
			Fighter.setSaber(f, true)
		end
	end
	task.wait(Config.Intro.Duration - Config.Intro.IgniteAt)
end

function Duels.startRound(matchId: string)
	local d = State.duels[matchId]
	if not d then
		return
	end
	for i, p in { d.A, d.B } do
		local f = fighterOf(p)
		if f then
			f.MatchId = matchId
			f.Model:SetAttribute(A.InDuel, true)
			Fighter.resetVitals(f)
			Fighter.setFrozen(f, true)
			placeAtSpawn(d, f, i == 1)
			Fighter.setSaber(f, true)
		end
	end
	linkOpponents(d)
	d.RoundOver = false
	d.Active = true
	for _, p in { d.A, d.B } do
		local f = fighterOf(p)
		if f then
			Fighter.setFrozen(f, false)
			Fighter.setState(f, "Idle")
		end
	end
end

-- Fin de round (PV à zéro, chute mortelle, réinitialisation du personnage, départ).
function Duels.endRound(d: Duel, loser: Player)
	if d.RoundOver then
		return
	end
	d.RoundOver = true
	d.Active = false
	local winner = if loser == d.A then d.B else d.A
	for _, p in { d.A, d.B } do
		local f = fighterOf(p)
		if f then
			Fighter.cancelPending(f)
			f.BlockHeld = false
			if p == loser then
				f.Alive = false
				Fighter.setState(f, "Dead")
			elseif f.State ~= "Dead" then
				Fighter.setState(f, "Idle")
			end
			Fighter.writeAttributes(f)
		end
	end
	local lf = fighterOf(loser)
	if lf then
		Broadcast.fx("KO", { Target = lf.Model, Position = lf.Root.Position, MatchId = d.Id })
	end
	roundEnded:Fire(d.Id, winner, loser)
end

function Duels.onDefeated(f: Fighter)
	local d = State.duelOf(f)
	local p = f.Player
	if d and p and not d.RoundOver then
		Duels.endRound(d, p)
	end
end

function Duels.playFinisher(matchId: string, winner: Player, loser: Player)
	local d = State.duels[matchId]
	if not d then
		return
	end
	local fw, fl = fighterOf(winner), fighterOf(loser)
	if not fw or not fl then
		return
	end
	d.Active = false
	d.RoundOver = true
	Fighter.setFrozen(fw, true)
	Fighter.setFrozen(fl, true)
	Fighter.setSaber(fw, true)
	Fighter.setState(fw, "Idle")
	Fighter.setState(fl, "Idle")
	-- le perdant face au vainqueur, à distance d'exécution
	local wcf = fw.Root.CFrame
	local look = Vector3.new(wcf.LookVector.X, 0, wcf.LookVector.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local lpos = Vector3.new(wcf.Position.X, fl.Root.Position.Y, wcf.Position.Z) + look * Config.Finisher.Distance
	Validation.teleport(fl, CFrame.lookAt(lpos, Vector3.new(wcf.Position.X, lpos.Y, wcf.Position.Z)))
	Broadcast.cinematic(Players:GetPlayers(), "Finisher", {
		MatchId = matchId,
		Winner = fw.Model,
		Loser = fl.Model,
		Duration = Config.Finisher.Duration,
		StrikeAt = Config.Finisher.StrikeAt,
	})
	task.wait(Config.Finisher.StrikeAt)
	if State.duels[matchId] ~= d then
		return
	end
	Fighter.setSaber(fl, false)
	task.wait(Config.Finisher.Duration - Config.Finisher.StrikeAt)
end

function Duels.endDuel(matchId: string)
	local d = State.duels[matchId]
	if not d then
		return
	end
	State.duels[matchId] = nil
	d.Active = false
	d.RoundOver = true
	for _, p in { d.A, d.B } do
		if State.playerDuel[p] == matchId then
			State.playerDuel[p] = nil
		end
		local f = fighterOf(p)
		if f and f.MatchId == matchId then
			f.MatchId = nil
			f.Opponent = nil
			f.Model:SetAttribute(A.InDuel, false)
			Fighter.resetVitals(f)
			Fighter.setFrozen(f, false)
			Fighter.setSaber(f, false)
		end
	end
	d.Maid:Clean()
end

-- Départ d'un joueur : RoundEnded immédiat en faveur de l'autre (l'équipe Match gère la pénalité).
function Duels.onPlayerLeaving(p: Player)
	local id = State.playerDuel[p]
	local d = if id then State.duels[id] else nil
	if not d then
		return
	end
	if d.RoundOver then
		-- entre deux rounds : on signale tout de même l'abandon
		local winner = if p == d.A then d.B else d.A
		roundEnded:Fire(d.Id, winner, p)
	else
		Duels.endRound(d, p)
	end
	local other = if p == d.A then d.B else d.A
	local of = fighterOf(other)
	if of then
		of.Opponent = nil
	end
end

-- Personnage (re)lié pendant un duel.
function Duels.onCharacterBound(f: Fighter)
	local p = f.Player
	if not p then
		return
	end
	local id = State.playerDuel[p]
	local d = if id then State.duels[id] else nil
	if d then
		prepare(d, f, p == d.A)
		if d.Active and not d.RoundOver then
			Fighter.setSaber(f, true)
			Fighter.setFrozen(f, false)
		end
	end
end

-- Chute mortelle (KillY de l'arène) pendant un round.
function Duels.tick()
	for _, d in State.duels do
		local ky = d.KillY
		if ky and d.Active and not d.RoundOver then
			for _, p in { d.A, d.B } do
				local f = fighterOf(p)
				if f and f.Alive and f.Root.Position.Y < ky then
					f.Health = 0
					Duels.endRound(d, p)
					break
				end
			end
		end
	end
end

return Duels
