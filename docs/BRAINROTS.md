# BVM Brainrots

Brainrots are the player's defensive units, placed on the grid. They are
**data-driven**: behavior is resolved from definition data, never from giant
if/elseif chains (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Registry

Definitions live in `ReplicatedStorage.Shared.Brainrots` (the registry).

API:

```lua
local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
Brainrots.get(id)      -- BrainrotDefinition?  (nil if unknown)
Brainrots.exists(id)   -- boolean
Brainrots.getAll()     -- { [id]: BrainrotDefinition }  (do not mutate)
```

Adding a Brainrot = add one data entry to the registry. No code branching.

---



## Definition schema

From `Shared.Types.BrainrotDefinition`:


| Field             | Type                   | Meaning                                                            |
| ----------------- | ---------------------- | ------------------------------------------------------------------ |
| `id`              | string                 | Unique key (matches registry key)                                  |
| `name`            | string                 | Display name                                                       |
| `cost`            | number                 | Coin cost to place                                                 |
| `maxHealth`       | number                 | HP pool (display / health bar)                                     |
| `health`          | number                 | Hits the Brainrot can take                                         |
| `damage`          | number                 | Damage per attack (0 for non-attackers)                            |
| `attackInterval`  | number                 | Seconds between attacks/actions (0 = wall)                         |
| `rangeTiles`      | number                 | Tiles ahead toward +X; `BrainrotConfig.FULL_LINE_RANGE` = full row |
| `ability`         | string?                | Ability handler id (`BrainrotService/Abilities`)                   |
| `coinGeneration`  | number?                | Coins per cycle for producers                                      |
| `abilityParams`   | `{ [string]: number}`? | Per-ability tuning (trap/freeze duration, …)                       |
| `triggersOnPlace` | boolean?               | Fires ability once on placement (line bomb)                        |
| `color`           | Color3?                | Placement visual tint (ghost + body)                               |


Range is measured in **grid tiles** along the lane toward the enemy (+X), not
studs. `GridUtil.isColumnInRange` is the shared helper.

---



## Roster ✅ (Milestone 5)


| Name                 | Cost | Health (hits) | Damage | Interval | Range    | Ability             | Coins |
| -------------------- | ---- | ------------- | ------ | -------- | -------- | ------------------- | ----- |
| Ballerina Cappucina  | 50   | 500 (5)       | 0      | 11s      | —        | Drops coins on random tiles | 25    |
| Tung Tung Sahur      | 75   | 1000 (10)     | 45     | 0.95s    | Short melee (`meleeReach`) | Melee bat           | —     |
| Tralalero Tralala    | 175  | 500 (5)       | 90     | 1.45s    | Full row | Bubble trap (1.2s)  | —     |
| Bombardino Crocodilo | 375  | — (1)         | 2800   | —        | Full row | Line bomb on place  | —     |
| Lirili Larila        | 150  | 500 (5)       | 0      | 2.4s     | 2 tiles  | Freeze enemies 2s   | —     |
| Cappuccino Assassino | 100  | 500 (5)       | 60     | 1.75s    | Full row | Throw knife         | —     |
| Chimpanzini Bananini | 75   | 3500 (35)     | 0      | —        | —        | Wall                | —     |

Milestone 14 tuning rationale: **`docs/BALANCE.md`**.


---



## Service ownership

- `BrainrotService` (server) ✅ M4 (placement) / ✅ M5 (behavior) — owns
placement, instance lifecycle, per-instance state, and the behavior tick.
Ability handlers live in `BrainrotService/Abilities/` and are resolved from
`definition.ability` (never from names). Placement uses `GridService` +
`CoinService`; combat intents route through `CombatService`. Models are built
by `BrainrotModel`. Public: `getPlacements`, `getPlacement`.
- `CombatService` (server) ✅ M7 — row targeting, projectiles, status effects,
  target acquisition (first-in-row vs splash vs entire-row). Boss skill polish
  for Duke Vampire / Goblin King continues in M10.
- `CoinService` — credits producer output via `dropRandomCoinForOwner` (random grid tile).

Placed models are tagged `Brainrot` with `InstanceId` / `BrainrotId` /
`OwnerUserId` / `Row` / `Column` / `Health` attributes.

---



## Behavior architecture ✅ (Milestone 5)

```
BrainrotService (placement)
       │
       ▼
BrainrotBehavior (cooldown tick)
       │
       ▼
Abilities/<AbilityId>  ──►  CombatService (damage / status on monsters)
       │                 └──►  CoinService (coin drops)
       └──►  BrainrotFeedback (server attack pulse for non-melee abilities)
       └──►  BrainrotAction remote → client SFX (+ client pulse for MeleeBat)
```

- `BrainrotBehavior` steps every `BrainrotConfig.BEHAVIOR_TICK` seconds,
counts down `attackInterval`, and calls the ability's `tryAct` when ready.
- `triggersOnPlace` abilities (Bombardino) call `onPlaced` once. Bombardino
detaches from the tile, deals row damage, flies house → enemy along the row
while tile blasts track under it, then despawns.
- Attackers only reset their cooldown when `tryAct` returns true (e.g. no
monsters in range). **Coin producers** and **Lirili** always consume their
cycle when they fire.

Monster targeting uses **first-in-row** acquisition for single-target attacks
and projectiles (M7). Coin producers and line-bomb placement work independently
of monster presence rules.

---



## Planned roster (Milestone 21)

Expand beyond the initial seven after launch. Each addition is registry data
plus an ability handler module when needed (see `ROADMAP.md` Post-Launch).