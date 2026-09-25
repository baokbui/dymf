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


| Field                     | Type                   | Meaning                                                                                  |
| ------------------------- | ---------------------- | ---------------------------------------------------------------------------------------- |
| `id`                      | string                 | Unique key (matches registry key)                                                        |
| `name`                    | string                 | Display name                                                                             |
| `cost`                    | number                 | Coin cost to place                                                                       |
| `maxHealth`               | number                 | HP pool (combat)                                                                         |
| `health`                  | number                 | Hits the Brainrot can take                                                               |
| `damage`                  | number                 | Damage per attack (0 for non-attackers)                                                  |
| `attackInterval`          | number                 | Seconds between attacks/actions (0 = wall)                                               |
| `rangeTiles`              | number                 | Tiles ahead toward +X; `BrainrotConfig.FULL_LINE_RANGE` = full row                       |
| `ability`                 | string?                | Ability handler id (`BrainrotService/Abilities`)                                         |
| `coinGeneration`          | number?                | Coins per cycle for producers                                                            |
| `abilityParams`           | `{ [string]: number}`? | Per-ability tuning (trap/freeze duration, …)                                             |
| `triggersOnPlace`         | boolean?               | Fires ability once on placement (line bomb / freeze cast); may plant on NightFog columns |
| `plantsOnFog`             | boolean?               | May plant on NightFog columns before the row is cleared (Giraffa)                        |
| `hidden`                  | boolean?               | Omit from shop, inventory, unlock-all, lawn restore                                      |
| `plantOnGrave`            | boolean?               | Must be planted on a grave (Patapim); graves sit on fog tiles                            |
| `ignoreMonsterChew`       | boolean?               | Monsters phase through; no chew damage (Lirili, Patapim)                                 |
| `plantCooldown`           | number?                | Seconds before re-plant; nil → `BrainrotConfig.plantCooldownFor(cost)`                   |
| `maxOnPlot`               | number?                | Cap of living plants of this id on one plot (Ballerina = 10). Nil = unlimited            |
| `color`                   | Color3?                | Shop swatch + placeholder / ghost validity tint                                          |
| `modelId`                 | string?                | Child name under `Assets.Brainrots` (defaults to `id`)                                   |
| `modelOrientationDegrees` | Vector3?               | Local Euler after facing (+X)                                                            |
| `modelScale`              | number?                | Footprint multiplier (default 1; compact units use `COMPACT_MODEL_SCALE`)                |
| `modelYOffset`            | number?                | Extra studs up (+) / down (−) after feet-snap to tile top                                |
| `previewFocusOffset`      | Vector3?               | Shop/inventory preview look-at nudge after visual center                                 |
| `animated`                | boolean?               | Keep Motor6D + Animator; play idle/attack tracks                                         |
| `idleAnimationId`         | string?                | Idle loop asset; nil → IdleAnimation child / AnimSaves                                   |
| `attackAnimationId`       | string?                | Action clip (swing / spit); nil → AttackAnimation child                                  |
| `hitAnimationId`          | string?                | Flinch when damaged; nil → HitAnimation child                                            |
| `attackHitDelay`          | number?                | Seconds after action anim starts before melee hit / coin drop                            |


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


| Registry `id`             | Assets child (`modelId`)     |
| ------------------------- | ---------------------------- |
| `BallerinaCappucina`      | `Ballerina Cappuccina`       |
| `TungTungSahur`           | `Tung Tung Tung Sahur`       |
| `TralaleroTralala`        | `Tralalero Tralala`          |
| `BombardinoCrocodilo`     | `Bombardiro Crocodilo`       |
| `LiriliLarila`            | `Lirilì Larilà`              |
| `CappuccinoAssassino`     | `Cappuccino Assassino`       |
| `ChimpanziniBananini`     | `Chimpanzini Bananini`       |
| `GiraffaCeleste`          | `Girafa Celestre`            |
| `BrrBrrPatapim`           | `Brr Brr Patapim`            |
| `OrangutiniAnanassini`    | `Orangutini Ananassini`      |
| `LaVaccaSaturnoSaturnita` | `La Vacca Saturno Saturnita` |
| `BlueberrinniOctopusini` | `Blueberrinni Octopusini` |


For each Model: set `PrimaryPart` (prefer `RootPart` / `HumanoidRootPart` —
`ModelUtil.pickPrimaryPart` does this on clone), strip leftover Tools/Scripts/
Sounds (clones also strip those in `ModelUtil`).

### Animated Brainrots ✅ (Milestone 17)

Set on the registry definition (never branch on names):


| Field                                                             | Role                                                                                |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `animated = true`                                                 | Keep Motor6Ds + Animator; `BrainrotAnimation` binds tracks                          |
| `idleAnimationId`                                                 | Optional; else `IdleAnimation` / `WalkAnimation` child, then idle-named `AnimSaves` |
| `attackAnimationId`                                               | Action clip (melee swing, coin spit, …); else `AttackAnimation` child               |
| `hitAnimationId`                                                  | Flinch when damaged; else `HitAnimation` child                                      |
| `attackHitDelay`                                                  | Seconds after action anim starts before hit / coin drop                             |
| `modelOrientationDegrees` / `modelYOffset` / `previewFocusOffset` | Placement + shop framing                                                            |


