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
| Freeze / Stun | Pauses movement (`frozenUntil`); visual style via optional `visual`: `"Ice"` (Lirili — icy tint + flakes) or `"Bubble"` (Tralalero — float in shell, pop on release) | Pauses attacks (`frozenUntil`) |
| Slow | Reduces movement speed | — |
| Poison / Burn | DoT via `MonsterStatus` tick | DoT via `BrainrotBehavior` tick |
| Knockback | Pushes column east (+X) | — |

**Queen Spider** ✅ — stuns brainrots on attack; poisons for `% max HP` per tick
(data in `abilityParams`).

Boss polish for Duke Vampire / Goblin King continues in **Milestone 10**.

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
| Death tip-over + linger + fade | Server `MonsterDeath` (3 random styles); client burst + Thanos ash on fade |
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
4. Server `MonsterDeath` tips the model slowly onto the ground (randomized
   faceplant / side flop / backfall), leaves the corpse for
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
