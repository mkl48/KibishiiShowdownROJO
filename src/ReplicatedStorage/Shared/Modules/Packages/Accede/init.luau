--!nonstrict
-- Accede
-- init.luau
-- Plinko Labs
--
-- An async-resolution library built for games -- "the new Promise". One value settles
-- once (resolve / reject / cancel); chains are typed and cancellable. Self-contained:
-- no Promise/Signal dependency, because Accede IS the async primitive everything else
-- (Moody, Mixit, Plinko, the Network layer) builds on.
--
-- The three things that make it nicer than a plain Promise:
--   * TYPED ERROR CHANNELS -- :toss("NetworkError", fn) handles only that tag; others
--     keep falling through until something catches them.
--   * STRUCTURED CANCELLATION -- a token cancels a whole chain at once; :link(inst)
--     cancels when a Roblox instance dies; :timeout(s) cancels on time.
--   * ONE TERMINAL -- :conclude(fn) always runs with a structured result, success or not.
--
--   Accede.wrap(fn)        -> a function returning an Accede (wraps a yielding call)
--   Accede.new(executor)   -> Accede        executor(resolve, reject, progress)
--   Accede.resolve(v) / Accede.reject(err, tag?)
--   a:next(fn) | a:next(tag, fn)            on success (optionally only a success tag)
--   a:toss(fn) | a:toss(tag, fn)           on failure (optionally only that error tag)
--   a:subscribe(fn)                         observe progress / settle
--   a:conclude(fn)                          terminal: fn({ status, value, error, tag })
--   a:timeout(s) | a:link(inst) | a:fallback(v) | a:await()
--   Accede.all / any / race / token

local Accede = {}
Accede.__index = Accede

local PENDING, RESOLVED, REJECTED, CANCELLED = "pending", "resolved", "rejected", "cancelled"

-- ===================================================================== tokens =====

local Token = {}
Token.__index = Token

function Accede.token()
	return setmetatable({ _cancelled = false, _listeners = {} }, Token)
end

function Token:cancel()
	if self._cancelled then
		return
	end
	self._cancelled = true
	for _, fn in self._listeners do
		task.spawn(fn)
	end
	table.clear(self._listeners)
end

function Token:isCancelled(): boolean
	return self._cancelled
end

function Token:onCancel(fn)
	if self._cancelled then
		task.spawn(fn)
	else
		table.insert(self._listeners, fn)
	end
end

-- ===================================================================== core ========

local function new(token)
	return setmetatable({
		_state = PENDING,
		_value = nil,
		_error = nil,
		_tag = nil,
		_queue = {}, -- { {onResolve, onReject} }
		_subs = {},
		_token = token,
	}, Accede)
end

function Accede:_settle(state, value, tag)
	if self._state ~= PENDING then
		return
	end
	self._state = state
	if state == RESOLVED then
		self._value = value
	else
		self._error = value
		self._tag = tag
	end
	for _, sub in self._subs do
		task.spawn(sub, { status = state, value = self._value, error = self._error, tag = self._tag })
	end
	for _, handlers in self._queue do
		self:_dispatch(handlers)
	end
	table.clear(self._queue)
end

function Accede:_dispatch(handlers)
	if self._state == RESOLVED then
		task.spawn(handlers.onResolve, self._value)
	elseif self._state == REJECTED then
		task.spawn(handlers.onReject, self._error, self._tag)
	end
	-- CANCELLED chains stop silently (no handlers run).
end

-- Register success/failure handlers, returning a new chained Accede.
function Accede:_then(onResolve, onReject)
	local child = new(self._token)

	local handlers = {
		onResolve = function(value)
			if onResolve then
				local ok, result, resultTag = pcall(onResolve, value)
				if not ok then
					child:_settle(REJECTED, result, "AccedeError")
				elseif getmetatable(result) == Accede then
					result:_forwardTo(child)
				else
					child:_settle(RESOLVED, result)
				end
			else
				child:_settle(RESOLVED, value)
			end
		end,
		onReject = function(err, tag)
			if onReject then
				local ok, result = pcall(onReject, err, tag)
				if not ok then
					child:_settle(REJECTED, result, "AccedeError")
				elseif getmetatable(result) == Accede then
					result:_forwardTo(child)
				else
					child:_settle(RESOLVED, result) -- handled = recovered
				end
			else
				child:_settle(REJECTED, err, tag) -- propagate untouched
			end
		end,
	}

	if self._state == PENDING then
		table.insert(self._queue, handlers)
	else
		self:_dispatch(handlers)
	end
	return child
end

function Accede:_forwardTo(child)
	self:_then(function(v)
		child:_settle(RESOLVED, v)
	end, function(e, tag)
		child:_settle(REJECTED, e, tag)
	end)
end

-- ===================================================================== thenable ====

-- :next(fn) runs on success, chaining fn's return (a plain value, or another Accede).
function Accede:next(fn)
	return self:_then(fn, nil)
end

