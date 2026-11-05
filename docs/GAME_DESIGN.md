# Brainrots vs. Monsters (BVM)

## Overview

Brainrots vs. Monsters (BVM) is a 3D Roblox tower defense game inspired by Plants vs. Zombies.

Each player owns a separate battlefield where they defend against progressively harder monster days by placing Brainrots on a grid. Players earn coins, purchase Brainrots, and progress through an increasingly difficult campaign of days.

Unlike traditional PvZ, player progress is persistent across sessions (✅ Milestone 9 — save/load).

---

# Core Gameplay Loop

Join Game

↓

Load Save

↓

Assign Plot

↓

Restore Battlefield

↓

Preparation Phase

↓

Plant Brainrots

↓

Press Start Day

↓

Day Begins

↓

Fight Monsters

↓

Day Complete

↓

Rewards

↓

Save Progress

↓

Preparation Phase

---

# Battlefield

The world is one shared grass baseplate. The playable area is split into two
side-by-side columns along X:

```
[ west: player plots (4 lanes) ] [ east: enemy spawn lanes (4 lanes) ]
```

Every player receives their own **isolated plot** in the west column (one plot
per shared-world lane, up to four concurrent players). The matching east lane is
that plot's **enemy spawn lane** — monsters stage there and enter the player's
grid from +X. There are no player grids in the east column.

Each player plot contains:

- Grid (5 × 9 tiles — see Grid System)
- Spawn point (player respawns here, facing the enemy)
- **House** ✅ — cottage in the house strip (−X); Toolbox model from
  `Assets.Houses` when present (see `HOUSE.md`); boss pedestals for Milestone 21
- House anchor (legacy marker on the plot base)
- Coin spawner marker (passive drop origin)
- Path / Decorations folders (populated in later milestones)

`Workspace.EnemyPaths` holds the east-column enemy lanes (`EnemyLane1` … `EnemyLane4`).
`Workspace.Maps.DarkForest` fills that east column with a dense, non-colliding
layered green forest (clear strip near the plots for entry). Seeded oak and
cypress clusters, small-to-tall trees, shrubs, and boulders soften
the woodland edge. The shared grass stays visible; overlapping canopies cast
the forest shade instead of a dark ground overlay. All scenery is static and non-queryable. Monsters spawn deeper in
the trees and walk west into player plots — that approach is setup time.

Players may **walk between plots to spectate**. They cannot plant, shovel, or
collect coins on another player's plot — the server validates ownership on every
intent.

---

# Grid System

Each plot's play area is a **5 rows × 9 columns** lawn (configured in
`Shared.Config.GridConfig`). Columns run toward the enemy (+X); rows run across
the lane (Z). Tile size is derived in `PlotConfig` so the grid fills the lane
depth.

Each tile tracks:

- Occupied
- Brainrot instance (if any)
- Grid position (`row`, `column`)

Rules

- One Brainrot per tile
- Cannot plant outside grid
- Cannot plant without enough coins
- Cannot plant while that Brainrot id is recharging (cost-scaled plant cooldown)
- Server validates every placement

See `GRID.md` for implementation details.

---

# Currency

**Coins** are the match currency (placement, passive drops). **Brains** are
progression currency (day-clear rewards, Progression Store spends).

Coins are earned by:

- Passive drops (every 25 seconds) ✅
- Coin-producing Brainrots (e.g. Ballerina Cappucina — 25 coins every 18s, max 10 on a plot) ✅
- Day purse: Day 1 opens with `STARTING_COINS` (125); later days start at 0; Rewind grants `REWIND_COINS` (200) ✅

Brains are earned on victory (day number × `BRAINS_PER_LEVEL_NUMBER`) plus a
stingy leftover-coin conversion at day end — see `ECONOMY.md`. Spend them at
the HUD **Upgrades** shop, the Brainrot stall beside your house, or on evolution
claims — see `STORE.md` / `EVOLUTIONS.md`. Speed and Magnet ranks persist in
`SaveData.upgrades`.

Only the server controls currency. Clients display balances and send intent.

Authoritative numbers: `docs/ECONOMY.md`.

---

# Brainrots

