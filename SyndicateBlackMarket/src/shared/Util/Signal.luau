--!strict
--[[
	Signal.luau
	Événements personnalisés rapides. Les gestionnaires sont exécutés dans un thread
	« runner » réutilisé tant qu'aucun gestionnaire ne cède (yield), ce qui évite de
	créer une coroutine par appel. La liste chaînée permet de se déconnecter pendant
	un Fire sans perturber l'itération.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type Handler = (...any) -> ()

type ConnectionImpl = {
	Connected: boolean,
	_signal: SignalImpl,
	_handler: Handler,
	_next: ConnectionImpl?,
}

type SignalImpl = {
	_head: ConnectionImpl?,
}

local freeRunnerThread: thread? = nil

local function acquireRunnerAndCall(handler: Handler, ...: any)
	local acquired = freeRunnerThread
	freeRunnerThread = nil
	handler(...)
	freeRunnerThread = acquired
end

local function runnerLoop(...: any)
	acquireRunnerAndCall(...)
	while true do
		acquireRunnerAndCall(coroutine.yield())
	end
end

local ConnectionMethods = {}
ConnectionMethods.__index = ConnectionMethods

function ConnectionMethods.Disconnect(self: ConnectionImpl)
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	if signal._head == self then
		signal._head = self._next
	else
		local previous = signal._head
		while previous ~= nil and previous._next ~= self do
			previous = previous._next
		end
		if previous ~= nil then
			previous._next = self._next
		end
	end
end

local SignalMethods = {}
SignalMethods.__index = SignalMethods

function SignalMethods.Connect(self: SignalImpl, handler: Handler): ConnectionImpl
	local connection: ConnectionImpl = setmetatable({
		Connected = true,
		_signal = self,
		_handler = handler,
		_next = self._head,
	}, ConnectionMethods) :: any
	self._head = connection
	return connection
end

function SignalMethods.Once(self: SignalImpl, handler: Handler): ConnectionImpl
	local connection: ConnectionImpl? = nil
	connection = SignalMethods.Connect(self, function(...: any)
		if connection ~= nil and connection.Connected then
			ConnectionMethods.Disconnect(connection)
		end
		handler(...)
	end)
	return connection :: ConnectionImpl
end

function SignalMethods.Wait(self: SignalImpl): ...any
	local waitingThread = coroutine.running()
	SignalMethods.Once(self, function(...: any)
		task.spawn(waitingThread, ...)
	end)
	return coroutine.yield()
end

function SignalMethods.Fire(self: SignalImpl, ...: any)
	local node = self._head
	while node ~= nil do
		if node.Connected then
			if freeRunnerThread == nil then
				local runner = coroutine.create(runnerLoop)
				freeRunnerThread = runner
				task.spawn(runner, node._handler, ...)
			else
				task.spawn(freeRunnerThread :: thread, node._handler, ...)
			end
		end
		node = node._next
	end
end

function SignalMethods.DisconnectAll(self: SignalImpl)
	local node = self._head
	while node ~= nil do
		node.Connected = false
		node = node._next
	end
	self._head = nil
end

function SignalMethods.Destroy(self: SignalImpl)
	SignalMethods.DisconnectAll(self)
end

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local impl: SignalImpl = { _head = nil }
	return setmetatable(impl, SignalMethods) :: any
end

function Signal.is(value: unknown): boolean
	return typeof(value) == "table" and getmetatable(value :: any) == SignalMethods
end

return table.freeze(Signal)
