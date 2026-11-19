# BVM Architecture

This document describes how the Brainrots vs. Monsters codebase is structured and
the conventions every contributor (human or AI) must follow. It is the technical
companion to `GAME_DESIGN.md` (what the game is) and `ROADMAP.md` (build order).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Core principles

In priority order (from `AGENTS.md`):

1. Maintainability
2. Readability
3. Scalability
4. Performance
5. Server authority

Supporting rules:

- Every major gameplay feature lives in its own **Service** (server) or
  **Controller** (client).
- Aim for files under ~300 lines where a clean split exists. Cohesive modules
  may be longer; avoid artificial fragmentation.
- Never duplicate logic — reused logic becomes a ModuleScript.
- Never hardcode gameplay values — they live in `Shared/Config`.
- Never trust RemoteEvents — the server validates everything.

---

## Tech stack

- Roblox Studio + Luau (`--!strict` in all modules)
- Rojo for filesystem ↔ Studio sync (`rojo 7.7.0`, pinned in `aftman.toml`)
- Codex for development (Cursor compatibility via the `.cursorrules` pointer)

Build the place from source:

```bash
rojo build -o bvm.rbxlx   # one-off build
rojo serve                 # live sync into Studio
```

`bvm.rbxlx` is git-ignored; source is committed. Authored models in Studio
are not exported into Git merely by enabling `$ignoreUnknownInstances`.
A source-only build uses fallbacks when those assets are unavailable.

For live sync, keep `rojo serve` running and connect Studio’s Rojo plugin to
`127.0.0.1:34872` (default). Studio MCP is a separate inspection/editing
connection and does not sync local files. Restart the playtest after config
edits: required modules are cached and join cheats run during save hydration.

`AGENTS.md` is the canonical project-wide rules file; `.cursorrules` is only a
compatibility pointer. Current runtime caveats: `IMPLEMENTATION_NOTES.md`.

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
    Config/        Grid, Economy, Level, Plot, Progress, Store, House, Magnet, Grave, Combat, Evolution, Weather, Audio, UI + aggregator init
    Constants/     structural keys (save version, tags, phases, folder names)
    Types/         shared Luau type definitions
    Utilities/     Logger, GridUtil, WeatherUtil, VfxLoad + aggregator init
    Brainrots/     data-driven Brainrot registry
    Monsters/      data-driven Monster registry
    Levels/        data-driven campaign level registry
    Remotes/       single network-boundary definition

ServerScriptService/Server/            (init.server.luau = bootstrap)
    Services/
        HouseService/     (online farm income + roaming Resident models)
        WorldStyleService/ (baseplate/daytime style; shared WorldStyle helper)
        FarmProgressionService/ (day-star attempts, regional shards, sky pickups, combine/fusion intents)
        PlotService/      (init + Plot + PlotBuilder, HouseBuilder, SanctuaryBuilder)
            PlotDecor     (permanent side gardens, paths, benches and small trees)
        GridService/      (battlefield tile grid + occupancy)
        CoinService/      (init + GroundCoin)
        MagnetService/    (player magnet pull + cooldown)
        BrainrotService/  (init + BrainrotModel, BrainrotBehavior, BrainrotAnimation, Abilities, BrainrotFeedback)
        EnemyService/     (init + MonsterModel, MonsterBehavior, Abilities, MonsterFeedback)
        CombatService/
        DamageMeterService/ (per-day HP ranks for the right-rail HUD)
        GraveService/     (fog graves → Zombie/Skeleton emerge)
        LevelService/
        SaveService/
        StoreService/     (Brainrot stall + shop ownership — M18)
        ProgressService/  (brains, unlocks, loadout, upgrades, statistics)
        RetentionService/ (DailyQuests, LoginRewards, Achievements, DailySpin, NextGoal, analytics; M20)

