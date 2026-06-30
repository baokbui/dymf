# BVM Monsters

Monsters are the enemies that cross the battlefield. All monsters derive from
one base implementation; special types (zombies, vampires, slimes,
frankensteins, ...) are **data entries** plus optional abilities — avoid
duplicated AI (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Registry

Definitions live in `ReplicatedStorage.Shared.Monsters` (the registry).

API:

```lua
local Monsters = require(ReplicatedStorage.Shared.Monsters)
Monsters.get(id)     -- MonsterDefinition?  (nil if unknown)
Monsters.exists(id)  -- boolean
Monsters.getAll()    -- { [id]: MonsterDefinition }  (do not mutate)
```

---

## Definition schema

From `Shared.Types.MonsterDefinition`:

| Field         | Type        | Meaning                       |
| ------------- | ----------- | ----------------------------- |
| `id`          | string      | Unique key                    |
| `name`        | string      | Display name                  |
| `health`      | number      | Starting health               |
| `speed`       | number      | Movement, studs per second    |
| `damage`      | number      | Damage per attack             |
| `attackSpeed` | number      | Attacks per second            |
| `abilities`   | `{string}`? | Optional special behavior ids |

---

## Implemented monsters ✅ (data only)

### Basic Monster

| id           | health | speed | damage | attackSpeed |
| ------------ | ------ | ----- | ------ | ----------- |
| `BasicMonster` | 100  | 6     | 10     | 1/s         |

The Milestone 6 starter. Walks along the plot path toward the player and attacks
Brainrots in its way. Movement/pathfinding and combat are implemented in
Milestones 6–7; only the definition exists today.

---

## Service ownership

- `EnemyService` (server) 🔜 M6 — spawning, pathfinding, per-instance state. One
  base implementation for all monster types. Driven by `LevelService`; never
  advances levels itself. Spawned monsters are tagged `Monster`
  (`Shared.Constants.TAGS.Monster`).
- `CombatService` (server) 🔜 M7 — applies all damage/health and status effects
  (Slow, Freeze, Poison, Burn, Knockback).
- `LevelService` (server) 🔜 M8 — decides what spawns and when by reading a
  level's authored spawn groups (see `LEVELS.md`).

Monsters and their positions are **never saved** (see `SAVE_SYSTEM.md`).

---

## Planned roster (Milestone 10)

A mix of behavioral archetypes and themed monster types. Each is added as
registry data plus ability handlers shared via the base monster.

| Type        | Notes                                            |
| ----------- | ------------------------------------------------ |
| Fast        | High speed, low health                           |
| Tank        | High health, slow                                |
| Shield      | Front damage reduction until shield breaks       |
| Flying      | Bypasses some ground defenses                    |
| Carrier     | May spawn with Brainrots attached (GAME_DESIGN)  |
| Boss        | Authored into specific campaign levels (see `LEVELS.md`) |
| Vampire     | Themed type — e.g. lifesteal on attack           |
| Slime       | Themed type — e.g. splits into smaller slimes    |
| Frankenstein| Themed type — e.g. high health bruiser           |
