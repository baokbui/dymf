# BVM Progression Stores

The **Brainrot shop** is a physical stall beside each plot house. **Upgrades**
are a section in the shared Menu. The overlay is display-only. Spends are
**server-authoritative** (`ProgressService`).

Status: ✅ Milestone 18

---

## HUD

The bottom-left Menu button opens one window with seven sections. Store-related sections:

| Button | Opens |
| ------ | ----- |
| Inventory | loadout |
| **Index** | encountered Brainrots / Monsters catalog |
| **Upgrades** | `UPGRADE_CATALOG` |
| Settings | settings modal |

Click Menu again, its X, or outside the window to close. Selecting another
section replaces the current page. A field inspect card closes Menu.

Talk to **your** Tung Mascot at the blue mini store to open the Brainrot
catalog. Upgrades are Menu-only (no red mini store).

Templates live in `ReplicatedStorage.Assets.Stores`. If they are still under
Workspace `Progression Stores` on Play, the server **moves** them into Assets
and clones the Brainrot stall per plot.

Tune `YARD_OFFSET_X` and `DOOR_RIGHT_Z` in `StoreConfig`.

---

## Shops

| Store | Where | Currency | Sells |
| ----- | ----- | -------- | ----- |
| Brainrot shop | Plot stall (`Tung Mascot`) | Brains | `STORE_CATALOG` (Girafa Celestre, Orangutini Ananassini, La Vacca Saturno Saturnita, Blueberrinni Octopusini, Boneca Ambalabu) |
| Upgrades | Menu → **Upgrades** | Brains | Player upgrades (`ProgressConfig.UPGRADE_CATALOG`) |

Starter-roster Brainrots (Day 1 + clear Days 3/5/7/9) and **Brr Brr Patapim**
(reach Day 31) are **not** sold here. The shop sells **Girafa Celestre**, **Orangutini Ananassini**, **La Vacca Saturno Saturnita**, **Blueberrinni Octopusini**, and **Boneca Ambalabu**. Buy Girafa
early with brains, or get her free on reach Day 25. Orangutini, La Vacca, Blueberrinni, and Boneca are store-only.
Already owned units gray out with a red **SOLD** stamp.

| Brainrot | Brains | Notes |
| -------- | ------ | ----- |
| Girafa Celestre | 50 | Fog gust; still free on reach Day 25 |
| Orangutini Ananassini | 80 | Lobs a pineapple over the front monster and graves |
| La Vacca Saturno Saturnita | 60 | One-shot: pulls one legal monster from each neighboring row; normally 1-tile only, Immortal allows 2; GOD replaces the pull with Black Hole |
| Blueberrinni Octopusini | 70 | Ink puddle on a random empty tile in her row, skipping graves; lower arc when close, higher when far; slows while they stand in it |
| Boneca Ambalabu | 65 | Headbutts each monster on her tile in front of her (hit + 1 second stun); poofs away after 5 headbutts |

The Upgrade Shop shows your brains balance and a card for each upgrade.
Cards show the current level, progress toward the cap, and the next price.
Selecting a card opens current and next stat values with the purchase button.
Maxed upgrades show a Max Level badge and their final stats.

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
| `UIController` | Menu Index / Upgrades; physical ProgressionStore overlay |
| `UIController/ProgressionStore` | List rows open a stats card (desc + buy) |
| `StoreController` | Hide Talk prompts on other players' stalls |
| `PlotService` | Applies `ProgressService.getWalkSpeed` on spawn |

Talk prompts only appear on **your** stall. `BuyStoreItem` for Brainrots also
requires the caller within `CLOSE_DISTANCE` of **their** stall. Menu Upgrades
only require owning a plot.

Walking farther than `StoreConfig.CLOSE_DISTANCE` from the mascot closes the
Brainrot overlay. Upgrades close when Menu is dismissed or another section opens.
The same store view detaches from Menu for the physical Brainrot catalog and
remounts for Upgrades; purchase/range checks remain on the server.

Remotes: `OpenProgressionStore` (server → client, `shopKind` + mascot
`Vector3` for the stall), `BuyStoreItem` (client → server),
`StorePurchaseSucceeded` / `StorePurchaseFailed` (server → client).
Success: kaching SFX, red `-{cost}` on the brains HUD, green “Bought!” banner. Not enough brains: error SFX
(`AudioConfig.PurchaseError`) and a red “Not enough Brains.” banner
**above the Buy button**. Repeat fails stack: the new banner sits on top
while older ones slide up and fade out faster. Profile refresh via
`ProfileUpdated`.

## Free Brainrot tickets ✅

The final first-time reward grants a saved ticket. Unowned store units offer
Use ticket alongside their paid button. `BuyStoreItem.useTicket` is optional
boolean intent; the server revalidates catalog, playable/owned status, shop
ownership/range and ticket count. SaveService commits ticket spend and unlock
together before success, charging zero brains. A ticket cannot buy campaign
units or upgrades. It has no expiry. Paid store purchases return a saving/busy
error while a profile transaction is active, preventing upgrade grant races.
