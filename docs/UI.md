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
        LevelUI   (Frame)   ✅ M8
        Settings  (Frame)   🔜 M13
```

`Coins` and `Shop` are populated at runtime by `UIController`; `LevelUI` and
`Settings` remain empty scaffolds until their milestones.

---

## Controllers (client)

UI and input are driven by client Controllers
(`StarterPlayerScripts.Client.Controllers`):

| Controller            | Owns                                         | Status |
| --------------------- | -------------------------------------------- | ------ |
| `UIController`        | Shop, Coins, Level display, Settings panels  | ✅ M3 (Coins), M4 (Shop), M8 (Level) |
| `CoinController`      | Ground-coin pickup intent (`CollectCoin`)    | ✅ M3  |
| `BrainrotController`  | Brainrot action sound feedback (`BrainrotAction`) | ✅ M5/M12 |
| `CombatController`      | Combat hit/death visuals (`CombatVisual`)         | ✅ M7 |
| `HealthBarController`   | Billboard health bars on local plot               | ✅ M7 |
| `AudioController`       | BGM, ambient, SFX (`AudioConfig` / `SfxPlayer`)   | ✅ M12 |
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
  it inside `MainUI.Coins` via `CoinCounter.luau` and only displays state.
  Floating **+N** (green) appears when the player collects a ground coin;
  **-N** (red) appears when a Brainrot placement is confirmed by the server
  (balance drop on `CoinsUpdated`).
- **Shop** ✅ M4 — PvZ-style **horizontal bar pinned to the top-center** of the
  screen. A **shovel** tool and red **cancel** button sit to the left of the
  Brainrot cards (portrait tiles with swatch, name, and cost), built by
  `UIController/Shop.luau` inside `MainUI.Shop`. Cards dim when unaffordable;
  the selected card gets a blue highlight. The cancel button appears while a card
  is selected; shovel mode swaps the cursor for digging up plants.
- **LevelUI** ✅ M8 — bottom-right panel with the current level number/name, a
  short phase hint, a green **Start Level** button (`StartLevel` remote) that
  becomes a red **Restart Level** button during `Defeat`, a spawn-group
  **progress bar** during `Active`, and a **big-wave warning**
  banner; reflects `LevelStateChanged`.
- **Settings** 🔜 M13 — options plus **Reset Progress** (confirmation required,
  `ResetProgress` remote), a **Level Select** for replaying cleared levels
  (`SelectLevel` remote), and statistics display.

---

## Placement flow (Milestone 4) ✅

The placement experience is split so each controller has one job:

- **`InputController`** translates raw devices into intent signals:
  `primaryAction` (left-click / tap / Enter).
  Inputs already consumed by the GUI (`gameProcessed`) are ignored, so clicking
  a Shop button never doubles as a battlefield action.
- **`PlacementController`** holds the selected Brainrot, renders the translucent
  **ghost** over the hovered own-plot tile (green when free + affordable, red
  otherwise — purely cosmetic), and forwards intent: `primaryAction` fires
  `PlaceBrainrot` then clears selection; **shovel mode** (Shop shovel button)
  swaps the cursor and removes Brainrots on click; the red **cancel** button
  (below the shovel, visible while a card is selected) clears selection.

The server (`BrainrotService`) re-validates everything (see `NETWORKING.md`).

---

## Rules for UI work

- Read state from server pushes (`CoinsUpdated`, `LevelStateChanged`, …); never
  compute authoritative values on the client.
- Send only intent via remotes; the server validates (see `NETWORKING.md`).
- Display Brainrot/monster info by reading the shared registries
  (`Shared.Brainrots`, `Shared.Monsters`) — single source of truth.
- Keep visual/sound feedback on the client (Milestones 13–14).
