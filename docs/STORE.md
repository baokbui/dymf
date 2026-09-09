# BVM Progression Stores

Each **plot house** gets its own blue + red mini stores in the yard (not a
shared world stall). Players **talk** to **their own** mascots only; the HUD is display-only.
Spends are **server-authoritative** (`ProgressService`).

Status: ✅ Milestone 18

---

## Where templates live

**Do not keep live shops in `Workspace.Progression Stores`.** That is one
copy for the whole map.

| Place | Role |
| ----- | ---- |
| `ReplicatedStorage.Assets.Stores` | **Templates** (like `Assets.Houses`) |
| `PlotN.ProgressionStores` | Clones beside that plot’s cottage |

In Studio: move **Blue Mini Store** and **Red Mini Store** into
`ReplicatedStorage.Assets.Stores`. Names can also be detected by mascot
(`Tung Mascot` / `67 Mascot`). If they are still under Workspace
`Progression Stores` on Play, the server **moves** them into Assets and
clones per plot (session-only unless you save the place).

Tune `YARD_OFFSET_X`, `STORE_SPACING`, `DOOR_RIGHT_Z`, and `FACE_DIRECTION`
in `StoreConfig`. Stalls sit on the **right** of the door, **side by side**
(offset along FACE after template yaw −90), facing the yard on a diagonal
toward the outer sand (`FACE_DIRECTION` +X/−Z).

---

## Shops

| Store | Mascot | Currency | Sells |
| ----- | ------ | -------- | ----- |
| Blue mini store | `Tung Mascot` | Brains | `STORE_CATALOG` (Girafa Celestre only for now) |
| Red mini store | `67 Mascot` | Brains | Player upgrades (`ProgressConfig.UPGRADE_CATALOG`) |

Starter-roster Brainrots (Day 1 + clear Days 3/5/7/9) and **Brr Brr Patapim**
(reach Day 31) are **not** sold here. The shop currently sells **Girafa
Celestre** only — buy her early with brains, or get her free on reach Day 25.
Already owned units gray out with a red **SOLD** stamp.

| Brainrot | Brains | Notes |
| -------- | ------ | ----- |
| Girafa Celestre | 50 | Fog gust; still free on reach Day 25 |

**Speed** (`WalkSpeed`): 20 levels, each `+walkSpeedBonusPerLevel` (1) on top of
Roblox-default `PlayerConfig.WALK_SPEED` (16 → 36 at max). Costs rise each
level (`6 / 10 / 14 / 19 / 25 / 32 / 41 / 52 / 65 / 80 / 98 / 118 / 142 /
170 / 204 / 245 / 294 / 353 / 424 / 509` brains). Persisted in
`SaveData.upgrades`.

**Magnet**: starts at **level 1** (max **5**). Each rank shortens the post-use
cooldown from **90s** to **20s** (linear). Active pull lasts **5s**. Costs to
reach 2 / 3 / 4 / 5: **30 / 55 / 90 / 150** brains. Press **1** (or the HUD
chip) on an Active day. See `MagnetConfig`.

---

## Architecture

| Module | Role |
| ------ | ---- |
| `StoreConfig` | Template names, yard offsets, prompt copy, close distance |
| `StoreService` | Clone beside house; owner-only ProximityPrompt → `OpenProgressionStore` (kind + mascot position) |
| `ProgressService` | Validate `BuyStoreItem` (own plot + in range, brains, catalog) |
| `MagnetService` | Activate magnet, cooldown, pull adjacent coins |
| `UIController/ProgressionStore` | List rows open a stats card (desc + buy) |
| `StoreController` | Hide Talk prompts on other players' stalls |
| `PlotService` | Applies `ProgressService.getWalkSpeed` on spawn |

Talk prompts only appear on **your** stalls. The server ignores Talk / buys
from anyone who does not own that plot, and `BuyStoreItem` also requires the
caller to be within `CLOSE_DISTANCE` of **their** matching stall (neighbor
shops never count).

Walking farther than `StoreConfig.CLOSE_DISTANCE` (XZ, default 22 studs) from
the mascot you talked to closes the overlay (and its stats card). Sidestepping
at the stall stays inside that radius; running onto the lawn does not. The
Heartbeat watch only runs while the UI is open.

Remotes: `OpenProgressionStore` (server → client, `shopKind` + mascot
`Vector3`), `BuyStoreItem` (client → server), `StorePurchaseSucceeded` /
`StorePurchaseFailed` (server → client).
Success: kaching SFX, red `-{cost}` on the brains HUD, green “Purchased
Successfully!” banner. Not enough brains: error SFX
(`AudioConfig.PurchaseError`) and a red “Purchase Unsuccessful…” banner
**above the Buy button**. Repeat fails stack: the new banner sits on top
while older ones slide up and fade out faster. Profile refresh via
`ProfileUpdated`.
