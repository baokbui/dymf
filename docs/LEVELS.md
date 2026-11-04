# BVM Day System (campaign levels)

BVM is a **day-based campaign** (PvZ-style), not an endless wave grinder.
Players progress through a sequence of discrete, hand-authored **days**; each
day is won by clearing its scripted monsters and lost when all house hearts
are gone (one heart per breach). **`LevelService` is the only system that advances days**
(`AGENTS.md`) — no other service advances the campaign. EnemyService performs spawns; abilities
can summon minions, GraveService spawns grave monsters, and ProgressService
owns balance grants requested by LevelService.

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
leftover pocket coins convert to brains + unlock next day. A monster reaching the house → **−1 heart**; at **0 hearts** →
**Defeat** → Game Over → **Rewind** stays on the failed day with the last
victory lawn restored (`highestUnlocked` kept for Day Select).

This keeps the moment-to-moment PvZ pacing (rising intensity into a final rush)
while making overall progress a finite, designed campaign rather than infinite
scaling.

---

## Per-day loop

```
Start Day ─► Countdown (Day starting in 3…0) ─► Active (plant + fight)
   ▲                              │
   │                  spawn groups run
   │                  (progress bar → big wave)
   │                              │
   └──── Reward + unlock next ◄── Victory
         (keep planted Brainrots;     │
          reset coins via day purse)  │
              Defeat (0 hearts) ─► Game Over → Rewind same day
                                   (restore victory checkpoint lawn)
```

During `Preparation`, planting and ground-coin drops are blocked. After
**Start Day**, a **3…0** overlay plays (`Countdown`), then the day enters
`Active` and both unlock. Monsters spawn deep in the dark forest
(`MonsterConfig.SPAWN_COLUMN_OFFSET` columns east of the lawn) and walk west
into the plot — that approach is the plant/setup window. First spawn groups
use a short `startDelay` (~1.5s); travel time to the lawn edge is ~20–30s
depending on species speed.

**Lawn carry-over:** after **Victory**, planted Brainrots (and their remaining
HP) stay on the plot. Coin purse: **Day 1 → `STARTING_COINS` (125)**; after any
later day ends → **0**. After **Defeat**, the player stays on the failed day;
mid-day plants are cleared and the **last victory checkpoint** lawn is restored;
hearts refill; leftover coins convert then `applyDayPurse` (Day 1 → 125, later → 0). Phase stays
**`Defeat`** until **Rewind Day N** (`RewindDay` remote) returns them to
`Preparation` on that day with **`REWIND_COINS` (200)**.
**Day Select** clears the lawn and applies the purse for the selected day.
**Rejoin restores** the **committed** lawn (plants from the last victory /
wipe — not mid-day placements on an unfinished day). Brainrots only attack /
spit coins while the day is **`Active`**.

Phases (see `Shared.Constants.PHASE`): `Preparation`, `Countdown` (3…0 Start
Day overlay), `Active`, `Victory`, `Defeat`.

---

## Level definitions (data-driven) ✅ (data seeded)

Levels are **authored data**, not generated. They live in the
`ReplicatedStorage.Shared.Levels` registry (mirrors the Brainrots/Monsters
registries). Add ordinary days with registry entries. The Day 40 → Hidden Day transition is
an explicit special case in LevelService.

API:

```lua
local Levels = require(ReplicatedStorage.Shared.Levels)
Levels.get(id)             -- LevelDefinition?  (nil if unknown)
Levels.getByNumber(n)      -- LevelDefinition?  (campaign position, 1-based)
Levels.getOrdered()        -- { LevelDefinition }  in `number` order
Levels.exists(id)          -- boolean
Levels.getAll()            -- { [id]: LevelDefinition }  (do not mutate)
Levels.count()             -- 50 numbered campaign days
Levels.getHidden()         -- separate unnumbered Hidden Day definition
Levels.firstDayForMonster(id) -- first authored numbered day, nil if absent
```

### `LevelDefinition` (`Shared.Types`)

| Field     | Type             | Meaning                                       |
| --------- | ---------------- | --------------------------------------------- |
| `id`      | string           | Unique key (matches registry key)             |
| `number`  | number           | 1-based campaign position (ordering + display)|
| `name`    | string           | Display name                                  |
| `groups`  | `{ SpawnGroup }` | Ordered internal waves to spawn               |
| `weather` | string?          | Optional weather id (`Night`, `NightFog`, …); see `WEATHER.md` |
| `graves`  | boolean?         | If true, place 3–5 fog graves (`GraveConfig.COUNT_MIN`/`MAX`) |
| `reward`  | number?          | Legacy/reserved; victory uses ProgressService brains + leftover conversion |

