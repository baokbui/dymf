# BVM Save System

Player progress is persistent across sessions. **Only `SaveService` touches
DataStore** — no other service accesses it (`AGENTS.md`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## What is saved vs. not

Saved (player-owned progression):

- Current level (campaign day)
- Highest unlocked level
- Brains
- Player health (hearts — progressive across days)
- **Planted Brainrots** (id, tile, remaining HP, remaining uses for `charges` plants like Boneca)
- Unlocks
- Equipped loadout
- Upgrades (`WalkSpeed` ranks, **Magnet** 1–5)
- Statistics
- Intro popup flags and optional v7 `hiddenDayPending`
- **Brainrot XP** (per registry id — shared species pool)
- **Claimed evolution tiers** (per Brainrot id, after brains spend)
- Daily quest assignment, progress, snapshotted rewards, and claimed flags (v8)
- Welcome/weekly counts, last claim date, and snapshotted current login offer (v9)
- Permanent achievement progress and claimed flags (v10)
- Weekly quest progress/claims, finite first-time rewards and Brainrot tickets (v11)
- Future progression systems (collected bosses, …)

Not saved (transient / runtime):

- **Coins** (Day 1 → `STARTING_COINS`; later days → 0 via `applyDayPurse` on
  join / day end; Rewind → `REWIND_COINS` — never persisted as a balance)
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
| `version`      | number (`SAVE_VERSION` = 11)|
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
| `evolutions`   | `{ [brainrotId]: { rarity } }` claimed Epic→God tiers |
| `introducedMonsters` | `{ string }` (monster intro popups already shown) |
| `introducedBrainrots` | `{ string }` (Brainrot intro popups already shown) |
| `introducedMechanics` | `{ string }` (mechanic intro popups already shown, e.g. Grave) |
| `hiddenDayPending` | boolean? (true after Day 40 is cleared until the Hidden Day ends) |
| `retention` | Quest progress/claims, login counts/date/offer achievement flags, weekly quests and tickets (internal version 4) |
| `collectedBosses` | `{ CollectedBoss }?` 🔜 M21 |

`PlantedBrainrot` = `{ instanceId, brainrotId, position: { row, column }, health, charges? }`.
`charges` is only written for definitions with `charges` (Boneca headbutts left).
Missing on older saves means full uses. A saved 0 is not restored. Immune charge
plants save `health = 0`, so restore decides by `charges` instead of HP.
`CollectedBoss` (planned) = `{ monsterId, slotIndex, collectedAtLevel? }` — see
`HOUSE.md`.

Relevant constants (`Shared.Constants`):

- `SAVE_VERSION = 11` — bump when the schema changes; migrate older payloads.
  **v4 → v5:** add `brainrotXp` (empty map if missing).
  **v5 → v6:** add `evolutions` (empty map if missing).
  **v6 → v7:** add `introducedMechanics` (empty list if missing).
  `hiddenDayPending` was optional in v7; missing means false.
  **v7 → v8:** sanitize daily quests; missing data means fresh quests.
  **v8 → v9:** preserve quests; initialize login welcome/weekly state if missing.
  **v9 → v10:** preserve both tracks; initialize permanent achievements.
  **v10 → v11:** retain paid welcome steps/date; remove recurring weekly login
  state, add weekly quests and ticket count. Legacy completed welcome tracks
  receive one final ticket catch-up (see `RETENTION.md`).
  Catch up owned types/claimed Epic from sanitized profile fields, not intro flags.
  Newer-than-supported schemas are refused, never downgraded.
- `SAVE_DATASTORE_NAME = "BVZ_PlayerData_v1"` — owned solely by `SaveService`.
  Retains its original `BVZ_` prefix despite the rename to Monsters, so existing
  player saves are never orphaned (the DataStore key is identity, not branding).

---

## Responsibilities (Milestone 9) ✅

`SaveService` (server):

- Load a player's `SaveData` on join (defaulting new players from config:
  `EconomyConfig.STARTING_COINS`, `LevelConfig.STARTING_PLAYER_HEALTH`, level 1).
- Migrate older `version` payloads forward.
- Persist on leave, periodic autosave, day victory, defeat, and **loadout changes** (`saveNow` as soon as the shop lineup is set). Shutdown waits for an in-flight save to finish so Studio stop does not drop that write.
- Own a **committed lawn** checkpoint (`commitLawn` / `clearCommittedLawn` /
  `restoreCommittedLawn`): only victory / day-select wipe / load / reset update
  the checkpoint list; leave and autosave write that checkpoint, not mid-day
  live plants. Defeat **restores** the checkpoint onto the plot (does not empty it).
