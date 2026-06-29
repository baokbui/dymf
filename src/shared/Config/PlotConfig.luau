--!strict
--[[
	PlotConfig
	Layout for player plots. Each plot is a horizontal LANE; lanes are tiled in a
	grid of LANE_COLUMNS columns sized to fill the baseplate (leaving a grass
	border). More players = more lanes (configurable via MAX_PLOTS). Splitting
	into more columns shortens each lane's length while fitting more plots.

	Within a lane, left -> right is:

		[ MARGIN | HOUSE_ZONE | PLAY_AREA (grid) | ENEMY_ZONE | MARGIN ]
		   house is behind the player (-X)        zombies enter here (+X)

	The play area is exactly the size of the battlefield grid (see GridConfig for
	ROWS/COLUMNS): tiles fill the lane's depth, and HOUSE_ZONE / ENEMY_ZONE are
	the reserved strips that take up the remaining lane length, so the grid never
	covers the house or enemy areas. The player spawns at the left edge of the
	play area facing +X. Tune here, never inline.
]]

local GridConfig = require(script.Parent.GridConfig)

-- Reference dimension: keep in sync with the Baseplate size in
-- default.project.json. The plot pool is sized from this.
local BASEPLATE_SIZE = 700
local POOL_MARGIN = 20 -- grass border between the plot pool and baseplate edge
local USABLE = BASEPLATE_SIZE - POOL_MARGIN * 2

local MAX_PLOTS = 12 -- total lanes (= max concurrent players)
local LANE_COLUMNS = 2 -- side-by-side columns of lanes
local LANE_ROWS = math.ceil(MAX_PLOTS / LANE_COLUMNS) -- lanes per column

local MARGIN_X = 10
local MARGIN_Z = 10

-- Lanes tile the baseplate: usable area split across columns (X) and rows (Z).
local BASE_WIDTH = USABLE / LANE_COLUMNS -- X (lane length)
local BASE_DEPTH = USABLE / LANE_ROWS -- Z (one lane)

-- Derive the grid to fill the play area. Tiles are square; their size is set by
-- the lane depth so the grid spans the full width of the lane (minus margins).
local PLAY_DEPTH = BASE_DEPTH - MARGIN_Z * 2
local TILE_SIZE = PLAY_DEPTH / GridConfig.ROWS
local GRID_DEPTH = TILE_SIZE * GridConfig.ROWS -- == PLAY_DEPTH
local GRID_WIDTH = TILE_SIZE * GridConfig.COLUMNS

-- The grid occupies the lane's center; whatever length is left over (after
-- margins and the grid) is split evenly into the house and enemy strips.
local ZONE_TOTAL = BASE_WIDTH - MARGIN_X * 2 - GRID_WIDTH
assert(ZONE_TOTAL >= 0, "PlotConfig: grid is wider than the lane; widen plots or shrink the grid")
local HOUSE_ZONE = ZONE_TOTAL / 2 -- left strip reserved for the house (behind player)
local ENEMY_ZONE = ZONE_TOTAL / 2 -- right strip where zombies enter

local PlotConfig = {
	MAX_PLOTS = MAX_PLOTS,
	LANE_COLUMNS = LANE_COLUMNS,
	LANE_ROWS = LANE_ROWS,

	BASEPLATE_SIZE = BASEPLATE_SIZE,
	POOL_MARGIN = POOL_MARGIN,

	-- Zone widths along X (see header diagram). Derived so the grid fills the
	-- play area and the house/enemy strips fall outside it.
	HOUSE_ZONE = HOUSE_ZONE,
	ENEMY_ZONE = ENEMY_ZONE,
	MARGIN_X = MARGIN_X,
	MARGIN_Z = MARGIN_Z,

	-- Physical battlefield grid size (logical ROWS/COLUMNS live in GridConfig).
	TILE_SIZE = TILE_SIZE,
	GRID_WIDTH = GRID_WIDTH, -- X (columns)
	GRID_DEPTH = GRID_DEPTH, -- Z (rows)

	BASE_WIDTH = BASE_WIDTH, -- X (lane length)
	BASE_DEPTH = BASE_DEPTH, -- Z (one lane)
	BASE_THICKNESS = 1,

	-- Containment walls rendered as clear glass so boundaries are visible.
	BARRIER_HEIGHT = 24,
	BARRIER_THICKNESS = 2,
	BARRIER_TRANSPARENCY = 0.9,
	BARRIER_COLOR = Color3.fromRGB(200, 230, 255),
	BARRIER_MATERIAL = Enum.Material.Glass,

	-- Spawn sits at the left edge of the play area, facing the enemy (+X).
	SPAWN_HEIGHT = 3,
	SPAWN_EDGE_INSET = 4,
}

table.freeze(PlotConfig)

return PlotConfig
