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
        Speed        (Frame)   ✅ M18
        Hearts       (Frame)   ✅ M13
        LevelUI      (Frame)   ✅ M8
        Settings     (Frame)   ✅ M13
        Inventory    (Frame)   ✅ M13 (loadout)
        Index        (Frame)   ✅ (encounter catalog)
        MagnetEntry  (created in MagnetHud) ✅
        DamageMeter  (Frame)   ✅
        BrainrotInspect (created in BrainrotInspect) ✅
        MonsterInspect (created in MonsterInspect) ✅
        RewardPopup  (Frame)   ✅ M13
        UnlockPopup  (Frame)   ✅ M13
        MonsterIntroPopup (Frame) ✅
        MechanicIntroPopup (Frame) ✅
        GameOverPopup (Frame) ✅
        ProgressionStore (Frame) ✅ M18
```

`UIController` builds each panel at runtime (except scaffolding frames).

---

## Visual theme ✅

All HUD panels share a **cartoon thick-outline** look from
`ReplicatedStorage.Shared.Config.UITheme` (also `Config.UI`):

- Solid panel / chip fills — same rounded-corner + thick black `UIStroke`
  geometry everywhere, but each HUD piece gets its own saturated "candy" color
  so the screen doesn't read as one wall of blue: Day/Start Day panel and Shop
  dock stay cool blue (the reference look), Coins / Brains / Speed are bare
  glyphs + amount (no plate or chip), Hearts are bare glyphs (no chip), Inventory /
  Index / Upgrades / Settings are bare icon + name (no plate), Magnet is red,
  RewardPopup is gold, UnlockPopup is purple, ProgressionStore is teal,
  MonsterIntroPopup is orange, MechanicIntroPopup is mossy stone, GameOverPopup is dark defeat crimson.
- Black `UIStroke` borders (thick on panels, slightly thinner on cards)
- Bold white/accent titles with black `TextStroke`
- Flat saturated accents (gold coins, red hearts/danger, green start)

Layout lives in each panel module. Theme tokens/helpers
(`applyPanelLook`, `applyChipLook`, `applyCardLook`, `applyButtonLook`,
`applyOutlinedTitle`, `applyBodyText`) take an optional per-panel `fill`
Color3 override (`UITheme.PANEL_BG_*` / `CHIP_BG_*`) for accent color. Do not
hardcode a second palette in new UI.

---

## Controllers (client)

| Controller            | Owns                                         | Status |
| --------------------- | -------------------------------------------- | ------ |
| `UIController`        | Shop, Coins, Brains, Speed, Hearts, Level, Settings, Inventory, Index, Magnet, Damage meter, field Brainrot / monster inspect, Rewards, Unlock / Monster intro / Mechanic intro / Game Over, Progression Store | ✅ M3–M4, M8, M13, M18 |
| `CoinController`      | Ground-coin pickup intent (`CollectCoin`)    | ✅ M3  |
| `BrainrotController`  | Brainrot action sound feedback (`BrainrotAction`) | ✅ M5/M12 |
| `CombatController`      | Combat hit/death visuals (`CombatVisual`)         | ✅ M7 |
| `AudioController`       | BGM, ambient, SFX + Settings volume/mute hooks    | ✅ M12/M13 |
| `GridController`      | Hover highlight + tile resolver for previews | ✅ M2  |
| `PlacementController` | Selection, ghost preview, placement intent   | ✅ M4  |
| `CameraController`    | Default 3rd-person camera (reserved for juice)| ✅ M1  |
| `InputController`     | Centralized mouse/touch/keyboard intent (magnet **1**) | ✅ M4  |

---

## Panels

- **Coins** ✅ M3 — mid-left glyph + amount (no plate/chip); floating ±N on collect/spend.
- **Brains** ✅ M13 — glyph + amount under Coins on the left edge; from
  `ProfileUpdated` / `RequestState` (`profile.brains`).
- **Speed** ✅ M18 — glyph + WalkSpeed under Brains on the left edge.
- **Hearts** ✅ M13 — five house hearts at top-left (no chip).
  Left-edge HUD order: Hearts (top) → gap → Coins / Brains / Speed (mid-left) →
  gap → Inventory, Index, Upgrades, Settings in one bottom-left row
  (icon on top, name under it; no plate). **Magnet** is a smaller square
  at **bottom-center**. Day / Start Day stays bottom-right. **Damage meter** sits
  upper-right (**Damage** title above Brainrots / Monsters tabs; height follows
  ranked rows).
- **Shop** ✅ M4 / M13 — top-center placement bar shows **equipped** Brainrots
  only (loadout from `ProfileUpdated` / `SetEquipped`). Cards remount only when
  the equipped list changes — XP / kill `ProfileUpdated` ticks restyle in place
  so a click is not dropped. Each card mounts a
  3D model preview via `BrainrotPreview` (`Assets.Brainrots` / `modelId`).
  **VFX Off** swaps those previews for flat color swatches. **Low** and **High**
  keep the 3D preview. Low and Off freeze the evolution gleam (color stays, the
  slash does not travel). Inspect portraits stay 3D on every setting.
  Cards use wider gaps, thinner outlines, and pulled-back previews (no nested
  stroke on the viewport) so the row stays readable.   Names and costs use
  outlined title text (same as HUD) so they stay readable. A card with no claimed
  evolution stays yellow (green while selected). Once a tier is claimed, the
  background uses that rarity’s saturated aura and the inspect-card gleam
  (`TextShine.applyPanel`; GOD uses the rainbow panel).
  Units with `maxOnPlot` (Ballerina) show a live **n/max** count under the name
  (`2/10`); card and shop size stay the same. Long names wrap the rest under the first word (card width unchanged). Framing uses visual AABB
  + optional `previewFocusOffset`; animated rigs stay posed (no idle playback
  in the ViewportFrame). After planting, the card
  shows a **recharge overlay** (`PlantCooldownsUpdated`; cheaper units recharge
  faster — see `BrainrotConfig.plantCooldownFor`).
- **Plant toasts** ✅ — stacked messages just under Shop when a plant fails
  (not enough coins, occupied tile, day not started, still recharging, …). Newest stays under the
  shop; older ones slide up and fade.
- **LevelUI** ✅ M8 — bottom-right Start **Day**, progress, big-wave banner
  (player copy uses "Day"; remotes stay `StartLevel` / `LevelStateChanged`).
  After Start Day, red bold **“Day starting in 3”** sits above the panel and
  counts down to 0, then hides when the day goes Active.
- **Settings** ✅ M13 — bottom-left bare icon + name opens the
  modal. Mute,
  music/SFX volume, Brainrot SFX toggle, **VFX** (**High** / **Low** / **Off**).
  High is full combat effects and a moving shine. Low simplifies combat effects
  and stops the shine. Off also turns shop, inventory, and index portraits into
  color swatches. Inspect portraits stay 3D on every setting. Statistics, **Danger Zone → Reset
  Progress** (red button, **two confirmations**). Confirmed reset → Day 1,
  empty lawn, coins = 125 (`SaveService.resetProgress`). Statistics come from
  `ProfileUpdated` / `RequestState`. Opening Settings re-pulls state so time
  played stays current. Day Select is deferred to a future dedicated UI.
- **Magnet** ✅ — smaller square HUD chip at **bottom-center**
  (magnet icon, **Lv. N**, hotkey **1**). Starts at level **1** (max **5**).
  Press **1** or click the chip during an **Active** day to pull landed coins
  toward the player for **5s**, then cooldown (**90s** at level 1 → **20s** at
  level 5, linear). Pull range is world Chebyshev from the player:
  **1.2 tiles** at level 1, **+1/5 tile per level**, **2 tiles** at level 5
  (`MagnetConfig.rangeTilesFor`). Rings spawn at that outer radius and collapse
  inward (`VfxUtil.playMagnetWaves`). If the day ends while the magnet is on
  cooldown (or still in its 5s window),
  the remaining cooldown **pauses** — the HUD timer does not tick during
  Victory / Defeat / Preparation — and **resumes** when the player starts the
  next day (Countdown or Active). Rejoin still drops in-memory cooldown.
  Server owns cooldown (`ActivateMagnet` /
  `MagnetStateChanged`). Upgrade ranks
  at the HUD **Upgrades** shop (`ProgressConfig.UPGRADE_CATALOG` Magnet).
- **Damage meter** ✅ — upper-right board titled **Damage**, with **Brainrots** /
  **Monsters** tabs under the title. Collapsed shows the title and those tabs;
  clicking a tab expands the list (click the active tab again to collapse).
  Expanded height follows ranked rows (scrolls after
  `DAMAGE_METER_VISIBLE_ROWS`). Each row is **name** (left) and **damage**
  (right), then a capsule bar scaled against the current tab’s leader. Brainrot
  ranks are HP to monsters; monster ranks are HP-equivalent chew / arrow hits
  on plants. Damaging Brainrot abilities (knives, bats, bubbles, Bombardino
  bombs, pierce / fifth-strike / execute leftover HP) all pass a
  `sourceBrainrotId` so they rank. Server-owned (`DamageMeterService` /
  `DamageMeterUpdated`); resets
  on Start Day. Display only.
- **Inventory** ✅ M13 — bottom-left bare icon + name (left of Index) opens the
  loadout modal; a
  PvZ-style **seed packet grid** (portrait + name plate + status ribbon) for
  unlocked Brainrots (max `ProgressConfig.MAX_EQUIPPED`). Only unlocked
  entries appear — locked starter-roster Brainrots are simply absent until
  their unlock day clears (see `BRAINROTS.md`). Packet ViewportFrames remount
  only when unlocks change — XP ticks update inspect bars in place.   **Click** a packet to inspect
  it: stats and evolution rows open on a card to the **right** of the modal
  (same layout as the field inspect card), with **Equip** /
  **Equipped** at the bottom. Equipped packets keep a green ribbon; clicking
  Equipped unequips unless it is the last unit in the loadout. The inspect
  header puts **name, an HP bar** (`current / max` inside the bar), **current
  Brainrot level, and an XP bar** (`current / needed` for the next level,
  inside the bar) beside the portrait. The card fill is **white** until a
  rarity is claimed; then it uses that rarity’s title color with a
  top-left → bottom-right gleam (`TextShine.applyPanel`: quick slash, then 3s
  rest; shared Heartbeat).
  **Stats** (cost, damage, atk. speed,
  range, coins / trap / freeze / recharge, ability — `BrainrotInfo.statRows`,
  Epic numbers after claim) and
  **Current Evolution** sit below: a white **Common** row (always unlocked,
  the unit’s current ability) then Epic → God. Rows below the Brainrot
  level gate stay gray. At the gate the tab uses a **light rarity fill**, the
  `Epic - level 10` (etc.) line is a **shiny dark rarity color**, and the
  name / kind / description are a **lighter rarity color**. Until the player
  spends brains to claim (`EvolveBrainrot`, costs in `TIER_BRAINS`), a
  **lock** sits on that row. Click it to open a confirm prompt (Evolve /
  Cancel). Claimed rows drop the lock. **Epic** stats apply on claim (HP bar
  / plant recharge); **Legendary** extras and **Mythic** / **Immortal**
  passives tick in
  combat. Planted Epic+ units get a rarity-tinted aura (purple / gold /
  red-orange / dark red / rainbow). GOD ultimates: Tung Tung
  **Sahur's Wrath**, Ballerina **Jackpot**, Chimpanzini **Primal Retaliation**,
  Lirili **Glacial Dominion**, Cappuccino **Shadow Requiem** ✅; Tralalero 🔜
  (`Shared.Evolutions` + `EvolutionConfig`). Built from
  `Client.Utilities.BrainrotInfo` (display-only text keyed by ability id,
  resolved from the same `Shared.Brainrots` registry). **Clicking a planted
  Brainrot on your lawn** opens the same inspect card on the right of the
  screen, with live **HP** (`Health` / `MaxHealth`; updates as it takes
  hits). Remaining **Banana Bastion** shield (`ShieldHp`) **paints the
  rightmost 500 of the current green fill blue** (body HP is unchanged;
  when the shield drops that slice is green again). **Banana Bastion** wraps
  the plant in a translucent blue ForceField bubble; **Tenfold Guard**
  (`orbitShield`) orbits a small `Assets.Projectiles.Shield` instead. No Equip button on the field card. No close X — dismiss by clicking
  empty lawn, shovel, a shop seed, or closing Inventory. **Clicking a monster
  on your plot** opens a matching right-side card (`MonsterInspect`): portrait,
  live HP, stats, ability blurb — no evolutions, XP, or Equip. Opening one
  lawn card hides the other. Server validates
  equip changes via `SetEquipped`. Loadout **cannot** change while the day is
  **Active** (server reject + inventory packets / Equip button locked).
  Every planted Brainrot shows a world nameplate (full name, claimed
  rarity with shine on Epic+, `Lv. N`) via `BrainrotController/Nameplate`.
- **UnlockPopup** ✅ — decently-sized center-screen celebration the first time
  a Brainrot is introduced (portrait, name, stat summary, ability blurb,
  dismiss). Starter trio (Ballerina / Tung Tung / Chimpanzini) has **no**
  intro. The other four after first **clear** of their unlock day
  (`UNLOCK_SCHEDULE` → `reward.unlockedBrainrotId`); Girafa / Patapim on
  **reach** (`BRAINROT_INTRO_SCHEDULE`). Queued so several intros play one after
  another. Server-decided; UI is display-only.
- **MonsterIntroPopup** ✅ — same cartoon modal for every campaign monster /
  boss the first time the player **reaches** its intro day (or catch-up if
  they skip ahead). `ProgressConfig.MONSTER_INTRO_SCHEDULE`: Goblin 5, Goblin
  Elite 10, Vampire 15, Duke Vampire 20, Spider 25, Queen Spider 30,
  Skeleton 31, Werewolf 35, Small Mummy 41, Scorpion 45, Pharaoh Mummy 50.
  Driven by `introducedMonsterIds` on `LevelStateChanged`; portrait via
  `MonsterPreview`, stats/abilities via `MonsterInfo`. Persisted in
  `SaveData.introducedMonsters` so it only fires once.
- **MechanicIntroPopup** ✅ — same cartoon modal the first time the player
  **reaches** a mechanic intro day. `ProgressConfig.MECHANIC_INTRO_SCHEDULE`:
  Graves on Day 31. Copy explains destroying graves with **Brr Brr Patapim**
  (Grave Buster) and hitting monsters behind them with Cappuccino's
  **Piercing Brew** (Legendary evolution). Driven by `introducedMechanicIds`
  on `LevelStateChanged`; persisted in `SaveData.introducedMechanics`.
- **GameOverPopup** ✅ — full-screen defeat overlay when hearts hit 0: slow
  **GAME OVER** reveal, “You have failed to protect Triple T and his house.”,
  and **Rewind Day N**. Clicking Rewind plays a translucent clock spin, fades
  the overlay, and fires `RewindDay` (server → Preparation on the failed day
  with `REWIND_COINS` 200).
  with the victory-checkpoint lawn already restored).
- **RewardPopup** ✅ M13 — victory overlay: day-clear brains, leftover-gold
  brains (smaller), and a large **Total Brains Earned**. After the title, those
  lines and **Continue** scale-pop in one at a time (no fade). Stays until
  **Continue** (`ContinueVictory`); then unlock intros may play.

### Index ✅

- **Index** — HUD button (icon + name) opens a catalog of **every** Brainrot
  and Monster. **Brainrots** / **Monsters** tabs. Units you have encountered
  show a portrait and name. Units you have not met yet are a **black
  silhouette** with **?** / `???`. Encountered Brainrots = unlocked or
  intro-shown (`unlocks` / `introducedBrainrots`). Encountered Monsters =
  intro-shown (`introducedMonsters`) plus Day 1 species (Zombie has no intro).
  Necromancer / GoblinKing stay silhouettes until they appear. Display-only.

### Milestone 18 — Progression Store ✅

- Talk to the **Brainrot shop** stall (Tung Mascot, blue mini store) beside
  your house. HUD **Upgrades** sits in the bottom-left row with Inventory /
  Index / Settings. Physical upgrade stall is gone.
- Overlay lists `STORE_CATALOG` (Girafa Celestre) / Speed upgrades. Owned
  Brainrots gray out with a red **SOLD** stamp. Clicking a row opens a
  **stats card** to the **right** of the shop (description, stats, buy/cost at
  the bottom, X to close). Clicking another row replaces the card. Buys play kaching + red `-{cost}`
  on the brains HUD and a green “Purchased Successfully!” float. Broke
  buys play an error SFX and a red “Purchase Unsuccessful…” message above the
  Buy button. Repeat fails stack (new on top; older slide up and fade faster).
  Brainrot buys require standing at your stall; HUD Upgrades require owning a plot.

See `docs/STORE.md`.

---

## Placement flow (Milestone 4) ✅

- **`InputController`** → `primaryAction` (ignores GUI-processed input);
  `magnetAction` on key **1**.
- **`PlacementController`** → ghost + `PlaceBrainrot` / shovel remove. Client
  pre-checks coins/occupancy and shows a plant toast on failure; the server still
  validates and may fire `PlaceBrainrotFailed`.
- Shop selection and planting are allowed in **Active** (after the 3…0 Start
  Day overlay). Planting matches `LevelService.isLevelActive`.
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
