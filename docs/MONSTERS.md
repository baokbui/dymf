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


| Field                     | Type                    | Meaning                                                             |
| ------------------------- | ----------------------- | ------------------------------------------------------------------- |
| `id`                      | string                  | Unique key                                                          |
| `name`                    | string                  | Display name                                                        |
| `health`                  | number                  | Starting HP                                                         |
| `secondsPerGrid`          | number                  | Seconds to move one tile toward the house (higher = slower)         |
| `damage`                  | number                  | Damage per attack (0 when abilities handle damage)                  |
| `attackInterval`          | number                  | Seconds between attacks while chewing a tile                        |
| `isBoss`                  | boolean?                | Boss flag (larger model, authored into levels)                      |
| `abilities`               | `{ string }?`           | Ability handler ids (`EnemyService/Abilities`)                      |
| `abilityParams`           | `{ [string]: number }?` | Per-ability tuning                                                  |
| `color`                   | Color3?                 | Placeholder / fallback tint                                         |
| `modelId`                 | string?                 | Child name under `Assets.Monsters` (defaults to `id`)               |
| `modelOrientationDegrees` | Vector3?                | Local Euler after facing house (−X)                                 |
| `walkAnimationId`         | string?                 | Walk loop (`rbxassetid://…`); falls back to config                  |
| `attackAnimationId`       | string?                 | Melee swing while chewing; falls back to config                     |
| `laneSpan`                | number?                 | Rows this unit occupies for targeting (default 1; Goblin Elite = 2) |
| `auraColor`               | Color3?                 | Persistent tinted particle + glow (`MonsterFeedback.applyAura`); omit for none |


Movement is **grid-based**: monsters spawn deep in the east dark forest
(`GridConfig.COLUMNS + MonsterConfig.SPAWN_COLUMN_OFFSET`) and walk toward
the house (−X), one tile per `secondsPerGrid` seconds. The march from forest
to lawn is the day's plant/setup window.

**Multi-lane bosses** (`laneSpan` > 1): the model scales to cover ~`laneSpan `tiles across Z, and Brainrots on any row in that span can target them (`GridUtil.occupiesLaneRow`). The reverse also holds — a multi-lane unit's melee attack hits every Brainrot standing on its current tile across **all** occupied rows, not just its anchor row (`MonsterBehavior.brainrotsAtColumn`), so Goblin Elite's one-shot club can down Brainrots in either of its two lanes in a single swing. The spawn row is a random **anchor** (lowest row occupied) chosen so the full span stays on the lawn — e.g. span 2 on a 5-row grid picks anchor 1–4 (4 options, covering rows 1–2 up to 4–5), vs. a span-3 unit which only has 3 valid centered positions. Visual placement centers the model on the midpoint of its span (`GridUtil.laneCenterRow`).

---

## Models ✅ (Milestone 16 pipeline)

Placed visuals come from **Toolbox / Studio Models** under
`ReplicatedStorage.Assets.Monsters`. `MonsterModel.create` resolves
`definition.modelId or definition.id`, clones + scales to fit
`MonsterConfig` height/footprint, faces `MODEL_FACE_DIRECTION` (−X toward the
house), and tags identity. Shared helpers: `Shared.Utilities.ModelUtil`.

On `EnemyService.start`, `ModelUtil.sanitizeAllMonsterAssets` strips Scripts,
LocalScripts, ModuleScripts, Sounds, and Tools from every template **in-place**
(keeps welded club MeshParts, Motor6Ds, and Animation children). The Humanoid
is kept — Shirt/Pants and layered clothing only render on a rig that still has
one — but neutralized (`ModelUtil` `neutralizeHumanoid`: no floating name/
health UI, `WalkSpeed`/`JumpPower` zeroed, `PlatformStand` on) so it can't
fight our own grid-driven movement or draw Roblox's built-in nameplate.

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
| `Zombie`      | `Zombie`               |
| `Goblin`      | `Goblin`               |
| `GoblinElite` | `GoblinElite`          |
| `Vampire`     | `Vampire`              |
| `DukeVampire` | `DukeVampire`          |


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


