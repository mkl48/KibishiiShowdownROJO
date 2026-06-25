

local Promise = {}
Promise.__index = Promise

type PromiseStatus = "pending" | "resolved" | "rejected" | "cancelled"

type PromiseInternal = {
	_status:    PromiseStatus,
	_value:     any,
	_callbacks: { { tag: string, fn: (...any) -> any } },
	_thread:    thread?,
}

local function new(executor: ((any) -> (), (any) -> ()) -> ()): any
	local self: PromiseInternal = {
		_status    = "pending",
		_value     = nil,
		_callbacks = {},
		_thread    = nil,
	}
	setmetatable(self :: any, Promise)

	local function resolve(value: any)
		if self._status ~= "pending" then return end
		self._status = "resolved"
		self._value  = value
		for _, cb in self._callbacks do
			if cb.tag == "next" or cb.tag == "conclude" then
				task.spawn(cb.fn, value)
			end
		end
	end

	local function reject(err: any)
		if self._status ~= "pending" then return end
		self._status = "rejected"
		self._value  = err
		local caught = false
		for _, cb in self._callbacks do
			if cb.tag == "catch" then
				caught = true
				task.spawn(cb.fn, err)
			elseif cb.tag == "conclude" then
				task.spawn(cb.fn)
			end
		end
		if not caught then
			task.spawn(function()
				warn("[Fabrik.promise] unhandled rejection:", err)
			end)
		end
	end

	self._thread = task.spawn(function()
		local ok, err = pcall(executor, resolve, reject)
		if not ok then
			reject(err)
		end
	end)

	return self
end

function Promise:next(cb: (...any) -> any): any
	if self._status == "resolved" then
		return new(function(resolve, reject)
			local ok, result = pcall(cb, self._value)
			if ok then resolve(result) else reject(result) end
		end)
	elseif self._status == "pending" then
		local child
		local p = new(function(resolve, reject)
			table.insert(self._callbacks, { tag = "next", fn = function(value)
				if child and child._status ~= "pending" then return end
				local ok, result = pcall(cb, value)
				if ok then resolve(result) else reject(result) end
			end })
			table.insert(self._callbacks, { tag = "catch", fn = function(err)
				if child and child._status ~= "pending" then return end
				reject(err)
			end })
		end)
		child = p
		return p
	end
	return self
end

function Promise:catch(cb: (any) -> ()): any
	if self._status == "rejected" then
		task.spawn(cb, self._value)
		return self
	elseif self._status == "pending" then
		table.insert(self._callbacks, { tag = "catch", fn = cb })
	end
	return self
end

function Promise:conclude(cb: () -> ()): any
	if self._status ~= "pending" then
		task.spawn(cb)
	else
		table.insert(self._callbacks, { tag = "conclude", fn = cb })
	end
	return self
end

function Promise:cancel()
	if self._status ~= "pending" then return end
	self._status = "cancelled"
	if self._thread then
		task.cancel(self._thread)
	end
end

function Promise:await(): (boolean, any)
	if self._status == "resolved" then return true, self._value end
	if self._status == "rejected" then return false, self._value end
	if self._status == "cancelled" then return false, "cancelled" end

	local thread = coroutine.running()
	self:next(function(v)
		task.spawn(thread, true, v)
	end):catch(function(e)
		task.spawn(thread, false, e)
	end)
	return coroutine.yield()
end

function Promise:status(): PromiseStatus
	return self._status
end

-- --

local Static = {}

Static.new = new

function Static.resolve(value: any): any
	return new(function(resolve) resolve(value) end)
end

function Static.reject(err: any): any
	return new(function(_, reject) reject(err) end)
end

function Static.delay(seconds: number): any
	return new(function(resolve)
		task.delay(seconds, resolve)
	end)
end

function Static.all(promises: { any }): any
	return new(function(resolve, reject)
		local results  = {}
		local count    = 0
		local total    = #promises
		if total == 0 then resolve(results) return end
		for i, p in promises do
			p:next(function(v)
				results[i] = v
				count += 1
				if count == total then resolve(results) end
			end):catch(reject)
		end
	end)
end

function Static.any(promises: { any }): any
	return new(function(resolve, reject)
		local errors = {}
		local count  = 0
		local total  = #promises
		for i, p in promises do
			p:next(resolve):catch(function(e)
				errors[i] = e
				count += 1
				if count == total then reject(errors) end
			end)
		end
	end)
end

function Static.race(promises: { any }): any
	return new(function(resolve, reject)
		local settled = false
		for _, p in promises do
			p:next(function(v)
				if settled then return end
				settled = true
				resolve(v)
			end):catch(function(e)
				if settled then return end
				settled = true
				reject(e)
			end)
		end
	end)
end

function Static.allSettled(promises: { any }): any
	return new(function(resolve)
		local results = {}
		local count   = 0
		local total   = #promises
		if total == 0 then resolve(results) return end
		for i, p in promises do
			p:next(function(v)
				results[i] = { status = "resolved", value = v }
				count += 1
				if count == total then resolve(results) end
			end):catch(function(e)
				results[i] = { status = "rejected", value = e }
				count += 1
				if count == total then resolve(results) end
			end)
		end
	end)
end

function Static.retry(fn: () -> any, times: number, backoff: number?): any
	return new(function(resolve, reject)
		local attempt = 0
		local function try()
			attempt += 1
			local p = fn()
			p:next(resolve):catch(function(err)
				if attempt >= times then
					reject(err)
				else
					local wait = backoff and (backoff ^ (attempt - 1)) or 0
					task.delay(wait, try)
				end
			end)
		end
		try()
	end)
end

function Static.timeout(promise: any, seconds: number): any
	return Static.race({
		promise,
		new(function(_, reject)
			task.delay(seconds, function()
				reject("timeout after " .. seconds .. "s")
			end)
		end),
	})
end

function Static.fromSignal(signal: any): any
	return new(function(resolve)
		local disconnect: (() -> ())?
		disconnect = signal:connect(function(...)
			if disconnect then disconnect() end
			resolve(...)
		end)
	end)
end

function Static.fromEvent(signal: any, predicate: ((...any) -> boolean)?): any
	return new(function(resolve)
		local disconnect: (() -> ())?
		disconnect = signal:connect(function(...)
			if predicate and not predicate(...) then return end
			if disconnect then disconnect() end
			resolve(...)
		end)
	end)
end

function Static.each(list: { any }, fn: (any) -> any, concurrency: number?): any
	local cap     = concurrency or #list
	local results = {}
	local index   = 0
	local done    = 0
	local total   = #list

	return new(function(resolve, reject)
		if total == 0 then resolve(results) return end

		local function next()
			if index >= total then return end
			index += 1
			local i = index
			fn(list[i]):next(function(v)
				results[i] = v
				done += 1
				if done == total then
					resolve(results)
				else
					next()
				end
			end):catch(reject)
		end

		for _ = 1, math.min(cap, total) do
			next()
		end
	end)
end

return Static