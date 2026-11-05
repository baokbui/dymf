# BVM Economy

The single **match** currency is **Coins**. **Brains** are a separate soft
currency for progression unlocks (Milestone 13 grants; Milestone 18 store;
Milestone 19 Brainrot leveling / evolution tiers; Milestone 21 house boss income).
Only the server controls currency — clients send collection intent and display
balances, never set them (`AGENTS.md`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Coin sources

From `GAME_DESIGN.md`:

- Passive drops (every ~25 seconds) ✅
- Coin-producing Brainrots (e.g. **Ballerina Cappucina** — see `BRAINROTS.md`) ✅
- Day purse ✅ Milestone 8 — after advancing past Day 1, purse resets to **0**;
  Day 1 gets `STARTING_COINS` (125). Leftover **pocket** coins convert to
  brains first (`COINS_PER_LEFTOVER_BRAIN`), then the
  purse applies. Defeat uses the same conversion + day-purse rules for the
  failed day. **Rewind** then sets the retry purse to `REWIND_COINS` (200).
  Victory keeps plants; coin purse does not carry between days.
  The **Hidden Day** after Day 40 pays kill brains (Goblin 1, Goblin Elite 10,
  Goblin King 25) on that same reward screen, then Day 41's purse applies.
- Progression rewards are listed separately below.

---

## Milestone 20 brains budget

The table assumes all available quest rewards are claimed, weekly rewards are
averaged over seven days, and the player takes the free spin and clears Forest
Rush whenever eligible. It excludes campaign victory rewards, leftover coins,
and one-time rewards.

| Highest unlocked day | Daily quests | Weekly average | Challenge | Expected spin | Total per UTC day |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1–4 | 6 | 1.86 | 0 | 0 | 7.86 |
| 5–9 | 6 | 1.86 | 0 | 1.70 | 9.56 |
| 10–29 | 12 | 3.71 | 8 | 3.40 | 27.11 |
| 30–50 | 18 | 5.57 | 12 | 5.10 | 40.67 |

Campaign milestones add up to 95 brains and achievements up to 75 once per
progression reset. First-time Rewards includes 12 base brains, three upgrade grants,
and one ticket. Maxed upgrade grants can instead pay their configured fallback.

The five Brainrot Shop unlocks cost 50–80 each and 325 combined before the
ticket. Magnet costs 325 to max from rank 1, Speed costs 2,901 from rank 0,
and one full evolution chain costs 775 brains. A late-band player completing
every recurring objective earns roughly one shop unlock every two days from
retention income alone. A full evolution chain costs about 19 days of that
expected income before campaign rewards and XP gates. Campaign victories add
one brain per cleared day number, so late-game affordability depends strongly
on campaign play as well. Step 7 reviewed the catalog without changing tuning.
Live completion rates, spends, and time to first purchase remain unmeasured.


## Configuration ✅

Values live in `Shared.Config.EconomyConfig` (frozen). Current tuning:

| Key                    | Value | Meaning                                  |
| ---------------------- | ----- | ---------------------------------------- |
| `STARTING_COINS`       | 125   | Day 1 opening purse only (Ballerina + Tung Tung) |
| `REWIND_COINS`         | 200   | Game Over → Rewind retry purse (any day) |
| `PASSIVE_DROP_INTERVAL`| 25    | Seconds between passive drops            |
| `PASSIVE_DROP_AMOUNT`  | 25    | Coins per passive drop                   |
| `PASSIVE_RAIN_HEIGHT`  | 42    | Studs above the tile for passive rain    |
| `PASSIVE_RAIN_DURATION`| 2.2   | Seconds for passive rain fall            |
| `PASSIVE_RAIN_DRIFT`   | 3     | Random horizontal spawn drift (studs)    |
| `PRODUCER_SPIT_DURATION` | 1.45 | Seconds for Ballerina spit arc         |
| `PRODUCER_SPIT_ARC_HEIGHT` | 7.5 | Peak loft of spit arc (studs)            |
| `PRODUCER_SPIT_ORIGIN_CLEARANCE` | −0.8 | Studs vs visual mesh top for spit origin (− = lower / into head) |
| `LEVEL_COMPLETION_REWARD`| 50  | Reserved; day purse uses Day 1 / 0 rules |
| `COINS_PER_LEFTOVER_BRAIN` | 100 | Pocket coins per leftover brain (floor) |
| `GROUND_COIN_LIFETIME` | 15    | Seconds an uncollected coin persists     |
| `COIN_COLLECT_RADIUS`  | 16    | Max studs from a coin to collect it      |

Related Brainrot income: `BallerinaCappucina.coinGeneration = 25` every 18s —
coins are **spat from the unit** and land on a **random grid tile**
(`GenerateCoins` → `CoinService.dropRandomCoinForOwner(..., origin)`).
At most **10** Ballerinas may be living on a plot (`definition.maxOnPlot`).
On NightFog days, spit and passive rain land only on **non-fog** columns
(`WeatherUtil.randomClearPlotPosition` — see `WEATHER.md`).

See **`docs/BALANCE.md`** for the full Milestone 14 economy rationale.

---

## Responsibilities (Milestone 3) ✅

`CoinService` (server) is the **sole authority over coins**; `ProgressService`
owns brains. CoinService:

- Holds each player's authoritative coin balance (`applyDayPurse` on join /
  day end: Day 1 → `STARTING_COINS`, later days → 0; `applyRewindPurse` after
  Game Over). `CoinService` does **not**
  default joiners to 125 — that raced save hydrate and wrongly granted Day 1
  coins on rejoin.
