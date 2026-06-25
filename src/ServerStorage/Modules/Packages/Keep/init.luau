local Players = game:GetService("Players")

local ProfileStore = require(script.ProfileStore)
local Promise     = require(script.Promise)
local Signal      = require(script.Signal)
local Live        = require(script.Live)
local Utility     = require(script.Utility)

local Keep = {}

local _config = {
	StorageType         = "Single",
	StudioSeparate      = false,
	AutoSave            = true,
	AutoSaveInterval    = 60,
	SessionLockRetries  = 5,
	SessionLockInterval = 15,
	LogLevel            = "Warn",
	Reconcile           = true,
	Migration           = nil,
	Version             = 1,
}

local _schemas      = {}
local _stores       = {}
local _channelCache = {}

local OnSessionStart = Signal.new()
local OnSessionEnd   = Signal.new()
local OnSaveComplete = Signal.new()

local function _log(level, ...)
	if _config.LogLevel == "None" then return end
	if level == "Verbose" and _config.LogLevel ~= "Verbose" then return end
	if level == "Warn" then
		warn("[Keep]", ...)
	else
		print("[Keep]", ...)
	end
end

local function _getStoreName(schemaName)
	local base = schemaName or "Default"
	if _config.StudioSeparate and Utility.IsStudio() then
		return "Studio_" .. base
	end
	return base
end

local function _resolveUserId(plrOrId)
	return Utility.ResolveUserId(plrOrId)
end

local function _buildSessionHandle(userId, schemaName)
	local schema  = _schemas[schemaName] or _schemas["Default"]
	local profile = Live.GetProfile(userId, schemaName)

	if not profile then
		_log("Warn", "No profile found for", userId, schemaName)
		return nil
	end

	local handle   = {}
	local _signals = {}

	local _proxy = setmetatable({}, {
		__index = function(_, key)
			if handle[key] ~= nil then
				return handle[key]
			end
			return profile.Data[key]
		end,
		__newindex = function(_, key, value)
			profile.Data[key] = value
		end,
	})

	function handle:Get(path)
		return Utility.GetPath(profile.Data, path)
	end

	function handle:GetAll()
		return Utility.DeepCopy(profile.Data)
	end

	function handle:Patch(tbl)
		for key, value in pairs(tbl) do
			local old = profile.Data[key]
			profile.Data[key] = value
			if _signals[key] then
				_signals[key]:Fire(value, old)
			end
		end
		if _signals["*"] then
			_signals["*"]:Fire(Utility.DeepCopy(profile.Data))
		end
		_log("Verbose", "Patch applied for", userId, schemaName)
	end

	function handle:DeepPatch(tbl)
		Utility.DeepMerge(profile.Data, tbl)
		if _signals["*"] then
			_signals["*"]:Fire(Utility.DeepCopy(profile.Data))
		end
		_log("Verbose", "DeepPatch applied for", userId, schemaName)
	end

	function handle:Set(path, value)
		local old = Utility.GetPath(profile.Data, path)
		Utility.SetPath(profile.Data, path, value)
		local topKey = path:match("^([^.]+)")
		if topKey and _signals[topKey] then
			_signals[topKey]:Fire(Utility.GetPath(profile.Data, topKey), old)
		end
		if _signals["*"] then
			_signals["*"]:Fire(Utility.DeepCopy(profile.Data))
		end
	end

	function handle:Increment(path, amount)
		local current = Utility.GetPath(profile.Data, path)
		assert(type(current) == "number", "[Keep] Increment target must be a number -- path: " .. path)
		self:Set(path, current + (amount or 1))
	end

	function handle:Append(path, value)
		local tbl = Utility.GetPath(profile.Data, path)
		assert(type(tbl) == "table", "[Keep] Append target must be a table -- path: " .. path)
		table.insert(tbl, value)
		if _signals["*"] then
			_signals["*"]:Fire(Utility.DeepCopy(profile.Data))
		end
	end

	function handle:Remove(path, index)
		local tbl = Utility.GetPath(profile.Data, path)
		assert(type(tbl) == "table", "[Keep] Remove target must be a table -- path: " .. path)
		if index then
			table.remove(tbl, index)
		else
			table.remove(tbl)
		end
		if _signals["*"] then
			_signals["*"]:Fire(Utility.DeepCopy(profile.Data))
		end
	end

	function handle:Observe(path, fn)
		if not _signals[path] then
			_signals[path] = Signal.new()
		end
		return _signals[path]:Connect(fn)
	end

	function handle:ObserveAll(fn)
		if not _signals["*"] then
			_signals["*"] = Signal.new()
		end
		return _signals["*"]:Connect(fn)
	end

	function handle:Save()
		return Promise.new(function(resolve, reject)
			local ok, err = pcall(function()
				profile:Save()
			end)
			if ok then
				Live.BumpSaveCount(userId, schemaName)
				Live.SetLastSave(userId, schemaName, os.time())
				OnSaveComplete:Fire(Live.GetOwner(userId))
				_log("Verbose", "Saved profile for", userId, schemaName)
				resolve()
			else
				_log("Warn", "Save failed for", userId, schemaName, err)
				reject(err)
			end
		end)
	end

	function handle:Snapshot()
		return Utility.DeepCopy(profile.Data)
	end

	function handle:Reconcile()
		if not schema then return end
		Utility.Reconcile(profile.Data, schema)
		_log("Verbose", "Reconciled profile for", userId, schemaName)
	end

	function handle:Release()
		return Promise.new(function(resolve, reject)
			local ok, err = pcall(function()
				profile:EndSession()
			end)
			if ok then
				Live.RemoveSession(userId, schemaName)
				_signals = {}
				_log("Verbose", "Released profile for", userId, schemaName)
				resolve(Live.GetOwner(userId))
			else
				_log("Warn", "Release failed for", userId, schemaName, err)
				reject(err)
			end
		end)
	end

	function handle:IsActive()
		return profile:IsActive()
	end

	function handle:GetOwner()
		return Live.GetOwner(userId)
	end

	function handle:GetVersion()
		return profile.MetaData.MetaTags and profile.MetaData.MetaTags.Version or _config.Version
	end

	function handle:GetSaveCount()
		return Live.GetSaveCount(userId, schemaName)
	end

	function handle:GetLastSave()
		return Live.GetLastSave(userId, schemaName)
	end

	return _proxy
