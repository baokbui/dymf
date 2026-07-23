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
| `plantCooldown`   | number?                | Seconds before re-plant; nil → `BrainrotConfig.plantCooldownFor(cost)` |
| `color`           | Color3?                | Shop swatch + placeholder / ghost validity tint                    |
| `modelId`         | string?                | Child name under `Assets.Brainrots` (defaults to `id`)             |
| `modelOrientationDegrees` | Vector3?         | Local Euler after facing (+X)                                      |
| `modelScale`      | number?                | Footprint multiplier (default 1; compact units use `COMPACT_MODEL_SCALE`) |


Range is measured in **grid tiles** along the lane toward the enemy (+X), not
studs. `GridUtil.isColumnInRange` is the shared helper.

---



## Models ✅ (Milestone 15 pipeline)

Placed visuals come from **Toolbox / Studio Models** under
`ReplicatedStorage.Assets.Brainrots`. `BrainrotModel.create` resolves
`definition.modelId or definition.id`, clones + scales to
`PlotConfig.BRAINROT_FOOTPRINT_RATIO * (modelScale or 1)`, and tags identity attributes.
Shared helpers live in `Shared.Utilities.ModelUtil`.

If a template is missing, the server logs once and uses the colored Part
placeholder so gameplay still works.

### Studio: insert from Toolbox

After Rojo connects, place one Model per Brainrot as a child of
`ReplicatedStorage.Assets.Brainrots` (folder uses `$ignoreUnknownInstances` so
Rojo does not wipe Studio assets). Names may differ from registry ids — set
`modelId` on the definition to the **exact** Explorer child name:

| Registry `id` | Assets child (`modelId`) |
| ------------- | ------------------------ |
| `BallerinaCappucina` | `Ballerina Cappuccina` |
| `TungTungSahur` | `Tung Tung Tung Sahur` |
| `TralaleroTralala` | `Tralalero Tralala` |
| `BombardinoCrocodilo` | `Bombardiro Crocodilo` |
| `LiriliLarila` | `Lirilì Larilà` |
| `CappuccinoAssassino` | `Cappuccino Assassino` |
| `ChimpanziniBananini` | `Chimpanzini Bananini` |

For each Model: set `PrimaryPart` (feet/base), strip leftover Tools/Scripts/
Sounds (clones also strip audio in `ModelUtil` so plant SFX stay plot-owner-only),
face enemy (+X) if the Toolbox facing is wrong. Placement ghost clones the same
template. Compact units use `modelScale = BrainrotConfig.COMPACT_MODEL_SCALE`
(0.7); Tralalero and Bombardino stay at full footprint. Shop cards show a
**ViewportFrame model preview** from the same `Assets.Brainrots` template
(`client/Utilities/BrainrotPreview`); color swatch is the fallback if a
template is missing.

M15 **Complete When** (all seven real models in-game) ✅ — templates under
`Assets.Brainrots` with `modelId` mapping in `Shared.Brainrots`.

---



## Roster ✅ (Milestone 5)


| Name                 | Cost | Health (hits) | Damage | Interval | Range    | Ability             | Coins |
| -------------------- | ---- | ------------- | ------ | -------- | -------- | ------------------- | ----- |
| Ballerina Cappucina  | 50   | 500 (5)       | 0      | 18s      | —        | Spits coins onto random tiles | 25    |
| Tung Tung Sahur      | 75   | 800 (8)       | 40     | 1.5s     | 1 tile (own + ahead) | Melee bat           | —     |
| Tralalero Tralala    | 175  | 500 (5)       | 55     | 5.0s     | Full row | Bubble projectile → trap (0.5s) | —     |
| Bombardino Crocodilo | 375  | — (1)         | 1000   | —        | Full row | Line bomb on place  | —     |
| Lirili Larila        | 150  | 500 (5)       | 0      | 6.0s     | 2 tiles  | Freeze enemies 0.7s | —     |
| Cappuccino Assassino | 100  | 500 (5)       | 50     | 2.0s     | Full row | Throw spinning sword | —     |
| Chimpanzini Bananini | 75   | 2000 (20)     | 0      | —        | —        | Wall                | —     |

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
- `CoinService` — credits producer output via `dropRandomCoinForOwner` (spit from unit onto a random grid tile).

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
       └──►  BrainrotFeedback (server attack pulse + hit flash when damaged)
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

### Plant recharge (shop) ✅

After a successful plant, that Brainrot **id** recharges before it can be
planted again (PvZ seed packet). Duration scales with **cost** via
`BrainrotConfig.plantCooldownFor` (cheaper → shorter). Approximate roster:

| Cost | Example | Recharge |
| ---- | ------- | -------- |
| 50 | Ballerina | ~7.5s |
| 75 | Tung Tung / Chimpanzini | ~10s |
| 100 | Cappuccino | ~13s |
| 150 | Lirili | ~18s |
| 175 | Tralalero | ~21s |
| 375 | Bombardino | ~42s |

Server enforces the lock; shop cards show a countdown overlay. Recharges reset
on **Start Day**. Optional `definition.plantCooldown` overrides the formula.

Monster targeting uses **first-in-row** acquisition for single-target attacks
and projectiles (M7). Targets must be **on the plot** (`column ≤ COLUMNS`) —
monsters still marching in the forest are ignored. Friendly Brainrots never
block targeting: Tung Tung (`rangeTiles = 1`) hits monsters on his tile or the
tile ahead even while that tile's ally (any roster unit) is being chewed. Coin
producers and line-bomb placement work independently of monster presence rules.

---



## Planned roster (Milestone 23)

Expand beyond the initial seven after launch. Each addition is registry data
plus an ability handler module when needed (see `ROADMAP.md` Post-Launch).

## Planned evolution & mutations (Milestone 24)

Two progression layers on existing Brainrots (see `ROADMAP.md` Milestone 24):

- **Evolution** — changes **color / look** and **base stats** (e.g. Diamond Tung
  Tung Tung Sahur: diamond tint + stronger HP/damage; same core ability).
- **Mutation** — **replaces** the unit's ability or **adds an extra** ability
  (ability handlers stay data-driven; no name-based combat branches).