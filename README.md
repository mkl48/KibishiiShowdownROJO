# Kibishii Showdown — Rojo project

The **code** of Kibishii Showdown as a [Rojo](https://rojo.space) project, generated
faithfully from the Studio place (160 scripts, byte-for-byte). A Gachiakuta-inspired
battlegrounds game built on **Junky** (SSJA), with **Memo** driving skills.

## What's here / what isn't

- **Here:** every script + the folder/class structure that holds it, under
  `src/<Service>/…`. `rojo build` reproduces all code exactly.
- **Not here:** built assets (Workspace geometry, the Umbreaker model, Rudo's anim rig,
  Lighting, RemoteEvents, Values). Those live in the **place** and the **RoGit** mirror
  ([KibishiiShowdownROGIT](https://github.com/mkl48/KibishiiShowdownROGIT)). Each service
  is mapped with `$ignoreUnknownInstances: true`, so `rojo serve` overlays code into your
  place **without deleting** those assets.

## Use it

```sh
rokit install     # rojo / wally / lune
rojo serve        # then connect the Rojo plugin in Studio
```

## Layout

```
src/
  ReplicatedStorage/   Shared (Modules, Classes/Characters) + Client modules + packages
  ServerScriptService/ ServerBootstrap
  ServerStorage/       Modules/Managers, server Services, Keep
  StarterPlayer/       Start*Scripts
  StarterGui/
```

Regenerated from the place with `scripts/` (Lune). Architecture: one `Config` +
`Bootstrap` (SSJA/Junky), domains as Controller/Manager/Service trios, characters under
`Shared.Classes.Characters.<Name>` with a `Manifest` + `Moveset` of Memo-built moves.
