# BVZ Wave System

The wave system is the core gameplay loop. **`WaveService` is the only system
that advances waves** (`.cursorrules`); no other service starts waves, spawns
wave enemies, or grants wave rewards.

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Loop

From `GAME_DESIGN.md`:

```
Preparation ─► Player plants ─► Start Wave ─► Wave begins
   ▲                                              │
   └────────── Rewards ◄── Wave complete ◄────────┘
```

Phases (see `Shared.Constants.PHASE`): `Preparation`, `Countdown`, `Active`,
`Complete`.

---

## Configuration ✅

Values live in `Shared.Config.WaveConfig` (frozen). Current tuning:

| Key                     | Value | Meaning                                    |
| ----------------------- | ----- | ------------------------------------------ |
| `PREPARATION_TIME`      | 30    | Seconds to plant before a wave             |
| `COUNTDOWN_TIME`        | 3     | Seconds after pressing Start Wave          |
| `STARTING_PLAYER_HEALTH`| 100   | Player base health                         |
| `BASE_ENEMY_COUNT`      | 5     | Enemies in wave 1                          |
| `BOSS_WAVE_INTERVAL`    | 10    | A boss appears every Nth wave              |

### Difficulty scaling (`WaveConfig.SCALING`)

Multiplicative per wave number:

| Stat        | Factor |
| ----------- | ------ |
| enemyCount  | 1.15   |
| enemyHealth | 1.10   |
| enemySpeed  | 1.02   |
| enemyDamage | 1.08   |

These are the knobs Milestone 16 (Balancing) will tune.

---

## Responsibilities (Milestone 8) 🔜

`WaveService` will own:

- Preparation phase + countdown timing.
- Handling the `StartWave` request (validated server-side).
- Orchestrating spawns by driving `EnemyService` (it decides *what* and *when*;
  `EnemyService` handles *how* enemies move/fight).
- Detecting wave completion and granting rewards via `CoinService`
  (`EconomyConfig.WAVE_COMPLETION_REWARD`, see `ECONOMY.md`).
- Applying difficulty scaling from `WaveConfig`.
- Broadcasting state via the `WaveStateChanged` remote (see `NETWORKING.md`).

---

## Interaction with save (see `SAVE_SYSTEM.md`)

- The **current wave number** is persisted.
- Active zombies, projectiles, and wave timers are **not** persisted.
- If a player leaves mid-wave: save the battlefield + wave number, end the wave.
- On rejoin: restore the battlefield, then the saved wave **restarts from the
  beginning** and the player must press Start Wave again.
