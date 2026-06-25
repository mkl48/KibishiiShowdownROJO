local RunService = game:GetService("RunService")

local Registry    = require(script.Registry)
local Middleware  = require(script.Middleware)
local Cache       = require(script.Cache)
local ContextMod  = require(script.Context)
local Lifecycle   = require(script.Lifecycle)
local Diagnostics = require(script.Diagnostics)

local Types = require(script.Types)

local ArTex = {}
ArTex.version = "1.0.0"

local _configured    = false
local _compiled      = false
local _compiling     = false
local _config        = {}
local _Fabrik        = nil
local _Schema        = nil
local _extensions    = {}
local _plugins       = {}
local _pluginHandles = {}
local _flags         = {}
local _schedules     = {}
local _scheduleId    = 0
local _workflows     = {}
local _commands      = {}
local _queries       = {}
local _globalEvents  = {}
local _loadedFns     = {}
local _ctxMap        = {}
local _ready         = nil
local _isReady       = false
local _bootStart     = nil
local _graph         = {}
local _classOrder    = {} :: { [string]: number }

local function assertConfigured(method)
	if not _configured then
		error("[ArTex] " .. method .. " called before ArTex.configure()")
	end
end

local function assertPreCompile(method)
	if _compiling or _compiled then
		error("[ArTex] " .. method .. " must be called before ArTex.compile()")
	end
end

local function resolveClassPriority(record): number
	if #_classOrder == 0 then return 0 end

	local instance = record.instance
	if not instance then return 0 end

	local parent = instance.Parent
	if not parent then return 0 end

	local parentName = parent.Name

	local direct = _classOrder[parentName]
	if direct then return direct end

	for className, weight in _classOrder do
		if parentName:lower():find(className:lower()) then
			return weight
		end
	end

	return 0
end

function ArTex.configure(opts: Types.ConfigureOptions)
	if _configured then
		error("[ArTex] configure() already called -- use ArTex.reset() first")
	end

	if RunService:IsServer() then
		assert(opts.NetworkManager,    "[ArTex] configure(): NetworkManager is required")
	else
		assert(opts.NetworkController, "[ArTex] configure(): NetworkController is required")
	end

	assert(opts.ContextStructure, "[ArTex] configure(): ContextStructure is required")

	_Fabrik = script:FindFirstChild("Fabrik") and require(script.Fabrik) or nil
	_Schema = script:FindFirstChild("Schema") and require(script.Schema) or nil

	if _Fabrik then
		Cache.init(_Fabrik)
		_ready = _Fabrik.latch.new()
	end

	_config     = opts
	_configured = true

	if opts.Strict then Registry.setStrict(true) end
end

--[[
	classOrder(map)

	Assigns boot-priority weights to folder/class names within any tier.
	Higher weight = boots earlier. Modules whose parent folder name matches
	a key here are sorted before unweighted modules in the same tier.

	Example -- ensure Managers and Controllers always precede Services:

		ArTex.classOrder({
			Manager    = 100,
			Controller = 90,
			Service    = 50,
		})

	Folder name matching is case-insensitive and also checks for substrings,
	so "PlayerManager" and "Managers" both match the "Manager" key.

	Must be called before ArTex.compile().
]]
function ArTex.classOrder(map: { [string]: number })
	assertConfigured("classOrder")
	assertPreCompile("classOrder")
	for k, v in map do
		_classOrder[k] = v
	end
	Registry.setClassResolver(resolveClassPriority)
	print(resolveClassPriority())
end

function ArTex.Inside(contextName, namespace, name, value)
	assertConfigured("Inside")
	assertPreCompile("Inside")
	ContextMod.inject(contextName, namespace, name, value)
end

function ArTex.priority(map)
	assertConfigured("priority")
	assertPreCompile("priority")
	Registry.setPriorityMap(map)
end

function ArTex.middleware(phaseOrFn, fn)
	assertConfigured("middleware")
	Middleware.add(phaseOrFn, fn)
end