**Clip resolve order (idle):** embedded `IdleAnimation` → `WalkAnimation` →
`Animation` child → `definition.idleAnimationId` → `AnimSaves` KeyframeSequence
named idle/walk/stand (never attack/bat/swing).

**Clip resolve order (attack):** embedded `AttackAnimation` →
`definition.attackAnimationId`.

**Clip resolve order (hit):** embedded `HitAnimation` →
`definition.hitAnimationId`. Played on damage via `BrainrotAnimation.playHit`
(e.g. Chimpanzini when chewed).

**Playback:** server `BrainrotAnimation` (replicates). `pulseAttack` plays the
swing for animated units and skips the old ScaleTo body pulse. Client
`BrainrotController` still plays hit SFX; it also skips ScaleTo when
`definition.animated`.

**Melee / producer windup:** `attackHitDelay` starts the action anim
immediately, spends the cooldown, then applies damage (`MeleeBat`) or drops
coins (`GenerateCoins`). If a melee target left range during the windup, the
swing misses (no refund).

Shop/inventory `BrainrotPreview` preserves the rig + orientation but does **not**
play idle in the ViewportFrame (static framed pose; tune with
`previewFocusOffset`).

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
`UnlockPopup` (client, display-only). Day 1 starters do **not** get an intro
popup (they are already equipped). Reach-unlock units use
`ProgressConfig.BRAINROT_INTRO_SCHEDULE`:


| Clear Day | Unlocks              |
| --------- | -------------------- |
| 3         | Cappuccino Assassino |
| 5         | Lirili Larila        |
| 7         | Tralalero Tralala    |
| 9         | Bombardino Crocodilo |


This cadence is **starter-roster only** — a one-time, free unlock path tied to
campaign progress. It never applies to post-launch Brainrots (Milestone 25+),
which cost **Brains** at the physical Store (Milestone 18). Re-clearing an
already-cleared day (Day Select) does not re-grant or re-show the popup
(`grantUnlockForLevel` is idempotent per player).

**Reach unlock:** **Girafa Celestre** is granted on first reach of Day 25
(Night Fog). **Brr Brr Patapim** is granted on first reach of Day 31
(`ProgressConfig.REACH_UNLOCK_SCHEDULE`), alongside a graves **MechanicIntroPopup**.
Equip into an open loadout slot if
one exists (`MAX_EQUIPPED` is still 7).

**Store (Milestone 18):** Mini stores cloned beside each plot house
(`docs/STORE.md`). The Brainrot shop currently sells **Girafa Celestre** only
(50 brains in `ProgressConfig.STORE_CATALOG`; still granted free on reach Day 25). Starter-roster units and
**Brr Brr Patapim** stay campaign/reach unlocks — they are not sold.

## Roster ✅ (Milestone 5)


| Name                       | Cost | Health (hits) | Damage | Interval | Range                | Ability                                                                                                                                                                                      | Coins    |
| -------------------------- | ---- | ------------- | ------ | -------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Ballerina Cappucina        | 50   | 500 (5)       | 0      | 18s      | —                    | Spits coins onto random tiles (**max 10** on the plot)                                                                                                                                       | 25       |
| Tung Tung Sahur            | 75   | 1200 (12)     | 55     | 1.5s     | 1 tile (own + ahead) | Melee bat                                                                                                                                                                                    | —        |
| Tralalero Tralala          | 175  | 500 (5)       | 55     | 5.0s     | Full row             | Bubble projectile → trap (0.5s)                                                                                                                                                              | —        |
| Bombardino Crocodilo       | 325  | — (1)         | 1000   | —        | Full row             | Line bomb on place                                                                                                                                                                           | 30s      |
| Lirili Larila              | 75   | —             | 0      | —        | 2 ahead + 2 behind   | Freeze 5s on place; despawn after cast anim                                                                                                                                                  | 20s      |
| Cappuccino Assassino       | 100  | 500 (5)       | 50     | 2.0s     | Full row             | Throw spinning shuriken                                                                                                                                                                      | —        |
| Chimpanzini Bananini       | 50   | 2000 (20)     | 0      | —        | —                    | Wall                                                                                                                                                                                         | —        |
| Girafa Celestre            | 50   | — (immune)    | 0      | —        | —                    | One-shot: gust anim, blow fog off the whole plot for 7s, despawn                                                                                                                             | ~7.5s CD |
| Brr Brr Patapim            | 50   | — (immune)    | 0      | 2.6s     | —                    | Plant on a grave; 2 smashes per clip (1s apart); 6 collapse it, then despawns                                                                                                                | 12s CD   |
| Orangutini Ananassini      | 100  | 700 (7)       | 40     | 2.0s     | Full row             | Lobs a pineapple over the front monster and graves, hitting the one behind. A lone monster is the target. No evolutions yet. Store: 80 brains                                                | —        |
| La Vacca Saturno Saturnita | 75   | — (immune)    | 0      | —        | Adjacent rows        | Floats and bobs above the tile, pulls the closest **1-tile** monster on each neighboring row onto her tile (edge: 1, middle: 2). Monsters **2+ tiles wide** are not pulled. Gravity-well VFX: High is dense, Low is thinner, Off skips it. Then she vanishes. Store: 60 brains | —        |
| Blueberrinni Octopusini    | 50   | 600 (6)       | 0      | 10s      | Own row              | Lobs ink onto a random empty tile in her row (never her own). A nearer tile arcs lower; a farther tile arcs higher. Puddle lasts 7 seconds and slows monsters only while they stand in it. High shows the droplet and tail, Low the droplet only, Off neither. No evolutions yet. Store: 70 brains | —        |