| Name         | Health | Sec/grid | Damage | Atk interval | Boss | Ability                                                    |
| ------------ | ------ | -------- | ------ | ------------ | ---- | ---------------------------------------------------------- |
| Zombie       | 250    | 3.5      | 100    | 1.5s         |      | —                                                          |
| Vampire      | 900    | 2.5      | 70     | 1.1s         |      | —                                                          |
| Werewolf     | 1400   | 2.9      | 130    | 1.1s         |      | —                                                          |
| Skeleton     | 950    | 4.0      | 95     | 1.5s         |      | —                                                          |
| Goblin       | 350    | 2.7      | 110    | 1.0s         |      | —                                                          |
| Goblin Elite | 6000   | 9.2      | 8000   | 3.5s         | Y    | One-shot club, cleaves both occupied lanes; **laneSpan 2** |
| Spider       | 900    | 2.9      | 90     | 1.4s         |      | Jump over first brainrot                                   |
| Necromancer  | 9000   | 5.5      | 0      | 5s           | Y    | Summon zombie/skeleton; lane change (passive stub)         |
| Goblin King  | 13000  | 6.0      | 140    | 1.5s         | Y    | +90 HP / 8s; speed buff (stub)                             |
| Queen Spider | 13000  | 6.3      | 140    | 1.5s         | Y    | Stun + poison brainrot on attack ✅                         |
| Duke Vampire | 10000  | 6.0      | 100    | 1.1s         | Y    | Regular chew (Vampire-paced, a bit stronger); Terrify (row ±1 Weaken+Stun, no dmg, 10s CD); once-only last-stand invuln+heal at ≤20% HP |


Milestone 14 tuning rationale: `docs/BALANCE.md`.

---

## Service ownership

- `EnemyService` (server) ✅ M6 — spawning, grid movement, per-instance state,
death. One `MonsterBehavior` tick pipeline; abilities in `EnemyService/Abilities/`.
On death, `MonsterDeath` tips the model (3 random styles), lingers 2s, fades,
then destroys. Driven by `LevelService` in M8. Public: `spawn`, `clearPlot`.
`MonsterConfig.DEV_SPAWN` is disabled while `LevelService` drives campaign
spawns (set `ENABLED = true` in config for isolated monster testing).
- `CombatService` (server) ✅ M7 — routes Brainrot damage to monsters and
monster damage to Brainrots; projectiles, status effects, target acquisition.
See `COMBAT.md`.
- `LevelService` (server) ✅ M8 — campaign loop: preparation → Active,
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
monster walks **onto that tile** and chews at a **standoff** east of the plant
center (`MonsterConfig.MELEE_CLOSE_REACH`) so models don't overlap. It attacks
on `attackInterval` and only advances once the Brainrot is destroyed. It never
walks west of the standoff while chewing (so a melee bat one tile behind still
reaches the monster).
- Reaching column `≤ 0.5` breaches the house (defeat handled in M8).
- Brainrots damage monsters through `CombatService.damageMonster` (M5 abilities work today).
- On death, `MonsterDeath` freezes the Motor6D pose, tips (forward / side / back),
lingers, fades — so authored animated models do not glitch upright.

Boss skill stubs (Goblin King speed buff) are registered and will be completed
in a later milestone. Duke Vampire's two skills are fully implemented:

