# Brainrots vs. Monsters (BVM) Roadmap

## Purpose

This roadmap defines the development milestones for Brainrots vs. Monsters. Every milestone should result in a working, playable version of the game. Do not begin a new milestone until the current one is complete and tested.

---

# Milestone 0 — Project Setup

**Status: ✅ Complete**

## Goal

Create a solid foundation for the project.

## Tasks

- Create Git repository
- Configure Rojo
- Connect Rojo to Roblox Studio
- Create `.cursorrules`
- Create documentation
- Create project folder structure
- Create empty services
- Create shared configuration modules



## Complete When

- Project syncs correctly between Cursor and Roblox Studio.
- Folder structure is complete.
- Documentation exists.

---



# Milestone 1 — Player Plot System

**Status: ✅ Complete**

## Goal

Every player receives their own isolated battlefield.

## Tasks

- Plot assignment
- Plot ownership
- Plot cleanup
- Open plot traversal (spectate other plots; no collision barriers)
- Spawn locations
- Camera positioning



## Complete When

- Multiple players can join.
- Each player receives a unique plot.
- Players can walk to other plots to spectate.
- No player can plant on or collect coins from another player's plot (server validation).

---



# Milestone 2 — Grid System

**Status: ✅ Complete**

## Goal

Create the battlefield grid.

## Tasks

- Grid generation
- Grid tiles
- Tile coordinates
- Occupied tile tracking
- Grid highlighting



## Complete When

- Grid appears correctly.
- Tiles know whether they are occupied.

---



# Milestone 3 — Coin System

**Status: ✅ Complete**

## Goal

Implement the game's economy.

## Tasks

- CoinService
- Coin UI
- Passive coin drops
- Coin collection
- Server-side validation



## Complete When

- Players receive coins.
- Coin count updates correctly.
- Coins cannot be exploited.

---



# Milestone 4 — Placement System

**Status: ✅ Complete**

## Goal

Allow players to place Brainrots.

## Tasks

- Shop UI
- Brainrot selection
- Placement preview
- Tile validation
- Placement RemoteEvents
- Cost validation



## Complete When

- Players can purchase and place Brainrots.
- Coins are deducted correctly.
- Invalid placements are rejected.

---



# Milestone 5 — Brainrot Framework

**Status: ✅ Complete**

## Goal

Create the base Brainrot system.

## Tasks

- Base Brainrot module
- Configuration system
- Health
- Attack stats
- Cooldowns
- Animations
- Sounds



## Initial Brainrots

- Ballerina Cappucina (coin producer)
- Tung Tung Sahur (melee)
- Tralalero Tralala (bubble trap)
- Bombardino Crocodilo (line bomb)
- Lirili Larila (freeze)
- Cappuccino Assassino (full-row knife)
- Chimpanzini Bananini (wall)



## Complete When

- All seven Brainrots function correctly (coin generation + combat through
`CombatService`). ✅

---



# Milestone 6 — Monster Framework

**Status: ✅ Complete**

## Goal

Create enemies.

## Tasks

- Base Monster
- Pathfinding
- Health
- Damage
- Death
- Animations



## Roster

- Zombie, Vampire, Werewolf, Skeleton, Goblin
- Bosses: Goblin Elite, Necromancer, Goblin King, Queen Spider, Duke Vampire
- Spider (jump ability)



## Complete When

- Monsters walk across the battlefield. ✅
- Brainrots can damage monsters; monsters attack brainrots on tiles. ✅

---



# Milestone 7 — Combat System

**Status: ✅ Complete**

## Goal

Implement combat.

## Tasks

- CombatService
- Projectile system
- Damage
- Death
- Target acquisition



## Complete When

- Brainrots attack monsters.
- Monsters die correctly.

---



# Milestone 8 — Level System

**Status: ✅ Complete**

## Goal

Create the gameplay loop: a PvZ-style campaign of discrete, authored levels.

## Tasks

- Levels registry (authored, data-driven)
- Preparation phase
- Countdown
- Start Level button
- Spawn groups (internal waves) + progress bar
- Big final wave + warning
- Victory / Defeat detection
- Rewards
- Linear progression (unlock next level)
- Lawn carry-over on victory (plants stay, coins reset); wipe on defeat / day select


## Complete When

- Players can play a level, win it, and advance to the next one.
- Losing (house breached) lets the player retry the same level.