### `SpawnGroup` (`Shared.Types`)

| Field          | Type     | Meaning                                          |
| -------------- | -------- | ------------------------------------------------ |
| `monsterId`    | string   | Id in the `Shared.Monsters` registry             |
| `count`        | number   | How many monsters in this group                  |
| `startDelay`   | number?  | Seconds before this group (after the previous)   |
| `spawnInterval`| number?  | Seconds between monsters within the group        |
| `isBigWave`    | boolean? | Marks the big final wave (flag) on the progress bar |
| `row`          | number?  | Fixed anchor row (lowest occupied row). Omit for `randomRowForSpan` (e.g. Queen Spider `laneSpan` 3 → random among anchors that fit). |

Omitted timing falls back to `LevelConfig.DEFAULT_SPAWN_INTERVAL` /
`DEFAULT_GROUP_DELAY`.

### Seeded campaign ✅ (Milestones 8 + 10; retuned for lawn carry-over)

Every scheduled spawn carries the group that produced it, including the final
unit before a group transition. Species, row settings, start delays, and
big-wave warnings therefore follow the authored groups below. Hidden Day
permits multiple Elites; normal duplicate-boss guards still apply. Rejected
spawn attempts are logged and counted as attempted progress; victory still
requires all living enemies and pending grave spawns to clear.

All early levels use the same **`Zombie`** grunt stats. Day 1 is authored for an
**empty lawn**; Days 2+ assume the player kept plants from prior victories, so
counts and pacing are higher than a wipe-each-day campaign:

| Day | Name | Weather | Authored groups · total |
| --- | --- | --- | --- |
| 1 | First Contact | Day | 1 Zombie, 2 Zombie, 2 Zombie · **5** |
| 2 | Rising Tide | Day | 2 Zombie, 3 Zombie, 3 Zombie · **8** |
| 3 | Greenhorns | Day | 3 Zombie, 3 Zombie, 4 Zombie · **10** |
| 4 | Pressing Forward | Day | 3 Zombie, 4 Zombie, 5 Zombie · **12** |
| 5 | Goblin Scout | Day | 4 Zombie, 2 Goblin, 3 Zombie, 3 Goblin · **12** |
| 6 | Quick Feet | Day | 4 Zombie, 3 Goblin, 3 Zombie, 4 Goblin · **14** |
| 7 | Crooked Charge | Day | 4 Goblin, 4 Zombie, 3 Goblin, 3 Zombie · **14** |
| 8 | Hold the Line | Day | 4 Zombie, 4 Goblin, 3 Zombie, 5 Goblin · **16** |
| 9 | Before the Banner | Day | 5 Goblin, 4 Zombie, 4 Goblin, 5 Zombie · **18** |
| 10 | Goblin Elite | Day | 5 Zombie, 5 Goblin, 4 Zombie, 1 GoblinElite · **15** |
| 11 | Advancing Ranks | Day | 5 Zombie, 5 Goblin, 4 Zombie, 5 Goblin · **19** |
| 12 | Iron Ranks | Day | 5 Goblin, 5 Zombie, 5 Goblin, 6 Zombie · **21** |
| 13 | Elite Vanguard | Day | 5 Zombie, 1 GoblinElite, 5 Goblin, 5 Zombie · **16** |
| 14 | Elite Pressure | Day | 1 GoblinElite, 5 Zombie, 6 Goblin, 5 Zombie · **17** |
| 15 | Night Falls | Day | 5 Zombie, 5 Goblin, 2 Vampire, 3 Vampire · **15** |
| 16 | Bloodlust Rising | Day | 5 Zombie, 5 Goblin, 4 Vampire, 4 Vampire · **18** |
| 17 | Crimson Vanguard | Day | 5 Zombie, 1 GoblinElite, 4 Vampire, 6 Goblin · **16** |
| 18 | Twin Terror | Day | 5 Zombie, 5 Vampire, 1 GoblinElite, 5 Vampire · **16** |
| 19 | Final Bloodline | Day | 1 GoblinElite, 5 Zombie, 5 Vampire, 6 Vampire · **17** |
| 20 | Duke Vampire | Day | 5 Zombie, 5 Vampire, 5 Goblin, 1 DukeVampire · **16** |
| 21 | Fogbound | Night | 4 Zombie, 4 Goblin, 2 Vampire, 5 Zombie · **15** |
| 22 | Mist March | Night | 5 Zombie, 1 GoblinElite, 5 Goblin, 4 Vampire · **15** |
| 23 | Quiet Night | Night | 4 Zombie, 3 Goblin, 2 Vampire, 4 Goblin · **13** |
| 24 | Blood Fog | Night | 5 Zombie, 1 DukeVampire, 4 Vampire, 6 Goblin · **16** |
| 25 | Webbed Path | NightFog | 4 Zombie, 4 Goblin, 2 Spider, 3 Spider · **13** |
| 26 | Silk and Steel | NightFog | 5 Zombie, 1 GoblinElite, 3 Spider, 4 Vampire · **13** |
| 27 | Lull in the Mist | NightFog | 4 Zombie, 2 Spider, 4 Goblin, 3 Vampire · **13** |
| 28 | Duke's Night | NightFog | 5 Zombie, 3 Spider, 1 DukeVampire, 5 Vampire · **14** |
| 29 | Closing Webs | NightFog | 1 GoblinElite, 5 Goblin, 4 Spider, 5 Vampire · **15** |
| 30 | Queen Spider | NightFog | 5 Zombie, 4 Spider, 3 Vampire, 1 QueenSpider · **13** |
| 31 | Rattling Fog | NightFog | 3 Zombie, 3 Skeleton, 2 Spider, 3 Goblin · **11** |
| 32 | Royal Remnant | NightFog | 2 Goblin, 1 QueenSpider, 3 Skeleton, 3 Vampire · **9** |
| 33 | Duke Returns | NightFog | 2 Zombie, 3 Vampire, 1 DukeVampire, 3 Skeleton, 2 Spider · **11** |
| 34 | Thickening Dark | NightFog | 1 GoblinElite, 3 Skeleton, 2 Vampire, 4 Goblin · **10** |
| 35 | Howl in the Mist | NightFogReceded | 3 Zombie, 2 Goblin, 2 Werewolf, 3 Werewolf · **10** |
| 36 | Pack Pressure | NightFogReceded | 3 Spider, 3 Werewolf, 2 Vampire, 3 Goblin · **11** |
| 37 | Silk and Fang | NightFogReceded | 3 Zombie, 1 QueenSpider, 3 Werewolf, 3 Vampire · **10** |
| 38 | Blood Pack | NightFogReceded | 3 Werewolf, 1 DukeVampire, 2 Spider, 4 Goblin · **10** |
| 39 | Moonlit March | NightFogReceded | 1 GoblinElite, 3 Werewolf, 2 Vampire, 3 Spider · **9** |
| 40 | Throne of Silk | NightFogReceded | 2 Werewolf, 2 Vampire, 2 Spider, 1 QueenSpider, 1 DukeVampire · **8** |
| 41 | First Wrappings | Desert | 5 SmallMummy, 5 SmallMummy, 6 SmallMummy · **16** |
| 42 | Linen March | Desert | 5 SmallMummy, 6 SmallMummy, 6 SmallMummy · **17** |
| 43 | Silk and Sand | Desert | 6 SmallMummy, 6 SmallMummy, 7 SmallMummy · **19** |
| 44 | Dust and Fang | Desert | 6 SmallMummy, 7 SmallMummy, 7 SmallMummy · **20** |
| 45 | Tomb Pressure | Desert | 6 SmallMummy, 5 Scorpion, 7 SmallMummy · **18** |
| 46 | Bandage Pack | Desert | 6 SmallMummy, 5 Scorpion, 7 SmallMummy · **18** |
| 47 | Royal Dust | Desert | 7 SmallMummy, 6 Scorpion, 7 SmallMummy · **20** |
| 48 | Blood Linen | Desert | 7 SmallMummy, 7 Scorpion, 7 SmallMummy · **21** |
| 49 | Before the Tomb | Desert | 8 SmallMummy, 7 Scorpion, 8 SmallMummy · **23** |
| 50 | Pharaoh Mummy | Desert | 6 SmallMummy, 5 Scorpion, 1 PharaohMummy · **12** |

Days **21–24** use `weather = "Night"` (moonlit night, full lawn plantable).
Days **25–34** use `weather = "NightFog"` (night + visible forest/east-lawn fog;
easternmost **3** columns unplantable; monsters stay visible — see `WEATHER.md`).
Days **35–40** use `weather = "NightFogReceded"` (same night fog look, but only
easternmost **2** columns blocked — one more plantable column).
Days **41–50** use `weather = "Desert"` (sand lawn, no fog, pyramids instead of
the dark forest; full lawn plantable).
Fog days keep moderate totals and alternate easier/harder pacing.

