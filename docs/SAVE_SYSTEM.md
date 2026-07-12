# BVM Save System

Player progress is persistent across sessions. **Only `SaveService` touches
DataStore** — no other service accesses it (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## What is saved vs. not

Saved (player-owned progression):

- Current level
- Highest unlocked level
- Coins
- Player health
- Planted Brainrots (+ positions, + health)
- Unlocks
- Upgrades
- Statistics
- Future progression systems

Not saved (transient / runtime):

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
| `coins`        | number                     |
| `brains`       | number                     |
| `playerHealth` | number (hearts, max 5)     |
| `brainrots`    | `{ PlantedBrainrot }`      |
| `unlocks`      | `{ string }`               |
| `equipped`     | `{ string }` loadout order |
| `upgrades`     | `{ [string]: number }`     |
| `statistics`   | `{ [string]: number }`     |

`PlantedBrainrot` = `{ instanceId, brainrotId, position (GridPosition), health }`.

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
- Persist on leave and on a periodic autosave.
- Coordinate restore with other services (battlefield via `PlotService` /
  `BrainrotService`, balance via `CoinService`, level via `LevelService`).

---

## Leave / rejoin behavior

If a player leaves during a level:

- Save the battlefield and the current level progression.
- End the active level.

On rejoin:

- Restore the battlefield, coins, all Brainrots, and progression.
- The saved level **restarts from the beginning**; the player must press Start
  Level again (see `LEVELS.md`).

---

## Reset Progress

A confirmed Reset (via Settings UI → `ResetProgress` remote, see `UI.md` /
`NETWORKING.md`) deletes all saved progress and returns the player to level 1
with starter coins, full hearts, default unlocks/loadout, and empty statistics.
Never erase save data unless Reset is explicitly confirmed.
