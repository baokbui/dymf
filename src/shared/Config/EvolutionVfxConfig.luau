--!strict
-- Presentation only; evolution eligibility, stats and combat stay server-owned.
local Config = {
	FLAME_TEXTURE = "rbxasset://textures/particles/fire_main.dds",
	GLINT_TEXTURE = "rbxassetid://137400119071253",
	UPDATE_INTERVAL = 0.5,
	MAX_DISTANCE = 140,
	DETAIL_DISTANCE = 70,
	MAX_VISIBLE = { High = 28, Medium = 18, Low = 10, Off = 0 },
	MAX_DETAILED = { High = 8, Medium = 6, Low = 0, Off = 0 },
	GRAPHICS_LOW_MAX = 3,
	GRAPHICS_MEDIUM_MAX = 7,
	MIN_WIDTH = 2.4,
	RIG_BOUNDS_MIN_PADDING = 0.2,
	RIG_BOUNDS_PADDING_RATIO = 0.04,
	OUTLINE_TRANSPARENCY = 0.2,
	FILL_TRANSPARENCY = 0.93,
	MAX_BURSTS = { High = 4, Medium = 3, Low = 2, Off = 0 },
	BURST = {
		CoreFlames = { High = 10, Medium = 6, Low = 3 },
		OuterFlames = { High = 6, Medium = 3, Low = 0 },
		Motes = { High = 14, Medium = 8, Low = 4 },
		Glints = { High = 8, Medium = 4, Low = 2 },
		BurstFlames = { High = 4, Medium = 2, Low = 1 },
	},
	BRIGHTNESS = 4.8,
	OUTER_BRIGHTNESS = 3.6,
	OUTER_LIGHT_EMISSION = 0.85,
	FLAME_SIZE = 2.2,
	FLAME_RISE_MIN = 0.12,
	FLAME_RISE_MAX = 0.18,
	FLAME_ACCELERATION = 0.01,
	FLAME_LIFETIME_MIN = 0.6,
	FLAME_LIFETIME_MAX = 0.95,
	FLAME_MAX_TRAVEL_RATIO = 0.2,
	FLAME_HEADROOM_RATIO = 0.12,
	FLAME_MIN_HEADROOM = 0.6,
	FLAME_MIN_SOURCE_HEIGHT_RATIO = 0.25,
	SPARK_DRIFT_MIN = 0.4,
	SPARK_DRIFT_MAX = 0.6,
	SPARK_DRAG = 0.1,
	SPARK_ACCELERATION = 0.04,
	SPARK_SPREAD = 35,
	MOTE_LIFETIME_MIN = 1.3,
	MOTE_LIFETIME_MAX = 1.8,
	GLINT_LIFETIME_MIN = 1.2,
	GLINT_LIFETIME_MAX = 1.7,
	SPARK_Z_OFFSET = 1,
	SPARK_BRIGHTNESS = 3.6,
	SPARK_LIGHT_EMISSION = 0.95,
	MOTE_SIZE = 0.48,
	GLINT_SIZE = 0.9,
	FLAME_SQUASH = -0.65,
	LIGHT_EMISSION = 0.95,
	FOOTPRINT_RATIO = 1.15,
	TIERS = {
		Epic = { density = 1,  glint = 1 },
		Legendary = { density = 1.1,  glint = 1.3 },
		Mythic = { density = 1.2,  glint = 1.5 },
		Immortal = { density = 1.3,  glint = 1.7 },
		God = { density = 1.4,  glint = 2 },
	},
	-- Emitters carry these bands as attributes, so clients never reconstruct VFX.
	RATES = {
		CoreFlames = { High = 72, Medium = 48, Low = 28 },
		OuterFlames = { High = 48, Medium = 24, Low = 0 },
		Motes = { High = 16, Medium = 10, Low = 4 },
		Glints = { High = 6, Medium = 4, Low = 1.5 },
		BurstFlames = { High = 0, Medium = 0, Low = 0 },
	},
}

function Config.band(effects: string, savedGraphics: number): string
	if effects == "Minimal" then return "Off" end
	if effects == "Reduced" then return "Low" end
	-- Automatic quality's live engine level is not exposed to game scripts.
	if savedGraphics <= 0 then return "Medium" end
	if savedGraphics <= Config.GRAPHICS_LOW_MAX then return "Low" end
	if savedGraphics <= Config.GRAPHICS_MEDIUM_MAX then return "Medium" end
	return "High"
end

for _, value in Config.TIERS do table.freeze(value) end
for _, value in Config.RATES do table.freeze(value) end
for _, value in Config.BURST do table.freeze(value) end
table.freeze(Config.BURST); table.freeze(Config.MAX_BURSTS)
table.freeze(Config.TIERS); table.freeze(Config.RATES)
table.freeze(Config.MAX_VISIBLE); table.freeze(Config.MAX_DETAILED)
return table.freeze(Config)
