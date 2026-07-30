# BVM Day System (campaign levels)

BVM is a **day-based campaign** (PvZ-style), not an endless wave grinder.
Players progress through a sequence of discrete, hand-authored **days**; each
day is won by surviving its scripted monsters and lost if the house is
breached. **`LevelService` is the only system that advances days**
(`.cursorrules`) — no other service starts a day, spawns its monsters, or
grants its completion reward.

Player-facing UI says **Day** (e.g. "Day 1 — First Contact", "Start Day").
Code, remotes, and save fields stay `Level*` / `levelNumber` for stability.

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Days vs. internal waves

- A **day** is one campaign encounter (e.g. "Day 1 — First Contact").
- Within a day, monsters arrive in an ordered list of **spawn groups** — the
  internal "waves". A progress bar fills as groups are spawned/cleared, and the
  final group is the **big wave** (the PvZ "flag"), preceded by a warning.
- Clearing every group (no monsters left alive) → **Victory** → brains reward +
unlock next day. A monster reaching the house → **−1 heart**; at **0 hearts** →
**Defeat** → reset to **Day 1** (lawn cleared; `highestUnlocked` kept for Day Select).

This keeps the moment-to-moment PvZ pacing (rising intensity into a final rush)
while making overall progress a finite, designed campaign rather than infinite
scaling.

---

## Per-day loop

```
Start Day ─► Active (plant + fight; monsters march from forest)
   ▲                              │
   │                  spawn groups run
   │                  (progress bar → big wave)
   │                              │
   └──── Reward + unlock next ◄── Victory
         (keep planted Brainrots;     │
          reset coins to STARTING)    │
              Defeat (0 hearts) ─► clear lawn + coins → Day 1
```

During `Preparation`, planting and ground-coin drops are blocked. Both unlock
when the day enters `Active`. There is **no idle countdown**: monsters spawn
deep in the dark forest (`MonsterConfig.SPAWN_COLUMN_OFFSET` columns east of
the lawn) and walk west into the plot — that approach is the plant/setup
window. First spawn groups use a short `startDelay` (~1.5s); travel time to
the lawn edge is ~20–30s depending on species speed.

**Lawn carry-over:** after **Victory**, planted Brainrots (and their remaining
HP) stay on the plot. Coin purse: **Day 1 → `STARTING_COINS` (125)**; after any
later day ends → **0**. After **Defeat**, the lawn is cleared and `currentLevel`
resets to **Day 1** with 125 coins (`highestUnlocked` kept for Day Select).
**Day Select** clears the lawn and applies the purse for the selected day.
**Rejoin restores** the **committed** lawn (plants from the last victory /
wipe — not mid-day placements on an unfinished day). Brainrots only attack /
spit coins while the day is **`Active`**.

Phases (see `Shared.Constants.PHASE`): `Preparation`, `Countdown` (unused /
optional), `Active`, `Victory`, `Defeat`.

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

| Field     | Type             | Meaning                                       |
| --------- | ---------------- | --------------------------------------------- |
| `id`      | string           | Unique key (matches registry key)             |
| `number`  | number           | 1-based campaign position (ordering + display)|
| `name`    | string           | Display name                                  |
| `groups`  | `{ SpawnGroup }` | Ordered internal waves to spawn               |
| `weather` | string?          | Optional weather id (`Night`, `NightFog`, …); see `WEATHER.md` |
| `reward`  | number?          | Completion coins (defaults to economy base)   |

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

### Seeded campaign ✅ (Milestones 8 + 10; retuned for lawn carry-over)

All early levels use the same **`Zombie`** grunt stats. Day 1 is authored for an
**empty lawn**; Days 2+ assume the player kept plants from prior victories, so
counts and pacing are higher than a wipe-each-day campaign:

