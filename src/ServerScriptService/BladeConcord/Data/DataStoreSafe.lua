--!strict
--[[
	DataStore patterns sûrs + mock local Studio (sans secrets).
	Session lock soft, retries exponentiels, jamais de clé API sur argv.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataStoreSafe = {}

local USE_MOCK = RunService:IsStudio()
local mockStore: { [string]: { [string]: any } } = {}
local sessionLocks: { [string]: number } = {} -- key → os.clock lock

local MAX_RETRIES = 4
local BASE_DELAY = 0.4

local function sleep(sec: number)
	task.wait(sec)
end

local function withRetries(label: string, fn: () -> any): (boolean, any)
	local lastErr = nil
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(string.format("[DataStoreSafe] %s attempt %d failed: %s", label, attempt, tostring(result)))
		sleep(BASE_DELAY * (2 ^ (attempt - 1)))
	end
	return false, lastErr
end

function DataStoreSafe.isMock(): boolean
	return USE_MOCK
end

function DataStoreSafe.getStore(name: string): any
	if USE_MOCK then
		if not mockStore[name] then
			mockStore[name] = {}
		end
		return {
			_name = name,
			GetAsync = function(_, key: string)
				return mockStore[name][key]
			end,
			SetAsync = function(_, key: string, value: any)
				mockStore[name][key] = value
			end,
			UpdateAsync = function(_, key: string, transform: (any) -> any)
				local current = mockStore[name][key]
				local nextValue = transform(current)
				mockStore[name][key] = nextValue
				return nextValue
			end,
		}
	end
	return DataStoreService:GetDataStore(name)
end

function DataStoreSafe.tryLock(key: string): boolean
	local now = os.clock()
	local existing = sessionLocks[key]
	if existing and now - existing < 30 then
		return false
	end
	sessionLocks[key] = now
	return true
end

function DataStoreSafe.unlock(key: string)
	sessionLocks[key] = nil
end

function DataStoreSafe.load(storeName: string, key: string, defaultValue: any): any
	local store = DataStoreSafe.getStore(storeName)
	local ok, data = withRetries("load:" .. storeName, function()
		return store:GetAsync(key)
	end)
	if not ok then
		return defaultValue
	end
	if data == nil then
		return defaultValue
	end
	return data
end

function DataStoreSafe.save(storeName: string, key: string, value: any): boolean
	local store = DataStoreSafe.getStore(storeName)
	local ok = withRetries("save:" .. storeName, function()
		store:SetAsync(key, value)
		return true
	end)
	return ok
end

function DataStoreSafe.update(storeName: string, key: string, transform: (any) -> any): (boolean, any)
	local store = DataStoreSafe.getStore(storeName)
	return withRetries("update:" .. storeName, function()
		return store:UpdateAsync(key, transform)
	end)
end

return DataStoreSafe
