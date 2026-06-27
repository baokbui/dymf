# BVZ Zombies

Zombies are the enemies that cross the battlefield. All zombies derive from one
base implementation; special types are **data entries** plus optional abilities —
avoid duplicated AI (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Registry

Definitions live in `ReplicatedStorage.Shared.Zombies` (the registry).

API:

```lua
local Zombies = require(ReplicatedStorage.Shared.Zombies)
Zombies.get(id)     -- ZombieDefinition?  (nil if unknown)
Zombies.exists(id)  -- boolean
Zombies.getAll()    -- { [id]: ZombieDefinition }  (do not mutate)
```

---

## Definition schema

From `Shared.Types.ZombieDefinition`:

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

## Implemented zombies ✅ (data only)

### Basic Zombie

| health | speed | damage | attackSpeed |
| ------ | ----- | ------ | ----------- |
| 100    | 6     | 10     | 1/s         |

The Milestone 6 starter. Walks along the plot path toward the player and attacks
Brainrots in its way. Movement/pathfinding and combat are implemented in
Milestones 6–7; only the definition exists today.

---

## Service ownership

- `EnemyService` (server) 🔜 M6 — spawning, pathfinding, per-instance state. One
  base implementation for all types. Driven by `WaveService`; never advances
  waves itself.
- `CombatService` (server) 🔜 M7 — applies all damage/health and status effects
  (Slow, Freeze, Poison, Burn, Knockback).
- `WaveService` (server) 🔜 M8 — decides what spawns and when (see `WAVES.md`).

Zombies and their positions are **never saved** (see `SAVE_SYSTEM.md`).

---

## Planned roster (Milestone 11)

| Type    | Notes                                            |
| ------- | ------------------------------------------------ |
| Fast    | High speed, low health                           |
| Tank    | High health, slow                                |
| Shield  | Front damage reduction until shield breaks       |
| Flying  | Bypasses some ground defenses                    |
| Carrier | May spawn with Brainrots attached (GAME_DESIGN)  |
| Boss    | Appears on boss waves (`WaveConfig.BOSS_WAVE_INTERVAL`) |

Each is added as registry data plus ability handlers shared via the base zombie.
