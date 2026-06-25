local Cache = {}

local _store      = {}
local _watchers   = {}
local _computed   = {}
local _ttl        = {}
local _locks      = {}
local _bindings   = {}
local _batching   = false
local _batchQueue = {}
local _persistent = {}

local Fabrik

function Cache.init(fabrik)
	Fabrik = fabrik
end

local function notifyWatchers(key, new, old)
	if _batching then
		_batchQueue[key] = { new = new, old = old }
		return
	end
	local watchers = _watchers[key]
	if not watchers then return end
	for _, fn in watchers do
		pcall(fn, new, old)
	end
end

local function recomputeComputed()
	for key, entry in _computed do
		local ok, result = pcall(entry.fn)
		if ok then
			local old = _store[key]
			if result ~= old then
				_store[key] = result
				notifyWatchers(key, result, old)
			end
		end
	end
end

function Cache.set(key, value)
	local old = _store[key]
	_store[key] = value
	notifyWatchers(key, value, old)
	recomputeComputed()
end

function Cache.get(key)
	return _store[key]
end

function Cache.has(key)
	return _store[key] ~= nil
end

function Cache.delete(key)
	local old = _store[key]
	_store[key] = nil
	notifyWatchers(key, nil, old)
end

function Cache.clear()
	for key in _store do
		if not _persistent[key] then
			Cache.delete(key)
		end
	end
end

function Cache.size()
	local n = 0
	for _ in _store do n += 1 end
	return n
end

function Cache.keys(pattern)
	local result = {}
	for key in _store do
		if not pattern or key:find(pattern) then
			table.insert(result, key)
		end
	end
	return result
end

function Cache.values()
	local result = {}
	for _, v in _store do
		table.insert(result, v)
	end
	return result
end

function Cache.snapshot()
	local snap = {}
	for k, v in _store do
		snap[k] = v
	end
	return snap
end

function Cache.watch(key, fn)
	if not _watchers[key] then _watchers[key] = {} end
	table.insert(_watchers[key], fn)
	return function()
		local list = _watchers[key]
		if not list then return end
		for i, f in list do
			if f == fn then
				table.remove(list, i)
				break
			end
		end
	end
end

Cache.subscribe = Cache.watch

function Cache.computed(key, fn, deps)
	_computed[key] = { fn = fn, deps = deps or {} }
	local ok, result = pcall(fn)
	if ok then _store[key] = result end
end

function Cache.batch(fn)
	_batching   = true
	_batchQueue = {}
	fn()
	_batching = false
	for key, change in _batchQueue do
		local watchers = _watchers[key]
		if watchers then
			for _, wfn in watchers do
				pcall(wfn, change.new, change.old)
			end
		end
	end
	_batchQueue = {}
end

function Cache.extend(key, field, value)
	local current = _store[key]
	if type(current) ~= "table" then current = {} end
	current[field] = value
	Cache.set(key, current)
end

function Cache.merge(key, tbl)
	local current = _store[key]
	if type(current) ~= "table" then current = {} end
	for k, v in tbl do
		current[k] = v
	end
	Cache.set(key, current)
end

function Cache.clone(key)
	local value = _store[key]
	if type(value) ~= "table" then return value end
	return table.clone(value)
end

function Cache.increment(key, amount)
	local current = _store[key] or 0
	Cache.set(key, current + (amount or 1))
end

function Cache.append(key, value)
	local current = _store[key]
	if type(current) ~= "table" then current = {} end
	table.insert(current, value)
	Cache.set(key, current)
end

function Cache.diff(key, newValue)
	local old = _store[key]
	Cache.set(key, newValue)
	return old
end

function Cache.ttl(key, value, seconds)
	Cache.set(key, value)
	local expireAt = os.clock() + seconds
	_ttl[key] = {
		expireAt = expireAt,
		watchers = {},
	}
	task.delay(seconds, function()
		if _ttl[key] and _ttl[key].expireAt == expireAt then
			for _, fn in _ttl[key].watchers do pcall(fn) end
			_ttl[key] = nil
			Cache.delete(key)
		end
	end)
end

function Cache.ttlRemaining(key)
	local entry = _ttl[key]
	if not entry then return 0 end
	return math.max(0, entry.expireAt - os.clock())
end

function Cache.refresh(key, seconds)
	local entry = _ttl[key]
	if not entry then return end
	local value = _store[key]
	if value ~= nil then
		Cache.ttl(key, value, seconds)
	end
end

