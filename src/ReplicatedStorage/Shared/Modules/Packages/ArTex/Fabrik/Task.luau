

local Promise = require(script.Parent.Promise)

type TaskStatus = "pending" | "running" | "done" | "cancelled" | "failed"

type TaskHandle = {
	_promise:  any,
	_status:   TaskStatus,
	next:      (self: TaskHandle, cb: (...any) -> ()) -> TaskHandle,
	catch:     (self: TaskHandle, cb: (any) -> ()) -> TaskHandle,
	conclude:  (self: TaskHandle, cb: () -> ()) -> TaskHandle,
	await:     (self: TaskHandle) -> (boolean, ...any),
	status:    (self: TaskHandle) -> TaskStatus,
}

local HandleMeta = {}
HandleMeta.__index = HandleMeta

local function newHandle(promise: any): TaskHandle
	local self = {
		_promise = promise,
		_status  = "pending" :: TaskStatus,
	}
	return setmetatable(self :: any, HandleMeta)
end

function HandleMeta:next(cb: (...any) -> ()): TaskHandle
	self._promise = self._promise:next(cb)
	return self
end

function HandleMeta:catch(cb: (any) -> ()): TaskHandle
	self._promise = self._promise:catch(cb)
	return self
end

function HandleMeta:conclude(cb: () -> ()): TaskHandle
	self._promise = self._promise:conclude(cb)
	return self
end

function HandleMeta:await(): (boolean, any)
	return self._promise:await()
end

function HandleMeta:status(): TaskStatus
	return self._status
end

-- --

local registry: { [string]: (...any) -> any } = {}
local errorHandler: ((any, string) -> ())?

local Task = {}

function Task.define(name: string, fn: (...any) -> any)
	assert(not registry[name], "[Fabrik.task] already defined: " .. name)
	registry[name] = fn
end

local function dispatch(name: string, ...: any): TaskHandle
	local fn = registry[name]
	assert(fn, "[Fabrik.task] not defined: " .. name)
	local args = { ... }
	local handle = newHandle(Promise.new(function(resolve, reject)
		local ok, result = pcall(fn, table.unpack(args))
		if ok then
			resolve(result)
		else
			if errorHandler then
				errorHandler(result, name)
			end
			reject(result)
		end
	end))
	return handle
end

function Task.run(name: string, ...: any): TaskHandle
	return dispatch(name, ...)
end

function Task.defer(name: string, ...: any): TaskHandle
	local args   = { ... }
	local handle: TaskHandle
	local p = Promise.new(function(resolve, reject)
		task.defer(function()
			local fn = registry[name]
			assert(fn, "[Fabrik.task] not defined: " .. name)
			local ok, result = pcall(fn, table.unpack(args))
			if ok then resolve(result) else reject(result) end
		end)
	end)
	handle = newHandle(p)
	return handle
end

function Task.spawn(name: string, ...: any): TaskHandle
	local args = { ... }
	local p = Promise.new(function(resolve, reject)
		task.spawn(function()
			local fn = registry[name]
			assert(fn, "[Fabrik.task] not defined: " .. name)
			local ok, result = pcall(fn, table.unpack(args))
			if ok then resolve(result) else reject(result) end
		end)
	end)
	return newHandle(p)
end

function Task.pool(limit: number, handles: { TaskHandle }): any
	local promises = {}
	for i, h in handles do
		promises[i] = h._promise
	end

	local index     = 0
	local done      = 0
	local results   = {}
	local total     = #promises

	return Promise.new(function(resolve, reject)
		if total == 0 then resolve(results) return end

		local function next()
			if index >= total then return end
			index += 1
			local i = index
			promises[i]:next(function(v)
				results[i] = v
				done += 1
				if done == total then
					resolve(results)
				else
					next()
				end
			end):catch(reject)
		end

		for _ = 1, math.min(limit, total) do
			next()
		end
	end)
end

function Task.chain(...: string): any
	local names = { ... }
	return Promise.new(function(resolve, reject)
		local function step(i: number, prev: any)
			if i > #names then resolve(prev) return end
			dispatch(names[i], prev):next(function(v)
				step(i + 1, v)
			end):catch(reject)
		end
		step(1, nil)
	end)
end

function Task.batch(handles: { TaskHandle }): any
	local promises = {}
	for i, h in handles do
		promises[i] = h._promise
	end
	return Promise.all(promises)
end

function Task.schedule(name: string, interval: number): { cancel: () -> () }
	local running = true
	local t = task.spawn(function()
		while running do
			task.wait(interval)
			if not running then break end
			local fn = registry[name]
			if fn then
				local ok, err = pcall(fn)
				if not ok and errorHandler then
					errorHandler(err, name)
				end
			end
		end
	end)
	return {
		cancel = function()
			running = false
			task.cancel(t)
		end,
	}
end

function Task.cancel(handle: TaskHandle)
	handle._promise:cancel()
	handle._status = "cancelled"
end

function Task.status(handle: TaskHandle): TaskStatus
	return handle:status()
end

function Task.onError(fn: (any, string) -> ())
	errorHandler = fn
end

return Task