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
| (declared inline) | `StarterGui.MainUI` (Shop / Coins / Brains / Speed / Hearts / LevelUI / Settings / Inventory / popups / ProgressionStore) |
| (declared inline) | `Workspace.{Plots, EnemyPaths, Maps}`            |

A folder containing `init.luau` becomes a single requireable ModuleScript with
its siblings as children. `init.server.luau` / `init.client.luau` become the
entry-point Script / LocalScript.

---

## Folder structure

```
ReplicatedStorage/Shared/
    Config/        Grid, Economy, Level, Plot, Progress, Store, House, Weather, Audio, UI + aggregator init
    Constants/     structural keys (save version, tags, phases, folder names)
    Types/         shared Luau type definitions
    Utilities/     Logger, GridUtil, WeatherUtil + aggregator init
    Brainrots/     data-driven Brainrot registry
    Monsters/      data-driven Monster registry
    Levels/        data-driven campaign level registry
    Remotes/       single network-boundary definition

ServerScriptService/Server/            (init.server.luau = bootstrap)
    Services/
        PlotService/      (init + Plot + PlotBuilder)
        GridService/      (battlefield tile grid + occupancy)
        CoinService/      (init + GroundCoin)
        MagnetService/    (player magnet pull + cooldown)
        BrainrotService/  (init + BrainrotModel, BrainrotBehavior, BrainrotAnimation, Abilities, BrainrotFeedback)
        EnemyService/     (init + MonsterModel, MonsterBehavior, Abilities, MonsterFeedback)
        CombatService/
        GraveService/     (fog graves → Zombie/Skeleton emerge)
        LevelService/
        SaveService/
        StoreService/     (Progression Store prompts — M18)
        ProgressService/  (brains, unlocks, loadout, upgrades, statistics)

StarterPlayerScripts/Client/           (init.client.luau = bootstrap)
    Controllers/
        UIController/     (init + Shop, HUD counters, Level, Settings, Inventory, ProgressionStore, popups)
        CoinController/   (ground-coin pickup intent + sparkle — M3/M11)
        PlacementController/ (selection, ghost preview, place/remove intent)
        GridController/   (hover highlight + tile resolver on own plot)
        CameraController/
        InputController/  (primary intent + magnet 1)
        BrainrotController/ (BrainrotAction SFX; ScaleTo pulse; world nameplates)
        CombatController/ (CombatVisual VFX + SFX — M11/M12)
        AudioController/  (weather + boss BGM, SFX via SfxPlayer — M12)
        StoreController/  (hide other players' store Talk prompts — M18)
        WeatherController/ (night/fog + desert pyramids)
    Utilities/
        VfxUtil/          (ephemeral particles — M11)
        PlotUtil/         (local plot helpers — M11)
        TextShine.luau    (shared rarity-title gleam)

Workspace/
    Plots/        plot models are generated here at runtime
    EnemyPaths/
    Maps/
    ProgressionStores/  per-plot clones (runtime)
```

`ReplicatedStorage.Assets.Stores` holds mini-store **templates**.

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
- **Brainrots / Monsters / Levels** — data-driven registries with `get`,
  `exists`, `getAll` (Levels also exposes `getByNumber` / `getOrdered`).
  Behavior and campaign content are resolved from data; never branch on names
  or level numbers.
- **Remotes** — the single client/server boundary. See `NETWORKING.md`.

---

## Server vs. client ownership

| Server owns                                   | Client owns                       |
| --------------------------------------------- | --------------------------------- |
| Coins, brains, store spends, damage, health, levels, spawning | UI, camera, input                 |
| Brainrot placement, saving, rewards, unlocks / loadout        | SFX, particles, UI juice          |
| Unit Animator tracks (idle / attack / walk)   | Placement ghost / shop previews   |
| Plot assignment & ownership                   |                                   |

The client sends **intent**; the server **decides**. UI only displays state.

---

## Implemented so far

### Milestone 0 — Project Setup ✅

Full folder structure, Rojo config, documentation, empty Services/Controllers,
and shared Config/Constants/Types/Utilities/Remotes/registries.

### Milestone 1 — Player Plot System ✅

`PlotService` owns player battlefields:

- The world floor is one shared grass baseplate; **player plots** tile the west
  column in `LANE_ROWS` stacked lanes (**no collision barriers** — players may
  walk between plots to spectate). The east column holds **enemy-spawn lanes**
  (`EnemySpawnBuilder`) aligned with each player row — no player grids on that
  side. The pool is sized to fill the baseplate (`BASEPLATE_SIZE` / `POOL_MARGIN`
  in `PlotConfig`): usable area split across `MAP_COLUMNS` (west = plots, east =
  enemy spawn) and `LANE_ROWS`. Default: 6 player plots + 6 enemy lanes
  (6 rows × 2 columns).
- **PlotBuilder** procedurally builds each player lane from `PlotConfig`: an
  invisible, non-colliding `Base` (region origin + placement raycast target), a
  `SpawnLocation` at the play area's left edge facing the enemy (+X),
  `HouseAnchor` (−X) / `CoinSpawner` markers, a walkable **`House`** cottage
  (`HouseBuilder` + `HouseConfig`; Toolbox model under `Assets.Houses` when
  present, procedural fallback) with boss pedestals for Milestone 21, and
  empty `Grid` / `Path` / `Decorations` folders. Lane layout left→right: house
  zone (cottage + yard), play area (grid). Monsters stage in the matching
  east-column `EnemyLane` (`EnemySpawn` attachment at its west edge).
- **ForestBuilder** fills the east column with `Workspace.Maps.DarkForest` —
  dark grass floor + procedural trees (non-colliding). A clear strip near the
  plot boundary keeps monster entry / spawn readable. **Desert** days hide that
  forest on the local client and spawn pyramids instead (`WEATHER.md`).
- See **`HOUSE.md`** for cottage layout and the planned boss-collection loop.
- Gameplay isolation is **server-validated**, not physical: plant / shovel /
  coin collect / Progression Store only succeed on the acting player's own plot
  (and own coins / own stalls).
  Players **phase through monsters** (`CollisionUtil` / `BvmPlayers` ×
  `BvmMonsters`); monster parts also stay `CanCollide = false`.
- **Plot** (class) tracks `ownerUserId` and provides reuse cleanup (`release`
  clears dynamic folders; plots are reused, never destroyed).
- **PlotService** builds a fixed pool of `MAX_PLOTS` lanes at startup, tiled in
  a columns × rows grid centered on the baseplate. It assigns a unique free plot
  per player and spawns them on it: auto-spawn is disabled
  (`CharacterAutoLoads = false`) and each plot has a `SpawnLocation` that the
  player's `RespawnLocation` is pointed at. Join and post-death respawns both
  call `LoadCharacter` so Reset Character works (no teleport race). Plots are
  released/cleaned on leave.
- **CameraController** intentionally leaves the default Roblox third-person
  camera in place (scroll to first person).

Public API: `PlotService.getPlot(player)`, `PlotService.getPlotModel(player)`,
`PlotService.getEnemyLane(rowIndex)`, `PlotService.getEnemyLaneForPlot(plot)`.

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
  pushes `CoinsUpdated`. `LevelService` answers `RequestState` with coins and
  level state; `CoinService` exposes
  `getBalance` / `resetBalance` / `trySpend` for other services (level resets,
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
  `GroundCoin` pattern) and tagged `Brainrot` with identity attributes. Visuals
  clone Templates from `ReplicatedStorage.Assets.Brainrots` via
  `Shared.Utilities.ModelUtil` (Milestone 15; Part placeholder if missing).
  Removal
  is owner-checked and frees the tile **without a refund**. It clears a leaving
  player's instances. Public: `getPlacements(plotModel)`.
- **InputController** (client) centralizes input into `primaryAction` and
  `magnetAction` (key **1**) intent signals (ignoring GUI-consumed input).
- **PlacementController** (client) owns selection, the cosmetic ghost preview
  (reusing `GridController.resolveTileAt`; clones Assets templates when present),
  and forwarding place/remove intent.
  It exposes `select`/`cancel`/`isPlacing` and a `selectionChanged` signal.
- **UIController** gains the **Shop** (`UIController/Shop.luau`): the registry
  roster with affordability, routing card clicks to `PlacementController` and
  mirroring its selection.

Dependency direction (no cycles): `UIController → PlacementController →
{GridController, InputController}`; `BrainrotService → {PlotService, GridService,
CoinService}`.

The Shop is a **PvZ-style horizontal bar** docked to the top of the screen. Each
Brainrot is a portrait card (swatch → name → cost). Layout constants live in
`UIController/Shop.luau`; the ghost footprint is `PlotConfig.BRAINROT_FOOTPRINT_RATIO`
(shared by `BrainrotModel` and `PlacementController`).

