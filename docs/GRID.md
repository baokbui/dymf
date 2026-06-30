# Grid System

The grid is the placement surface inside every plot's play area: a fixed
`ROWS` × `COLUMNS` lawn of square tiles. Brainrots occupy tiles; monsters walk
across them. The server owns tile state; the client only renders/highlights.

Status: ✅ implemented (Milestone 2). Placement now consumes the grid
(Milestone 4): `BrainrotService` reserves tiles via `tryOccupy`, and
`PlacementController` previews/targets tiles via `GridController.resolveTileAt`.

---

## Dimensions & layout

The **logical** grid size and tile visuals live in `Shared/Config/GridConfig.luau`:

| Key                       | Default | Meaning                                  |
| ------------------------- | ------- | ---------------------------------------- |
| `ROWS`                    | 5       | tiles across the lane (Z)                |
| `COLUMNS`                 | 11      | tiles along the lane toward the enemy (X)|
| `TILE_HEIGHT`             | 0.4     | visual thickness of a tile               |
| `TILE_GAP`                | 0.6     | bare grass between tiles (the gridlines) |
| `TILE_Y_OFFSET`           | 0.05    | lift above grass to avoid z-fighting     |
| `TILE_COLOR_A/B`          | greens  | checkerboard colors                      |
| `HIGHLIGHT_*`             | —       | client hover-highlight look              |

Column → world X (toward the enemy spawn, +X), row → world Z (across the lane).
A PvZ-style lawn that runs along the lane: 11 columns deep, 5 rows wide. Adding
columns lengthens the grid and (because the zones are derived — see below)
shrinks the house/enemy strips; more rows would require a deeper lane.

The **physical** tile size is *derived* in `PlotConfig` so the grid fills each
plot's play area rather than floating as a small patch:

- `TILE_SIZE = (BASE_DEPTH − 2·MARGIN_Z) / ROWS` — square tiles sized so the grid
  spans the full lane depth.
- `GRID_WIDTH = COLUMNS · TILE_SIZE`, `GRID_DEPTH = ROWS · TILE_SIZE`.
- `HOUSE_ZONE` and `ENEMY_ZONE` are then derived as the leftover lane length
  split evenly, so they are reserved strips at the −X / +X ends and the grid
  **never covers the house or enemy area**.

With the current defaults (lane 330 × 110, `MARGIN` 10, `ROWS` 5, `COLUMNS` 11):
`TILE_SIZE = 18`, `GRID_WIDTH = 198`, `GRID_DEPTH = 90`, and each of
`HOUSE_ZONE` / `ENEMY_ZONE = 56`.

The grid is centered on the play area: `PlotBuilder` places a `GridCenter`
attachment at the play-area center, and `GridService` lays tiles out from the
grid's near corner (`GridCenter − ½ footprint`).

> Implementation note: marker attachments (`GridCenter`, `HouseAnchor`,
> `EnemySpawn`, `CoinSpawner`) are parented to the base **before** their
> `WorldPosition` is set — an unparented attachment treats `WorldPosition` as a
> local offset, which would double the coordinate once parented.

> Dependency direction: `PlotConfig` requires `GridConfig` (reads `ROWS`/
> `COLUMNS`); `GridConfig` never requires `PlotConfig`. `GridUtil` reads
> `PlotConfig.TILE_SIZE` for world math.

---

## Coordinates (`Shared/Utilities/GridUtil.luau`)

Pure, side-effect-free math shared by client and server so previews and
validation agree exactly:

- `isInBounds(position)` — within `1..ROWS` / `1..COLUMNS`.
- `toKey(position)` — stable `"row:column"` string for occupancy maps.
- `toLocalOffset(position)` — tile center offset from the grid's near corner.
- `fromLocalOffset(offset)` — inverse: which tile an offset falls in.
- `dimensions()` — total grid footprint in studs (X = columns, Z = rows).
- `positions()` — every valid `GridPosition`, row-major.

A `GridPosition` is `{ row: number, column: number }` (see `Shared/Types`).

---

## Server: `GridService` (authoritative)

`Services/GridService` builds and owns the grid.

- **Generation** — in `start()` (after `PlotService.init` has built the plot
  pool), it builds a tile grid into every plot's `Grid` folder. Each tile is an
  anchored, non-colliding `Part` tagged `GridTile` with `Row`, `Column`, and
  `Occupied` attributes, colored as a checkerboard.
- **Occupancy** — tracked per plot, keyed by the plot `Model`. The `Occupied`
  attribute on each tile mirrors state so clients react without extra remotes.
- **Reuse** — tiles are static and shared across plot owners. `PlotService`
  calls `GridService.resetPlot(plotModel)` on release to clear occupancy
  (tiles are never rebuilt; the `Grid` folder is excluded from `Plot.release`'s
  dynamic-folder wipe).

### Public API

| Function                                              | Purpose                              |
| ----------------------------------------------------- | ------------------------------------ |
| `getTile(plotModel, position) -> Tile?`               | read-only snapshot                   |
| `isOccupied(plotModel, position) -> boolean`          | occupancy check                      |
| `getWorldPosition(plotModel, position) -> Vector3?`   | top-center of a tile (placement)     |
| `tryOccupy(plotModel, position, brainrotInstanceId)`  | reserve a free tile (returns bool)   |
| `release(plotModel, position)`                        | free one tile                        |
| `resetPlot(plotModel)`                                | free all tiles on a plot             |

`tryOccupy` is the server-authoritative placement gate (used by
`BrainrotService` in Milestone 4): it rejects out-of-bounds, unknown-plot, and
already-occupied tiles, and stores the placing Brainrot's `brainrotInstanceId`
on the tile so removal can resolve which instance occupies a cell.

---

## Client: `GridController` (visual only)

`Controllers/GridController` highlights the tile under the cursor on the local
player's **own** plot (ownership read from the plot model's `OwnerUserId`
attribute set by `PlotService`).

- Event-driven: updates on `UserInputService.InputChanged` (mouse/touch move) —
  no per-frame polling.
- Raycasts the cursor, accepts the hit only if it is tagged `GridTile` and on the
  player's own plot, then repositions a single reused highlight part over it.
- Colors the highlight by the tile's `Occupied` attribute (valid vs. blocked).
- Exposes `getHoveredTile() -> { row, column }?` and the side-effect-free
  `resolveTileAt(x, y) -> BasePart?` (same raycast + own-plot/tag rules as the
  highlight). `PlacementController` (Milestone 4) reuses `resolveTileAt` to
  position its ghost and resolve the target tile on click/tap, so there is a
  single source of cursor→tile logic.

No RemoteEvents are involved: tiles and their attributes replicate from the
server, and highlighting is a local visual.

---

## Rules (from `GAME_DESIGN.md`)

- One Brainrot per tile.
- Cannot plant outside the grid.
- Cannot plant without enough coins.
- The server validates every placement (via `GridService` + cost checks).