Brainrots are data-driven defensive units. Definitions live in
`Shared.Brainrots`; behavior is resolved from definition data and ability
handlers — never from giant if/elseif chains on names.

Each Brainrot defines (see `BRAINROTS.md` for the full schema):

- Name, cost
- Max health (HP pool for display) and health (hits the unit can take)
- Damage (per attack — e.g. 100 one-shots a 100-HP Basic Monster)
- Attack interval (seconds between actions)
- Range (tiles ahead toward +X, or full row)
- Ability (handler id — coin generation, melee, freeze, line bomb, wall, …)
- Optional coin generation, ability params, on-place triggers
- Visual tint (placement ghost + body)

**Launch roster (Milestone 5 ✅):** Ballerina Cappucina, Tung Tung Sahur,
Tralalero Tralala, Bombardino Crocodilo, Lirili Larila, Cappuccino Assassino,
Chimpanzini Bananini.

The current registry has **13** Brainrots: the launch seven plus Girafa Celestre,
Brr Brr Patapim, Orangutini Ananassini, La Vacca Saturno Saturnita, Blueberrinni
Octopusini, and Boneca Ambalabu. See `BRAINROTS.md` for unlocks and roles.
Nine have authored Epic→GOD tracks; the other four have no evolution rows yet.

Authored idle/attack clips play on the server through `BrainrotAnimation`;
non-animated units retain a ScaleTo pulse fallback. Ability SFX play locally via
`BrainrotAction` and `AudioController` / `AudioConfig` (M12/M17 ✅).

---

# Monsters

Monster stats include:

- Health
- Speed
- Damage
- Attack Speed
- Abilities

Monster types may include:

- Basic
- Fast
- Tank
- Boss
- Flying
- Shield
- Carrier
- Vampire
- Slime
- Frankenstein

All monsters derive from one base implementation; types are data entries plus
optional abilities (see `MONSTERS.md`).

Carrier monsters may spawn with Brainrots attached.

---

# Day System

BVM is a PvZ-style **campaign**: players progress through discrete, hand-authored
**days** rather than endless scaling waves. (See `LEVELS.md` for the full design.
Code still uses `LevelService` / `Shared.Levels`.)

Every day consists of:

Preparation

↓

Player Plants

↓

Start Day Button

↓

Day Begins (spawn groups / internal waves)

↓

Big Final Wave

↓

Day Complete (Victory) — or Defeat if the house is breached

↓

Rewards + Unlock Next Day

↓

Next Day Preparation

Within a day, monsters arrive in an ordered list of **spawn groups** (the
internal "waves") shown on a progress bar, building to a **big final wave**. A
day is won by clearing every group and lost when all five house hearts are gone.
A single breach costs one heart.

Each authored day controls its own difficulty through its data:

- Which monster types appear
- How many, and in how many groups
- Spawn timing (group delays + per-monster interval)
- Whether/where bosses and special enemies appear

Progression is **linear**: clearing a day unlocks the next; cleared days can
be replayed through the server `SelectLevel` intent; a player-facing Day Select
screen is not shipped. There is no endless mode.

The registry contains **50 numbered days**. Day 50 (Pharaoh Mummy) is the final
numbered encounter. After Day 40, a separate **Hidden Day** becomes
pending: Night, no fog or graves, manual Start Day. It has 35 Goblins, 4 Elites,
and Goblin King. Kill rewards total 100 brains if all die. Win or lose, the
player proceeds to Day 41; a loss restores the Day 40 lawn. See `LEVELS.md` and
`IMPLEMENTATION_NOTES.md` for scheduling caveats.

---

# Combat

Combat damage, projectiles, and status application route through CombatService.
Brainrot healing uses its registered handler. Monster regeneration/lifesteal
uses MonsterBehavior’s shared pending-heal queue; no public monster-heal API
exists in CombatService.

Brainrots never directly modify enemy health.

Enemies never directly modify Brainrot health.

Cross-unit damage and status requests route through CombatService. Runtime
owners apply registered handlers; monster self-heal uses the shared queue above.

Supported effects:

- Slow
- Freeze / Stun
- Weaken (Brainrot outgoing damage reduction)
- Poison
- Venom
- Burn
- Knockback

---

# Save System

Player **progression** is persistent across sessions. The **lawn** is persisted
as a **victory checkpoint** (not a live mid-day mirror).

