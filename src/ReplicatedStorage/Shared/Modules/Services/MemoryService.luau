-- Kibishii Showdown
-- Shared/Modules/Services/MemoryService.luau
--
-- The authority for per-player Memory (Session / Keybinds / Settings). It defines one
-- Plinko cache per manifest block; Plinko then auto-creates each player's entry on join
-- and replicates "owner" fields to their client for free. Clients can't write to Plinko
-- directly, so a client change request comes in over Network "Memory.Change" -- the
-- service validates it (real cache, real key, clamped by middleware) and writes, and
-- Plinko streams the result back. Other server systems read with Memory:Get(...).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Shared.Modules.Packages
local Plinko = require(Packages.Plinko)
local Net = require(Packages.Network)
local MemoryManifest = require(ReplicatedStorage.Shared.Modules.Utility.MemoryManifest)

-- Per-key value guards (clamp / sanitize before a write lands).
local SETTINGS_MW = {
	MasterVolume = function(v) return math.clamp(tonumber(v) or 0, 0, 100) end,
	SfxVolume = function(v) return math.clamp(tonumber(v) or 0, 0, 100) end,
	MusicVolume = function(v) return math.clamp(tonumber(v) or 0, 0, 100) end,
	Sensitivity = function(v) return math.clamp(tonumber(v) or 1, 0.1, 5) end,
}

local MemoryService = {}
MemoryService.Caches = {} -- [block] = Plinko cache

function MemoryService:Start(context)
	-- Define one cache per manifest block. onLoad returns {} so Plinko creates each
	-- player's entry from schema defaults on join (real data load wires in here later).
	for _, block in MemoryManifest.Order do
		local def = MemoryManifest[block]
		self.Caches[block] = Plinko.define(block, {
			schema = def.schema,
			replicate = def.replicate,
			middleware = (block == "Settings") and SETTINGS_MW or nil,
			onLoad = function()
				return {}
			end,
		})
	end

	-- client -> server: a validated change request (Net puts the player first).
	Net:OnClient("Memory.Change", function(player, payload)
		self:Change(player, payload)
	end)
end

function MemoryService:Cache(block: string)
	return self.Caches[block]
end

function MemoryService:Get(block: string, player: Player, key: string?)
	local cache = self.Caches[block]
	return cache and cache:get(player, key) or nil
end

function MemoryService:Set(block: string, player: Player, key: string, value)
	local cache = self.Caches[block]
	if cache then
		cache:set(player, key, value)
	end
end

-- Apply a client-requested change after validating block + key exist in the manifest.
function MemoryService:Change(player: Player, payload)
	if type(payload) ~= "table" then
		return
	end
	local block = payload.Cache
	local def = MemoryManifest[block]
	local cache = self.Caches[block]
	if not (def and cache) then
		return
	end
	-- Only allow keys that exist in the schema (no arbitrary writes).
	if def.schema[payload.Key] == nil then
		return
	end
	-- Keybinds + Settings are player-changeable; Session is server-owned.
	if block == "Session" then
		return
	end
	cache:set(player, payload.Key, payload.Value)
end

return MemoryService
