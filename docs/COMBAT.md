# BVM Combat

Combat is handled **exclusively** by `CombatService` on the server. Brainrots and
monsters never modify each other's health directly — they send intents through
this service (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Ownership

| System | Role |
| ------ | ---- |
| `CombatService` | Damage, death routing, target acquisition, projectiles, status effects |
| `EnemyService` | Monster runtime state, movement, status fields, death cleanup |
| `BrainrotService` | Brainrot runtime state, status on planted units |
| `CombatController` (client) | Hit/death/explosion VFX, projectile trails (`CombatVisual` + plot watcher) |

---

## Target acquisition ✅ (Milestone 7)

Monsters use **fractional grid columns** (west toward the house = decreasing
column). When a Brainrot attacks a row:

| Mode | API | Behavior |
| ---- | --- | -------- |
| First in row | `attackFirstInRow` / `launchProjectile` | Damages the monster with the **lowest column** in range (closest to the house — PvZ peashooter style). Used by Cappuccino knives and Tralalero bubbles. |
| All in range | `attackInRow` | Damages every monster in range (instant splash) |
| Entire row | `dealEntireRowDamage` | Damages **every** monster on the row (Bombardino line bomb) |
| Entire row status | `applyEntireRowStatus` | Status on **every** monster on the row. Returns how many received it. |
| Column-band status | `applyStatusAroundColumn` | Status on the caster's tile plus N tiles ahead and behind (Lirili freeze = 2). Returns how many monsters received the status. |

Range uses `GridUtil.isColumnInRange` with `BrainrotConfig.FULL_LINE_RANGE` (-1)
for full-row-from-tile attacks. Tile-based `rangeTiles` covers whole cells ahead.
**Melee bat** uses tile-based `rangeTiles` (Tung Tung = 1): hits monsters on the
Brainrot's own tile **or** one tile ahead. Friendly Brainrots do **not** block —
a bat behind Ballerina, Lirili, Chimpanzini, etc. can still hit a monster chewing
that unit. (Legacy fractional `MELEE_BAT_REACH` is unused.) Optional
`attackHitDelay` starts the swing anim first, then re-acquires the target before
damage — if nothing is still in range, the swing misses (cooldown already spent).
**Ranged Rampage** (`rangedUntil`) launches a full-lane `Knife` projectile
instead of the close-range hit.

Monsters still east of the lawn (`column > GridConfig.COLUMNS`, forest march)
are **not** valid targets — Brainrots wait until the monster enters the plot.

**Fog graves** sit on a lawn column and **block** Brainrot damage, projectiles,
and status aimed at monsters **strictly east** of the stone (`fromColumn <
grave < targetColumn`). Combat does not apply HP or status to those monsters
(shurikens stop at the stone). **Piercing Brew** (`pierceCount`) is the
exception: the shot flies through the grave, damages the first monster, and
still hits the one behind. Graves have no combat HP except **Patapim**
smashes (`hitFromPatapim`), which also **shake** the mesh. Other hits do not
shake. **Bombardino** `dealColumnDamage` / entire-row bombs still hit monsters
on and behind the grave tile. Monsters on the grave tile or west of it remain
valid targets for lane shots. Graves do not block westbound Skeleton arrows.

Monsters with `laneSpan` > 1 (e.g. Goblin Elite = 2) occupy rows
`[row, row + laneSpan − 1]` — `row` is the unit's lowest/anchor row, not a
center — and are valid targets from **any** row in that range
(`GridUtil.occupiesLaneRow`). Melee, projectiles, and row splash all use this
rule via `EnemyService` queries. Visual placement centers the model on the
midpoint of its occupied span (`GridUtil.laneCenterRow`) so even spans still
render centered between their lanes instead of snapped to one edge.

The reverse direction also respects the span: when a multi-lane unit attacks,
it hits every Brainrot standing on its current tile across **all** occupied
rows (`MonsterBehavior.brainrotsAtColumn`), not just its anchor row. This is
what lets Goblin Elite's one-shot club (`GoblinEliteClubOneShot`) down
Brainrots in either of its two lanes in the same swing.

---

## Projectiles ✅ (Milestone 7)

`CombatService.launchProjectile` spawns a server-replicated part in
`plot.Projectiles` and moves it along the row. Brainrot shots travel **+X**;
Skeleton arrows use `launchTowardBrainrot` (`columnDirection = −1`).

| Ability | `kind` | On impact |
| ------- | ------ | --------- |
| Cappuccino (`ThrowKnife`) | `Shuriken` — clones `Assets.Projectiles.Shuriken` when present (procedural star fallback); spins about +Y | Damage + `ThrowKnifeHit`. Optional `pierceCount` also damages the next monster east (100%) and flies through graves. Piercing shots carry a gold aura (`PiercingBrew`) so they read as Piercing Brew. |
| Tung Tung (`MeleeBat` during Ranged Rampage) | `Knife` (legacy bolt) | Full-lane damage + `MeleeBat` |
| Skeleton (`SkeletonArrow`) | `Arrow` — clones `Assets.Projectiles.Arrow` (**Model or Part**); spawns from bow `Middle` attachment / `LArm`; flies **−X** toward the house | Brainrot hits (chew-equivalent) |
| Tralalero (`BubbleTrap` / `BubbleBarrage`) | `Bubble` (ForceField ball) | Damage + Freeze/`Bubble` shell + `BubbleTrap`. Barrage fires one per lawn row from the plant’s column. |

Tuning: `CombatConfig` (`SHURIKEN_MODEL_ID`, `SHURIKEN_TARGET_EXTENT`,
`SHURIKEN_MODEL_ORIENTATION_DEGREES`, speed, spin, bubble size) +
`MonsterConfig.BUBBLE_COLOR`. Client trail/glow branches on the `ProjectileKind`
attribute (`VfxUtil`).

### Studio: Cappuccino shuriken model

1. Rojo-sync so `ReplicatedStorage.Assets.Projectiles` exists.
2. Move your shuriken **Model** from Workspace into that folder.
3. Rename it to **`Shuriken`** (or set `CombatConfig.SHURIKEN_MODEL_ID`).
4. Set a `PrimaryPart` if possible; strip Tools/Scripts.
5. If it flies edge-on, tweak `SHURIKEN_MODEL_ORIENTATION_DEGREES` (often
   `Vector3.new(90, 0, 0)` or similar).

---

## Status effects ✅ (Milestone 7)

Applied only through `CombatService.applyStatusToMonster` or
`applyStatusToBrainrot`.

| Effect | Monsters | Brainrots |
| ------ | -------- | --------- |
| Freeze / Stun | Pauses movement (`frozenUntil`); visual style via optional `visual`: `"Ice"` (Lirili — Ice material + color, textures/SurfaceAppearance disabled, ice Highlight + flakes) or `"Bubble"` (Tralalero — float in shell, pop on release) | Pauses attacks (`frozenUntil`); client **dizzy ★ stars** + yellow rising **"Stunned"** floater (`CombatVisual` `Dizzy`). Multiple floaters on one Brainrot **queue** (lead word faster, then the next) so they never cover each other. |
| Slow | Reduces movement speed | — |
| Poison / Burn | DoT via `MonsterStatus` tick | DoT via `BrainrotBehavior` tick; **Poison** tints the Brainrot slightly purple (`BrainrotFeedback.setPoisoned`) for the duration and pops a rising **"Poisoned"** floater. Floaters share the same per-Brainrot queue as Stun. |
| Knockback | Pushes column east (+X) | — |
| Weaken | — | Scales the Brainrot's own outgoing `damage` down by `magnitude`% for `duration` (non-mutating `__index` override on the ability context's `definition` — see `BrainrotBehavior.effectiveDefinition`); every existing ability respects it automatically |

