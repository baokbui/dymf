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
	NIGHT_FOG = "NightFog", -- night + 3 east lawn fog columns (Days 25–34)
	-- Night + thinner fog bank: only 2 east lawn columns blocked (Days 35–40).
	NIGHT_FOG_RECEDED = "NightFogReceded",
	-- Hot desert: sand lawn, no fog; forest replaced by pyramids (Days 41–50).
	DESERT = "Desert",

	-- Default / NightFog blocked lawn depth (easternmost columns).
	-- With COLUMNS = 9 → columns 7, 8, 9.
	FOG_PLOT_COLUMNS = 3,
	-- NightFogReceded blocked depth (one column restored to planting).
	-- With COLUMNS = 9 → columns 8, 9.
	FOG_PLOT_COLUMNS_RECEDED = 2,

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
	NIGHT_FOG_START = 50,
	NIGHT_FOG_END = 260,
	NIGHT_FOG_COLOR = Color3.fromRGB(150, 165, 200),
	NIGHT_ATMOSPHERE_DENSITY = 0.48,
	NIGHT_ATMOSPHERE_HAZE = 1.85,
	NIGHT_ATMOSPHERE_GLARE = 0.05,
	NIGHT_ATMOSPHERE_OFFSET = 0.12,

	-- Local mist on top of Lighting Fog + Atmosphere. Keep rates low: each
	-- particle is a large camera-facing smoke billboard (fill-rate heavy).
	-- One lawn bank + two forest bands (Giraffa clears the whole plot).
	FOG_LAWN_PARTICLE_RATE = 12,
	FOG_FOREST_NEAR_PARTICLE_RATE = 18,
	FOG_FOREST_DEEP_PARTICLE_RATE = 26,
	-- Fraction of forest depth (from the lawn edge) that uses the lighter
	-- "near" band before the heavy deep-forest mist.
	FOG_FOREST_NEAR_DEPTH_FRACTION = 0.35,
	FOG_PARTICLE_SIZE = 21,
	FOG_PARTICLE_LIFETIME = 5,
	FOG_PARTICLE_COLOR = Color3.fromRGB(210, 220, 235),
	FOG_PARTICLE_LIGHT_EMISSION = 0.08,
	FOG_PARTICLE_LIGHT_INFLUENCE = 0.2,

	-- Desert lighting (local Lighting — only this player's client).
	DESERT_CLOCK_TIME = 14.2,
	DESERT_BRIGHTNESS = 3.1,
	DESERT_AMBIENT = Color3.fromRGB(180, 150, 110),
	DESERT_OUTDOOR_AMBIENT = Color3.fromRGB(210, 175, 120),
	DESERT_COLOR_SHIFT_TOP = Color3.fromRGB(255, 210, 140),
	DESERT_COLOR_SHIFT_BOTTOM = Color3.fromRGB(200, 140, 70),
	DESERT_FOG_START = 120,
	DESERT_FOG_END = 520,
	DESERT_FOG_COLOR = Color3.fromRGB(220, 185, 130),
	DESERT_ATMOSPHERE_DENSITY = 0.22,
	DESERT_ATMOSPHERE_HAZE = 1.6,
	DESERT_ATMOSPHERE_GLARE = 0.28,
	DESERT_ATMOSPHERE_OFFSET = 0.18,
	DESERT_ATMOSPHERE_COLOR = Color3.fromRGB(230, 190, 120),
	DESERT_ATMOSPHERE_DECAY = Color3.fromRGB(180, 110, 50),

	-- Sand lawn (server-replicated tile paint + bed under tile gaps).
	DESERT_TILE_MATERIAL = Enum.Material.Sand,
	DESERT_TILE_COLOR_A = Color3.fromRGB(232, 198, 128),
	DESERT_TILE_COLOR_B = Color3.fromRGB(210, 168, 98),
	DESERT_SAND_BED_COLOR = Color3.fromRGB(196, 154, 88),
	DESERT_SAND_BED_THICKNESS = 0.25,
	-- Local-only world floor paint (Workspace.Baseplate) for Desert weather.
	DESERT_BASEPLATE_COLOR = Color3.fromRGB(204, 162, 92),

	-- Graves on desert days sit on the easternmost columns (still plantable
	-- except where a grave occupies the tile). Same depth as receded fog.
	DESERT_GRAVE_COLUMNS = 2,

	-- Procedural pyramids (client décor). Prefer Assets.Decor.Pyramid.
	DESERT_PYRAMID_MODEL_ID = "Pyramid",
	DESERT_PYRAMID_COUNT = 5,
	DESERT_PYRAMID_BACK_COUNT = 6,
	DESERT_PYRAMID_SPACING = 96,
	DESERT_PYRAMID_BACK_SPACING = 110,
	-- Extra studs east of the forest AABB, still clamped to the Baseplate.
	DESERT_PYRAMID_EAST_EXTRA = 80,
	DESERT_PYRAMID_SMALL = 28,
	DESERT_PYRAMID_MEDIUM = 54,
	DESERT_PYRAMID_LARGE = 80,
	DESERT_PYRAMID_COLOR = Color3.fromRGB(214, 176, 108),
	DESERT_PYRAMID_MATERIAL = Enum.Material.Sand,
}

-- How many eastern lawn columns are plant-blocked for this weather (0 = none).
function WeatherConfig.fogPlotColumns(weather: string?): number
	if weather == WeatherConfig.NIGHT_FOG_RECEDED then
		return WeatherConfig.FOG_PLOT_COLUMNS_RECEDED
	end
	if weather == WeatherConfig.NIGHT_FOG then
		return WeatherConfig.FOG_PLOT_COLUMNS
	end
	return 0
end

-- First lawn column index that is fog-blocked (inclusive). When there is no
-- fog weather, returns COLUMNS + 1 so no column is in range.
function WeatherConfig.fogStartColumn(weather: string?): number
	local blocked = WeatherConfig.fogPlotColumns(weather)
	if blocked <= 0 then
		return GridConfig.COLUMNS + 1
	end
	return GridConfig.COLUMNS - blocked + 1
end

-- Studs from the lawn's east edge through the player's margin + the full
-- enemy-column forest (matches ForestBuilder's east extent).
function WeatherConfig.forestFogDepthFromLawnEdge(): number
	return PlotConfig.MARGIN_X + PlotConfig.BASE_WIDTH - PlotConfig.FOREST_MARGIN_EAST
end

table.freeze(WeatherConfig)

return WeatherConfig
