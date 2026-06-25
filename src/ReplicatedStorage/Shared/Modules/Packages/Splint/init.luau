--!strict
-- Splint
-- init.luau
-- Plinko Labs
--
-- Server-authoritative, client-visual ragdoll for R6/R15. Define a named recipe once,
-- apply it to any character to get a live Handle you can recover, auto-recover, or
-- stream. Core controllers: Classic (full limp) and Active (limp + fights upright).
--
--   local Splint = require(ReplicatedStorage.Shared.Modules.Packages.Splint)
--
--   Splint.define("Death", { type = "Classic", joints = "all",
--       inheritVelocity = true, collisions = true })
--
--   local rag = Splint.apply("Death", character)   -- server: character goes limp
--   rag.OnRecovered:Connect(function() print("up!") end)
--   task.delay(3, function() rag:recover() end)
--
--   -- knockback stagger that recovers itself:
--   Splint.apply({ type = "Active", joints = {"RightHip","LeftHip"},
--       inheritVelocity = true, collisions = true, autoRecover = 1.2 }, character)

local Handle = require(script.Handle)
local Replication = require(script.Replication)
local Types = require(script.Types)

type Config = Types.Config
type Snapshot = Types.Snapshot

local Splint = {}
local _registry: { [string]: Config } = {}

local DEFAULTS: Config = {
	type = "Classic",
	joints = "all",
	inheritVelocity = true,
	collisions = true,
}

local function normalize(config): Config
	local c = table.clone(DEFAULTS)
	for k, v in config do
		(c :: any)[k] = v
	end
	return c
end

-- Register a reusable recipe by name.
function Splint.define(name: string, config): Config
	local c = normalize(config)
	_registry[name] = c
	return c
end

function Splint.get(name: string): Config?
	return _registry[name]
end

-- Apply a ragdoll (recipe name or inline config) to a character. Returns the Handle.
function Splint.apply(nameOrConfig: string | { [string]: any }, character: Model)
	local config: Config
	if type(nameOrConfig) == "string" then
		local found = _registry[nameOrConfig]
		assert(found, "[Splint] no ragdoll recipe named '" .. nameOrConfig .. "'")
		config = found
	else
		config = normalize(nameOrConfig)
	end
	return Handle.new(config, character):engage()
end

-- Client helper: apply a streamed snapshot to a character's parts.
function Splint.applySnapshot(character: Model, snapshot: Snapshot)
	Replication.apply(character, snapshot)
end

return Splint
