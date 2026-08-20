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


| Field                     | Type                    | Meaning                                                                        |
| ------------------------- | ----------------------- | ------------------------------------------------------------------------------ |
| `id`                      | string                  | Unique key                                                                     |
| `name`                    | string                  | Display name                                                                   |
| `health`                  | number                  | Starting HP                                                                    |
| `secondsPerGrid`          | number                  | Seconds to move one tile toward the house (higher = slower)                    |
| `damage`                  | number                  | Damage per attack (0 when abilities handle damage)                             |
| `attackInterval`          | number                  | Seconds between attacks while chewing a tile                                   |
| `isBoss`                  | boolean?                | Boss flag (larger model, authored into levels)                                 |
| `abilities`               | `{ string }?`           | Ability handler ids (`EnemyService/Abilities`)                                 |
| `abilityParams`           | `{ [string]: number }?` | Per-ability tuning                                                             |
| `color`                   | Color3?                 | Placeholder / fallback tint                                                    |
| `modelId`                 | string?                 | Child name under `Assets.Monsters` (defaults to `id`)                          |
| `modelOrientationDegrees` | Vector3?                | Local Euler after facing house (−X)                                            |
| `walkAnimationId`         | string?                 | Walk loop (`rbxassetid://…`); falls back to config                             |
| `attackAnimationId`       | string?                 | Melee swing while chewing; falls back to config                                |
| `attackHitDelay`          | number?                 | Seconds after melee anim starts before chew damage (nil/0 = same tick)         |
| `laneSpan`                | number?                 | Rows this unit occupies for targeting (default 1; Goblin Elite = 2)            |
| `deathStyle`              | string?                 | Death pose (`TipOver` default, `SpiderFlat` for Queen Spider)                  |
| `spawnStyle`              | string?                 | Entrance (`RiseFromGround` = buried then tween up; mummies)                    |
| `spawnRiseDuration`       | number?                 | Rise duration; nil = `MonsterConfig.SPAWN_RISE_DURATION`                       |


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

**Zombie** uses authored walk / attack clips (`walkAnimationId` /
`attackAnimationId` on the definition). Tune `attackHitDelay` so chew damage
lands on the impact frame of the swing.

**Goblin** disables walk (`walkAnimationId = ""`) — catalog R15 walk looked
buggy against grid snap — and plays a one-shot club swing (`ToolSlash`) each
chew hit via `MonsterAnimation.playMelee`.

**Spider** Toolbox packs often ship a Script named `Animation` with a child
`Animation` (`rbxassetid`). Those IDs are usually **permission-locked** for
other experiences — do not play them. With `proceduralWalk = true`,
`MonsterAnimation` registers a KeyframeSequence from `AnimSaves` via
`AnimationClipProvider` (local, owned by this place) when present; otherwise
`MonsterProceduralGait` drives the legs. Sanitize still strips the Script.

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
| `Spider`      | `Spider`               |
| `QueenSpider` | `QueenSpider`          |
| `Werewolf`    | `Werewolf` (currently under `Assets.Brainrots`; `ModelUtil` falls back) |

Spider / Queen Spider Toolbox meshes face the wrong way relative to
`MODEL_FACE_DIRECTION` (−X); both set `modelOrientationDegrees`.
Boss spawns refuse a second living copy of the same `monsterId` on a plot
(guards Studio soft-reload double-bootstrap).


Also insert any other types you spawn in `Shared.Levels`. Set `PrimaryPart`
(prefer `HumanoidRootPart`). You do **not** need to hand-delete Scripts —
`sanitizeAllMonsterAssets` strips Scripts / Tools / Sounds / Sparkles / Fire /
Smoke on server start. Optional: parent `WalkAnimation` / `AttackAnimation`
instances under the model to override catalog IDs. Use
`modelOrientationDegrees` if the mesh needs a Tung-style upright fix.

M16 **Complete When** is met once campaign monsters in authored levels use real
models (at least Zombie, Goblin, Goblin Elite).

---

## Roster ✅ (Milestone 6)


