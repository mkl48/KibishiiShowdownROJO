# Mixit

**A timeline-driven animation controller.** Turn one "all-in-one" animation into precise
game beats: carve the clip into named **scenes**, drop **stamps** that fire as the
**playhead** (0..1) crosses them, and **loop/pause** regions for combo timing.

## The M1 combo, wired

```lua
local Mixit = require(ReplicatedStorage.Shared.Modules.Packages.Mixit)

Mixit.define("M1Combo", {
    AnimationId = "rbxassetid://0000001",   -- optional: play the real clip, synced
    Duration = 0.9,                          -- seconds per pass when not track-synced
    Scene = {
        Windup   = { Start = 0,   End = 0.2 },
        Active   = { Start = 0.2, End = 0.5 },
        Recovery = { Start = 0.5, End = 1.0, Cut = true },  -- auto-cut at its end
    },
})

Mixit.stamp("M1Combo", "HitboxOpen",  0.2):next(function(f) Hitbox.open() end)
Mixit.stamp("M1Combo", "HitboxClose", 0.5):next(function(f) Hitbox.close() end)

local deck = Mixit.play("M1Combo", { Animator = humanoid.Animator })
deck.onScene:next(function(scene) print("scene:", scene) end)
deck:done():next(function() print("combo done") end)
```

Pass an `Animator` + `AnimationId` and the **real animation drives the playhead** (stamps
fire at exact clip frames). Omit them and the playhead is an abstract `Duration` timer.

## API

```lua
Mixit.define(name, { AnimationId?, Duration?, Speed?, Scene })  --> tape interface
Mixit.stamp(name, stampName, posOrScene, { Persistent? })       --> Hook (:next per cross)
Mixit.onCut(name)                                               --> Hook
Mixit.play(name, { Animator?, Pos?, Speed? })                   --> deck
Mixit.seek/cut/loop/tamper(name, ...)
Mixit.tape(name)            -- pre-bound { play, seek, cut, loop, stamp, onCut, tamper }
```

**Deck:** `deck.playhead` · `deck.scene` · `:seek(pos)` · `:setLoop(from, to)` ·
`:pause()` · `:resume()` · `:cut()` · `:done()` (Accede) · `deck.onScene` / `deck.onCut`.

`posOrScene` is a number **or** a scene name (resolves to that scene's `Start`).
**Hooks fire every cross** (across loops; non-persistent stamps re-arm on loop wrap).

---

<sub>Mixit · Plinko Labs · stamps/done build on Accede</sub>
