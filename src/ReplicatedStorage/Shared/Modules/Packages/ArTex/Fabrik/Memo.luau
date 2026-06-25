

local Promise = require(script.Parent.Promise)

type MemoConfig = {
	timeout: number?,
}

type CacheEntry = {
	value:     any,
	expiresAt: number,
	inflight:  any?,
}

type MemoInternal = {
	_fn:      (...any) -> any,
	_timeout: number?,
	_cache:   { [string]: CacheEntry },
}

local Memo = {}
Memo.__index = Memo

local function serialize(...: any): string
	local parts = {}
	for _, v in { ... } do
		table.insert(parts, tostring(v))
	end
	return table.concat(parts, ":")
end

local function new(fn: (...any) -> any, config: MemoConfig?): any
	local cfg = config or {}
	local self: MemoInternal = {
		_fn      = fn,
		_timeout = cfg.timeout,
		_cache   = {},
	}
	local meta = setmetatable(self :: any, Memo)

	local callable = setmetatable({}, {
		__index = meta,
		__call  = function(_, ...: any)
			return meta:_call(...)
		end,
	})

	return callable
end

function Memo:_call(...: any): any
	local key     = serialize(...)
	local now     = os.clock()
	local entry   = self._cache[key]

	if entry then
		if entry.inflight then
			return entry.inflight
		end
		if not self._timeout or (now < entry.expiresAt) then
			return Promise.resolve(entry.value)
		end
	end

	local args = { ... }
	local p = Promise.new(function(resolve, reject)
		local ok, result = pcall(self._fn, table.unpack(args))
		if ok then
			self._cache[key] = {
				value     = result,
				expiresAt = self._timeout and (now + self._timeout) or math.huge,
				inflight  = nil,
			}
			resolve(result)
		else
			self._cache[key] = nil
			reject(result)
		end
	end)

	self._cache[key] = {
		value     = nil,
		expiresAt = 0,
		inflight  = p,
	}

	return p
end

function Memo:invalidate(...: any)
	local key = serialize(...)
	self._cache[key] = nil
end

function Memo:clear()
	table.clear(self._cache)
end

return { new = new }