---



# Milestone 9 — Save System

**Status: ✅ Complete**

## Goal

Persist player progress.

## Save

- Current level
- Highest unlocked level
- Coins
- Player health
- Brainrots
- Brainrot positions
- Brainrot health
- Unlocks
- Upgrades
- Statistics



## Do Not Save

- Monsters
- Monster positions
- Projectiles
- Ground coins
- Temporary combat state



## Rejoin Behavior

- Restore battlefield
- Restore player progress
- Restart the saved level from the beginning



## Complete When

- Players can leave and return without losing progress.

---



# Milestone 10 — Additional Monsters

**Status: ✅ Complete**

## Add

- Introduce monsters from the roster into campaign data.
- **One** new non-boss every 5 levels (Level 5 = Goblin; 15 = Vampire; 25 = Spider).
- **One** boss every 10 levels (Level 10 = Goblin Elite; 20 = Duke Vampire;
  30 = Queen Spider).
- Adjacent levels ramp slowly — sometimes the same difficulty as the prior level.
- Days 21–24: Night weather; Days 25–30: NightFog (`docs/WEATHER.md`) +
  Spider / Queen Spider intros.



## Complete When

- Multiple enemy types appear during gameplay.

---



# Milestone 11 — Visual Effects

**Status: ✅ Complete**

## Add

- Projectiles
- Explosions
- Particles
- Death effects
- Coin effects



## Complete When

- Combat feels visually satisfying.

---



# Milestone 12 — Audio

**Status: ✅ Complete**

## Add

- Background music
- UI sounds
- Monster sounds
- Brainrot sounds
- Ambient sounds
- Boss music



## Complete When

- All major gameplay events have audio feedback.

---



# Milestone 13 — UI Polish

**Status: ✅ Complete** (physical Brainrots Store deferred → Milestone 19)

## Improve and Add

- Shop (Already implemented in a previous milestone. Can improve if needed) ✅
- Brainrots Store (Buy new brainrots) → **deferred to Milestone 19** (physical world shop)
- Brains (currency) ✅ granted on victory; spent at store in M19
- Reward System ✅ victory popup shows brains earned (level number × config)
- Inventory / Loadout ✅ equip & unequip unlocked Brainrots for the shop bar
- Coins ✅ (prior milestone)
- Level display ✅ + Level Select in Settings
- Health ✅ 5 hearts; −1 per house breach; defeat at 0
- Settings ✅ mute, music/SFX volume, Brainrot SFX toggle (left HUD entry)
- Reset Progress ✅ double-confirm in Settings → `ResetProgress`
- Statistics ✅ levels cleared, placements, kills, brains earned, time played
- Level Select → deferred (dedicated UI later; `SelectLevel` remote remains)

## Complete When

- UI is polished and easy to use. ✅

---



# Milestone 14 — Balancing ✅



## Tune

- Costs ✅
- Damage ✅
- Health ✅
- Coin generation ✅
- Cooldowns ✅
- Level difficulty ✅
- Enemy scaling ✅

## Done

- **`docs/BALANCE.md`** — design targets and knob locations
- **`EconomyConfig`** — `STARTING_COINS` 125; passive 25 coins / 25s
- **`LevelConfig`** — 5 hearts; big-wave warning 5s; spawn fallbacks tuned
- **`Shared.Brainrots`** — roster costs, DPS, wall tankiness, Bombardino 1000 row nuke
- **`Shared.Monsters`** — single `Zombie` profile; `Goblin` / `GoblinElite` species mix
- **`Shared.Levels`** — L1–4 Zombie-only (count/pacing); L5+ species mix; Goblin Elite spawn delay

## Complete When

- Gameplay feels fair and engaging. ✅

---



# Milestone 15 — Brainrot Models

**Status: ✅ Complete**

## Replace placeholder visuals

The current roster uses **test placeholders** — colored `Part` bodies built by
`BrainrotModel` from each definition's `color` swatch. Replace them with authored
3D models for every shipped Brainrot.

## Add

- Model source for each roster Brainrot (Studio assets under `ReplicatedStorage`
  or catalog `Model` / `MeshPart` references — decide at implementation) ✅
  - Folder: `ReplicatedStorage.Assets.Brainrots` (`$ignoreUnknownInstances`)
  - Source: Toolbox Models you insert in Studio (named by Brainrot `id`)
