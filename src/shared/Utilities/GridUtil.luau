--!strict
--[[
	GridUtil
	Pure grid math shared by placement, combat, and rendering. Kept side-effect
	free so it can run on client (preview) and server (validation) identically.
]]

local GridConfig = require(script.Parent.Parent.Config.GridConfig)
local PlotConfig = require(script.Parent.Parent.Config.PlotConfig)
local Types = require(script.Parent.Parent.Types)

local GridUtil = {}

-- True if a grid position is inside the configured battlefield bounds.
function GridUtil.isInBounds(position: Types.GridPosition): boolean
	return position.row >= 1
		and position.row <= GridConfig.ROWS
		and position.column >= 1
		and position.column <= GridConfig.COLUMNS
end

-- Stable string key for a tile, suitable for use in occupancy maps.
function GridUtil.toKey(position: Types.GridPosition): string
	return string.format("%d:%d", position.row, position.column)
end

-- Converts a grid position to a local offset from the grid's near corner
-- (column 1, row 1), centered on the tile. Column maps to X, row maps to Z.
-- Y is left at 0; callers add their own height.
function GridUtil.toLocalOffset(position: Types.GridPosition): Vector3
	local size = PlotConfig.TILE_SIZE
	local x = (position.column - 0.5) * size
	local z = (position.row - 0.5) * size
	return Vector3.new(x, 0, z)
end

-- Inverse of toLocalOffset: which tile a corner-relative offset falls in.
-- May return an out-of-bounds position; pair with isInBounds to validate.
function GridUtil.fromLocalOffset(offset: Vector3): Types.GridPosition
	local size = PlotConfig.TILE_SIZE
	return {
		column = math.floor(offset.x / size) + 1,
		row = math.floor(offset.z / size) + 1,
	}
end

-- Total footprint of the grid in studs (X = columns, Z = rows).
function GridUtil.dimensions(): Vector3
	return Vector3.new(PlotConfig.GRID_WIDTH, 0, PlotConfig.GRID_DEPTH)
end

-- Every valid grid position, row-major. Useful for generation/iteration.
function GridUtil.positions(): { Types.GridPosition }
	local result: { Types.GridPosition } = {}
	for row = 1, GridConfig.ROWS do
		for column = 1, GridConfig.COLUMNS do
			table.insert(result, { row = row, column = column })
		end
	end
	return result
end

return GridUtil
