--!strict
--[[
	GridUtil
	Pure grid math shared by placement, combat, and rendering. Kept side-effect
	free so it can run on client (preview) and server (validation) identically.
]]

local GridConfig = require(script.Parent.Parent.Config.GridConfig)
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

-- Converts a grid position to a local offset (relative to a plot origin),
-- centered on the tile. Y is left at 0; callers add their own height.
function GridUtil.toLocalOffset(position: Types.GridPosition): Vector3
	local size = GridConfig.TILE_SIZE
	local x = (position.column - 0.5) * size
	local z = (position.row - 0.5) * size
	return Vector3.new(x, 0, z)
end

return GridUtil