- Data-driven mapping from `BrainrotDefinition` → model template (registry field
  or `BrainrotModel` lookup table — no per-name branching) ✅ `modelId` / default `id`
- `BrainrotModel.create` clones the authored template, applies footprint scaling
  (`PlotConfig.BRAINROT_FOOTPRINT_RATIO`), and preserves identity attributes /
  `Brainrot` tag ✅ (`ModelUtil`; Part fallback if missing)
- Shop cards and placement ghost use model preview or thumbnail where applicable
  (still display-only on the client) ✅ ghost clones template; shop keeps color swatch
- Wall / line-bomb / fly-over units keep correct bounds and pivot after swap ✅
  - Attack pulse uses `Model:ScaleTo` (not Size-tween)
  - LineBomb fly-over uses `PivotTo` + extents height

## Complete When

- All seven launch Brainrots use their real models in-game (placement, combat
  pulse, save/restore) instead of colored placeholder parts. ✅
  - Templates under `Assets.Brainrots`; `modelId` mapped to Studio names in
    `Shared.Brainrots` (see `docs/BRAINROTS.md`).

---



# Milestone 16 — Monster Models



## Replace placeholder visuals

Monsters currently use **test placeholders** — colored `Part` bodies from
`MonsterModel` / definition `color` swatches. Replace them with authored 3D
models for campaign enemies (same pattern as Milestone 15 Brainrots).

## Add

- Model source for shipped monsters (Studio under `ReplicatedStorage.Assets.Monsters`
  with `$ignoreUnknownInstances`, or catalog templates — decide at implementation) ✅
  - Folder: `ReplicatedStorage.Assets.Monsters` (`$ignoreUnknownInstances`)
  - Source: Toolbox Models you insert in Studio (named by monster `id` / `modelId`)
- Data-driven mapping from `MonsterDefinition` → template (`modelId` defaults to
  `id` — no per-name branching) ✅
- `MonsterModel.create` clones the template, applies footprint scaling
  (`MonsterConfig`), preserves identity attributes / `Monster` tag ✅
  (`ModelUtil`; Part fallback if missing; faces house −X)
- Bosses keep correct bounds (larger footprint / PrimaryPart) after swap ✅
- Hit flash and freeze/bubble shells still resolve against `PrimaryPart` /
  `"Body"` (or shared `ModelUtil` helpers) ✅
  - Movement / knockback: `ModelUtil.snapFeetToTileTop`
  - Pulse: `Model:ScaleTo`; flash/freeze tint visible BaseParts

## Complete When

- Campaign monsters used in authored levels (at least Zombie, Goblin, Goblin Elite, plus
  any other types already in `Shared.Levels`) use real models in-game instead of
  colored placeholder parts.
  - **Pipeline ✅** — insert Toolbox Models per `docs/MONSTERS.md` Models table to finish.
  - Status: 🔜 pending until campaign templates exist under `Assets.Monsters`.

---



# Milestone 17 — Animations



## Goal

Add authored animations for Brainrots (and monsters where ready) on top of the
M15–M16 model pipelines. **Combat outcomes stay server-authoritative.** Unit
Animator tracks (idle / attack / walk) are driven on the **server** so Motor6D
poses replicate to all clients — same pattern as `MonsterAnimation` (Tung Tung
`BrainrotAnimation` ✅). Client still owns SFX, particles, and UI juice
(`.cursorrules` presentation layer).

## Add

- Animation assets / ids per unit (idle, attack, death — extend as needed)
- Data-driven mapping on definitions (`animated`, `idleAnimationId`,
  `attackAnimationId`, `attackHitDelay` — no per-name branching) ✅ Tung Tung
- Server modules play clips when behavior fires (`BrainrotAnimation` /
  `MonsterAnimation`) — display-only relative to combat math
- Brainrot idle + attack for the launch seven; wall / one-shot units use idle
  (and place/fly clips where applicable) — 🔜 remaining six after Tung Tung
- Monster walk / attack / death when models support it (partial ✅)

## Complete When

- Launch Brainrots animate idle and attack in-game instead of static poses /
  ScaleTo-only feedback alone. (Tung Tung ✅; others 🔜)
- Combat damage / targeting remain server-authoritative; Animator playback does
  not grant client authority over hits.

---



# Milestone 18 — Retention Systems



