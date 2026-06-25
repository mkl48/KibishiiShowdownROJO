local Live = {}

local _sessions = {}
local _profiles = {}
local _owners = {}
local _pending = {}
local _pendingQueues = {}
local _saveCounts = {}
local _lastSaves = {}
local _autosaveConnections = {}

function Live.RegisterProfile(userId, schemaName, profile)
	if not _profiles[userId] then
		_profiles[userId] = {}
	end
	_profiles[userId][schemaName] = profile

	if not _sessions[userId] then
		_sessions[userId] = {}
	end
	_sessions[userId][schemaName] = true

	if not _saveCounts[userId] then
		_saveCounts[userId] = {}
	end
	_saveCounts[userId][schemaName] = 0

	if not _lastSaves[userId] then
		_lastSaves[userId] = {}
	end
	_lastSaves[userId][schemaName] = 0
end

function Live.RegisterOwner(userId, owner)
	_owners[userId] = owner
end

function Live.GetProfile(userId, schemaName)
	if not _profiles[userId] then return nil end
	return _profiles[userId][schemaName]
end

function Live.GetOwner(userId)
	return _owners[userId]
end

function Live.GetAllOwners()
	local result = {}
	for userId, owner in pairs(_owners) do
		result[userId] = owner
	end
	return result
end

function Live.IsSessionActive(userId)
	return _sessions[userId] ~= nil and next(_sessions[userId]) ~= nil
end

function Live.RemoveSession(userId, schemaName)
	if not _sessions[userId] then return end
	_sessions[userId][schemaName] = nil
	if not next(_sessions[userId]) then
		_sessions[userId] = nil
	end

	if _profiles[userId] then
		_profiles[userId][schemaName] = nil
		if not next(_profiles[userId]) then
			_profiles[userId] = nil
		end
	end
end

function Live.ClearSessions(userId)
	_sessions[userId] = nil
	_profiles[userId] = nil
	_saveCounts[userId] = nil
	_lastSaves[userId] = nil
end

function Live.RemoveOwner(userId)
	_owners[userId] = nil
end

function Live.SetPending(userId, state)
	_pending[userId] = state
end

function Live.IsPending(userId)
	return _pending[userId] == true
end

function Live.QueuePendingPromise(userId)
	local Promise = require(script.Parent.Promise)

	if not _pendingQueues[userId] then
		_pendingQueues[userId] = {}
	end

	return Promise.new(function(resolve)
		table.insert(_pendingQueues[userId], resolve)
	end)
end

function Live.ResolvePendingPromises(userId, stores, owner)
	local queue = _pendingQueues[userId]
	if not queue then return end

	for _, resolve in ipairs(queue) do
		resolve(stores, owner)
	end

	_pendingQueues[userId] = nil
end

function Live.BumpSaveCount(userId, schemaName)
	if not _saveCounts[userId] then
		_saveCounts[userId] = {}
	end
	_saveCounts[userId][schemaName] = (_saveCounts[userId][schemaName] or 0) + 1
end

function Live.GetSaveCount(userId, schemaName)
	if not _saveCounts[userId] then return 0 end
	return _saveCounts[userId][schemaName] or 0
end

function Live.SetLastSave(userId, schemaName, timestamp)
	if not _lastSaves[userId] then
		_lastSaves[userId] = {}
	end
	_lastSaves[userId][schemaName] = timestamp
end

function Live.GetLastSave(userId, schemaName)
	if not _lastSaves[userId] then return 0 end
	return _lastSaves[userId][schemaName] or 0
end

function Live.StartAutoSave(userId, interval, callback)
	if _autosaveConnections[userId] then
		_autosaveConnections[userId]:Disconnect()
	end

	local elapsed = 0
	_autosaveConnections[userId] = game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			callback()
		end
	end)
end

function Live.StopAutoSave(userId)
	if _autosaveConnections[userId] then
		_autosaveConnections[userId]:Disconnect()
		_autosaveConnections[userId] = nil
	end
end

function Live.GetAllUserIds()
	local ids = {}
	for userId in pairs(_owners) do
		table.insert(ids, userId)
	end
	return ids
end

function Live.GetLiveCount()
	local count = 0
	for _ in pairs(_owners) do
		count += 1
	end
	return count
end

function Live.GetAllSessions()
	local result = {}
	for userId, schemas in pairs(_sessions) do
		result[userId] = {}
		for schemaName in pairs(schemas) do
			result[userId][schemaName] = {
				SaveCount = Live.GetSaveCount(userId, schemaName),
				LastSave = Live.GetLastSave(userId, schemaName),
				Owner = _owners[userId],
			}
		end
	end
	return result
end

function Live.GetAllSessionsForUser(userId)
	if not _sessions[userId] then return nil end

	local result = {}
	for schemaName in pairs(_sessions[userId]) do
		result[schemaName] = {
			SaveCount = Live.GetSaveCount(userId, schemaName),
			LastSave = Live.GetLastSave(userId, schemaName),
			Profile = _profiles[userId] and _profiles[userId][schemaName] or nil,
		}
	end
	return result
end

return Live