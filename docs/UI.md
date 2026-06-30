# BVM UI

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
        Shop      (Frame)   ✅ M4
        Coins     (Frame)   ✅ M3
        WaveUI    (Frame)   🔜 M8
        Settings  (Frame)   🔜 M14
```

`Coins` and `Shop` are populated at runtime by `UIController`; `WaveUI` and
`Settings` remain empty scaffolds until their milestones.

---

## Controllers (client)

UI and input are driven by client Controllers
(`StarterPlayerScripts.Client.Controllers`):

| Controller            | Owns                                         | Status |
| --------------------- | -------------------------------------------- | ------ |
| `UIController`        | Shop, Coins, Wave display, Settings panels   | ✅ M3 (Coins), M4 (Shop) |
| `CoinController`      | Ground-coin pickup intent (`CollectCoin`)    | ✅ M3  |
| `GridController`      | Hover highlight + tile resolver for previews | ✅ M2  |
| `PlacementController` | Selection, ghost preview, placement intent   | ✅ M4  |
| `CameraController`    | Default 3rd-person camera (reserved for juice)| ✅ M1  |
| `InputController`     | Centralized mouse/touch/keyboard intent      | ✅ M4  |

`GridController` is visual-only (see `GRID.md`); `PlacementController` reuses its
`resolveTileAt(x, y)` raycast rather than re-implementing hover detection.

---

## Panels

- **Coins** ✅ M3 — top-left counter showing the authoritative balance from
  `CoinsUpdated`, seeded by the initial `RequestState` pull. `UIController` builds
  it inside `MainUI.Coins` and only displays state.
- **Shop** ✅ M4 — right-side panel listing the Brainrot roster (swatch, name,
  cost) read from `Shared.Brainrots`, sorted by cost. Built by
  `UIController/Shop.luau` inside `MainUI.Shop`. Cards grey out when unaffordable
  (driven by the same `CoinsUpdated` balance). Clicking a card selects it for
  placement (clicking the selected card again cancels); the highlight follows
  `PlacementController.selectionChanged`, so it stays correct even when placement
  is cancelled with right-click / Esc.
- **WaveUI** 🔜 M8 — current wave, phase, countdown, and the **Start Wave**
  button (`StartWave` remote); reflects `WaveStateChanged`.
- **Settings** 🔜 M14 — options plus **Reset Progress** (confirmation required,
  `ResetProgress` remote) and statistics display.

---

## Placement flow (Milestone 4) ✅

The placement experience is split so each controller has one job:

- **`InputController`** translates raw devices into two intent signals,
  `primaryAction` (left-click / tap / Enter) and `secondaryAction` (right-click /
  Esc / Backspace), each carrying the screen position. Inputs already consumed by
  the GUI (`gameProcessed`) are ignored, so clicking a Shop button never doubles
  as a battlefield action.
- **`PlacementController`** holds the selected Brainrot, renders the translucent
  **ghost** over the hovered own-plot tile (green when free + affordable, red
  otherwise — purely cosmetic), and forwards intent: `primaryAction` fires
  `PlaceBrainrot`; `secondaryAction` cancels placement, or — when nothing is
  selected — fires `RemoveBrainrot` on the targeted own tile. Placement mode
  stays active after a successful place so several can be set down in a row.

The server (`BrainrotService`) re-validates everything (see `NETWORKING.md`).

---

## Rules for UI work

- Read state from server pushes (`CoinsUpdated`, `WaveStateChanged`, …); never
  compute authoritative values on the client.
- Send only intent via remotes; the server validates (see `NETWORKING.md`).
- Display Brainrot/monster info by reading the shared registries
  (`Shared.Brainrots`, `Shared.Monsters`) — single source of truth.
- Keep visual/sound feedback on the client (Milestones 13–14).