-- :toss(fn) catches any error; :toss(tag, fn) catches ONLY that error tag and lets the
-- rest keep falling through to a later :toss. That's the typed-error-channel feature.
function Accede:toss(tagOrFn, maybeFn)
	local wantTag, handler
	if type(tagOrFn) == "string" then
		wantTag, handler = tagOrFn, maybeFn
	else
		handler = tagOrFn
	end

	local child = new(self._token)
	self:_then(function(value)
		child:_settle(RESOLVED, value)
	end, function(err, tag)
		if wantTag ~= nil and tag ~= wantTag then
			child:_settle(REJECTED, err, tag) -- not our tag; propagate untouched
			return
		end
		local ok, result = pcall(handler, err, tag)
		if not ok then
			child:_settle(REJECTED, result, "AccedeError")
		elseif getmetatable(result) == Accede then
			result:_forwardTo(child)
		else
			child:_settle(RESOLVED, result) -- handled = recovered
		end
	end)
	return child
end

function Accede:subscribe(fn)
	if self._state ~= PENDING then
		task.spawn(fn, { status = self._state, value = self._value, error = self._error, tag = self._tag })
	else
		table.insert(self._subs, fn)
	end
	return self
end

-- Always runs once settled, with a structured result. Terminal (returns self).
function Accede:conclude(fn)
	local function report()
		task.spawn(fn, { status = self._state, value = self._value, error = self._error, tag = self._tag })
	end
	if self._state ~= PENDING then
		report()
	else
		table.insert(self._queue, {
			onResolve = report,
			onReject = report,
		})
	end
	return self
end

function Accede:fallback(value)
	return self:_then(nil, function()
		return value
	end)
end

function Accede:timeout(seconds: number)
	task.delay(seconds, function()
		self:_settle(REJECTED, ("timeout after %.2fs"):format(seconds), "Timeout")
	end)
	return self
end

-- Cancel the chain when a Roblox instance leaves the tree.
function Accede:link(instance: Instance)
	local conn
	conn = instance.AncestryChanged:Connect(function(_, parent)
		if not parent then
			conn:Disconnect()
			self:cancel()
		end
	end)
	return self
end

function Accede:cancel()
	self:_settle(CANCELLED, nil)
	if self._token then
		self._token:cancel()
	end
end

-- Yield until settled. Returns (true, value) or (false, err, tag).
function Accede:await()
	while self._state == PENDING do
		task.wait()
	end
	if self._state == RESOLVED then
		return true, self._value
	end
	return false, self._error, self._tag
end

-- ===================================================================== factories ===

function Accede.new(executor, token)
	local self = new(token)
	if token then
		token:onCancel(function()
			self:_settle(CANCELLED, nil)
		end)
	end
	local function resolve(v)
		self:_settle(RESOLVED, v)
	end
	local function reject(err, tag)
		self:_settle(REJECTED, err, tag)
	end
	local function progress(p)
		for _, sub in self._subs do
			task.spawn(sub, { status = "progress", value = p })
		end
	end
	local ok, err = pcall(executor, resolve, reject, progress)
	if not ok then
		reject(err, "AccedeError")
	end
	return self
end

function Accede.resolve(value)
	local self = new()
	self:_settle(RESOLVED, value)
	return self
end

function Accede.reject(err, tag)
	local self = new()
	self:_settle(REJECTED, err, tag)
	return self
end

-- Wrap a yielding function so calling it returns an Accede that resolves with its
-- return (or rejects if it errors). The bread-and-butter wrapper for DataStore/HTTP/etc.
function Accede.wrap(fn)
	return function(...)
		local args = table.pack(...)
		return Accede.new(function(resolve, reject)
			task.spawn(function()
				local results = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
				if results[1] then
					resolve(table.unpack(results, 2, results.n))
				else
					reject(results[2], "AccedeError")
				end
			end)
		end)
	end
end

-- ===================================================================== combinators =

-- Resolves with an array of all values, or rejects on the first failure.
function Accede.all(list)
	return Accede.new(function(resolve, reject)
		local results, remaining = {}, #list
		if remaining == 0 then
			resolve(results)
			return
		end
		for i, a in list do
			a:next(function(v)
				results[i] = v
				remaining -= 1
				if remaining == 0 then
					resolve(results)
				end
			end):toss(function(e, tag)
				reject(e, tag)
			end)
		end
	end)
end

-- Resolves with the first to resolve; rejects only if all fail.
function Accede.any(list)
	return Accede.new(function(resolve, reject)
		local remaining = #list
		for _, a in list do
			a:next(function(v)
				resolve(v)
			end):toss(function(e, tag)
				remaining -= 1
				if remaining == 0 then
					reject(e, tag)
				end
			end)
		end
	end)
end

-- Settles with whichever settles first (resolve OR reject).
function Accede.race(list)
	return Accede.new(function(resolve, reject)
		for _, a in list do
			a:next(resolve):toss(reject)
		end
	end)
end

return Accede
