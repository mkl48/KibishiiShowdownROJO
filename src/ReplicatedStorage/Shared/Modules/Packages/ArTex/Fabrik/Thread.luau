local Promise = require(script.Parent.Promise)
local Signal  = require(script.Parent.Signal)

local Thread = {}

function Thread.spawn(fn: (...any) -> (), ...: any): thread
	local args = { ... }
	return task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args))
		if not ok then
			warn("[Fabrik.thread.spawn]", err)
		end
	end)
end

function Thread.defer(fn: (...any) -> (), ...: any): thread
	local args = { ... }
	return task.defer(function()
		local ok, err = pcall(fn, table.unpack(args))
		if not ok then
			warn("[Fabrik.thread.defer]", err)
		end
	end)
end

function Thread.delay(seconds: number, fn: (...any) -> (), ...: any): thread
	local args = { ... }
	return task.delay(seconds, function()
		local ok, err = pcall(fn, table.unpack(args))
		if not ok then
			warn("[Fabrik.thread.delay]", err)
		end
	end)
end

function Thread.sleep(seconds: number)
	task.wait(seconds)
end

function Thread.pause()
	coroutine.yield()
end

function Thread.resume(t: thread, ...: any)
	task.spawn(t, ...)
end

function Thread.cancel(t: thread)
	task.cancel(t)
end

function Thread.current(): thread
	return coroutine.running()
end

function Thread.wrap(fn: (...any) -> any): (...any) -> any
	local co = coroutine.wrap(function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Fabrik.thread.wrap]", err)
		end
	end)
	return co
end

function Thread.interval(seconds: number, fn: () -> ()): { cancel: () -> () }
	local running = true
	local t = Thread.spawn(function()
		while running do
			task.wait(seconds)
			if not running then break end
			local ok, err = pcall(fn)
			if not ok then
				warn("[Fabrik.thread.interval]", err)
			end
		end
	end)
	return {
		cancel = function()
			running = false
			task.cancel(t)
		end,
	}
end

function Thread.once(signal: any, fn: (...any) -> ())
	signal:once(function(...)
		Thread.spawn(fn, ...)
	end)
end

function Thread.race(threads: { thread }): any
	return Promise.new(function(resolve)
		local settled = false
		for _, t in threads do
			Thread.spawn(function()
				coroutine.resume(t)
				if not settled then
					settled = true
					for _, other in threads do
						if other ~= t then
							pcall(task.cancel, other)
						end
					end
					resolve(t)
				end
			end)
		end
	end)
end

return Thread