| Name         | Health | Sec/grid | Damage | Atk interval | Boss | Ability                                                                                                                                 |
| ------------ | ------ | -------- | ------ | ------------ | ---- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Zombie       | 250    | 3.5      | 100    | 1.5s         |      | —                                                                                                                                       |
| Vampire      | 900    | 2.5      | 70     | 1.1s         |      | —                                                                                                                                       |
| Werewolf     | 1400   | 2.0      | 60     | 1.5s         |      | Lifesteal 5% max HP per chew hit (`WerewolfLifesteal`) ✅                                                                                |
| Skeleton     | 200    | 4.0      | 100     | 1.5s         |      | Bone Arrow — stop 3 tiles east, shoot westbound arrows (`SkeletonArrow` / `rangedTiles`) ✅ |
| Goblin       | 350    | 2.7      | 110    | 1.0s         |      | —                                                                                                                                       |
| Goblin Elite | 6000   | 6.2      | 8000   | 3.5s         | Y    | One-shot club, cleaves both occupied lanes; **laneSpan 2**                                                                              |
| Spider       | 550    | 1.8      | 90     | 1.4s         |      | Jump over first Brainrot (visible arc) ✅                                                                                                |
| Necromancer  | 9000   | 5.5      | 0      | 5s           | Y    | Summon zombie/skeleton; lane change (passive stub)                                                                                      |
| Goblin King  | 13000  | 6.0      | 140    | 1.5s         | Y    | +90 HP / 8s; speed buff (stub)                                                                                                          |
| Queen Spider | 13000  | 6.3      | 140    | 1.5s         | Y    | **laneSpan 3** (random valid 3-lane placement); stun 2s + poison DoT on chew; no jump ✅ |
| Duke Vampire | 8000   | 4.8      | 100    | 1.1s         | Y    | Regular chew (Vampire-paced, a bit stronger); Terrify (row ±1 Weaken+Stun, no dmg, 10s CD); once-only last-stand invuln+heal at ≤20% HP |
| Small Mummy  | 1000   | 2.0      | 150    | 1.5s         |      | Fast linen grunt (Day 41+); `spawnStyle = RiseFromGround` |
| Pharaoh Mummy| 15000  | 5.0      | 200    | 1.0s         | Y    | Rise from ground; summon Small Mummy in all 5 lanes (20s); steal 1 Brainrot from 3 random lanes (15s) ✅ |


Milestone 14 tuning rationale: `docs/BALANCE.md`.

---

## Service ownership

- `EnemyService` (server) ✅ M6 — spawning, grid movement, per-instance state,
death. One `MonsterBehavior` tick pipeline; abilities in `EnemyService/Abilities/`.
On death, `MonsterDeath` plays the unit's `deathStyle` (default: tip-over, 3
random styles), lingers 2s, fades, then destroys. Driven by
`LevelService` in M8. Public: `spawn`, `spawnAt`, `clearPlot`.
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
(forest march). `EnemyService.spawnAt` places a unit on a lawn column (grave emerge).

### Graves (Day 31+)