### Milestone 5 — Brainrot Framework ✅

Full details in `BRAINROTS.md`. Summary:

- **`Shared.Brainrots`** — seven data-driven roster entries (replaces the M4
  Shooter / Money Generator placeholders). Stats use hit-based health, tile
  range, and `attackInterval` (seconds between actions).
- **`Shared.Config.BrainrotConfig`** — global knobs (`FULL_LINE_RANGE`,
  `BEHAVIOR_TICK`, attack pulse, sound keys).
- **`BrainrotService/Abilities/`** — one handler module per ability id;
  `BrainrotBehavior` resolves handlers from `definition.ability`.
- **`BrainrotBehavior`** — server tick loop for cooldowns; calls `tryAct` /
  `onPlaced`; ticks claimed evolution extras even when `attackInterval <= 0`;
  routes combat through `CombatService`, coins through
  `CoinService.dropCoinForOwner`.
- **`BrainrotAnimation`** — server idle/attack Animator tracks for
  `definition.animated` units (replicates Motor6D poses; same idea as
  `MonsterAnimation`).
- **`BrainrotFeedback`** — ScaleTo attack pulse (skipped when `animated`) +
  replicated hit flash on damage + rarity-tinted Super Saiyan aura.
- **`BrainrotController`** (client) — plays sounds from `BrainrotAction`
  pushes; ScaleTo pulse only for non-animated melee (gameplay stays server-side).
- **`CombatService`** — row-based Brainrot attacks + monster damage/death (M6).
  Full combat: projectiles, target acquisition, status effects (M7).

### Milestone 6 — Monster Framework ✅

Full details in `MONSTERS.md`. Summary:

- **`Shared.Monsters`** — eleven data-driven entries (replaces BasicMonster).
  Movement uses `secondsPerGrid`; attacks use `attackInterval`.
- **`Shared.Config.MonsterConfig`** — behavior tick, spawn column, dev test spawns.
- **`EnemyService`** — `spawn`, `MonsterBehavior` grid movement, attack-on-tile,
  `Abilities/` handlers (Goblin Elite one-shot, Spider jump, Necromancer summon, …).
- **`MonsterModel`** / **`MonsterFeedback`** — models clone from
  `Assets.Monsters` via `ModelUtil` (M16; Part fallback); pulse / hit flash /
  freeze / bubble feedback on the model.
- **`CombatService`** — wired to `EnemyService` for `damageMonster`, row queries,
  and status effects.
- **`GridService.getWorldPositionAtColumn`** — fractional column positioning.
- Opening levels now spawn **Zombie**. Campaign spawns come from `LevelService`
  (`MonsterConfig.DEV_SPAWN` stays off for play).

### Milestone 7 — Combat System ✅

Full details in `COMBAT.md`. Summary:

- **`Shared.Config.CombatConfig`** — projectile speed, DoT ticks, death timings.
- **`CombatService`** — `attackFirstInRow`, `attackInRow`, `dealEntireRowDamage`,
  `launchProjectile`, status APIs; `Projectile` submodule.
- **`EnemyService/MonsterStatus`** — Slow / Poison / Burn / Knockback on monsters.
- **`CombatController`** (client) — visuals only.
- **`CombatVisual`** remote — plot-owner feedback for hits and deaths.

### Milestone 8 — Level System ✅

Full details in `LEVELS.md`. Summary:

- **`LevelService`** — preparation → Start Day → Active (monsters stage in the
  forest, then enter the plot); spawn groups via `LevelRun` scheduler;
  victory keeps planted Brainrots and resets coins via day purse; defeat
  restores the victory checkpoint on the same day (Game Over → Rewind); day
  select wipes the lawn + checkpoint; `LevelStateChanged` remote.
- **`LevelService/LevelRun`** — spawn-group timing, big-wave warning, random rows.
- **`UIController/Level.luau`** — bottom-right day title, Start Day button, progress bar, big-wave banner.
- **`UIController/GameOverPopup.luau`** — defeat overlay + Rewind Day N.
- **`EnemyService.setHouseBreachHandler`** — defeat on house breach.
- **`MonsterConfig.DEV_SPAWN.ENABLED = false`** — campaign spawns replace dev waves.

### Milestone 9 — Save System ✅

Full details in `SAVE_SYSTEM.md`. Summary:

