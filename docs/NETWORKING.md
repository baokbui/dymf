# BVM Networking

How the client and server communicate. The guiding rule from `.cursorrules`:
**never trust RemoteEvents — validate everything on the server.**

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Single boundary: the Remotes module

All traffic flows through `ReplicatedStorage.Shared.Remotes`. Remote **names**
are declared once in that module; nothing creates ad-hoc remotes elsewhere.

- On the **server**, `Remotes.initServer()` (called by the server bootstrap)
  eagerly creates a `Remotes` folder under `ReplicatedStorage` and every
  declared `RemoteEvent` / `RemoteFunction` inside it — before any client can
  reference them.
- On the **client**, `Remotes.getEvent(name)` / `Remotes.getFunction(name)`
  `WaitForChild` the instance (10s timeout).

```lua
local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.getEvent("CoinsUpdated").OnClientEvent:Connect(handler) -- client
Remotes.getEvent("StartLevel"):FireServer()                     -- client
```

Adding a new remote = add its name to `EVENT_NAMES` or `FUNCTION_NAMES` in the
Remotes module. That is the only required step.

---

## Remote catalog

### RemoteEvents

| Name               | Direction       | Status | Purpose                                 |
| ------------------ | --------------- | ------ | --------------------------------------- |
| `PlaceBrainrot`    | client → server | ✅ M4  | Request to place a Brainrot on a tile   |
| `RemoveBrainrot`   | client → server | ✅ M4  | Request to remove a placed Brainrot     |
| `PlaceBrainrotFailed` | server → client | ✅ M4  | Plant rejected (coins / occupied / recharging / …) — toast under Shop |
| `PlantCooldownsUpdated` | server → client | ✅ | `brainrotId` → `readyAt` (`GetServerTimeNow`) after plant / Start Day clear |
| `CollectCoin`      | client → server | ✅ M3  | Intent to collect a ground coin (by id) |
| `CoinsUpdated`     | server → client | ✅ M3  | Pushes the authoritative coin balance   |
| `BrainrotAction`   | server → client | ✅ M5/M12 | Ability feedback (`action`, `instanceId`) → owner-only SFX/pulse |
| `FogRowsChanged`   | server → client | ✅ | Lawn rows whose Night Fog plant-block is lifted (Giraffa plot gust); `{ rows }` **plot owner only** |
| `CombatVisual`     | server → client | ✅ M7/M11/M12 | Hit / death / explosion / BatSlam / Jackpot / Terrify / SandTornado / Dizzy / MonsterAttack VFX + SFX (**plot owner only**) |
| `StartLevel`       | client → server | ✅ M8  | Player presses Start Day (Preparation only) |
| `LevelStateChanged`| server → client | ✅ M8  | Phase / level number / progress / weather updates  |
| `SelectLevel`      | client → server | ✅ M13 | Replay a cleared level via Level Select  |
| `RewindDay`        | client → server | ✅     | Game Over → Preparation on the failed day (`REWIND_COINS`) |
| `ContinueVictory`  | client → server | ✅     | Reward Continue → Preparation (next day) |
| `ResetProgress`    | client → server | ✅ M13 | Confirmed reset of all save data         |
| `ProfileUpdated`   | server → client | ✅ M13 | Brains, unlocks, equipped loadout, stats, Brainrot XP, claimed evolutions, introduced Brainrots / Monsters (Index). Support-job XP (`grantBrainrotXp`) is coalesced (`ProgressConfig.XP_BROADCAST_INTERVAL`) so coin / soak ticks do not remount Inventory ViewportFrames. Kills / purchases still push immediately. |
| `SetEquipped`      | client → server | ✅ M13 | Replace equipped loadout (validated; ignored while day is Active) |
| `OpenProgressionStore` | server → client | ✅ M18 | Owner talks to own Tung mascot → open Brainrot overlay (`shopKind`, mascot `Vector3`) |
| `BuyStoreItem`     | client → server | ✅ M18 | Spend brains (`shop` + `id`); stall range for Brainrots, own plot for HUD Upgrades |
| `StorePurchaseSucceeded` | server → client | ✅ M18 | Authoritative spend (`cost`); client kaching + brains delta |
| `StorePurchaseFailed` | server → client | ✅ M18 | Rejected buy (broke / owned / max) |
| `EvolveBrainrot`   | client → server | ✅ M19 | Claim an evolution (`brainrotId`, `rarity`); server checks level, previous tier, brains |
| `ActivateMagnet`   | client → server | ✅ | Press **1** / HUD chip; server checks Active day, plot, cooldown (rejects while paused) |
| `MagnetStateChanged` | server → client | ✅ | `{ level, activeUntil, readyAt, pausedRemaining }` (`GetServerTimeNow`; remaining seconds frozen between days) |
| `DamageMeterUpdated` | server → client | ✅ | `{ brainrots, monsters }` ranked `{ id, damage }` lists (plot owner; coalesced) |

### RemoteFunctions

| Name           | Direction       | Status | Purpose                              |
| -------------- | --------------- | ------ | ------------------------------------ |
| `RequestState` | client → server | ✅ M3  | Initial state pull on join/UI        |

`RequestState` returns `{ coins, level, profile, plantCooldowns, magnet, damageMeter }` — handled by `LevelService.start()`
(`plantCooldowns` is `brainrotId` → `readyAt` server time for shop recharge UI;
`magnet` is `{ level, activeUntil, readyAt, pausedRemaining }`;
`damageMeter` is `{ brainrots, monsters }` ranked `{ id, damage }` lists).
using `CoinService`, `LevelService.getClientState`, and `ProgressService.getClientState`.

---

## Plot assignment (Milestone 1) ✅

