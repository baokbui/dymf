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

Range uses `GridUtil.isColumnInRange` with `BrainrotConfig.FULL_LINE_RANGE` (-1)
for full-row-from-tile attacks. Tile-based `rangeTiles` covers whole cells ahead.
**Melee bat** uses tile-based `rangeTiles` (Tung Tung = 1): hits monsters on the
Brainrot's own tile **or** one tile ahead. Friendly Brainrots do **not** block —
a bat behind Ballerina, Lirili, Chimpanzini, etc. can still hit a monster chewing
that unit. (Legacy fractional `MELEE_BAT_REACH` is unused.)

Monsters still east of the lawn (`column > GridConfig.COLUMNS`, forest march)
are **not** valid targets — Brainrots wait until the monster enters the plot.

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
`plot.Projectiles`, moves it along the row (+X), and applies damage on impact
(optional status via `options`). Appearance is set by `kind`:

| Ability | `kind` | On impact |
| ------- | ------ | --------- |
| Cappuccino (`ThrowKnife`) | `Shuriken` (flat 4-blade disc; spins horizontally around +Y) | Damage + `ThrowKnifeHit` |
| Tralalero (`BubbleTrap`) | `Bubble` (ForceField ball) | Damage + Freeze/`Bubble` shell + `BubbleTrap` |

Tuning: `CombatConfig` (speed, shuriken/bubble size, `SHURIKEN_SPIN_RADIANS_PER_SECOND`)
+ `MonsterConfig.BUBBLE_COLOR`. Client trail/glow branches on the `ProjectileKind`
attribute (`VfxUtil`).

---

## Status effects ✅ (Milestone 7)

Applied only through `CombatService.applyStatusToMonster` or
`applyStatusToBrainrot`.

| Effect | Monsters | Brainrots |
| ------ | -------- | --------- |
| Freeze / Stun | Pauses movement (`frozenUntil`); visual style via optional `visual`: `"Ice"` (Lirili — icy tint + flakes) or `"Bubble"` (Tralalero — float in shell, pop on release) | Pauses attacks (`frozenUntil`); client **dizzy ★ stars** + yellow rising **"Stunned"** floater (`CombatVisual` `Dizzy`). Multiple floaters on one Brainrot **queue** (lead word faster, then the next) so they never cover each other. |
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
Death uses `deathStyle = "SpiderFlat"` (legs fall flat, body drops — not tip-over).

**Spider** ✅ — `SpiderJump` vaults the **first** Brainrot in its lane with a
visible parabola (`MonsterBehavior` jump state: column lerps west of the plant
while `floatY` peaks). The plant takes no damage; later Brainrots are chewed
normally. Tunables: `jumpDuration` / `jumpPeakHeight` / `jumpLandOffset` /
`jumpTriggerReach` on `abilityParams` (defaults in `MonsterConfig.JUMP_*`).

**Duke Vampire** ✅ — `DukeVampireFreeze` is a **once-only** last stand: at
≤20% HP he falls over (`MonsterDeath.playDowned`, rig intact —
`MonsterBehavior` suspends movement/attack/sync via `runtime.downedUntil`)
for 1.4s while invulnerable (`MonsterRuntime.invulnerableUntil`, checked in
`EnemyService.damageMonster`), then rises (`MonsterDeath.riseUp`) already
healed to 50% max HP. `DukeVampireTerrify`
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
| Melee bat SFX + pulse | `BrainrotAction` (`MeleeBat`) — client pulse + sound together |
| Death tip-over / SpiderFlat + linger + fade | Server `MonsterDeath` (default 3 tip styles; Queen Spider `SpiderFlat`); client burst + Thanos ash on fade |
| Line-bomb explosion | `CombatVisual` kind `Explosion` — Bombardino flies house→enemy along the row; `entireRow` blasts each tile under the pass (`stagger` matches flight) |
| Projectile trail/glow | Watches `plot.Projectiles` (non-blocking; never delays hit/death SFX) |
| Coin pickup sparkle | `CoinController` when a collected coin despawns |

Tuning lives in `Shared.Config.VfxConfig` (particles, colors, durations). Gameplay
values remain in `CombatConfig`.

---

## Death ✅ (Milestone 7 / M12 audio)

1. `CombatService.damageMonster` / `damageBrainrot` routes to the owning service.
2. On monster death, `CombatService.notifyMonsterDeath` pushes `CombatVisual`
   `{ kind = "Death", instanceId, monsterId, row, column }` to the plot owner.
3. Client plays `Death_<monsterId>` when configured (else `Death`), then a death
   particle burst. After tip-over + linger, a Thanos-style ash disintegrate
   (`VfxUtil.playDeathDisintegrate`) plays as the corpse fades.
4. Server `MonsterDeath` plays the definition's `deathStyle` (default: tip onto
   the ground — randomized faceplant / side flop / backfall; Queen Spider:
   `SpiderFlat` legs-out collapse), leaves the corpse for
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
