local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal  = require(script.GoodSignal)
local Promise = require(script.Promise)

local IS_SERVER = RunService:IsServer()

type MiddlewareFn = (value: any, old: any) -> any
type FilterFn     = (id: any, data: { [string]: any }) -> boolean

type SaveConfig = {
	interval : number?,
	onLeave  : boolean?,
}

type Config = {
	schema     : { [string]: any },
	replicate  : { [string]: "owner" | "all" }?,
	visibility : ("public" | "private")?,
	middleware : { [string]: MiddlewareFn }?,
	standalone : boolean?,
	save       : SaveConfig?,
	onLoad     : ((player: Player) -> any)?,
	onSave     : ((player: Player, dirty: { [string]: any }) -> any)?,
}

type Entry = {
	data      : { [string]: any },
	defaults  : { [string]: any },
	dirty     : { [string]: any },
	locked    : boolean,
	hidden    : boolean,
	snapshots : { [string]: { [string]: any } },
	_onChange : any,
	_onFlush  : any,
	_watches  : { [string]: { any } },
}

local function deepCopy(t: { [string]: any }): { [string]: any }
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local Cache  = {}
Cache.__index = Cache

function Cache:_entry(id: any): Entry?
	return self._entries[id]
end

function Cache:_create(id: any, data: { [string]: any }): Entry
	local entry: Entry = {
		data      = deepCopy(data),
		defaults  = deepCopy(data),
		dirty     = {},
		locked    = false,
		hidden    = self._config.visibility == "private",
		snapshots = {},
		_onChange = Signal.new(),
		_onFlush  = Signal.new(),
		_watches  = {},
	}
	self._entries[id]   = entry
	self._snapshots[id] = entry.snapshots
	return entry
end

function Cache:_middleware(key: string, value: any, old: any): any
	local mw = self._config.middleware
	return mw and mw[key] and mw[key](value, old) or value
end

function Cache:_write(id: any, key: string, value: any)
	local entry = self:_entry(id)
	if not entry then return end

	if entry.locked then
		warn(`[Plinko] "{self._name}" is locked for {tostring(id)}`)
		return
	end

	local schema  = self._config.schema
	local default = schema[key]
	if default ~= nil and value ~= nil and type(value) ~= type(default) then
		warn(`[Plinko] type mismatch on "{key}": expected {type(default)}, got {type(value)}`)
	end

	local old    = entry.data[key]
	local cooked = self:_middleware(key, value, old)

	entry.data[key]  = cooked
	entry.dirty[key] = cooked

	entry._onChange:Fire(key, cooked, old)

	local watches = entry._watches[key]
	if watches then
		for _, fn in ipairs(watches) do
			task.spawn(fn, cooked, old)
		end
	end

	if IS_SERVER and self._remote then
		local scope = self._config.replicate and self._config.replicate[key]
		if scope then
			self:_replicate(id, key, cooked, scope)
		end
	end
end

function Cache:_replicate(id: any, key: string, value: any, scope: "owner" | "all")
	if not self._remote then return end

	if scope == "owner" and typeof(id) == "Instance" and id:IsA("Player") then
		self._remote:FireClient(id, { k = key, v = value })
	elseif scope == "all" then
		for _, player in ipairs(Players:GetPlayers()) do
			local e = self:_entry(player)
			if e and not e.hidden then
				self._remote:FireClient(player, { k = key, v = value, o = id })
			end
		end
	end
end

function Cache:_bootstrap(player: Player)
	if not self._remote then return end
	local entry     = self:_entry(player)
	local replicate = self._config.replicate
	if not entry or not replicate then return end

	for key, scope in pairs(replicate) do
		local value = entry.data[key]
		if scope == "owner" then
			self._remote:FireClient(player, { k = key, v = value })
		elseif scope == "all" and not entry.hidden then
			for _, other in ipairs(Players:GetPlayers()) do
				self._remote:FireClient(other, { k = key, v = value, o = player })
			end
		end
	end
end

