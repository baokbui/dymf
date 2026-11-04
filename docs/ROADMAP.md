# Brainrots vs. Monsters (BVM) Roadmap

## Purpose

Completion markers describe delivered scope, not a guarantee of zero bugs or
full coverage for future units. Current caveats live in `IMPLEMENTATION_NOTES.md`.
M0–19 are delivered; M20 is in progress; M21–25 remain planned. Days 1–50 and the manual Hidden Day
after 40 are present. Day Select has a server API but no shipped UI.

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
- Maintain `AGENTS.md` (canonical rules) + `.cursorrules` compatibility pointer
- Create documentation
- Create project folder structure
- Create empty services
- Create shared configuration modules



## Complete When

- Project syncs correctly between local source and Roblox Studio via Rojo.
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
- Grid-based movement (no PathfindingService)
- Health
- Damage
- Death
- Animations



## Current registry

- Zombie, Vampire, Werewolf, Skeleton, Goblin, Spider, Small Mummy, Scorpion
- Bosses: Goblin Elite, Necromancer, Goblin King, Queen Spider, Duke Vampire, Pharaoh Mummy
- Necromancer is a prototype, not in authored days; lane-change handler is a stub.



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
- Losing (all five house hearts gone) lets the player retry the same level.
- Hidden Day after Day 40 is manually started; win/loss proceeds to Day 41.

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
- Statistics, Brainrot XP checkpoints, claimed evolution tiers, intro flags,
  optional Hidden Day pending flag (introduced in v7; current schema v11)



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
- Reward System ✅ persistent Continue popup: day brains + leftover conversion;
  Hidden Day uses kill brains on either outcome
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

Authored templates are used by `BrainrotModel` for shipped Brainrots.
Colored Part placeholders remain only as missing-asset fallbacks.

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
  (still display-only on the client) ✅ ghost clones template; shop uses previews on High/Low and swatches on Off
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

Campaign monsters use authored templates through `MonsterModel`. Colored Parts
remain as missing-asset fallbacks.

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
(`AGENTS.md` presentation layer).

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
  (five units: Girafa, Orangutini, La Vacca, Blueberrinni, Boneca;
  Girafa is also free on reach Day 25). Starter roster and
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
  Cappuccino, Lirili, Orangutini, La Vacca, and Boneca
  (Girafa / Patapim / Blueberrinni / Bombardino TBD)

## Tasks

- Shared schema: Brainrot XP map live (`brainrotXp`); evolution rows
  (`brainrotId` + rarity, ability ids, **Epic `stats`**, **Legendary extras**,
  **Mythic passives**) ✅; **Immortal passives** ✅; GOD ultimates: Tung
  Tung Sahur (`SahurWrath`), Ballerina (`Jackpot`), Chimpanzini
  (`PrimalRetaliation`), Lirili Glacial Dominion, Cappuccino
  (`ShadowRequiem`), Tralalero (`AbyssalTorrent`), Orangutini (`PineappleExpress`),
  Boneca (Last Laugh), and La Vacca (Black Hole) ✅
- XP grant rules ✅ — last-hit species for normal kills (`BubbleTrap` /
  `BubbleBarrage` / `MeleeBat` / `TileTrap` skipped); boss XP split evenly across every living plant; support
  jobs (`COIN_XP` / `SOAK_XP` / `FREEZE_XP` / `BUBBLE_XP` every 2 landed
  bubbles / `MELEE_XP` every 3 connecting hits / TileTrap every 2 headbutts)
- Compose Epic stats onto the common placement runtime ✅
  (`Evolutions.applyStats` — no name branches). Legendary extras ✅
  (`claimedExtras` + `tickExtras`). Mythic passives ✅
- Persist XP via `SaveService` (v5) and claimed tiers (v6 `evolutions`);
  Epic combat stats ✅; Legendary combat extras ✅; Mythic passives ✅;
  Immortal passives ✅; GOD ultimates: Tung Tung (`SahurWrath`), Ballerina
  (`Jackpot`), Chimpanzini (`PrimalRetaliation`), Lirili Glacial Dominion,
  Cappuccino (`ShadowRequiem`), Tralalero (`AbyssalTorrent`), Orangutini (`PineappleExpress`),
  Boneca (Last Laugh), and La Vacca (Black Hole) ✅
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

**Status: 🛠 In progress — Steps 0–4 complete; quests, login rewards, achievements and next-goal display implemented**

## Goal

Give players achievable goals for a session, a reason to return, and longer-term
progress through the existing campaign and Brainrot roster. Implement the steps
below **one at a time, in order**. Check an item only after its behavior is
implemented and verified. Keep partial features marked in progress; do not mark
the whole milestone complete until its acceptance checks pass.

## Step 0 — Fix the campaign spawn handoff

