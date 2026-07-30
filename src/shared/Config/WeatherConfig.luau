--!strict
--[[
	WeatherConfig
	Per-day weather tuning. Weather is data-driven on LevelDefinition.weather;
	never branch on day numbers in services — read the definition.
]]

local GridConfig = require(script.Parent.GridConfig)
local PlotConfig = require(script.Parent.PlotConfig)

local WeatherConfig = {
	-- LevelDefinition.weather values (never branch on day numbers in services).
	NIGHT = "Night", -- moonlit night, no fog (Days 21–24)
	NIGHT_FOG = "NightFog", -- night + forest/east-lawn fog (Days 25–30)

	-- Easternmost lawn columns covered by fog (unable to hold Brainrots).
	-- With COLUMNS = 9 → columns 7, 8, 9.
	FOG_PLOT_COLUMNS = 3,

	-- Forest fog covers the player's lane strip through the full enemy-column
	-- forest (see `forestFogDepthFromLawnEdge`).
	FOG_HEIGHT_STUDS = 20,
	FOG_CENTER_HEIGHT_STUDS = 8,

	-- Client night look (local Lighting — only this player's client).
	NIGHT_CLOCK_TIME = 20.8,
	NIGHT_BRIGHTNESS = 2.4,
	NIGHT_AMBIENT = Color3.fromRGB(110, 120, 160),
	NIGHT_OUTDOOR_AMBIENT = Color3.fromRGB(130, 140, 180),
	NIGHT_COLOR_SHIFT_TOP = Color3.fromRGB(70, 85, 130),
	NIGHT_COLOR_SHIFT_BOTTOM = Color3.fromRGB(50, 55, 90),
	NIGHT_FOG_START = 120,
	NIGHT_FOG_END = 520,
	NIGHT_FOG_COLOR = Color3.fromRGB(150, 165, 200),
	NIGHT_ATMOSPHERE_DENSITY = 0.22,
	NIGHT_ATMOSPHERE_HAZE = 0.9,
	NIGHT_ATMOSPHERE_GLARE = 0.05,
	NIGHT_ATMOSPHERE_OFFSET = 0.12,

	-- Cheap fog: invisible emission volumes + soft particle mist only
	-- (no translucent Part "glass box"). Heavier deep in the forest, lighter
	-- on the plot's fog columns so density falls off toward the lawn.
	FOG_LAWN_PARTICLE_RATE = 8,
	FOG_FOREST_NEAR_PARTICLE_RATE = 18,
	FOG_FOREST_DEEP_PARTICLE_RATE = 36,
	-- Fraction of forest depth (from the lawn edge) that uses the lighter
	-- "near" band before the heavy deep-forest mist.
	FOG_FOREST_NEAR_DEPTH_FRACTION = 0.35,
	FOG_PARTICLE_SIZE = 20,
	FOG_PARTICLE_LIFETIME = 5.5,
	FOG_PARTICLE_COLOR = Color3.fromRGB(210, 220, 235),
	FOG_PARTICLE_LIGHT_EMISSION = 0.3,
	FOG_PARTICLE_LIGHT_INFLUENCE = 0.15,
}

-- First lawn column index that is fog-blocked (inclusive).
function WeatherConfig.fogStartColumn(): number
	return GridConfig.COLUMNS - WeatherConfig.FOG_PLOT_COLUMNS + 1
end

-- Studs from the lawn's east edge through the player's margin + the full
-- enemy-column forest (matches ForestBuilder's east extent).
function WeatherConfig.forestFogDepthFromLawnEdge(): number
	return PlotConfig.MARGIN_X + PlotConfig.BASE_WIDTH - PlotConfig.FOREST_MARGIN_EAST
end

table.freeze(WeatherConfig)

return WeatherConfig
