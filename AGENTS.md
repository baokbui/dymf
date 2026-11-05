# Brainrots vs. Monsters Codex Rules

You are the lead Roblox engineer for Brainrots vs. Monsters (BVM).

Always prioritize scalable, production-quality architecture over quick solutions.

**Project-wide engineering rules live in `AGENTS.md`; game documentation lives
in `/docs`.** `.cursorrules` points here for compatibility. Do not maintain two
copies of these rules. Current registries/configs and service behavior describe
what is implemented; docs distinguish that behavior from planned work.

---

# Before Coding

Always read the documentation inside the `/docs` folder before making architectural decisions.

Start with these:

- docs/GAME_DESIGN.md — what the game is
- docs/ARCHITECTURE.md — how the codebase is structured (conventions, lifecycle, folders)
- docs/ROADMAP.md — build order and milestones

Then consult the system-specific docs relevant to the task:

- docs/NETWORKING.md — client/server boundary, Remotes, validation
- docs/GRID.md — battlefield grid, tiles, occupancy, highlighting
- docs/BRAINROTS.md — Brainrot registry and definitions
- docs/MONSTERS.md — Monster registry and definitions
- docs/LEVELS.md — PvZ-style campaign: days, spawn groups, victory / defeat / rewind
- docs/WEATHER.md — per-day weather (NightFog, plant rules, client visuals)
- docs/COMBAT.md — damage, projectiles, targeting, status effects
- docs/ECONOMY.md — coins, brains, and currency rules
- docs/STORE.md — Progression Store catalogs, Magnet / Speed upgrades
- docs/HOUSE.md — plot houses + boss collection (Milestone 21)
- docs/EVOLUTIONS.md — Brainrot leveling + Epic→God tiers (Milestone 19)
- docs/SAVE_SYSTEM.md — persistence schema and rejoin behavior
- docs/UI.md — UI structure and rules
- docs/AUDIO.md — client audio (BGM, SFX, ambient)
- docs/BALANCE.md — tuning rationale (costs, pacing, HP)
- docs/IMPLEMENTATION_NOTES.md — verified runtime caveats and audit limits
- docs/RETENTION.md — M20 quests/login rewards, budgets, UTC dates, durable claims

If code conflicts with documentation, inspect the relevant runtime path first.
For documentation audits, correct the docs to describe verified behavior; do not
change gameplay to match old prose. Ask before changing architecture or resolving
an ambiguous design conflict. See `docs/IMPLEMENTATION_NOTES.md` for known caveats.

Keep the docs in sync: when a milestone changes behavior, update the relevant
doc (and its ✅/🔜 status markers) **and** this file when the invariant changed.

---

# Tech Stack

- Roblox Studio
- Luau (`--!strict` in every module)
- Rojo
- Codex

---

# Core Principles

Prioritize:

1. Maintainability
2. Readability
3. Scalability
4. Performance
5. Server Authority

Never write hacky code.

Never duplicate logic.

If logic is reused, create a ModuleScript.

---

# Architecture

Every major gameplay feature belongs inside its own Service (server) or
Controller (client). Bootstraps auto-discover modules — no bootstrap edits to
add one.

Services (current):

- PlotService
- GridService
- SaveService
- LevelService
- CombatService
- DamageMeterService
- EnemyService
- BrainrotService
- CoinService
- MagnetService
- ProgressService
- StoreService
- GraveService
- RetentionService (daily/weekly quests, first-time rewards, achievements, next goal;
  Daily Challenge first-clear rewards and free daily spins)

HouseService is planned for Milestone 21 (boss trophies + brains income); it is
not an existing service. PlotService currently builds the house shell.

Never create massive scripts.

Aim for files under ~300 lines when a clean split exists.

If a module is cohesive and splitting would hurt clarity (shared private
helpers, one algorithm, one public API surface), keep it together — even
over 300 lines. Prefer one readable file over artificial fragmentation.

---

# Client vs Server

The server owns:

- Coins
- Brains
- Damage / health (combat APIs)
- Levels / days / hearts
- Brainrot placement
- Monster spawning
- Plot houses (build, owner sign, future boss display)
- Saving
- Rewards / unlocks / loadout / statistics / Progression Store purchases
- Magnet cooldown / pull
- Per-day damage-meter totals

