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

	The player spawns at the left edge of the play area facing +X (the enemy
	spawn). Tune here, never inline.
]]

-- Reference dimension: keep in sync with the Baseplate size in
-- default.project.json. The plot pool is sized from this.
local BASEPLATE_SIZE = 700
local POOL_MARGIN = 20 -- grass border between the plot pool and baseplate edge
local USABLE = BASEPLATE_SIZE - POOL_MARGIN * 2

local MAX_PLOTS = 12 -- total lanes (= max concurrent players)
local LANE_COLUMNS = 2 -- side-by-side columns of lanes
local LANE_ROWS = math.ceil(MAX_PLOTS / LANE_COLUMNS) -- lanes per column

local HOUSE_ZONE = 40 -- left strip reserved for the house (behind the player)
local ENEMY_ZONE = 40 -- right strip where zombies enter
local MARGIN_X = 10
local MARGIN_Z = 10

-- Lanes tile the baseplate: usable area split across columns (X) and rows (Z).
local BASE_WIDTH = USABLE / LANE_COLUMNS -- X (lane length)
local BASE_DEPTH = USABLE / LANE_ROWS -- Z (one lane)

local PlotConfig = {
	MAX_PLOTS = MAX_PLOTS,
	LANE_COLUMNS = LANE_COLUMNS,
	LANE_ROWS = LANE_ROWS,

	BASEPLATE_SIZE = BASEPLATE_SIZE,
	POOL_MARGIN = POOL_MARGIN,

	-- Zone widths along X (see header diagram).
	HOUSE_ZONE = HOUSE_ZONE,
	ENEMY_ZONE = ENEMY_ZONE,
	MARGIN_X = MARGIN_X,
	MARGIN_Z = MARGIN_Z,

	BASE_WIDTH = BASE_WIDTH, -- X (lane length)
	BASE_DEPTH = BASE_DEPTH, -- Z (one lane)
	BASE_THICKNESS = 1,

	-- Containment walls rendered as clear glass so boundaries are visible.
	BARRIER_HEIGHT = 24,
	BARRIER_THICKNESS = 2,
	BARRIER_TRANSPARENCY = 0.8,
	BARRIER_COLOR = Color3.fromRGB(200, 230, 255),
	BARRIER_MATERIAL = Enum.Material.Glass,

	-- Spawn sits at the left edge of the play area, facing the enemy (+X).
	SPAWN_HEIGHT = 3,
	SPAWN_EDGE_INSET = 4,
}

table.freeze(PlotConfig)

return PlotConfig
