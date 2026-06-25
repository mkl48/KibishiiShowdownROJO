local Middleware = {}

local _global  = {}
local _phased  = {}

function Middleware.add(phaseOrFn, fn)
	if type(phaseOrFn) == "function" then
		table.insert(_global, phaseOrFn)
	else
		local phase = phaseOrFn:lower()
		if not _phased[phase] then _phased[phase] = {} end
		table.insert(_phased[phase], fn)
	end
end

function Middleware.run(phase, moduleCtx, coreFn)
	local stack = {}

	for _, fn in _global do
		table.insert(stack, fn)
	end

	local phased = _phased[phase]
	if phased then
		for _, fn in phased do
			table.insert(stack, fn)
		end
	end

	table.insert(stack, coreFn)

	local index = 0

	local function next()
		index += 1
		local fn = stack[index]
		if fn then fn(moduleCtx, next) end
	end

	next()
end

function Middleware.reset()
	_global = {}
	_phased = {}
end

return Middleware