--!strict
--[[
	Trove.luau
	Gestionnaire de nettoyage mémoire. Tout ce qui est ajouté (Instances, connexions,
	threads, fonctions, objets possédant Destroy/Disconnect/Clean) est libéré par
	:Clean() ou :Destroy(), dans l'ordre inverse d'ajout.
]]

type CleanupKind = "Instance" | "Connection" | "Function" | "Thread" | "Method"

type Entry = {
	Object: any,
	Kind: CleanupKind,
	Method: string?,
}

type TroveData = {
	_entries: { Entry },
	_cleaning: boolean,
	_destroyed: boolean,
}

local TroveMethods = {}
TroveMethods.__index = TroveMethods

export type Trove = typeof(setmetatable({} :: TroveData, TroveMethods))

local OBJECT_METHODS: { string } = { "Destroy", "Disconnect", "Clean", "destroy", "disconnect" }

local function classify(object: any, explicitMethod: string?): (CleanupKind, string?)
	if explicitMethod ~= nil then
		return "Method", explicitMethod
	end
	local objectType = typeof(object)
	if objectType == "Instance" then
		return "Instance", nil
	elseif objectType == "RBXScriptConnection" then
		return "Connection", nil
	elseif objectType == "function" then
		return "Function", nil
	elseif objectType == "thread" then
		return "Thread", nil
	elseif objectType == "table" then
		for _, methodName in OBJECT_METHODS do
			if typeof(object[methodName]) == "function" then
				return "Method", methodName
			end
		end
	end
	error(`Trove : impossible de déterminer comment nettoyer un objet de type {objectType}`, 3)
end

local function cleanEntry(entry: Entry)
	local object = entry.Object
	local kind = entry.Kind
	if kind == "Instance" then
		object:Destroy()
	elseif kind == "Connection" then
		object:Disconnect()
	elseif kind == "Function" then
		object()
	elseif kind == "Thread" then
		local thread: thread = object
		if coroutine.running() ~= thread and coroutine.status(thread) ~= "dead" then
			local cancelled = pcall(task.cancel, thread)
			if not cancelled then
				pcall(coroutine.close, thread)
			end
		end
	elseif kind == "Method" then
		local methodName = entry.Method :: string
		object[methodName](object)
	end
end

local Trove = {}

function Trove.new(): Trove
	local data: TroveData = {
		_entries = {},
		_cleaning = false,
		_destroyed = false,
	}
	return setmetatable(data, TroveMethods)
end

function TroveMethods.Add<T>(self: Trove, object: T, cleanupMethod: string?): T
	if self._cleaning then
		error("Trove : impossible d'ajouter un objet pendant le nettoyage", 2)
	end
	local kind, method = classify(object, cleanupMethod)
	table.insert(self._entries, {
		Object = object,
		Kind = kind,
		Method = method,
	})
	return object
end

function TroveMethods.Connect(self: Trove, signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(handler)
	self:Add(connection)
	return connection
end

function TroveMethods.Once(self: Trove, signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
	local connection = signal:Once(handler)
	self:Add(connection)
	return connection
end

function TroveMethods.Spawn(self: Trove, fn: (...any) -> (), ...: any): thread
	local thread = task.spawn(fn, ...)
	self:Add(thread)
	return thread
end

function TroveMethods.Delay(self: Trove, seconds: number, fn: (...any) -> (), ...: any): thread
	local thread = task.delay(seconds, fn, ...)
	self:Add(thread)
	return thread
end

function TroveMethods.Clone<T>(self: Trove, instance: T): T
	if typeof(instance) ~= "Instance" then
		error("Trove:Clone attend une Instance", 2)
	end
	local clone: Instance = (instance :: any):Clone()
	self:Add(clone)
	return clone :: any
end

function TroveMethods.Create<T>(self: Trove, className: string, properties: { [string]: any }?): T
	local instance: Instance = Instance.new(className :: any)
	if properties ~= nil then
		local parent: Instance? = nil
		for key, value in properties do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
		if parent ~= nil then
			instance.Parent = parent
		end
	end
	self:Add(instance)
	return instance :: any
end

function TroveMethods.BindToRenderStep(self: Trove, name: string, priority: number, fn: (deltaTime: number) -> ())
	local RunService = game:GetService("RunService")
	RunService:BindToRenderStep(name, priority, fn)
	self:Add(function()
		RunService:UnbindFromRenderStep(name)
	end)
end

function TroveMethods.Extend(self: Trove): Trove
	local child = Trove.new()
	self:Add(child, "Destroy")
	return child
end

-- Nettoie automatiquement la Trove quand l'instance est détruite.
function TroveMethods.AttachToInstance(self: Trove, instance: Instance): RBXScriptConnection
	return self:Connect(instance.Destroying, function()
		self:Destroy()
	end)
end

-- Retire un objet et le nettoie immédiatement. Retourne true s'il était suivi.
function TroveMethods.Remove(self: Trove, object: any): boolean
	local entries = self._entries
	for index = #entries, 1, -1 do
		local entry = entries[index]
		if entry.Object == object then
			table.remove(entries, index)
			cleanEntry(entry)
			return true
		end
	end
	return false
end

-- Retire un objet sans le nettoyer (transfert de propriété).
function TroveMethods.Release(self: Trove, object: any): boolean
	local entries = self._entries
	for index = #entries, 1, -1 do
		if entries[index].Object == object then
			table.remove(entries, index)
			return true
		end
	end
	return false
end

function TroveMethods.Clean(self: Trove)
	if self._cleaning then
		return
	end
	self._cleaning = true
	local entries = self._entries
	while #entries > 0 do
		local entry = table.remove(entries) :: Entry
		local ok, err = pcall(cleanEntry, entry)
		if not ok then
			warn("Trove : erreur pendant le nettoyage :", err)
		end
	end
	self._cleaning = false
end

function TroveMethods.Destroy(self: Trove)
	self:Clean()
	self._destroyed = true
end

function TroveMethods.IsDestroyed(self: Trove): boolean
	return self._destroyed
end

return table.freeze(Trove)
