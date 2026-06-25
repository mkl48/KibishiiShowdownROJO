

local Promise = require(script.Parent.Promise)

type AtomInternal = {
	_value:     any,
	_listeners: { (any, any) -> () },
	_batching:  boolean,
}

local Atom = {}
Atom.__index = Atom

local batchQueue: { { atom: any, new: any, old: any } } = {}
local isBatching = false

local function new(initial: any): any
	local self: AtomInternal = {
		_value     = initial,
		_listeners = {},
		_batching  = false,
	}
	return setmetatable(self :: any, Atom)
end

function Atom:get(): any
	return self._value
end

function Atom:set(value: any)
	local old = self._value
	if old == value then return end
	self._value = value
	if isBatching then
		table.insert(batchQueue, { atom = self, new = value, old = old })
	else
		for _, fn in self._listeners do
			task.spawn(fn, value, old)
		end
	end
end

function Atom:onChange(cb: (any, any) -> ()): () -> ()
	table.insert(self._listeners, cb)
	return function()
		for i, fn in self._listeners do
			if fn == cb then
				table.remove(self._listeners, i)
				break
			end
		end
	end
end

function Atom:promise(): any
	return Promise.new(function(resolve)
		local disconnect: (() -> ())?
		disconnect = self:onChange(function(new, old)
			if disconnect then disconnect() end
			resolve(new, old)
		end)
	end)
end

function Atom:derive(fn: (any) -> any): any
	local derived = new(fn(self._value))
	self:onChange(function(value)
		derived:set(fn(value))
	end)
	return derived
end

local function batch(fn: () -> ())
	isBatching = true
	local ok, err = pcall(fn)
	isBatching = false

	local fired: { any } = {}
	for _, entry in batchQueue do
		local already = false
		for _, a in fired do
			if a == entry.atom then already = true break end
		end
		if not already then
			table.insert(fired, entry.atom)
			for _, listener in entry.atom._listeners do
				task.spawn(listener, entry.new, entry.old)
			end
		end
	end
	table.clear(batchQueue)

	if not ok then error(err) end
end

return { new = new, batch = batch }