StarterPlayerScripts/Client/           (init.client.luau = bootstrap)
    Controllers/
        UIController/     (init + Shop, HUD counters, DamageMeter, Level, Settings, Inventory, Index, BrainrotInspect, MonsterInspect, ProgressionStore, popups)
        CoinController/   (ground-coin pickup intent + sparkle — M3/M11)
        PlacementController/ (selection, ghost preview, place/remove intent)
        GridController/   (hover highlight + tile resolver on own plot)
        CameraController/
        InputController/  (primary intent + magnet 1)
        BrainrotController/ (BrainrotAction SFX; ScaleTo pulse; world nameplates; High-only IdleAnimation)
        FarmController/   (session-local visibility for other farms' residents)
        CombatController/ (CombatVisual VFX + SFX — M11/M12)
        AudioController/  (weather + boss BGM, SFX via SfxPlayer — M12)
        StoreController/  (hide other players' store Talk prompts — M18)
        WeatherController/ (night/fog + desert pyramids)
        QuestController/ (quest/login/achievement tabs, NextGoal hint, UTC countdown, claims)
        UIController/MenuPages.luau (adapts existing panels into the shared Menu)
    Utilities/
        VfxUtil/          (ephemeral particles — M11)
        PlotUtil/         (local plot helpers — M11)
        TextShine.luau    (shared rarity-title gleam)
        MenuRouter.luau  (single Menu window, page registry, badges and responsive hosting)
        MenuTiles.luau   (shared icon/name artwork for the seven drawer destinations and reward entries)
        MenuDrawer.luau  (seven HUD destinations, slide-out/retraction and Menu/X morph)
        SettingsShortcut.luau (safe-inset top-bar Settings entry)
        BrainAmount.luau (inline number + brain texture for rewards/statistics)
        UISizing.luau    (event-driven desktop HUD scaling and screen bounds)
        HudLayout.luau   (shared window bounds reserving planting/navigation bands and HUD rails)
        ScrollPolicy.luau (overflow-only scrollbar chrome and balanced gutters)

Workspace/
    Plots/        plot models are generated here at runtime
    EnemyPaths/
    Maps/
```

---

## Bootstrap & lifecycle

PlotBuilder builds permanent garden scenery once under each plot's `Scenery`
folder. `PlotDecorConfig` controls its density, palette, path width and offsets.
PlotDecor reuses ForestDecor's static part/tree helpers. Garden bushes clone
`Assets.Decor.GardenBush` (Toolbox asset `8647777369`) through ModelUtil,
fit to the configured footprint/height and grounded at each shrub position.
Keep this authored template saved in the Studio place; Rojo preserves it.
A procedural shrub is used if the template is absent. All garden geometry is
anchored, non-colliding, non-touchable and non-queryable. Side paths and beds sit
beyond the lawn's Z edges, with the east monster approach open. Scenery survives
Plot.release because it is outside the per-owner cleanup folders. The default
four-plot garden adds 532 static parts. Edit-mode geometry checks verified lawn
and lane-boundary clearance and owner-release persistence; an isolated garden
preview was visually inspected. Full gameplay/performance QA remains pending.

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
  Behavior and ordinary campaign content are resolved from data. Avoid new
  name/number branches; Day 40 → Hidden Day is an explicit service-owned exception.
- **Remotes** — the single client/server boundary. See `NETWORKING.md`.

---

## Server vs. client ownership

| Server owns                                   | Client owns                       |
| --------------------------------------------- | --------------------------------- |
| Coins, brains, store spends, damage, health, levels, spawning | UI, camera, input                 |
| Brainrot placement, saving, rewards, unlocks / loadout        | SFX, particles, UI juice          |
| Combat Animator tracks and Monster walk    | High-only Brainrot cosmetic idle, placement ghost / shop previews |
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
  enemy spawn) and `LANE_ROWS`. Default: **4** player plots + **4** enemy lanes
  (4 rows × 2 columns). Plot footprint stays the original packed 6-lane size
  (`PACKED_LANE_ROWS`); `LANE_PITCH` spaces the four plots evenly along Z.
- **PlotBuilder** procedurally builds each player lane from `PlotConfig`: an
  invisible, non-colliding `Base` (region origin + placement raycast target), a
  `SpawnLocation` at the play area's left edge facing the enemy (+X),
  `HouseAnchor` (−X) / `CoinSpawner` markers, an open **`House`** monster farm
  (`HouseBuilder` → `SanctuaryBuilder`, imported farm template under
  `Assets.Houses` with a procedural farm fallback), and empty `Grid` / `Path` /
  `Decorations` folders. Lane layout left→right: house zone (farm + yard),
  play area (grid). Monsters stage in the matching
  east-column `EnemyLane` (`EnemySpawn` attachment at its west edge).
- **ForestBuilder** fills the east column with `Workspace.Maps.DarkForest` —
  shared grass with dense layered trees casting shade (non-colliding). An
  invisible ForestFloor marker supplies bounds. A clear strip near the
  plot boundary keeps monster entry / spawn readable. **Desert** days hide that
  forest on the local client and spawn pyramids instead (`WEATHER.md`).
- See **`HOUSE.md`** and **`FARM_PROGRESSION.md`** for the current farm loop.
- Gameplay isolation is **server-validated**, not physical: plant / shovel /
  coin collect / Progression Store only succeed on the acting player's own plot
  (and own coins).
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

- **`Shared.Brainrots`** — 13 data-driven roster entries (the launch seven replaced
  the M4 Shooter / Money Generator placeholders). Stats use hit-based health, tile
  range, and `attackInterval` (seconds between actions).
- **`Shared.Config.BrainrotConfig`** — global knobs (`FULL_LINE_RANGE`,
  `BEHAVIOR_TICK`, attack pulse, sound keys).
- **`BrainrotService/Abilities/`** — one handler module per ability id;
  `BrainrotBehavior` resolves handlers from `definition.ability`.
- **`BrainrotBehavior`** — server tick loop for cooldowns; calls `tryAct` /
  `onPlaced`; ticks claimed evolution extras even when `attackInterval <= 0`;
  routes combat through `CombatService`, coins through
  `CoinService.dropCoinForOwner`.
- **`BrainrotAnimation`** — server attack/hit/ability Animator tracks for
  `definition.animated` units; resolves idle asset ids for local playback.
- **`BrainrotController.IdleAnimation`** — High-only local idle clips and
  procedural motion; skips definitions marked `noIdle`, leaving action clips
  server-owned.
- **`BrainrotFeedback`** — ScaleTo attack pulse (skipped when `animated`) +
  replicated hit flash on damage + EvolutionAura construction/stone integration.
- **`BrainrotController`** (client) — plays sounds from `BrainrotAction`
  pushes; ScaleTo pulse only for non-animated melee (gameplay stays server-side);
  local aura detail from graphics preference, distance/crowd budgets and pause;
  Off retains the rarity outline. See EVOLUTION_AURAS.md.
- **`CombatService`** — row-based Brainrot attacks + monster damage/death (M6).
  Full combat: projectiles, target acquisition, status effects (M7).

### Milestone 6 — Monster Framework ✅

Full details in `MONSTERS.md`. Summary:

- **`Shared.Monsters`** — 14 data-driven entries (including the unused Necromancer prototype).
  Movement uses `secondsPerGrid`; attacks use `attackInterval`.
- **`Shared.Config.MonsterConfig`** — behavior tick, spawn column, campaign HP aging, dev test spawns.
- **`EnemyService`** — `spawn` (level = current day; non-boss HP scaled for that day), `MonsterBehavior` grid movement, attack-on-tile,
  `Abilities/` handlers (Goblin Elite one-shot, Spider jump, Necromancer summon, …).
- **`MonsterModel`** / **`MonsterFeedback`** — models clone from
  `Assets.Monsters` via `ModelUtil` (M16; Part fallback); pulse / hit flash /
  freeze / bubble feedback on the model.
- **`CombatService`** — wired to `EnemyService` for `damageMonster`, row queries,
  and status effects. **`DamageMeterService`** ranks HP dealt this day for the
  right-rail HUD.
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
  select wipes the lawn + checkpoint; `LevelStateChanged` remote. After Day 40
  is cleared, the lawn switches to the Hidden Day night. Continue returns to
  preparation; the player presses Start Day to run it. Win or lose shows the
  reward popup, then Day 41.
- **`LevelService/LevelRun`** — spawn-group timing, big-wave warning, random rows.
  Every spawn carries its authored group before the scheduler advances; species
  and row settings stay correct at boundaries for numbered and Hidden days.
  Rejected spawn attempts log a warning; victory still waits for living enemies.
- **`UIController/Level.luau`** — bottom-right day title, Start Day button, progress bar, big-wave banner.
- **`UIController/GameOverPopup.luau`** — defeat overlay + Rewind Day N.
- **`EnemyService.setHouseBreachHandler`** — subtract one house heart per breach;
  defeat only at zero.
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

- **`VfxConfig`** — client VFX tuning (burst counts, colors, trail lifetime) plus
  per-effect `HEAVY_VFX_*` ids for GOD ultimates.
- **`VfxLoad`** — Settings **VFX** choice (High = Full, Low = Reduced, Off = Minimal)
  and a local **Other plots** toggle. The server always authors the full ult.
  Off flattens shop / inventory / index portraits and freezes evolution shine.
  Inspect portraits stay 3D. Damage is never throttled.
- **`VfxUtil`** + **`PlotUtil`** (client utilities) — ephemeral particles and plot helpers.
- **`CombatController`** — hit/death particles, line-bomb explosions (`Explosion`
  payload), Sahur’s Wrath landing (`BatSlam`), projectile trail/glow on `plot.Projectiles` parts.
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
- **Settings** — Menu section; mute, volume sliders, Brainrot SFX toggle,
  VFX choice (High / Low / Off), double-confirm Reset Progress. Statistics has its own Menu section. Level Select deferred to a later UI.
- **Inventory** — Menu section; click a packet
  for a shared inspect card on the right (portrait + HP / level / XP bar,
  stats + gray/lit evolutions, Equip / Equipped). Clicking a planted unit
  on your lawn opens the same card with live HP. Clicking a monster on your
  plot opens `MonsterInspect` (portrait, live HP, stats, ability — no
  evolutions).
- **Reward popup** — victory shows brains earned (store purchases → M18). The Hidden Day after Day 40 uses the same popup for a clear or a loss.
- Current save schema is **v16** (`SAVE_SYSTEM.md`): progression, XP, claimed
  evolutions, intro lists, retention state, farm instances/receipts, shards,
  best day stars, species history, and optional `hiddenDayPending`. Coins are a legacy
  placeholder, not a persisted gameplay balance.

### Milestone 18 — Progression Store ✅

Full details in `STORE.md` / `UI.md`. Summary:

- **`StoreService`** + **`StoreConfig`** — clone the Brainrot stall beside each
  house; owner-only Talk → `OpenProgressionStore`. Overlay closes past
  `CLOSE_DISTANCE` from the mascot. HUD **Upgrades** only need an owned plot.
- **`ProgressService`** validates `BuyStoreItem` (stall range for Brainrots, own plot
  for Upgrades, brains spend, catalog, owned /
  max level). Catalogs in `ProgressConfig.STORE_CATALOG` (five units; see `STORE.md`) and
  `UPGRADE_CATALOG` (WalkSpeed, 20 ranks; Magnet 1–5). Speed applied on spawn / rejoin via
  `PlotService` + `ProgressService.getWalkSpeed`.
- **`UIController/ProgressionStore`** — list + stats card to the right; kaching /
  stacked error banners. Upgrades is hosted in Menu; the physical Brainrot store
  detaches the shared view. HUD: mid-left Coins / Brains / Speed glyphs; one
  bottom-left Menu entry; Magnet square bottom-center.
- **`UIController/Index`** — Brainrots / Monsters catalog; unseen units are
  black silhouettes with **?**. Encountered from unlocks / intro lists (Day 1
  Zombie is always shown — no intro popup).

### Milestone 19 — Brainrot leveling + evolutions ✅ (ladder + GOD ultimates live)

Full details in `EVOLUTIONS.md` / `ROADMAP.md`. Summary:

- Each roster Brainrot has its own **Brainrot level** (XP), **not** campaign day.
- At 10 / 20 / 30 / 40 / 50: Epic → God (aura + stat / active / passive /
  ultimate). Tiers stack; base shop id stays.
- Persist level + XP + owned tiers via `SaveService`. Combat extras stay
  data-driven ability ids.
- **XP (live):** last-hit species for normal kills (`BubbleTrap`, `BubbleBarrage`, `MeleeBat`,
  and `TileTrap` skip last-hit XP; configured hit jobs grant separately); boss XP split per living plant on the lawn;
  persisted as `brainrotXp` (introduced v5; current save schema v16). Inspect UI shows level / XP. XP from a
  failed or unfinished day rewinds to the Start Day snapshot.
- **Epic stats + Legendary extras + Mythic / Immortal passives + aura (live):** claimed Epic overlays `stats`
  onto the registry definition (interval / HP / damage / plant cooldown).
  Legendary extras and Mythic / Immortal passives tick from evolution `ability` ids
  (`CoinHaste`, `ShieldPulse`, `RangedRampage`, `BubbleBarrage`, `PierceBrew`,
  `RegenPulse`, `DesperateFury`, `Stoneheart`, `TenfoldGuard`, `SahurWrath`,
  `Jackpot`, `PrimalRetaliation`, `ShadowRequiem`, `AbyssalTorrent`; Lirili’s
  `freezeEntireLane` / `freezeDuration` / `freezeAdjacentLane` /
  `freezeEntireLawn` / `lawnSlowPercent` and other
  params-only rows merge into `abilityParams`). Aura is purple at
  Epic, gold at Legendary, red-orange at Mythic, dark red at Immortal, rainbow
  at GOD. **GOD ultimates:** Tung Tung `SahurWrath`, Ballerina `Jackpot`,
  Chimpanzini `PrimalRetaliation` ✅; Lirili Glacial Dominion (on plant) ✅;
  Cappuccino `ShadowRequiem` ✅ (ramped crescent + last-tile pillar); Tralalero `AbyssalTorrent` ✅ (mouth jet, base damage per second, 3+ or a boss, easternmost ready first).

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
  `SpawnGroup` entries (the internal "waves"). `LevelService` reads these. The Hidden Day transition after Day 40 is an
  explicit exception to the numbered registry flow.
- **`Shared.Config.LevelConfig`** — global pacing knobs (preparation time,
  Start Day countdown, big-wave warning, spawn interval defaults). Plant/setup
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

## Milestone 20 foundation

`Config.Retention` / `RetentionConfig` define immutable quest and mixed first-time reward
catalogs and progression bands. `Utilities.RetentionTime` provides pure UTC
date/countdown helpers; `Types.Retention` defines quest, reward, achievement,
challenge receipt, and spin save contracts.
RetentionService owns daily/weekly quests and finite first-time offers, pure DailyQuests/LoginRewards rules,
and analytics. Achievements tracks permanent milestones and NextGoal selects
one actionable hint from the existing authoritative profile/registries.
QuestController registers Quests (daily/weekly/Campaign tabs) and Achievements in the
shared Menu. QuestTracker adds a right-side daily/weekly progress panel between
Damage and the day UI; QuestPresentation supplies shared display rows. FirstTimeRewards hosts LoginRewardsPanel in a standalone temporary
HUD window, hiding its gift entry after authoritative completion. OutsideDismiss
shares outside-only click regions between that window and Menu. RewardGrant prepares durable upgrade/ticket
snapshot mutations; the physical shop also accepts a saved free-ticket intent. MenuPages
adapts existing feature panels. Current save schema v16 and SaveService.SessionStore
provide session/revision-guarded writes and durable claims. DailySpin selects
the server outcome inside the save transaction, and DailySpinHud reveals it
from a standalone HUD entry. See `RETENTION.md`.

## Conventions

- **PascalCase**: modules, classes, services, folders.
- **camelCase**: variables, functions, parameters.
- **ALL_CAPS**: constants / config keys.
- `--!strict` everywhere; type public APIs.
- Prefer early returns; avoid nesting deeper than three levels.
- Prefer events over polling; disconnect connections when done; cache services.
- Freeze config/constant tables with `table.freeze`.

Desktop UI readability is centralized in `Client.Utilities.UISizing`, using
UITheme reference-size tokens and viewport/window bounds. UIController binds current and future
MainUI children once. Full-screen overlays stay in screen coordinates, while
Menu and FirstTimeRewards fit their own scaled windows. Reparented Menu pages
use host scaling, avoiding compounded UIScales. See `UI.md` for geometry/tests.

ShovelIcon shares the user-supplied shovel texture between toolbar and cursor. UISizing skips
`ScreenSpaceUI` objects such as ShovelCursor: pointer screen coordinates must
not receive authored HUD offset scaling. See `UI.md` for removal regressions.

Menu navigation now uses an animated horizontal HUD drawer, not a large grid
launcher. MenuRouter retains its feature-panel registry/hosting; MenuDrawer
manages the seven drawer icons and Menu/X state, including resize/tween cancellation.
Settings uses its own safe-inset top-bar shortcut into the same Menu host.
Selecting a section leaves the drawer open; feature windows have no top-left
Menu button. HudLayout keeps hosted and standalone windows within the reserved
HUD rectangle, with event-driven updates shared by UISizing and the Menu host.

UIController starts ScrollPolicy once for current/future MainUI scrollers.
It controls chrome/gutters, not gameplay or claim state. Menu pages own their
internal scrolling and the host scrolls only actual overflow. The quest tracker
uses one Daily/Weekly toggle, retaining period-specific completion animation.

### Daily Challenge

LevelService reuses the per-plot wave scheduler and tracks Forest Rush through
a temporary ChallengeRun context. Campaign day, hearts, pending Hidden Day
and the committed lawn remain the source of save snapshots. Challenge payout
uses SaveService's existing serialized retention writer. Combat and coin
events exclude the temporary run from campaign progression credit.

### Woodland scenery

`PlotService.ForestBuilder` builds the static east-column forest once;
`ForestDecor` supplies oak/cypress silhouettes and edge rocks/shrubs. Cosmetic
spacing, seed, palette and clearings are configured in `PlotConfig`. A local
Random instance makes placement reproducible without touching gameplay RNG.
All scenery is anchored, non-colliding, non-touching and non-queryable.
`DarkForest.ForestFloor` is an invisible bounds marker for DesertVisuals.
The shared grass receives canopy shadows; no dark floor or moss overlay covers it.
Trees vary from sapling to tall canopy sizes at denser, staggered spacing. Every
forest detail stays under that folder so desert weather can hide it locally.

### Monster Sanctuary (M21 core)

PlotService builds an open habitat in the house slot through SanctuaryBuilder.
HouseService owns online income and cosmetic roaming residents up to the purchased farm capacity, supplied
by its Resident module. Shard combining creates individual monsters through
the durable save writer; campaign clears award shards rather than automatic
ownership. The latest purchased-capacity count of instances roam and accrue
species rate × size multiplier income. Schema v16 retains instances/receipts
plus the earlier species history. Existing species-only saves migrate to Medium
instances; there is no current campaign backfill. FarmController only controls
local visibility. See HOUSE.md for income and migration limitations.

### Farm stars and shards (M21B)

FarmProgressionService owns attempt ratings, rare sky drops and combine/fusion requests.
Shared.Utilities.FarmProgression supplies pure rules from FarmProgressionConfig.
LevelService awards numbered-day stars/brains/shards. Schema v16 retains
v15 shards/best stars and adds individual farmMonsters and bounded farmReceipts.
SaveService atomically commits shard combining and 3–5 input fusion;
MonsterFusionConfig/Utilities.MonsterFusion own size tiers, recipes and receipt
validation. ShardInventory, MonsterCollection and DayGoals present the feature.
See FARM_PROGRESSION.md.

### Shard presentation

`ShardVisualConfig` and `Utilities.ShardAppearance` share cosmetic tuning/colors
between server `Utilities.ShardModel` and client `Utilities.ShardIcon`.
`FarmProgressionService.SkyShard` moves the entire faceted model using one
CFrameValue tween and attaches its server-validated prompt to the invisible
root. `UIController.FusionPanel` owns the separate Fusion page, reusing
MonsterCollection without duplicating recipe/request logic. Inventory Items
retains tickets and shard combining. `UIController.ShardInventory` adds compact matching icon/name/count tiles. A shared
`Utilities.ShardTooltip` presents the description, quantities and eligible
combine action on hover, focus or tap. `ShardController` watches tagged world pickups and applies graphics-quality
particle rates. `Utilities.ShardEffects` owns visibility-aware boss icon
tweens. MonsterPreview optionally supports translucent head framing, and
world shards contain static, sanitized monster miniatures. No animation
frame loop, asset upload, remote or save schema change is needed.

## Per-player day pause ✅

LevelService owns pause phases; its PauseScene helper captures animation and
character freeze state. Shared.Utilities.BattleClock owns per-player simulation
time, delayed callbacks and tracked tweens. Combat systems use it without a
LevelService dependency. See [DAY_PAUSE.md](DAY_PAUSE.md).

## Farm pet equipment ✅

InventoryPets renders owned monsters and forwards place/remove intent.
Shared.Utilities.FarmResidents holds pure legacy selection and capacity rules.
HouseService validates requests, ProgressService owns the live selection and
SaveService persists the optional per-monster onFarm field. Refreshing resident
visuals after equipment changes does not run an income tick. See HOUSE.md.

## Studded material construction ✅

WorldStyle owns reusable PBR material assignment and artwork/physics exclusions.
Plot/forest/grid construction and sanitized ModelUtil clones apply it once.
WorldStyleService owns the daytime baseline; client weather retains night and
desert transitions. Shared MaterialVariants are source-controlled in the Rojo
project. See [WORLD_STYLE.md](WORLD_STYLE.md).

Evolution purchase presentation uses an optional celebration flag on
BrainrotService.applyEvolutionStats. Transient model/carrier serials let
AuraQuality play one matched, quality/count-limited local burst. Normal
placement, restore and dev overrides do not trigger it. No combat or save
schema changes. See EVOLUTION_AURAS.md.

EvolutionAura uses its cosmetic-only AuraBounds helper to include visible mesh
bounds and transformed rig bones. AuraVfx spans the full body; nested FlameVolume
starts at the feet with a lowered ceiling for flame sprite extent/travel.
Five emitters share that Box/Volume, including sparse rising Motes/Glints.
No leg/torso point sources remain. Placement and ModelUtil snapping remain
unchanged. See EVOLUTION_AURAS.md.