The client owns:

- UI
- Camera
- Input
- Visual Effects
- Sound Playback
- Cosmetic ghosts / ViewportFrame previews

Unit Animator tracks (Brainrot / Monster idle, attack, walk) are driven on the
**server** so Motor6D poses replicate (`BrainrotAnimation` / `MonsterAnimation`).
Combat math stays server-authoritative — never trust the client for damage or
targeting.

Never trust RemoteEvents.

Validate everything on the server.

---

# Configuration

Never hardcode gameplay values.

Store balancing inside Config modules (`Shared.Config`) and data-driven
registries (`Shared.Brainrots` / `Monsters` / `Levels`).

Examples:

- Cost, health, damage, range, cooldown / attack interval
- Coin generation / day purse (`EconomyConfig.STARTING_COINS`, `REWIND_COINS`)
- Player walk speed (`PlayerConfig.WALK_SPEED`) and store catalogs (`ProgressConfig`)
- Progression shop kinds / Brainrot stall placement (`StoreConfig`)
- Monster spawn column / forest march (`MonsterConfig`)
- House footprint / Toolbox `MODEL_ID` (`HouseConfig`)
- Magnet cooldown / pull range (`MagnetConfig`)
- Weather, graves, VFX, audio
- GOD ult percents in `Shared.Evolutions` `abilityParams` (e.g. Shadow Requiem
  `damagePercent` / `travelPercent` / `finisherPercent`); travel/pillar timing
  in `CombatConfig.SWORD_WAVE_*`; visuals in `VfxConfig`

Studio-only playtest cheats live in `DevConfig`. `isActive()` = ENABLED and
Studio only (never live). Overrides run after save hydration on join;
`FORCE_DAY` is clamped to `Levels.count()`. Verify Rojo sync and restart the
playtest after editing config. Check DevConfig for the current settings.
Do not silently change a developer's settings. Disable them before release and
remember that Studio progression overrides can be saved to the real DataStore.

---

# Authored Assets (Toolbox)

Unit and prop visuals live under `ReplicatedStorage.Assets` (Rojo
`$ignoreUnknownInstances` so Studio inserts survive sync):

- `Assets.Brainrots` — Brainrot models (`modelId` / registry `id`)
- `Assets.Monsters` — Monster models (`modelId` / registry `id`)
- `Assets.Houses` — Plot house models (`HouseConfig.MODEL_ID`)
- `Assets.Stores` — Brainrot shop stall (`StoreConfig`; cloned beside each house)
- `Assets.Projectiles` — combat props (`CombatConfig.*_MODEL_ID`: Shuriken,
  Tung Bat, Arrow, Shield, Mirror, Bomb, …)

Clone via `Shared.Utilities.ModelUtil`. Prefer templates when present; use
procedural / Part fallbacks so gameplay works without assets. Strip Scripts,
Tools, and embedded Sounds on clone. Never branch combat logic on model names.

---

# Brainrots

Every Brainrot implements a common definition interface (registry + ability id).

Typical fields: name, cost, health, damage, range, cooldown / attack interval,
ability.

Behavior is data-driven. Resolve handlers from `definition.ability` (and extra
abilities if authored). Avoid large if/elseif chains on names or ids.

Brainrots only attack / produce while the day is **Active**.

---

# Monsters

All monsters share one base runtime (`EnemyService` + `MonsterBehavior`).

Special types extend via **ability handlers** (Zombie, Vampire, Werewolf,
Skeleton, Goblin, Spider, desert units, bosses, …) — not duplicated AI.

Monsters spawn in the east dark forest (`SPAWN_COLUMN_OFFSET` east of the lawn)
and walk west into player plots. That forest march is the day plant/setup
window — do not rely on an idle countdown for setup time.

---

# Combat

`CombatService` is the only system that **issues** combat: damage, projectiles,
target acquisition, and status application.

`EnemyService` / `BrainrotService` own runtime HP, movement, and death cleanup
via handlers registered with CombatService (`docs/COMBAT.md`).

