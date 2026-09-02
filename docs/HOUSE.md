# BVM Houses

Each player plot has a **walkable cottage** in the `HOUSE_ZONE` (west of the
lawn, behind the spawn). The shell ships with **authored** interior pedestals
in the Cottage asset; boss collection and passive brains income are
**Milestone 21**.

Status legend: ✅ implemented · 🔜 planned (with milestone)

---

## Layout ✅

Within a lane (see `PlotConfig`):

```
[ MARGIN | HOUSE (cottage) | yard + spawn | PLAY_AREA (grid) | MARGIN ]
                              → facing +X toward enemies
```

- Built by `PlotService` house modules from `Shared.Config.HouseConfig`:
  `HouseBuilder` (orchestrates), `ProceduralHouse`, `HouseSanitize`,
  `HouseBossDisplay`, `HouseSlot`.
- Parent: `PlotN.House`.
- **Preferred visual:** Toolbox Model under `ReplicatedStorage.Assets.Houses`
  named `HouseConfig.MODEL_ID` (default `Cottage`). Scaled to fit DEPTH×WIDTH,
  door facing +X (tune `MODEL_ORIENTATION_DEGREES` if needed). Collision kept.
  On clone: strips Toolbox **Lock Base** UI/pads; the **Empty Base** sign is
  rewritten to `{DisplayName}'s Base` when the plot is assigned.
- **Owner sign** ✅ — TextLabel/TextButton under a `Sign` ancestor (e.g.
  `Second Floor → Sign`) or with Empty Base / `'s Base` text; rewritten to
  `{DisplayName}'s Base` on plot assign.
- **Fallback:** procedural cottage if the asset is missing (dev-safe).
- `HouseAnchor` attachment remains on the plot base for legacy markers.
- Interior: authored pedestals live in the Cottage asset. Runtime only adds an
  empty `CollectedBosses` folder for future trophy models (M21) — no spawned
  `BossDisplay` cylinders.

### Studio: insert from Toolbox

1. Rojo-sync so `ReplicatedStorage.Assets.Houses` exists (`$ignoreUnknownInstances`).
2. Insert a house Model from the Toolbox into that folder.
3. Rename it to **`Cottage`** (or change `HouseConfig.MODEL_ID` to match).
4. Set a `PrimaryPart`, strip Tools/Scripts if any.
5. Prefer the doorway facing the mesh forward; default yaw is **180°**
   (`MODEL_ORIENTATION_DEGREES`). If still wrong, try `0` or `±90`.
6. Optional **`Sign`** under a `Second Floor` (or any) child Model —
   owner label TextLabel(s) updated by `HouseSanitize`. Leftover **Tung Mascot**
   meshes in the Cottage asset are stripped on clone.

Tune size / pedestal count in `HouseConfig` — never inline.

---

## Future: Boss collection & brains (Milestone 21) 🔜

Design target (not implemented yet):

1. **Collect** — when the player **first defeats** a boss species (`isBoss` in
   `Shared.Monsters`), the server unlocks that boss for the house collection
   (once per species; persist in `SaveData.collectedBosses`).
2. **Display** — `HouseService` places a scaled display model on the next free
   `BossSlot_*` pedestal (`BossStand` attachment). Players can walk into the
   house to see their trophies.
3. **Income** — displayed bosses generate **brains** on a slow server tick
   (rate from config per `monsterId`). Brains remain the progression currency
   already used for the Brainrots Store (M18) and evolutions/mutations (M19).
4. **Spend** — no new currency: brains buy unlocks / evolves as those
   milestones define. House income is an additional brains source.

### Authority

- Server-only grants, placement, and income (`HouseService` + `ProgressService`).
- Clients never invent collected bosses or brains totals.
- Only `SaveService` persists `collectedBosses`.

### Suggested config (when implementing)

| Key | Meaning |
| --- | ------- |
| `brainsPerMinute` per boss id | Passive income while displayed |
| `displayScale` | Trophy model scale on pedestal |
| `maxSlots` | Already `HouseConfig.BOSS_SLOT_COUNT` |

---

## Related

- `docs/GAME_DESIGN.md` — battlefield / house zone
- `docs/ECONOMY.md` — brains vs coins
- `docs/ROADMAP.md` — Milestone 21
- `docs/SAVE_SYSTEM.md` — persistence rules
