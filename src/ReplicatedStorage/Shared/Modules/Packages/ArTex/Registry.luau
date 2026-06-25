local Registry = {}

local RunService = game:GetService("RunService")

local _modules         = {}
local _byAlias         = {}
local _byTag           = {}
local _priority        = {}
local _disabled        = {}
local _pinned          = {}
local _mocked          = {}
local _strict          = false
local _classResolver   = nil

local DEFAULT_TIER_ORDER = { "Shared", "Services", "Managers", "Controllers" }

function Registry.setStrict(v)
	_strict = v
end

function Registry.setPriorityMap(map)
	for tier, list in map do
		_priority[tier] = list
	end
end

function Registry.setClassResolver(fn)
	_classResolver = fn
end

local function scanFolder(folder, tierName, contextName)
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, mod = pcall(require, child)
			if not ok then
				warn("[ArTex] Registry: failed to require " .. child.Name .. ": " .. tostring(mod))
				continue
			end
			if type(mod) ~= "table" then continue end
			Registry.register(child.Name, mod, tierName, contextName, child)
		elseif child:IsA("Folder") then
			scanFolder(child, tierName, contextName)
		end
	end
end

function Registry.scan(contextStructure)
	for contextName, branch in contextStructure do
		if contextName == "Server" and not RunService:IsServer() then continue end
		if contextName == "Client" and not RunService:IsClient() then continue end

		local host = branch.Host
		if not host then continue end

		for _, tierName in branch.Structure do
			local tierFolder = host:FindFirstChild(tierName)
			if not tierFolder then continue end
			scanFolder(tierFolder, tierName, contextName)
		end
	end
end

function Registry.register(name, mod, tier, contextName, instance)
	if _modules[name] then return end

	local record = {
		name     = name,
		mod      = mod,
		tier     = tier,
		context  = mod.Context or contextName,
		status   = "pending",
		timing   = 0,
		tags     = mod.Tags or {},
		alias    = mod.Alias,
		version  = mod.Version,
		instance = instance,
	}

	_modules[name] = record

	if mod.Alias then
		_byAlias[mod.Alias] = name
	end

	for _, tag in (mod.Tags or {}) do
		if not _byTag[tag] then _byTag[tag] = {} end
		table.insert(_byTag[tag], name)
	end
end

function Registry.inject(name, mod, tier, contextName)
	Registry.register(name, mod, tier or "Shared", contextName or "Shared", nil)
end

function Registry.get(name)
	local record = _modules[name]
	if record then return record end
	local resolved = _byAlias[name]
	if resolved then return _modules[resolved] end
	return nil
end

function Registry.has(name)
	return _modules[name] ~= nil or _byAlias[name] ~= nil
end

function Registry.all()
	local result = {}
	for _, record in _modules do
		table.insert(result, record)
	end
	return result
end

function Registry.getTagged(tag)
	local names = _byTag[tag]
	if not names then return {} end
	local result = {}
	for _, name in names do
		local r = _modules[name]
		if r then table.insert(result, r) end
	end
	return result
end

function Registry.getTierOrder(override)
	if override then return override end
	local seen  = {}
	local order = {}
	for _, name in DEFAULT_TIER_ORDER do
		seen[name] = true
		table.insert(order, name)
	end
	for _, record in _modules do
		if not seen[record.tier] then
			seen[record.tier] = true
			table.insert(order, record.tier)
		end
	end
	return order
end

function Registry.getByTier(tierName)
	local result = {}
	for _, record in _modules do
		if record.tier ~= tierName then continue end
		if _disabled[record.name] then continue end
		local ctx = record.context
		if ctx == "Server" and not RunService:IsServer() then continue end
		if ctx == "Client" and not RunService:IsClient() then continue end
		table.insert(result, record)
	end

	local resolver = _classResolver

	table.sort(result, function(a, b)
		local cp_a = resolver and resolver(a) or 0
		local cp_b = resolver and resolver(b) or 0

		if cp_a ~= cp_b then
			return cp_a > cp_b
		end

		return Registry._prioritySort(a, b, tierName)
	end)

	return result
end

function Registry._prioritySort(a, b, tier)
	local map = _priority[tier]

	local function indexOf(name)
		if not map then return math.huge end
		for i, n in map do
			if n == name then return i end
		end
		return math.huge
	end

	local ai = a.mod.BootPriority or indexOf(a.name)
	local bi = b.mod.BootPriority or indexOf(b.name)

	if ai ~= bi then return ai < bi end
	return a.name < b.name
end

function Registry.setStatus(name, status)
	local record = _modules[name]
	if record then record.status = status end
end

function Registry.setTiming(name, ms)
	local record = _modules[name]
	if record then record.timing = ms end
end

function Registry.disable(name)
	if _pinned[name] then
		warn("[ArTex] Registry: cannot disable pinned module " .. name)
		return
	end
	_disabled[name] = true
end

function Registry.enable(name)
	_disabled[name] = nil
end

function Registry.pin(name)
	_pinned[name] = true
end

function Registry.unpin(name)
	_pinned[name] = nil
end

function Registry.mock(name, mockMod)
	if _pinned[name] then
		warn("[ArTex] Registry: cannot mock pinned module " .. name)
		return
	end
	local record = _modules[name]
	if record then
		_mocked[name] = record.mod
		record.mod    = mockMod
	end
end

function Registry.isMocked(name)
	return _mocked[name] ~= nil
end

function Registry.replace(name, mod)
	if _pinned[name] then
		warn("[ArTex] Registry: cannot replace pinned module " .. name)
		return
	end
	local record = _modules[name]
	if record then record.mod = mod end
end

function Registry.detectCycles()
	local cycles  = {}
	local visited = {}
	local stack   = {}

	local function dfs(name, path)
		if visited[name] then return end
		if stack[name] then
			local cycle = {}
			local found = false
			for _, n in path do
				if n == name then found = true end
				if found then table.insert(cycle, n) end
			end
			table.insert(cycle, name)
			table.insert(cycles, cycle)
			return
		end

		stack[name] = true
		table.insert(path, name)

		local record = _modules[name]
		if record then
			for _, dep in (record.mod.After or {}) do
				dfs(dep, path)
			end
		end

		table.remove(path)
		stack[name] = nil
		visited[name] = true
	end

	for name in _modules do
		dfs(name, {})
	end

	return cycles
end

function Registry.recordSkipReason(name, reason)
	local record = _modules[name]
	if record then record.skipReason = reason end
end

function Registry.recordError(name, phase, err, trace)
	local record = _modules[name]
	if record then
		record.errorPhase = phase
		record.errorMsg   = err
		record.errorTrace = trace
	end
end

function Registry.recordWaiting(name, waitingOn)
	local record = _modules[name]
	if record then record.waitingOn = waitingOn end
end

function Registry.find(predicate)
	for _, record in _modules do
		if predicate(record) then return record end
	end
	return nil
end

function Registry.filter(predicate)
	local result = {}
	for _, record in _modules do
		if predicate(record) then table.insert(result, record) end
	end
	return result
end

function Registry.reset()
	_modules       = {}
	_byAlias       = {}
	_byTag         = {}
	_priority      = {}
	_disabled      = {}
	_pinned        = {}
	_mocked        = {}
	_classResolver = nil
end

return Registry