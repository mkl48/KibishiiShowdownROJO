

local Promise = require(script.Parent.Promise)

type CooldownInternal = {
	_duration:  number,
	_expiresAt: number,
}

local Cooldown = {}
Cooldown.__index = Cooldown

local function new(duration: number): any
	local self: CooldownInternal = {
		_duration  = duration,
		_expiresAt = 0,
	}
	return setmetatable(self :: any, Cooldown)
end

function Cooldown:start()
	self._expiresAt = os.clock() + self._duration
end

function Cooldown:reset()
	self._expiresAt = 0
end

function Cooldown:isReady(): boolean
	return os.clock() >= self._expiresAt
end

function Cooldown:remaining(): number
	local r = self._expiresAt - os.clock()
	return math.max(r, 0)
end

function Cooldown:promise(): any
	local rem = self:remaining()
	if rem <= 0 then
		return Promise.resolve(nil)
	end
	return Promise.new(function(resolve)
		task.delay(rem, resolve)
	end)
end

function Cooldown:andThen(fn: () -> ()): any
	return self:promise():next(fn)
end

function Cooldown:auth(handle: any)
	if not self:isReady() then return end
	self:start()
	if handle and handle._promise then
		-- already dispatched -- no-op, gate was checked before dispatch
	end
end

function Cooldown:throttle(fn: (...any) -> ()): (...any) -> ()
	return function(...)
		if not self:isReady() then return end
		self:start()
		fn(...)
	end
end

function Cooldown:debounce(fn: (...any) -> ()): (...any) -> ()
	local pending: thread?
	return function(...)
		local args = { ... }
		if pending then
			task.cancel(pending)
		end
		pending = task.delay(self._duration, function()
			pending = nil
			fn(table.unpack(args))
		end)
		self._expiresAt = os.clock() + self._duration
	end
end

return { new = new }