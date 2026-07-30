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

-- Picks a random in-bounds grid cell (for coin drops, etc.).
function GridUtil.randomPosition(): Types.GridPosition
	return {
		row = math.random(1, GridConfig.ROWS),
		column = math.random(1, GridConfig.COLUMNS),
	}
end

-- True when `targetColumn` is within `rangeTiles` ahead of the Brainrot's column
-- on the same row (+X toward the enemy). Uses tile indices so a monster standing
-- anywhere in the adjacent east tile counts for melee range 1.
function GridUtil.tileAtColumn(column: number): number
	return math.floor(column + 0.5)
end

-- True if a fractional column is on the player lawn (not still marching in the
-- forest east of the grid). Compares by **tile index**, not raw column, so a
-- monster standing on the frontmost tile (column = COLUMNS) but stopped at its
-- melee standoff (`COLUMNS + MELEE_CLOSE_REACH`, a fraction past the tile
-- center) still counts as on-plot — otherwise Brainrots targeting the very
-- last column (e.g. Tung Tung Sahur planted there, or one tile behind a wall
-- on that column) could never see the monster actively chewing them.
function GridUtil.isOnPlotColumn(column: number): boolean
	return GridUtil.tileAtColumn(column) <= GridConfig.COLUMNS
end

function GridUtil.isColumnInRange(
	attackerColumn: number,
	targetColumn: number,
	rangeTiles: number,
	fullLineRange: number
): boolean
	if not GridUtil.isOnPlotColumn(targetColumn) then
		return false
	end
	local targetTile = GridUtil.tileAtColumn(targetColumn)
	if targetTile < attackerColumn then
		return false
	end
	if rangeTiles == fullLineRange then
		return true
	end
	if rangeTiles <= 0 then
		return false
	end
	return targetTile <= attackerColumn + rangeTiles
end

-- Short melee reach in fractional columns ahead of the Brainrot's column (+X).
function GridUtil.isWithinMeleeReach(attackerColumn: number, targetColumn: number, reachColumns: number): boolean
	if not GridUtil.isOnPlotColumn(targetColumn) then
		return false
	end
	if targetColumn < attackerColumn or reachColumns <= 0 then
		return false
	end
	return targetColumn <= attackerColumn + reachColumns
end

-- Multi-lane units (laneSpan > 1) occupy rows [row, row + laneSpan - 1] —
-- `row` is the lowest/anchor row, not a center. This works uniformly for any
-- span (odd or even) without needing fractional "center row" occupancy math.
function GridUtil.occupiesLaneRow(row: number, laneSpan: number, targetRow: number): boolean
	local span = math.max(1, math.floor(laneSpan))
	return targetRow >= row and targetRow <= row + span - 1
end

-- Visual midpoint of a multi-lane unit's occupied rows, for world-position
-- placement (may be a half-integer for even spans — GridService accepts
-- fractional rows fine).
function GridUtil.laneCenterRow(row: number, laneSpan: number): number
	local span = math.max(1, math.floor(laneSpan))
	return row + (span - 1) / 2
end

-- Random anchor row that keeps a multi-lane unit's full span on the lawn.
function GridUtil.randomRowForSpan(laneSpan: number): number
	local span = math.max(1, math.floor(laneSpan))
	local maxRow = GridConfig.ROWS - span + 1
	if maxRow < 1 then
		return 1
	end
	return math.random(1, maxRow)
end

return GridUtil
