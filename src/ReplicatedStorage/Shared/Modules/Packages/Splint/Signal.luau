--!strict
-- Splint
-- Signal.luau
-- Plinko Labs
--
-- Minimal synchronous signal for ragdoll lifecycle events (contact, recovered).

local Signal = {}
Signal.__index = Signal

export type Connection = { Connected: boolean, Disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ _h = {} }, Signal)
end

function Signal:Connect(fn): Connection
	local c = { Connected = true, _fn = fn }
	function c:Disconnect()
		self.Connected = false
	end
	table.insert(self._h, c)
	return c
end

function Signal:Once(fn): Connection
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end

function Signal:Fire(...)
	for _, c in self._h do
		if c.Connected then
			local ok, err = pcall(c._fn, ...)
			if not ok then
				warn("[Splint] signal handler error:", err)
			end
		end
	end
end

function Signal:DisconnectAll()
	for _, c in self._h do
		c.Connected = false
	end
	table.clear(self._h)
end

return Signal
