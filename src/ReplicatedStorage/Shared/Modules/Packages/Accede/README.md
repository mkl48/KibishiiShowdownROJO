# Accede

**The async primitive for the game — "the new Promise."** Self-contained (no Promise/Signal
dependency), because Moody, Mixit, Plinko, and the network layer all build on it.

## Why not just a Promise?

Three things it does that a plain promise doesn't:

- **Typed error channels** — `:toss("NetworkError", fn)` handles *only* that tag; other
  errors keep falling through to a later `:toss`. No more one giant catch-all.
- **Structured cancellation** — a `token` cancels a whole chain at once; `:link(inst)`
  cancels when a Roblox instance dies; `:timeout(s)` cancels on time.
- **One terminal** — `:conclude(fn)` always runs with a structured result (success or not).

## Quick start

```lua
local Accede = require(ReplicatedStorage.Shared.Modules.Packages.Accede)

local fetch = Accede.wrap(function(userId)
    return DataStore:GetAsync(userId)   -- a yielding call
end)

fetch(player.UserId)
    :next(function(profile) return profile.level * 100 end)
    :toss("DataStoreError", function(err) warn("store failed:", err) end)
    :fallback(0)
    :conclude(function(r) print(r.status, r.value) end)
```

## API

```lua
Accede.new(executor, token?)   -- executor(resolve, reject, progress)
Accede.wrap(fn)                -- -> a function returning an Accede
Accede.resolve(v) / Accede.reject(err, tag?)
Accede.token()                 -- -> { :cancel(), :isCancelled(), :onCancel(fn) }
Accede.all(list) / any(list) / race(list)

a:next(fn)                     -- on success; chain a value or another Accede
a:toss(fn) | a:toss(tag, fn)   -- on failure; tagged = only that error channel
a:subscribe(fn)                -- observe progress / settle
a:conclude(fn)                 -- terminal: fn({ status, value, error, tag })
a:timeout(s) | a:link(inst) | a:fallback(v) | a:cancel() | a:await()
```

`:await()` yields and returns `(true, value)` or `(false, err, tag)`.

## Roadmap (v0.2)

`retry`/`retryWith` backoff, `batch`/`waterfall`/`reduce`, signal bridging
(`fromSignalWhere`), and the hot-push Subject API — the core above lands first.

---

<sub>Accede · Plinko Labs</sub>
