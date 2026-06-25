local Diagnostics = {}

local _trace      = {}
local _spans      = {}
local _events     = {}
local _startTime  = nil
local _bootTime   = nil
local _checkpoints = {}

local diagnostics = {
	bootTime     = 0,
	moduleCount  = 0,
	errorCount   = 0,
	skippedCount = 0,
	slowest      = "",
	fastest      = "",
	byTier       = {},
}

function Diagnostics.start()
	_startTime = os.clock()
end

function Diagnostics.finish(registry)
	_bootTime = (os.clock() - _startTime) * 1000
	diagnostics.bootTime = _bootTime

	local records = registry.all()
	diagnostics.moduleCount  = #records
	diagnostics.errorCount   = 0
	diagnostics.skippedCount = 0
	diagnostics.byTier       = {}

	local slowestTime = -1
	local fastestTime = math.huge

	for _, record in records do
		if record.status == "errored"  then diagnostics.errorCount   += 1 end
		if record.status == "skipped"  then diagnostics.skippedCount += 1 end

		local tier = record.tier
		if not diagnostics.byTier[tier] then
			diagnostics.byTier[tier] = { count = 0, totalTime = 0 }
		end
		diagnostics.byTier[tier].count     += 1
		diagnostics.byTier[tier].totalTime += record.timing

		if record.timing > slowestTime then
			slowestTime     = record.timing
			diagnostics.slowest = record.name
		end
		if record.timing < fastestTime and record.timing > 0 then
			fastestTime     = record.timing
			diagnostics.fastest = record.name
		end
	end
end

function Diagnostics.get()
	return diagnostics
end

function Diagnostics.report(registry)
	local records = registry.all()
	local result  = {}
	for _, record in records do
		result[record.name] = record.timing
	end
	return result
end

function Diagnostics.trace()
	return table.clone(_trace)
end

function Diagnostics.logEvent(moduleName, phase, duration)
	table.insert(_trace, {
		timestamp = os.clock(),
		module    = moduleName,
		phase     = phase,
		duration  = duration,
	})
end

function Diagnostics.emit(event, data)
	table.insert(_events, {
		timestamp = os.clock(),
		event     = event,
		data      = data,
	})
end

function Diagnostics.health(registry)
	local result = {}
	for _, record in registry.all() do
		result[record.name] = {
			status   = record.status,
			uptime   = _bootTime and (os.clock() * 1000 - _bootTime) or 0,
			restarts = 0,
		}
	end
	return result
end

function Diagnostics.inspect(registry, name)
	local record = registry.get(name)
	if not record then return nil end
	return {
		name     = record.name,
		tier     = record.tier,
		status   = record.status,
		timing   = record.timing,
		tags     = record.tags,
		alias    = record.alias,
		context  = record.context,
		version  = record.version,
		exports  = record.mod.Exports,
		schema   = record.mod.Schema,
	}
end

function Diagnostics.compare(registry, nameA, nameB)
	local a = Diagnostics.inspect(registry, nameA)
	local b = Diagnostics.inspect(registry, nameB)
	if not a or not b then return nil end
	local diff = {}
	local keys = {}
	for k in a do keys[k] = true end
	for k in b do keys[k] = true end
	for k in keys do
		if a[k] ~= b[k] then
			diff[k] = { [nameA] = a[k], [nameB] = b[k] }
		end
	end
	return diff
end

function Diagnostics.snapshot(registry, cache)
	return {
		time    = os.clock(),
		cache   = cache.snapshot(),
		modules = (function()
			local s = {}
			for _, r in registry.all() do
				s[r.name] = r.status
			end
			return s
		end)(),
	}
end

function Diagnostics.diff(snap1, snap2)
	local result = {}
	for key, v1 in snap1.cache do
		local v2 = snap2.cache[key]
		if v1 ~= v2 then
			if not result.cache then result.cache = {} end
			result.cache[key] = { before = v1, after = v2 }
		end
	end
	for name, s1 in snap1.modules do
		local s2 = snap2.modules[name]
		if s1 ~= s2 then
			if not result.modules then result.modules = {} end
			result.modules[name] = { before = s1, after = s2 }
		end
	end
	return result
end

function Diagnostics.span(name)
	_spans[name] = { start = os.clock() }
end

function Diagnostics.endSpan(name)
	local s = _spans[name]
	if s then
		s.duration = (os.clock() - s.start) * 1000
	end
end

function Diagnostics.getSpans()
	return _spans
end

function Diagnostics.checkpoint(name, registry, cache)
	_checkpoints[name] = Diagnostics.snapshot(registry, cache)
end

function Diagnostics.rollback(name)
	return _checkpoints[name]
end

function Diagnostics.printBoot(registry, verbosity)
	if verbosity ~= "trace" then return end

	local records  = registry.all()
	local byTier   = {}
	local tierOrder = {}

	for _, record in records do
		if not byTier[record.tier] then
			byTier[record.tier] = {}
			table.insert(tierOrder, record.tier)
		end
		table.insert(byTier[record.tier], record)
	end

	print(string.rep("─", 48))
	print(string.format("[ArTex] Boot complete in ~%.2fms", _bootTime or 0))
	print(string.rep("─", 48))

	for _, tier in tierOrder do
		print("[ArTex] -- " .. tier .. " " .. string.rep("─", 32 - #tier))
		for _, record in byTier[tier] do
			local icon = record.status == "started" and "✓"
				or record.status == "skipped" and "~"
				or "✗"
			print(string.format("[ArTex]   %-24s %-10s %.2fms  %s",
				record.name, record.status, record.timing, icon))
		end
	end

	print(string.rep("─", 48))
end

function Diagnostics.reset()
	_trace       = {}
	_spans       = {}
	_events      = {}
	_startTime   = nil
	_bootTime    = nil
	_checkpoints = {}
	diagnostics  = {
		bootTime     = 0,
		moduleCount  = 0,
		errorCount   = 0,
		skippedCount = 0,
		slowest      = "",
		fastest      = "",
		byTier       = {},
	}
end

return Diagnostics