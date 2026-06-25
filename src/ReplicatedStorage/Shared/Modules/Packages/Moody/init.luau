--!nonstrict
-- Moody
-- init.luau
-- Plinko Labs
--
-- A hierarchical state machine. States nest with dot-notation ("Combat.Aiming");
-- events drive transitions, with guards, middleware, and enter/exit hooks that fire
-- by lowest-common-ancestor (moving between siblings doesn't re-enter the parent).
-- post()/go() return Accede thenables. Built for "the server owns state, clients
-- listen" -- the core is local; wire onTransition to the network layer for replication.
--
--   local Character = Moody.new("Idle")
--       .state("Idle")
--       .state("Combat", { onEnter = function() print("draw") end })
--       .state("Combat.Aiming", { tags = { "ranged" } })
--       .subscribe("engage", { from = "Idle", to = "Combat" })
--       .subscribe("aim",    { from = "Combat", to = "Combat.Aiming",
--                              guard = function(ctx) return ctx.data.hasAmmo end })
--       .build()
--
--   local m = Character.spawn()
--   m.use(function(ctx, next) print(ctx.from, "->", ctx.to) next() end)
--   m.post("engage"):next(function(new) print("now", new) end):toss(warn)
--   print(m.current(), m.is("Combat"))   -- "Combat.Aiming"  true
--
-- Call style: the BUILDER chains with dot (.state().build()); the thenable returned
-- by post()/go() chains with colon (:next/:toss), same as Accede.

local Accede = require(script.Parent.Accede)

local Moody = {}

-- ===================================================================== helpers =====

-- "Combat.Aiming" -> { "Combat", "Combat.Aiming" } (root-to-leaf chain of state ids).
local function chain(state: string): { string }
	local out, acc = {}, nil
	for segment in state:gmatch("[^%.]+") do
		acc = acc and (acc .. "." .. segment) or segment
		table.insert(out, acc)
	end
	return out
end

-- True if `state` is `ancestor` or nested under it.
local function within(state: string, ancestor: string): boolean
	return state == ancestor or state:sub(1, #ancestor + 1) == (ancestor .. ".")
end

-- Lowest common ancestor id of two states ("" if none).
local function lca(a: string, b: string): string
	local ca, cb = chain(a), chain(b)
	local common = ""
	for i = 1, math.min(#ca, #cb) do
		if ca[i] == cb[i] then
			common = ca[i]
		else
			break
		end
	end
	return common
end

local function matchesFrom(current: string, from: string): boolean
	return from == "*" or within(current, from)
end

-- ===================================================================== builder =====

function Moody.new(initial: string)
	local def = {
		_initial = initial,
		_states = {} :: { [string]: any }, -- id -> config
		_transitions = {} :: { any }, -- { event, from, to, guard, action }
		_middleware = {} :: { any },
	}

	local builder = {}

	function builder.state(id: string, config)
		def._states[id] = config or {}
		return builder
	end

	function builder.subscribe(event: string, config)
		table.insert(def._transitions, {
			event = event,
			from = config.from or "*",
			to = config.to,
			guard = config.guard,
			action = config.action,
		})
		return builder
	end

	function builder.use(fn)
		table.insert(def._middleware, fn)
		return builder
	end

	function builder.build()
		return Moody._define(def)
	end

	return builder
end

-- ===================================================================== runtime =====

local function configOf(def, id)
	return def._states[id] or {}
end

-- Fire onExit from `current` up to (not including) lca; onEnter from lca down to target.
local function applyHooks(def, current: string, target: string, ctx)
	local boundary = lca(current, target)
	local cur = chain(current)
	for i = #cur, 1, -1 do
		local id = cur[i]
		if id == boundary then
			break
		end
		local cfg = configOf(def, id)
		if cfg.onExit then
			pcall(cfg.onExit, ctx)
		end
	end
	local tgt = chain(target)
	local passedBoundary = (boundary == "")
	for _, id in tgt do
		if passedBoundary then
			local cfg = configOf(def, id)
			if cfg.onEnter then
				pcall(cfg.onEnter, ctx)
			end
		elseif id == boundary then
			passedBoundary = true -- don't re-enter the shared ancestor
		end
	end
end

local function runMiddleware(mws, ctx, proceed, blocked)
	local i = 0
	local advanced = false
	local function nextFn()
		i += 1
		local mw = mws[i]
		if mw then
			mw(ctx, nextFn)
		else
			advanced = true
			proceed()
		end
	end
	nextFn()
	-- A middleware that never called next() leaves us un-advanced = blocked.
	if not advanced and i <= #mws then
		blocked()
	end
end

function Moody._define(def)
	local definition = {}

	function definition.spawn(_opts)
		local machine = {}
		local current = def._initial
		local middleware = table.clone(def._middleware)
		local onTransition = {} -- listeners

		local function fire(new, old, data)
			for _, fn in onTransition do
				task.spawn(fn, new, old, data)
			end
		end

		-- Perform a validated transition to `target` (shared by post + go).
		local function transition(target: string, data, eventName, guard, action)
			return Accede.new(function(resolve, reject)
				if not def._states[target] then
					reject("[Moody] unknown state: " .. tostring(target), "UnknownState")
					return
				end
				local old = current
				local ctx = {
					event = eventName,
					from = old,
					to = target,
					data = data,
					machine = machine,
				}

				local function proceed()
					if guard and guard(ctx) == false then
						reject("[Moody] transition blocked by guard", "Guarded")
						return
					end
					applyHooks(def, old, target, ctx)
					if action then
						pcall(action, ctx)
					end
					current = target
					fire(target, old, data)
					resolve(target, old, data)
				end

				runMiddleware(middleware, ctx, proceed, function()
					reject("[Moody] transition halted by middleware", "Halted")
				end)
			end)
		end

		-- Drive by event: find a transition whose event + from match the current state.
		function machine.post(event: string, data)
			for _, t in def._transitions do
				if t.event == event and matchesFrom(current, t.from) then
					return transition(t.to, data, event, t.guard, t.action)
				end
			end
			return Accede.reject(
				("[Moody] no '%s' transition from '%s'"):format(event, current),
				"NoTransition"
			)
		end

		-- Direct jump to a state, bypassing event lookup (still runs hooks/middleware).
		function machine.go(stateId: string, data)
			return transition(stateId, data, nil, nil, nil)
		end

		function machine.current(): string
			return current
		end

		function machine.is(stateId: string): boolean
			return within(current, stateId)
		end

		function machine.tags(): { string }
			return configOf(def, current).tags or {}
		end

		function machine.use(fn)
			table.insert(middleware, fn)
			return machine
		end

		function machine.onTransition(fn)
			table.insert(onTransition, fn)
			return function()
				local idx = table.find(onTransition, fn)
				if idx then
					table.remove(onTransition, idx)
				end
			end
		end

		-- Snapshot / restore the current state id (extend with context as needed).
		function machine.snapshot(): string
			return current
		end

		function machine.restore(stateId: string)
			current = stateId
		end

		return machine
	end

	return definition
end

return Moody
