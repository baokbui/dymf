--!strict
--[[
	GridConfig
	Battlefield grid dimensions and layout. Tweak here, never inline.
]]

local GridConfig = {
	ROWS = 5,
	COLUMNS = 9,
	TILE_SIZE = 16, -- studs per square tile
	TILE_HEIGHT = 1, -- visual thickness of a tile
}

table.freeze(GridConfig)

return GridConfig
