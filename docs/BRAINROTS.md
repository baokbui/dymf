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
| `maxHealth`       | number                 | HP pool (combat)                                                   |
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



## Starter unlock cadence ✅

New players start Day 1 with only three roster entries unlocked and equipped
— **Ballerina Cappucina**, **Tung Tung Sahur**, **Chimpanzini Bananini**
(`ProgressConfig.DEFAULT_UNLOCKS` / `DEFAULT_EQUIPPED`) — so the opening board
is economy + melee + wall only, matched against the Day 1–4 Zombie-only ramp
(see `BALANCE.md`). The remaining four unlock by clearing a day for the first
time (`ProgressConfig.UNLOCK_SCHEDULE`, granted server-side in
`LevelService.onVictory` → `ProgressService.grantUnlockForLevel`), auto-equipped
when there's an open loadout slot, and shown via a center-screen
`UnlockPopup` (client, display-only):

| Clear Day | Unlocks |
| --------- | ------- |
| 3 | Cappuccino Assassino |
| 5 | Lirili Larila |
| 7 | Tralalero Tralala |
| 9 | Bombardino Crocodilo |

This cadence is **starter-roster only** — a one-time, free unlock path tied to
campaign progress. It never applies to post-launch Brainrots (Milestone 25+),
which cost **Brains** at the physical Store (Milestone 19). Re-clearing an
already-cleared day (Day Select) does not re-grant or re-show the popup
(`grantUnlockForLevel` is idempotent per player).

## Roster ✅ (Milestone 5)


| Name                 | Cost | Health (hits) | Damage | Interval | Range    | Ability             | Coins |
| -------------------- | ---- | ------------- | ------ | -------- | -------- | ------------------- | ----- |
| Ballerina Cappucina  | 50   | 500 (5)       | 0      | 18s      | —        | Spits coins onto random tiles | 25    |
| Tung Tung Sahur      | 75   | 1200 (12)     | 55     | 1.5s     | 1 tile (own + ahead) | Melee bat           | —     |
| Tralalero Tralala    | 175  | 500 (5)       | 55     | 5.0s     | Full row | Bubble projectile → trap (0.5s) | —     |
| Bombardino Crocodilo | 375  | — (1)         | 1000   | —        | Full row | Line bomb on place  | —     |
| Lirili Larila        | 150  | 500 (5)       | 0      | 6.0s     | 2 tiles  | Freeze enemies 0.7s | —     |
| Cappuccino Assassino | 100  | 500 (5)       | 50     | 2.0s     | Full row | Throw spinning shuriken | —     |
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

Separately, each placed unit's **ability cooldown** (`attackInterval` —
`BrainrotBehavior.cooldownRemaining`, e.g. Ballerina's coin spit) only ticks
while `LevelService.isLevelActive` is true, so it's implicitly paused for the
whole time between a day ending and the next Start Day. Freshly-planted units
start at a full `attackInterval` (first act after one full interval of active
play). Units restored together (rejoin / committed-lawn restore via
`BrainrotService.restorePlacements`) get a **randomized** initial cooldown
instead, so several Ballerinas kept across a rejoin don't all spit coins in
lockstep the moment the day starts.

Monster targeting uses **first-in-row** acquisition for single-target attacks
and projectiles (M7). Targets must be **on the plot** — `GridUtil.isOnPlotColumn`
compares by **tile index** (`tileAtColumn(column) ≤ COLUMNS`), not raw
fractional column, so a monster stopped at its melee standoff on the frontmost
tile (`COLUMNS + MELEE_CLOSE_REACH`, a fraction past that tile's center) still
counts as on-plot; monsters still marching in the forest (a full tile+ away)
are ignored. This matters for melee units planted on the last column — e.g.
Tung Tung Sahur standing on the frontmost tile, or one tile behind a wall on
that tile — which would otherwise never see the monster actively chewing
them. Friendly Brainrots never block targeting: Tung Tung (`rangeTiles = 1`)
hits monsters on his tile or the tile ahead even while that tile's ally (any
roster unit) is being chewed. Coin producers and line-bomb placement work
independently of monster presence rules.

---



## Planned roster (Milestone 25)

Expand beyond the initial seven after launch. Each addition is registry data
plus an ability handler module when needed (see `ROADMAP.md` Post-Launch).

## Planned evolution & mutations (Milestone 20)

Two progression layers on existing Brainrots (see `ROADMAP.md` Milestone 20):

- **Evolution** — changes **color / look** and **base stats** (e.g. Diamond Tung
  Tung Tung Sahur: diamond tint + stronger HP/damage; same core ability).
- **Mutation** — **replaces** the unit's ability or **adds an extra** ability
  (ability handlers stay data-driven; no name-based combat branches).