- **`DukeVampireFreeze`** (last stand) — a small `onTick` state machine that
  does nothing until his HP first drops to/below `lastStandTriggerPercent`
  (20%). It then triggers exactly **once** (`state.lastStandUsed` guard) and
  runs two phases, both covered by a single `setInvulnerable` call
  (`MonsterRuntime.invulnerableUntil`, checked in
  `EnemyService.damageMonster` — every monster damage path, including DoT,
  routes through it) sized to the full sequence so Brainrots can't finish him
  off mid-animation:
  - **Falling** (`lastStandFallDuration`, 1.4s) — `beginFall` reuses the
    regular death tip-over pose (`MonsterDeath.playDowned`) but leaves the
    rig intact (no `freezeCorpse` / fade), and `MonsterBehavior.tick` skips
    movement/attack/transform-sync entirely while `runtime.downedUntil` is in
    the future so the tween isn't fought every frame.
  - **Rising** (`lastStandRiseDuration`, 0.7s) — `beginRise` tweens back to
    the pre-fall pivot (`MonsterDeath.riseUp`) while queuing enough heal via
    the shared `pendingHeal` mechanism (`MonsterBehavior.applyPendingHeal`,
    also used by Goblin King's regen) to reach `lastStandHealPercent` (50%)
    of max HP by the time he's back on his feet.
- **`DukeVampireTerrify`** — deals **no damage**. On a `terrifyCooldown` timer
  (10s), it afflicts the Brainrot directly in front of him plus the ones in
  the lane above/below (his row ± 1, independent of `laneSpan` which stays 1)
  with a `"Weaken"` status (`Types.StatusEffectKind` — scales the Brainrot's
  own outgoing damage down by `terrifyDamageReduction`%, implemented as a
  non-mutating `__index`-fallback override of `damage` on the ability
  context's `definition` in `BrainrotBehavior.effectiveDefinition`, so every
  existing Brainrot ability respects it for free) plus a `"Stun"` (freezes its
  attacks) for `terrifyFreezeDuration` (2s).
- His **regular chew** (`damage` / `attackInterval` on the definition, no
  ability) matches a Vampire's pace (1.1s) with a bit more bite (100 vs. 70).

He also carries a persistent dark `auraColor` (`MonsterFeedback.applyAura`) —
a data-driven, per-definition dual-layer particle (tight wisps + a larger
slow-drifting haze) + bright `PointLight` glow any boss can opt into.

---

## Campaign rollout ✅ (Milestone 10)

The roster is introduced **one monster at a time** through campaign levels
(spawn counts assume **lawn carry-over** after victory — see `LEVELS.md`):

- Levels 1–4: same `Zombie` profile, with rising counts/pacing (Day 1 empty board).
- **Level 5:** first new non-boss — `Goblin` (faster grunt, same HP tier as Zombie).
- Levels 6–9: mix `Zombie` + `Goblin` only; difficulty ramps for a growing defense.
- **Level 10:** first boss — `GoblinElite` / Goblin Elite (heavy melee counterpart to the Goblin line).
- Levels 11–12: still `Zombie` + `Goblin` only — counts/pacing keep ramping to
  recover from the Level 10 boss dip before Goblin Elite starts recurring.
- **Levels 13–14, 17–19:** `GoblinElite` recurs as a mixed-in miniboss (not
  always the big-wave finale) alongside the existing roster — a recognizable
  recurring threat, not a one-off boss fight.
- **Level 15:** next new non-boss — `Vampire` (fast, high-HP grunt), introduced
  gently (low count, generous `spawnInterval`) the same way Goblin was at
  Level 5.
- Levels 16–19: `Vampire` count/pacing ramps steadily alongside `Zombie` /
  `Goblin` / recurring `GoblinElite`.
- **Level 20:** next boss — `DukeVampire` / Duke Vampire, tuned as the softest
  of the Milestone-10 boss roster (below Goblin King / Queen Spider) since
  it's the very next boss after Goblin Elite.

Future cadence when further levels are authored: **one** new non-boss every 5
levels (e.g. Level 25), **one** boss every 10 levels (e.g. Level 30). Further
archetypes (Shield, Flying, Carrier, …) follow the same pattern: registry data
plus ability handlers, never duplicated base AI.