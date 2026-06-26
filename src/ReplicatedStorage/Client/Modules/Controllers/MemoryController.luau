-- Kibishii Showdown
-- Client/Modules/Controllers/MemoryController.luau
--
-- The client view of Memory. It defines the same Plinko caches as the server, so each
-- one auto-receives this player's replicated Session / Keybinds / Settings (read-only --
-- Plinko refuses client writes). The UI reads with Memory:Get(block, key) and asks for
-- changes with Memory:Set(...), which routes to the server's MemoryService for
-- validation; the new value streams back through Plinko. Watch a field to react live
-- (e.g. apply volume).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Shared.Modules.Packages
local Plinko = require(Packages.Plinko)
local Net = require(Packages.Network)
local MemoryManifest = require(ReplicatedStorage.Shared.Modules.Utility.MemoryManifest)

local MemoryController = {}
MemoryController.Caches = {}

function MemoryController:Start(_context)
	-- Mirror the server's caches; Plinko connects each to its replication remote.
	for _, block in MemoryManifest.Order do
		local def = MemoryManifest[block]
		self.Caches[block] = Plinko.define(block, {
			schema = def.schema,
			replicate = def.replicate,
		})
	end
end

-- Read this player's replicated value.
function MemoryController:Get(block: string, key: string)
	local cache = self.Caches[block]
	return cache and cache:get(key) or nil
end

-- React to a field changing (server-pushed). Returns a disconnect handle.
function MemoryController:Watch(block: string, key: string, fn)
	local cache = self.Caches[block]
	return cache and cache:watch(key, fn) or nil
end

-- Request a change. Server validates + writes; the value comes back via replication.
function MemoryController:Set(block: string, key: string, value)
	Net:ToServer("Memory.Change", { Cache = block, Key = key, Value = value })
end

return MemoryController