**Queen Spider** ✅ — **laneSpan 3** (random valid placement among anchors that
fit a 3-row footprint on the 5-row lawn). Does **not** jump. Each chew applies
`"Stun"` for `stunDuration` (2s) and `"Poison"` for `poisonDuration` (4s) at
`poisonPercent` (3% of the Brainrot's max HP per 1s tick). Cleaves all three
occupied lanes. Stun/poison visuals: dizzy stars + yellow "Stunned" floater;
slight purple model tint + purple "Poisoned" floater (queued so they don't overlap).
Uses the default tip-over death like other monsters.

**Scorpion** ✅ — `spawnStyle = RiseFromGround` in the forest (same mummy
entrance). `ScorpionBurrow` only on first **plot** column: sinks, travels
underground (invulnerable / untargetable), and rises just east of the first
Brainrot in its lane, then chews. Empty lanes do not burrow. Walk uses the same `proceduralWalk` crawl as Spider (no uploaded clips). Tunables:
`burrowDuration` / `burrowDepth` / `emergeOffset` (`MonsterConfig.BURROW_*`).

**Spider** ✅ — `SpiderJump` vaults the **first** Brainrot in its lane with a
visible parabola (`MonsterBehavior` jump state: column lerps west of the plant
while `floatY` peaks). The plant takes no damage; later Brainrots are chewed
normally. Tunables: `jumpDuration` / `jumpPeakHeight` / `jumpLandOffset` /
`jumpTriggerReach` on `abilityParams` (defaults in `MonsterConfig.JUMP_*`).

**Werewolf** ✅ — `WerewolfLifesteal`: each chew against a Brainrot
(`onBrainrotAttacked`) queues a heal of `lifestealPercent` (default **5**) of
its max HP via `abilityState.pendingHeal` (applied next `MonsterBehavior`
tick, capped at max HP). Fast march (`secondsPerGrid` 2.0).

**Lirili / Bombardino** — Lirili freeze (`applyStatusAroundColumn`, 2 tiles
ahead and behind) and Bombardino entire-row damage only target monsters **on
the lawn** (`isOnPlotColumn`). Bombardino column hits
match by **tile index** so chewing units at melee standoff still take damage.
Freeze/Stun are rejected while a monster is **downed**, and starting a tip-over
(last stand) clears any active freeze.

**Duke Vampire** ✅ — `DukeVampireFreeze` is a **once-only** last stand: at
≤20% HP he falls over (`MonsterDeath.playDowned`, rig intact —
`MonsterBehavior` suspends movement/attack/sync via `runtime.downedUntil`)
for 1.4s while invulnerable (`MonsterRuntime.invulnerableUntil`, checked in
`EnemyService.damageMonster`), then rises (`MonsterDeath.riseUp`) already
healed to 25% max HP. `DukeVampireTerrify`
deals **no damage**; on a 10s cooldown it applies `Weaken` + `Stun` to his row
± 1 (independent of `laneSpan`, which stays 1). His regular chew is a plain
stat-driven attack (no ability) at Vampire pace with more damage. Goblin
King's speed-buff stub still awaits a follow-up milestone.

---

## Client visuals ✅ (Milestone 11)

`CombatController` + `VfxUtil` (client) render feedback on the **local plot only**:

| Effect | Trigger |
| ------ | ------- |
| Hit spark | `CombatVisual` kind `Hit` (client particles) |
| Hit flash (monsters) | `MonsterFeedback.flashHit` on server (replicated body color) |
| Hit flash (Brainrots) | `BrainrotFeedback.flashHit` on server (replicated BasePart colors) |
| Hit / death / explosion SFX | `AudioController` via `CombatVisual` (M12) |
| Melee bat SFX | `BrainrotAction` (`MeleeBat`) after `attackHitDelay` — sound only for animated units; ScaleTo pulse only if not `animated` |
| Melee bat swing | Server `BrainrotAnimation.playAttack` at windup start (`pulseAttack`) |
| Death tip-over + linger + fade | Server `MonsterDeath` (default 3 tip styles); client burst + Thanos ash on fade |
| Line-bomb explosion | `CombatVisual` kind `Explosion` — Bombardino drops a bomb on each tile (staggered); on land the bomb despawns and a per-tile blast plays |
| Projectile trail/glow | Watches `plot.Projectiles` (non-blocking; never delays hit/death SFX). Piercing Brew shurikens use a gold trail/glow; server adds gold outline + sparks |
| Terrify scream | `CombatVisual` kind `Terrify` → `VfxUtil.playTerrifySoundwave` |
| Pharaoh steal sand tornado | `CombatVisual` kind `SandTornado` — vortex at the boss + grit from stolen plants |

Tuning lives in `Shared.Config.VfxConfig` (particles, colors, durations). Gameplay
values remain in `CombatConfig`.

---

## Death ✅ (Milestone 7 / M12 audio)

1. `CombatService.damageMonster` / `damageBrainrot` routes to the owning service.
   Brainrot hits pass a `sourceBrainrotId` so the monster records last-hit
   species. Status DoT and `BubbleTrap` bubbles omit that source, so they keep
   the previous last hit.
2. On monster death, `CombatService.notifyMonsterDeath` pushes `CombatVisual`
   `{ kind = "Death", instanceId, monsterId, row, column }` to the plot owner,
   grants Brainrot XP (`ProgressService.grantKillXp` — last-hit species for
   normal kills, skipping `SKIP_LAST_HIT` abilities; boss XP split across living
   plants), then increments `STAT_MONSTERS_DEFEATED`. Silent destroys (house
   breach, `clearPlot`) skip this and grant no XP. Support jobs (`COIN_XP` /
   `SOAK_XP` / `FREEZE_XP` / landed-hit `HIT_JOB`) grant separately via
   `grantBrainrotXp` — coin spit, wall damage ticks, freeze casts, every N
   landed hits (`BubbleTrap` every 2, `MeleeBat` every 3) **instead of** last-hit.
3. Client plays `Death_<monsterId>` when configured (else `Death`), then a death
   particle burst. After tip-over + linger, a Thanos-style ash disintegrate
   (`VfxUtil.playDeathDisintegrate`) plays as the corpse fades.
4. Server `MonsterDeath` bakes the live pose into welds (keeps overlay meshes
   glued; does not teleport named arms), then plays the definition's
   `deathStyle` (default: tip onto the ground — randomized faceplant / side
   flop / backfall), leaves the corpse for
   `CombatConfig.DEATH_CORPSE_LINGER` (2s), fades it out, then destroys the model.
5. Brainrot death destroys the placement and frees the tile (unchanged from M5).

Hit flash on damage uses server-side `MonsterFeedback.flashHit` /
`BrainrotFeedback.flashHit` so the red tint replicates reliably.

---

## Config

`Shared.Config.CombatConfig` — projectile speed, DoT intervals, monster death
fall / linger / fade timings. **Never hardcode** combat tuning in services.

---

## Remotes

| Name | Direction | Purpose |
| ---- | --------- | ------- |
| `CombatVisual` | server → client | `Hit` (`instanceId`, optional `soundKey` / `muteSound`), `Death` (`monsterId`, …), `Explosion` (`row`, optional `column` / `entireRow`) |

See `NETWORKING.md` for the full catalog.

---

## Ability routing

```
BrainrotBehavior.tryAct
       → Abilities/<id>
       → CombatService (attack / projectile / status)

MonsterBehavior.attackBrainrot
       → CombatService.damageBrainrot
       → Abilities.onBrainrotAttacked (boss effects)
```

**Pharaoh Mummy** ✅ — `PharaohSummon` spawns a `SmallMummy` in every row (20s).
`PharaohSteal` removes one living Brainrot from each of 3 random occupied lanes
(15s) via `BrainrotService.stealPlacement` (tile freed, model yanked toward the
boss) with a client sand-tornado suck (`CombatVisual` `SandTornado`). Steal is not Combat damage. Pharaoh and Small Mummy both use
`spawnStyle = "RiseFromGround"` (buried, then tween up; invulnerable while rising).
Pharaoh walk / chew / summon / steal clips live on the definition
(`abilityAnimationIds` for summon + steal; chew uses the Small Mummy attack id).
Summon/steal wait `summonHitDelay` / `stealHitDelay` after the clip starts.
Pharaoh **stops walking** for the clip length (`beginChannel`), then resumes walk.