- **`SaveService`** is now the sole DataStore boundary (`BVZ_PlayerData_v1`), with
  versioned load/migrate/save logic.
- Player progression (`currentLevel`, `highestLevel`, `brains`, `playerHealth`,
  committed lawn Brainrots, unlocks, loadout, statistics) persists on leave,
  autosave, and victory/defeat.
- Lawn is a **victory checkpoint** (`commitLawn` / `clearCommittedLawn` /
  `restoreCommittedLawn`); mid-day
  plants are not written until the day is won. Concurrent saves queue a resave.
- Match coins always reset via `applyDayPurse` on join (not stored as balance).
- Restore flow: `LevelService.applySaveProgress`, `CoinService.applyDayPurse`,
  `BrainrotService.restorePlacements` (committed list).
- Transient state remains unsaved: mid-day plants, monsters, projectiles, ground
  coins, temporary combat status, and active level timers.

### Milestone 10 — Additional Monsters ✅

Full details in `MONSTERS.md` / `LEVELS.md`. Summary:

- Campaign content in `Shared.Levels` now includes Levels 4–10.
- **One** new non-boss monster (`Goblin`) is introduced at Level 5; Levels 6–9
  mix only `Zombie` + `Goblin` with a slow difficulty ramp.
- **One** boss (`GoblinElite`) is introduced at Level 10 as the big final wave.
- Cadence repeats every 5 / 10 levels when more campaign content is authored.
- All additions are data-driven level entries; no changes to base enemy AI/service
  architecture were required.

### Milestone 11 — Visual Effects ✅

Full details in `COMBAT.md`. Summary:

- **`VfxConfig`** — client VFX tuning (burst counts, colors, trail lifetime).
- **`VfxUtil`** + **`PlotUtil`** (client utilities) — ephemeral particles and plot helpers.
- **`CombatController`** — hit/death particles, line-bomb explosions (`Explosion`
  payload), projectile trail/glow on `plot.Projectiles` parts.
- **`CoinController`** — gold pickup sparkle when a collected coin despawns.
- Server still owns combat; visuals are pushed via `CombatVisual` or derived from
  replicated instances (projectiles, coin removal).

### Milestone 13 — UI Polish ✅

Full details in `UI.md`. Summary:

- **`ProgressService`** + **`ProgressConfig`** — brains, unlocks, equipped loadout,
  statistics; `ProfileUpdated` / `SetEquipped` remotes. Stats increment broadcasts
  immediately; support-job XP coalesces (`XP_BROADCAST_INTERVAL`). Time played includes the live session in client payloads. Join
  hydrate is synchronous from `SaveService` so defaults cannot wipe saved stats.
  Starter roster unlocks only 3 Brainrots by default (`DEFAULT_UNLOCKS`); the
  rest of the launch seven unlock via `UNLOCK_SCHEDULE`
  (`grantUnlockForLevel`, called from `LevelService.onVictory`) — see
  `BRAINROTS.md`.
- **Hearts HUD** — 5 house hearts at top-left (no chip); LevelService −1 per breach, defeat at 0.
- **Settings** — bottom-left HUD button; mute, volume steps, Brainrot SFX toggle,
  statistics, double-confirm Reset Progress. Level Select deferred to a later UI.
- **Inventory** — bottom-left HUD button (above Settings) + modal; click a packet
  for a shared inspect card on the right (portrait + HP / level / XP bar,
  stats + gray/lit evolutions, Equip / Equipped). Clicking a planted unit
  on your lawn opens the same card with live HP.
- **Reward popup** — victory shows brains earned (store purchases → M18).
- Save schema **v5** (`SAVE_SYSTEM.md`) includes brains, equipped, upgrades, intro lists, and `brainrotXp`.

### Milestone 18 — Progression Store ✅

Full details in `STORE.md` / `UI.md`. Summary:

- **`StoreService`** + **`StoreConfig`** — clone blue/red mini stores beside each
  plot house; owner-only ProximityPrompt → `OpenProgressionStore`. Overlay closes
  past `CLOSE_DISTANCE` from the mascot. `BuyStoreItem` requires the caller at
  their own stall.
- **`ProgressService`** validates `BuyStoreItem` (own shop range, brains spend, catalog, owned /
  max level). Catalogs in `ProgressConfig.STORE_CATALOG` (Girafa Celestre) and
  `UPGRADE_CATALOG` (WalkSpeed, 20 ranks; Magnet 1–5). Speed applied on spawn / rejoin via
  `PlotService` + `ProgressService.getWalkSpeed`.
