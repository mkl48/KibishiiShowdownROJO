# Splint

**Server-authoritative, client-visual ragdoll for Roblox (R6 + R15).**

Define a ragdoll recipe once, apply it to any character to get a live `Handle` you can
recover, auto-recover, or stream. This is the **core** build — `Classic` and `Active`
controllers, the joint engine, velocity inheritance, collision grouping, and a
snapshot/stream layer. The wider Splint feature set (more controllers, splice/dismember,
deform, trajectory, zones) layers on top of this spine.

## Quick start

```lua
local Splint = require(ReplicatedStorage.Shared.Modules.Packages.Splint)

Splint.define("Death", { type = "Classic", joints = "all",
    inheritVelocity = true, collisions = true })

local rag = Splint.apply("Death", character)   -- run on the SERVER
rag.OnRecovered:Connect(function() print("up!") end)
task.delay(3, function() rag:recover() end)
```

A knockback stagger that fights upright and recovers itself:

```lua
Splint.apply({
    type = "Active",
    joints = { "RightHip", "LeftHip", "Waist" },
    inheritVelocity = true,
    collisions = true,
    autoRecover = 1.2,
    uprightForce = 6000,
}, character)
```

## Controllers

| Type | Behaviour |
| --- | --- |
| **Classic** | Full limp — every masked joint goes loose, the character faints. |
| **Active** | Limp joints **plus** an `AlignOrientation` on the root fighting toward upright, so knockback staggers and recovers instead of fully KO-ing. |

## Config

| Key | Default | Meaning |
| --- | --- | --- |
| `type` | `"Classic"` | Controller behaviour. |
| `joints` | `"all"` | `"all"` or a list of Motor6D names to limp (the rest stay rigid). |
| `inheritVelocity` | `true` | Carry the character's momentum into the loose limbs. |
| `collisions` | `true` | Limbs collide with the world; self-collision is off (one group). |
| `autoRecover` | `nil` | Seconds, then auto-`recover()`. `nil` = manual. |
| `uprightForce` | `6000` | Active only — `AlignOrientation` torque toward upright. |

## How it works

- **Joint engine** (`Rig`): each `Motor6D` is mirrored as two `Attachment`s at its
  `C0`/`C1` and joined by a `BallSocketConstraint` with per-joint cone limits; the motor
  is disabled. `recover()` destroys the constraints and re-enables the motors. Discovery
  walks the character, so R6 and R15 both work.
- **Authority:** on `engage` the server takes `SetNetworkOwner(nil)` of the assembly, so
  the server's physics is the truth and Roblox replicates it. `Handle:startStreaming` is
  the optional precision layer — sample limb CFrames → your transport → `applySnapshot`.

## Handle API

```lua
handle:recover()                       -- restore the rig
handle:startStreaming(send, rate?)     -- server: stream snapshots at `rate` Hz
handle:destroy()                       -- recover + drop listeners
handle.Active                          -- boolean
handle.OnEngaged / handle.OnRecovered  -- Signals
Splint.applySnapshot(character, snap)  -- client: apply a streamed snapshot
```

---

<sub>Splint · core · Plinko Labs</sub>
