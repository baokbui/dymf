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
[ west: player plots (6 lanes) ] [ east: enemy spawn lanes (6 lanes) ]
```

Every player receives their own **isolated plot** in the west column (one lane
per row, up to six concurrent players). The matching row in the east column is
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

`Workspace.EnemyPaths` holds the east-column enemy lanes (`EnemyLane1` … `EnemyLane6`).
`Workspace.Maps.DarkForest` fills that east column with a dense, non-colliding
dark forest (clear strip near the plots for entry). Monsters spawn deeper in
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

Currency: Coins

Coins are earned by:

- Passive drops (every ~30 seconds) ✅
- Coin-producing Brainrots (e.g. Ballerina Cappucina — 25 coins every 18s) ✅
- Completing days 🔜 Milestone 8
- Future achievements/events

Only the server controls currency.

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

**Current roster (Milestone 5 ✅):** Ballerina Cappucina, Tung Tung Sahur,
Tralalero Tralala, Bombardino Crocodilo, Lirili Larila, Cappuccino Assassino,
Chimpanzini Bananini.

Attack animations use a server-side pulse tween today; ability SFX play via the
`BrainrotAction` remote through `AudioController` / `AudioConfig` (Milestone 12 ✅).
Full character rig animations arrive in later polish milestones.

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
day is won by clearing every group and lost if a monster reaches the house.

Each authored day controls its own difficulty through its data:

- Which monster types appear
- How many, and in how many groups
- Spawn timing (group delays + per-monster interval)
- Whether/where bosses and special enemies appear

Progression is **linear**: clearing a day unlocks the next; cleared days can
be replayed via Day Select. There is no endless mode (yet).

---

# Combat

Combat is handled entirely by CombatService.

Brainrots never directly modify enemy health.

Enemies never directly modify Brainrot health.

Everything routes through CombatService.

Supported effects:

- Slow
- Freeze
- Poison
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
- Future progression systems

Not Saved:

- Coins (Day 1 → `STARTING_COINS`; later days → 0)
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
rejoin; coin purse is **125 on Day 1** and **0 after later days**; **defeat**
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
- Saved Progress

Player returns to Day 1.

Reset should require confirmation.

---

# Folder Structure

Source lives under `src/` and syncs via Rojo. See `ARCHITECTURE.md` for the
full mapping and lifecycle.

```
ReplicatedStorage/Shared/
    Config/        Grid, Economy, Level, Plot, Brainrot + aggregator
    Constants/     save version, tags, phases, folder names
    Types/         shared Luau types
    Utilities/     Logger, GridUtil
    Brainrots/     data-driven Brainrot registry
    Monsters/      data-driven Monster registry
    Levels/        data-driven campaign level registry
    Remotes/       single network boundary

ServerScriptService/Server/
    Services/
        PlotService/      plots + enemy-spawn lanes
        GridService/      tile grid + occupancy
        CoinService/      currency + ground coins
        BrainrotService/  placement, lifecycle, behavior
        CombatService/    damage + status (monsters stubbed until M6–7)
        EnemyService/     🔜 Milestone 6
        LevelService/     🔜 Milestone 8
        SaveService/      🔜 Milestone 9

StarterPlayerScripts/Client/Controllers/
    UIController/         Shop, coin counter
    PlacementController/  selection, ghost, place/remove intent
    GridController/       hover highlight
    CoinController/       ground-coin pickup intent
    BrainrotController/   action sound feedback
    InputController/      primary/secondary intent
    CameraController/     default third-person

StarterGui/MainUI/
    Shop, Coins, LevelUI, Settings

Workspace/
    Plots/        player plot models (runtime)
    EnemyPaths/   enemy-spawn lanes (runtime)
    Maps/
```

---

# Development Order

See `ROADMAP.md` for milestone status. Summary:

**Phase 1 ✅** — Rojo, folder structure, plots, grid, coins, placement, shop

**Phase 2 (in progress)** — Brainrot framework ✅ (M5); monsters ✅ (M6); combat ✅
(M7); levels ✅ (M8); save 🔜 (M9)

**Phase 3 🔜** — Save system, progression (M9)

**Phase 4 🔜** — Additional monsters & bosses (M10)

**Phase 5 🔜** — VFX, audio, UI polish, balancing, roster expansion, release (M11–18)