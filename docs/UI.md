# BVZ UI

UI **only displays state** and forwards player intent. It performs no gameplay
logic — all calculations happen on the server (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Structure

The UI root lives in `StarterGui.MainUI` (a `ScreenGui`, declared in
`default.project.json`). Current placeholder panels (hidden, transparent) are:

```
StarterGui/
    MainUI (ScreenGui)
        Shop      (Frame)   🔜 M4
        Coins     (Frame)   🔜 M3
        WaveUI    (Frame)   🔜 M8
        Settings  (Frame)   🔜 M15
```

These are empty scaffolds today; they are populated by the milestones noted.

---

## Controllers (client)

UI and input are driven by client Controllers
(`StarterPlayerScripts.Client.Controllers`):

| Controller            | Owns                                         | Status |
| --------------------- | -------------------------------------------- | ------ |
| `UIController`        | Shop, Coins, Wave display, Settings panels   | 🔜 M3+ |
| `PlacementController` | Selection, ghost preview, tile highlighting  | 🔜 M4  |
| `CameraController`    | Default 3rd-person camera (reserved for juice)| ✅ M1  |
| `InputController`     | Centralized mouse/touch/keyboard intent      | 🔜 M4  |

---

## Panels (planned)

- **Coins** 🔜 M3 — shows the authoritative balance from `CoinsUpdated`.
- **Shop** 🔜 M4 — lists Brainrots (name, cost from the registry); selecting one
  enters placement mode (`PlacementController`).
- **WaveUI** 🔜 M8 — current wave, phase, countdown, and the **Start Wave**
  button (`StartWave` remote); reflects `WaveStateChanged`.
- **Settings** 🔜 M15 — options plus **Reset Progress** (confirmation required,
  `ResetProgress` remote) and statistics display.

---

## Rules for UI work

- Read state from server pushes (`CoinsUpdated`, `WaveStateChanged`, …); never
  compute authoritative values on the client.
- Send only intent via remotes; the server validates (see `NETWORKING.md`).
- Display Brainrot/zombie info by reading the shared registries
  (`Shared.Brainrots`, `Shared.Zombies`) — single source of truth.
- Keep visual/sound feedback on the client (Milestones 13–14).
