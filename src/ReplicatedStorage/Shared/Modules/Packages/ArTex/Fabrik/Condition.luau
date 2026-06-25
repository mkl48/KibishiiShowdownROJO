local Promise = require(script.Parent.Promise)

type ConditionConfig = {
	interval: number?,
}

local Condition = {}

function Condition.till(predicate: () -> boolean, config: ConditionConfig?): any
	local interval = (config and config.interval) or 0.1
	return Promise.new(function(resolve)
		local function poll()
			if predicate() then
				resolve()
			else
				task.delay(interval, poll)
			end
		end
		poll()
	end)
end

function Condition.onChange(getter: () -> any, config: ConditionConfig?): any
	local interval = (config and config.interval) or 0.1
	local last     = getter()
	return Promise.new(function(resolve)
		local function poll()
			local current = getter()
			if current ~= last then
				resolve(current, last)
			else
				task.delay(interval, poll)
			end
		end
		task.delay(interval, poll)
	end)
end

return Condition