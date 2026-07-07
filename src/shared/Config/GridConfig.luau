--!strict
--[[
	GridConfig
	Logical battlefield grid size and tile visuals. The grid is ROWS x COLUMNS
	tiles that fill each plot's play area (columns run along the lane toward the
	enemy, +X; rows run across the lane, Z).

	The *physical* tile size (studs) is derived in PlotConfig (TILE_SIZE /
	GRID_WIDTH / GRID_DEPTH) so the grid always fills the play area and the
	house/enemy strips fall outside it. Tweak here, never inline.
]]

local GridConfig = {
	ROWS = 5, -- tiles across the lane (Z)
	COLUMNS = 9, -- tiles along the lane toward the enemy (X)

	-- Tile rendering (server-built, replicated lawn).
	TILE_HEIGHT = 0.4, -- visual thickness of a tile
	TILE_GAP = 0.6, -- studs of bare grass between tiles (the "grid lines")
	TILE_Y_OFFSET = 0.05, -- lift above the grass to avoid z-fighting
	TILE_MATERIAL = Enum.Material.Grass,
	TILE_COLOR_A = Color3.fromRGB(120, 190, 70), -- checkerboard light
	TILE_COLOR_B = Color3.fromRGB(96, 168, 58), -- checkerboard dark
	TILE_TRANSPARENCY = 0,

	-- Hover highlight (client-only overlay, see GridController).
	HIGHLIGHT_TRANSPARENCY = 0.5,
	HIGHLIGHT_VALID_COLOR = Color3.fromRGB(120, 220, 120), -- free tile
	HIGHLIGHT_BLOCKED_COLOR = Color3.fromRGB(220, 110, 110), -- occupied tile
	HIGHLIGHT_Y_OFFSET = 0.15, -- sit just above the tile surface
}

table.freeze(GridConfig)

return GridConfig