function ArTex.compile(opts)
	assertConfigured("compile")
	if _compiled or _compiling then
		error("[ArTex] compile() already called")
	end

	opts = opts or {}

	local promise
	if _Fabrik then
		promise = _Fabrik.promise(function(resolve, reject)
			task.spawn(function()
				local ok, err = pcall(ArTex._runCompile, opts, resolve)
				if not ok then reject(err) end
			end)
		end)
	else
		task.spawn(ArTex._runCompile, opts, function() end)
		promise = {
			next     = function(_, fn) fn() return promise end,
			catch    = function(_, fn) return promise end,
			conclude = function(_, fn) fn() return promise end,
		}
	end

	return promise
end

function ArTex._runCompile(opts, resolve)
	_compiling = true
	_bootStart = os.clock()
	Diagnostics.start()
	Lifecycle.runPrecompile()

	local tierOrder = Registry.getTierOrder(_config.TierOrder)

	Registry.scan(_config.ContextStructure)

	local cycles = Registry.detectCycles()
	if #cycles > 0 then
		local lines = { "[ArTex] dependency cycle detected before boot" }
		for _, cycle in cycles do
			table.insert(lines, "  " .. table.concat(cycle, " -> "))
			table.insert(lines, "  Fix: remove '" .. cycle[#cycle] .. "' from '" .. cycle[#cycle - 1] .. ".After'")
			table.insert(lines, "       or use ArTex.await() inside Start instead")
		end
		error(table.concat(lines, "\n"))
	end

	if opts.dry then
		print("[ArTex] Dry run -- resolved boot order:")
		for _, tier in tierOrder do
			local records = Registry.getByTier(tier)
			print("  " .. tier .. ":")
			for _, r in records do
				local cp = resolveClassPriority(r)
				local cpStr = cp ~= 0 and (" [class:" .. cp .. "]") or ""
				print("    " .. r.name .. cpStr)
			end
		end
		_compiling = false
		resolve()
		return
	end

	local allRecords = Registry.all()

	for _, record in allRecords do
		local ctx = ContextMod.build(record, ArTex, Cache, _config)
		ContextMod.applyStructure(ctx, Registry)
		_ctxMap[record.name] = ctx
	end

	ContextMod.wireClientProxies(Registry, _Schema, _ctxMap)
	ContextMod.buildClientProxies(Registry, _Schema, _ctxMap)

	for _, tier in tierOrder do
		local records = Registry.getByTier(tier)
		if #records == 0 then continue end
		Lifecycle.runTier(records, _ctxMap, Middleware, _config, Registry)
	end

	Diagnostics.finish(Registry)
	Diagnostics.printBoot(Registry, _config.Verbosity)

	_compiling = false
	_compiled  = true
	_isReady   = true

	if _ready then _ready:open() end

	Lifecycle.runPostcompile()

	local modules = Registry.all()
	for _, fn in _loadedFns do
		pcall(fn, modules)
	end

	resolve(modules)
end

function ArTex.loaded(fn)
	if _compiled then
		pcall(fn, Registry.all())
	else
		table.insert(_loadedFns, fn)
	end
end

function ArTex.onError(fn)
	Lifecycle.onError(fn)
end

function ArTex.onModuleLoaded(fn)
	Lifecycle.onModuleLoaded(fn)
end

function ArTex.onPhaseStart(phase, fn)
	Lifecycle.onPhaseStart(phase, fn)
end

function ArTex.onPhaseEnd(phase, fn)
	Lifecycle.onPhaseEnd(phase, fn)
end

function ArTex.onProgress(fn)
	Lifecycle.onProgress(fn)
end

function ArTex.precompile(fn)
	Lifecycle.precompile(fn)
end

function ArTex.postcompile(fn)
	Lifecycle.postcompile(fn)
end

function ArTex.get(name)
	local record = Registry.get(name)
	if not record then
		error("[ArTex] get(): module not found -- " .. tostring(name))
	end
	return record.mod
end

function ArTex.has(name)
	return Registry.has(name)
end

function ArTex.await(name)
	if not _Fabrik then
		error("[ArTex] await() requires Fabrik")
	end
	return _Fabrik.promise(function(resolve)
		if Registry.has(name) and Registry.get(name).status == "started" then
			resolve(Registry.get(name).mod)
			return
		end
		Lifecycle.onModuleLoaded(function(loaded)
			if loaded == name then
				resolve(Registry.get(name).mod)
			end
		end)
	end)
end

function ArTex.modules()
	local result = {}
	for _, record in Registry.all() do
		table.insert(result, {
			name          = record.name,
			status        = record.status,
			tier          = record.tier,
			context       = record.context,
			timing        = record.timing,
			tags          = record.tags,
			version       = record.version,
			alias         = record.alias,
			classPriority = resolveClassPriority(record),
		})
	end
	return result
end

function ArTex.status(name)
	local record = Registry.get(name)
	return record and record.status or "pending"
end

function ArTex.context()
	return RunService:IsServer() and "Server" or "Client"
end

function ArTex.isReady()
	return _isReady
end

function ArTex.uptime()
	if not _bootStart then return 0 end
	return os.clock() - _bootStart
end

function ArTex.time()
	if not _bootStart then return 0 end
	return os.clock() - _bootStart
end

ArTex.ready = setmetatable({}, {
	__index = function(_, key)
		if _ready then return _ready[key] end
	end,
})

ArTex.Cache = Cache

ArTex.diagnostics = setmetatable({}, {
	__index = function(_, key)
		return Diagnostics.get()[key]
	end,
})

ArTex.config = setmetatable({}, {
	__index = function(_, key)
		return _config[key]
	end,
	get = function(key)
		return _config[key]
	end,
})

function ArTex.report()
	return Diagnostics.report(Registry)
end

function ArTex.trace()
	return Diagnostics.trace()
end

function ArTex.health()
	return Diagnostics.health(Registry)
end

function ArTex.inspect(name)
	return Diagnostics.inspect(Registry, name)
end

function ArTex.compare(nameA, nameB)
	return Diagnostics.compare(Registry, nameA, nameB)
end

function ArTex.snapshot()
	return Diagnostics.snapshot(Registry, Cache)
end

function ArTex.diff(snap1, snap2)
	return Diagnostics.diff(snap1, snap2)
end

function ArTex.emit(event, data)
	Diagnostics.emit(event, data)
	local listeners = _globalEvents[event]
	if listeners then
		for _, fn in listeners do
			pcall(fn, data)
		end
	end
end

function ArTex.span(name)
	Diagnostics.span(name)
end

function ArTex.endSpan(name)
	Diagnostics.endSpan(name)
end

ArTex.spans = setmetatable({}, {
	__index = function(_, key)
		return Diagnostics.getSpans()[key]
	end,
})

function ArTex.checkpoint(name)
	Diagnostics.checkpoint(name, Registry, Cache)
end

function ArTex.rollback(name)
	return Diagnostics.rollback(name)
end

function ArTex.extend(name, methods)
	_extensions[name] = methods
	ArTex[name] = methods
end

function ArTex.install(plugin, opts)
	assert(plugin and plugin.name, "[ArTex] install(): plugin must have a name")

	if plugin.requires then
		for _, dep in plugin.requires do
			if not _plugins[dep] then
				error("[ArTex] install(): plugin " .. plugin.name .. " requires " .. dep)
			end
		end
	end

	local pluginProxy = {
		middleware     = function(p, fn) Middleware.add(p, fn) end,
		onCompileStart = function(fn) Lifecycle.precompile(fn) end,
		onCompileEnd   = function(fn) Lifecycle.postcompile(fn) end,
		onModuleStart  = function(fn) Lifecycle.onModuleLoaded(fn) end,
		onModuleError  = function(fn) Lifecycle.onError(fn) end,
		onCacheChange  = function(key, fn)
			if type(key) == "function" then
				fn = key
				Cache.watch("*", fn)
			else
				Cache.watch(key, fn)
			end
		end,
		extend = function(name, methods) ArTex.extend(name, methods) end,
	}

	local handle = plugin:install(pluginProxy, opts)
	_plugins[plugin.name]       = plugin
	_pluginHandles[plugin.name] = handle or {}
	return handle or {}
end

function ArTex.open(pluginName, methodName, ...)
	local handle = _pluginHandles[pluginName]
	if not handle then
		warn("[ArTex] open(): plugin not installed -- " .. pluginName)
		return
	end
	local method = handle[methodName]
	if not method then
		warn("[ArTex] open(): method not found -- " .. pluginName .. "." .. methodName)
		return
	end
	return method(...)
end

function ArTex.plug(name)
	return _pluginHandles[name]
end

ArTex.Plugins = {}

function ArTex.disable(name)
	Registry.disable(name)
end

function ArTex.enable(name)
	Registry.enable(name)
end

function ArTex.pin(name)
	Registry.pin(name)
end

function ArTex.unpin(name)
	Registry.unpin(name)
end

function ArTex.mock(name, mockMod)
	Registry.mock(name, mockMod)
end

function ArTex.isMocked(name)
	return Registry.isMocked(name)
end

function ArTex.replace(name, mod)
	Registry.replace(name, mod)
end

function ArTex.freeze()
	ContextMod.freeze()
end

function ArTex.seal()
	_configured = true
	_compiling  = true
end

function ArTex.reset()
	if not RunService:IsStudio() then
		warn("[ArTex] reset() is Studio-only")
		return
	end
	Registry.reset()
	Middleware.reset()
	Cache.reset()
	ContextMod.reset()
	Lifecycle.reset()
	Diagnostics.reset()

	_configured    = false
	_compiled      = false
	_compiling     = false
	_config        = {}
	_extensions    = {}
	_plugins       = {}
	_pluginHandles = {}
	_flags         = {}
	_schedules     = {}
	_scheduleId    = 0
	_workflows     = {}
	_commands      = {}
	_queries       = {}
	_globalEvents  = {}
	_loadedFns     = {}
	_ctxMap        = {}
	_ready         = nil
	_isReady       = false
	_bootStart     = nil
	_classOrder    = {}
end

function ArTex.reconfigure(opts)
	for k, v in opts do
		_config[k] = v
	end
end

function ArTex.flag(name)
	return _flags[name] == true
end

function ArTex.setFlag(name, value)
	_flags[name] = value
end

ArTex.flags = setmetatable({}, {
	__index    = function(_, key) return _flags[key] end,
	__newindex = function(_, key, value) _flags[key] = value end,
})

function ArTex.schedule(interval, fn)
	_scheduleId += 1
	local id     = _scheduleId
	local handle = { cancelled = false }

	task.spawn(function()
		while not handle.cancelled do
			task.wait(interval)
			if not handle.cancelled then
				pcall(fn)
			end
		end
	end)

	_schedules[id] = handle
	return id
end

function ArTex.cancelSchedule(id)
	local handle = _schedules[id]
	if handle then
		handle.cancelled = true
		_schedules[id] = nil
	end
end

ArTex.schedules = setmetatable({}, {
	__index = function(_, key) return _schedules[key] end,
})

function ArTex.command(name, fn)
	_commands[name] = fn
end

function ArTex.query(name, fn)
	_queries[name] = fn
end

function ArTex.dispatch(name, data)
	local fn = _commands[name]
	if not fn then
		error("[ArTex] dispatch(): command not found -- " .. name)
	end
	if _Fabrik then
		return _Fabrik.promise(function(resolve, reject)
			local ok, result = pcall(fn, data)
			if ok then resolve(result) else reject(result) end
		end)
	end
	return fn(data)
end

function ArTex.ask(name, data)
	local fn = _queries[name]
	if not fn then
		error("[ArTex] ask(): query not found -- " .. name)
	end
	if _Fabrik then
		return _Fabrik.promise(function(resolve, reject)
			local ok, result = pcall(fn, data)
			if ok then resolve(result) else reject(result) end
		end)
	end
	return fn(data)
end

function ArTex.workflow(name, steps)
	_workflows[name] = steps
end

function ArTex.runWorkflow(name, data)
	local steps = _workflows[name]
	if not steps then
		error("[ArTex] runWorkflow(): workflow not found -- " .. name)
	end
	if not _Fabrik then
		error("[ArTex] runWorkflow() requires Fabrik")
	end

	return _Fabrik.promise(function(resolve, reject)
		task.spawn(function()
			local ctx = table.clone(data or {})
			for _, step in steps do
				local ok, result = pcall(step, ctx)
				if not ok then
					reject(result)
					return
				end
				if type(result) == "table" then
					for k, v in result do
						ctx[k] = v
					end
				end
			end
			resolve(ctx)
		end)
	end)
end

ArTex.workflows = setmetatable({}, {
	__index = function(_, key) return _workflows[key] end,
})

function ArTex.event(name)
	if not _globalEvents[name] then
		_globalEvents[name] = {}
	end
end

function ArTex.on(name, fn)
	if not _globalEvents[name] then _globalEvents[name] = {} end
	table.insert(_globalEvents[name], fn)
end

function ArTex.off(name, fn)
	local list = _globalEvents[name]
	if not list then return end
	for i, f in list do
		if f == fn then
			table.remove(list, i)
			break
		end
	end
end

function ArTex.promise(fn)
	assert(_Fabrik, "[ArTex] promise() requires Fabrik")
	return _Fabrik.promise(fn)
end

function ArTex.race(promises)
	assert(_Fabrik, "[ArTex] race() requires Fabrik")
	return _Fabrik.promise.race(promises)
end

function ArTex.timeout(promise, secs)
	assert(_Fabrik, "[ArTex] timeout() requires Fabrik")
	return _Fabrik.promise.timeout(promise, secs)
end

function ArTex.signal()
	assert(_Fabrik, "[ArTex] signal() requires Fabrik")
	return _Fabrik.signal.new()
end

function ArTex.atom(value)
	assert(_Fabrik, "[ArTex] atom() requires Fabrik")
	return _Fabrik.atom(value)
end

function ArTex.molecule(shape)
	assert(_Fabrik, "[ArTex] molecule() requires Fabrik")
	return _Fabrik.molecule(shape)
end

function ArTex.batch(fn)
	assert(_Fabrik, "[ArTex] batch() requires Fabrik")
	return _Fabrik.batch(fn)
end

function ArTex.latch()
	assert(_Fabrik, "[ArTex] latch() requires Fabrik")
	return _Fabrik.latch.new()
end

function ArTex.interval(secs, fn)
	assert(_Fabrik, "[ArTex] interval() requires Fabrik")
	return _Fabrik.thread.interval(secs, fn)
end

function ArTex.debounce(fn, secs)
	assert(_Fabrik, "[ArTex] debounce() requires Fabrik")
	return _Fabrik.cooldown.new(secs):debounce(fn)
end

function ArTex.throttle(fn, secs)
	assert(_Fabrik, "[ArTex] throttle() requires Fabrik")
	return _Fabrik.cooldown.new(secs):throttle(fn)
end

function ArTex.measure(fn)
	local t = os.clock()
	fn()
	return (os.clock() - t) * 1000
end

function ArTex.defer(fn)
	if _compiled then
		task.defer(fn)
	else
		Lifecycle.postcompile(function()
			task.defer(fn)
		end)
	end
end

function ArTex.once(event, fn)
	local disconnect
	disconnect = ArTex.on(event, function(...)
		pcall(fn, ...)
		ArTex.off(event, disconnect)
	end)
end

function ArTex.protect(fn)
	local ok, err = pcall(fn)
	if not ok then
		Lifecycle.onError(function() end)
		warn("[ArTex] protect(): " .. tostring(err))
	end
	return ok, err
end

function ArTex.log(level, message)
	local verbosity = _config.Verbosity or "warn"
	local levels    = { trace = 1, info = 2, warn = 3, error = 4, silent = 5 }
	if (levels[level] or 1) >= (levels[verbosity] or 3) then
		if level == "error" or level == "warn" then
			warn("[ArTex] " .. message)
		else
			print("[ArTex] " .. message)
		end
	end
end

function ArTex.print(message)
	print("[ArTex] " .. message)
end

function ArTex.warn(message)
	ArTex.log("warn", message)
end

function ArTex.error(message)
	ArTex.log("error", message)
	Diagnostics.emit("error", message)
end

function ArTex.assert(condition, message)
	if not condition then
		ArTex.error(message)
		error("[ArTex] " .. message, 2)
	end
end

function ArTex.channel(name, shape, opts)
	assert(_Schema, "[ArTex] channel() requires Schema")
	return _Schema.channel(name, shape, opts)
end

function ArTex.define(name, shape, opts)
	assert(_Schema, "[ArTex] define() requires Schema")
	return _Schema.define(name, shape, opts)
end

function ArTex.post(name, ...)
	assert(_Schema, "[ArTex] post() requires Schema")
	return _Schema.post(name, ...)
end

function ArTex.subscribe(name, fn)
	assert(_Schema, "[ArTex] subscribe() requires Schema")
	return _Schema.subscribe(name, fn)
end

function ArTex.party(name)
	assert(_Schema, "[ArTex] party() requires Schema")
	return _Schema.party(name)
end

function ArTex.validate(name, data)
	assert(_Schema, "[ArTex] validate() requires Schema")
	return _Schema.validate(name, data)
end

ArTex.Type = setmetatable({}, {
	__index = function(_, key)
		assert(_Schema, "[ArTex] Type requires Schema")
		return _Schema.Type[key]
	end,
})

function ArTex.route(name, shape, opts)
	assert(_Schema, "[ArTex] route() requires Schema")
	return _Schema.define(name, shape, opts)
end

function ArTex.useState(key, initial)
	Cache.set(key, Cache.get(key) or initial)
	return Cache.get(key), function(v) Cache.set(key, v) end
end

function ArTex.useAtom(initial)
	assert(_Fabrik, "[ArTex] useAtom() requires Fabrik")
	return _Fabrik.atom(initial)
end

function ArTex.useMolecule(shape)
	assert(_Fabrik, "[ArTex] useMolecule() requires Fabrik")
	return _Fabrik.molecule(shape)
end

function ArTex.bind(key, instance, property)
	Cache.bind(key, instance, property)
end

function ArTex.unbind(key)
	Cache.watch(key, function() end)
end

function ArTex.getTagged(tag)
	local result = {}
	for _, record in Registry.getTagged(tag) do
		table.insert(result, record.mod)
	end
	return result
end

function ArTex.getTier(name)
	local record = Registry.get(name)
	return record and record.tier or nil
end

function ArTex.getContext(name)
	local record = Registry.get(name)
	return record and record.context or nil
end

function ArTex.tag(name, tags)
	local record = Registry.get(name)
	if not record then return end
	for _, tag in tags do
		if not table.find(record.tags, tag) then
			table.insert(record.tags, tag)
		end
	end
end

function ArTex.untag(name, tags)
	local record = Registry.get(name)
	if not record then return end
	for _, tag in tags do
		local idx = table.find(record.tags, tag)
		if idx then table.remove(record.tags, idx) end
	end
end

function ArTex.schema(name)
	local record = Registry.get(name)
	return record and record.mod.Schema or nil
end

function ArTex.exports(name)
	local record = Registry.get(name)
	return record and record.mod.Exports or nil
end

function ArTex.find(fn)
	local record = Registry.find(fn)
	return record and record.mod or nil
end

function ArTex.filter(fn)
	local result = {}
	for _, record in Registry.filter(fn) do
		table.insert(result, record.mod)
	end
	return result
end

function ArTex.search(query)
	query = query:lower()
	return ArTex.filter(function(record)
		if record.name:lower():find(query) then return true end
		if record.alias and record.alias:lower():find(query) then return true end
		for _, tag in (record.tags or {}) do
			if tag:lower():find(query) then return true end
		end
		return false
	end)
end

function ArTex.graph()
	return _graph
end

function ArTex.benchmark(name)
	if not RunService:IsStudio() then return end
	local record = Registry.get(name)
	if not record then return end
	local ctx = _ctxMap[name]
	local t   = os.clock()
	if record.mod.Start then
		pcall(record.mod.Start, ctx)
	end
	return (os.clock() - t) * 1000
end

function ArTex.spy(name, method)
	if not RunService:IsStudio() then return end
	local record = Registry.get(name)
	if not record then return end
	local original = record.mod[method]
	if not original then return end
	record.mod[method] = function(...)
		print("[ArTex:spy] " .. name .. "." .. method .. " called")
		return original(...)
	end
end

function ArTex.unspy(name, method)
	warn("[ArTex] unspy() -- store original reference to restore")
end

function ArTex.metric(name, metricType)
	ArTex._metrics = ArTex._metrics or {}
	ArTex._metrics[name] = { type = metricType, value = 0, samples = {} }
end

function ArTex.increment(name, amount)
	local m = (ArTex._metrics or {})[name]
	if m then m.value += (amount or 1) end
end

function ArTex.gauge(name, value)
	local m = (ArTex._metrics or {})[name]
	if m then m.value = value end
end

function ArTex.histogram(name, value)
	local m = (ArTex._metrics or {})[name]
	if m then table.insert(m.samples, value) end
end

ArTex.metrics = setmetatable({}, {
	__index = function(_, key)
		return (ArTex._metrics or {})[key]
	end,
})

ArTex.bindings = Cache._bindings or {}

function ArTex.when(conditions, fn)
	assertConfigured("when")

	if type(conditions) == "table" and conditions.Cache then
		local key      = conditions.Cache
		local expected = conditions.is
		local function check(value)
			if value == expected then pcall(fn) end
		end
		Cache.watch(key, check)
		check(Cache.get(key))
		return
	end

	if type(conditions) == "table" then
		local function checkAll()
			for _, flag in conditions do
				if not _flags[flag] then return false end
			end
			return true
		end
		if checkAll() then
			pcall(fn)
		else
			Cache.watch("__flags__", function()
				if checkAll() then
					pcall(fn)
					Cache.watch("__flags__", nil)
				end
			end)
		end
	end
end

local _streams = {}

function ArTex.stream(cacheKey, player)
	assert(_Schema, "[ArTex] stream() requires Schema")
	assertConfigured("stream")

	if not RunService:IsServer() then return end

	local channelName = "__stream__." .. cacheKey
	local T           = _Schema.Type

	if not _streams[cacheKey] then
		_Schema.define(channelName, {
			key   = T.string(),
			value = T.any(true),
		}, { mode = "unreliable" })

		_streams[cacheKey] = true

		Cache.watch(cacheKey, function(new)
			local payload = { key = cacheKey, value = new }
			if player then
				_Schema.post(channelName, player, payload)
			else
				_Schema.postAll(channelName, payload)
			end
		end)
	end

	local current = Cache.get(cacheKey)
	if current ~= nil then
		local payload = { key = cacheKey, value = current }
		if player then
			_Schema.post(channelName, player, payload)
		else
			_Schema.postAll(channelName, payload)
		end
	end
end

function ArTex._initStreamClient()
	if not RunService:IsClient() then return end
	if not _Schema then return end

	local T = _Schema.Type

	task.defer(function()
		for cacheKey in _streams do
			local channelName = "__stream__." .. cacheKey
			pcall(function()
				_Schema.define(channelName, {
					key   = T.string(),
					value = T.any(true),
				}, { mode = "unreliable" })

				_Schema.subscribe(channelName, function(_, data)
					if data and data.key then
						Cache.set(data.key, data.value)
					end
				end)
			end)
		end
	end)
end

local _stores = {}

function ArTex.store(name, initialState, reducers)
	assert(type(name)         == "string", "[ArTex] store(): name must be a string")
	assert(type(initialState) == "table",  "[ArTex] store(): initialState must be a table")
	assert(type(reducers)     == "table",  "[ArTex] store(): reducers must be a table")

	local cacheKey   = "__store__." .. name
	local _listeners = {}

	Cache.set(cacheKey, table.clone(initialState))

	local store = {}

	function store.getState()
		return Cache.get(cacheKey)
	end

	function store.dispatch(action, data)
		local reducer = reducers[action]
		if not reducer then
			error("[ArTex] store '" .. name .. "': unknown action '" .. action .. "'")
		end
		local current = store.getState()
		local next    = reducer(table.clone(current), data)
		local old     = current
		Cache.set(cacheKey, next)
		for _, fn in _listeners do
			pcall(fn, next, old)
		end
	end

	function store.subscribe(fn)
		table.insert(_listeners, fn)
		return function()
			for i, f in _listeners do
				if f == fn then table.remove(_listeners, i) break end
			end
		end
	end

	function store.reset()
		Cache.set(cacheKey, table.clone(initialState))
	end

	_stores[name] = store
	return store
end

function ArTex.gate(name, fn)
	assertConfigured("gate")
	assertPreCompile("gate")
	Lifecycle.registerGate(name, fn)
end

function ArTex.scenario(name, opts)
	assert(RunService:IsStudio(), "[ArTex] scenario() is Studio-only")
	opts = opts or {}

	local scenario = {}

	function scenario.run(fn)
		if not _Fabrik then
			error("[ArTex] scenario() requires Fabrik")
		end

		return _Fabrik.promise(function(resolve, reject)
			task.spawn(function()
				local isolatedCache = require(script.Cache)
				isolatedCache.reset()

				local mockCtx = {
					ArTex   = ArTex,
					Cache   = isolatedCache,
					Context = ArTex.context(),
					Log     = {
						trace = print,
						info  = print,
						warn  = warn,
						error = warn,
					},
				}

				for mockName, mockMod in (opts.mocks or {}) do
					mockCtx[mockName] = mockMod
					local tier = Registry.get(mockName) and Registry.get(mockName).tier
					if tier then
						if not mockCtx[tier] then mockCtx[tier] = {} end
						mockCtx[tier][mockName] = mockMod
					end
				end

				local passed = 0
				local total  = 0
				local errors = {}

				ArTex._scenarioExpect = function(value)
					return {
						toBeDefined = function()
							total += 1
							if value ~= nil then passed += 1
							else table.insert(errors, "expected defined value, got nil") end
							return value
						end,
						toBe = function(expected)
							total += 1
							if value == expected then passed += 1
							else table.insert(errors, "expected " .. tostring(expected) .. ", got " .. tostring(value)) end
						end,
						toEqual = function(expected)
							total += 1
							if value == expected then passed += 1
							else table.insert(errors, "toEqual failed") end
						end,
					}
				end

				local ok, err = pcall(fn, mockCtx)

				ArTex._scenarioExpect = nil

				if not ok then
					reject(err)
					return
				end

				resolve({
					name   = name,
					passed = passed,
					total  = total,
					errors = errors,
					ok     = #errors == 0,
				})
			end)
		end)
	end

	return scenario
end

function ArTex.expect(value)
	if ArTex._scenarioExpect then
		return ArTex._scenarioExpect(value)
	end
	return {
		toBeDefined = function()
			assert(value ~= nil, "[ArTex] expect: value is nil")
			return value
		end,
		toBe = function(expected)
			assert(value == expected, "[ArTex] expect: " .. tostring(value) .. " ~= " .. tostring(expected))
		end,
		toEqual = function(expected)
			assert(value == expected, "[ArTex] expect: toEqual failed")
		end,
	}
end

function ArTex.why(name)
	local record = Registry.get(name)
	if not record then
		print("[ArTex] why('" .. name .. "'): module not found")
		return
	end

	local lines = {
		string.format("[ArTex] %s -- status: %s", name, record.status),
	}

	if record.status == "skipped" then
		table.insert(lines, "  Reason  : " .. (record.skipReason or "unknown"))

		if record.skipReason and record.skipReason:find("flag") then
			local flag = record.skipReason:match("'([^']+)'")
			if flag then
				table.insert(lines, "  Fix     : ArTex.setFlag('" .. flag .. "', true) before compile")
			end
		end

		if record.skipReason and record.skipReason:find("gate") then
			local gate = record.skipReason:match("'([^']+)'")
			if gate then
				table.insert(lines, "  Fix     : ensure ArTex.gate('" .. gate .. "', fn) resolves before compile")
			end
		end
	end

	if record.status == "errored" then
		table.insert(lines, "  Phase   : " .. (record.errorPhase or "unknown"))
		table.insert(lines, "  Error   : " .. tostring(record.errorMsg or "unknown"))

		local waitingOn = record.waitingOn
		if waitingOn then
			local dep       = Registry.get(waitingOn)
			local depStatus = dep and dep.status or "not found"
			table.insert(lines, "  Waiting : ArTex.await('" .. waitingOn .. "') never resolved")
			table.insert(lines, "  Hint    : " .. waitingOn .. ".status is '" .. depStatus .. "' -- check that first")
		end
	end

	if record.status == "pending" then
		table.insert(lines, "  Hint    : compile() has not been called or has not reached this module yet")
	end

	if record.status == "started" then
		table.insert(lines, string.format("  Timing  : %.2fms total across all phases", record.timing))
		if record.tags and #record.tags > 0 then
			table.insert(lines, "  Tags    : " .. table.concat(record.tags, ", "))
		end
		local cp = resolveClassPriority(record)
		if cp ~= 0 then
			table.insert(lines, "  ClassPri: " .. cp)
		end
	end

	warn(table.concat(lines, "\n"))
end

function ArTex.setKeep(keep)
	Cache.setKeep(keep)
end

return ArTex