Plot assignment is fully server-side and needs no remotes: on `PlayerAdded`,
`PlotService` assigns a free plot, points the player's `RespawnLocation` at that
plot's `SpawnLocation`, and spawns the character there (`CharacterAutoLoads`
is off so join doesn't spawn before a plot exists). On Reset Character / death,
`PlotService` calls `LoadCharacter` again after `Players.RespawnTime`. The
camera uses Roblox's default third-person behavior, so no client handshake is
required. Clients cannot choose, move, or learn about other players' plots.

---

## Coin collection (Milestone 3) ✅

Passive drops spawn collectible **ground coins** on each player's plot (server,
`CoinService`) **only while that player's level is `Active`**. Collection is
client-intent + server-authority:

1. The owning client's `CoinController` detects its character touching one of its
   own coins (coins are tagged `Coin` with `CoinId`/`OwnerUserId`/`Value`) and
   fires `CollectCoin(coinId)`.
2. The server re-validates: the coin exists, the caller owns it, and the caller's
   authoritative `HumanoidRootPart` is within `COIN_COLLECT_RADIUS`. Only then is
   the coin's (server-side) value credited and `CoinsUpdated` pushed.

The client never sends an amount and cannot collect coins it doesn't own or
isn't near, so balances can't be exploited.

---

## Brainrot placement & removal (Milestone 4) ✅

Placement is client-intent + server-authority, owned by `BrainrotService`.

**Place** — the client sends `PlaceBrainrot(brainrotId, { row, column })`. It
never sends a cost or a world position; it only names a registry id and a tile.
The server validates, in order:

0. The level is `Active` (`LevelService.isLevelActive`).
1. Argument shapes — `brainrotId` is a string, the position is a table of
   integers, and the tile is in-bounds (`GridUtil.isInBounds`).
2. The id exists in the `Shared.Brainrots` registry (definition resolved here;
   never branch on names).
3. The caller owns a plot (`PlotService.getPlot`).
4. The caller can afford the definition's `cost` (against the authoritative
   balance from `CoinService`).
5. The target tile is free — reserved via `GridService.tryOccupy` *before*
   charging, so two requests can't claim the same tile.
6. The coins are spent (`CoinService.trySpend`); the tile is released if the
   charge fails (guards a balance race between steps 4 and 6).

Only then is the model built and the instance recorded.

**Remove** — the client sends `RemoveBrainrot({ row, column })`. The server
resolves the Brainrot occupying that tile (via the tile's
`brainrotInstanceId`), confirms the **caller owns it**, frees the tile, and
destroys the model. Digging up a Brainrot is **not refunded** — the coins spent
placing it are lost. A client can never remove another player's Brainrot.

The placement **ghost** is a purely cosmetic client preview
(`PlacementController`); it carries no authority. `UIController` disables
placement selection outside `Active` via `PlacementController.setPlacementAllowed`.
The client tracks its balance
only to tint the ghost and grey unaffordable Shop cards — the server is the
sole judge of affordability.

---

## Level campaign (Milestone 8) ✅

The campaign loop is server-authoritative, owned by `LevelService` (see
`LEVELS.md`).

**Start** — the client sends `StartLevel()` with no arguments when the player
presses the button (only enabled during `Preparation`). The server
validates phase, enters `Countdown` (3…0 overlay), then `Active`.
Monsters spawn in the forest and walk toward the plot (setup time).

**`RewindDay`** — client fires from the Game Over overlay while phase is
`Defeat`. Server validates phase, enters `Preparation` on the same failed day
(lawn already restored from the victory checkpoint on defeat; Brainrot XP
already rolled back to the Start Day snapshot) and sets the coin purse to
`REWIND_COINS` (200).

**State** — the server pushes `LevelStateChanged(payload)` to the plot owner
whenever phase, progress, or big-wave warning changes. The client
`UIController/Level.luau` panel only displays this payload. Payload includes
optional `weather` (e.g. `"Night"` / `"NightFog"` / `"Desert"`) from the current
`LevelDefinition` — `WeatherController` / placement use it for night/fog
presentation and fog-tile rules (`WEATHER.md`). Initial join state includes
`level` inside the `RequestState` pull (`{ coins, level }`).

**Defeat** — when hearts reach 0 during `Active`, `LevelService` clears mid-day
plants / monsters / ground coins, **restores the last victory checkpoint lawn**,
keeps `currentLevel` on the failed day, refills hearts, applies the day purse
(Day 1 → 125; later → 0), and sets phase to `Defeat`. The client shows
**GameOverPopup** (slow GAME OVER + Rewind Day N). **Victory** —
when all spawn groups are finished and no monsters remain, the server grants
coins and unlocks the next level. The Victory payload's `reward` table may
include `unlockedBrainrotId` when clearing that day grants a starter-roster
Brainrot (`ProgressConfig.UNLOCK_SCHEDULE`). Phase stays **Victory** until the
player presses **Continue** (`ContinueVictory`); then Preparation. Unlock
popups queue after Continue. Join / Preparation payloads may include
`introducedBrainrotIds`, `introducedMechanicIds`, and `introducedMonsterIds`
(queued intros; see `BRAINROTS.md` / `UI.md` / `LEVELS.md`).

---

## Validation rules (server authority)

When implementing client → server events in later milestones:

- Treat all arguments as untrusted; validate type, range, and ownership.
- Verify the acting player owns the plot/tile/Brainrot they reference
  (`PlotService.getPlot(player)`).
- Re-check resource costs server-side (e.g. coins) before applying effects.
- Never echo client-claimed authoritative values (coins, health, damage).
- Rate-limit/guard against spam where relevant.

---

## Data passed over remotes

- `CFrame`, `Vector3`, numbers, strings, and tables of these are safe to send.
- Prefer sending **identifiers** (tile coordinates, Brainrot ids) over full
  instances; the server resolves them against authoritative state.