end

local function _makeChannel(schemaName)
	return function(plrOrId)
		local userId = _resolveUserId(plrOrId)
		if not userId then
			_log("Warn", "Could not resolve userId from", tostring(plrOrId))
			return nil
		end

		local cacheKey = userId .. "_" .. schemaName
		if _channelCache[cacheKey] then
			return _channelCache[cacheKey]
		end

		local handle = _buildSessionHandle(userId, schemaName)
		if handle then
			_channelCache[cacheKey] = handle
		end
		return handle
	end
end

function Keep.Configure(config)
	for key, value in pairs(config) do
		_config[key] = value
	end
	_log("Verbose", "Keep configured")
end

function Keep.SetSchema(nameOrSchema, schema)
	if type(nameOrSchema) == "table" then
		_schemas["Default"] = nameOrSchema
		if not Keep.Account then
			Keep.Account = _makeChannel("Default")
		end
		_log("Verbose", "Default schema set")
	elseif type(nameOrSchema) == "string" then
		assert(type(schema) == "table", "[Keep] SetSchema requires a table as second argument")
		_schemas[nameOrSchema] = schema
		Keep[nameOrSchema]     = _makeChannel(nameOrSchema)
		_log("Verbose", "Schema set for", nameOrSchema)
	end
end

function Keep.StartPlayerSession(plrOrId, overrides)
	local userId = _resolveUserId(plrOrId)
	local player = Utility.ResolvePlayer(plrOrId)

	if not userId then
		return Promise.reject("[Keep] Could not resolve userId")
	end

	if Live.IsSessionActive(userId) then
		_log("Verbose", "Session already active for", userId)
		local owner = Live.GetOwner(userId)
		return Promise.new(function(resolve)
			local stores = {}
			for schemaName in pairs(_schemas) do
				stores[schemaName] = _buildSessionHandle(userId, schemaName)
			end
			resolve(stores, owner)
		end)
	end

	Live.SetPending(userId, true)

	return Promise.new(function(resolve, reject)
		local schemaNames = {}
		for name in pairs(_schemas) do
			table.insert(schemaNames, name)
		end

		if #schemaNames == 0 then
			Live.SetPending(userId, false)
			reject("[Keep] No schemas defined -- call Keep.SetSchema first")
			return
		end

		local owner = {
			Player     = player,
			UserId     = userId,
			SessionId  = Utility.GenerateSessionId(userId),
			StartTime  = os.time(),
			StoreNames = schemaNames,
		}

		local loaded = {}
		local failed = false

		for _, schemaName in ipairs(schemaNames) do
			if failed then break end

			local storeName = _getStoreName(schemaName)

			if not _stores[storeName] then
				local defaults = Utility.DeepCopy(_schemas[schemaName])
				if overrides then
					Utility.DeepMerge(defaults, overrides)
				end
				_stores[storeName] = ProfileStore.New(storeName, defaults)
			end

			local profile = _stores[storeName]:StartSessionAsync("Player_" .. userId, {
				Cancel = function()
					if not player then return false end
					return not player:IsDescendantOf(Players)
				end,
			})

			if not profile then
				failed = true
				Live.SetPending(userId, false)
				_log("Warn", "Failed to load profile for", userId, storeName)
				reject("[Keep] ProfileStore failed to load -- userId: " .. userId)
				break
			end

			profile:AddUserId(userId)
			profile:Reconcile()

			if _config.Migration and type(_config.Migration) == "function" then
				local currentVersion = profile.MetaData.MetaTags and profile.MetaData.MetaTags.Version or 0
				if currentVersion < _config.Version then
					profile.Data = _config.Migration(profile.Data, currentVersion) or profile.Data
					if profile.MetaData.MetaTags then
						profile.MetaData.MetaTags.Version = _config.Version
					end
				end
			end

			Live.RegisterProfile(userId, schemaName, profile)
			loaded[schemaName] = _buildSessionHandle(userId, schemaName)

			local cacheKey = userId .. "_" .. schemaName
			_channelCache[cacheKey] = loaded[schemaName]
		end

		if not failed then
			Live.RegisterOwner(userId, owner)
			Live.SetPending(userId, false)
			Live.ResolvePendingPromises(userId, loaded, owner)

			if _config.AutoSave then
				Live.StartAutoSave(userId, _config.AutoSaveInterval, function()
					for schemaName in pairs(_schemas) do
						local profile = Live.GetProfile(userId, schemaName)
						if profile and profile:IsActive() then
							profile:Save()
							Live.BumpSaveCount(userId, schemaName)
							Live.SetLastSave(userId, schemaName, os.time())
							OnSaveComplete:Fire(owner)
						end
					end
				end)
			end

			OnSessionStart:Fire(loaded, owner)
			_log("Verbose", "Session started for", userId)
			resolve(loaded, owner)
		end
	end)
