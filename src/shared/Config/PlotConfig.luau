--!strict
--[[
	PlotConfig
	Layout for player plots and the shared enemy-spawn column.

	The baseplate is split into MAP_COLUMNS side-by-side strips along X:

		[ west: player plots ] [ east: enemy spawn lanes ]

	Player plots tile the west column in LANE_ROWS rows (one lane per row).
	The east column holds enemy-spawn lanes aligned with each player row — no
	player grids there. Monsters stage in the east column and enter the matching
	player plot from the +X side.

	Within a player lane, left -> right is:

		[ MARGIN | HOUSE_ZONE | PLAY_AREA (grid) | MARGIN ]
		   house is behind the player (-X)

	The play area is exactly the size of the battlefield grid (see GridConfig for
	ROWS/COLUMNS): tiles fill the lane's depth, and HOUSE_ZONE is the reserved
	strip behind the grid. The player spawns at the left edge of the play area
	facing +X. Tune here, never inline.
]]

local GridConfig = require(script.Parent.GridConfig)

-- Reference dimension: keep in sync with the Baseplate size in
-- default.project.json. The plot pool is sized from this.
local BASEPLATE_SIZE = 700
local POOL_MARGIN = 20 -- grass border between the plot pool and baseplate edge
local USABLE = BASEPLATE_SIZE - POOL_MARGIN * 2

local MAP_COLUMNS = 2 -- west = player plots, east = enemy spawn
local LANE_ROWS = 6 -- stacked lanes per column (one row per concurrent player)
local MAX_PLOTS = LANE_ROWS -- player lanes in the west column only

local MARGIN_X = 10
local MARGIN_Z = 10

-- Each map column is half the baseplate; rows stack along Z.
local BASE_WIDTH = USABLE / MAP_COLUMNS -- X (lane length)
local BASE_DEPTH = USABLE / LANE_ROWS -- Z (one lane)

-- Derive the grid to fill the play area. Tiles are square; their size is set by
-- the lane depth so the grid spans the full width of the lane (minus margins).
local PLAY_DEPTH = BASE_DEPTH - MARGIN_Z * 2
local TILE_SIZE = PLAY_DEPTH / GridConfig.ROWS
local GRID_DEPTH = TILE_SIZE * GridConfig.ROWS -- == PLAY_DEPTH
local GRID_WIDTH = TILE_SIZE * GridConfig.COLUMNS

-- The grid occupies the lane's center; leftover length is the house strip behind
-- the player. Enemy staging lives in the east map column, not inside each plot.
local ZONE_TOTAL = BASE_WIDTH - MARGIN_X * 2 - GRID_WIDTH
assert(ZONE_TOTAL >= 0, "PlotConfig: grid is wider than the lane; widen plots or shrink the grid")
local HOUSE_ZONE = ZONE_TOTAL

local PlotConfig = {
	MAX_PLOTS = MAX_PLOTS,
	MAP_COLUMNS = MAP_COLUMNS,
	LANE_ROWS = LANE_ROWS,
	PLAYER_MAP_COLUMN = 0, -- west column index
	ENEMY_MAP_COLUMN = 1, -- east column index

	BASEPLATE_SIZE = BASEPLATE_SIZE,
	POOL_MARGIN = POOL_MARGIN,

	-- Zone width along X behind the grid (see header diagram).
	HOUSE_ZONE = HOUSE_ZONE,
	MARGIN_X = MARGIN_X,
	MARGIN_Z = MARGIN_Z,

	-- Physical battlefield grid size (logical ROWS/COLUMNS live in GridConfig).
	TILE_SIZE = TILE_SIZE,
	GRID_WIDTH = GRID_WIDTH, -- X (columns)
	GRID_DEPTH = GRID_DEPTH, -- Z (rows)

	BASE_WIDTH = BASE_WIDTH, -- X (lane length)
	BASE_DEPTH = BASE_DEPTH, -- Z (one lane)
	BASE_THICKNESS = 1,

	-- Spawn sits at the left edge of the play area, facing the enemy (+X).
	SPAWN_HEIGHT = 3,
	SPAWN_EDGE_INSET = 4,

	-- Fraction of a tile's side length used as the Brainrot body footprint.
	-- Both BrainrotModel (server) and PlacementController ghost (client) read this
	-- so they always agree on size. Tune here, never inline.
	BRAINROT_FOOTPRINT_RATIO = 0.72,

	-- Dark forest filling the east (enemy-spawn) column. Non-colliding décor so
	-- players can walk through and monsters stay grid-based. Monsters spawn
	-- deeper in the trees (MonsterConfig.SPAWN_COLUMN_OFFSET) and walk west
	-- through this clear strip into player plots.
	FOREST_CLEAR_WEST = 18, -- studs kept open near plot boundary for entry path (~1 tile)
	FOREST_MARGIN_EAST = 6,
	FOREST_MARGIN_Z = 8,
	FOREST_SPACING = 18,
	FOREST_JITTER = 6,
	FOREST_GROUND_COLOR = Color3.fromRGB(16, 28, 16),
	FOREST_TRUNK_COLOR = Color3.fromRGB(32, 22, 14),
	FOREST_FOLIAGE_A = Color3.fromRGB(10, 26, 12),
	FOREST_FOLIAGE_B = Color3.fromRGB(6, 18, 10),
}

table.freeze(PlotConfig)

return PlotConfig