Day 50 (Pharaoh Mummy) is the final numbered encounter. Clearing it keeps
current/highest day at 50; Continue returns to Preparation on Day 50.
Saved days above the current registry limit are clamped on load.

**Hidden Day** (after clearing Day 40, before Day 41 preparation): not a numbered
level (`Levels.getHidden()`). Clearing Day 40 switches the lawn
to this day's night (`weather = "Night"`, no fog, no graves) instead of Day 41's
desert. Continue returns to preparation. The player presses Start Day to run it.
Leaving and rejoining while it is still pending (`hiddenDayPending`) stays in
that preparation. Spawns: **35** Goblin, **4**
Goblin Elite (spaced through the day; more than one elite can be alive), then
**Goblin King** as the big-wave finale. Goblins and Goblin Elites spawn with
**+20%** max HP, attack speed, and movement speed (`HIDDEN_DAY_GOBLIN_STAT_BONUS`);
Goblin King does not. Kill brains (`ProgressConfig.HIDDEN_DAY_KILL_BRAINS`):
Goblin 1, Goblin Elite 10, Goblin King 25 — **100** if every one dies. Brains are
granted once when the day ends, on the same reward screen for a clear or a loss.
A loss refills hearts and restores the Day 40 victory lawn and Start Day XP
snapshot. A clear commits the live lawn and XP. An unfinished Hidden Day restarts from Preparation on rejoin; kill
brains are paid only at finish and are not saved mid-run. Either way Continue
goes to Day 41 preparation. Goblin King's
intro plays when this day starts, not when the player reaches Day 40.

Milestone 10 adds roster variety through **one new monster at a time**, not a
bundle of types in a single level.

Introduction cadence:

- **Every 5 levels:** use a non-boss introduction cadence (Level 5 =
  `Goblin`; Level 15 = `Vampire`; Level 25 = `Spider`; Level 35 = `Werewolf`).
  **Exception:** Level 31 also introduces `Skeleton` (ranged archer) plus fog **graves**,
  and grants **Brr Brr Patapim** (grave buster) on first reach of that day.
  The first reach of Day 31 also queues a **graves** intro (`MECHANIC_INTRO_SCHEDULE`)
  explaining Grave Buster and Cappuccino's Piercing Brew (Legendary).
  **Exception:** Level 41 introduces `SmallMummy` at the start of the 41–50 band.
  **Exception:** Level 45 introduces `Scorpion` (matches the 5-level cadence).
  Days **41–50** authored waves are desert-only: **SmallMummy** from 41,
  **Scorpion** from 45, **PharaohMummy** on 50. **No graves** on desert days.
- **Every 10 levels:** use a boss finale cadence (Level 10 =
  `GoblinElite`; Level 20 = `DukeVampire`; Level 30 = `QueenSpider`; Level 40
  dual-boss wave `QueenSpider` + `DukeVampire`; Level 50 = `PharaohMummy`).
  **Goblin King** is not on Day 40. He is the finale of the **Hidden Day**
  made available after Day 40 is cleared; the player starts it manually (see above).
- The first time a player **reaches** an intro day (or skips ahead via Day
  Select), `LevelService` queues **MonsterIntroPopup**s for every
  `MONSTER_INTRO_SCHEDULE` entry with `day` ≤ current that has not been
  shown — Goblin from Day 5, then bosses / Skeleton / desert units as
  listed in `ProgressConfig`. Same idea as Brainrot intros, persisted on
  `introducedMonsters`. **Zombie** has no intro (Day 1 already uses them).
  Girafa / Patapim use `BRAINROT_INTRO_SCHEDULE` on reach (`introducedBrainrots`).
  Graves use `MECHANIC_INTRO_SCHEDULE` on Day 31 (`introducedMechanics`).
- Levels between introductions mix only monsters the player has already seen,
  ramping count/pacing slowly — sometimes the same difficulty as the prior level.
  Returning **non-boss** species also **age**: HP +30% per 10 days since that
  unit’s intro (`Monsters.scaledForDay`). Day 40 Zombies are 2.2× their Day 1
  HP; damage and speed are unchanged. **Bosses do not scale.**
  Every monster’s **level** is the current campaign day (intro day is the
  starting level: Zombie Lv. 1, Goblin Elite Lv. 10, Queen Spider Lv. 30).
  A Day 11 Zombie is Lv. 11 with the aging HP above.