| Day | name              | mix (count per group) · total                  |
| ----- | ----------------- | ---------------------------------------------- |
| 1     | First Contact     | 1, 2, **2** Zombie · **5**                     |
| 2     | Rising Tide       | 2, 3, **3** Zombie · **8**                     |
| 3     | Greenhorns        | 3, 3, **4** Zombie · **10**                    |
| 4     | Pressing Forward  | 3, 4, **5** Zombie · **12**                    |
| 5     | Goblin Scout      | 4 Zombie, **2** Goblin, 3 Zombie, **3** Goblin · **12** |
| 6     | Quick Feet        | 4 Zombie, 3 Goblin, 3 Zombie, **4** Goblin · **14** |
| 7     | Crooked Charge    | 4 Goblin, 4 Zombie, 3 Goblin, **3** Zombie · **14** |
| 8     | Hold the Line     | 4 Zombie, 4 Goblin, 3 Zombie, **5** Goblin · **16** |
| 9     | Before the Banner | 5 Goblin, 4 Zombie, 4 Goblin, **5** Zombie · **18** |
| 10    | Goblin Elite      | 5 Zombie, 5 Goblin, 4 Zombie, **1** GoblinElite · **15** |
| 11    | Advancing Ranks   | 5 Zombie, 5 Goblin, 4 Zombie, **5** Goblin · **19** |
| 12    | Iron Ranks        | 5 Goblin, 5 Zombie, 5 Goblin, **6** Zombie · **21** |
| 13    | Elite Vanguard    | 5 Zombie, 5 Goblin, 4 Zombie, **1** GoblinElite · **15** |
| 14    | Elite Pressure    | 5 Zombie, **1** GoblinElite, 6 Goblin, **5** Zombie · **17** |
| 15    | Night Falls       | 5 Zombie, 5 Goblin, 2 Vampire, **3** Vampire · **15** |
| 16    | Bloodlust Rising  | 5 Zombie, 5 Goblin, 4 Vampire, **4** Vampire · **18** |
| 17    | Crimson Vanguard  | 5 Zombie, 4 Vampire, 5 Goblin, **1** GoblinElite · **15** |
| 18    | Twin Terror       | 5 Zombie, 5 Vampire, **1** GoblinElite, 5 Vampire · **16** |
| 19    | Final Bloodline   | 5 Zombie, 5 Vampire, **1** GoblinElite, 6 Vampire · **17** |
| 20    | Duke Vampire      | 5 Zombie, 5 Vampire, 5 Goblin, **1** DukeVampire · **16** |
| 21    | Fogbound          | Night · Zombie/Goblin/Vampire · **15** |
| 22    | Mist March        | Night · + GoblinElite finale · **14** |
| 23    | Quiet Night       | Night · easier breather · **13** |
| 24    | Blood Fog         | Night · DukeVampire finale · **15** |
| 25    | Webbed Path       | NightFog · **Spider** intro · **13** |
| 26    | Silk and Steel    | NightFog · Spider + GoblinElite · **12** |
| 27    | Lull in the Mist  | NightFog · easier mix · **13** |
| 28    | Duke's Night      | NightFog · DukeVampire finale · **13** |
| 29    | Closing Webs      | NightFog · Spider pressure + Elite · **14** |
| 30    | Queen Spider      | NightFog · **QueenSpider** boss finale · **13** |

Days **21–24** use `weather = "Night"` (moonlit night, full lawn plantable).
Days **25–30** use `weather = "NightFog"` (night + visible forest/east-lawn fog;
easternmost 3 columns unplantable; monsters stay visible — see `WEATHER.md`).
Fog days keep moderate totals and alternate easier/harder pacing.

Milestone 10 adds roster variety through **one new monster at a time**, not a
bundle of types in a single level.

Introduction cadence:

- **Every 5 levels:** introduce exactly **one** new non-boss monster (Level 5 =
  `Goblin`; Level 15 = `Vampire`; Level 25 = `Spider`).
- **Every 10 levels:** introduce **one** boss as the big final wave (Level 10 =
  `GoblinElite`; Level 20 = `DukeVampire`; Level 30 = `QueenSpider`).
- Levels between introductions mix only monsters the player has already seen,
  ramping count/pacing slowly — sometimes the same difficulty as the prior level.
- Once a boss has been introduced, it can also **recur as a mixed-in miniboss**
  in later levels (not always the big-wave finale) instead of only ever
  appearing once — e.g. `GoblinElite` / `DukeVampire` recur through the fog stretch.

### Difficulty ramp (early campaign)

Progression is tuned in **small steps** across level data — never a single giant
spike between adjacent levels. **Lawn carry-over** is part of the balance: later
days expect a stronger board, so spawn pressure rises to match.

1. **Species** — new monster types enter one at a time (Level 5 = `Goblin`; Level 10 = `GoblinElite` boss).
2. **Count** — total enemies per level rise slowly (Level 1: 5 → Level 2: 8 →
   Level 3: 10 → … → Level 9: 18).
