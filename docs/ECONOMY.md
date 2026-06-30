# BVM Economy

The single currency is **Coins**. Only the server controls currency — clients
send collection intent and display balances, never set them (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Coin sources

From `GAME_DESIGN.md`:

- Passive drops (every ~30 seconds)
- Money-producing Brainrots (e.g. Money Generator, see `BRAINROTS.md`)
- Completing levels
- Future achievements / events

---

## Configuration ✅

Values live in `Shared.Config.EconomyConfig` (frozen). Current tuning:

| Key                    | Value | Meaning                                  |
| ---------------------- | ----- | ---------------------------------------- |
| `STARTING_COINS`       | 50    | Balance for a new player                 |
| `PASSIVE_DROP_INTERVAL`| 30    | Seconds between passive drops            |
| `PASSIVE_DROP_AMOUNT`  | 25    | Coins per passive drop                   |
| `LEVEL_COMPLETION_REWARD`| 50  | Base reward for finishing a level        |
| `GROUND_COIN_LIFETIME` | 60    | Seconds an uncollected coin persists     |
| `COIN_COLLECT_RADIUS`  | 16    | Max studs from a coin to collect it      |

Related Brainrot income: `MoneyGenerator.coinGeneration = 25` per cycle.

---

## Responsibilities (Milestone 3) ✅

`CoinService` (server) is the **sole authority** over currency:

- Holds each player's authoritative coin balance (starts at `STARTING_COINS`;
  in-memory until `SaveService` adds persistence).
- Grants passive drops on `PASSIVE_DROP_INTERVAL` as **collectible ground
  coins** (one per active player per interval), each worth
  `PASSIVE_DROP_AMOUNT`, spawned at a random spot on the player's grid via the
  plot's `CoinSpawner` marker. Uncollected coins despawn after
  `GROUND_COIN_LIFETIME`.
- Validates `CollectCoin` intents — ownership, existence, and distance (against
  the authoritative `HumanoidRootPart` position, within `COIN_COLLECT_RADIUS`) —
  before crediting. The coin's value is server-side; client-supplied amounts are
  never trusted.
- Pushes balances to clients via `CoinsUpdated`, and answers the initial
  `RequestState` pull with `{ coins }` (see `NETWORKING.md`).

### Public API (for other services)

| Function                          | Use                                          |
| --------------------------------- | -------------------------------------------- |
| `getBalance(player) -> number`    | read a balance (placement pre-check, M4)     |
| `addCoins(player, amount)`        | credit rewards/income (e.g. level rewards M8) |
| `trySpend(player, amount) -> bool`| charge costs; false if unaffordable. Brainrot placement (M4) ✅ |

Spending is now live: `BrainrotService` (M4) pre-checks `getBalance` and charges
with `trySpend` when reserving a tile. **Digging up a Brainrot is not refunded**
— the coins spent placing it are lost (see `BRAINROTS.md` / `NETWORKING.md`).

### Implementation

`CoinService/` is split into the service (`init.luau`) and `GroundCoin.luau`
(builds a single coin part, tagged `Coin` with `CoinId`/`OwnerUserId`/`Value`
attributes). The client `CoinController` detects the local player touching their
own coin and fires the `CollectCoin` intent; `UIController` renders the balance.

---

## Persistence (see `SAVE_SYSTEM.md`)

- The coin **balance** is saved.
- **Ground coins** (uncollected pickups) are **not** saved.
