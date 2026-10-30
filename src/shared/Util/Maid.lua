--!strict
-- Maid : regroupe connexions, instances et fonctions de nettoyage, et les libère d'un coup.
-- Utilisé entre les rounds et à la sortie d'un joueur pour éviter toute fuite mémoire.

export type Task = RBXScriptConnection | Instance | thread | () -> () | { Destroy: (any) -> () }

export type Maid = {
	Give: (self: Maid, task: Task) -> Task,
	Set: (self: Maid, key: string, task: Task?) -> (),
	Clean: (self: Maid) -> (),
	Destroy: (self: Maid) -> (),
}

type MaidImpl = Maid & {
	_tasks: { Task },
	_named: { [string]: Task },
}

-- Paramètre nommé `job` (pas `task`) pour ne pas masquer la librairie globale `task`.
local function cleanup(job: Task)
	if typeof(job) == "RBXScriptConnection" then
		job:Disconnect()
	elseif typeof(job) == "Instance" then
		job:Destroy()
	elseif type(job) == "thread" then
		if coroutine.status(job) ~= "dead" then
			pcall(task.cancel, job)
		end
	elseif type(job) == "function" then
		job()
	elseif type(job) == "table" and type((job :: any).Destroy) == "function" then
		(job :: any):Destroy()
	end
end

local Maid = {}
Maid.__index = Maid

function Maid.new(): Maid
	local self = setmetatable({ _tasks = {}, _named = {} }, Maid)
	return (self :: any) :: Maid
end

function Maid.Give(self: MaidImpl, job: Task): Task
	table.insert(self._tasks, job)
	return job
end

-- Remplace (et nettoie) la tâche nommée précédente.
function Maid.Set(self: MaidImpl, key: string, job: Task?)
	local old = self._named[key]
	if old ~= nil and old ~= job then
		cleanup(old)
	end
	self._named[key] = job :: any
end

function Maid.Clean(self: MaidImpl)
	local named = self._named
	self._named = {}
	for _, t in named do
		cleanup(t)
	end
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		cleanup(tasks[i])
	end
end

Maid.Destroy = Maid.Clean

return Maid
