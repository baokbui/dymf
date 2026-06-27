# BVZ Networking

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
Remotes.getEvent("StartWave"):FireServer()                      -- client
```

Adding a new remote = add its name to `EVENT_NAMES` or `FUNCTION_NAMES` in the
Remotes module. That is the only required step.

---

## Remote catalog

### RemoteEvents

| Name               | Direction       | Status | Purpose                                 |
| ------------------ | --------------- | ------ | --------------------------------------- |
| `PlaceBrainrot`    | client → server | 🔜 M4  | Request to place a Brainrot on a tile   |
| `RemoveBrainrot`   | client → server | 🔜 M4  | Request to remove a placed Brainrot     |
| `CollectCoin`      | client → server | 🔜 M3  | Request to collect a ground coin        |
| `CoinsUpdated`     | server → client | 🔜 M3  | Pushes the authoritative coin balance   |
| `StartWave`        | client → server | 🔜 M8  | Player presses Start Wave                |
| `WaveStateChanged` | server → client | 🔜 M8  | Phase / wave number / countdown updates  |
| `ResetProgress`    | client → server | 🔜 M15 | Confirmed reset of all save data         |

### RemoteFunctions

| Name           | Direction       | Status | Purpose                              |
| -------------- | --------------- | ------ | ------------------------------------ |
| `RequestState` | client → server | 🔜     | Initial full-state pull on join/UI   |

---

## Plot assignment (Milestone 1) ✅

Plot assignment is fully server-side and needs no remotes: on `PlayerAdded`,
`PlotService` assigns a free plot, points the player's `RespawnLocation` at that
plot's `SpawnLocation`, and spawns the character there. The camera uses Roblox's
default third-person behavior, so no client handshake is required. Clients
cannot choose, move, or learn about other players' plots.

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
