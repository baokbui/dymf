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
| `color`           | Color3?                | Placement visual tint                                |

Movement is **grid-based**: monsters spawn just east of the lawn and walk
toward the house (−X), one tile per `secondsPerGrid` seconds.

---

## Roster ✅ (Milestone 6)

| Name | Health | Sec/grid | Damage | Atk interval | Boss | Ability |
| ---- | ------ | -------- | ------ | ------------ | ---- | ------- |
| TutorialZombie | 150 | 7 | 40 | 2.5s | | — (Level 1 tutorial only) |
| EarlyZombie | 250 | 6 | 55 | 2.2s | | — (Level 2–3 bridge) |
| Zombie | 1000 | 4.7 | 100 | 2s | | — |
| Vampire | 1000 | 2.5 | 75 | 1s | | — |
| Werewolf | 1500 | 3.5 | 150 | 1s | | — |
| Skeleton | 1000 | 4.7 | 100 | 1.5s | | — |
| Goblin | 1000 | 3 | 100 | 1s | | — |
| Orc | 20000 | 8 | 10000 | 4s | Y | One-shot brainrot (club) |
| Spider | 1000 | 3.5 | 100 | 1.5s | | Jump over first brainrot |
| Necromancer | 10000 | 6 | 0 | 5s | Y | Summon zombie/skeleton; lane change (passive stub) |
| Goblin King | 15000 | 6.5 | 150 | 1.5s | Y | +100 HP / 8s; speed buff (stub) |
| Queen Spider | 15000 | 7 | 150 | 1.5s | Y | Stun + poison brainrot on attack ✅ |
| Duke Vampire | 15000 | 5.5 | 150 | 1.5s | Y | Self-freeze heal / terrify (stubs — M10) |

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

## Future additions (Milestone 10+)

Additional archetypes (Shield, Flying, Carrier, …) are added as registry data
plus ability handlers — no AI duplication.
