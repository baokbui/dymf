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
| `HealthBarController` (client) | Billboard health bars on the local plot |

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
**Melee bat** uses fractional `abilityParams.meleeReach` (see `BrainrotConfig.MELEE_BAT_REACH`)
so the attacker only hits monsters right beside the Brainrot.

---

## Projectiles ✅ (Milestone 7)

`CombatService.launchProjectile` spawns a server-replicated part in
`plot.Projectiles`, moves it along the row (+X), and applies damage on impact
(optional status via `options`). Appearance is set by `kind`:

| Ability | `kind` | On impact |
| ------- | ------ | --------- |
| Cappuccino (`ThrowKnife`) | `Knife` (default neon bolt) | Damage + `ThrowKnifeHit` |
| Tralalero (`BubbleTrap`) | `Bubble` (ForceField ball) | Damage + Freeze/`Bubble` shell + `BubbleTrap` |

Tuning: `CombatConfig` (speed, knife/bubble size) + `MonsterConfig.BUBBLE_COLOR`.
Client trail/glow branches on the `ProjectileKind` attribute (`VfxUtil`).

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
| Death burst + fade | `CombatVisual` kind `Death` |
| Line-bomb explosion | `CombatVisual` kind `Explosion` — Bombardino flies house→enemy along the row; `entireRow` blasts each tile under the pass (`stagger` matches flight) |
| Projectile trail/glow | Watches `plot.Projectiles` (non-blocking; never delays hit/death SFX) |
| Coin pickup sparkle | `CoinController` when a collected coin despawns |

Tuning lives in `Shared.Config.VfxConfig` (particles, colors, durations). Gameplay
values remain in `CombatConfig`.

---

## Death ✅ (Milestone 7 / M12 audio)

1. `CombatService.damageMonster` / `damageBrainrot` routes to the owning service.
2. On monster death, `CombatService.notifyMonsterDeath` pushes `CombatVisual`
   `{ kind = "Death", instanceId, monsterId, row, column }` to the plot owner;
   model destroy is delayed briefly for client fade.
3. Client plays `Death_<monsterId>` when configured (else `Death`), then death VFX.
4. Brainrot death destroys the placement and frees the tile (unchanged from M5).

Hit flash on damage uses server-side `MonsterFeedback.flashHit` /
`BrainrotFeedback.flashHit` so the red tint replicates reliably.

---

## Health bars ✅ (Milestone 7)

`HealthBarController` attaches a `BillboardGui` to `Body` on tagged Brainrots and
Monsters **on the local player's plot**. Bars read `Health` / `MaxHealth`
attributes (server-authoritative). Boss monsters use a wider bar.

---

## Config

`Shared.Config.CombatConfig` — projectile speed, DoT intervals, health bar layout,
death fade duration. **Never hardcode** combat tuning in services.

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
