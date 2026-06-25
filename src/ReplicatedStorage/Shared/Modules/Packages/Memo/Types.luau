export type Ctx = { [string]: any }

export type DriveMode =
	| { kind: "time", duration: number }
| { kind: "frames", count: number }
| { kind: "gate", signal: any }
| { kind: "any", modes: { DriveMode } }
| { kind: "all", modes: { DriveMode } }

export type TrackSide = "server" | "client" | "shared"

export type TrackKind = "anim" | "hitbox" | "vfx" | "sfx" | "stat" | "brand" | "custom"

export type TrackDescriptor = {
	kind: TrackKind,
	side: TrackSide,
	data: { [string]: any },
	onEnter: ((ctx: Ctx) -> ())?,
	onExit: ((ctx: Ctx) -> ())?,
	onTick: ((ctx: Ctx, dt: number) -> ())?,
}

export type PhaseKind = "startup" | "active" | "recovery" | string

export type PhaseDescriptor = {
	name: PhaseKind,
	drive: DriveMode,
	tracks: { TrackDescriptor },
	onEnter: ((ctx: Ctx) -> ())?,
	onExit: ((ctx: Ctx) -> ())?,
	counter: CounterWindow?,
}

export type CancelWindow = {
	name: string,
	phase: PhaseKind,
	from: number?,
	to: number?,
	targets: { string }?,
	entryPhase: PhaseKind?,
}

export type BranchRoute = {
	from: string,
	to: string,
	crossfade: CrossfadeConfig?,
	entryPhase: PhaseKind?,
}

export type CrossfadeConfig = {
	mode: "hard" | "overlap" | "blend",
	duration: number?,
}

export type CounterWindow = {
	signal: any,
	resolver: ((ctx: Ctx, attacker: any) -> string?)?,
	onTriggered: ((ctx: Ctx, attacker: any) -> ())?,
	punishMove: string?,
	crossfade: CrossfadeConfig?,
}

export type HitboxController = {
	[string]: any,
}

export type PriorityTier = number | string

export type MoveSpec = {
	name: string,
	priority: PriorityTier,
	phases: { PhaseDescriptor },
	windows: { CancelWindow },
	routes: { BranchRoute },
	defaultCrossfade: CrossfadeConfig,
	tags: { string }?,
}

export type VariantResolver = (ctx: Ctx) -> string

export type VariantSpec = {
	name: string,
	variants: { [string]: MoveSpec },
	resolver: VariantResolver,
	tags: { string }?,
}

export type TimelineHandle = {
	interrupt: (crossfade: CrossfadeConfig?) -> (),
	cancel: (windowName: string, crossfade: CrossfadeConfig?) -> boolean,
	onPhaseChanged: any,
	onCompleted: any,
	onInterrupted: any,
	onCancelled: any,
	onCounter: any,
	getPhase: () -> PhaseKind?,
	isActive: () -> boolean,
}

return {}