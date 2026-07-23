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
| `walkAnimationId` | string?                | Walk loop (`rbxassetid://…`); falls back to config   |
| `attackAnimationId` | string?              | Melee swing while chewing; falls back to config      |
| `laneSpan`        | number?                | Rows this unit occupies for targeting (default 1; Goblin Elite = 3) |

Movement is **grid-based**: monsters spawn deep in the east dark forest
(`GridConfig.COLUMNS + MonsterConfig.SPAWN_COLUMN_OFFSET`) and walk toward
the house (−X), one tile per `secondsPerGrid` seconds. The march from forest
to lawn is the day's plant/setup window.

**Multi-lane bosses** (`laneSpan` > 1): the model scales to cover ~`laneSpan`
tiles across Z, and Brainrots on adjacent rows can target them (half-span
tolerance around the spawn row). Spawns pick a center row so the span stays
on the lawn (e.g. span 3 → rows 2–4 on a 5-row grid).

---

## Models ✅ (Milestone 16 pipeline)

Placed visuals come from **Toolbox / Studio Models** under
`ReplicatedStorage.Assets.Monsters`. `MonsterModel.create` resolves
`definition.modelId or definition.id`, clones + scales to fit
`MonsterConfig` height/footprint, faces `MODEL_FACE_DIRECTION` (−X toward the
house), and tags identity. Shared helpers: `Shared.Utilities.ModelUtil`.

On `EnemyService.start`, `ModelUtil.sanitizeAllMonsterAssets` strips Scripts,
LocalScripts, ModuleScripts, Sounds, Humanoids, and Tools from every template
**in-place** (keeps welded club MeshParts, Motor6Ds, and Animation children).

Clones use `preserveAnimationRig = true`: only the root part is Anchored so
Motor6D limbs can animate. `MonsterAnimation` binds walk/attack tracks from:

1. `WalkAnimation` / `AttackAnimation` children under the template (if present)
2. `definition.walkAnimationId` / `attackAnimationId` (`""` disables that track)
3. `MonsterConfig.DEFAULT_WALK_ANIMATION_ID` / `DEFAULT_ATTACK_ANIMATION_ID`
   when the definition omits the field (`nil`)

**Goblin** disables walk (`walkAnimationId = ""`) — catalog R15 walk looked
buggy against grid snap — and plays a one-shot club swing (`ToolSlash`) each
chew hit via `MonsterAnimation.playMelee`.

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
| `GoblinElite` | `GoblinElite` |

Also insert any other types you spawn in `Shared.Levels`. Set `PrimaryPart`
(prefer `HumanoidRootPart`). You do **not** need to hand-delete Scripts —
`sanitizeAllMonsterAssets` does that on server start. Optional: parent
`WalkAnimation` / `AttackAnimation` instances under the model to override
catalog IDs. Use `modelOrientationDegrees` if the mesh needs a Tung-style
upright fix.

M16 **Complete When** is met once campaign monsters in authored levels use real
models (at least Zombie, Goblin, Goblin Elite).

---

## Roster ✅ (Milestone 6)

| Name | Health | Sec/grid | Damage | Atk interval | Boss | Ability |
| ---- | ------ | -------- | ------ | ------------ | ---- | ------- |
| Zombie | 250 | 3.0 | 100 | 1.5s | | — |
| Vampire | 900 | 2.2 | 70 | 1.1s | | — |
| Werewolf | 1400 | 2.5 | 130 | 1.1s | | — |
| Skeleton | 950 | 3.5 | 95 | 1.5s | | — |
| Goblin | 200 | 2.3 | 110 | 1.0s | | — |
| Goblin Elite | 14000 | 8 | 8000 | 3.5s | Y | One-shot club; **laneSpan 3** |
| Spider | 900 | 2.5 | 90 | 1.4s | | Jump over first brainrot |
| Necromancer | 9000 | 4.8 | 0 | 5s | Y | Summon zombie/skeleton; lane change (passive stub) |
| Goblin King | 13000 | 5.2 | 140 | 1.5s | Y | +90 HP / 8s; speed buff (stub) |
| Queen Spider | 13000 | 5.5 | 140 | 1.5s | Y | Stun + poison brainrot on attack ✅ |
| Duke Vampire | 13000 | 4.4 | 140 | 1.5s | Y | Self-freeze heal / terrify (stubs — M10) |

Milestone 14 tuning rationale: **`docs/BALANCE.md`**.

---

## Service ownership

- **`EnemyService`** (server) ✅ M6 — spawning, grid movement, per-instance state,
  death. One `MonsterBehavior` tick pipeline; abilities in `EnemyService/Abilities/`.
  On death, `MonsterDeath` tips the model (3 random styles), lingers 2s, fades,
  then destroys. Driven by `LevelService` in M8. Public: `spawn`, `clearPlot`.
  `MonsterConfig.DEV_SPAWN` is disabled while `LevelService` drives campaign
  spawns (set `ENABLED = true` in config for isolated monster testing).
- **`CombatService`** (server) ✅ M7 — routes Brainrot damage to monsters and
  monster damage to Brainrots; projectiles, status effects, target acquisition.
  See `COMBAT.md`.
- **`LevelService`** (server) ✅ M8 — campaign loop: preparation → Active,
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

- Monsters spawn at column `COLUMNS + SPAWN_COLUMN_OFFSET` on a chosen grid row
  (forest march).
- Movement decreases `column` toward the house; **Freeze** / **Stun** pause movement.
- Monsters **phase through each other** on the same row (no blocking — all parts
  `CanCollide = false`). They walk the **lane center** (no lateral Z stagger).
  They only stop for Brainrots (or the house).
- When a tile holds a Brainrot (any type — wall, producer, attacker, …), the
  monster walks **onto that tile** and chews while closing to the plant's column
  center — PvZ-style overlap. It attacks on `attackInterval` and only advances
  once the Brainrot is destroyed. It never walks west of the plant center while
  chewing (so a melee bat one tile behind still reaches the monster).
- Reaching column `≤ 0.5` breaches the house (defeat handled in M8).
- Brainrots damage monsters through `CombatService.damageMonster` (M5 abilities work today).
- On death, `MonsterDeath` freezes the Motor6D pose, tips (forward / side / back),
  lingers, fades — so authored animated models do not glitch upright.

Boss skill stubs (Queen Spider, Duke Vampire, Goblin King speed buff) are
registered and will be completed in Milestones 7 and 10.

---

## Campaign rollout ✅ (Milestone 10)

The roster is introduced **one monster at a time** through campaign levels
(spawn counts assume **lawn carry-over** after victory — see `LEVELS.md`):

- Levels 1–4: same `Zombie` profile, with rising counts/pacing (Day 1 empty board).
- **Level 5:** first new non-boss — `Goblin` (faster grunt, same HP tier as Zombie).
- Levels 6–9: mix `Zombie` + `Goblin` only; difficulty ramps for a growing defense.
- **Level 10:** first boss — `GoblinElite` / Goblin Elite (heavy melee counterpart to the Goblin line).

Future cadence when levels are authored: **one** new non-boss every 5 levels
(e.g. Level 15), **one** boss every 10 levels (e.g. Level 20). Further
archetypes (Shield, Flying, Carrier, …) follow the same pattern: registry data
plus ability handlers, never duplicated base AI.
