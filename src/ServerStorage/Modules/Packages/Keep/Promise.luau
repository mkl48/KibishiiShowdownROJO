local Promise = {}
Promise.__index = Promise

local STATUS = {
	Pending = "Pending",
	Resolved = "Resolved",
	Rejected = "Rejected",
}

function Promise.new(executor)
	local self = setmetatable({}, Promise)

	self._status = STATUS.Pending
	self._value = nil
	self._error = nil
	self._nextCallbacks = {}
	self._catchCallbacks = {}
	self._concludedCallbacks = {}

	local function resolve(...)
		if self._status ~= STATUS.Pending then return end
		self._status = STATUS.Resolved
		self._value = { ... }

		for _, cb in ipairs(self._nextCallbacks) do
			task.spawn(cb, table.unpack(self._value))
		end
		for _, cb in ipairs(self._concludedCallbacks) do
			task.spawn(cb)
		end
	end

	local function reject(err)
		if self._status ~= STATUS.Pending then return end
		self._status = STATUS.Rejected
		self._error = err

		if #self._catchCallbacks == 0 then
			warn("[Keep.Promise] Unhandled rejection:", err)
		end

		for _, cb in ipairs(self._catchCallbacks) do
			task.spawn(cb, err)
		end
		for _, cb in ipairs(self._concludedCallbacks) do
			task.spawn(cb)
		end
	end

	task.spawn(executor, resolve, reject)

	return self
end

function Promise:next(fn)
	if self._status == STATUS.Resolved then
		task.spawn(fn, table.unpack(self._value))
	elseif self._status == STATUS.Pending then
		table.insert(self._nextCallbacks, fn)
	end
	return self
end

function Promise:catch(fn)
	if self._status == STATUS.Rejected then
		task.spawn(fn, self._error)
	elseif self._status == STATUS.Pending then
		table.insert(self._catchCallbacks, fn)
	end
	return self
end

function Promise:concluded(fn)
	if self._status ~= STATUS.Pending then
		task.spawn(fn)
	else
		table.insert(self._concludedCallbacks, fn)
	end
	return self
end

function Promise.resolve(...)
	local args = { ... }
	return Promise.new(function(resolve)
		resolve(table.unpack(args))
	end)
end

function Promise.reject(err)
	return Promise.new(function(_, reject)
		reject(err)
	end)
end

function Promise.all(promises)
	return Promise.new(function(resolve, reject)
		local results = {}
		local remaining = #promises

		if remaining == 0 then
			resolve(results)
			return
		end

		for i, promise in ipairs(promises) do
			promise
				.next(function(...)
					results[i] = { ... }
					remaining -= 1
					if remaining == 0 then
						resolve(results)
					end
				end)
				.catch(function(err)
					reject(err)
				end)
		end
	end)
end

function Promise.any(promises)
	return Promise.new(function(resolve, reject)
		local errors = {}
		local remaining = #promises

		if remaining == 0 then
			reject("[Keep.Promise] Promise.any received empty list")
			return
		end

		for _, promise in ipairs(promises) do
			promise
				.next(function(...)
					resolve(...)
				end)
				.catch(function(err)
					table.insert(errors, err)
					remaining -= 1
					if remaining == 0 then
						reject(errors)
					end
				end)
		end
	end)
end

function Promise.delay(seconds)
	return Promise.new(function(resolve)
		task.delay(seconds, resolve)
	end)
end

function Promise.fromSignal(signal)
	return Promise.new(function(resolve)
		local conn
		conn = signal:Connect(function(...)
			conn:Disconnect()
			resolve(...)
		end)
	end)
end

function Promise.retry(fn, retries, interval)
	return Promise.new(function(resolve, reject)
		local attempts = 0

		local function attempt()
			attempts += 1
			fn()
				.next(function(...)
					resolve(...)
				end)
				.catch(function(err)
					if attempts >= retries then
						reject(err)
					else
						task.delay(interval or 1, attempt)
					end
				end)
		end

		attempt()
	end)
end

function Promise:await()
	if self._status == STATUS.Resolved then
		return true, table.unpack(self._value)
	elseif self._status == STATUS.Rejected then
		return false, self._error
	end

	local thread = coroutine.running()
	local result, err

	self
		.next(function(...)
			result = { ... }
			task.spawn(thread)
		end)
		.catch(function(e)
			err = e
			task.spawn(thread)
		end)

	coroutine.yield()

	if err then
		return false, err
	end
	return true, table.unpack(result)
end

function Promise:IsResolved()
	return self._status == STATUS.Resolved
end

function Promise:IsRejected()
	return self._status == STATUS.Rejected
end

function Promise:IsPending()
	return self._status == STATUS.Pending
end

function Promise:GetStatus()
	return self._status
end

return Promise