## Goal

Add first-time and recurring meta rewards that bring players back without
touching core combat or level authority. Server owns all claim/progress state;
UI only displays and sends intents.

## Systems



### 7-Day First-Time Rewards

- One-time login streak for new players (days 1–7)
- Authored reward table (coins and/or unlocks)
- Persist claimed days + streak day via `SaveService`
- Missed-day rules (reset streak vs. pause — decide at implementation)
- Claim UI; server validates eligibility before granting



### Spinner

- Weighted reward wheel (coins, unlocks, cosmetics placeholders as available)
- Free spin cadence (e.g. daily) + optional paid/extra spins later
- Server rolls outcome; client only animates the result
- Persist last spin time / remaining free spins



### Daily Quests

- Small rotating quest pool (e.g. place N Brainrots, clear a level, collect coins)
- Daily reset (timezone / UTC — decide at implementation)
- Progress tracked server-side; claim rewards when complete
- Persist quest ids, progress, and claim state via `SaveService`



## Architecture Notes

- New service(s) own eligibility, rolls, and quest progress (e.g. `RewardService`,
`QuestService`) — never trust client claim/spin results
- Grants go through existing economy / unlock APIs (`CoinService`, etc.)
- Remotes for claim / spin / quest claim with full server validation
- UI panels under `UIController` (display-only)



## Complete When

- New players can claim a 7-day first-time reward track.
- Players can use the spinner on its free cadence and receive the rolled reward.
- Daily quests appear, track progress, reset on schedule, and grant rewards on claim.
- All progress survives leave/rejoin; exploits (double-claim, fake progress) fail server checks.

---



# Milestone 19 — Progression Store

**Status: 🔜 Planned** (deferred from Milestone 13)

## Add

- Physical **Brainrots Store** on the plot / lobby (not a ScreenGui shop bar)
- Spend **Brains** to unlock new Brainrot roster entries
- Wire purchases into `ProgressService` unlocks + `SaveService`

## Complete When

- Players can browse and buy locked Brainrots with brains earned from levels.

---



# Milestone 20 — Brainrot Evolution & Mutations

**Status: 🔜 Planned**

## Goal

Add two data-driven progression layers on top of the base roster — **evolutions**
and **mutations** — without name-based combat forks. Server owns unlocks and
placement identity; client UI is display + intent only.

## Definitions

| Layer | What it changes | What it does **not** change |
| ----- | --------------- | --------------------------- |
| **Evolution** | **Color / look** (tint or prestige visual) and **base stats** (HP, damage, attack interval, cost, range, coin generation, etc.) | Core ability identity (still the same ability id) |
| **Mutation** | **Ability** — replace the unit’s ability **or** add an **extra** ability | Base stat line (unless a later balance pass explicitly couples them) |

Example flavor: **Diamond Tung Tung Tung Sahur** is an *evolution* of Tung Tung
(diamond color + stronger melee stats, still `MeleeBat`). A mutation on Tung Tung
might swap bat for a different ability, or add a secondary ability on top of bat.

Evolutions and mutations can stack on the same unit if authored that way
(e.g. Diamond Tung Tung + a mutation) — decide composition rules at impl.

## Examples (authoring targets)

### Evolutions (color + base stats)

| Base | Evolved form (example) | Direction |
| ---- | ---------------------- | --------- |
| Tung Tung Tung Sahur | Diamond Tung Tung Tung Sahur | Diamond look + higher HP / damage |
| Ballerina Cappucina | (TBD) | Prestige tint + faster / richer coin generation |
| Cappuccino Assassino | (TBD) | Prestige tint + stronger / faster shuriken stats |
| Other roster units | (TBD) | At least one evolution path each for this system’s launch |

### Mutations (ability change / extra ability)

| Base (example) | Mutation direction (example) |
| -------------- | ---------------------------- |
| Tung Tung | Replace `MeleeBat` **or** add a second ability (e.g. slow on hit) |
| Ballerina | Extra ability alongside `GenerateCoins` (e.g. small heal pulse) |
| Cappuccino | Replace / augment `ThrowKnife` (e.g. pierce, burn on hit) |
| Other roster units | At least one mutation option each for this system’s launch |

Exact names, costs, stat deltas, and ability ids are balancing / content work —
tables above are flavor targets, not final numbers.

## Tasks