- Grants passive drops on `PASSIVE_DROP_INTERVAL` as **collectible ground
  coins** (one per active player per interval, **only while the level is
  `Active`**), each worth `PASSIVE_DROP_AMOUNT`. Passive coins **rain slowly
  from the sky** onto a **random grid tile**. Uncollected coins despawn after
  `GROUND_COIN_LIFETIME`. Walking collects a coin only after it finishes landing
  (`Landed` attribute). The magnet also grabs coins that are still in the air
  (sky rain or a Ballerina spit) when they are inside its range.
- Validates `CollectCoin` intents — ownership, existence, and distance (against
  the authoritative `HumanoidRootPart` position, within `COIN_COLLECT_RADIUS`) —
  before crediting. Magnet pulls (`MagnetService`) skip the walk radius after a
  server-side range check (`MagnetConfig.rangeTilesFor`, world Chebyshev from the
  player). The coin's value is server-side; client-supplied amounts are
  never trusted.
- Pushes balances to clients via `CoinsUpdated`. The initial `RequestState` pull
  is answered by `LevelService` with `{ coins, level }` (see `NETWORKING.md`).

### Public API (for other services)

| Function                          | Use                                          |
| --------------------------------- | -------------------------------------------- |
| `getBalance(player) -> number`    | read a balance (placement pre-check, M4)     |
| `resetBalance(player)`            | set balance to `STARTING_COINS` (Reset Progress) ✅ |
| `applyDayPurse(player, level)`    | Day 1 → 125; else → 0 ✅ |
| `applyRewindPurse(player)`        | Game Over Rewind → `REWIND_COINS` (200) ✅ |
| `clearPlot(plotModel)`            | despawn all ground coins on a plot ✅          |
| `addCoins(player, amount)`        | credit rewards/income                        |
| `trySpend(player, amount) -> bool`| charge costs; false if unaffordable (M4) ✅  |
| `dropCoinForOwner(userId, plotModel, gridPosition, amount)` | spawn a coin on a specific grid tile ✅ |
| `dropRandomCoinForOwner(userId, amount, spitFrom?)` | Rain (no origin) or spit-from-origin onto a random tile ✅ |
| `pullCoinsInRange(player, originWorld, rangeTiles)` | Magnet: tween + collect coins in range, including ones still falling or mid-spit ✅ |

Spending is now live: `BrainrotService` (M4) pre-checks `getBalance` and charges
with `trySpend` when reserving a tile. **Digging up a Brainrot is not refunded**
— the coins spent placing it are lost (see `BRAINROTS.md` / `NETWORKING.md`).

**Brains** are spent at the Brainrot stall and HUD Upgrades (Milestone 18): `ProgressService`
validates `BuyStoreItem` and deducts brains. See `docs/STORE.md`. Leftover
match coins convert to brains at victory / defeat via
`ProgressService.brainsFromLeftoverCoins` (then `applyDayPurse`). Rewind then
applies `REWIND_COINS`. Day Select
and leave do **not** convert.

### Implementation

`CoinService/` is split into the service (`init.luau`), `GroundCoin.luau`
(builds a coin part), and `CoinMotion.luau` (rain / spit animations). The client
`CoinController` detects the local player touching their own coin and fires the
`CollectCoin` intent; `UIController` renders the balance. Brainrot producers
call `dropRandomCoinForOwner` with the unit’s world position so coins spit out
onto a random tile.

---

## Persistence (see `SAVE_SYSTEM.md`)

- The coin **balance** is **not** saved. Join / day end apply the day purse
  (Day 1 → `STARTING_COINS`; later days → 0). Rewind applies `REWIND_COINS`.
- **Ground coins** (uncollected pickups) are **not** saved.
