# BVZ Economy

The single currency is **Coins**. Only the server controls currency — clients
send collection intent and display balances, never set them (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Coin sources

From `GAME_DESIGN.md`:

- Passive drops (every ~30 seconds)
- Money-producing Brainrots (e.g. Money Generator, see `BRAINROTS.md`)
- Completing waves
- Future achievements / events

---

## Configuration ✅

Values live in `Shared.Config.EconomyConfig` (frozen). Current tuning:

| Key                    | Value | Meaning                                  |
| ---------------------- | ----- | ---------------------------------------- |
| `STARTING_COINS`       | 50    | Balance for a new player                 |
| `PASSIVE_DROP_INTERVAL`| 30    | Seconds between passive drops            |
| `PASSIVE_DROP_AMOUNT`  | 25    | Coins per passive drop                   |
| `WAVE_COMPLETION_REWARD`| 50   | Base reward for finishing a wave         |
| `GROUND_COIN_LIFETIME` | 60    | Seconds an uncollected coin persists     |

Related Brainrot income: `MoneyGenerator.coinGeneration = 25` per cycle.

---

## Responsibilities (Milestone 3) 🔜

`CoinService` (server) will be the **sole authority** over currency:

- Hold each player's authoritative coin balance.
- Grant passive drops on `PASSIVE_DROP_INTERVAL`.
- Grant money-Brainrot income and wave-completion rewards
  (called by `WaveService`).
- Validate `CollectCoin` requests (ownership, distance, existence) before
  crediting; never trust a client-supplied amount.
- Push updates to clients via `CoinsUpdated` (see `NETWORKING.md`).
- Deduct costs on placement/merge (in cooperation with `BrainrotService` /
  `MergeService`).

---

## Persistence (see `SAVE_SYSTEM.md`)

- The coin **balance** is saved.
- **Ground coins** (uncollected pickups) are **not** saved.
