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
        Brains       (Frame)   ✅ M13
        Hearts       (Frame)   ✅ M13
        LevelUI      (Frame)   ✅ M8
        Settings     (Frame)   ✅ M13
        Inventory    (Frame)   ✅ M13 (loadout)
        RewardPopup  (Frame)   ✅ M13
        UnlockPopup  (Frame)   ✅ M13
        MonsterIntroPopup (Frame) ✅
        GameOverPopup (Frame) ✅
```

`UIController` builds each panel at runtime (except scaffolding frames).

---

## Visual theme ✅

All HUD panels share a **cartoon thick-outline** look from
`ReplicatedStorage.Shared.Config.UITheme` (also `Config.UI`):

- Solid panel / chip fills — same rounded-corner + thick black `UIStroke`
  geometry everywhere, but each HUD piece gets its own saturated "candy" color
  so the screen doesn't read as one wall of blue: Day/Start Day panel and Shop
  dock stay cool blue (the reference look), Coins is gold, Brains is purple,
  Hearts is rosy red, Inventory is leafy green, Settings is orange,
  RewardPopup is gold, UnlockPopup is purple, MonsterIntroPopup is orange,
  GameOverPopup is dark defeat crimson.
- Black `UIStroke` borders (thick on panels, slightly thinner on cards)
- Bold white/accent titles with black `TextStroke`
- Flat saturated accents (gold coins, red hearts/danger, green start)

Layout and structure are unchanged — panels only consume theme tokens/helpers
(`applyPanelLook`, `applyChipLook`, `applyCardLook`, `applyButtonLook`,
`applyOutlinedTitle`, `applyBodyText`), passing an optional per-panel `fill`
Color3 override (`UITheme.PANEL_BG_*` / `CHIP_BG_*`) for accent color. Do not
hardcode a second palette in new UI.

---

## Controllers (client)

| Controller            | Owns                                         | Status |
| --------------------- | -------------------------------------------- | ------ |
| `UIController`        | Shop, Coins, Brains, Hearts, Level, Settings, Inventory, Rewards, Unlock popup | ✅ M3–M4, M8, M13 |
| `CoinController`      | Ground-coin pickup intent (`CollectCoin`)    | ✅ M3  |
| `BrainrotController`  | Brainrot action sound feedback (`BrainrotAction`) | ✅ M5/M12 |
| `CombatController`      | Combat hit/death visuals (`CombatVisual`)         | ✅ M7 |
| `AudioController`       | BGM, ambient, SFX + Settings volume/mute hooks    | ✅ M12/M13 |
| `GridController`      | Hover highlight + tile resolver for previews | ✅ M2  |
| `PlacementController` | Selection, ghost preview, placement intent   | ✅ M4  |
| `CameraController`    | Default 3rd-person camera (reserved for juice)| ✅ M1  |
| `InputController`     | Centralized mouse/touch/keyboard intent      | ✅ M4  |

---

## Panels

- **Coins** ✅ M3 — top-left counter; floating ±N feedback on collect/spend.
- **Brains** ✅ M13 — top-left counter directly under Coins; display-only,
  synced from `ProfileUpdated` / `RequestState` (`profile.brains`).
- **Hearts** ✅ M13 — five house hearts in a rounded HUD box under Brains.
- **Shop** ✅ M4 / M13 — top-center placement bar shows **equipped** Brainrots
  only (loadout from `ProfileUpdated` / `SetEquipped`). Each card mounts a
  3D model preview via `BrainrotPreview` (`Assets.Brainrots` / `modelId`).
  Cards use wider gaps, thinner outlines, and pulled-back previews (no nested
  stroke on the viewport) so the row stays readable. Framing uses visual AABB
  + optional `previewFocusOffset`; animated rigs stay posed (no idle playback
  in the ViewportFrame). After planting, the card
  shows a **recharge overlay** (`PlantCooldownsUpdated`; cheaper units recharge
  faster — see `BrainrotConfig.plantCooldownFor`).
- **Plant toasts** ✅ — stacked messages just under Shop when a plant fails
  (not enough coins, occupied tile, day not started, still recharging, …). Newest stays under the
  shop; older ones slide up and fade.
- **LevelUI** ✅ M8 — bottom-right Start/Restart **Day**, progress, big-wave banner
  (player copy uses "Day"; remotes stay `StartLevel` / `LevelStateChanged`).
- **Settings** ✅ M13 — left HUD bar under Inventory opens the modal. Mute,
  music/SFX volume, Brainrot SFX toggle, statistics, **Danger Zone → Reset
  Progress** (red button, **two confirmations**). Confirmed reset → Day 1,
  empty lawn, coins = 125 (`SaveService.resetProgress`). Statistics come from
  `ProfileUpdated` / `RequestState`. Opening Settings re-pulls state so time
  played stays current. Day Select is deferred to a future dedicated UI.
- **Inventory** ✅ M13 — left HUD bar under Hearts opens the loadout modal; a
  PvZ-style **seed packet grid** (portrait + name plate + status ribbon) for
  equip/unequip of unlocked Brainrots (max `ProgressConfig.MAX_EQUIPPED`). Only
  unlocked entries appear — locked starter-roster Brainrots are simply absent
  until their unlock day clears (see `BRAINROTS.md`). Hovering a packet opens
  an info tooltip (portrait + stat rows + ability blurb) built from
  `Client.Utilities.BrainrotInfo` (display-only text keyed by ability id,
  resolved from the same `Shared.Brainrots` registry). Server validates equip
  changes via `SetEquipped`. Loadout **cannot** change while the day is
  **Active** (server reject + inventory packets locked).
- **UnlockPopup** ✅ — decently-sized center-screen celebration the first time
  a Brainrot is introduced (portrait, name, stat summary, ability blurb,
  dismiss). Starter trio (Ballerina / Tung Tung / Chimpanzini) on first
  **reach** of Day 1 (`ProgressConfig.BRAINROT_INTRO_SCHEDULE`). The other
  four after first **clear** of their unlock day (`UNLOCK_SCHEDULE` →
  `reward.unlockedBrainrotId`). Queued so several intros play one after
  another. Server-decided; UI is display-only.
- **MonsterIntroPopup** ✅ — same cartoon modal for every campaign monster /
  boss the first time the player **reaches** its intro day (or catch-up if
  they skip ahead). `ProgressConfig.MONSTER_INTRO_SCHEDULE`: Zombie 1, Goblin
  5, Goblin Elite 10, Vampire 15, Duke Vampire 20, Spider 25, Queen Spider 30,
  Skeleton 31, Werewolf 35, Small Mummy 41, Scorpion 45, Pharaoh Mummy 50.
  Driven by `introducedMonsterIds` on `LevelStateChanged`; portrait via
  `MonsterPreview`, stats/abilities via `MonsterInfo`. Persisted in
  `SaveData.introducedMonsters` so it only fires once.
- **GameOverPopup** ✅ — full-screen defeat overlay when hearts hit 0: slow
  **GAME OVER** reveal, “You have failed to protect Triple T and his house.”,
  and **Rewind Day N**. Clicking Rewind plays a translucent clock spin, fades
  the overlay, and fires `RewindDay` (server → Preparation on the failed day
  with the victory-checkpoint lawn already restored).
- **RewardPopup** ✅ M13 — victory overlay showing brains earned for the cleared
  day (`LevelStateChanged.reward`).

### Milestone 18 — Progression Store 🔜

- Physical **Brainrots Store** (Tung Mascot, blue mini store) and **Upgrade
  Store** (67 Mascot, red mini store) cloned beside each plot house.
- Purchasing locked roster entries and Speed with brains.

See `docs/STORE.md`.

---

## Placement flow (Milestone 4) ✅

- **`InputController`** → `primaryAction` (ignores GUI-processed input).
- **`PlacementController`** → ghost + `PlaceBrainrot` / shovel remove. Client
  pre-checks coins/occupancy and shows a plant toast on failure; the server still
  validates and may fire `PlaceBrainrotFailed`.
- Shop selection and planting are allowed in **Active** (Start Day skips the
  old Countdown idle wait). Planting matches `LevelService.isLevelActive`.
- Client coin balance for affordability checks is synced from `CoinsUpdated` and
  `RequestState` via `UIController` → `PlacementController.setBalance` (UI display
  and placement pre-check stay in sync).
- Server also checks **unlocked + equipped** (`ProgressService.canPlace`).

---

## Rules for UI work

- Read state from server pushes (`CoinsUpdated`, `LevelStateChanged`,
  `ProfileUpdated`, …); never compute authoritative values on the client.
- Send only intent via remotes; the server validates (see `NETWORKING.md`).
- Display Brainrot/monster info from shared registries.
- Keep visual/sound feedback on the client.

## Shop tool row ✅

- **Shovel** — toggles remove mode; cursor becomes a shovel icon.
- **Cancel (red X)** — clears the current Brainrot selection **and** exits
  shovel mode; visible whenever either is active (`Shop.setCancelVisible`).
- Clicking a card that is still on plant-recharge cooldown does not select it —
  it shows the same plant-failure toast as a rejected server placement
  ("still recharging").
