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
| `COLUMNS`                 | 9       | tiles along the lane toward the enemy (X)|
| `TILE_HEIGHT`             | 0.4     | visual thickness of a tile               |
| `TILE_GAP`                | 0.6     | bare grass between tiles (the gridlines) |
| `TILE_Y_OFFSET`           | 0.05    | lift above grass to avoid z-fighting     |
| `TILE_COLOR_A/B`          | greens  | checkerboard colors                      |
| `HIGHLIGHT_*`             | —       | client hover-highlight look              |

Column → world X (toward the enemy spawn, +X), row → world Z (across the lane).
A PvZ-style lawn that runs along the lane: 9 columns deep, 5 rows wide. Adding
columns lengthens the grid and (because the zones are derived — see below)
shrinks the house/enemy strips; more rows would require a deeper lane.

The **physical** tile size is *derived* in `PlotConfig` so the grid fills each
plot's play area rather than floating as a small patch:

- `TILE_SIZE = (BASE_DEPTH − 2·MARGIN_Z) / ROWS` — square tiles sized so the grid
  spans the full lane depth.
- `GRID_WIDTH = COLUMNS · TILE_SIZE`, `GRID_DEPTH = ROWS · TILE_SIZE`.
- `HOUSE_ZONE` is the leftover lane length behind the grid (enemy staging lives
  in the east map column, not inside each plot).

With the current defaults (lane **330 × 110**, four plots pitched **165** apart,
`MARGIN` 10, `ROWS` 5, `COLUMNS` 9):
`TILE_SIZE = 18`, `GRID_WIDTH = 162`, `GRID_DEPTH = 90`, and `HOUSE_ZONE = 148`.

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

`tryOccupy(plotModel, position, brainrotInstanceId?)` is the server-authoritative
placement gate. Pass a Brainrot instance id for plants. Pass **nil** for
blocking props (**graves**): the tile is occupied (no planting) but
`brainrotInstanceId` stays nil so monsters **phase through** and never chew.
**Brr Brr Patapim** uses `tryOccupyOverGrave` / `revertToGrave` so it can sit
on a grave without dropping the grave occupancy flag until the stone collapses.

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
  On NightFog days, fog-blocked east columns get **no** hover highlight
  (`WEATHER.md`). Desert days use the same hover rules on a sand-colored lawn.
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
- Cannot plant on NightFog / NightFogReceded fog columns (easternmost 3 or 2),
  unless the row is temporarily cleared, or the selected definition permits fog
  placement (`triggersOnPlace`, `plantsOnFog`, or `plantOnGrave`). Grave busters
  still require a grave. See `WEATHER.md`. Desert and Hidden Day have no blocked
  fog columns.
- The server validates every placement (via `GridService` + cost checks).

Shovel input can resolve a directly clicked planted model via its replicated
Row/Column and PlotUtil local ownership check, falling back to the occupied
grid tile. Raw screen coordinates still feed the camera ray; GUI inset
subtraction applies only to the cosmetic cursor position, not world targeting.

## Lawn finish ✅

GridService keeps its existing checker colors, dimensions, tags and occupancy.
WorldStyle applies BvmStudsGround at tile construction. The finish is a shared
PBR material with no extra geometry; original physical properties are retained.
DesertVisuals switches the colors while keeping that pattern. See WORLD_STYLE.md.