3. **Pacing** — inter-group `startDelay` and `spawnInterval` shrink gradually;
   first-group delay is short (~1.5s) because plant time is the forest march
   (`SPAWN_COLUMN_OFFSET` × `secondsPerGrid`).
4. **Big wave** — the final group is the hardest step *within* a level, not a
   jump to endgame tuning. Level 10 Goblin Elite spawns with lead time (`startDelay` 18s).

Level 1 is intentionally gentle: one zombie at a time with long gaps, plus enough
starting coins for Ballerina + Tung Tung (`EconomyConfig.STARTING_COINS` = 125).
The first zombie appears in the forest almost immediately and takes ~21s to
reach the lawn.

---

## Configuration ✅

Global pacing lives in `Shared.Config.LevelConfig` (frozen). Per-level content
is in the registry above, not here.

| Key                     | Value | Meaning                                    |
| ----------------------- | ----- | ------------------------------------------ |
| `PREPARATION_TIME`      | 30    | Reserved prep window before Start (planned) |
| `COUNTDOWN_TIME`        | 0     | Unused (optional Countdown experiments)    |
| `STARTING_PLAYER_HEALTH`| 5     | Hearts at day start (one lost per breach) |
| `BIG_WAVE_WARNING_TIME` | 5     | Lead time for the "huge wave!" banner      |
| `DEFAULT_SPAWN_INTERVAL`| 1.8   | Fallback gap between monsters in a group   |
| `DEFAULT_GROUP_DELAY`   | 7     | Fallback gap between groups                |

Milestone 14 balance pass: **`docs/BALANCE.md`**. Per-level spawn data lives in
`Shared.Levels`.

---

## Responsibilities (Milestone 8) ✅

`LevelService` owns:

- Preparation phase; Start Day enters Active immediately (forest march = setup).
- Handling the `StartLevel` request (validated server-side).
- Playing the current level's `groups` in order: driving `EnemyService` to spawn
  (it decides *what* and *when*; `EnemyService` handles *how* monsters
  move/fight), and announcing the big wave.
- Tracking progress and detecting **Victory** (all groups spawned and cleared)
  vs. **Defeat** (a monster reaches the house).
- On **Victory**: clear monsters / projectiles / ground coins; **keep planted
  Brainrots** (current HP); set coin purse via `applyDayPurse` (Day 1 → 125,
  later days → 0); then unlock/advance to the next level.
- On **Defeat**: clear Brainrots, monsters, ground coins; set `currentLevel` to
  **1**; hearts refill; purse → 125 (`highestUnlockedLevel` unchanged). Phase
  stays **`Defeat`** until the player presses **Start Day 1**. Passive and
  ability coin drops are blocked outside `Active`.
- On **Day Select**: full lawn wipe; purse via `applyDayPurse` for the selected day.
- Broadcasting phase / level number / progress / `weather` via `LevelStateChanged`
  (see `NETWORKING.md`). Applying NightFog plant rules on prep / lawn restore
  (`WEATHER.md`).

Progression is **linear**: victory advances `currentLevel` and raises
`highestLevel`; players may replay any unlocked level via Day Select
(`SelectLevel`, UI milestone). There is no endless mode yet (could be added
later as its own mode).

---

## Interaction with save (see `SAVE_SYSTEM.md`)

- The **current level**, **highest unlocked level**, and **hearts** are persisted.
- Hearts are **progressive** across days (not refilled on victory / Start Day /
  day select). Full refill on **defeat** (and Reset Progress). Defeat also
  sets the current day back to **1**.
- **Coins** — Day 1 → `STARTING_COINS` (125); later days → **0** after each day
  ends (`CoinService.applyDayPurse`). Not DataStore-persisted.
- Planted Brainrots are **persisted as a victory checkpoint** (id, tile, HP) and
  restored on rejoin. Defeat / Day Select clear the lawn (and the committed
  checkpoint). Mid-day plants on an unfinished day are **not** saved.
- Monsters, projectiles, and level timers are never persisted.
- If a player leaves mid-day or before Start Day: save progression + committed
  lawn only; clear combat runtimes. The unfinished day resets to Preparation.
- On rejoin: restore day + hearts + brains/unlocks + committed plants; coins via
  day purse; press Start Day.