Milestone 14 tuning rationale: `docs/BALANCE.md`.

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
       └──►  BrainrotAnimation (server idle / attack tracks when animated)
       └──►  BrainrotFeedback (ScaleTo pulse if not animated; hit flash on damage)
       └──►  BrainrotAction remote → client SFX (ScaleTo pulse only if not animated)
```

- `BrainrotBehavior` steps every `BrainrotConfig.BEHAVIOR_TICK` seconds,
counts down `attackInterval`, and calls the ability's `tryAct` when ready.
- `triggersOnPlace` abilities (Bombardino, Lirili) call `onPlaced` once.
Bombardino detaches, **flies** house → enemy in `(COLUMNS - 1) * LINE_BOMB_DROP_STAGGER`
seconds (so he lines up with each drop), and releases one
`Assets.Projectiles.Bomb` per tile as he passes. Bombs fall nose-down; on
impact they despawn into a tile explosion + column damage. Tune
`LINE_BOMB_DROP_STAGGER` (fly + drop cadence), `LINE_BOMB_FALL_DURATION`,
`LINE_BOMB_FLY_HEIGHT`, `LINE_BOMB_DROP_HEIGHT`,
`LINE_BOMB_DROP_ORIENTATION_DEGREES` in `BrainrotConfig`. Lirili stays on its
tile, plays attack anim + cast SFX, then applies `Freeze` (`Ice`) to monsters
on its tile and **2 tiles ahead and 2 behind** (`abilityParams.freezeTiles`)
for `abilityParams.freezeDuration` (5s; Mythic Permafrost overlays 7s). Claimed **Winter's Grasp** sets
`abilityParams.freezeEntireLane` and freezes the **whole row** instead.
`ignoreMonsterChew` means monsters walk through and never chew it. The plant
**despawns when the cast animation ends** (not when freeze expires); thaw SFX
plays when the freeze duration ends.
- Attackers only reset their cooldown when `tryAct` returns true (e.g. no
monsters in range). **Coin producers** always consume their cycle when they
fire. **Melee bat** with `attackHitDelay` returns true when the swing starts;
damage applies after the delay (may miss if the target left).



### Plant recharge (shop) ✅

After a successful plant, that Brainrot **id** recharges before it can be
planted again (PvZ seed packet). Duration scales with **cost** via
`BrainrotConfig.plantCooldownFor` (cheaper → shorter). Approximate roster:


| Cost | Example                 | Recharge                       |
| ---- | ----------------------- | ------------------------------ |
| 50   | Ballerina / Chimpanzini | ~7.5s                          |
| 75   | Tung Tung               | ~10s                           |
| 75   | Lirili                  | 20s (`plantCooldown` override) |
| 100  | Cappuccino              | ~13s                           |
| 175  | Tralalero               | ~21s                           |
| 325  | Bombardino              | 30s                            |


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

## Planned evolution (Milestone 19)

Each roster Brainrot has its own **Brainrot level** (not campaign day). At
levels 10 / 20 / 30 / 40 / 50 they unlock Epic → God (aura + stat / active /
passive / ultimate). Tiers stack; core shop id and base ability stay the same.

Full sheet + architecture: `docs/EVOLUTIONS.md`. XP is live (shared per
registry id; last-hit normal kills except `BubbleTrap` / `MeleeBat`; boss XP
split across plants on the lawn; coin / soak / freeze / bubble-every-2 /
melee-every-3 jobs). Claiming an evolution after the level gate spends
brains (`evolutions` save v6). **Epic** stat overrides apply on place / restore
/ claim; planted Epic+ units get a rarity-tinted aura (purple / gold /
red-orange). **High** shows the dense flame column, **Low** a thin core, and
**Off** no flames (the rarity outline stays). **Legendary** extras, **Mythic** passives, and **Immortal**
passives tick in combat from evolution ability ids / `abilityParams`. GOD
ultimates: Tung Tung **Sahur's Wrath**, Ballerina **Jackpot**, Chimpanzini
**Primal Retaliation**, Lirili **Glacial Dominion**, Cappuccino **Shadow
Requiem** ✅; Tralalero **Abyssal Torrent** ✅.
A separate mutation layer (replace or add an unrelated ability) is post-launch
(Milestone 25), not part of this ladder.