- [x] Keep the final spawn of each group attached to its authored species and row.
- [x] Verify mixed-species boundaries, single-monster groups, boss timing, and
  the final group; confirm a rejected duplicate boss cannot silently break progress.
- [x] Preserve Hidden Day's 35 Goblins, 4 Elites, and 1 King, plus its manual start.
- [x] Update `LEVELS.md` / `IMPLEMENTATION_NOTES.md` after verification.

**Verified:** the Day 13 bug was reproduced, then 54 isolated scheduler scenarios
passed (768 spawn events, 53 big-wave warnings). Service-handler checks covered
rejected duplicates, live-enemy victory gating, and Hidden Day manual start.
Rojo build passes. This is a prerequisite bug fix, not a new reward feature.
Full gameplay/multiplayer playtests remain in Step 7.

## Step 1 — Define reward rules and shared infrastructure

- [x] Set a combined brains budget for quests, login rewards, achievements,
  challenges, and free spins against existing day rewards and shop/evolution costs.
- [x] Author reward/objective definitions in shared configuration; decide the
  initial reward catalog before implementing claims.
- [x] Define server UTC dates and provide a pure countdown helper; UI wiring is Step 2.
  Login reward days mean real-world claim dates, not campaign Day N.
- [x] Define versioned persistence, migration defaults, and reconnect-safe,
  repeat-safe claim transactions through SaveService and the existing currency APIs.
- [x] Define server gameplay events for objective progress, plus validated claim
  remotes. Avoid scanning every plant/monster each frame.
- [x] Define analytics events for eligibility, progress, claim success, and rejection.
  Add instrumentation with each feature below.
- [x] Document an isolated test setup and verify pure helpers without player data;
  preserve developer cheat preferences for gameplay/economy tests.

**Verified:** `RetentionConfig`, `RetentionTime`, and `Types.Retention` are
implemented. `RETENTION.md` defines budgets, expiry/claim rules, migration and
durable SaveService requirements, event contracts, and service responsibilities.
133 isolated Luau checks and Rojo build passed. Claims, migrations, server
subscriptions/remotes, analytics emission, and UI were deferred to Step 2 and
are now implemented for daily quests.

## Step 2 — Daily quests

- [x] Assign three daily quests using only mechanics/Brainrots available to the player.
- [x] Include varied objectives such as collecting coins, defeating monsters, or
  clearing a day; avoid requiring a purchase or unavailable content.
- [x] Add a once-per-day completion bonus for finishing all three.
- [x] Track progress server-side; persist assigned quests, progress, date, and claims.
- [x] Add a compact quest UI with progress, reward, claim state, and reset timer.
- [x] Verify midnight rollover, reconnects, repeated claims, failed days, and
  eligibility for new versus advanced players.
- [x] Record quest participation, completion, and rewards granted.

**Done when:** quests refresh correctly and each eligible reward pays exactly
once, including after reconnecting.

**Verified:** 32 versioned regression assertions plus isolated service/save/UI
checks passed. Coverage includes UTC rollover, reconnects, duplicate claims,
Hidden Day filtering, failed-day credit, queued purchases/saves, disconnects
during a claim, and lost write responses. Save schema v8 commits claim flags
and balances together under a guarded session writer. The UI renders all four
rows and server claim states. Tests use in-memory storage; complete visual and
four-player QA, real DataStore fault testing, and live analytics ingestion remain
Step 7 acceptance checks. See `RETENTION.md`.

## Step 3 — First-time rewards and weekly quests

- [x] Add a finite seven-day first-time track: brains, Speed/Magnet upgrade
  levels, and a free Brainrot-store ticket on Day 7.
- [x] Advance once per distinct eligible UTC date; missed dates preserve progress.
- [x] End permanently after seven claims; remove recurring weekly login rewards.
- [x] Preserve existing paid steps; give legacy seven-brain-reward completions
  one final ticket catch-up without repeating the migration.
- [x] Commit mixed rewards and ticket redemption atomically through SaveService.
- [x] Split Quests into Daily Quests and Weekly Quests tabs, with independent
  progress/claims and Monday 00:00 UTC weekly resets.
- [x] Verify dates, duplicates, migration, maxed upgrade fallback, ticket purchases
  and queued save/leave merges with isolated fixtures.

**Done when:** each first-time reward pays once, the final ticket buys one
unowned store Brainrot for free, and weekly quests reset/pay independently.
Live battle/device/cloud verification remains Step 7. See `RETENTION.md` for
catalogs, budgets and the schema-v11 transaction rules.

## Step 4 — Achievements and the next-goal display

- [x] Add permanent milestones: first boss defeat, first Epic evolution, first
  perfect defense, and Brainrot ownership milestones.
- [x] Define objective semantics precisely (e.g. perfect defense means no house
  breaches during that successful encounter).
