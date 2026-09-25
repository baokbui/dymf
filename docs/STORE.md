# BVM Progression Stores

The **Brainrot shop** is a physical stall beside each plot house. **Upgrades**
are a HUD button next to Inventory. The overlay is display-only. Spends are
**server-authoritative** (`ProgressService`).

Status: ✅ Milestone 18

---

## HUD

Bottom-left row (icon on top, name under it; no plate):

| Button | Opens |
| ------ | ----- |
| Inventory | loadout |
| **Index** | encountered Brainrots / Monsters catalog |
| **Upgrades** | `UPGRADE_CATALOG` |
| Settings | settings modal |

Click the same chip again (or the overlay X) to close. Opening Inventory,
Settings, Index, or a field inspect card closes the store overlay.

Talk to **your** Tung Mascot at the blue mini store to open the Brainrot
catalog. The upgrade stall is HUD-only (no red mini store).

Templates live in `ReplicatedStorage.Assets.Stores`. If they are still under
Workspace `Progression Stores` on Play, the server **moves** them into Assets
and clones the Brainrot stall per plot.

Tune `YARD_OFFSET_X` and `DOOR_RIGHT_Z` in `StoreConfig`.

---

## Shops

| Store | Where | Currency | Sells |
| ----- | ----- | -------- | ----- |
| Brainrot shop | Plot stall (`Tung Mascot`) | Brains | `STORE_CATALOG` (Girafa Celestre, Orangutini Ananassini, La Vacca Saturno Saturnita) |
| Upgrades | HUD **Upgrades** | Brains | Player upgrades (`ProgressConfig.UPGRADE_CATALOG`) |

Starter-roster Brainrots (Day 1 + clear Days 3/5/7/9) and **Brr Brr Patapim**
(reach Day 31) are **not** sold here. The shop sells **Girafa Celestre**, **Orangutini Ananassini**, **La Vacca Saturno Saturnita**, and **Blueberrinni Octopusini**. Buy Girafa
early with brains, or get her free on reach Day 25. Orangutini, La Vacca, and Blueberrinni are store-only.
Already owned units gray out with a red **SOLD** stamp.

| Brainrot | Brains | Notes |
| -------- | ------ | ----- |
| Girafa Celestre | 50 | Fog gust; still free on reach Day 25 |
| Orangutini Ananassini | 80 | Lobs a pineapple over the front monster and graves |
| La Vacca Saturno Saturnita | 60 | One-shot: pulls one monster from a neighboring row into hers |
| Blueberrinni Octopusini | 70 | Ink puddle on the nearest empty tile ahead; slows while they stand in it |

**Speed** (`WalkSpeed`): 20 levels, each `+walkSpeedBonusPerLevel` (1) on top of
Roblox-default `PlayerConfig.WALK_SPEED` (16 → 36 at max). Costs rise each
level (`6 / 10 / 14 / 19 / 25 / 32 / 41 / 52 / 65 / 80 / 98 / 118 / 142 /
170 / 204 / 245 / 294 / 353 / 424 / 509` brains). Persisted in
`SaveData.upgrades`.

**Magnet**: starts at **level 1** (max **5**). Each rank shortens the post-use
cooldown from **90s** to **20s** (linear) and grows pull range by **1/5 tile**
(world Chebyshev from the player: **1.2 tiles** at level 1 → **2 tiles** at
max). Active pull lasts **5s**. Remaining
cooldown **pauses** when the day ends and **resumes** on Start Day. Costs to
reach 2 / 3 / 4 / 5: **30 / 55 / 90 / 150** brains. Press **1** (or the HUD
chip) on an Active day. See `MagnetConfig`.

---

## Architecture

| Module | Role |
| ------ | ---- |
| `StoreConfig` | Stall template names, yard offsets, prompt copy, shop kinds |
| `StoreService` | Clone Brainrot stall; owner-only Talk → `OpenProgressionStore`; `canPlayerUseShop` |
| `ProgressService` | Validate `BuyStoreItem` (plot + stall range for Brainrots; plot for Upgrades) |
| `MagnetService` | Activate magnet, cooldown (pauses between days), pull coins in level-scaled range |
| `UIController` | HUD Index / Upgrades; ProgressionStore overlay |
| `UIController/ProgressionStore` | List rows open a stats card (desc + buy) |
| `StoreController` | Hide Talk prompts on other players' stalls |
| `PlotService` | Applies `ProgressService.getWalkSpeed` on spawn |

Talk prompts only appear on **your** stall. `BuyStoreItem` for Brainrots also
requires the caller within `CLOSE_DISTANCE` of **their** stall. HUD Upgrades
only require owning a plot.

Walking farther than `StoreConfig.CLOSE_DISTANCE` from the mascot closes the
Brainrot overlay. HUD Upgrades stay open until dismissed.

Remotes: `OpenProgressionStore` (server → client, `shopKind` + mascot
`Vector3` for the stall), `BuyStoreItem` (client → server),
`StorePurchaseSucceeded` / `StorePurchaseFailed` (server → client).
Success: kaching SFX, red `-{cost}` on the brains HUD, green “Purchased
Successfully!” banner. Not enough brains: error SFX
(`AudioConfig.PurchaseError`) and a red “Purchase Unsuccessful…” banner
**above the Buy button**. Repeat fails stack: the new banner sits on top
while older ones slide up and fade out faster. Profile refresh via
`ProfileUpdated`.
