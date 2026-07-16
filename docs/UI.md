# BVM UI

UI **only displays state** and forwards player intent. It performs no gameplay
logic — all calculations happen on the server (`.cursorrules`).

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Structure

The UI root lives in `StarterGui.MainUI` (a `ScreenGui`, declared in
`default.project.json`). Panels:

```
StarterGui/
    MainUI (ScreenGui)
        Shop         (Frame)   ✅ M4 / loadout-driven M13
        Coins        (Frame)   ✅ M3
        Hearts       (Frame)   ✅ M13
        LevelUI      (Frame)   ✅ M8
        Settings     (Frame)   ✅ M13
        Inventory    (Frame)   ✅ M13 (loadout)
        RewardPopup  (Frame)   ✅ M13
```

`UIController` builds each panel at runtime (except scaffolding frames).

---

## Controllers (client)

| Controller            | Owns                                         | Status |
| --------------------- | -------------------------------------------- | ------ |
| `UIController`        | Shop, Coins, Hearts, Level, Settings, Inventory, Rewards | ✅ M3–M4, M8, M13 |
| `CoinController`      | Ground-coin pickup intent (`CollectCoin`)    | ✅ M3  |
| `BrainrotController`  | Brainrot action sound feedback (`BrainrotAction`) | ✅ M5/M12 |
| `CombatController`      | Combat hit/death visuals (`CombatVisual`)         | ✅ M7 |
| `HealthBarController`   | Billboard health bars on local plot               | ✅ M7 |
| `AudioController`       | BGM, ambient, SFX + Settings volume/mute hooks    | ✅ M12/M13 |
| `GridController`      | Hover highlight + tile resolver for previews | ✅ M2  |
| `PlacementController` | Selection, ghost preview, placement intent   | ✅ M4  |
| `CameraController`    | Default 3rd-person camera (reserved for juice)| ✅ M1  |
| `InputController`     | Centralized mouse/touch/keyboard intent      | ✅ M4  |

---

## Panels

- **Coins** ✅ M3 — top-left counter; floating ±N feedback on collect/spend.
- **Hearts** ✅ M13 — five house hearts in a rounded HUD box under Coins.
- **Shop** ✅ M4 / M13 — top-center placement bar shows **equipped** Brainrots
  only (loadout from `ProfileUpdated` / `SetEquipped`).
- **Plant toasts** ✅ — stacked messages just under Shop when a plant fails
  (not enough coins, occupied tile, day not started, …). Newest stays under the
  shop; older ones slide up and fade.
- **LevelUI** ✅ M8 — bottom-right Start/Restart **Day**, progress, big-wave banner
  (player copy uses "Day"; remotes stay `StartLevel` / `LevelStateChanged`).
- **Settings** ✅ M13 — left HUD bar under Inventory opens the modal. Mute,
  music/SFX volume, Brainrot SFX toggle, statistics, **Reset Progress**
  (double-confirm). Day Select is deferred to a future dedicated UI.
- **Inventory** ✅ M13 — left HUD bar under Hearts opens the loadout modal;
  equip/unequip unlocked Brainrots (max `ProgressConfig.MAX_EQUIPPED`). Server
  validates via `SetEquipped`.
- **RewardPopup** ✅ M13 — victory overlay showing brains earned for the cleared
  day (`LevelStateChanged.reward`).

### Deferred (Milestone 22 — Progression Store)

- Physical **Brainrots Store** (world shop to spend brains on new unlocks).
- Purchasing locked roster entries with brains.

Brains currency + victory grants are live so the store can plug in later.

---

## Placement flow (Milestone 4) ✅

- **`InputController`** → `primaryAction` (ignores GUI-processed input).
- **`PlacementController`** → ghost + `PlaceBrainrot` / shovel remove. Client
  pre-checks coins/occupancy and shows a plant toast on failure; the server still
  validates and may fire `PlaceBrainrotFailed`.
- Server also checks **unlocked + equipped** (`ProgressService.canPlace`).

---

## Rules for UI work

- Read state from server pushes (`CoinsUpdated`, `LevelStateChanged`,
  `ProfileUpdated`, …); never compute authoritative values on the client.
- Send only intent via remotes; the server validates (see `NETWORKING.md`).
- Display Brainrot/monster info from shared registries.
- Keep visual/sound feedback on the client.