- Shared schema for evolution + mutation definitions (base id, costs,
  requirements, stacking rules)
- **Evolutions:** color / visual override + base-stat overrides on the common
  Brainrot interface (prefer tint / material / `color` + optional prestige
  `modelId` when a full mesh swap is needed)
- **Mutations:** ability override and/or extra ability id list resolved by
  `BrainrotBehavior` / Abilities (multi-ability tick without name branches)
- Unlock / purchase / fuse flows (Brains, coins, and/or materials — decide at impl)
- Persist owned evolutions + mutations via `SaveService` (`unlocks` /
  `upgrades` / versioned fields)
- Shop / Inventory / loadout show evolved + mutated variants when owned
- Optional: evolution / mutation apply VFX + plant SFX variants

## Architecture Notes

- **Data-driven only** — no `if id == "DiamondTungTung"` combat trees; resolve
  effective definition (stats + color) and ability set from registry + owned
  modifiers
- Evolutions compose onto base stats/color; mutations compose onto
  `ability` / extra abilities — keep a single placement runtime shape
- Server owns eligibility, spend, and grants (`ProgressService` or a dedicated
  evolution/mutation API)
- Models stay on the Milestone 15 pipeline when a prestige mesh is used
- Save schema stays versioned; migrate players who already own bases

## Complete When

- At least one **evolution** path ships end-to-end (prefer **Tung Tung →
  Diamond Tung Tung Tung Sahur**: unlock, color + stats, place, combat,
  save/rejoin).
- At least one **mutation** ships end-to-end (ability replaced **or** extra
  ability active in combat, persist + rejoin).
- Players obtain both through authored costs/requirements.
- Exploits (free evolve/mutate, fake ownership) fail server validation.

---



# Milestone 21 — Boss Collection House

**Status: 🔜 Planned** (house shell ✅ now; collection / income later)

## Goal

Turn the plot **house** into a boss trophy room: defeating a new boss unlocks
it for display; displayed bosses generate **brains** used for the store (M19)
and evolutions/mutations (M20).

## Prerequisites

- Plot houses + empty `BossSlot_*` pedestals (`HouseBuilder` / `HouseConfig`) ✅
- Brains currency + ProgressService ✅ (M13)
- Boss monsters authored in levels (`isBoss`) ✅

## Add

- On **first defeat** of a boss species, unlock for the player's collection
  (server-authoritative; persist `SaveData.collectedBosses`)
- `HouseService` places a scaled display model on the next free pedestal
- Passive **brains** income from displayed bosses (config rate per `monsterId`)
- Optional UI: collection progress / brains-per-minute readout (display-only)

## Architecture Notes

- New **`HouseService`** owns display placement + income ticks; grants brains
  through `ProgressService` (never invent balances on the client)
- Only `SaveService` persists collected bosses
- Pedestal markers already exist under `PlotN.House.BossDisplay`
- Full design: **`docs/HOUSE.md`**

## Complete When

- Defeating Goblin Elite (and later bosses) once unlocks a house trophy.
- Trophy appears on a pedestal after rejoin (save/load).
- Displayed bosses grant brains over time; spend path uses existing brains sinks.
- Exploits (fake collect, double income) fail server validation.

---



# Milestone 22 — Optimization



## Improve

- Performance
- Memory usage
- Network traffic
- Object cleanup
- Event management



## Complete When

- Stable performance with multiple players and many units.

---



# Milestone 23 — Testing



## Test

- Saving
- Rejoining
- Multiplayer
- Placement
- Combat
- Bosses
- Exploit prevention
- Edge cases



## Complete When

- No critical bugs remain.

---



# Milestone 24 — Release



## Final Tasks

- Publish game
- Create icon
- Create thumbnails
- Create trailer
- Configure game page
- Enable analytics
- Final playtesting



## Complete When

- Brainrots vs. Monsters is publicly released.

---



# Milestone 25 — Post-Launch



## Continue Development

- **New Brainrots** — expand the roster beyond the launch seven (registry +
  ability handlers; additional model work as needed)
- Brainrot evolution & mutations → **Milestone 20**
- Boss collection house (display defeated bosses → brains income) → **Milestone 21**
- New Monsters
- New Maps
- Seasonal Events
- Achievements
- Cosmetics
- Quality of Life updates
- Balance patches

Development continues indefinitely after release.

---
