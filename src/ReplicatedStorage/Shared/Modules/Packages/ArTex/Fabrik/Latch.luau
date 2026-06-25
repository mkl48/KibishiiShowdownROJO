

local Promise = require(script.Parent.Promise)

type LatchInternal = {
	_open:    boolean,
	_waiters: { thread },
}

local Latch = {}
Latch.__index = Latch

local function new(): any
	local self: LatchInternal = {
		_open    = false,
		_waiters = {},
	}
	return setmetatable(self :: any, Latch)
end

function Latch:await()
	if self._open then return end
	table.insert(self._waiters, coroutine.running())
	coroutine.yield()
end

function Latch:open()
	self._open = true
	local waiters = self._waiters
	self._waiters = {}
	for _, t in waiters do
		task.spawn(t)
	end
end

function Latch:reset()
	self._open = false
end

function Latch:isOpen(): boolean
	return self._open
end

function Latch:promise(): any
	if self._open then
		return Promise.resolve(nil)
	end
	return Promise.new(function(resolve)
		local disconnect: (() -> ())?
		local t = task.spawn(function()
			self:await()
			resolve()
		end)
		_ = t
	end)
end

return { new = new }