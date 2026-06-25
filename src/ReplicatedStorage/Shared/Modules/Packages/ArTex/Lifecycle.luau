local Lifecycle = {}

local _onError        = {}
local _onModuleLoaded = {}
local _onPhaseStart   = {}
local _onPhaseEnd     = {}
local _onProgress     = {}
local _precompile     = {}
local _postcompile    = {}
local _gates          = {}

local function fireAll(list, ...)
	for _, fn in list do
		pcall(fn, ...)
	end
end

local function formatError(record, phase, err)
	local lines = {
		string.format("[ArTex] ✗ %s failed during %s", record.name, phase),
		string.format("  Tier    : %s", record.tier),
		string.format("  Phase   : %s", phase),
	}

	local errStr = tostring(err)

	local file, line = errStr:match("([^:]+%.lua):(%d+)")
	if file and line then
		table.insert(lines, string.format("  Line    : %s:%s", file, line))
	end

	local msg = errStr:gsub("^[^:]+:%d+:%s*", "")
	table.insert(lines, string.format("  Error   : %s", msg))

	return table.concat(lines, "\n")
end

local function runWithTimeout(fn, seconds, label)
	local done   = false
	local result = nil
	local err    = nil

	local thread = task.spawn(function()
		local ok, val = pcall(fn)
		done   = true
		result = val
		if not ok then err = val end
	end)

	local elapsed = 0
	local step    = 0.05
	while not done and elapsed < seconds do
		task.wait(step)
		elapsed += step
	end

	if not done then
		task.cancel(thread)
		return false, label .. " timed out after " .. seconds .. "s"
	end

	if err then
		return false, err
	end

	return true, result
end

local function shouldSkip(record, config)
	if record.mod.NoBoot then
		return true, "NoBoot = true"
	end

	local isShared = record.context == "Shared"
	if isShared and not record.mod.Boot then
		return true, "Shared module -- Boot not set to true"
	end

	local flags = record.mod.Flags
	if flags then
		for _, flag in flags do
			if not (config.flags and config.flags[flag]) then
				return true, "flag '" .. flag .. "' is false"
			end
		end
	end

	local gate = record.mod.Gate
	if gate and _gates[gate] then
		local ok, result = pcall(_gates[gate])
		if not ok or not result then
			return true, "gate '" .. gate .. "' did not pass"
		end
	end

	return false
end

local function awaitGate(gateName, timeout)
	if not _gates[gateName] then return end
	local elapsed = 0
	local step    = 0.05
	while elapsed < timeout do
		local ok, result = pcall(_gates[gateName])
		if ok and result then return true end
		task.wait(step)
		elapsed += step
	end
	return false
end

function Lifecycle.registerGate(name, fn)
	_gates[name] = fn
end

function Lifecycle.runPrecompile()
	for _, fn in _precompile do
		pcall(fn)
	end
end

function Lifecycle.runPostcompile()
	for _, fn in _postcompile do
		pcall(fn)
	end
end

function Lifecycle.runPhase(phase, records, ctxMap, middleware, config, registry)
	local timeout = config.Timeout or 30
	local strict  = config.Strict

	fireAll(_onPhaseStart[phase] or {})

	local total    = #records
	local complete = 0

	for _, record in records do
		local skip, reason = shouldSkip(record, config)
		if skip then
			record.status    = "skipped"
			record.skipReason = reason
			if registry then registry.recordSkipReason(record.name, reason) end
			if strict and not record.mod.NoBoot then
				warn("[ArTex] skipped " .. record.name .. " -- " .. reason)
			end
			complete += 1
			continue
		end

		if record.mod.Gate then
			local gateOk = awaitGate(record.mod.Gate, timeout)
			if not gateOk then
				record.status     = "skipped"
				record.skipReason = "gate '" .. record.mod.Gate .. "' timed out"
				if registry then registry.recordSkipReason(record.name, record.skipReason) end
				complete += 1
				continue
			end
		end

		local ctx    = ctxMap[record.name]
		local mod    = record.mod
		local fnName = phase:sub(1,1):upper() .. phase:sub(2)
		local fn     = mod[fnName]
		local t0     = os.clock()

		record.status = phase

		local mwCtx = {
			module  = record.name,
			phase   = phase,
			tier    = record.tier,
			context = record.context,
			time    = t0,
		}

		local maxRetry = record.mod.Retry or 0
		local attempts = 0
		local success  = false
		local lastErr  = nil

		repeat
			attempts += 1
			local ok, err

			if fn then
				ok, err = runWithTimeout(function()
					middleware.run(phase, mwCtx, function()
						if phase == "warmup" then
							fn()
						else
							fn(ctx)
						end
					end)
				end, record.mod.Timeout or timeout, record.name .. "." .. phase)
			else
				ok = true
			end

			if ok then
				success = true
			else
				lastErr = err
				if attempts <= maxRetry then
					task.wait(0.1 * attempts)
				end
			end
		until success or attempts > maxRetry

		local elapsed = (os.clock() - t0) * 1000
		record.timing = (record.timing or 0) + elapsed

		if success then
			if phase == "start" then
				record.status = "started"
				fireAll(_onModuleLoaded, record.name)
			end
		else
			record.status = "errored"

			local formatted = formatError(record, phase, lastErr)
			if registry then registry.recordError(record.name, phase, lastErr, formatted) end
			fireAll(_onError, record.name, phase, lastErr)

			if record.mod.Critical then
				error(formatted)
			elseif not record.mod.Optional then
				if strict then
					error(formatted)
				else
					warn(formatted)
				end
			end
		end

		complete += 1
		fireAll(_onProgress, complete / (total * 3))
	end

	fireAll(_onPhaseEnd[phase] or {})
end

function Lifecycle.runTier(tierRecords, ctxMap, middleware, config, registry)
	Lifecycle.runPhase("warmup", tierRecords, ctxMap, middleware, config, registry)
	Lifecycle.runPhase("init",   tierRecords, ctxMap, middleware, config, registry)
	Lifecycle.runPhase("start",  tierRecords, ctxMap, middleware, config, registry)
end

function Lifecycle.onError(fn)
	table.insert(_onError, fn)
end

function Lifecycle.onModuleLoaded(fn)
	table.insert(_onModuleLoaded, fn)
end

function Lifecycle.onPhaseStart(phase, fn)
	if not _onPhaseStart[phase] then _onPhaseStart[phase] = {} end
	table.insert(_onPhaseStart[phase], fn)
end

function Lifecycle.onPhaseEnd(phase, fn)
	if not _onPhaseEnd[phase] then _onPhaseEnd[phase] = {} end
	table.insert(_onPhaseEnd[phase], fn)
end

function Lifecycle.onProgress(fn)
	table.insert(_onProgress, fn)
end

function Lifecycle.precompile(fn)
	table.insert(_precompile, fn)
end

function Lifecycle.postcompile(fn)
	table.insert(_postcompile, fn)
end

function Lifecycle.reset()
	_onError        = {}
	_onModuleLoaded = {}
	_onPhaseStart   = {}
	_onPhaseEnd     = {}
	_onProgress     = {}
	_precompile     = {}
	_postcompile    = {}
	_gates          = {}
end

return Lifecycle