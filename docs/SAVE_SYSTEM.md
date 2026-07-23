# BVM Save System

Player progress is persistent across sessions. **Only `SaveService` touches
DataStore** — no other service accesses it (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## What is saved vs. not

Saved (player-owned progression):

- Current level (campaign day)
- Highest unlocked level
- Brains
- Player health (hearts — progressive across days)
- **Planted Brainrots** (id, tile, remaining HP)
- Unlocks
- Equipped loadout
- Upgrades
- Statistics
- Future progression systems (collected bosses, evolutions, …)

Not saved (transient / runtime):

- **Coins** (Day 1 → `STARTING_COINS`; later days → 0 via `applyDayPurse` on
  join / day end — never persisted as a balance)
- Active monsters & their positions
- Active projectiles
- Ground coins
- Temporary combat effects
- Level timers

---

## Save schema ✅ (type defined)

`Shared.Types.SaveData` defines the versioned shape:

| Field          | Type                       |
| -------------- | -------------------------- |
| `version`      | number (`SAVE_VERSION` = 2)|
| `currentLevel` | number                     |
| `highestLevel` | number                     |
| `coins`        | number (always written as `STARTING_COINS`; ignored on load) |
| `brains`       | number                     |
| `playerHealth` | number (hearts, max 5)     |
| `brainrots`    | `{ PlantedBrainrot }`      |
| `unlocks`      | `{ string }`               |
| `equipped`     | `{ string }` loadout order |
| `upgrades`     | `{ [string]: number }`     |
| `statistics`   | `{ [string]: number }`     |
| `collectedBosses` | `{ CollectedBoss }?` 🔜 M25 |

`PlantedBrainrot` = `{ instanceId, brainrotId, position: { row, column }, health }`.
`CollectedBoss` (planned) = `{ monsterId, slotIndex, collectedAtLevel? }` — see
`HOUSE.md`.

Relevant constants (`Shared.Constants`):

- `SAVE_VERSION = 2` — bump when the schema changes; migrate older payloads.
- `SAVE_DATASTORE_NAME = "BVZ_PlayerData_v1"` — owned solely by `SaveService`.
  Retains its original `BVZ_` prefix despite the rename to Monsters, so existing
  player saves are never orphaned (the DataStore key is identity, not branding).

---

## Responsibilities (Milestone 9) ✅

`SaveService` (server):

- Load a player's `SaveData` on join (defaulting new players from config:
  `EconomyConfig.STARTING_COINS`, `LevelConfig.STARTING_PLAYER_HEALTH`, level 1).
- Migrate older `version` payloads forward.
- Persist on leave, periodic autosave, day victory, and defeat (`saveNow`).
- Leave-save is connected in `init()` so it runs **before** `PlotService` /
  `BrainrotService` clear the lawn on `PlayerRemoving`.
- Writes via `UpdateAsync` with JSON round-trip + retries (Studio may still log
  transient Roblox-cloud `HTTP 500` lines; look for `SaveService` retry/success
  logs — enable **Studio Access to API Services** in Game Settings).
- Coordinate restore: day/hearts via `LevelService`, unlocks via
  `ProgressService`, purse via `CoinService.applyDayPurse`, lawn via
  `BrainrotService.restorePlacements`.

---

## Leave / rejoin behavior

If a player leaves during a level:

- Save progression (day, hearts, brains, unlocks) **and** planted Brainrots.
- End the active level; clear monster / coin runtimes on plot release.

On rejoin:

- Restore day, hearts, brains, unlocks / loadout.
- Restore planted Brainrots (positions + HP).
- Coins via `applyDayPurse` (Day 1 → 125; later → 0).
- Monsters are never restored — press Start Day to play again.

---

## Session lawn rules

| Event | Brainrots | Coins | Monsters / ground coins |
| ----- | --------- | ----- | ----------------------- |
| Victory → next day | **Keep** (current HP); saved | Day 1 → 125; else **0** | Cleared |
| Defeat | Cleared; **current day → 1**; saved empty | **125** | Cleared |
| Day Select | Cleared; next save empties store | Day 1 → 125; else **0** | Cleared |
| Leave / Rejoin | **Persisted** / restored | Day purse (not saved) | Cleared |
| Reset Progress | Cleared | **125** | Cleared |

See `LEVELS.md` / `BALANCE.md` — campaign spawn pressure assumes carry-over.

---

## Reset Progress

A confirmed Reset (via Settings UI → `ResetProgress` remote, see `UI.md` /
`NETWORKING.md`) deletes all saved progress and returns the player to level 1
with starter coins, full hearts, default unlocks/loadout, empty lawn, and empty
statistics. Never erase save data unless Reset is explicitly confirmed.