end

function Keep.AwaitSession(plrOrId)
	local userId = _resolveUserId(plrOrId)

	if not userId then
		return Promise.reject("[Keep] Could not resolve userId")
	end

	if Live.IsSessionActive(userId) then
		local owner = Live.GetOwner(userId)
		return Promise.new(function(resolve)
			local stores = {}
			for schemaName in pairs(_schemas) do
				stores[schemaName] = _buildSessionHandle(userId, schemaName)
			end
			resolve(stores, owner)
		end)
	end

	return Live.QueuePendingPromise(userId)
end

function Keep.EndPlayerSession(plrOrId)
	local userId = _resolveUserId(plrOrId)

	if not userId then
		return Promise.reject("[Keep] Could not resolve userId")
	end

	return Promise.new(function(resolve, reject)
		if not Live.IsSessionActive(userId) then
			_log("Warn", "No active session for", userId)
			reject("[Keep] No active session -- userId: " .. userId)
			return
		end

		local owner = Live.GetOwner(userId)
		local ok    = true

		for schemaName in pairs(_schemas) do
			local profile = Live.GetProfile(userId, schemaName)
			if profile and profile:IsActive() then
				local s, err = pcall(function()
					profile:EndSession()
				end)
				if not s then
					_log("Warn", "Release error for", userId, schemaName, err)
					ok = false
				end
			end
			local cacheKey = userId .. "_" .. schemaName
			_channelCache[cacheKey] = nil
		end

		Live.StopAutoSave(userId)
		Live.RemoveOwner(userId)
		Live.ClearSessions(userId)

		OnSessionEnd:Fire(owner)
		_log("Verbose", "Session ended for", userId)

		if ok then
			resolve(owner)
		else
			reject("[Keep] Some profiles failed to release -- userId: " .. userId)
		end
	end)
end

function Keep.EndAllSessions()
	return Promise.new(function(resolve)
		local userIds = Live.GetAllUserIds()
		local pending = #userIds
		if pending == 0 then
			resolve()
			return
		end
		for _, userId in ipairs(userIds) do
			Keep.EndPlayerSession(userId):concluded(function()
				pending -= 1
				if pending == 0 then
					resolve()
				end
			end)
		end
	end)
end

function Keep.IsSessionActive(plrOrId)
	local userId = _resolveUserId(plrOrId)
	if not userId then return false end
	return Live.IsSessionActive(userId)
end

