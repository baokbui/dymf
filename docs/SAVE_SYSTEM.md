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
- Upgrades (`WalkSpeed` ranks, **Magnet** 1–5)
- Statistics
- **Brainrot XP** (per registry id — shared species pool)
- **Claimed evolution tiers** (per Brainrot id, after brains spend)
- Future progression systems (collected bosses, …)

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
| `version`      | number (`SAVE_VERSION` = 6)|
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
| `brainrotXp`   | `{ [string]: number }` (per Brainrot registry id) |
| `evolutions`   | `{ [brainrotId]: { rarity } }` claimed Epic→Immortal tiers |
| `introducedMonsters` | `{ string }` (monster intro popups already shown) |
| `introducedBrainrots` | `{ string }` (Brainrot intro popups already shown) |
| `collectedBosses` | `{ CollectedBoss }?` 🔜 M21 |

`PlantedBrainrot` = `{ instanceId, brainrotId, position: { row, column }, health }`.
`CollectedBoss` (planned) = `{ monsterId, slotIndex, collectedAtLevel? }` — see
`HOUSE.md`.

Relevant constants (`Shared.Constants`):

- `SAVE_VERSION = 6` — bump when the schema changes; migrate older payloads.
  **v4 → v5:** add `brainrotXp` (empty map if missing).
  **v5 → v6:** add `evolutions` (empty map if missing).
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
- Own a **committed lawn** checkpoint (`commitLawn` / `clearCommittedLawn` /
  `restoreCommittedLawn`): only victory / day-select wipe / load / reset update
  the checkpoint list; leave and autosave write that checkpoint, not mid-day
  live plants. Defeat **restores** the checkpoint onto the plot (does not empty it).
- Leave-save is connected in `init()` so it runs **before** `PlotService` /
  `BrainrotService` clear the lawn on `PlayerRemoving`. Snapshot is captured
  synchronously; if a save is already in flight, the leave payload is queued
  and flushed when the in-flight write finishes (never dropped).
- Writes via `UpdateAsync` with JSON round-trip + retries (Studio may still log
  transient Roblox-cloud `HTTP 500` lines; look for `SaveService` retry/success
  logs — enable **Studio Access to API Services** in Game Settings).
- Coordinate restore: day/hearts via `LevelService`, unlocks/stats/XP via
  `ProgressService` (**hydrated synchronously on join** so autosave cannot wipe
  defaults over real statistics), purse via `CoinService.applyDayPurse`, lawn via
  `BrainrotService.restorePlacements` (committed list only, after plot assign).
- Statistics and Brainrot XP are live-pushed on kill (`ProfileUpdated`); time played includes
  the current session in client payloads and is committed on save/leave.

---

## Committed lawn checkpoint

The DataStore lawn is a **checkpoint**, not a live mirror of the plot:

- **Updated** on Victory (`SaveService.commitLawn` → current plants + HP);
  Day Select / Reset (`clearCommittedLawn` → empty). Defeat does **not** empty
  the checkpoint — it calls `restoreCommittedLawn` so the player retries the
  same day with the prior clear's plants.
- **Used** by leave, autosave, and shutdown (`collectSnapshot` reads the
  checkpoint — never mid-day live placements).
- **Brainrot XP** is the same idea: a **Start Day snapshot**. Live grants during
  the day are not written to DataStore until **Victory** (`commitBrainrotXp`).
  Defeat restores that snapshot onto the profile (inspect bars / nameplates
  rewind with Rewind). Leave / autosave persist the snapshot, not mid-day XP.

So if a player starts Day 2, plants more Brainrots, then leaves: only the lawn
from after Day 1 victory is saved. Day 2 mid-day plants are discarded; on rejoin
they are back in Preparation on Day 2 with the prior-day lawn and can press
Start Day again. Day 1 has an empty checkpoint and purse → 125.

Concurrent saves queue a resave so victory/leave are never dropped while an
autosave `UpdateAsync` is in flight.

---

## Leave / rejoin behavior

If a player leaves mid-day or before Start Day:

- Save progression (day, hearts, brains, unlocks) **and** the **committed** lawn
  (last victory / wipe) — not plants placed during the unfinished day.
- End the active day; clear monster / coin runtimes on plot release.

On rejoin:

- Restore day, hearts, brains, unlocks / loadout.
- Restore the committed lawn (positions + HP from last checkpoint).
- Coins via `applyDayPurse` (Day 1 → 125; later → 0).
- Monsters are never restored — press Start Day to play again.

---

## Session lawn rules

| Event | Live Brainrots | Committed / DataStore lawn | Coins | Monsters / ground coins | Brainrot XP |
| ----- | -------------- | -------------------------- | ----- | ----------------------- | ----------- |
| Victory → next day | **Keep** (current HP) | **Commit** then save | Day 1 → 125; else **0** | Cleared | **Commit** live XP |
| Defeat | Mid-day cleared; **restore checkpoint**; **same day** | **Unchanged** (restored to plot) | Day purse (Day 1 → 125; else **0**) | Cleared | **Restore** Start Day snapshot |
| Rewind (`RewindDay`) | Checkpoint already on plot | Unchanged | Unchanged | — | Already restored on defeat |
| Day Select | Cleared | **Empty** then save | Day 1 → 125; else **0** | Cleared | Unchanged (no day in progress) |
| Leave / Rejoin | Cleared on leave | **Checkpoint** restored | Day purse (not saved) | Cleared | Unfinished-day XP **not** kept |
| Mid-day place / damage | Live only | Unchanged until victory | Session purse | — | Live only until victory |
| Reset Progress | Cleared | **Empty** | **125** | Cleared | Cleared |

See `LEVELS.md` / `BALANCE.md` — campaign spawn pressure assumes carry-over.

---

## Reset Progress

A confirmed Reset (via Settings **Danger Zone** → red **Reset Progress**,
**two confirmations**, then `ResetProgress` remote — see `UI.md` /
`NETWORKING.md`) deletes all saved progress and returns the player to day 1
with starter coins (125), full hearts, default unlocks/loadout, empty lawn, and
empty statistics. Never erase save data unless Reset is explicitly confirmed.
