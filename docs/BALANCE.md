# BVM Balance (Milestone 14)

Gameplay tuning lives in **Config modules** and **data registries** — never
hardcoded in services (`.cursorrules`). This doc explains the design targets;
numbers are authoritative in code.

Status: ✅ Milestone 14

---

## Design targets

| Phase | Levels | Goal |
| ----- | ------ | ---- |
| Opening | 1–4 | Learn plant → earn → defend; **Zombie** only, gentle counts/pacing |
| Campaign | 5–9 | **Zombie** + **Goblin** mix; economy opens mid-tier units |
| Boss intro | 10 | **Orc** big wave; row clear + sustained DPS, not one bomb |

Difficulty never uses duplicate stat tiers of the same enemy. It ramps through
**spawn counts**, **pacing** (`startDelay` / `spawnInterval`), and **monster
species** (Zombie → Goblin → Orc, …).

**House hearts:** 5 (one lost per breach). **Match coins** reset to
`STARTING_COINS` each level (PvZ-style); income during the level funds the
current attempt only.

---

## Economy (`EconomyConfig` + Ballerina registry)

| Knob | Value | Rationale |
| ---- | ----- | --------- |
| `STARTING_COINS` | 125 | Exactly Ballerina (50) + Tung Tung (75) on level 1 |
| `PASSIVE_DROP_INTERVAL` | 25s | Passive income cadence during Active levels |
| `PASSIVE_DROP_AMOUNT` | 25 | Matches producer coin size |
| Ballerina `coinGeneration` | 25 / 11s | Primary mid-level income when planted |

---

## Brainrot baseline (`Shared.Brainrots`)

Hit-based **defender** HP: `maxHealth / health` = HP lost per monster chew hit.

| Unit | Cost | Hits | DPS role |
| ---- | ---- | ---- | -------- |
| Ballerina | 50 | 5 | Economy |
| Chimpanzini | 75 | 35 | Wall (~70s vs one Zombie) |
| Tung Tung | 75 | 10 | Melee (45 dmg / 0.95s; 4 hits vs 180 HP Zombie) |
| Cappuccino | 100 | 5 | Row sniper (60 dmg / 1.75s; 3 hits vs 180 HP Zombie) |
| Lirili | 150 | 5 | Freeze support (2s; 3.5s interval) |
| Tralalero | 175 | 5 | Bubble projectile (60 dmg / 1.7s; 3 hits vs Zombie) + 1.2s trap |
| Bombardino | 375 | 1 | Row nuke (2800); ~4× on Orc |

---

## Monster profiles (`Shared.Monsters`)

One **`Zombie`** stat line for the whole campaign. Difficulty comes from level
data, not weaker zombie variants:

| Id | Role | HP | Sec/tile | Chew dmg |
| -- | ---- | -- | -------- | -------- |
| `Zombie` | Grunt (L1+) | 180 | 5.0 | 85 |
| `Goblin` | Fast grunt (L5+) | 150 | 3.4 | 75 |
| `Orc` | Boss (L10) | 12000 | 7.5 | 8000 + one-shot ability |

---

## Level pacing (`Shared.Levels` + `LevelConfig`)

- First spawn group always leaves **≥20s** plant time after countdown.
- Adjacent levels change **counts/pacing/species** — never hidden HP scaling.
- Big-wave groups use `isBigWave`; warning lead = `BIG_WAVE_WARNING_TIME` (5s).
- Level 10 Orc wave: extra `startDelay` before the boss spawns.

---

## Where to tune

| What | Where |
| ---- | ----- |
| Unit costs/stats | `Shared.Brainrots`, `Shared.Monsters` |
| Wave content | `Shared.Levels` |
| Coins / drops | `EconomyConfig` |
| Level UX pacing | `LevelConfig` |
| Combat globals | `CombatConfig`, `BrainrotConfig`, `MonsterConfig` |