`GraveService` + `GraveConfig` + optional `LevelDefinition.graves`. At
Start Day, **1–5** graves occupy random **fog** tiles (`occupied`, no Brainrot id —
plants blocked, monsters phase through) and **rise from under the tile**
(`GraveConfig.RISE_DURATION`). While the day is Active **and authored waves
are still running**, each grave repeatedly spawns a **Zombie** or **Skeleton**
at random intervals (`EMERGE_*` first, then `RESPAWN_*`). Units rise from
under the stone (`MONSTER_RISE_DURATION`). The grave **stays** on the tile
(still blocking plants; monsters phase through) until the plot is cleared.
Grave production **stops** when spawn groups finish so victory can fire. Authored model:
`Assets.Graves.Grave` (Model or MeshPart; procedural tombstone fallback). Graves are not saved.
- Movement decreases `column` toward the house; **Freeze** / **Stun** pause movement.
- Monsters **phase through each other** on the same row (no blocking — all parts
`CanCollide = false`). Player characters also **phase through monsters** via
`CollisionUtil` (`BvmPlayers` / `BvmMonsters` collision groups). They walk the
**lane center** (no lateral Z stagger).
- Foot placement uses a **rest-pose** pivot→bottom cache (`footSnapOffset`) so
procedural / animated limbs (esp. Spider crawl) do not rewrite visual minY
every tick and bury the body. `MonsterFeedback.pulseAttack` skips `ScaleTo` on
Motor6D/Bone rigs (ScaleTo was breaking spider visibility).
They only stop for Brainrots (or the house), except **Skeleton** (`rangedTiles`):
it stops `rangedTiles` east of the nearest plant and shoots instead of chewing.
**Spider** is the exception for the *first* Brainrot: instead of chewing (or walking through at ground level),
`SpiderJump` vaults it with a visible parabola (`MonsterBehavior` jump arc —
column lerps west of the plant while `floatY` peaks at `jumpPeakHeight`), then
chews later plants normally. Jump timing/height are data-driven via
`abilityParams` / `MonsterConfig.JUMP_*`.
- When a tile holds a Brainrot (any type — wall, producer, attacker, …), the
monster walks **onto that tile** and chews at a **standoff** east of the plant
center (`MonsterConfig.MELEE_CLOSE_REACH`) so models don't overlap. It attacks
on `attackInterval` and only advances once the Brainrot is destroyed. It never
walks west of the standoff while chewing (so a melee bat one tile behind still
reaches the monster). Exception: `definition.ignoreMonsterChew` (Lirili) —
monsters phase through and never deal chew damage.
- Reaching column `≤ 0.5` breaches the house (defeat handled in M8).
- Brainrots damage monsters through `CombatService.damageMonster` (M5 abilities work today).
- On death, `MonsterDeath` freezes the Motor6D pose, then plays
`deathStyle` (default tip forward / side / back), then lingers and fades —
so authored animated models do not glitch upright.

Boss skill stubs (Goblin King speed buff) are registered and will be completed
in a later milestone. **Werewolf** `WerewolfLifesteal` heals
`lifestealPercent` (5) of max HP on every chew via `pendingHeal`. Duke Vampire's
two skills are fully implemented:

