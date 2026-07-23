# BVM Balance (Milestone 14+)

Gameplay tuning lives in **Config modules** and **data registries** — never
hardcoded in services (`.cursorrules`). This doc explains the design targets;
numbers are authoritative in code.

Status: ✅ Milestone 14 (retuned after plant cooldowns)

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
| Ballerina `coinGeneration` | 25 / 18s | Primary mid-level income (slower snowball) |

---

## Plant recharge (`BrainrotConfig`)

After planting, that Brainrot id must recharge before another of the same type
can be planted. Lower **cost** → shorter cooldown (linear map):

| Knob | Value |
| ---- | ----- |
| `PLANT_COOLDOWN_MIN` | 7.5s at cost 50 |
| `PLANT_COOLDOWN_MAX` | 42s at cost 375 |
| Override | optional `definition.plantCooldown` |

Resets on **Start Day**. Not saved.

---

## Brainrot baseline (`Shared.Brainrots`)

Hit-based **defender** HP: `maxHealth / health` = HP lost per monster chew hit
(~100 HP per hit on most units).

| Unit | Cost | Hits | Combat role |
| ---- | ---- | ---- | ----------- |
| Ballerina | 50 | 5 | Economy (25 / 18s) |
| Chimpanzini | 75 | 20 | Wall (~30s vs one Zombie) |
| Tung Tung | 75 | 8 | Melee (40 / 1.5s ≈ 27 DPS; ~7 hits vs 250 HP Zombie) |
| Cappuccino | 100 | 5 | Row sniper (50 / 2.0s = 25 DPS; 5 hits vs Zombie) |
| Lirili | 150 | 5 | Freeze support (0.7s / 6.0s; range 2) |
| Tralalero | 175 | 5 | Bubble (55 / 5.0s) + 0.5s trap |
| Bombardino | 375 | 1 | Row nuke (1000) — ~4 zombies, ~7% of Elite |

Intent: Cappuccino is reliable lane DPS; Tung Tung rewards the front line;
Lirili/Tralalero are support; Bombardino is panic clear, not a boss delete.

---

## Monster profiles (`Shared.Monsters`)

Campaign difficulty still ramps via **counts / pacing / species**. Grunt stats
were raised so early boards need real DPS:

| Id | Role | HP | Sec/tile | Chew |
| -- | ---- | -- | -------- | ---- |
| `Zombie` | Grunt (L1+) | 250 | 3.0 | 100 / 1.5s |
| `Goblin` | Fast grunt (L5+) | 200 | 2.3 | 110 / 1.0s |
| `GoblinElite` | Boss (L10) | 14000 | 8 | 8000 + one-shot; **laneSpan 3** |

Forest march setup ≈ `SPAWN_COLUMN_OFFSET` × `secondsPerGrid` (~18s Zombie,
~14s Goblin).

---

## Day pacing (`Shared.Levels` + `LevelConfig`)

- First spawn group uses a short delay; **≥14–18s** plant time comes from the
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
