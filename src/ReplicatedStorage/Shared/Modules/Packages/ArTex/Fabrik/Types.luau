

export type PromiseStatus = "pending" | "resolved" | "rejected" | "cancelled"
export type TaskStatus    = "pending" | "running" | "done" | "cancelled" | "failed"

export type Promise<T> = {
	next:     (self: Promise<T>, cb: (T) -> any) -> Promise<any>,
	catch:    (self: Promise<T>, cb: (any) -> ()) -> Promise<T>,
	conclude: (self: Promise<T>, cb: () -> ()) -> Promise<T>,
	cancel:   (self: Promise<T>) -> (),
	await:    (self: Promise<T>) -> (boolean, T),
	status:   (self: Promise<T>) -> PromiseStatus,
}

export type Signal<T> = {
	connect:      (self: Signal<T>, cb: (...any) -> ()) -> () -> (),
	once:         (self: Signal<T>, cb: (...any) -> ()) -> (),
	fire:         (self: Signal<T>, ...any) -> (),
	filter:       (self: Signal<T>, fn: (...any) -> boolean) -> Signal<T>,
	map:          (self: Signal<T>, fn: (...any) -> any) -> Signal<any>,
	merge:        (self: Signal<T>, other: Signal<any>) -> Signal<any>,
	pipe:         (self: Signal<T>, other: Signal<any>) -> (),
	promise:      (self: Signal<T>) -> Promise<T>,
	promiseWhere: (self: Signal<T>, fn: (...any) -> boolean) -> Promise<T>,
	toTask:       (self: Signal<T>, name: string) -> (),
	destroy:      (self: Signal<T>) -> (),
}

export type Atom<T> = {
	get:      (self: Atom<T>) -> T,
	set:      (self: Atom<T>, value: T) -> (),
	onChange: (self: Atom<T>, cb: (T, T) -> ()) -> () -> (),
	promise:  (self: Atom<T>) -> Promise<T>,
	derive:   (self: Atom<T>, fn: (T) -> any) -> Atom<any>,
}

export type Molecule = {
	get:      (self: Molecule) -> { [string]: any },
	patch:    (self: Molecule, values: { [string]: any }) -> (),
	onChange: (self: Molecule, cb: (string, any, any) -> ()) -> () -> (),
	promise:  (self: Molecule) -> Promise<any>,
}

export type Organism = {
	get:      (self: Organism) -> { [string]: any },
	patch:    (self: Organism, values: { [string]: any }) -> (),
	onChange: (self: Organism, cb: (string, string, any, any) -> ()) -> () -> (),
	promise:  (self: Organism) -> Promise<any>,
}

export type Cooldown = {
	start:    (self: Cooldown) -> (),
	reset:    (self: Cooldown) -> (),
	isReady:  (self: Cooldown) -> boolean,
	remaining:(self: Cooldown) -> number,
	promise:  (self: Cooldown) -> Promise<()>,
	andThen:  (self: Cooldown, fn: () -> ()) -> Cooldown,
	auth:     (self: Cooldown, handle: any) -> (),
	throttle: (self: Cooldown, fn: (...any) -> ()) -> (...any) -> (),
	debounce: (self: Cooldown, fn: (...any) -> ()) -> (...any) -> (),
}

export type TaskHandle = {
	next:     (self: TaskHandle, cb: (...any) -> ()) -> TaskHandle,
	catch:    (self: TaskHandle, cb: (any) -> ()) -> TaskHandle,
	conclude: (self: TaskHandle, cb: () -> ()) -> TaskHandle,
	await:    (self: TaskHandle) -> (boolean, ...any),
	status:   (self: TaskHandle) -> TaskStatus,
}

export type Latch = {
	await:   (self: Latch) -> (),
	open:    (self: Latch) -> (),
	reset:   (self: Latch) -> (),
	isOpen:  (self: Latch) -> boolean,
	promise: (self: Latch) -> Promise<()>,
}

export type Lock = {
	acquire:  (self: Lock) -> Promise<()>,
	release:  (self: Lock) -> (),
	withLock: (self: Lock, fn: () -> ()) -> Promise<()>,
}

export type Queue = {
	push:    (self: Queue, fn: () -> ()) -> (),
	pause:   (self: Queue) -> (),
	resume:  (self: Queue) -> (),
	clear:   (self: Queue) -> (),
	size:    (self: Queue) -> number,
	drained: Signal<()>,
}

export type IntervalHandle = {
	cancel: (self: IntervalHandle) -> (),
}

export type PromiseStatic = {
	new:        ((any, any) -> ()) -> Promise<any>,
	resolve:    (any) -> Promise<any>,
	reject:     (any) -> Promise<any>,
	all:        ({ Promise<any> }) -> Promise<{ any }>,
	any:        ({ Promise<any> }) -> Promise<any>,
	race:       ({ Promise<any> }) -> Promise<any>,
	allSettled: ({ Promise<any> }) -> Promise<{ { status: string, value: any } }>,
	delay:      (number) -> Promise<()>,
	retry:      (() -> Promise<any>, number, number?) -> Promise<any>,
	timeout:    (Promise<any>, number) -> Promise<any>,
	fromSignal: (Signal<any>) -> Promise<any>,
	fromEvent:  (Signal<any>, ((...any) -> boolean)?) -> Promise<any>,
	each:       ({ any }, (any) -> Promise<any>, number?) -> Promise<{ any }>,
}

export type ThreadStatic = {
	spawn:    ((...any) -> (), ...any) -> thread,
	defer:    ((...any) -> (), ...any) -> thread,
	delay:    (number, (...any) -> (), ...any) -> thread,
	sleep:    (number) -> (),
	pause:    () -> (),
	resume:   (thread, ...any) -> (),
	cancel:   (thread) -> (),
	current:  () -> thread,
	wrap:     ((...any) -> any) -> (...any) -> any,
	interval: (number, () -> ()) -> { cancel: () -> () },
	once:     (any, (...any) -> ()) -> (),
	race:     ({ thread }) -> Promise<any>,
}

export type TaskStatic = {
	define:   (string, (...any) -> any) -> (),
	batch:    ({ TaskHandle }) -> Promise<any>,
	schedule: (string, number) -> { cancel: () -> () },
	status:   (TaskHandle) -> TaskStatus,
	onError:  ((any, string) -> ()) -> (),
}

export type ConditionStatic = {
	till:     (() -> boolean, { interval: number? }?) -> Promise<()>,
	onChange: (() -> any, { interval: number? }?) -> Promise<any>,
}

export type Fabrik = {
	promise:   PromiseStatic,
	thread:    ThreadStatic,
	task:      TaskStatic,
	run:       (string, ...any) -> TaskHandle,
	defer:     (string, ...any) -> TaskHandle,
	spawn:     (string, ...any) -> TaskHandle,
	pool:      (number, { TaskHandle }) -> Promise<any>,
	chain:     (...string) -> Promise<any>,
	cancel:    (TaskHandle) -> (),
	queue:     { new: ({ concurrency: number? }?) -> Queue },
	lock:      { new: () -> Lock },
	memo:      { new: ((...any) -> any, { timeout: number? }?) -> any },
	condition: ConditionStatic,
	signal:    { new: () -> Signal<any> },
	cooldown:  { new: (number) -> Cooldown },
	atom:      (any) -> Atom<any>,
	batch:     (() -> ()) -> (),
	molecule:  { new: ({ [string]: Atom<any> }) -> Molecule },
	organism:  { new: ({ [string]: Molecule }) -> Organism },
	latch:     { new: () -> Latch },
}

return {}