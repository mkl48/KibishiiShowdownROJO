local Builder = require(script.Builder)
local VariantBuilder = require(script.VariantBuilder)
local Timeline = require(script.Timeline)
local Promise = require(script.Promise)
local Types = require(script.Types)

type MoveSpec = Types.MoveSpec
type VariantSpec = Types.VariantSpec
type Ctx = Types.Ctx
type CrossfadeConfig = Types.CrossfadeConfig
type PriorityTier = Types.PriorityTier
type HitboxController = Types.HitboxController

local Memo = {}

local _registry: { [string]: MoveSpec } = {}
local _variantRegistry: { [string]: VariantSpec } = {}
local _hitboxController: HitboxController? = nil

local function priorityValue(p: PriorityTier): number
	if type(p) == "number" then return p end
	local tiers: { [string]: number } = {
		light = 1,
		normal = 2,
		heavy = 3,
		super = 4,
	}
	return tiers[p] or 0
end

local function buildCtx(base: Ctx): Ctx
	local ctx = table.clone(base)
	if _hitboxController then
		ctx.hitbox = _hitboxController
	end
	return ctx
end

function Memo.setHitboxController(hc: HitboxController)
	_hitboxController = hc
end

function Memo.getHitboxController(): HitboxController?
	return _hitboxController
end

function Memo.define(name: string): typeof(Builder.new(""))
	return Builder.new(name)
end

function Memo.defineVariants(name: string): typeof(VariantBuilder.new(""))
	return VariantBuilder.new(name)
end

function Memo.register(spec: MoveSpec)
	_registry[spec.name] = spec
end

function Memo.registerVariants(spec: VariantSpec)
	_variantRegistry[spec.name] = spec
	for variantName, moveSpec in spec.variants do
		_registry[spec.name .. "/" .. variantName] = moveSpec
	end
end

function Memo.getVariant(name: string): VariantSpec?
	return _variantRegistry[name]
end

function Memo.get(name: string): MoveSpec?
	return _registry[name]
end

function Memo.execute(spec: MoveSpec, ctx: Ctx): typeof(Promise.new(function() end))
	local resolved = buildCtx(ctx)
	local _, promise = Timeline.start(spec, resolved)
	return promise
end

function Memo.executeAt(spec: MoveSpec, ctx: Ctx, phase: string): typeof(Promise.new(function() end))
	local resolved = buildCtx(ctx)
	local _, promise = Timeline.startAt(spec, resolved, phase)
	return promise
end

function Memo.executeByName(name: string, ctx: Ctx): typeof(Promise.new(function() end))
	local spec = _registry[name]
	if not spec then
		return Promise.rejected("No move registered under: " .. name)
	end
	return Memo.execute(spec, ctx)
end

function Memo.executeByNameAt(name: string, ctx: Ctx, phase: string): typeof(Promise.new(function() end))
	local spec = _registry[name]
	if not spec then
		return Promise.rejected("No move registered under: " .. name)
	end
	return Memo.executeAt(spec, ctx, phase)
end

function Memo.executeVariant(spec: VariantSpec, ctx: Ctx): typeof(Promise.new(function() end))
	local resolved = buildCtx(ctx)
	local variantName = spec.resolver(resolved)
	local moveSpec = spec.variants[variantName]
	if not moveSpec then
		return Promise.rejected("Variant not found: " .. variantName .. " on " .. spec.name)
	end
	local _, promise = Timeline.start(moveSpec, resolved)
	return promise
end

function Memo.executeVariantAt(spec: VariantSpec, ctx: Ctx, phase: string): typeof(Promise.new(function() end))
	local resolved = buildCtx(ctx)
	local variantName = spec.resolver(resolved)
	local moveSpec = spec.variants[variantName]
	if not moveSpec then
		return Promise.rejected("Variant not found: " .. variantName .. " on " .. spec.name)
	end
	local _, promise = Timeline.startAt(moveSpec, resolved, phase)
	return promise
end

function Memo.executeVariantByName(name: string, ctx: Ctx): typeof(Promise.new(function() end))
	local spec = _variantRegistry[name]
	if not spec then
		return Promise.rejected("No variant move registered under: " .. name)
	end
	return Memo.executeVariant(spec, ctx)
end

function Memo.canInterrupt(current: MoveSpec, incoming: MoveSpec): boolean
	return priorityValue(incoming.priority) >= priorityValue(current.priority)
end

-- The resources a move declares it costs (your game deducts them; Memo never owns
-- resources). Empty table if none.
function Memo.costOf(spec: MoveSpec): { [string]: number }
	return spec.cost or {}
end

-- Run a move's conditions against a context without starting it. Returns
-- (true) or (false, reason). Call this (plus your own cost check) before execute.
function Memo.canStart(spec: MoveSpec, ctx: Ctx): (boolean, string?)
	if spec.conditions then
		local resolved = buildCtx(ctx)
		for _, cond in spec.conditions do
			local ok, reason = cond(resolved)
			if not ok then
				return false, reason or ("[Memo] condition failed for " .. spec.name)
			end
		end
	end
	return true
end

-- Gate + execute in one call: refuses with a rejected promise if a condition fails.
function Memo.tryExecute(spec: MoveSpec, ctx: Ctx): typeof(Promise.new(function() end))
	local ok, reason = Memo.canStart(spec, ctx)
	if not ok then
		return Promise.rejected(reason)
	end
	return Memo.execute(spec, ctx)
end

Memo.Drive = {
	time = function(duration: number): Types.DriveMode
		return { kind = "time", duration = duration }
	end,
	frames = function(count: number): Types.DriveMode
		return { kind = "frames", count = count }
	end,
	gate = function(signal: any): Types.DriveMode
		return { kind = "gate", signal = signal }
	end,
	any = function(modes: { Types.DriveMode }): Types.DriveMode
		return { kind = "any", modes = modes }
	end,
	all = function(modes: { Types.DriveMode }): Types.DriveMode
		return { kind = "all", modes = modes }
	end,
}

Memo.Crossfade = {
	hard = function(): CrossfadeConfig
		return { mode = "hard" }
	end,
	overlap = function(duration: number): CrossfadeConfig
		return { mode = "overlap", duration = duration }
	end,
	blend = function(duration: number): CrossfadeConfig
		return { mode = "blend", duration = duration }
	end,
}

return Memo