- Leave-save is connected in `init()` so it runs **before** `PlotService` /
  `BrainrotService` clear the lawn on `PlayerRemoving`. Snapshot is captured
  synchronously; if a save is already in flight, the leave payload is queued
  and flushed when the in-flight write finishes (never dropped).
- Writes via `UpdateAsync` with JSON round-trip, bounded retries, and session /
  revision guards. Studio cloud errors can still appear; API access must be
  enabled for real saves. Exhausted or uncertain writes end the unsafe session;
  failed loads do not substitute writable defaults. See the retention section.
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
  rewind on defeat, before Rewind). Leave / autosave persist the snapshot, not mid-day XP.

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
| Rewind (`RewindDay`) | Checkpoint already on plot | Unchanged | **`REWIND_COINS` (200)** | — | Already restored on defeat |
| Day Select | Cleared | **Empty** then save | Day 1 → 125; else **0** | Cleared | Unchanged (no day in progress) |
| Leave / Rejoin | Cleared on leave | **Checkpoint** restored | Day purse (not saved) | Cleared | Unfinished-day XP **not** kept |
| Mid-day place / damage | Live only | Unchanged until victory | Session purse | — | Live only until victory |
| Reset Progress | Cleared | **Empty** | **125** | Cleared | Cleared |

See `LEVELS.md` / `BALANCE.md` — campaign spawn pressure assumes carry-over.

---

## Hidden Day persistence

Clearing Day 40 saves current day 41 plus `hiddenDayPending = true` and the Day
40 victory lawn. Pending/active Hidden Day displays Night. Continue after the
Day 40 reward enters Preparation; Start Day is manual. Leaving an unfinished
Hidden Day preserves its pending flag, not monsters, kill brains, or elapsed
time. Rejoin restores the checkpoint and Preparation for a full attempt.
On finish the flag clears; a clear commits lawn/XP, a loss restores the Day 40
lawn and XP checkpoint. Kill brains and leftover conversion pay at finish;
both outcomes proceed to Day 41 via Continue. Day Select and Studio FORCE_DAY
clear the pending state.

## Retention foundation (Milestone 20)

Schema v11 persists daily/weekly quests, finite first-time rewards, tickets and achievements under `retention`.
Ordinary `saveNow` queues snapshots; `claimRetentionReward` durably saves
the claim flag/date together with its brains/statistic, permanent upgrade or
ticket grant. Ticket redemption commits ticket consumption with the store unlock
before UI success. Queued save/leave snapshots merge the committed reward delta
and claim state without replacing concurrent purchases/progress. `claimDailyQuest`
delegates to this writer for API compatibility. Quest credit survives
failed days; Brainrot XP rollback is unchanged.
Achievement progress/claims survive day resets and defeat. A claim does not
expire at midnight. Next-goal hints and current-attempt breach markers are
runtime-only. Confirmed Reset Progress clears all retention tracks.

SessionStore acquires/renews a 180s session lease via UpdateAsync. All writes
check owner/revision and use operation ids to reconcile lost responses. Autosave
renews every 60s; leave/shutdown releases only its own lease. Unavailable loads
never become writable defaults; uncertain exhausted writes end the unsafe
session. Retire legacy published writers at deployment; they do not honor leases.
See `RETENTION.md` for isolated test coverage and remaining live QA.

## Studio overrides

After save hydration, `SaveService.hydrateProgression` applies `DevConfig`
(day, roster, Brainrot level/tier, brains, and coins). Overrides only run when
`ENABLED` and `RunService:IsStudio()` are true. They can still be saved; Studio
does not use a separate DataStore name. FORCE_DAY is clamped to the numbered
registry count, applies on join, and clears Hidden Day. See `IMPLEMENTATION_NOTES.md`.

## Reset Progress

A confirmed Reset (via Settings **Danger Zone** → red **Reset Progress**,
**two confirmations**, then `ResetProgress` remote — see `UI.md` /
`NETWORKING.md`) deletes all saved progress and returns the player to day 1
with starter coins (125), full hearts, default unlocks/loadout, empty lawn, and
empty statistics. Never erase save data unless Reset is explicitly confirmed.
