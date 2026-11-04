# BVM UI

UI **only displays state** and forwards player intent. It performs no gameplay
logic — all calculations happen on the server (`AGENTS.md`).

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
        Menu         (shared feature window (selected sections only))
        MenuEntry    (bottom-left Menu/X HUD button)
        MenuDrawer   (animated horizontal strip of seven icon/name buttons)
        FirstTimeRewards (standalone temporary reward window)
        FirstTimeRewardsEntry (gift HUD button above Menu until completion)
```

`UIController` builds each panel at runtime (except scaffolding frames).
MenuRouter hosts Inventory, Index, Upgrades, Settings, Quests, Achievements
and Statistics in one window. Existing panel instances are reused;
Inventory/Index/Settings/ProgressionStore move into its content host at runtime.
The physical Brainrot store can detach the shared ProgressionStore view and
open independently at the owned stall.

---

## Visual theme ✅

All HUD panels share a **cartoon thick-outline** look from
`ReplicatedStorage.Shared.Config.UITheme` (also `Config.UI`):

- Solid panel / chip fills — same rounded-corner + thick black `UIStroke`
  geometry everywhere, but each HUD piece gets its own saturated "candy" color
  so the screen doesn't read as one wall of blue: Day/Start Day panel and Shop
  dock stay cool blue (the reference look), Coins / Brains / Speed are bare
  glyphs + amount (no plate or chip), Hearts are bare glyphs (no chip), Inventory /
  Index / Upgrades / Settings retain their panel styles inside Menu; the HUD
  has one bare Menu icon + name. Magnet is red,
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
  gap → one Menu button at bottom-left (icon above name; no plate). Menu
  contains all eight navigation sections. **Magnet** is a smaller square
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
- **Settings** ✅ M13 — the Settings section of Menu opens the
  modal. Mute,
  music/SFX volume, Brainrot SFX toggle, **VFX** (**High** / **Low** / **Off**), and **Other plots** (**On** / **Off**). The VFX hint reads: “High shows all effects. Low shows fewer. Off turns effects off, but keeps the colored outline on your Brainrots. Weaker PCs should use Low or Off.” Other plots: “Off hides Brainrot effects on other players' plots. Your plot stays the same. Turn this off for better performance if you need it.”
  Behind that: High is full combat effects and a dense aura; Low thins the aura and freezes shine; Off clears aura flames (outline stays) and swaps shop, inventory, and index portraits to color swatches. Inspect portraits stay 3D. **Danger Zone → Reset
  Progress** (red button, **two confirmations**). Confirmed reset → Day 1,
  empty lawn, coins = 125 (`SaveService.resetProgress`).
- **Statistics** ✅ — a separate Menu tile. Displays days cleared, Brainrots
  placed, monsters defeated, total brains earned (number + brain icon), time
  played, owned/equipped Brainrot type counts, and Speed/Magnet upgrade ranks.
  Uses existing `ProfileUpdated` / `RequestState` data with no new save fields.
  Opening Statistics refreshes the profile so time played stays current. Day Select is deferred to a future dedicated UI.
- **Magnet** ✅ — smaller square HUD chip at **bottom-center**
  (magnet icon, **Lv. N**, hotkey **1**). Starts at level **1** (max **5**).
  Press **1** or click the chip during an **Active** day to pull nearby coins
  toward the player for **5s**, including coins still falling or mid-spit, then cooldown (**90s** at level 1 → **20s** at
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
- **Inventory** ✅ M13 — the Inventory section of Menu opens the
  loadout modal; a
  PvZ-style **seed packet grid** (portrait + name plate + status ribbon) for
  unlocked Brainrots (max `ProgressConfig.MAX_EQUIPPED`). Only unlocked
  entries appear — locked starter-roster Brainrots are simply absent until
  their unlock day clears (see `BRAINROTS.md`). Packet ViewportFrames remount
  only when unlocks change — XP ticks update inspect bars in place.   **Click** a packet to inspect
  it: stats and evolution rows open on a card to the **right** inside Menu
  (a separate detail page with Back when the available width is narrow)
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
  red-orange / dark red / rainbow). **High** shows the full flame column, **Low**
  a thin core, and **Off** no flames — the rarity outline stays on every setting. GOD ultimates: Tung Tung
  **Sahur's Wrath**, Ballerina **Jackpot**, Chimpanzini **Primal Retaliation**,
  Lirili **Glacial Dominion**, Cappuccino **Shadow Requiem**, Tralalero **Abyssal Torrent** ✅.
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
  live HP, level, stats, ability blurb — no evolutions, XP, or Equip. Opening one
  lawn card hides the other. Server validates
  equip changes via `SetEquipped`. Loadout **cannot** change while the day is
  **Active** (server reject + inventory packets / Equip button locked).
  Every planted Brainrot shows a world nameplate (full name, claimed
  rarity with shine on Epic+, `Lv. N`) via `BrainrotController/Nameplate`.
  Every monster shows a world nameplate (species name, `Lv. N` = current day)
  via `CombatController/MonsterNameplate`. The level line shows on **VFX High**
  only; **Low** and **Off** keep the name and hide the level.
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
  **Goblin King** is introduced when the Hidden Day starts (after Day 40 is
  cleared), not from this reach schedule.
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
  The victory-checkpoint lawn is already restored.
- **RewardPopup** ✅ M13 — victory overlay: day-clear brains, leftover-gold
  brains (smaller), and a large **Total Brains Earned**. The Hidden Day uses
  the same overlay titled **Hidden Day**, with **Brains earned** for kills
  (win or loss). After the title, those
  lines and **Continue** scale-pop in one at a time (no fade). Stays until
  **Continue** (`ContinueVictory`); then unlock intros may play.

### Index ✅

- **Index** — HUD button (icon + name) opens a catalog of **every** Brainrot
  and Monster. **Brainrots** / **Monsters** tabs. Units you have encountered
  show a portrait and name. Units you have not met yet are a **black
  silhouette** with **?** / `???`. Encountered Brainrots = unlocked or
  intro-shown (`unlocks` / `introducedBrainrots`). Encountered Monsters =
  intro-shown (`introducedMonsters`) plus Day 1 species (Zombie has no intro).
  Necromancer stays a silhouette until he appears. Goblin King is encountered on
  the Hidden Day after Day 40. Display-only.

### Milestone 18 — Progression Store ✅

- Talk to the **Brainrot shop** stall (Tung Mascot, blue mini store) beside
  your house. **Upgrades** is a Menu section. Physical upgrade stall is gone.
- Overlay lists the five `STORE_CATALOG` units / Speed and Magnet upgrades. Owned
  Brainrots gray out with a red **SOLD** stamp. Clicking a row opens a
  **stats card** to the **right** of the shop (description, stats, buy/cost at
  the bottom, X to close). Clicking another row replaces the card. Buys play kaching + red `-{cost}`
  on the brains HUD and a green “Bought!” float. Broke
  buys play an error SFX and a red “Not enough Brains.” message above the
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

M20 QuestController registers Quests and Achievements as
separate Menu sections, sharing existing reward views: Daily Quests / Weekly Quests tabs with three objective bars, completion
bonus, brains rewards, Claim/Claimed states, UTC countdown, and success/error
SFX. Initial state comes from UIController via cached UIEvents; updates use
RetentionUpdated. The Menu dismissal layer is transparent, so opening it
does not darken the game. A standalone First-time Rewards window displays seven
one-time mixed-reward slots, today's claim state and a next-reward preview. The panel
scales to the viewport and never auto-opens during combat. Challenge and
spinner UI remain planned. Achievements shows
five permanent milestones in a padded scrolling list and one server-selected
next goal above it. Completed rewards use the same Claim/Claimed feedback.
The goal can open an owned Brainrot's existing inventory details or dismiss
the window for campaign play; it never purchases or starts a day automatically.
The Menu entry and relevant section show pending-reward badges. The restored
visual style and all server-backed behavior remain unchanged.

## Unified Menu navigation

`Client.Utilities.MenuRouter` owns the single window, HUD entry, seven sections,
page visibility, badges and responsive fitting. `UIController.MenuPages` adapts
the existing Inventory/Index/ProgressionStore/Settings APIs; QuestController
registers Quests and Achievements. First-time Rewards has a separate HUD entry
and window, outside the Menu. Opening a section closes the previous one and its details.

The HUD Menu button morphs from three bars into an X and slides out seven bare
icon/name buttons to its right. There is no large blue launcher or 3 × 3 grid.
`MenuDrawer` animates reveal/retraction over 0.24 seconds; repeated toggles cancel
previous tweens safely. The compact strip uses desktop scaling and horizontal
scrolling if the screen cannot fit all seven icons. The existing four textures
and quest/achievement/statistics illustrations are reused. Selecting an icon opens or switches its feature while the strip stays open. There is no top-left Menu button in feature windows. X/close resets the HUD button to its Menu appearance.
The strip does not add a full-screen blocker during normal gameplay.

Selected features use one panel surface: the host takes the feature's color
and fits its authored dimensions; the embedded root fill/outline are hidden.
The launcher title is hidden while viewing a feature, leaving its own title
and close navigation. Detached physical shops restore their original
fill and outline. Reward badges appear on tiles and the HUD entry. Index, Settings, Achievements
and Statistics own their internal scrolling: the Menu viewport does not scroll
around them, and their root height fits the available space. Other content scrolls vertically
when needed instead of shrinking long pages to the screen height. Wide
inventory/upgrade views keep right-side details; narrow views show those cards
inside Menu with Back. Close and click-outside dismiss the entire Menu. Four transparent hit regions
cover only the area outside the window; clicks on panel content or blank
panel space cannot activate dismissal. Day
results close it; results and intros render above this optional window.

The physical Brainrot shop still opens through the owned stall and retains its
range-close behavior. It detaches the shared store view, restores its standalone
close button/scale, and remounts when Upgrades is selected again. No ownership,
purchase validation, currency, claims or save behavior moves into MenuRouter.
Settings retains its deferred state refresh. Goal links open Inventory directly
inside Menu. `tests/MenuIntegration.spec.luau` contains 207 isolated checks for
navigation, badges, single-surface hosting, detail cleanup, narrow layout, store
detach/remount and day results. All 207 checks passed in an isolated Edit-mode rerun, including single-surface
hosting and dismissal regions remaining outside the panel. The updated Rojo
build passes. Remotes/player data are mocked;
real device/gameplay QA remains open.

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

Reward amounts in Quests and Achievements use the shared
`BrainAmount` utility: number followed by texture `12691330734`. Saving/claimed
labels hide the icon. The footer starts blank; there is no “Rewards are Brains!”
copy. Only the daily/weekly quest sections show their own UTC reset timers; permanent Achievements
do not reset. Next-goal titles use plain text without a trailing glyph.

First-time rewards show a centered icon above a caption such as `+4 brains`
or `+1 magnet level`. Speed and Magnet reuse their HUD textures. The free
Brainrot ticket has a native UI ticket illustration with a brain emblem.
Claimed cards use a gray fill while retaining the icon and caption, with a red rotated Claimed stamp
over the day heading. There is no DONE text, intro sentence or next-day preview;
the claim button is hidden after today's reward is collected. Steps 2/6 are Speed
levels, step 4 a Magnet level (maxed upgrades pay 10 brains), and step 7 a
free Brainrot ticket. The finite track ends with Completed, hides its timer,
and never transitions to a recurring weekly login reward. Quests is the Menu
tile for Daily Quests / Weekly Quests; Monday UTC reset is shown on the weekly
tab. Physical store stats expose a separate Use ticket button when tickets
are available, preserving the ordinary paid purchase option.

## Temporary First-time Rewards HUD entry

`QuestController.FirstTimeRewards` reuses LoginRewardsPanel in its own window.
A gift button above the bottom-left Menu button opens/closes it. The button is
hidden until authoritative login state loads, remains visible between claim dates,
and shows a ready badge only when a reward can be claimed. The button and window
disappear after `login.finished` confirms all seven rewards have been collected;
completed profiles keep it hidden on rejoin. No First-time Rewards Menu tile remains.
The panel is a wide horizontal window with all seven reward cards in one row.
On narrow screens, the cards scroll horizontally instead of wrapping or shrinking
their text. Opening the panel centers the current reward when scrolling is needed.
The panel fits the viewport, has an X, and closes on outside clicks only.
`OutsideDismiss` shares the four outside hit regions with Menu, so blank panel
space does not dismiss either window. Opening Menu, a physical store, an inspector
or day results closes the standalone reward panel; opening rewards closes peer
panels. Claim feedback stays in the panel that requested the claim.

## Desktop readability and responsive scaling

`Client.Utilities.UISizing` scales top-level HUD/widgets from a 1536 × 864
reference, up to 1.5× on larger displays. Scale is the smaller viewport ratio,
never an automatic enlargement on phones. Large widgets are bounded to the
available viewport; anchors stay at their intended screen edges and authored
offsets scale with the widget, preserving currency/entry spacing. Changes use
size/parent events, not frame polling. Windows are fitted independently of their
full-screen dismissal layers. Menu layout converts physical pixels back to
logical units, so pages are not scaled twice when hosted.

The planting bar now uses 84 × 110 cards with larger portraits, 12px baseline
names, and clearer cost/count text. Desktop scaling enlarges these further.
The damage board uses a 270px baseline width, larger tabs and 44px ranking rows.
Menu, inspectors, shop panels, reward popups, HUD icons and amounts all use the
shared sizing path. The Menu hamburger uses native UI bars to avoid missing-font
glyphs. None of these changes affect combat or VFX quality.

First-time Rewards uses the shared desktop scale with a wider horizontal row.
Its height follows visible content: 280 logical pixels after today's claim,
336 when the claim button is needed, and extra room only for actual feedback.
Empty feedback and the hidden claim button reserve no bottom space. These
values include the header, card strip and even outer margins.

`tests/UISizing.spec.luau` passes 17 isolated assertions covering baseline,
1080p, 2260 × 1163, 1440p and capped 4K scaling, edge bounds, repeated setup,
wide-widget fitting and nested-page scaling. The Menu fixture passes 109 checks,
including compact reward height. Actual device visual/battle QA remains open.

## Shovel cursor and scaled toolbar

Shop and PlacementController reuse `Client.Utilities.ShovelIcon` with texture
`123683019299968` (catalog asset `129146573433376`). The passive ImageLabel uses
Fit scaling with no background; the procedural handle/grip/blade are removed.
The passive ShovelCursor is marked `ScreenSpaceUI` before parenting. UISizing
excludes such objects from automatic scale/position transforms. Raw mouse/touch
screen coordinates subtract the GUI inset once before positioning the cursor;
the initial mouse location uses the same path as subsequent movements.

Shovel removal first resolves a clicked planted model to its own row/column and
verifies it matches PlotUtil's local Brainrot. It falls back to an occupied tile.
The existing Active-day gate and server removal validation remain authoritative.
Cancelling restores the normal mouse icon. `tests/Shovel.spec.luau` passes ten
isolated checks for geometry, pointer position, own/foreign/empty targets and
cancellation; the sizing fixture verifies that the cursor is not scaled.

## Right-side quest tracker

`QuestController.QuestTracker` shows a compact progress panel with one Daily/Weekly heading toggle between Damage and the Day/Start Day panel, aligned with Damage's right
edge. Three objectives plus the all-three bonus share `QuestPresentation` rows
with the full quest view. It displays server progress as outlined text. Only
the single heading is clickable: Daily Quests becomes Weekly Quests on click,
then switches back on the next click; there is no View Quests or claim shortcut. The Menu Quests tile still
opens the full claim view, and its badge includes the all-three bonus.

The tracker sits directly above Start Day with a 12px logical gap. It moves up to reserve countdown/wave-warning space only while those messages are visible. The heading includes a cycle icon; clicking anywhere on that heading switches Daily/Weekly. The tracker uses HUD absolute bounds and desktop scaling, with no polling.
Damage expansion/day-panel height changes refit the available gap. A shorter gap
scrolls the objectives; a very short gap shows the heading only. If less than
80 logical pixels remain, the tracker hides instead of overlapping other HUD;
full quests remain accessible from Menu. It reserves space above the day panel
for countdown/wave messages. `tests/MenuIntegration.spec.luau` now passes 109
checks, including tracker progress and collapsed/expanded Damage geometry.

The compact quest tracker is text-only: panel/card/button fills, border strokes,
progress-bar graphics and scrollbar visuals are fully transparent. Headings and
progress counts remain opaque with dark text outlines for world readability.
The heading stays white with a dark outline. Its click target and scrolling
remain functional; refresh/tab changes preserve transparency. This affects only
the right-side tracker, not the full quest window.

Newly completed tracker objectives briefly turn green, then slide right and
fade over 0.45s after a 0.35s hold. Completed rows leave the list and remaining
rows move up. Already-complete objectives are hidden on initial state/tab return
without replaying; daily/weekly period changes reset the local presentation.
This is cosmetic only: rewards are not auto-claimed, and the full Menu quest
view retains completed objectives and claim buttons. Tween connections are
cancelled when rows are reused or the tracker is destroyed. The Menu integration
fixture verifies one tracker heading button and completion/refresh behavior.

## Compact layout and scroll review

Desktop scaling is moderated to 1.25× at 1920 × 1080 and capped at 1.5×; font
sizes stay intact while planting cards use slightly tighter 84 × 110 geometry.
The tracker has 34px objective rows with 5px gaps and one centered heading with cycle texture 86604833779310 to indicate switching.
Menu icon captions remain white after selection, with no name highlighting.
The drawer fits before the magnet button, reducing its icon scale slightly if
that fits all seven without shrinking below their readable baseline; genuine
horizontal overflow still scrolls.

`ScrollPolicy` monitors all MainUI scrolling frames (including later-created
views). Bars hide when their axis fits within a 3px rounding tolerance or the
wrapper cannot scroll. Real overflow restores the authored thickness. Explicit
zero-thickness text-only views stay hidden. Vertical padding is symmetric when
there is no scrollbar, and reserves a gutter when one is needed. Scrolling
remains enabled for mouse/touch where the feature itself allows it.

Inventory now uses automatic canvas sizing instead of writing measured pixel
heights back into a scaled canvas. Inventory and Upgrades join other Menu pages
in owning their internal scroll regions; inspect cards with their own scroll
bodies fit available height. The outer wrapper is retained only for actual
plain-card overflow. Settings hint heights/bottom padding are tightened and its
560px baseline height fits its controls. Statistics uses the same baseline
height to fit all nine totals without a needless desktop scrollbar. Long Index,
achievement and evolution content retains necessary scrolling.

Latest checks: 207 Menu/UI integration assertions, 17 viewport assertions,
15 reserved-HUD layout assertions and 7 dedicated scrollbar-policy checks pass, including Settings text fit, Statistics
scrolling, all hosted scrollbars, drawer/magnet separation and compact rewards.
This is an isolated UI/state/geometry review; real-device visual and battle QA
remain open.

Menu fitting no longer adds bottom padding to an already-fitting page. A quest
card that fits uses the viewport height as its canvas, with no artificial
12px overflow. Real overflow in a shorter window still scrolls and keeps its
scrollbar. The Menu fixture checks both fitting and shortened quest windows.

Quests and Achievements use symmetric title bounds centered on their panel.
Their shared view registers per-page Menu fill colors: coral for Quests (Upgrades keeps teal), lavender
for Achievements. The Menu content host has equal 6px side gutters so centering
does not inherit an extra left offset. Index keeps its four-column grid with
a narrower, inset vertical scroller and a content gutter between cards and bar.
The 207-check UI fixture validates title centers, page colors and Index geometry.

`HudLayout` provides a shared physical window rectangle below the planting bar,
above bottom navigation/magnet, and between the currency and right HUD rails.
Menu pages, First-time Rewards, standalone shops/details, inspectors and centered
popups use these bounds. Menu fitting may reduce desktop enlargement toward the
readable 1x baseline to fit a complete page; longer content still scrolls. Bounds
refit from geometry/visibility events, not polling. On very narrow screens where
the rails leave less than 280px, side gutters fall back to screen edges; top and
bottom reservations remain. Full mobile/device QA is still required.

Menu icons and the Menu/X entry remain above the transparent dismissal layer, so
switching sections does not close or block the drawer. Window X, outside clicks,
and the HUD X still close it. Opening standalone dialogs or day results closes
Menu as before. Index removes its native border (the dark line beside the thumb),
clips scroll content, and uses `VerticalScrollBarInset.Always` with a card gutter,
so its vertical scrollbar stays inside the list rather than beside a border.

Additional isolated checks: `HudLayout.spec.luau` passes 15 assertions across
1366x768, 1920x1080 and 2560x1440, including right-side details and planting-bar
resizes. A narrower 1000px fixture verifies Damage shifts below a wide shop bar.