- `DukeVampireFreeze` (last stand) — a small `onTick` state machine that
does nothing until his HP first drops to/below `lastStandTriggerPercent`
(20%). It then triggers exactly **once** (`state.lastStandUsed` guard) and
runs two phases, both covered by a single `setInvulnerable` call
(`MonsterRuntime.invulnerableUntil`, checked in
`EnemyService.damageMonster` — every monster damage path, including DoT,
routes through it) sized to the full sequence so Brainrots can't finish him
off mid-animation:
  - **Falling** (`lastStandFallDuration`, 1.0s — same speed as a regular
  death) — `beginFall` reuses `MonsterDeath.playDowned`, which shares the
  same randomized 3-style tip-over pose picker as a real death
  (`randomTipGoal`) so it falls exactly like any other monster, but leaves
  the rig intact (no `freezeCorpse` / fade). `MonsterBehavior.tick` skips
  movement/attack/transform-sync entirely while `runtime.downedUntil` is in
  the future so the tween isn't fought every frame.
  - **Grounded** (`lastStandGroundDuration`, 3s) — lies motionless on the
  ground; `holdDowned` extends `runtime.downedUntil` without playing a new
  tween (no separate visual, just a hold before rising).
  - **Rising** (`lastStandRiseDuration`, 0.7s) — `beginRise` tweens back to
  the pre-fall pivot (`MonsterDeath.riseUp`) while queuing enough heal via
  the shared `pendingHeal` mechanism (`MonsterBehavior.applyPendingHeal`,
  also used by Goblin King's regen) to reach `lastStandHealPercent` (25%)
  of max HP by the time he's back on his feet.
  Fatal overkill that would skip the ≤20% check between behavior ticks is
  rescued by `DukeVampireFreeze.onWouldDie` (wired from
  `EnemyService.damageMonster`) so a single big hit can't delete him before
  last stand starts.
- `DukeVampireTerrify` — deals **no damage**. On a `terrifyCooldown` timer
(10s), it afflicts the Brainrot directly in front of him, the
`terrifyColumnsBehind` (2) tiles ahead of that one (west, toward the
house), plus the lanes above/below at each of those columns (his row ± 1,
independent of `laneSpan` which stays 1) with a `"Weaken"` status
(`Types.StatusEffectKind` — scales the Brainrot's own outgoing damage down
by `terrifyDamageReduction`%, implemented as a non-mutating
`__index`-fallback override of `damage` on the ability context's
`definition` in `BrainrotBehavior.effectiveDefinition`, so every existing
Brainrot ability respects it for free) plus a `"Stun"` (freezes its attacks)
for `terrifyFreezeDuration` (4s). Visible feedback (no gameplay effect):
a row of red curved comic-book soundwave lines (`CombatVisual` kind
`"Terrify"` → `VfxUtil.playTerrifySoundwave`) fans out from him along the
terrify cone (forward / toward the house — matching his column −
`terrifyColumnsBehind` AoE) whenever he actually hits something, and each
afflicted Brainrot gets three yellow ★ stars orbiting in a dizzy halo over
its head (kind `"Dizzy"` → `VfxUtil.playDizzy`) for the freeze duration.
The scream **never** fires while he's still in the forest, while
last-standing, or when the cone has zero living Brainrots (short retry
poll instead of burning the full cooldown / playing VFX).
- His **regular chew** (`damage` / `attackInterval` on the definition, no
ability) matches a Vampire's pace (1.1s) with a bit more bite (100 vs. 70).

He also carries a persistent dark `auraColor` (`MonsterFeedback.applyAura`) —
a data-driven, per-definition dual-layer particle (tight wisps + a larger
slow-drifting haze) + bright `PointLight` glow any boss can opt into. Duke
Vampire sets `auraScale = 1.6` (default 1) to scale up the particle sizes /
speeds / glow range so his boss "tell" reads clearly at a distance.

Visual feedback for Terrify (`CombatVisual` kind `"Terrify"` / `"Dizzy"` →
`VfxUtil.playTerrifySoundwave` / `playDizzy`) anchors on the model via
`PlotUtil.getModelBodyCenter` (client) / `MonsterFeedback.resolveBody`
(server). Both fall back through a recursive `"Body"` search → `PrimaryPart`
→ `HumanoidRootPart` → any `BasePart`, since authored Toolbox rigs with
`preserveAnimationRig` never get the procedural `"Body"` alias
(`ModelUtil.ensureBodyAlias` is skipped for them) — without that fallback
chain, effects anchored on real (non-placeholder) monster models would
silently never render.

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
- **Levels 21–24:** Night weather (`WEATHER.md`); mix of prior roster
(`Zombie` / `Goblin` / `GoblinElite` / `Vampire` / `DukeVampire`) with
alternating easier/harder pacing.
- **Level 25:** next new non-boss — `Spider` (visible jump over first Brainrot),
gentle intro counts as NightFog begins.
- **Levels 26–29:** Spider mixes with the fog roster; Elite / Duke recur as
early/mid pressure spikes (not the big-wave closer — only decade boss days
end on the boss).
- **Level 30:** next boss — `QueenSpider` / Queen Spider (**laneSpan 3**,
  random valid 3-lane spawn via `randomRowForSpan`; stun 2s + poison DoT on
  chew; does **not** jump) as the NightFog decade finale.
- **Levels 31–34:** still NightFog (3 blocked columns); **Skeleton** intro on
  31 (`rangedTiles` 3, westbound arrows) plus **graves** on random fog tiles
  (`GraveService`); Queen / Duke recur mid-day; counts inch up toward the
  Werewolf band.
- **Level 35:** next new non-boss — `Werewolf` (fast march ~2s/tile; authored
  walk/attack clips; **lifesteal** 5% max HP per chew; template under
  `Assets.Brainrots` until moved). Weather switches to `NightFogReceded`
  (2 blocked columns).
- **Levels 36–39:** Werewolf pack pressure with Queen / Duke / Elite mid spikes.
- **Level 40:** decade closer — `QueenSpider` + `DukeVampire` dual big-wave
  finale under receded fog (Queen flags the wave; Duke spawns immediately after).
- **Levels 41–49:** `Desert`; **SmallMummy** only (counts ramp). Later desert
  species slot in here when authored.
- **Level 50:** `PharaohMummy` big-wave finale (still mummy grunts before the boss).

Further archetypes (Shield, Flying, Carrier, …) follow the same pattern:
registry data plus ability handlers, never duplicated base AI.