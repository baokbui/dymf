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
- Unlocks
- Equipped loadout
- Upgrades
- Statistics
- Future progression systems (collected bosses, evolutions, …)

Not saved (transient / runtime):

- **Coins** (always `EconomyConfig.STARTING_COINS` on join — PvZ-style)
- **Planted Brainrots** (lawn is always empty on rejoin)
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
| `coins`        | number (always written as `STARTING_COINS`) |
| `brains`       | number                     |
| `playerHealth` | number (hearts, max 5)     |
| `brainrots`    | `{ PlantedBrainrot }` (always `{}` — legacy field) |
| `unlocks`      | `{ string }`               |
| `equipped`     | `{ string }` loadout order |
| `upgrades`     | `{ [string]: number }`     |
| `statistics`   | `{ [string]: number }`     |
| `collectedBosses` | `{ CollectedBoss }?` 🔜 M25 |

`PlantedBrainrot` remains on the type for older payloads but is **never written or
restored**. `CollectedBoss` (planned) = `{ monsterId, slotIndex, collectedAtLevel? }`
— see `HOUSE.md`.

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
- Migrate older `version` payloads forward (legacy `brainrots` cleared).
- Persist on leave and on a periodic autosave.
- Coordinate restore with other services (empty lawn, balance via `CoinService`,
  day/hearts via `LevelService`, unlocks via `ProgressService`).

---

## Leave / rejoin behavior

If a player leaves during a level:

- Save progression (day, hearts, brains, unlocks).
- End the active level; clear Brainrot / monster / coin runtimes on plot release.

On rejoin:

- Restore day, hearts, brains, unlocks / loadout.
- Coins reset to `STARTING_COINS` (125).
- Lawn is **empty** — press Start Day to play again.
- Monsters are never restored.

---

## Reset Progress

A confirmed Reset (via Settings UI → `ResetProgress` remote, see `UI.md` /
`NETWORKING.md`) deletes all saved progress and returns the player to level 1
with starter coins, full hearts, default unlocks/loadout, and empty statistics.
Never erase save data unless Reset is explicitly confirmed.
