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
- Lawn carry-over on victory (plants stay, coins reset); defeat restores
  checkpoint on same day (Rewind); wipe on day select


## Complete When

- Players can play a level, win it, and advance to the next one.
- Losing (house breached) lets the player retry the same level.

---



# Milestone 9 — Save System

**Status: ✅ Complete**

## Goal

Persist player progress.

## Save

- Current day
- Highest unlocked day
- Brains
- Player health (hearts)
- Planted Brainrots (id, tile, HP) — **victory checkpoint only**
- Unlocks
- Equipped loadout
- Upgrades
- Statistics



## Do Not Save

- **Coins** (Day 1 → `STARTING_COINS`; later days → 0 via `applyDayPurse`)
- Mid-day plants (until that day is won)
- Monsters / monster positions
- Projectiles
- Ground coins
- Temporary combat state
- Level timers



## Rejoin Behavior

- Restore day, hearts, brains, unlocks, and the **committed** lawn
- Coins via day purse (not a saved balance)
- Press Start Day again (active day does not resume mid-fight)



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
- Days 21–24: Night weather; Days 25–34: NightFog; Days 35–40: NightFogReceded;
  Days 41–50: Desert (`docs/WEATHER.md`) — Small Mummy, Scorpion (45), Pharaoh (50).



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

**Status: ✅ Complete** (physical Progression Store → Milestone 18)

## Improve and Add

- Shop (Already implemented in a previous milestone. Can improve if needed) ✅
- Brainrots Store (Buy new brainrots) → **Milestone 18** (HUD shops)
- Brains (currency) ✅ granted on victory; spent at store in M18
- Reward System ✅ victory popup shows brains earned (level number × config)
- Inventory / Loadout ✅ equip & unequip unlocked Brainrots for the shop bar
- Coins ✅ (prior milestone)
- Level display ✅ (Day panel). Level Select in Settings was **not** shipped —
  deferred to a dedicated UI (`SelectLevel` remote remains)
- Health ✅ 5 hearts; −1 per house breach; defeat at 0
- Settings ✅ mute, music/SFX volume, Brainrot SFX toggle, VFX High / Low / Off (bottom-left HUD)
- Reset Progress ✅ double-confirm in Settings → `ResetProgress`
- Statistics ✅ levels cleared, placements, kills, brains earned, time played

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

**Status: ✅ Complete**

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

- Campaign monsters used in authored levels (Zombie, Goblin, Goblin Elite, and
  the rest of the Days 1–50 roster in `Shared.Levels`) use real models in-game
  instead of colored placeholder parts. ✅
  - Templates under `Assets.Monsters` (Werewolf may live under `Assets.Brainrots`;
    `ModelUtil` falls back). See `docs/MONSTERS.md`.

---



# Milestone 17 — Animations

**Status: ✅ Complete**

## Goal

Add authored animations for Brainrots (and monsters where ready) on top of the
M15–M16 model pipelines. **Combat outcomes stay server-authoritative.** Unit
Animator tracks (idle / attack / walk) are driven on the **server** so Motor6D
poses replicate to all clients — same pattern as `MonsterAnimation` (Tung Tung
`BrainrotAnimation` ✅). Client still owns SFX, particles, and UI juice
(`.cursorrules` presentation layer).

## Add

- Animation assets / ids per unit (idle, attack, death — extend as needed) ✅
- Data-driven mapping on definitions (`animated`, `idleAnimationId`,
  `attackAnimationId`, `attackHitDelay` — no per-name branching) ✅
- Server modules play clips when behavior fires (`BrainrotAnimation` /
  `MonsterAnimation`) — display-only relative to combat math ✅
- Brainrot idle + attack for the launch seven; wall / one-shot units use idle
  (and place/fly clips where applicable) ✅
- Monster walk / attack / death when models support it ✅
  (procedural gait where Toolbox clips are permission-locked)

## Complete When

- Launch Brainrots animate idle and attack in-game instead of static poses /
  ScaleTo-only feedback alone. ✅
- Combat damage / targeting remain server-authoritative; Animator playback does
  not grant client authority over hits. ✅

---



# Milestone 18 — Progression Store

**Status: ✅ Complete** (moved ahead of Retention, now M20; deferred from Milestone 13)

## Add

- Physical **Brainrot shop** cloned beside each plot house (Talk to Tung Mascot)
- HUD **Upgrades** next to Inventory (no red stall)
- HUD **Index** catalog of encountered Brainrots / Monsters
- **Brainrots** shop: spend **Brains** on `STORE_CATALOG`
  (Girafa Celestre for now; still free on reach Day 25). Starter roster and
  Patapim stay campaign/reach unlocks.
- **Upgrades** shop: spend Brains on player upgrades (Speed, Magnet)
- Catalog in `ProgressConfig.STORE_CATALOG` / `UPGRADE_CATALOG`
- Purchases through `ProgressService` + persist via `SaveService` (`unlocks`,
  `upgrades`)

