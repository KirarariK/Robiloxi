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

local function cleanup(task: Task)
	if typeof(task) == "RBXScriptConnection" then
		task:Disconnect()
	elseif typeof(task) == "Instance" then
		task:Destroy()
	elseif type(task) == "thread" then
		if coroutine.status(task) ~= "dead" then
			pcall(task.cancel, task)
		end
	elseif type(task) == "function" then
		task()
	elseif type(task) == "table" and type(task.Destroy) == "function" then
		task:Destroy()
	end
end

local Maid = {}
Maid.__index = Maid

function Maid.new(): Maid
	local self = setmetatable({ _tasks = {}, _named = {} }, Maid)
	return (self :: any) :: Maid
end

function Maid.Give(self: MaidImpl, task: Task): Task
	table.insert(self._tasks, task)
	return task
end

-- Remplace (et nettoie) la tâche nommée précédente.
function Maid.Set(self: MaidImpl, key: string, task: Task?)
	local old = self._named[key]
	if old ~= nil and old ~= task then
		cleanup(old)
	end
	self._named[key] = task :: any
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
