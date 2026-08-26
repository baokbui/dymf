# BVM Progression Stores

Each **plot house** gets its own blue + red mini stores in the yard (not a
shared world stall). Players **talk** to mascots; the HUD is display-only.
Spends are **server-authoritative** (`ProgressService`).

Status: 🔜 Milestone 18

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

Tune `YARD_OFFSET_X`, `STORE_SPACING_X`, and `DOOR_RIGHT_Z` in `StoreConfig`.
Stalls sit on the **right** of the door, side by side along the yard, facing
the player (`MODEL_ORIENTATION_DEGREES` −90).

---

## Shops

| Store | Mascot | Currency | Sells |
| ----- | ------ | -------- | ----- |
| Blue mini store | `Tung Mascot` | Brains | Roster Brainrots (`ProgressConfig.STORE_CATALOG`) |
| Red mini store | `67 Mascot` | Brains | Player upgrades (`ProgressConfig.UPGRADE_CATALOG`) |

Campaign unlocks stay free later. Buying a catalog Brainrot early just skips
the wait. Already owned units show **Owned**.

**Speed** (`WalkSpeed`): levels 1–5 add `walkSpeedBonusPerLevel` on top of
`PlayerConfig.WALK_SPEED`. Persisted in `SaveData.upgrades`.

---

## Architecture

| Module | Role |
| ------ | ---- |
| `StoreConfig` | Template names, yard offsets, prompt copy |
| `StoreService` | Clone beside house; ProximityPrompt → `OpenProgressionStore` |
| `ProgressService` | Validate `BuyStoreItem`, spend brains, grant unlock / upgrade |
| `UIController/ProgressionStore` | Overlay list + buy intent |
| `PlotService` | Applies `ProgressService.getWalkSpeed` on spawn |

Remotes: `OpenProgressionStore` (server → client), `BuyStoreItem` (client →
server), `StorePurchaseFailed` (server → client). Profile refresh via
`ProfileUpdated`.
