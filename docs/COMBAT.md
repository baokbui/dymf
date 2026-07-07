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
| `CombatController` (client) | Hit flash + death fade (`CombatVisual` remote) |
| `HealthBarController` (client) | Billboard health bars on the local plot |

---

## Target acquisition ✅ (Milestone 7)

Monsters use **fractional grid columns** (west toward the house = decreasing
column). When a Brainrot attacks a row:

| Mode | API | Behavior |
| ---- | --- | -------- |
| First in row | `attackFirstInRow` / `launchProjectile` | Damages the monster with the **lowest column** in range (closest to the house — PvZ peashooter style) |
| All in range | `attackInRow` | Damages every monster in range (e.g. Tralalero bubble splash) |
| Entire row | `dealEntireRowDamage` | Damages **every** monster on the row (Bombardino line bomb) |

Range uses `GridUtil.isColumnInRange` with `BrainrotConfig.FULL_LINE_RANGE` (-1)
for full-row-from-tile attacks. Tile-based `rangeTiles` covers whole cells ahead.
**Melee bat** uses fractional `abilityParams.meleeReach` (see `BrainrotConfig.MELEE_BAT_REACH`)
so the attacker only hits monsters right beside the Brainrot.

---

## Projectiles ✅ (Milestone 7)

`CombatService.launchProjectile` spawns a server-replicated part in
`plot.Projectiles`, moves it along the row (+X), and applies damage on impact.
Used by **Cappuccino Assassino** (`ThrowKnife` ability).

Tuning: `Shared.Config.CombatConfig` (`PROJECTILE_COLUMNS_PER_SECOND`, size, color).

---

## Status effects ✅ (Milestone 7)

Applied only through `CombatService.applyStatusToMonster` or
`applyStatusToBrainrot`.

| Effect | Monsters | Brainrots |
| ------ | -------- | --------- |
| Freeze / Stun | Pauses movement (`frozenUntil`) | Pauses attacks (`frozenUntil`) |
| Slow | Reduces movement speed | — |
| Poison / Burn | DoT via `MonsterStatus` tick | DoT via `BrainrotBehavior` tick |
| Knockback | Pushes column east (+X) | — |

**Queen Spider** ✅ — stuns brainrots on attack; poisons for `% max HP` per tick
(data in `abilityParams`).

Boss polish for Duke Vampire / Goblin King continues in **Milestone 10**.

---

## Death ✅ (Milestone 7)

1. `CombatService.damageMonster` / `damageBrainrot` routes to the owning service.
2. On monster death, `CombatService.notifyMonsterDeath` pushes `CombatVisual`
   to the plot owner; model destroy is delayed briefly for client fade.
3. Brainrot death destroys the placement and frees the tile (unchanged from M5).

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
| `CombatVisual` | server → client | Hit flash, death fade (plot owner only) |

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
