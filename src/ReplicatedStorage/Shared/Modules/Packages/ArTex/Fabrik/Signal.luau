local Promise = require(script.Parent.Promise)

local Signal = {}
Signal.__index = Signal

type Connection = () -> ()

type SignalInternal = {
	_listeners: { { id: number, fn: (...any) -> () } },
	_nextId:    number,
}

local _fabrik -- injected by _init to break circular dependency

local function new(): any
	local self: SignalInternal = {
		_listeners = {},
		_nextId    = 0,
	}
	return setmetatable(self :: any, Signal)
end

function Signal:connect(cb: (...any) -> ()): Connection
	self._nextId += 1
	local id = self._nextId
	table.insert(self._listeners, { id = id, fn = cb })
	return function()
		for i, l in self._listeners do
			if l.id == id then
				table.remove(self._listeners, i)
				break
			end
		end
	end
end

function Signal:once(cb: (...any) -> ())
	local disconnect: Connection
	disconnect = self:connect(function(...)
		disconnect()
		cb(...)
	end)
end

function Signal:fire(...: any)
	for _, l in self._listeners do
		task.spawn(l.fn, ...)
	end
end

function Signal:promise(): any
	return Promise.new(function(resolve)
		self:once(function(...)
			resolve(...)
		end)
	end)
end

function Signal:promiseWhere(predicate: (...any) -> boolean): any
	return Promise.new(function(resolve)
		local disconnect: Connection
		disconnect = self:connect(function(...)
			if predicate(...) then
				disconnect()
				resolve(...)
			end
		end)
	end)
end

function Signal:filter(predicate: (...any) -> boolean): any
	local filtered = new()
	self:connect(function(...)
		if predicate(...) then
			filtered:fire(...)
		end
	end)
	return filtered
end

function Signal:map(fn: (...any) -> any): any
	local mapped = new()
	self:connect(function(...)
		mapped:fire(fn(...))
	end)
	return mapped
end

function Signal:merge(other: any): any
	local merged = new()
	self:connect(function(...) merged:fire(...) end)
	other:connect(function(...) merged:fire(...) end)
	return merged
end

function Signal:pipe(other: any)
	self:connect(function(...)
		other:fire(...)
	end)
end

function Signal:toTask(name: string)
	self:connect(function(...)
		if _fabrik then
			_fabrik.run(name, ...)
		end
	end)
end

function Signal:destroy()
	table.clear(self._listeners)
end

local function _init(fabrik: any)
	_fabrik = fabrik
end

return { new = new, _init = _init }