- [x] Persist progress/claims; show rewards and completion state in one clear UI.
- [x] Show one relevant next goal: next campaign unlock, evolution level gate,
  or brains needed to claim an eligible evolution.
- [x] Update that goal from authoritative state without adding HUD clutter.
- [x] Verify catch-up for existing saves, unavailable goals, max-level players,
  and repeat-safe achievement claims.
- [x] Record milestone completion and next-goal engagement where measurable
  (instrumented; live ingestion/cohort review remains Step 7).

**Done when:** both new and existing players receive accurate, reachable goals
and cannot claim a permanent achievement twice.

**Verified:** 32 achievement/goal assertions join 32 quest/storage and 55 login
checks (119 total). Isolated SaveService/RetentionService tests cover v7/v8/v9
migration, concurrent saves/purchases/progress, repeated claims, permanent
claims across midnight, disconnects during achievement commits, attempt breach
tracking, Hidden/Challenge filtering, two-player isolation and goal-view validation.
The shared Menu has an Achievements section with five rows and one next goal,
using the restored UI style and transparent dismissal layer. Ownership/Epic
catch-up is verified; boss/perfect history begins with new events. Schema v10
stores permanent progress/claims. Full battle/device/multiplayer and live
analytics remain Step 7 checks; Step 5 is next. Menu also hosts Inventory, Index,
Upgrades, Settings, Statistics and Quests behind one HUD entry. First-time
Rewards has its own temporary gift HUD entry, hidden after all seven claims.

## Step 5 — Daily challenge encounter

- [ ] Author a separate optional challenge with a readable modifier and difficulty.
- [ ] Use a separate challenge lawn/state; safely preserve and restore the player's
  campaign day, hearts, pending Hidden Day, lawn checkpoint, and coin rules.
- [ ] Define challenge XP, quest/achievement credit, and retry rules explicitly
  before wiring it into campaign services.
- [ ] Give a fixed first-clear reward per UTC day; permit free retries afterward.
- [ ] Handle victory, defeat, leaving, reconnecting, and daily rollover without
  replacing or corrupting campaign progress.
- [ ] Add entry/result UI and record attempts, clears, retries, and rewards.

**Done when:** a challenge can be played and retried independently of campaign
progress, with only one first-clear payout per eligible day.

## Step 6 — Free daily spinner

- [ ] Author a small reward pool with visible odds and the agreed economy budget.
- [ ] Grant one free spin per eligible UTC day; paid spins are outside this scope.
- [ ] Choose and record the outcome on the server; the client animates that outcome.
- [ ] Persist spin eligibility/outcome so disconnects cannot lose a reward or reroll it.
- [ ] Add UI, claim feedback, and analytics.
- [ ] Verify repeated requests, leaving mid-animation, reconnecting, and rollover.

**Done when:** each daily spin produces one authoritative reward regardless of
client animation or connection state.

## Step 7 — Integration, balance, and release checks

- [ ] Test migration from current saves and reconnect/restart behavior for all tracks.
- [ ] Test invalid remote arguments, spam, simultaneous claims, and duplicate payouts.
- [ ] Test interaction with victory/defeat, Hidden Day, Reset Progress, and upgrades.
- [ ] Verify mobile/desktop layouts and four-player server isolation/performance.
- [ ] Review total brains income against shop/evolution prices; adjust config as needed.
- [ ] Verify analytics and compare D1/D7/D30 cohorts once enough live data exists;
  do not claim a retention improvement from implementation alone.
- [ ] Update NETWORKING, SAVE_SYSTEM, ECONOMY, UI, AUDIO, ARCHITECTURE, and relevant
  gameplay docs as each feature ships; update AGENTS.md if an invariant changes.

**Done when:** the features pass functional/integration checks, their rewards
fit the economy, and observability is ready. Longer-term retention evaluation
continues after release as cohorts mature.

## Architecture constraints

RetentionService and durable daily quest claims implement the shared boundary;
challenge lifecycle and the remaining reward tracks are still planned:

- Dedicated server services/modules own retention eligibility, objectives,
  challenge lifecycle, and claims; use the existing service bootstrap.
- Only SaveService accesses DataStore. Bump/migrate the schema when adding fields.
- Reward grants use ProgressService / CoinService; clients never choose balances,
  random outcomes, timestamps, progress, or claim eligibility.
- Challenge progression must explicitly distinguish itself from campaign
  LevelService progression; no other service advances campaign days.
- UI stays under client Controllers and only presents state/sends intent.
- Seasonal/live events, trading, rebirths, and paid spins are deferred.
  Offline house income remains Milestone 21.

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

**Status: 🔜 Planned**



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

**Status: 🔜 Planned**



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

**Status: 🔜 Planned**



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

**Status: 🔜 Planned**



## Continue Development

- **New Brainrots** — expand the current 13-unit roster (registry +
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