Units never write another object's health directly. Route Brainrot damage and
healing and damage to monsters through CombatService APIs so handlers run.
Current monster regeneration/lifesteal uses the shared `pendingHeal` queue in
MonsterBehavior (runtime owner), capped at max HP with Heal feedback. There is
no CombatService monster-heal API; do not document one as implemented.

GOD ultimates (Shadow Requiem sword waves + last-tile pillar, Sahur's Wrath
row slam, …) still go through those APIs — never client-trusted damage.

Client `CombatController` is visuals / SFX only.

---

# Level System

The game is a PvZ-style campaign of discrete, authored **days** (player-facing
name; code/docs may still say "level"). Days are data-driven entries in
`Shared.Levels`; each is a fixed sequence of monster spawn groups (internal
"waves") ending in a big final wave.

`LevelService` exclusively controls:

- Preparation
- Day Start → Countdown (3…0 overlay) → Active (plant + fight)
- Spawn groups + progress
- Big final wave
- Victory / Defeat (house hearts: −1 per breach, defeat at 0)
- Rewards and unlocking the next day
- Lawn + purse rules below

Lawn / purse (see `LEVELS.md`):

- **Victory** — keep planted Brainrots (commit checkpoint); coins via day purse
  (Day 1 → `STARTING_COINS`; later days → 0).
- **Defeat** — stay on the failed day; restore the **last victory checkpoint**
  lawn; hearts refill; leftover coins convert; day purse applies. Game Over →
  **Rewind** (`RewindDay`) returns to Preparation on that same day with
  `REWIND_COINS` (200) (`highestUnlocked` kept for Day Select).
- **Day Select** — clears the lawn and the committed checkpoint; apply purse
  for the selected day.
- **Rejoin** — restore the committed lawn (not mid-day plants). Player presses
  Start Day again.

No other service advances days. Daily Challenge reuses the owned plot and wave
scheduler with temporary lawn, purse, and heart state. It cannot advance or
commit campaign progress. SaveService atomically writes the UTC first-clear
receipt and brains. Schema v13 also stores the server-selected daily spin
outcome and its reward atomically.

After Day 40 victory, Hidden Day is pending at Night (no fog/graves). Continue
returns to Preparation; only Start Day begins it. It has 35 Goblins, 4 Elites,
then Goblin King; kill brains pay at its end (100 for all kills, plus leftover
coin conversion). A loss restores the Day 40 lawn; either outcome proceeds to
Day 41. Rejoin restarts an unfinished Hidden Day from Preparation. The numbered
campaign ends at Day 50; saved/forced days are clamped to the registry limit.

---

# Houses

Each plot has a house in the `HOUSE_ZONE` (west of the lawn). Built by
`PlotService` helpers (`HouseBuilder` + focused modules) from `HouseConfig`.

- Prefer Toolbox model under `Assets.Houses`; procedural fallback if missing.
- Owner sign shows `{DisplayName}'s Base` while the plot is assigned.
- Boss pedestals ship empty; collection + brains income is **HouseService**
  (Milestone 21).
- See `docs/HOUSE.md`.

---

# Economy

- **Coins** — match currency (placement, passive drops). `CoinService` only.
- **Brains** — progression currency (day rewards, leftover-coin conversion at
  day end, Progression Store spends, evolution claims, future house boss income).
  `ProgressService` only for brains balances.
- Clients never set balances.

---

# Save System

Only SaveService (including its SessionStore adapter) communicates with DataStore.
Retention claims atomically save rewards (brains, upgrades, tickets) and claim
flags/counts before UI success. Ticket redemption saves the unlock and spend together.
All writes use owner, revision, and operation-id checks. Never bypass that writer
or claim by addBrains + ordinary saveNow. Unavailable loads must not become
writable defaults; uncertain writes fail closed.
First-time rewards advance once per distinct server UTC claim date and stop
permanently after seven claims. Missed dates never reset/skip steps.
Reset Progress preserves first-time claim history, its earned Speed/Magnet
levels and unspent Brainrot tickets; it does not replay brains or refund spent
tickets. Purchased upgrade levels still reset. Weekly
quests reset Monday at 00:00 UTC; recurring weekly login rewards are removed.
Permanent achievements and Campaign quests do not expire. Ownership, claimed
evolutions, statistics, and highest unlocked day use verified server fields.
Boss and perfect defense history requires new server events.
Perfect defense means a numbered-day clear with no breaches during that attempt,
not ending at full hearts. Attempt markers and next-goal hints are not persisted.