function Cache.expire(key)
	local entry = _ttl[key]
	if entry then
		for _, fn in entry.watchers do pcall(fn) end
		_ttl[key] = nil
	end
	Cache.delete(key)
end

function Cache.onExpire(key, fn)
	if not _ttl[key] then return end
	table.insert(_ttl[key].watchers, fn)
end

function Cache.lock(key)
	if not Fabrik then return end
	if not _locks[key] then
		_locks[key] = Fabrik.lock.new()
	end
	return _locks[key]
end

function Cache.transaction(fn)
	_batching   = true
	_batchQueue = {}
	local ok, err = pcall(fn)
	_batching = false
	if ok then
		for key, change in _batchQueue do
			local watchers = _watchers[key]
			if watchers then
				for _, wfn in watchers do pcall(wfn, change.new, change.old) end
			end
		end
	else
		warn("[ArTex] Cache.transaction failed: " .. tostring(err))
	end
	_batchQueue = {}
end

function Cache.atomic(key, fn)
	local current = _store[key]
	local new = fn(current)
	Cache.set(key, new)
	return new
end

function Cache.namespace(prefix)
	local ns = {}
	local fullKey = function(k) return prefix .. "." .. k end

	ns.set      = function(k, v)  Cache.set(fullKey(k), v) end
	ns.get      = function(k)     return Cache.get(fullKey(k)) end
	ns.has      = function(k)     return Cache.has(fullKey(k)) end
	ns.delete   = function(k)     Cache.delete(fullKey(k)) end
	ns.watch    = function(k, fn) return Cache.watch(fullKey(k), fn) end

	ns.keys = function(pattern)
		local result = {}
		for _, key in Cache.keys() do
			if key:sub(1, #prefix + 1) == prefix .. "." then
				local short = key:sub(#prefix + 2)
				if not pattern or short:find(pattern) then
					table.insert(result, short)
				end
			end
		end
		return result
	end

	ns.snapshot = function()
		local snap = {}
		for _, key in Cache.keys() do
			if key:sub(1, #prefix + 1) == prefix .. "." then
				snap[key:sub(#prefix + 2)] = _store[key]
			end
		end
		return snap
	end

	return ns
end

function Cache.localNamespace(player)
	return Cache.namespace("Player." .. player.UserId)
end

local _keepBacking = {}

function Cache.persist(key, opts)
	_persistent[key] = true

	if opts and opts.keepKey and _keepBacking._keep then
		local keepKey = opts.keepKey
		local keep    = _keepBacking._keep

		keep.load(keepKey):next(function(value)
			if value ~= nil then
				Cache.set(key, value)
			end
		end)

		Cache.watch(key, function(new)
			keep.save(keepKey, new)
		end)
	end
end

function Cache.setKeep(keep)
	_keepBacking._keep = keep
end

function Cache.getOrSet(key, defaultFn)
	if Cache.has(key) then return Cache.get(key) end
	local value = defaultFn()
	Cache.set(key, value)
	return value
end

function Cache.evict(pattern)
	for _, key in Cache.keys(pattern) do
		Cache.delete(key)
	end
end

function Cache.count(predicate)
	if not predicate then return Cache.size() end
	local n = 0
	for k, v in _store do
		if predicate(k, v) then n += 1 end
	end
	return n
end

function Cache.map(fn)
	local result = {}
	for k, v in _store do
		result[k] = fn(k, v)
	end
	return result
end

function Cache.filter(fn)
	local result = {}
	for k, v in _store do
		if fn(k, v) then result[k] = v end
	end
	return result
end

function Cache.reduce(fn, initial)
	local acc = initial
	for k, v in _store do
		acc = fn(acc, k, v)
	end
	return acc
end

function Cache.forEach(fn)
	for k, v in _store do
		fn(k, v)
	end
end

function Cache.search(query)
	query = query:lower()
	local result = {}
	for k, v in _store do
		if k:lower():find(query) then
			result[k] = v
		end
	end
	return result
end

function Cache.bind(key, instance, property)
	local disconnect = Cache.watch(key, function(new)
		if instance and instance.Parent then
			instance[property] = new
		end
	end)
	_bindings[key] = { instance = instance, property = property, disconnect = disconnect }
end

function Cache.reset()
	_store      = {}
	_watchers   = {}
	_computed   = {}
	_ttl        = {}
	_locks      = {}
	_bindings   = {}
	_batching   = false
	_batchQueue = {}
	_persistent = {}
end

return Cache