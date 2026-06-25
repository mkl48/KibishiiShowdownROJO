# Network

**The messaging core — the simpler replacement for Junky's Junction.** No central routing
table to declare, no Network-vs-Local guessing: a channel is just a `"Domain.Event"`
string, and **direction lives in the method name**.

```lua
local Net = require(ReplicatedStorage.Shared.Modules.Packages.Network)
```

## Direction is in the name

| Client | Server |
|---|---|
| `Net:ToServer("Combat.Swing", hit)` | `Net:OnClient("Combat.Swing", function(plr, hit) end)` |
| `Net:OnServer("Combat.Hit", fn)` | `Net:ToClient(plr, "Combat.Hit", result)` |
| | `Net:ToAll("Round.Begin", payload)` |
| | `Net:ToAllExcept(plr, "Effect.Play", vfx)` |
| `Net:Ask("Character.List"):next(fn)` | `Net:Answer("Character.List", function(plr) return list end)` |

Same side, in-process (replaces the old `Local` namespace):

```lua
Net:Signal("Input.Pressed", "M1")
Net:OnSignal("Input.Pressed", function(action) end)
```

`Ask` returns an **Accede** thenable (`:next`/`:toss`). Every `On*`/`OnSignal`/`Answer`
returns a disconnect function.

## Why it's simpler than the Junction

- **No declaration step.** The old way needed every event written into `Config.Junction`
  with a `Destination` + `Side`. Here you just send/receive on a channel.
- **No destination filtering to reason about.** Any module can listen to a channel.
- **Side-aware by construction.** Requiring it gives you the right side's role — the
  client instance is your *NetworkController*, the server instance your *NetworkManager*.
  Calling a wrong-side method (`ToServer` on the server) asserts loudly.

It wires its own `RemoteEvent` + `RemoteFunction` once, and routes by channel.

## Migrating off Junky (incremental)

You don't have to rip out Junky at once. Junky still owns the **module lifecycle**
(discovery, `:Start`, boot order). Replace messaging per domain:

| Junky | Network |
|---|---|
| `context:Network("Combat"):Post("Swing", d)` | `Net:ToServer("Combat.Swing", d)` |
| `context:Network("Combat"):PostTo(plr, "Hit", r)` | `Net:ToClient(plr, "Combat.Hit", r)` |
| `Network:Subscribe("Hit", fn)` (server) | `Net:OnClient("Combat.Hit", fn)` |
| `context:Network("X"):Request("Q"):Next(fn)` | `Net:Ask("X.Q"):next(fn)` |
| `context:Local("Input"):Post("Pressed", a)` | `Net:Signal("Input.Pressed", a)` |

---

<sub>Network · Plinko Labs · requests build on Accede</sub>