function Keep.GetOwner(plrOrId)
	local userId = _resolveUserId(plrOrId)
	if not userId then return nil end
	return Live.GetOwner(userId)
end

function Keep.GetAllOwners()
	return Live.GetAllOwners()
end

function Keep.WaitForSession(plrOrId)
	local userId = _resolveUserId(plrOrId)
	if not userId then return nil, nil end

	while not Live.IsSessionActive(userId) do
		task.wait(0.1)
	end

	local owner  = Live.GetOwner(userId)
	local stores = {}
	for schemaName in pairs(_schemas) do
		stores[schemaName] = _buildSessionHandle(userId, schemaName)
	end
	return stores, owner
end

function Keep.ResolveUserId(plrOrId)
	return _resolveUserId(plrOrId)
end

function Keep.OnSessionStart(fn)
	return OnSessionStart:Connect(fn)
end

function Keep.OnSessionEnd(fn)
	return OnSessionEnd:Connect(fn)
end

function Keep.OnSaveComplete(fn)
	return OnSaveComplete:Connect(fn)
end

Keep.Debug = {}

function Keep.Debug.GetAllSessions()
	return Live.GetAllSessions()
end

function Keep.Debug.GetSession(plrOrId)
	local userId = _resolveUserId(plrOrId)
	if not userId then return nil end
	return Live.GetAllSessionsForUser(userId)
end

function Keep.Debug.GetLiveCount()
	return Live.GetLiveCount()
end

function Keep.Debug.PrintSession(plrOrId)
	local userId = _resolveUserId(plrOrId)
	if not userId then
		warn("[Keep.Debug] Could not resolve userId")
		return
	end

	local owner = Live.GetOwner(userId)
	if not owner then
		warn("[Keep.Debug] No session for userId:", userId)
		return
	end

	print("[Keep.Debug] Session --", userId)
	print("  SessionId:", owner.SessionId)
	print("  StartTime:", owner.StartTime)
	print("  Stores:", table.concat(owner.StoreNames, ", "))

	for _, schemaName in ipairs(owner.StoreNames) do
		local profile = Live.GetProfile(userId, schemaName)
		if profile then
			print("  [" .. schemaName .. "] SaveCount:", Live.GetSaveCount(userId, schemaName))
			print("  [" .. schemaName .. "] LastSave:", Live.GetLastSave(userId, schemaName))
			print("  [" .. schemaName .. "] Data:", profile.Data)
		end
	end
end

function Keep.Debug.SimulateRelease(plrOrId)
	local userId = _resolveUserId(plrOrId)
	if not userId then
		warn("[Keep.Debug] Could not resolve userId")
		return
	end
	_log("Warn", "Debug SimulateRelease called for", userId)
	Keep.EndPlayerSession(userId):catch(function() end)
end

function Keep.Debug.ForceExpire(plrOrId)
	local userId = _resolveUserId(plrOrId)
	if not userId then
		warn("[Keep.Debug] Could not resolve userId")
		return
	end

	for schemaName in pairs(_schemas) do
		local profile = Live.GetProfile(userId, schemaName)
		if profile then
			_log("Warn", "Debug ForceExpire -- invalidating profile for", userId, schemaName)
			pcall(function() profile:EndSession() end)
		end
	end

	Live.ClearSessions(userId)
	Live.RemoveOwner(userId)
	Live.StopAutoSave(userId)

	for schemaName in pairs(_schemas) do
		local cacheKey = userId .. "_" .. schemaName
		_channelCache[cacheKey] = nil
	end

	_log("Warn", "Debug ForceExpire complete for", userId)
end

function Keep.Debug.DumpLive()
	print("[Keep.Debug] DumpLive --")
	print("  Live count:", Live.GetLiveCount())
	for _, userId in ipairs(Live.GetAllUserIds()) do
		Keep.Debug.PrintSession(userId)
	end
end

function Keep.Debug.GetConfig()
	return Utility.DeepCopy(_config)
end

function Keep.Debug.GetSchemas()
	return Utility.DeepCopy(_schemas)
end

function Keep.Debug.GetStoreNames()
	local names = {}
	for name in pairs(_stores) do
		table.insert(names, name)
	end
	return names
end

game.Players.PlayerRemoving:Connect(function(player)
	if Live.IsSessionActive(player.UserId) then
		_log("Verbose", "Auto-releasing session on PlayerRemoving for", player.UserId)
		Keep.EndPlayerSession(player):catch(function() end)  -- FIX: colon
	end
end)

game:BindToClose(function()
	_log("Verbose", "BindToClose -- ending all sessions")
	Keep.EndAllSessions()
end)

return Keep