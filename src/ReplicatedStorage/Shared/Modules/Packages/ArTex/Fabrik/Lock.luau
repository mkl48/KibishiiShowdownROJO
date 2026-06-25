

local Promise = require(script.Parent.Promise)

type LockInternal = {
	_locked:  boolean,
	_waiters: { (any) -> () },
}

local Lock = {}
Lock.__index = Lock

local function new(): any
	local self: LockInternal = {
		_locked  = false,
		_waiters = {},
	}
	return setmetatable(self :: any, Lock)
end

function Lock:acquire(): any
	if not self._locked then
		self._locked = true
		return Promise.resolve(nil)
	end
	return Promise.new(function(resolve)
		table.insert(self._waiters, resolve)
	end)
end

function Lock:release()
	if #self._waiters > 0 then
		local next = table.remove(self._waiters, 1)
		task.spawn(next, nil)
	else
		self._locked = false
	end
end

function Lock:withLock(fn: () -> ()): any
	return self:acquire():next(function()
		local ok, err = pcall(fn)
		self:release()
		if not ok then
			error(err)
		end
	end)
end

return { new = new }