- **`UIController/ProgressionStore`** — list + stats card to the right; kaching /
  stacked error banners. HUD: mid-left Coins / Brains / Speed glyphs; Inventory +
  Settings bottom-left with Magnet square to the right.

### Milestone 19 — Brainrot leveling + evolutions 🔜

Full details in `EVOLUTIONS.md` / `ROADMAP.md`. Summary:

- Each roster Brainrot has its own **Brainrot level** (XP), **not** campaign day.
- At 10 / 20 / 30 / 40 / 50: Epic → Immortal (aura + stat / active / passive /
  ultimate). Tiers stack; base shop id stays.
- Persist level + XP + owned tiers via `SaveService`. Combat extras stay
  data-driven ability ids.
- **XP (live):** last-hit species for normal kills (`BubbleTrap` and `MeleeBat`
  use landed-hit XP instead); boss XP split per living plant on the lawn;
  persisted as `brainrotXp` (save v5). Inspect UI shows level / XP. XP from a
  failed or unfinished day rewinds to the Start Day snapshot.
- **Epic stats + Legendary extras + Mythic passives + aura (live):** claimed Epic overlays `stats`
  onto the registry definition (interval / HP / damage / plant cooldown).
  Legendary extras and Mythic passives tick from evolution `ability` ids
  (`CoinHaste`, `ShieldPulse`, `RangedRampage`, `BubbleBarrage`, `PierceBrew`,
  `RegenPulse`, `DesperateFury`; Lirili’s `freezeEntireLane` / `freezeDuration`
  and other params-only rows merge into `abilityParams`). Aura is purple at
  Epic, gold at Legendary, and red-orange at Mythic. Celestial+ combat extras
  still 🔜.

### Milestone 12 — Audio ✅

Full details in `AUDIO.md`. Summary:

- **`AudioConfig`** — music / SFX ids, volumes, `PRELOAD_SFX`,
  optional `MaxDuration` / `StartOffset`.
- **`AudioController`** + **`SfxPlayer`** — SoundGroups, preloaded one-shots,
  weather + boss BGM crossfade; mute hook for Settings.
- Wired from UI, placement, coins, combat visuals, level phases, boss big-wave
  BGM, and Brainrot ability actions (`BrainrotAction`).
- Hit flash stays server-side (`MonsterFeedback`); combat SFX never block on
  projectile-folder waits (plots ship with `Projectiles` / `Monsters` / … folders).

### Design pivot — Level System (replaces Wave System)

The game uses a **PvZ-style campaign** of discrete authored levels rather than an
endless scaling-wave loop. Full details in `LEVELS.md`. Shared modules added:

- **`Shared.Levels`** — data-driven campaign level registry (mirrors
  `Brainrots`/`Monsters`). Each `LevelDefinition` contains an ordered list of
  `SpawnGroup` entries (the internal "waves"). `LevelService` reads these; code
  never branches on level numbers.
- **`Shared.Config.LevelConfig`** — global pacing knobs (preparation time,
  optional countdown, big-wave warning, spawn interval defaults). Plant/setup
  time is the forest march (`MonsterConfig.SPAWN_COLUMN_OFFSET`). Per-level
  content lives in the registry, not here.
- **`Shared.Types`** — added `SpawnGroup`, `LevelDefinition`. `SaveData` now
  carries `currentLevel` + `highestLevel` (replaces `currentWave`).
- **`Shared.Constants.PHASE`** — extended with `Victory` and `Defeat`.
- **`Shared.Remotes`** — `StartWave`/`WaveStateChanged` → `StartLevel`/
  `LevelStateChanged`; new `SelectLevel` (level-select replay, M13).
- **`LevelService`** (server stub replaced) ✅ M8 — full campaign loop.
- **`MainUI.LevelUI`** (frame scaffold) replaces `WaveUI`.

---

## Conventions

- **PascalCase**: modules, classes, services, folders.
- **camelCase**: variables, functions, parameters.
- **ALL_CAPS**: constants / config keys.
- `--!strict` everywhere; type public APIs.
- Prefer early returns; avoid nesting deeper than three levels.
- Prefer events over polling; disconnect connections when done; cache services.
- Freeze config/constant tables with `table.freeze`.
