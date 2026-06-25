local Context = {}

local RunService = game:GetService("RunService")

local _injections = {}
local _frozen     = false

local VERBOSITY_LEVELS = { trace = 1, info = 2, warn = 3, error = 4, silent = 5 }

local function shouldLog(globalVerbosity, moduleVerbosity, level)
	local effective = moduleVerbosity or globalVerbosity or "warn"
	local threshold = VERBOSITY_LEVELS[effective] or 3
	local current   = VERBOSITY_LEVELS[level] or 1
	return current >= threshold
end

local function makeLogger(moduleName, globalVerbosity, moduleVerbosity)
	local prefix = "[ArTex:" .. moduleName .. "] "
	return {
		trace = function(msg)
			if shouldLog(globalVerbosity, moduleVerbosity, "trace") then
				print(prefix .. msg)
			end
		end,
		info = function(msg)
			if shouldLog(globalVerbosity, moduleVerbosity, "info") then
				print(prefix .. msg)
			end
		end,
		warn = function(msg)
			if shouldLog(globalVerbosity, moduleVerbosity, "warn") then
				warn(prefix .. msg)
			end
		end,
		error = function(msg)
			if shouldLog(globalVerbosity, moduleVerbosity, "error") then
				warn(prefix .. "ERROR: " .. msg)
			end
		end,
	}
end

function Context.inject(contextName, namespace, name, value)
	if _frozen then
		warn("[ArTex] Context.inject called after ctx was frozen -- " .. name .. " ignored")
		return
	end
	table.insert(_injections, {
		context   = contextName,
		namespace = namespace,
		name      = name,
		value     = value,
	})
end

function Context.build(record, artext, cache, config)
	local currentContext = RunService:IsServer() and "Server" or "Client"

	local ctx = {
		ArTex             = artext,
		Cache             = cache,
		Context           = currentContext,
		Net               = RunService:IsServer() and config.NetworkManager or config.NetworkController,
		Module            = record.mod,
		Name              = record.name,
		Tier              = record.tier,
		Version           = artext.version,
		Manifest          = config.Manifest,
		NetworkManager    = config.NetworkManager,
		NetworkController = config.NetworkController,
		Log               = makeLogger(record.name, config.Verbosity, record.mod.Verbosity),
		Server            = RunService:IsServer() and {
			PlaceId      = game.PlaceId,
			JobId        = game.JobId,
			PlayerCount  = #game:GetService("Players"):GetPlayers(),
		} or nil,
		Player = RunService:IsClient() and game:GetService("Players").LocalPlayer or nil,
	}

	ctx.Env = ctx

	ctx.use = function(path)
		local parts = path:split(".")
		local current = ctx
		for _, part in parts do
			if type(current) ~= "table" then
				error("[ArTex] ctx.use('" .. path .. "'): could not resolve '" .. part .. "'")
			end
			current = current[part]
		end
		if current == nil then
			error("[ArTex] ctx.use('" .. path .. "'): resolved to nil")
		end
		return current
	end

	for _, injection in _injections do
		local forServer = injection.context == "Server"
		local forClient = injection.context == "Client"
		local forShared = injection.context == "Shared" or injection.context == nil

		local relevant = forShared
			or (forServer and RunService:IsServer())
			or (forClient and RunService:IsClient())

		if not relevant then continue end

		if injection.namespace then
			if not ctx[injection.namespace] then
				ctx[injection.namespace] = {}
			end
			ctx[injection.namespace][injection.name] = injection.value
		else
			ctx[injection.name] = injection.value
		end
	end

	return ctx
end

local TIER_SINGULAR = {
	Services    = "Service",
	Managers    = "Manager",
	Controllers = "Controller",
	Packages    = "Package",
	Utility     = "Utility",
}

local function makeGetter(ctx, tier)
	return function(name)
		local ns = ctx[tier]
		if not ns then
			error("[ArTex] Get" .. (TIER_SINGULAR[tier] or tier) .. ": namespace '" .. tier .. "' does not exist")
		end
		local mod = ns[name]
		if not mod then
			error("[ArTex] Get" .. (TIER_SINGULAR[tier] or tier) .. ": '" .. name .. "' not found in " .. tier)
		end
		return mod
	end
end

function Context.applyStructure(ctx, registry)
	local records = registry.all()
	for _, record in records do
		if not ctx[record.tier] then
			ctx[record.tier] = {}
		end
		ctx[record.tier][record.name] = record.mod
	end

	local tiers = {}
	for _, record in records do
		tiers[record.tier] = true
	end

	for tier in tiers do
		local singular = TIER_SINGULAR[tier] or tier
		ctx["Get" .. singular] = makeGetter(ctx, tier)
	end
end

function Context.wireClientProxies(registry, schema, ctxMap)
	if not RunService:IsServer() then return end
	if not schema then return end

	local T = schema.Type

	for _, record in registry.all() do
		local clientTable = record.mod.Client
		if type(clientTable) ~= "table" then continue end

		for methodName, entry in clientTable do
			local handler
			local rate, per

			if type(entry) == "function" then
				handler = entry
			elseif type(entry) == "table" then
				handler = entry.handler
				rate    = entry.rate
				per     = entry.per
			else
				continue
			end

			if not handler then continue end

			local channelName = record.name .. "." .. methodName

			schema.define(channelName, {
				args = T.table(true),
			}, { mode = "invoke" })

			local playerCallTimes = {}

			schema.subscribe(channelName, function(player, data)
				if rate and per then
					local userId = player.UserId
					local now    = os.time()

					if not playerCallTimes[userId] then
						playerCallTimes[userId] = {}
					end

					local times = playerCallTimes[userId]
					local windowStart = now - per

					local filtered = {}
					for _, t in times do
						if t > windowStart then
							table.insert(filtered, t)
						end
					end
					playerCallTimes[userId] = filtered

					if #filtered >= rate then
						if data.remit then
							data.remit({ __rateLimit = true, error = "Rate limit exceeded" })
						end
						return
					end

					table.insert(playerCallTimes[userId], now)
				end

				local args     = data.args or {}
				local response = handler(record.mod, player, table.unpack(args))
				if data.remit then data.remit(response) end
			end)
		end
	end
end

function Context.buildClientProxies(registry, schema, ctxMap)
	if not RunService:IsClient() then return end
	if not schema then return end

	local proxies = {}

	for _, record in registry.all() do
		local clientTable = record.mod.Client
		if type(clientTable) ~= "table" then continue end

		local proxy = {}

		for methodName in clientTable do
			local channelName = record.name .. "." .. methodName

			schema.define(channelName, {
				args = schema.Type.table(true),
			}, { mode = "invoke" })

			proxy[methodName] = function(...)
				local args = { ... }
				return schema.post(channelName, { args = args })
			end
		end

		proxies[record.name] = proxy
	end

	for name, proxy in proxies do
		for _, record in registry.all() do
			local ctx = ctxMap[record.name]
			if not ctx then continue end
			local tier = registry.get(name) and registry.get(name).tier
			if tier and ctx[tier] then
				ctx[tier][name] = proxy
			end
		end
	end
end

function Context.freeze()
	_frozen = true
end

function Context.reset()
	_injections = {}
	_frozen     = false
end

return Context