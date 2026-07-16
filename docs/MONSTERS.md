# BVM Monsters

Monsters are the enemies that cross the battlefield. All monsters derive from
one base implementation; special types and bosses are **data entries** plus
optional ability handlers — avoid duplicated AI (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Registry

Definitions live in `ReplicatedStorage.Shared.Monsters` (the registry).

API:

```lua
local Monsters = require(ReplicatedStorage.Shared.Monsters)
Monsters.get(id)     -- MonsterDefinition?  (nil if unknown)
Monsters.exists(id)  -- boolean
Monsters.getAll()    -- { [id]: MonsterDefinition }  (do not mutate)
```

---

## Definition schema

From `Shared.Types.MonsterDefinition`:

| Field             | Type                   | Meaning                                              |
| ----------------- | ---------------------- | ---------------------------------------------------- |
| `id`              | string                 | Unique key                                           |
| `name`            | string                 | Display name                                         |
| `health`          | number                 | Starting HP                                          |
| `secondsPerGrid`  | number                 | Seconds to move one tile toward the house (higher = slower) |
| `damage`          | number                 | Damage per attack (0 when abilities handle damage)   |
| `attackInterval`  | number                 | Seconds between attacks while chewing a tile         |
| `isBoss`          | boolean?               | Boss flag (larger model, authored into levels)       |
| `abilities`       | `{ string }?`          | Ability handler ids (`EnemyService/Abilities`)       |
| `abilityParams`   | `{ [string]: number }?`| Per-ability tuning                                   |
| `color`           | Color3?                | Placeholder / fallback tint                          |
| `modelId`         | string?                | Child name under `Assets.Monsters` (defaults to `id`) |
| `modelOrientationDegrees` | Vector3?         | Local Euler after facing house (−X)                  |

Movement is **grid-based**: monsters spawn just east of the lawn and walk
toward the house (−X), one tile per `secondsPerGrid` seconds.

---

## Models ✅ (Milestone 16 pipeline)

Placed visuals come from **Toolbox / Studio Models** under
`ReplicatedStorage.Assets.Monsters`. `MonsterModel.create` resolves
`definition.modelId or definition.id`, clones + scales to
`MonsterConfig.FOOTPRINT_RATIO` (bosses ×1.15), faces
`MonsterConfig.MODEL_FACE_DIRECTION` (−X toward the house), and tags identity.
Shared helpers: `Shared.Utilities.ModelUtil`.

If a template is missing, the server logs once and uses the colored Part
placeholder so gameplay still works. Movement uses `snapFeetToTileTop` so
multi-part models keep their facing while walking.

### Studio: insert from Toolbox

After Rojo connects, place Models under `ReplicatedStorage.Assets.Monsters`
(`$ignoreUnknownInstances`). Name children to match registry `id` (or set
`modelId`). Campaign-critical first:

| Registry `id` | Suggested Assets child |
| ------------- | ---------------------- |
| `Zombie` | `Zombie` |
| `Goblin` | `Goblin` |
| `Orc` | `Orc` |

Also insert any other types you spawn in `Shared.Levels`. Set `PrimaryPart`,
strip Tools/Scripts, and use `modelOrientationDegrees` if the mesh needs a
Tung-style upright fix.

M16 **Complete When** is met once campaign monsters in authored levels use real
models (at least Zombie, Goblin, Orc).

---

## Roster ✅ (Milestone 6)

| Name | Health | Sec/grid | Damage | Atk interval | Boss | Ability |
| ---- | ------ | -------- | ------ | ------------ | ---- | ------- |
| Zombie | 180 | 5 | 85 | 1.6s | | — |
| Vampire | 900 | 2.8 | 70 | 1.1s | | — |
| Werewolf | 1400 | 3.2 | 130 | 1.1s | | — |
| Skeleton | 950 | 4.5 | 95 | 1.5s | | — |
| Goblin | 150 | 3.4 | 75 | 1.1s | | — |
| Orc | 12000 | 7.5 | 8000 | 3.5s | Y | One-shot brainrot (club) |
| Spider | 900 | 3.2 | 90 | 1.4s | | Jump over first brainrot |
| Necromancer | 9000 | 6 | 0 | 5s | Y | Summon zombie/skeleton; lane change (passive stub) |
| Goblin King | 13000 | 6.5 | 140 | 1.5s | Y | +90 HP / 8s; speed buff (stub) |
| Queen Spider | 13000 | 7 | 140 | 1.5s | Y | Stun + poison brainrot on attack ✅ |
| Duke Vampire | 13000 | 5.5 | 140 | 1.5s | Y | Self-freeze heal / terrify (stubs — M10) |

Milestone 14 tuning rationale: **`docs/BALANCE.md`**.

---

## Service ownership

- **`EnemyService`** (server) ✅ M6 — spawning, grid movement, per-instance state,
  death. One `MonsterBehavior` tick pipeline; abilities in `EnemyService/Abilities/`.
  Driven by `LevelService` in M8. Public: `spawn`, `clearPlot`.
  `MonsterConfig.DEV_SPAWN` is disabled while `LevelService` drives campaign
  spawns (set `ENABLED = true` in config for isolated monster testing).
- **`CombatService`** (server) ✅ M7 — routes Brainrot damage to monsters and
  monster damage to Brainrots; projectiles, status effects, target acquisition.
  See `COMBAT.md`.
- **`LevelService`** (server) ✅ M8 — campaign loop: preparation, countdown,
  spawn groups, big-wave warning, victory/defeat, rewards, progression.
  See `LEVELS.md`.

Spawned monsters are tagged `Monster` (`Shared.Constants.TAGS.Monster`) with
`InstanceId`, `MonsterId`, `Row`, `Column`, `Health`, `MaxHealth` attributes.

Monsters and their positions are **never saved** (see `SAVE_SYSTEM.md`).

---

## Behavior architecture ✅ (Milestone 6)

```
EnemyService.spawn
       │
       ▼
MonsterBehavior (movement + attack tick)
       │
       ├──► Abilities/<AbilityId>  (jump, one-shot, summon, …)
       ├──► CombatService.damageBrainrot  (chewing tiles)
       └──► MonsterFeedback (attack pulse)
```

- Monsters spawn at column `COLUMNS + 0.5` on a chosen grid row.
- Movement decreases `column` toward the house; **Freeze** / **Stun** pause movement.
- When the tile **immediately west** holds a Brainrot, the monster walks toward it
  and stops at its natural position once **close enough** (`MELEE_CLOSE_REACH`) —
  no snap or teleport. It attacks on `attackInterval` and only advances once the
  Brainrot is destroyed. Brainrot melee range uses the same tile-based check so
  both sides can hit while the monster is in the east-adjacent stand tile.
- Reaching column `≤ 0.5` breaches the house (defeat handled in M8).
- Brainrots damage monsters through `CombatService.damageMonster` (M5 abilities work today).

Boss skill stubs (Queen Spider, Duke Vampire, Goblin King speed buff) are
registered and will be completed in Milestones 7 and 10.

---

## Campaign rollout ✅ (Milestone 10)

The roster is introduced **one monster at a time** through campaign levels:

- Levels 1–4: same `Zombie` profile, with gradual count/pacing changes only.
- **Level 5:** first new non-boss — `Goblin` (faster grunt, same HP tier as Zombie).
- Levels 6–9: mix `Zombie` + `Goblin` only; difficulty ramps slowly (Level 8 is a
  plateau at roughly the same pressure as Level 7).
- **Level 10:** first boss — `Orc` (heavy melee counterpart to the Goblin line).

Future cadence when levels are authored: **one** new non-boss every 5 levels
(e.g. Level 15), **one** boss every 10 levels (e.g. Level 20). Further
archetypes (Shield, Flying, Carrier, …) follow the same pattern: registry data
plus ability handlers, never duplicated base AI.
