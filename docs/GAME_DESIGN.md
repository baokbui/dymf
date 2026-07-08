# Brainrots vs. Monsters (BVM)

## Overview

Brainrots vs. Monsters (BVM) is a 3D Roblox tower defense game inspired by Plants vs. Zombies.

Each player owns a separate battlefield where they defend against progressively harder monster levels by placing Brainrots on a grid. Players earn coins, purchase Brainrots, and progress through an increasingly difficult campaign of levels.

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

Press Start Level

↓

Level Begins

↓

Fight Monsters

↓

Level Complete

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
- House anchor (behind the grid, −X — for future house-breach defeat)
- Coin spawner marker (passive drop origin)
- Path / Decorations folders (populated in later milestones)
- Clear glass barriers (north/south between lanes; west edge of map; east side
  open toward the adjacent enemy lane)

`Workspace.EnemyPaths` holds the east-column enemy lanes (`EnemyLane1` … `EnemyLane6`).

Players cannot enter or interact with another player's plot.

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
- Server validates every placement

See `GRID.md` for implementation details.

---

# Currency

Currency: Coins

Coins are earned by:

- Passive drops (every ~30 seconds) ✅
- Coin-producing Brainrots (e.g. Ballerina Cappucina — 25 coins every 12s) ✅
- Completing levels 🔜 Milestone 8
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

Attack animations use a server-side pulse tween today; sound hooks exist via the
`BrainrotAction` remote (asset ids wired in `BrainrotConfig.SOUNDS`). Full rig
animations and final audio arrive in later polish milestones.

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

# Level System

BVM is a PvZ-style **campaign**: players progress through discrete, hand-authored
levels rather than endless scaling waves. (See `LEVELS.md` for the full design.)

Every level consists of:

Preparation

↓

Player Plants

↓

Start Level Button

↓

Level Begins (spawn groups / internal waves)

↓

Big Final Wave

↓

Level Complete (Victory) — or Defeat if the house is breached

↓

Rewards + Unlock Next Level

↓

Next Level Preparation

Within a level, monsters arrive in an ordered list of **spawn groups** (the
internal "waves") shown on a progress bar, building to a **big final wave**. A
level is won by clearing every group and lost if a monster reaches the house.

Each authored level controls its own difficulty through its data:

- Which monster types appear
- How many, and in how many groups
- Spawn timing (group delays + per-monster interval)
- Whether/where bosses and special enemies appear

Progression is **linear**: clearing a level unlocks the next; cleared levels can
be replayed via Level Select. There is no endless mode (yet).

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

The battlefield is persistent.

Everything player-owned should be saved.

Saved:

- Current Level
- Highest Unlocked Level
- Coins
- Player Health
- Planted Brainrots
- Brainrot Positions
- Brainrot Health
- Unlocks
- Upgrades
- Statistics
- Future progression systems

Not Saved:

- Active Monsters
- Monster Positions
- Active Projectiles
- Ground Coins
- Temporary Combat Effects
- Level Timers

If a player leaves during a level:

- Save the battlefield.
- Save the current level progression.
- End the active level.

When the player rejoins:

- Restore the battlefield.
- Restore coins.
- Restore all Brainrots.
- Restore progression.
- The current level starts over from the beginning.
- The player must press Start Level again.

---

# Reset Progress

A Reset Progress button exists inside Settings.

Reset deletes:

- Current Level
- Highest Unlocked Level
- Coins
- Battlefield
- Brainrots
- Unlocks
- Upgrades
- Statistics
- Saved Progress

Player returns to Level 1.

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

**Phase 5 🔜** — Roster expansion, VFX, audio polish, balancing, release (M11–18)