- Once a boss has been introduced, it can also **recur as a mixed-in miniboss**
  in later levels — placed in the **beginning or middle** of the day, not as
  the big-wave closer. Only decade boss days (10 / 20 / 30 / 40 / …) keep the boss
  as the finale. Regular days that mix in `GoblinElite` / `DukeVampire` /
  `QueenSpider` use a grunt big wave after the elite spike (e.g. Day 13 Elite mid
  → Zombie flag; Day 32 Queen mid → Vampire flag; Day 38 Duke mid → Goblin flag).

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
| `COUNTDOWN_TIME`        | 4     | Start Day overlay: 3, 2, 1, 0 then Active |
| `STARTING_PLAYER_HEALTH`| 5     | Hearts at day start (one lost per breach) |
| `BIG_WAVE_WARNING_TIME` | 5     | Lead time for the "huge wave!" banner      |
| `DEFAULT_SPAWN_INTERVAL`| 1.8   | Fallback gap between monsters in a group   |
| `DEFAULT_GROUP_DELAY`   | 7     | Fallback gap between groups                |

Milestone 14 balance pass: **`docs/BALANCE.md`**. Per-level spawn data lives in
`Shared.Levels`.

---

## Responsibilities (Milestone 8) ✅

`LevelService` owns:

- Preparation phase; Start Day → Countdown (3…0 overlay) → Active (forest march = setup).
- Handling the `StartLevel` request (validated server-side).
- Playing the current level's `groups` in order: driving `EnemyService` to spawn
  (it decides *what* and *when*; `EnemyService` handles *how* monsters
  move/fight), and announcing the big wave.
- Tracking progress and detecting **Victory** (all groups spawned **and** no
  living monsters) vs. **Defeat** (a monster reaches the house). Graves stop
  producing when spawn groups finish so the lawn can clear.
- On **Victory**: clear monsters / projectiles / ground coins; **keep planted
  Brainrots** (current HP); convert leftover **pocket** coins to brains
  (`100` coins → `1` brain, uncapped); set coin purse via `applyDayPurse`
  (Day 1 → 125, later days → 0); then unlock/advance to the next level.
  Phase stays **Victory** until **Continue** (`ContinueVictory` → Preparation).
- On **Defeat**: convert leftover pocket coins the same way; clear mid-day
  Brainrots / monsters / ground coins; **keep**
  `currentLevel` on the failed day; **restore** the last victory checkpoint lawn
  (`SaveService.restoreCommittedLawn` — do not wipe the checkpoint); **roll back
  Brainrot XP** to the Start Day snapshot; hearts
  refill; purse via `applyDayPurse`. Phase stays **`Defeat`** until the player
  presses **Rewind Day N** (`RewindDay` → `Preparation` with `REWIND_COINS`
  200). Then **Start Day** as
  usual. Passive and ability coin drops are blocked outside `Active`.
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
  day select). Full refill on **defeat** (and Reset Progress). Defeat keeps the
  failed day; Rewind returns to Preparation on that day.
- **Coins** — Day 1 → `STARTING_COINS` (125); later days → **0** after each day
  ends (`CoinService.applyDayPurse`). **Rewind** → `REWIND_COINS` (200). Not DataStore-persisted.
- Planted Brainrots are **persisted as a victory checkpoint** (id, tile, HP) and
  restored on rejoin **and on defeat** (retry the same day with the prior clear's
  lawn). Day Select clears the lawn (and the committed checkpoint). Mid-day
  plants on an unfinished day are **not** saved.
- Monsters, projectiles, and level timers are never persisted.
- If a player leaves mid-day or before Start Day: save progression + committed
  lawn only; **Brainrot XP from the unfinished day is not kept** (same snapshot
  as defeat); clear combat runtimes. The unfinished day resets to Preparation.
- On rejoin: restore day + hearts + brains/unlocks + committed plants; coins via
  day purse; press Start Day.

## Retention event hooks (M20)

Entering Active begins a transient attempt marker in RetentionService. Each
actual house breach marks that attempt; a numbered-day victory with no breach
qualifies for Perfect Defense. Initial hearts need not be full. Defeat, Hidden
Day results and rejoin clear the marker. Hidden Day is not a numbered clear.
Completed achievement progress survives defeat; Brainrot XP retains its existing
rollback rules. These hooks never advance days or change combat/rewards/purses.
See `RETENTION.md` for permanent reward and catch-up rules.