Saved:

- Current Day
- Highest Unlocked Day
- Brains
- Player Health (progressive hearts)
- Planted Brainrots from the last victory / wipe (positions + HP)
- Unlocks
- Equipped loadout
- Upgrades
- Statistics
- Brainrot XP (victory-committed) and claimed evolution tiers
- Intro flags and optional Hidden Day pending flag
- Daily/weekly quests, first-time reward counts/dates/offers, tickets and claims
- Permanent achievement progress and claimed rewards
- Future progression systems

Not Saved:

- Coins (Day 1 → `STARTING_COINS`; later days → 0; Rewind → `REWIND_COINS`)
- Brainrots placed during an unfinished day (until that day is won)
- Active Monsters
- Monster Positions
- Active Projectiles
- Ground Coins
- Temporary Combat Effects
- Level Timers

If a player leaves mid-day or before Start Day:

- Save progression and the **committed** lawn (prior day’s plants).
- Discard mid-day placements; end the active day; clear combat runtimes.

When the player rejoins:

- Restore day, hearts, brains, unlocks, and the committed lawn.
- Coins via day purse (Day 1 → 125; later → 0).
- The player must press Start Day again.

Within a session, **victory keeps planted Brainrots** and commits them for
rejoin; coin purse is **125 on Day 1** and **0 after later days**; **Rewind**
after Game Over grants **200**; **defeat**
restores the last victory lawn on the **same day** (Game Over → Rewind);
**day select** clears the lawn. Brainrots idle outside **Active**. See
`LEVELS.md` / `SAVE_SYSTEM.md`.

---

# Reset Progress

A Reset Progress button exists inside Settings.

Reset deletes:

- Current Day
- Highest Unlocked Day
- Coins
- Battlefield
- Brainrots
- Unlocks
- Upgrades
- Statistics

Player returns to Day 1.

Reset requires two confirmations in Settings. It also clears brains, XP,
claimed evolutions, intro flags, pending Hidden Day state, quests, login rewards
and achievements. Daily Challenge and Daily Spin receipts survive the reset.

---

# Retention features (Milestone 20) ✅ Implemented

Players can open Daily Quests from the bottom-left Menu. Collect 150 coins,
defeat 15 monsters, and clear one numbered campaign day; finishing all three
also unlocks a bonus. Rewards total 6, 12, or 18 brains based on the highest
unlocked day when assigned. Quests reset at UTC midnight. Actual pickup/kill
progress survives failed days; rewards must be claimed and each pays once.
The Quests section also has a Weekly Quests tab: 1,500 coins, 150 monsters,
and seven numbered clears, resetting Monday at 00:00 UTC. First-time Rewards
ends after seven claims on distinct UTC dates, offering brains, Speed/Magnet
levels and a free store Brainrot ticket on step seven. No recurring weekly
login reward follows. The Campaign tab offers ten one-time milestone claims
from Day 5 through Day 50. The Achievements section tracks ten permanent
objectives and shows a next-goal hint for campaign unlocks or evolutions.
Forest Rush unlocks at Day 10 and offers a first-clear reward each UTC day.
The Daily Spinner offers one free spin per UTC day after clearing Day 2.
Release verification remains open in Step 7. See `RETENTION.md`.

---

# Folder Structure

Source lives under `src/` and syncs via Rojo. **Authoritative layout, services,
and lifecycle:** `docs/ARCHITECTURE.md`. Do not treat this file as the folder
map — it drifted when milestones landed.

---

# Development Order

See `ROADMAP.md` for milestone status. Summary:

**Phase 1 ✅** — Rojo, folder structure, plots, grid, coins, placement, shop

**Phase 2 ✅** — Brainrots (M5), monsters (M6), combat (M7), days (M8), save (M9)

**Phase 3 ✅** — Campaign content, VFX, audio, UI polish, balance, models,
animations, weather, graves (M10–17)

**Phase 4 ✅** — Progression Store (M18): Brainrot stall + HUD Upgrades, brains spends,
Speed upgrades

**Phase 5** — Brainrot leveling + evolutions (M19 ✅); retention (M20 🛠 in progress) and
house boss collection (M21 🔜).