function Cache:_hookPlayers()
	Players.PlayerAdded:Connect(function(player)
		local onLoad = self._config.onLoad
		if not onLoad then return end

		Promise.resolve():andThen(function()
			return onLoad(player)
		end):andThen(function(data)
			local merged = deepCopy(self._config.schema)
			if data then
				for k, v in pairs(data) do merged[k] = v end
			end
			local entry = self:_create(player, merged)
			self.onAdded:Fire(player, entry.data)
			self:_bootstrap(player)
		end):catch(function(err)
			self.onError:Fire(player, err)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = self:_entry(player)
		if not entry then return end

		local shouldSave = not (self._config.save and self._config.save.onLeave == false)
		if shouldSave then
			self:lock(player)
			self:flush(player):andThen(function()
				self:_release(player)
			end):catch(function(err)
				self.onError:Fire(player, err)
				self:_release(player)
			end)
		else
			self:_release(player)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		local onLoad = self._config.onLoad
		if not onLoad then continue end

		Promise.resolve():andThen(function()
			return onLoad(player)
		end):andThen(function(data)
			local merged = deepCopy(self._config.schema)
			if data then
				for k, v in pairs(data) do merged[k] = v end
			end
			local entry = self:_create(player, merged)
			self.onAdded:Fire(player, entry.data)
			self:_bootstrap(player)
		end):catch(function(err)
			self.onError:Fire(player, err)
		end)
	end
end

function Cache:_startTimer()
	local interval = self._config.save and self._config.save.interval
	if not interval or interval <= 0 then return end

	task.spawn(function()
		while self._entries do
			task.wait(interval)
			self:flushAll():catch(function(err)
				self.onError:Fire(nil, err)
			end)
		end
	end)
end

function Cache:_release(id: any)
	local entry = self:_entry(id)
	if not entry then return end
	self.onRemoving:Fire(id, entry.data)
	self._entries[id]   = nil
	self._snapshots[id] = nil
end

-- Public API

function Cache:get(keyOrPlayer: any, key: string?): any
	if not IS_SERVER and not self._standalone then
		local localPlayer = Players.LocalPlayer
		if key == nil then
			local entry = self:_entry(localPlayer)
			return entry and entry.data[keyOrPlayer] or nil
		end
		local entry = self:_entry(keyOrPlayer)
		if not entry or entry.hidden then return nil end
		local rep = self._config.replicate
		return rep and rep[key] == "all" and entry.data[key] or nil
	end
	local entry = self:_entry(keyOrPlayer)
	if not entry then return nil end
	return key ~= nil and entry.data[key] or entry.data
end

function Cache:set(keyOrPlayer: any, key: string, value: any)
	if not IS_SERVER and not self._standalone then
		warn("[Plinko] clients cannot write to cache")
		return
	end
	self:_write(keyOrPlayer, key, value)
end
function Cache:increment(keyOrPlayer: any, key: string, n: number?)
	local entry = self:_entry(keyOrPlayer)
	if not entry then return end
	local current = entry.data[key]
	if type(current) ~= "number" then
		warn(`[Plinko] cannot increment non-number key "{key}"`)
		return
	end
	self:_write(keyOrPlayer, key, current + (n or 1))
end

function Cache:patch(keyOrPlayer: any, delta: { [string]: any })
	for key, value in pairs(delta) do
		self:_write(keyOrPlayer, key, value)
	end
end

function Cache:reset(keyOrPlayer: any, key: string)
	local entry = self:_entry(keyOrPlayer)
	if not entry then return end
	self:_write(keyOrPlayer, key, entry.defaults[key])
end

function Cache:flush(keyOrPlayer: any): any
	local entry = self:_entry(keyOrPlayer)
	if not entry then return Promise.resolve() end

	local dirty   = deepCopy(entry.dirty)
	entry.dirty   = {}

	entry._onFlush:Fire(dirty)
	self.onFlush:Fire(keyOrPlayer, dirty)

	local onSave = self._config.onSave
	if onSave and IS_SERVER then
		return Promise.resolve():andThen(function()
			return onSave(keyOrPlayer, dirty)
		end)
	end

	return Promise.resolve()
end

function Cache:flushAll(): any
	local promises = {}
	for id in pairs(self._entries) do
		table.insert(promises, self:flush(id))
	end
	return Promise.all(promises)
end

function Cache:loaded(player: Player): boolean
	return self._entries[player] ~= nil
end

function Cache:await(player: Player?): any
	local id = player or (not IS_SERVER and Players.LocalPlayer or nil)
	if not id then return Promise.reject("[Plinko] no player") end

	if self._entries[id] then
		return Promise.resolve(self._entries[id].data)
	end

	return Promise.new(function(resolve)
		local conn
		conn = self.onAdded:Connect(function(p, data)
			if p == id then
				conn:Disconnect()
				resolve(data)
			end
		end)
	end)
end

function Cache:lock(player: Player)
	local e = self:_entry(player)
	if e then e.locked = true end
end

function Cache:unlock(player: Player)
	local e = self:_entry(player)
	if e then e.locked = false end
end

function Cache:hide(player: Player)
	local e = self:_entry(player)
	if e then e.hidden = true end
end

function Cache:show(player: Player)
	local e = self:_entry(player)
	if e then e.hidden = false end
end

function Cache:find(fn: FilterFn): { [any]: { [string]: any } }
	local results = {}
	for id, entry in pairs(self._entries) do
		if fn(id, entry.data) then results[id] = entry.data end
	end
	return results
end

function Cache:some(fn: FilterFn): boolean
	for id, entry in pairs(self._entries) do
		if fn(id, entry.data) then return true end
	end
	return false
end

function Cache:count(fn: FilterFn?): number
	local n = 0
	for id, entry in pairs(self._entries) do
		if not fn or fn(id, entry.data) then n += 1 end
	end
	return n
end

function Cache:setAll(key: string, value: any)
	for id in pairs(self._entries) do self:_write(id, key, value) end
end

function Cache:patchAll(delta: { [string]: any })
	for id in pairs(self._entries) do self:patch(id, delta) end
end

function Cache:resetAll(key: string)
	for id in pairs(self._entries) do self:reset(id, key) end
end

function Cache:dirty(keyOrPlayer: any): { [string]: any }
	local entry = self:_entry(keyOrPlayer)
	return entry and deepCopy(entry.dirty) or {}
end

function Cache:isDirty(keyOrPlayer: any, key: string): boolean
	local entry = self:_entry(keyOrPlayer)
	return entry ~= nil and entry.dirty[key] ~= nil
end

function Cache:clearDirty(keyOrPlayer: any)
	local entry = self:_entry(keyOrPlayer)
	if entry then entry.dirty = {} end
end

function Cache:snapshot(keyOrPlayer: any, name: string)
	local entry = self:_entry(keyOrPlayer)
	if not entry then return end
	entry.snapshots[name] = deepCopy(entry.data)
end

function Cache:getSnapshot(keyOrPlayer: any, name: string): { [string]: any }?
	local entry = self:_entry(keyOrPlayer)
	return entry and entry.snapshots[name] or nil
end

function Cache:diff(keyOrPlayer: any, name: string): { [string]: { old: any, new: any } }
	local entry = self:_entry(keyOrPlayer)
	if not entry then return {} end
	local snap = entry.snapshots[name]
	if not snap then return {} end
	local result = {}
	for key, current in pairs(entry.data) do
		if snap[key] ~= current then
			result[key] = { old = snap[key], new = current }
		end
	end
	return result
end

function Cache:migrate(keyOrPlayer: any, name: string)
	local entry = self:_entry(keyOrPlayer)
	if not entry then return end
	local snap = entry.snapshots[name]
	if not snap then
		warn(`[Plinko] no snapshot "{name}"`)
		return
	end
	self:patch(keyOrPlayer, snap)
end

function Cache:destroySnapshot(keyOrPlayer: any, name: string)
	local entry = self:_entry(keyOrPlayer)
	if entry then entry.snapshots[name] = nil end
end

function Cache:destroySnapshots(keyOrPlayer: any)
	local entry = self:_entry(keyOrPlayer)
	if not entry then return end
	entry.snapshots       = {}
	self._snapshots[keyOrPlayer] = entry.snapshots
end

function Cache:onChange(playerOrFn: any, fn: ((key: string, new: any, old: any) -> ())?): any
	if type(playerOrFn) == "function" then
		return self.onAdded:Connect(function(player)
			local entry = self:_entry(player)
			if entry then entry._onChange:Connect(playerOrFn) end
		end)
	end
	local entry = self:_entry(playerOrFn)
	return entry and entry._onChange:Connect(fn) or nil
end

function Cache:onFlushFor(playerOrFn: any, fn: ((dirty: { [string]: any }) -> ())?): any
	if type(playerOrFn) == "function" then
		return self.onFlush:Connect(function(_, dirty) playerOrFn(dirty) end)
	end
	local entry = self:_entry(playerOrFn)
	return entry and entry._onFlush:Connect(fn) or nil
end

function Cache:watch(keyOrPlayer: any, keyOrFn: any, fn: ((new: any, old: any) -> ())?): any
	local id       = IS_SERVER and keyOrPlayer or Players.LocalPlayer
	local watchKey = IS_SERVER and keyOrFn or keyOrPlayer
	local callback = IS_SERVER and fn or keyOrFn

	local entry = self:_entry(id)
	if not entry then return nil end

	if not entry._watches[watchKey] then entry._watches[watchKey] = {} end
	table.insert(entry._watches[watchKey], callback)

	return {
		Disconnect = function()
			local list = entry._watches[watchKey]
			local idx  = table.find(list, callback)
			if idx then table.remove(list, idx) end
		end,
	}
end

function Cache:create(id: any)
	if self._entries[id] then return end
	local entry = self:_create(id, self._config.schema)
	self.onAdded:Fire(id, entry.data)
end

function Cache:exists(id: any): boolean
	return self._entries[id] ~= nil
end

function Cache:release(id: any)
	self:_release(id)
end

function Cache:destroy()
	self:flushAll():andThen(function()
		for id in pairs(self._entries) do
			self:_release(id)
		end
		self.onAdded:Destroy()
		self.onRemoving:Destroy()
		self.onFlush:Destroy()
		self.onError:Destroy()
		if self._remote and IS_SERVER then
			self._remote:Destroy()
		end
	end)
end

local Plinko = {}

function Plinko.define(name: string, config: Config): Cache
	assert(type(name) == "string" and #name > 0, "[Plinko] name must be a non-empty string")
	assert(type(config) == "table",               "[Plinko] config must be a table")
	assert(type(config.schema) == "table",        "[Plinko] config.schema must be a table")

	local self          = setmetatable({}, Cache) :: any
	self._config        = config
	self._name          = name
	self._entries       = {}
	self._snapshots     = {}
	self._standalone    = config.standalone == true
	self._remote        = nil

	self.onAdded    = Signal.new()
	self.onRemoving = Signal.new()
	self.onFlush    = Signal.new()
	self.onError    = Signal.new()

	if config.replicate then
		local remoteName = "Plinko_" .. name

		if IS_SERVER then
			local remote      = Instance.new("RemoteEvent")
			remote.Name       = remoteName
			remote.Parent     = game:GetService("ReplicatedStorage")
			self._remote      = remote
		else
			local remote = game:GetService("ReplicatedStorage"):WaitForChild(remoteName, 10)
			if remote then
				self._remote = remote
				remote.OnClientEvent:Connect(function(data: { k: string, v: any, o: any? })
					local id    = data.o or Players.LocalPlayer
					local entry = self:_entry(id)
					if not entry then
						entry = self:_create(id, deepCopy(config.schema))
					end
					local old         = entry.data[data.k]
					entry.data[data.k] = data.v
					entry._onChange:Fire(data.k, data.v, old)
					local watches = entry._watches[data.k]
					if watches then
						for _, fn in ipairs(watches) do
							task.spawn(fn, data.v, old)
						end
					end
				end)
			else
				warn(`[Plinko] remote "{remoteName}" not found -- replication disabled`)
			end
		end
	end

	if IS_SERVER and not self._standalone then
		self:_hookPlayers()
		self:_startTimer()
	end

	return self
end

return Plinko