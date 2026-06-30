# Brainrots vs. Monsters (BVM)

## Overview

Brainrots vs. Monsters (BVM) is a 3D Roblox tower defense game inspired by Plants vs. Zombies.

Each player owns a separate battlefield where they defend against progressively harder monster levels by placing Brainrots on a grid. Players earn coins, purchase Brainrots, combine them into stronger variants, and progress through an increasingly difficult campaign of levels.

Unlike traditional PvZ, player progress is persistent across sessions.

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

Every player receives their own isolated plot.

Each plot contains:

- Grid
- Monster Path
- Spawn Point
- Coin Spawner
- Decorations
- Invisible Barriers

Players cannot enter or interact with another player's plot.

---

# Grid System

Each tile contains:

- Occupied
- Brainrot Instance
- Grid Position

Rules

- One Brainrot per tile
- Cannot plant outside grid
- Cannot plant without enough coins
- Server validates every placement

---

# Currency

Currency: Coins

Coins are earned by:

- Passive drops (every ~30 seconds)
- Money-producing Brainrots
- Completing levels
- Future achievements/events

Only the server controls currency.

---

# Brainrots

Each Brainrot defines:

- Name
- Cost
- Health
- Damage
- Attack Speed
- Range
- Ability
- Animations
- Sounds

Brainrots are data-driven.

Behavior should never be hardcoded into giant if-statements.

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

ReplicatedStorage

    Shared
        Config
        Constants
        Types
        Utilities
        Brainrots
        Monsters
        Levels
        Remotes

ServerScriptService

    Services
        PlotService
        LevelService
        CombatService
        CoinService
        EnemyService
        BrainrotService
        SaveService

StarterPlayer

    StarterPlayerScripts

        Controllers
            UIController
            PlacementController
            CameraController
            InputController

StarterGui

    MainUI
        Shop
        Coins
        LevelUI
        Settings

Workspace

    Plots
    EnemyPaths
    Maps

---

# Development Order

Phase 1

- Rojo
- Folder structure
- Plot system
- Placement
- Coin system

Phase 2

- Basic Brainrot
- Basic Monster
- Combat
- Levels

Phase 3

- Shop UI
- Save system
- Progression

Phase 4

- Bosses
- Special enemies

Phase 5

- Effects
- Animations
- Audio
- Polish
- Balancing