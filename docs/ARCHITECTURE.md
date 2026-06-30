# BVM Architecture

This document describes how the Brainrots vs. Monsters codebase is structured and
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
rojo build -o bvm.rbxlx   # one-off build
rojo serve                 # live sync into Studio
```

`bvm.rbxlx` is git-ignored; only source is committed.

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
    Config/        Grid, Economy, Wave, Plot + aggregator init
    Constants/     structural keys (save version, tags, phases, folder names)
    Types/         shared Luau type definitions
    Utilities/     Logger, GridUtil + aggregator init
    Brainrots/     data-driven Brainrot registry
    Monsters/      data-driven Monster registry
    Remotes/       single network-boundary definition

ServerScriptService/Server/            (init.server.luau = bootstrap)
    Services/
        PlotService/      (init + Plot + PlotBuilder)
        GridService/      (battlefield tile grid + occupancy)
        CoinService/      (init + GroundCoin)
        BrainrotService/  (init + BrainrotModel — placement & lifecycle)
        EnemyService/
        CombatService/
        WaveService/
        SaveService/

StarterPlayerScripts/Client/           (init.client.luau = bootstrap)
    Controllers/
        UIController/     (init + Shop — coin counter + shop HUD)
        CoinController/   (ground-coin pickup intent)
        PlacementController/ (selection, ghost preview, place/remove intent)
        GridController/   (hover highlight + tile resolver on own plot)
        CameraController/
        InputController/  (primary/secondary intent signals)

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
- **Types** — shared Luau types (`BrainrotDefinition`, `MonsterDefinition`,
  `Tile`, `PlantedBrainrot`, `SaveData`, status effects). No behavior.
- **Utilities** — reusable helpers: `Logger` (scoped print/warn) and `GridUtil`
  (pure, side-effect-free grid math usable on client and server — see
  `GRID.md`).
- **Brainrots / Monsters** — data-driven registries with `get`, `exists`,
  `getAll`. Behavior is resolved from data; never branch on names.
- **Remotes** — the single client/server boundary. See `NETWORKING.md`.

---

## Server vs. client ownership

| Server owns                                   | Client owns                       |
| --------------------------------------------- | --------------------------------- |
| Coins, damage, health, waves, spawning        | UI                                |
| Brainrot placement, saving, rewards           | Camera, input, animations         |
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
  folders. Lane layout left→right: house zone, play area (grid), enemy
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

### Milestone 2 — Grid System ✅

Full details in `GRID.md`. Summary:

- **GridService** (server, authoritative) builds a static `ROWS` × `COLUMNS`
  tile lawn into each plot's `Grid` folder at `start()` (after the plot pool is
  built), centered on the plot's `GridCenter` marker. The grid **fills the play
  area**: tile size is derived in `PlotConfig` from the lane depth, and the
  house/enemy strips are the reserved leftover lane length (the grid never covers
  them). Tiles are tagged `GridTile` with `Row`/`Column`/`Occupied` attributes.
  It tracks occupancy per plot and exposes `getTile`, `isOccupied`,
  `getWorldPosition`, `tryOccupy`, `release`, `resetPlot`. Tiles are reused
  across owners — `PlotService` calls `GridService.resetPlot` on release instead
  of rebuilding (the `Grid` folder is excluded from `Plot.release`'s wipe).
- **GridUtil** (shared, pure) is the single home for grid coordinate math, used
  identically on client (preview) and server (validation).
- **GridController** (client, visual only) highlights the hovered tile on the
  player's own plot, event-driven via `InputChanged`, colored by the tile's
  replicated `Occupied` attribute. No remotes — tiles and attributes replicate.

### Milestone 3 — Coin System ✅

Full details in `ECONOMY.md` / `NETWORKING.md`. Summary:

- **CoinService** (server, authoritative) owns every balance. It grants passive
  drops as collectible ground coins on each player's plot, validates
  `CollectCoin` intents (ownership / existence / distance) before crediting, and
  pushes `CoinsUpdated`. It answers `RequestState` with the balance and exposes
  `getBalance` / `addCoins` / `trySpend` for other services (wave rewards,
  placement costs). Coin parts are built by `CoinService/GroundCoin.luau`.
- **CoinController** (client) detects the local player touching their own coins
  and fires the `CollectCoin` intent — no balance logic.
- **UIController** (client) renders the coin counter from `CoinsUpdated` and the
  initial `RequestState` pull; it displays state only.

### Milestone 4 — Placement System ✅

Full details in `NETWORKING.md` / `UI.md` / `BRAINROTS.md`. Summary:

- **BrainrotService** (server, authoritative) owns Brainrot placement and
  instance lifecycle. It handles the `PlaceBrainrot` / `RemoveBrainrot` remotes,
  validating every step server-side: argument shapes + in-bounds, registry
  lookup (`Shared.Brainrots`, never name-branching), plot ownership
  (`PlotService`), affordability + spend (`CoinService`), and tile reservation
  (`GridService.tryOccupy`) — reserving the tile *before* charging so two
  requests can't claim one cell, and releasing it if the charge loses a race.
  Models are built by its `BrainrotModel` submodule (the `CoinService`/
  `GroundCoin` pattern) and tagged `Brainrot` with identity attributes. Removal
  is owner-checked and frees the tile **without a refund**. It clears a leaving
  player's instances. Public: `getPlacements(plotModel)`.
- **InputController** (client) centralizes input into `primaryAction` /
  `secondaryAction` intent signals (ignoring GUI-consumed input).
- **PlacementController** (client) owns selection, the cosmetic ghost preview
  (reusing `GridController.resolveTileAt`), and forwarding place/remove intent.
  It exposes `select`/`cancel`/`isPlacing` and a `selectionChanged` signal.
- **UIController** gains the **Shop** (`UIController/Shop.luau`): the registry
  roster with affordability, routing card clicks to `PlacementController` and
  mirroring its selection.

Dependency direction (no cycles): `UIController → PlacementController →
{GridController, InputController}`; `BrainrotService → {PlotService, GridService,
CoinService}`.

---

## Conventions

- **PascalCase**: modules, classes, services, folders.
- **camelCase**: variables, functions, parameters.
- **ALL_CAPS**: constants / config keys.
- `--!strict` everywhere; type public APIs.
- Prefer early returns; avoid nesting deeper than three levels.
- Prefer events over polling; disconnect connections when done; cache services.
- Freeze config/constant tables with `table.freeze`.
