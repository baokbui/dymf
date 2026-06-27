# BVZ Architecture

This document describes how the Brainrots vs. Zombies codebase is structured and
the conventions every contributor (human or AI) must follow. It is the technical
companion to `GAME_DESIGN.md` (what the game is) and `ROADMAP.md` (build order).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Core principles

In priority order (from `.cursorrules`):

1. Maintainability
2. Readability
3. Scalability
4. Performance
5. Server authority

Supporting rules:

- Every major gameplay feature lives in its own **Service** (server) or
  **Controller** (client).
- No giant scripts. Target < ~300 lines per file; split into focused modules.
- Never duplicate logic — reused logic becomes a ModuleScript.
- Never hardcode gameplay values — they live in `Shared/Config`.
- Never trust RemoteEvents — the server validates everything.

---

## Tech stack

- Roblox Studio + Luau (`--!strict` in all modules)
- Rojo for filesystem ↔ Studio sync (`rojo 7.6.1`, pinned in `aftman.toml`)
- Cursor + Claude for development

Build the place from source:

```bash
rojo build -o bvz.rbxlx   # one-off build
rojo serve                 # live sync into Studio
```

`bvz.rbxlx` is git-ignored; only source is committed.

---

## Rojo project mapping

Defined in `default.project.json`:

| Filesystem        | Roblox location                                  |
| ----------------- | ------------------------------------------------ |
| `src/shared`      | `ReplicatedStorage.Shared`                       |
| `src/server`      | `ServerScriptService.Server` (Script)            |
| `src/client`      | `StarterPlayerScripts.Client` (LocalScript)      |
| (declared inline) | `StarterGui.MainUI` (Shop/Coins/WaveUI/Settings) |
| (declared inline) | `Workspace.{Plots, EnemyPaths, Maps}`            |

A folder containing `init.luau` becomes a single requireable ModuleScript with
its siblings as children. `init.server.luau` / `init.client.luau` become the
entry-point Script / LocalScript.

---

## Folder structure

```
ReplicatedStorage/Shared/
    Config/        Grid, Economy, Wave, Plot, Camera + aggregator init
    Constants/     structural keys (save version, tags, phases, folder names)
    Types/         shared Luau type definitions
    Utilities/     Logger, GridUtil + aggregator init
    Brainrots/     data-driven Brainrot registry
    Zombies/       data-driven Zombie registry
    Remotes/       single network-boundary definition

ServerScriptService/Server/            (init.server.luau = bootstrap)
    Services/
        PlotService/      (init + Plot + PlotBuilder)
        CoinService/
        BrainrotService/
        EnemyService/
        CombatService/
        WaveService/
        MergeService/
        SaveService/

StarterPlayerScripts/Client/           (init.client.luau = bootstrap)
    Controllers/
        UIController/
        PlacementController/
        CameraController/
        InputController/

Workspace/
    Plots/        plot models are generated here at runtime
    EnemyPaths/
    Maps/
```

---

## Bootstrap & lifecycle

Both bootstrappers auto-discover their modules — adding a Service/Controller
requires **no** bootstrap edits.

Two-phase lifecycle so cross-module references during startup are safe:

1. `init()` is called on **every** module first (one-time setup, no dependence
   on other modules being started).
2. `start()` is called on every module afterwards (connect events, begin
   runtime behavior).

Server bootstrap (`src/server/init.server.luau`) additionally calls
`Remotes.initServer()` before any service starts, so all RemoteEvents exist
before clients can reference them.

### Service / Controller contract

Each module returns a table shaped like:

```lua
local MyService = {}
MyService.Name = "MyService"
function MyService.init() end   -- optional
function MyService.start() end  -- optional
return MyService
```

Services may expose additional public functions (camelCase) for other services
to call, e.g. `PlotService.getPlot(player)`.

---

## Shared modules

- **Config** — all balancing/tuning. Frozen tables. Access via
  `require(Shared.Config)` (aggregated) or a specific submodule.
- **Constants** — structural, non-balancing identifiers (save version, DataStore
  name, CollectionService tags, phase names, Workspace folder names). Frozen.
- **Types** — shared Luau types (`BrainrotDefinition`, `ZombieDefinition`,
  `Tile`, `PlantedBrainrot`, `SaveData`, status effects). No behavior.
- **Utilities** — reusable helpers: `Logger` (scoped print/warn) and `GridUtil`
  (pure, side-effect-free grid math usable on client and server).
- **Brainrots / Zombies** — data-driven registries with `get`, `exists`,
  `getAll`. Behavior is resolved from data; never branch on names.
- **Remotes** — the single client/server boundary. See `NETWORKING.md`.

---

## Server vs. client ownership

| Server owns                                   | Client owns                       |
| --------------------------------------------- | --------------------------------- |
| Coins, damage, health, waves, spawning        | UI                                |
| Brainrot placement, merging, saving, rewards  | Camera, input, animations         |
| Plot assignment & ownership                   | Visual effects, sound playback    |

The client sends **intent**; the server **decides**. UI only displays state.

---

## Implemented so far

### Milestone 0 — Project Setup ✅

Full folder structure, Rojo config, documentation, empty Services/Controllers,
and shared Config/Constants/Types/Utilities/Remotes/registries.

### Milestone 1 — Player Plot System ✅

`PlotService` owns player battlefields:

- The world floor is one shared grass baseplate; plots are **lanes** of it,
  tiled in a `LANE_COLUMNS` × `LANE_ROWS` grid and divided by clear glass
  barriers. The pool is sized to fill the baseplate (`BASEPLATE_SIZE` /
  `POOL_MARGIN` in `PlotConfig`): usable area split across columns (X length)
  and rows (Z). Default: 12 plots as 2 columns × 6 rows.
- **PlotBuilder** procedurally builds each lane from `PlotConfig`: an invisible,
  non-colliding `Base` (region origin + future placement raycast target), a
  `Barriers` folder (clear glass `CanCollide` walls — North/South divide lanes,
  West/East are the field edges), a `SpawnLocation` at the play area's left edge
  facing the enemy (+X), `HouseAnchor` (−X, behind player) / `EnemySpawn` (+X) /
  `CoinSpawner` attachment markers, and empty `Grid` / `Path` / `Decorations`
  folders. Lane layout left→right: house zone, play area (grid, later), enemy
  zone.
- **Plot** (class) tracks `ownerUserId` and provides reuse cleanup (`release`
  clears dynamic folders; plots are reused, never destroyed).
- **PlotService** builds a fixed pool of `MAX_PLOTS` lanes at startup, tiled in
  a columns × rows grid centered on the baseplate. It assigns a unique free plot
  per player and spawns them on it: auto-spawn is disabled
  and each plot has a `SpawnLocation` that the player's `RespawnLocation` is
  pointed at, so spawns/respawns land on the plot (no teleport race). Plots are
  released/cleaned on leave.
- **CameraController** intentionally leaves the default Roblox third-person
  camera in place (scroll to first person).

Public API: `PlotService.getPlot(player)`, `PlotService.getPlotModel(player)`.

---

## Conventions

- **PascalCase**: modules, classes, services, folders.
- **camelCase**: variables, functions, parameters.
- **ALL_CAPS**: constants / config keys.
- `--!strict` everywhere; type public APIs.
- Prefer early returns; avoid nesting deeper than three levels.
- Prefer events over polling; disconnect connections when done; cache services.
- Freeze config/constant tables with `table.freeze`.
