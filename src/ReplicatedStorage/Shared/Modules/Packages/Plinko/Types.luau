local Types = {}

export type MiddlewareFn = (value: any, old: any) -> any
export type FilterFn = (player: Player, data: { [string]: any }) -> boolean

export type Config = {
	schema: { [string]: any },
	replicate: { [string]: "owner" | "all" }?,
	visibility: ("public" | "private")?,
	middleware: { [string]: MiddlewareFn }?,
	standalone: boolean?,
	save: {
		interval: number?,
		onLeave: boolean?,
	}?,
	onLoad: ((player: Player) -> any)?,
	onSave: ((player: Player, data: { [string]: any }) -> any)?,
}

export type Entry = {
	data: { [string]: any },
	defaults: { [string]: any },
	dirty: { [string]: any },
	locked: boolean,
	hidden: boolean,
	snapshots: { [string]: { [string]: any } },
	_onChange: any,
	_onFlush: any,
	_watches: { [string]: { any } },
}

export type Cache = {
	_config: Config,
	_name: string,
	_entries: { [any]: Entry },
	_standalone: boolean,

	_saveTimer: number,

	onAdded: any,
	onRemoving: any,
	onFlush: any,
	onError: any,

	_snapshots: { [any]: { [string]: any } },

	get: (self: Cache, keyOrPlayer: any, key: string?) -> any,
	set: (self: Cache, keyOrPlayer: any, key: string, value: any) -> (),
	increment: (self: Cache, keyOrPlayer: any, key: string, n: number?) -> (),
	patch: (self: Cache, keyOrPlayer: any, delta: { [string]: any }) -> (),
	reset: (self: Cache, keyOrPlayer: any, key: string) -> (),
	flush: (self: Cache, keyOrPlayer: any) -> any,
	loaded: (self: Cache, player: Player) -> boolean,
	await: (self: Cache, player: Player?) -> any,
	lock: (self: Cache, player: Player) -> (),
	unlock: (self: Cache, player: Player) -> (),
	hide: (self: Cache, player: Player) -> (),
	show: (self: Cache, player: Player) -> (),

	find: (self: Cache, fn: FilterFn) -> { [Player]: { [string]: any } },
	some: (self: Cache, fn: FilterFn) -> boolean,
	count: (self: Cache, fn: FilterFn?) -> number,

	setAll: (self: Cache, key: string, value: any) -> (),
	patchAll: (self: Cache, delta: { [string]: any }) -> (),
	flushAll: (self: Cache) -> any,
	resetAll: (self: Cache, key: string) -> (),

	dirty: (self: Cache, keyOrPlayer: any) -> { [string]: any },
	isDirty: (self: Cache, keyOrPlayer: any, key: string) -> boolean,
	clearDirty: (self: Cache, keyOrPlayer: any) -> (),

	snapshot: (self: Cache, keyOrPlayer: any, name: string) -> (),
	getSnapshot: (self: Cache, keyOrPlayer: any, name: string) -> { [string]: any }?,
	diff: (self: Cache, keyOrPlayer: any, name: string) -> { [string]: { old: any, new: any } },
	migrate: (self: Cache, keyOrPlayer: any, name: string) -> (),
	destroySnapshot: (self: Cache, keyOrPlayer: any, name: string) -> (),
	destroySnapshots: (self: Cache, keyOrPlayer: any) -> (),

	onChange: (self: Cache, playerOrFn: any, fn: ((key: string, new: any, old: any) -> ())?) -> any,
	onFlushFor: (self: Cache, playerOrFn: any, fn: ((dirty: { [string]: any }) -> ())?) -> any,
	watch: (self: Cache, keyOrPlayer: any, keyOrFn: any, fn: ((new: any, old: any) -> ())?) -> any,

	create: (self: Cache, id: any) -> (),
	exists: (self: Cache, id: any) -> boolean,
	release: (self: Cache, id: any) -> (),

	destroy: (self: Cache) -> (),
}

return Types