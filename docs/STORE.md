# BVM Progression Stores

Each **plot house** gets its own blue + red mini stores in the yard (not a
shared world stall). Players **talk** to mascots; the HUD is display-only.
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

**Speed** (`WalkSpeed`): 10 levels, each `+walkSpeedBonusPerLevel` (1) on top of
Roblox-default `PlayerConfig.WALK_SPEED` (16 → 26 at max). Costs rise each
level (`6 / 10 / 14 / 19 / 25 / 32 / 41 / 52 / 65 / 80` brains). Persisted in
`SaveData.upgrades`.

---

## Architecture

| Module | Role |
| ------ | ---- |
| `StoreConfig` | Template names, yard offsets, prompt copy |
| `StoreService` | Clone beside house; ProximityPrompt → `OpenProgressionStore` |
| `ProgressService` | Validate `BuyStoreItem`, spend brains, grant unlock / upgrade |
| `UIController/ProgressionStore` | List rows open a stats card (desc + buy) |
| `PlotService` | Applies `ProgressService.getWalkSpeed` on spawn |

Remotes: `OpenProgressionStore` (server → client), `BuyStoreItem` (client →
server), `StorePurchaseSucceeded` / `StorePurchaseFailed` (server → client).
Success: kaching SFX, red `-{cost}` on the brains HUD, green “Purchased
Successfully!” banner. Not enough brains: error SFX
(`AudioConfig.PurchaseError`) and a red “Purchase Unsuccessful…” banner
**above the Buy button**. Repeat fails stack: the new banner sits on top
while older ones slide up and fade out faster. Profile refresh via
`ProfileUpdated`.