## Complete When

- Players can talk to the Brainrot stall or open HUD Upgrades, browse, and buy with brains.
- Speed upgrades apply on spawn / rejoin.
- Exploits (free unlock, fake spend) fail server validation.

---



# Milestone 19 — Brainrot Evolution

**Status: ✅ Complete**

## Goal

Give each roster Brainrot its own **leveling track** (XP + Brainrot level),
independent of campaign days. At Brainrot levels **10 / 20 / 30 / 40 / 50**
unlock a cumulative **Epic → God** rarity ladder (aura + stat / active /
passive / ultimate). Server owns XP, level, and grants; client UI is display +
intent only. Full design: **`docs/EVOLUTIONS.md`**.

Do **not** treat sheet “Level 10” as campaign Day 10.

## Systems

- **Brainrot levels** — one meter per registry id (all planted copies share it)
- **Five tiers** — Epic (purple, stat), Legendary (gold, active), Mythic
  (red-orange, passive), Immortal (dark red, passive), God (rainbow,
  ultimate)
- **Authored rows** for Ballerina, Chimpanzini, Tung Tung, Tralalero,
  Cappuccino, Lirili (Girafa / Patapim / Bombardino TBD)

## Tasks

- Shared schema: Brainrot XP map live (`brainrotXp`); evolution rows
  (`brainrotId` + rarity, ability ids, **Epic `stats`**, **Legendary extras**,
  **Mythic passives**) ✅; **Immortal passives** ✅; GOD ultimates: Tung
  Tung Sahur (`SahurWrath`), Ballerina (`Jackpot`), Chimpanzini
  (`PrimalRetaliation`), Lirili Glacial Dominion, Cappuccino
  (`ShadowRequiem`), Tralalero (`AbyssalTorrent`) ✅
- XP grant rules ✅ — last-hit species for normal kills (`BubbleTrap` /
  `MeleeBat` skipped); boss XP split evenly across every living plant; support
  jobs (`COIN_XP` / `SOAK_XP` / `FREEZE_XP` / `BUBBLE_XP` every 2 landed
  bubbles / `MELEE_XP` every 3 connecting hits)
- Compose Epic stats onto the common placement runtime ✅
  (`Evolutions.applyStats` — no name branches). Legendary extras ✅
  (`claimedExtras` + `tickExtras`). Mythic passives ✅
- Persist XP via `SaveService` (v5) and claimed tiers (v6 `evolutions`);
  Epic combat stats ✅; Legendary combat extras ✅; Mythic passives ✅;
  Immortal passives ✅; GOD ultimates: Tung Tung (`SahurWrath`), Ballerina
  (`Jackpot`), Chimpanzini (`PrimalRetaliation`), Lirili Glacial Dominion,
  Cappuccino (`ShadowRequiem`), Tralalero (`AbyssalTorrent`) ✅
- Inventory / field inspect show portrait header (name, HP bar, level, XP bar)
  plus Stats and evolution rows (gray until the Brainrot level gate,
  then light rarity fill + shiny title; lock until brains claim, with a
  confirm prompt); Epic stats live in the HP bar / plant cooldown
- Aura VFX (highest owned tier) ✅ Epic dark purple, Legendary gold, Mythic
  red-orange, Immortal dark red, GOD rainbow

## Architecture Notes

- **Data-driven only** — resolve effective stats + extra ability ids from
  registry + owned tiers
- Keep a single placement runtime shape (base `ability` + extras)
- Server owns eligibility, XP, spend, and grants
- See **`docs/EVOLUTIONS.md`** for the sheet tables

## Complete When

- At least one Brainrot earns XP, levels up, and persists that meter across
  rejoin (independent of campaign day).
- That unit’s **Epic** stat unlock + at least one **Legendary** active (or
  later tier) work in combat, with the matching aura.
- Remaining sheet units are data-authored even if tuning follows.
- Exploits (client-set level, free tier, fake XP) fail server validation.

---



# Milestone 20 — Retention Systems

**Status: 🔜 Planned**



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



# Milestone 21 — Boss Collection House

**Status: 🔜 Planned** (house shell ✅ now; collection / income later)

## Goal

Turn the plot **house** into a boss trophy room: defeating a new boss unlocks
it for display; displayed bosses generate **brains** used for the store (M18)
and evolutions (M19).

## Prerequisites

- Plot houses + authored Cottage pedestals (`HouseBuilder` / `HouseConfig`) ✅
  (runtime no longer spawns `BossDisplay` cylinders)
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
- Pedestal markers live in the authored Cottage; `CollectedBosses` folder is
  created at runtime for future trophies.
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
- **Brainrot mutations** — a layer separate from the Epic→God ladder: replace
  or add an unrelated ability, independent of Brainrot level. Evolutions
  shipped in **Milestone 19**; mutations are post-launch.
- Retention (7-day rewards, spinner, daily quests) → **Milestone 20**
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
