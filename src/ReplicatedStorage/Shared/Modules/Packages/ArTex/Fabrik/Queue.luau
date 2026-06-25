

local Signal = require(script.Parent.Signal)

type QueueConfig = {
	concurrency: number?,
}

type QueueInternal = {
	_items:       { () -> () },
	_running:     number,
	_paused:      boolean,
	_concurrency: number,
	drained:      any,
}

local Queue = {}
Queue.__index = Queue

local function new(config: QueueConfig?): any
	local cfg = config or {}
	local self: QueueInternal = {
		_items       = {},
		_running     = 0,
		_paused      = false,
		_concurrency = cfg.concurrency or 1,
		drained      = Signal.new(),
	}
	return setmetatable(self :: any, Queue)
end

function Queue:_tick()
	if self._paused then return end
	while self._running < self._concurrency and #self._items > 0 do
		local fn = table.remove(self._items, 1)
		self._running += 1
		task.spawn(function()
			local ok, err = pcall(fn)
			if not ok then
				warn("[Fabrik.queue]", err)
			end
			self._running -= 1
			if #self._items == 0 and self._running == 0 then
				self.drained:fire()
			else
				self:_tick()
			end
		end)
	end
end

function Queue:push(fn: () -> ())
	table.insert(self._items, fn)
	self:_tick()
end

function Queue:pause()
	self._paused = true
end

function Queue:resume()
	self._paused = false
	self:_tick()
end

function Queue:clear()
	table.clear(self._items)
end

function Queue:size(): number
	return #self._items
end

return { new = new }