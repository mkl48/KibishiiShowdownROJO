local Types = require(script.Parent.Types)

type MoveSpec = Types.MoveSpec
type PhaseDescriptor = Types.PhaseDescriptor
type TrackDescriptor = Types.TrackDescriptor
type DriveMode = Types.DriveMode
type CancelWindow = Types.CancelWindow
type BranchRoute = Types.BranchRoute
type CrossfadeConfig = Types.CrossfadeConfig
type CounterWindow = Types.CounterWindow
type Ctx = Types.Ctx
type TrackSide = Types.TrackSide
type TrackKind = Types.TrackKind

export type TrackBuilder = {
	side: (self: TrackBuilder, side: TrackSide) -> TrackBuilder,
	data: (self: TrackBuilder, d: { [string]: any }) -> TrackBuilder,
	onEnter: (self: TrackBuilder, fn: (ctx: Ctx) -> ()) -> TrackBuilder,
	onExit: (self: TrackBuilder, fn: (ctx: Ctx) -> ()) -> TrackBuilder,
	onTick: (self: TrackBuilder, fn: (ctx: Ctx, dt: number) -> ()) -> TrackBuilder,
	done: (self: TrackBuilder) -> PhaseBuilder,
}

export type PhaseBuilder = {
	drive: (self: PhaseBuilder, mode: DriveMode) -> PhaseBuilder,
	track: (self: PhaseBuilder, kind: TrackKind) -> TrackBuilder,
	onEnter: (self: PhaseBuilder, fn: (ctx: Ctx) -> ()) -> PhaseBuilder,
	onExit: (self: PhaseBuilder, fn: (ctx: Ctx) -> ()) -> PhaseBuilder,
	counter: (self: PhaseBuilder, config: CounterWindow) -> PhaseBuilder,
	done: (self: PhaseBuilder) -> MoveBuilder,
}

export type MoveBuilder = {
	priority: (self: MoveBuilder, p: Types.PriorityTier) -> MoveBuilder,
	phase: (self: MoveBuilder, name: Types.PhaseKind) -> PhaseBuilder,
	window: (self: MoveBuilder, config: CancelWindow) -> MoveBuilder,
	route: (self: MoveBuilder, config: BranchRoute) -> MoveBuilder,
	crossfade: (self: MoveBuilder, config: CrossfadeConfig) -> MoveBuilder,
	tag: (self: MoveBuilder, ...string) -> MoveBuilder,
	build: (self: MoveBuilder) -> MoveSpec,
}

local function newTrackBuilder(kind: TrackKind, phaseRef: any): TrackBuilder
	local desc: TrackDescriptor = {
		kind = kind,
		side = "shared",
		data = {},
	}

	local tb = {} :: any
	local tbMeta = { __index = tb }

	function tb:side(s)
		desc.side = s
		return self
	end

	function tb:data(d)
		for k, v in d do
			desc.data[k] = v
		end
		return self
	end

	function tb:onEnter(fn)
		desc.onEnter = fn
		return self
	end

	function tb:onExit(fn)
		desc.onExit = fn
		return self
	end

	function tb:onTick(fn)
		desc.onTick = fn
		return self
	end

	function tb:done()
		table.insert(phaseRef._tracks, desc)
		return phaseRef
	end

	return setmetatable({}, tbMeta) :: any
end

local function newPhaseBuilder(name: Types.PhaseKind, moveRef: any): PhaseBuilder
	local pb = {} :: any
	pb._tracks = {} :: { TrackDescriptor }

	local desc: PhaseDescriptor = {
		name = name,
		drive = { kind = "time", duration = 0 },
		tracks = pb._tracks,
	}

	function pb:drive(mode: DriveMode)
		desc.drive = mode
		return self
	end

	function pb:track(kind: TrackKind)
		return newTrackBuilder(kind, pb)
	end

	function pb:onEnter(fn)
		desc.onEnter = fn
		return self
	end

	function pb:onExit(fn)
		desc.onExit = fn
		return self
	end

	function pb:counter(config: CounterWindow)
		desc.counter = config
		return self
	end

	function pb:done()
		desc.tracks = pb._tracks
		table.insert(moveRef._phases, desc)
		return moveRef
	end

	return pb
end

local function new(name: string): MoveBuilder
	local mb = {} :: any
	mb._name = name
	mb._priority = 0
	mb._phases = {} :: { PhaseDescriptor }
	mb._windows = {} :: { CancelWindow }
	mb._routes = {} :: { BranchRoute }
	mb._crossfade = { mode = "hard" } :: CrossfadeConfig
	mb._tags = {} :: { string }

	function mb:priority(p)
		mb._priority = p
		return self
	end

	function mb:phase(phaseName)
		return newPhaseBuilder(phaseName, mb)
	end

	function mb:window(config)
		table.insert(mb._windows, config)
		return self
	end

	function mb:route(config)
		table.insert(mb._routes, config)
		return self
	end

	function mb:crossfade(config)
		mb._crossfade = config
		return self
	end

	function mb:tag(...)
		for _, t in { ... } do
			table.insert(mb._tags, t)
		end
		return self
	end

	function mb:build(): MoveSpec
		local spec: MoveSpec = {
			name = mb._name,
			priority = mb._priority,
			phases = mb._phases,
			windows = mb._windows,
			routes = mb._routes,
			defaultCrossfade = mb._crossfade,
			tags = mb._tags,
		}
		table.freeze(spec)
		return spec
	end

	return mb
end

return { new = new }