# Moody

**A hierarchical state machine.** States nest with dot-notation (`"Combat.Aiming"`);
events drive transitions through guards, middleware, and enter/exit hooks that fire by
**lowest common ancestor** — moving between siblings doesn't re-enter the shared parent.
`post()`/`go()` return [Accede](../Accede) thenables.

## Define → spawn → drive

```lua
local Moody = require(ReplicatedStorage.Shared.Modules.Packages.Moody)

local Character = Moody.new("Idle")
    .state("Idle")
    .state("Combat", { onEnter = function() print("draw weapon") end })
    .state("Combat.Aiming", { tags = { "ranged" } })
    .state("Combat.Idle")
    .subscribe("engage", { from = "Idle",   to = "Combat.Idle" })
    .subscribe("aim",    { from = "Combat", to = "Combat.Aiming",
                           guard = function(ctx) return ctx.data.hasAmmo end })
    .subscribe("lower",  { from = "Combat.Aiming", to = "Combat.Idle" })
    .build()

local m = Character.spawn()
m.use(function(ctx, next) print(ctx.from, "->", ctx.to); next() end)  -- middleware

m.post("engage")
    :next(function(new) print("now in", new) end)
    :toss("Guarded", function() print("blocked!") end)

print(m.current(), m.is("Combat"))  -- "Combat.Idle"  true
```

## API

**Builder (dot-chain):** `Moody.new(initial)` · `.state(id, config?)` · `.subscribe(event, {from, to, guard?, action?})` · `.use(mw)` · `.build()`

`state` config: `{ tags, onEnter(ctx), onExit(ctx), onUpdate(ctx) }`.

**Machine:**
```lua
m.post(event, data?)   --> Accede  (finds a matching event+from transition)
m.go(stateId, data?)   --> Accede  (direct jump; still runs hooks/middleware)
m.current()            --> string
m.is(stateId)          --> boolean (true if current is, or is nested under, stateId)
m.tags()               --> { string }
m.use(mw)              -- mw(ctx, next): call next() to proceed, skip it to block
m.onTransition(fn)     --> disconnect  (fn(new, old, data))
m.snapshot() / m.restore(stateId)
```

**Rejection tags:** `NoTransition`, `Guarded`, `Halted`, `UnknownState` — catch them with
`:toss("Guarded", fn)`.

## Replication

The core is single-VM. "The server owns state, clients listen" is wired by connecting
`m.onTransition` to the network layer (broadcast new state) and giving clients a
read-only machine they `restore()` — that lands with the NetworkController pass.

---

<sub>Moody · Plinko Labs · builds on Accede</sub>
