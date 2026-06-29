# BVZ Brainrots

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

| Field            | Type                  | Meaning                              |
| ---------------- | --------------------- | ------------------------------------ |
| `id`             | string                | Unique key (matches registry key)    |
| `name`           | string                | Display name                         |
| `cost`           | number                | Coin cost to place                   |
| `health`         | number                | Starting health                      |
| `damage`         | number                | Damage per attack                    |
| `attackSpeed`    | number                | Attacks per second (0 = non-attacker)|
| `range`          | number                | Attack range in studs                |
| `ability`        | string?               | Optional special ability id          |
| `coinGeneration` | number?               | Coins per cycle for money producers  |

---

## Implemented Brainrots ✅ (data only)

The two Milestone 5 starters are seeded as data. Their **behavior** (attacking,
coin generation) is implemented in Milestones 5–7; only the definitions exist
today.

### Shooter

| cost | health | damage | attackSpeed | range | ability |
| ---- | ------ | ------ | ----------- | ----- | ------- |
| 50   | 100    | 10     | 1/s         | 24    | —       |

Basic single-target attacker. Will fire at the nearest in-range zombie via
`CombatService` (Milestone 7).

### Money Generator

| cost | health | damage | attackSpeed | range | ability        | coinGeneration |
| ---- | ------ | ------ | ----------- | ----- | -------------- | -------------- |
| 75   | 80     | 0      | 0           | 0     | `GenerateCoins`| 25             |

Produces coins on a timer instead of attacking (handled by `CoinService` /
`BrainrotService` in Milestone 5).

---

## Service ownership

- `BrainrotService` (server) 🔜 M4–5 — placement, instance lifecycle, per-instance
  state on a plot. Reads definitions from the registry.
- `CombatService` (server) 🔜 M7 — the only system that applies damage/health.

Placement validation, cost deduction, and one-Brainrot-per-tile are all
server-authoritative (see `NETWORKING.md`).

---

## Planned roster (Milestone 11)

Target of at least 15 Brainrots. Candidates: Freeze, Fire, Cannon, Wall,
Electric, Poison, Sniper, Healer, Bomb, Support, Laser, Summoner.

Each is added purely as registry data plus, where needed, an ability handler.
