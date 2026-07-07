# BVM Level System

BVM is a **level-based campaign** (PvZ-style), not an endless wave grinder.
Players progress through a sequence of discrete, hand-authored **levels**; each
level is won by surviving its scripted monsters and lost if the house is
breached. **`LevelService` is the only system that advances levels**
(`.cursorrules`) — no other service starts a level, spawns its monsters, or
grants its completion reward.

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Levels vs. internal waves

- A **level** is one campaign encounter (e.g. "Level 1 — First Contact").
- Within a level, monsters arrive in an ordered list of **spawn groups** — the
  internal "waves". A progress bar fills as groups are spawned/cleared, and the
  final group is the **big wave** (the PvZ "flag"), preceded by a warning.
- Clearing every group (no monsters left alive) → **Victory** → unlock and
  advance to the next level. A monster reaching the house → **Defeat** → retry
  the same level.

This keeps the moment-to-moment PvZ pacing (rising intensity into a final rush)
while making overall progress a finite, designed campaign rather than infinite
scaling.

---

## Per-level loop

```
Start Level ─► Countdown ─► Active (plant + fight)
   ▲                              │
   │                  spawn groups run
   │                  (progress bar → big wave)
   │                              │
   └──── Reward + unlock next ◄── Victory
                                  │
              Defeat (house breached) ─► retry level
```

During `Preparation`, planting and ground-coin drops are blocked. Both unlock
when the level enters `Active` (after countdown).

Phases (see `Shared.Constants.PHASE`): `Preparation`, `Countdown`, `Active`,
`Victory`, `Defeat`.

---

## Level definitions (data-driven) ✅ (data seeded)

Levels are **authored data**, not generated. They live in the
`ReplicatedStorage.Shared.Levels` registry (mirrors the Brainrots/Monsters
registries). Add a level by adding one entry — never branch on level numbers.

API:

```lua
local Levels = require(ReplicatedStorage.Shared.Levels)
Levels.get(id)             -- LevelDefinition?  (nil if unknown)
Levels.getByNumber(n)      -- LevelDefinition?  (campaign position, 1-based)
Levels.getOrdered()        -- { LevelDefinition }  in `number` order
Levels.exists(id)          -- boolean
Levels.getAll()            -- { [id]: LevelDefinition }  (do not mutate)
Levels.count()             -- number of authored levels
```

### `LevelDefinition` (`Shared.Types`)

| Field    | Type             | Meaning                                       |
| -------- | ---------------- | --------------------------------------------- |
| `id`     | string           | Unique key (matches registry key)             |
| `number` | number           | 1-based campaign position (ordering + display)|
| `name`   | string           | Display name                                  |
| `groups` | `{ SpawnGroup }` | Ordered internal waves to spawn               |
| `reward` | number?          | Completion coins (defaults to economy base)   |

### `SpawnGroup` (`Shared.Types`)

| Field          | Type     | Meaning                                          |
| -------------- | -------- | ------------------------------------------------ |
| `monsterId`    | string   | Id in the `Shared.Monsters` registry             |
| `count`        | number   | How many monsters in this group                  |
| `startDelay`   | number?  | Seconds before this group (after the previous)   |
| `spawnInterval`| number?  | Seconds between monsters within the group        |
| `isBigWave`    | boolean? | Marks the big final wave (flag) on the progress bar |

Omitted timing falls back to `LevelConfig.DEFAULT_SPAWN_INTERVAL` /
`DEFAULT_GROUP_DELAY`.

### Seeded campaign ✅ (data only)

Two opening levels are seeded using **Zombie**, each ending in an `isBigWave` group:

| Level | name          | enemies (count per group)                  |
| ----- | ------------- | ------------------------------------------ |
| 1     | First Contact | 1, 2, **2** TutorialZombie                 |
| 2     | Rising Tide   | 2, 2 TutorialZombie, **2** EarlyZombie     |
| 3     | Greenhorns    | 2, 3 EarlyZombie, **3** Zombie             |

Richer monster types per level arrive with Milestone 10.

### Difficulty ramp (early campaign)

Progression is tuned in **small steps** across level data — never a single giant
spike between adjacent levels:

1. **Enemy tier** — `TutorialZombie` (150 HP, slow) → `EarlyZombie` (250 HP) →
   standard `Zombie` (1000 HP). A level should introduce at most one tier step.
2. **Count** — total enemies per level rise slowly (Level 1: 5 → Level 2: 6 →
   Level 3: 8).
3. **Pacing** — `startDelay` and `spawnInterval` shrink gradually; the first
   group always leaves time to plant after countdown.
4. **Big wave** — the final group is the hardest step *within* a level, not a
   jump to endgame tuning.

Level 1 is intentionally gentle: **25-second grace** before the first enemy,
`TutorialZombie` spawns one at a time, and starting coins cover a coin producer
plus an attacker (see `EconomyConfig.STARTING_COINS`).

---

## Configuration ✅

Global pacing lives in `Shared.Config.LevelConfig` (frozen). Per-level content
is in the registry above, not here.

| Key                     | Value | Meaning                                    |
| ----------------------- | ----- | ------------------------------------------ |
| `PREPARATION_TIME`      | 30    | Reserved prep window before Start (planned) |
| `COUNTDOWN_TIME`        | 3     | Seconds after pressing Start Level         |
| `STARTING_PLAYER_HEALTH`| 100   | Player base health                         |
| `BIG_WAVE_WARNING_TIME` | 4     | Lead time for the "huge wave!" banner      |
| `DEFAULT_SPAWN_INTERVAL`| 1.5   | Fallback gap between monsters in a group   |
| `DEFAULT_GROUP_DELAY`   | 6     | Fallback gap between groups                |

These (and the per-level data) are the knobs Milestone 15 (Balancing) tunes.

---

## Responsibilities (Milestone 8) ✅

`LevelService` owns:

- Preparation phase + countdown timing.
- Handling the `StartLevel` request (validated server-side).
- Playing the current level's `groups` in order: driving `EnemyService` to spawn
  (it decides *what* and *when*; `EnemyService` handles *how* monsters
  move/fight), and announcing the big wave.
- Tracking progress and detecting **Victory** (all groups spawned and cleared)
  vs. **Defeat** (a monster reaches the house).
- On **Victory**: clearing the plot (Brainrots, monsters, ground coins) and
  resetting coins to `EconomyConfig.STARTING_COINS` (PvZ-style fresh start),
  then unlocking/advancing to the next level.
- Broadcasting phase / level number / progress via `LevelStateChanged` (see
  `NETWORKING.md`).

Progression is **linear**: victory advances `currentLevel` and raises
`highestLevel`; players may replay any unlocked level via Level Select
(`SelectLevel`, UI milestone). There is no endless mode yet (could be added
later as its own mode).

---

## Interaction with save (see `SAVE_SYSTEM.md`)

- The **current level** and **highest unlocked level** are persisted.
- Active monsters, projectiles, and level timers are **not** persisted.
- If a player leaves mid-level: save the battlefield + level progression, end the
  active level.
- On rejoin: restore the battlefield, then the saved level **starts over from the
  beginning** and the player must press Start Level again.