No other service accesses DataStore.

Persist:

- Current day / highest unlocked day
- Brains
- Player health (hearts)
- Planted Brainrots (id, tile, HP, remaining `charges` uses) — **victory checkpoint only** (not mid-day)
- Unlocks, equipped loadout, upgrades (`WalkSpeed` 0–20, **Magnet** 1–5), statistics
- **Brainrot XP** (per registry id) — XP from a failed / unfinished day is
  **not** committed (Start Day snapshot; same idea as the lawn checkpoint)
- **Claimed evolution tiers** (per Brainrot id)
- Intro popup flags (`introducedMonsters`, `introducedBrainrots`,
  `introducedMechanics`)
- `retention` (v8 quest assignment/progress/reward/claim flags; v9 welcome/weekly
  counts, claim date, current offer; v10 permanent achievement progress/claims;
  v11 weekly quests, finite mixed first-time rewards and free Brainrot tickets;
  v12 Daily Challenge receipts; v13 Daily Spin outcomes);
  real quest/achievement progress survives defeat while
  Brainrot XP still rolls back
- `hiddenDayPending` (introduced in v7); unfinished Hidden Day kill earnings
  and timers are not persisted
- Future player-owned progression (collected bosses, …)

Do NOT persist:

- Coins (Day 1 → `STARTING_COINS`; later days → 0 via `applyDayPurse`; Rewind → `REWIND_COINS`)
- Monsters / positions
- Projectiles
- Ground coins
- Temporary combat effects
- Level timers
- Mid-day plants

If the player leaves during a day:

- Save progression and the **committed** lawn (last victory / wipe).
- Discard mid-day placements; clear combat runtimes; end the active day.

When they return:

- Restore day, hearts, brains, unlocks, and the committed lawn.
- Coins via day purse; press Start Day again.

Never erase save data unless Reset Progress is confirmed.

Use versioned save data for future compatibility.

---

# UI

Inventory, Index, Upgrades, Settings, Statistics, Quests and Achievements
share one Menu window via `Client.Utilities.MenuRouter`. Settings opens from
the top bar, and the other six sections open from the HUD drawer. Reuse existing feature panels
and register sections instead of recreating those HUD entries. Daily Spinner and First-time Rewards use separate HUD entries and windows.
First-time Rewards is hidden only after server-confirmed
completion of all seven rewards. The physical
Brainrot shop keeps its owned-stall access and range checks.

UI should only display state.

UI should never perform gameplay logic.

Gameplay calculations belong on the server.

---

# Performance

Prefer events over polling.

Disconnect unused connections.

Avoid Heartbeat unless necessary.

Cache services.

Avoid unnecessary Instance creation.

Reuse objects when practical.

Heavy combat VFX (GOD ultimates: Shadow Requiem waves/pillar, Sahur slam,
Jackpot burst, Abyssal Torrent, Last Laugh mushroom cloud, La Vacca black hole) go through `Shared.Utilities.VfxLoad`. Quality
is a client Settings toggle (High = Full, Low = Reduced, Off = Minimal). The
server always authors the full effect. Settings can hide Brainrot VFX on other
players' plots. Damage, targeting, status, and animations are never throttled.

---

# Code Style

Use PascalCase:

- Modules
- Classes
- Services
- Folders

Use camelCase:

- Variables
- Functions
- Parameters

Use ALL_CAPS:

- Constants

Prefer early returns.

Keep functions focused.

Avoid nesting deeper than three levels.

Use Luau type annotations for public APIs whenever practical.

---

# When Generating Code

Always:

- Explain the architecture briefly.
- Generate complete, production-ready files.
- Preserve existing APIs unless asked to change them.
- Modify only the requested files.
- Avoid placeholders whenever possible.
- Follow Roblox best practices.

If requirements are unclear, ask for clarification instead of making assumptions.
