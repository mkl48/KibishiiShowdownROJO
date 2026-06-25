local Promise   = require(script.Promise)
local Thread    = require(script.Thread)
local Task      = require(script.Task)
local Queue     = require(script.Queue)
local Lock      = require(script.Lock)
local Memo      = require(script.Memo)
local Condition = require(script.Condition)
local SignalMod = require(script.Signal)
local Cooldown  = require(script.Cooldown)
local AtomMod   = require(script.Atom)
local Molecule  = require(script.Molecule)
local Organism  = require(script.Organism)
local Latch     = require(script.Latch)
local Types     = require(script.Types)

type PromiseStatus = Types.PromiseStatus
type TaskStatus    = Types.TaskStatus
type Promise<T>    = Types.Promise<T>
type Signal<T>     = Types.Signal<T>
type Atom<T>       = Types.Atom<T>
type MoleculeType  = Types.Molecule
type OrganismType  = Types.Organism
type CooldownType  = Types.Cooldown
type TaskHandle    = Types.TaskHandle
type LatchType     = Types.Latch
type LockType      = Types.Lock
type QueueType     = Types.Queue

export type PromiseStatus = Types.PromiseStatus
export type TaskStatus    = Types.TaskStatus
export type Promise<T>    = Types.Promise<T>
export type Signal<T>     = Types.Signal<T>
export type Atom<T>       = Types.Atom<T>
export type Molecule      = Types.Molecule
export type Organism      = Types.Organism
export type Cooldown      = Types.Cooldown
export type TaskHandle    = Types.TaskHandle
export type Latch         = Types.Latch
export type Lock          = Types.Lock
export type Queue         = Types.Queue

local Fabrik = {}

-- Promise (callable table so both Fabrik.promise(fn) and Fabrik.promise.resolve(v) work)
local promise = {
	new        = Promise.new,
	resolve    = Promise.resolve,
	reject     = Promise.reject,
	all        = Promise.all,
	any        = Promise.any,
	race       = Promise.race,
	allSettled = Promise.allSettled,
	delay      = Promise.delay,
	retry      = Promise.retry,
	timeout    = Promise.timeout,
	fromSignal = Promise.fromSignal,
	fromEvent  = Promise.fromEvent,
	each       = Promise.each,
}
setmetatable(promise, { __call = function(_, ...) return Promise.new(...) end })
Fabrik.promise = promise

-- Thread
Fabrik.thread = Thread

-- Task
Fabrik.task = {
	define   = Task.define,
	batch    = Task.batch,
	schedule = Task.schedule,
	status   = Task.status,
	onError  = Task.onError,
}

Fabrik.run    = Task.run
Fabrik.defer  = Task.defer
Fabrik.spawn  = Task.spawn
Fabrik.pool   = Task.pool
Fabrik.chain  = Task.chain
Fabrik.cancel = Task.cancel

-- Modules
Fabrik.queue     = Queue
Fabrik.lock      = Lock
Fabrik.memo      = Memo
Fabrik.condition = Condition
Fabrik.signal    = SignalMod
Fabrik.cooldown  = Cooldown

Fabrik.atom      = AtomMod.new
Fabrik.batch     = AtomMod.batch
Fabrik.molecule  = Molecule
Fabrik.organism  = Organism
Fabrik.latch     = Latch

-- Inject fabrik reference into modules that need it (breaks circular dependency)
SignalMod._init(Fabrik)

return Fabrik