# BVM Balance (Milestone 14)

Gameplay tuning lives in **Config modules** and **data registries** — never
hardcoded in services (`.cursorrules`). This doc explains the design targets;
numbers are authoritative in code.

Status: ✅ Milestone 14

---

## Design targets

| Phase | Days | Goal |
| ----- | ------ | ---- |
| Opening | 1–4 | Learn plant → earn → defend; **Zombie** only; Day 1 empty board, then carry-over |
| Campaign | 5–9 | **Zombie** + **Goblin** mix; economy opens mid-tier units |
| Boss intro | 10 | **Goblin Elite** big wave; row clear + sustained DPS, not one bomb |

Difficulty never uses duplicate stat tiers of the same enemy. It ramps through
**spawn counts**, **pacing** (`startDelay` / `spawnInterval`), and **monster
species** (Zombie → Goblin → Goblin Elite, …).

**House hearts:** 5 (one lost per breach). **Match coins:** Day 1 opens with
`STARTING_COINS` (125); after later days end the purse resets to **0** (earn
in-match via producers / passive). **Planted Brainrots** carry across
**victories** and **rejoin** (DataStore); the lawn is wiped on defeat, day
select, and reset progress. Brainrots only act while the day is **Active**.
Campaign spawn counts assume that growing board — see `Shared.Levels` /
`LEVELS.md`.

---

## Economy (`EconomyConfig` + Ballerina registry)

| Knob | Value | Rationale |
| ---- | ----- | --------- |
| `STARTING_COINS` | 125 | Day 1 purse only (Ballerina 50 + Tung Tung 75) |
| `PASSIVE_DROP_INTERVAL` | 25s | Backup income cadence during Active levels |
| `PASSIVE_DROP_AMOUNT` | 25 | Matches producer coin size |
| Ballerina `coinGeneration` | 25 / 16s | Primary mid-level income when planted |

---

## Brainrot baseline (`Shared.Brainrots`)

Hit-based **defender** HP: `maxHealth / health` = HP lost per monster chew hit.

| Unit | Cost | Hits | DPS role |
| ---- | ---- | ---- | -------- |
| Ballerina | 50 | 5 | Economy |
| Chimpanzini | 75 | 25 | Wall (~40s vs one Zombie) |
| Tung Tung | 75 | 10 | Melee (45 dmg / 1.35s; ~4 hits vs 180 HP Zombie) |
| Cappuccino | 100 | 5 | Row sniper (60 dmg / 1.75s; 3 hits vs 180 HP Zombie) |
| Lirili | 150 | 5 | Freeze support (2s; 3.5s interval) |
| Tralalero | 175 | 5 | Bubble projectile (40 dmg / 4.0s; weaker than Cappuccino) + 1.2s trap |
| Bombardino | 375 | 1 | Row nuke (2800); ~4× on Goblin Elite |

---

## Monster profiles (`Shared.Monsters`)

One **`Zombie`** stat line for the whole campaign. Difficulty comes from level
data, not weaker zombie variants:

| Id | Role | HP | Sec/tile | Chew dmg |
| -- | ---- | -- | -------- | -------- |
| `Zombie` | Grunt (L1+) | 180 | 4.0 | 85 |
| `Goblin` | Fast grunt (L5+) | 150 | 3.4 | 75 |
| `GoblinElite` | Boss (L10) | 12000 | 11 | 8000 + one-shot; **laneSpan 3** (hit from 3 rows) |

---

## Day pacing (`Shared.Levels` + `LevelConfig`)

- First spawn group uses a short delay; **≥20s** plant time comes from the
  forest march (`SPAWN_COLUMN_OFFSET` × `secondsPerGrid`).
- Adjacent levels change **counts/pacing/species** — never hidden HP scaling.
- Big-wave groups use `isBigWave`; warning lead = `BIG_WAVE_WARNING_TIME` (5s).
- Level 10 Goblin Elite wave: `startDelay` 18s before the boss spawns.
- **Carry-over retune:** Day 1 total **5** zombies (empty board). Later days
  scale ~8 → 18 enemies so a kept defense still feels challenged.

---

## Where to tune

| What | Where |
| ---- | ----- |
| Unit costs/stats | `Shared.Brainrots`, `Shared.Monsters` |
| Wave content | `Shared.Levels` |
| Coins / drops | `EconomyConfig` |
| Level UX pacing | `LevelConfig` |
| Combat globals | `CombatConfig`, `BrainrotConfig`, `MonsterConfig` |
