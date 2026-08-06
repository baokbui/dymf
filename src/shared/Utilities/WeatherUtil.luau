--!strict
--[[
	WeatherUtil
	Pure helpers for weather rules (plantable tiles, coin drops).
	Shared by server validation and client visuals.
]]

local GridConfig = require(script.Parent.Parent.Config.GridConfig)
local WeatherConfig = require(script.Parent.Parent.Config.WeatherConfig)
local Types = require(script.Parent.Parent.Types)
local GridUtil = require(script.Parent.GridUtil)

local WeatherUtil = {}

-- Night lighting (Night, NightFog, or NightFogReceded).
function WeatherUtil.isNight(weather: string?): boolean
	return weather == WeatherConfig.NIGHT
		or weather == WeatherConfig.NIGHT_FOG
		or weather == WeatherConfig.NIGHT_FOG_RECEDED
end

-- Night + plant-blocking fog zone. Fog is cosmetic for visibility — monsters
-- are not hidden; only planting / coin tiles are gated. Includes both full
-- NightFog (3 columns) and NightFogReceded (2 columns).
function WeatherUtil.isNightFog(weather: string?): boolean
	return weather == WeatherConfig.NIGHT_FOG or weather == WeatherConfig.NIGHT_FOG_RECEDED
end

-- True when a lawn column is inside the fog plant-blocked zone for `weather`.
function WeatherUtil.isFogPlotColumn(column: number, weather: string?): boolean
	if not WeatherUtil.isNightFog(weather) then
		return false
	end
	return column >= WeatherConfig.fogStartColumn(weather) and column <= GridConfig.COLUMNS
end

-- Every fog-blocked lawn tile (east columns × all rows) for `weather`.
function WeatherUtil.fogPlotPositions(weather: string?): { Types.GridPosition }
	local result: { Types.GridPosition } = {}
	if not WeatherUtil.isNightFog(weather) then
		return result
	end
	for _, position in GridUtil.positions() do
		if WeatherUtil.isFogPlotColumn(position.column, weather) then
			table.insert(result, position)
		end
	end
	return result
end

-- Random lawn tile that can receive ground coins / plants under the current
-- weather (excludes fog east columns). Falls back to any tile if somehow
-- every column is fogged.
function WeatherUtil.randomClearPlotPosition(weather: string?): Types.GridPosition
	if not WeatherUtil.isNightFog(weather) then
		return GridUtil.randomPosition()
	end

	local clear: { Types.GridPosition } = {}
	for _, position in GridUtil.positions() do
		if not WeatherUtil.isFogPlotColumn(position.column, weather) then
			table.insert(clear, position)
		end
	end
	if #clear == 0 then
		return GridUtil.randomPosition()
	end
	return clear[math.random(1, #clear)]
end

return WeatherUtil
