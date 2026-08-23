--!strict
--[[
	ClearFogRow (Giraffa Celeste)
	While alive, NightFog plant-block and lawn fog on this row are lifted.
]]

local FogRows = require(script.Parent.Parent.FogRows)

local ClearFogRow = {}

function ClearFogRow.onPlaced(ctx)
	FogRows.add(ctx.plotModel, ctx.row)
end

function ClearFogRow.onRemoved(ctx)
	FogRows.remove(ctx.plotModel, ctx.row)
end

return ClearFogRow
