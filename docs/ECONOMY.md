# BVM Economy

The single currency is **Coins**. Only the server controls currency — clients
send collection intent and display balances, never set them (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Coin sources

From `GAME_DESIGN.md`:

- Passive drops (every ~30 seconds) ✅
- Coin-producing Brainrots (e.g. **Ballerina Cappucina** — see `BRAINROTS.md`) ✅
- Completing a level ✅ Milestone 8 — **resets** balance to `STARTING_COINS` (PvZ-style; no carry-over)
- Future achievements / events

---

## Configuration ✅

Values live in `Shared.Config.EconomyConfig` (frozen). Current tuning:

| Key                    | Value | Meaning                                  |
| ---------------------- | ----- | ---------------------------------------- |
| `STARTING_COINS`       | 125   | Balance for a new player (Ballerina + Tung Tung) |
| `PASSIVE_DROP_INTERVAL`| 30    | Seconds between passive drops            |
| `PASSIVE_DROP_AMOUNT`  | 25    | Coins per passive drop                   |
| `LEVEL_COMPLETION_REWARD`| 50  | Reserved for future bonus rewards (victory resets to `STARTING_COINS`) |
| `GROUND_COIN_LIFETIME` | 60    | Seconds an uncollected coin persists     |
| `COIN_COLLECT_RADIUS`  | 16    | Max studs from a coin to collect it      |

Related Brainrot income: `BallerinaCappucina.coinGeneration = 25` every 12s on a
**random grid tile** (via `GenerateCoins` → `CoinService.dropRandomCoinForOwner`).

---

## Responsibilities (Milestone 3) ✅

`CoinService` (server) is the **sole authority** over currency:

- Holds each player's authoritative coin balance (starts at `STARTING_COINS`;
  persisted by `SaveService` in Milestone 9).
- Grants passive drops on `PASSIVE_DROP_INTERVAL` as **collectible ground
  coins** (one per active player per interval, **only while the level is
  `Active`**), each worth
  `PASSIVE_DROP_AMOUNT`, spawned on a **random grid tile** via
  `GridService.getRandomWorldPosition`. Uncollected coins despawn after
  `GROUND_COIN_LIFETIME`.
- Validates `CollectCoin` intents — ownership, existence, and distance (against
  the authoritative `HumanoidRootPart` position, within `COIN_COLLECT_RADIUS`) —
  before crediting. The coin's value is server-side; client-supplied amounts are
  never trusted.
- Pushes balances to clients via `CoinsUpdated`. The initial `RequestState` pull
  is answered by `LevelService` with `{ coins, level }` (see `NETWORKING.md`).

### Public API (for other services)

| Function                          | Use                                          |
| --------------------------------- | -------------------------------------------- |
| `getBalance(player) -> number`    | read a balance (placement pre-check, M4)     |
| `resetBalance(player)`            | set balance to `STARTING_COINS` (level clear) ✅ |
| `clearPlot(plotModel)`            | despawn all ground coins on a plot ✅          |
| `addCoins(player, amount)`        | credit rewards/income                        |
| `trySpend(player, amount) -> bool`| charge costs; false if unaffordable (M4) ✅  |
| `dropCoinForOwner(userId, plotModel, gridPosition, amount)` | spawn a coin on a specific grid tile ✅ |
| `dropRandomCoinForOwner(userId, plotModel, amount)` | spawn a coin on a random grid tile (producers) ✅ |

Spending is now live: `BrainrotService` (M4) pre-checks `getBalance` and charges
with `trySpend` when reserving a tile. **Digging up a Brainrot is not refunded**
— the coins spent placing it are lost (see `BRAINROTS.md` / `NETWORKING.md`).

### Implementation

`CoinService/` is split into the service (`init.luau`) and `GroundCoin.luau`
(builds a single coin part, tagged `Coin` with `CoinId`/`OwnerUserId`/`Value`
attributes). The client `CoinController` detects the local player touching their
own coin and fires the `CollectCoin` intent; `UIController` renders the balance.
Brainrot producers call `dropCoinForOwner` to spawn coins at the unit's tile
(Milestone 5).

---

## Persistence (see `SAVE_SYSTEM.md`)

- The coin **balance** is saved.
- **Ground coins** (uncollected pickups) are **not** saved.
