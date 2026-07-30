--!strict
--[[
	VfxConfig
	Client visual-effect tuning. Gameplay values stay in CombatConfig / registries.
]]

local PlotConfig = require(script.Parent.PlotConfig)

-- Lawn tiles are ~19 studs; terrify arcs must scale to them or they look tiny.
local TILE = PlotConfig.TILE_SIZE

local VfxConfig = {
	-- Hit spark burst on damaged units.
	HIT_BURST_COUNT = 6,
	HIT_BURST_SPEED = 10,
	HIT_BURST_SIZE = 0.35,
	HIT_BURST_LIFETIME = 0.35,

	-- Death dissolve companion burst (on kill).
	DEATH_BURST_COUNT = 14,
	DEATH_BURST_SPEED = 12,
	DEATH_BURST_SIZE = 0.45,
	DEATH_BURST_LIFETIME = 0.5,

	-- Thanos-style ash when the corpse fades / disappears.
	DISINTEGRATE_EMIT_DURATION = 0.55,
	DISINTEGRATE_PARTICLE_LIFETIME = 1.4,
	DISINTEGRATE_BURST_PER_PART = 18,
	DISINTEGRATE_RATE = 40,
	DISINTEGRATE_SPEED = 1.8,
	DISINTEGRATE_SIZE = 0.28,
	DISINTEGRATE_ACCELERATION = Vector3.new(0, 3.5, 0),
	DISINTEGRATE_COLOR_A = Color3.fromRGB(55, 48, 42),
	DISINTEGRATE_COLOR_B = Color3.fromRGB(140, 120, 95),
	DISINTEGRATE_COLOR_C = Color3.fromRGB(210, 175, 130),

	-- Line-bomb / row explosion (single large blast, legacy).
	EXPLOSION_BURST_COUNT = 24,
	EXPLOSION_BURST_SPEED = 18,
	EXPLOSION_BURST_SIZE = 0.6,
	EXPLOSION_BURST_LIFETIME = 0.55,
	EXPLOSION_RING_SIZE = Vector3.new(8, 1.2, 8),
	EXPLOSION_RING_DURATION = 0.25,

	-- Per-tile blasts along a Bombardino row (`entireRow` Explosion) — big and
	-- exaggerated so a full-row line bomb reads as the game's biggest hit.
	TILE_EXPLOSION_BURST_COUNT = 26,
	TILE_EXPLOSION_BURST_SPEED = 22,
	TILE_EXPLOSION_BURST_SIZE = 0.75,
	TILE_EXPLOSION_BURST_LIFETIME = 0.6,
	TILE_EXPLOSION_RING_SIZE = Vector3.new(7, 1.4, 7),
	TILE_EXPLOSION_RING_DURATION = 0.35,
	-- Secondary shockwave ring (expands further, fades slower) layered on top
	-- of the main ring for extra punch.
	TILE_EXPLOSION_SHOCKWAVE_SIZE = Vector3.new(10.5, 0.5, 10.5),
	TILE_EXPLOSION_SHOCKWAVE_DURATION = 0.5,
	TILE_EXPLOSION_FLASH_SIZE = Vector3.new(4.5, 3, 4.5),
	TILE_EXPLOSION_FLASH_DURATION = 0.15,
	ROW_EXPLOSION_STAGGER = 0.035,

	-- Ground coin pickup sparkle.
	COIN_PICKUP_COUNT = 10,
	COIN_PICKUP_SPEED = 8,
	COIN_PICKUP_SIZE = 0.3,
	COIN_PICKUP_LIFETIME = 0.4,

	-- Projectile trail (client embellishment on server projectile parts).
	PROJECTILE_TRAIL_LIFETIME = 0.18,
	PROJECTILE_TRAIL_WIDTH = 0.25,
	PROJECTILE_GLOW_BRIGHTNESS = 1.5,
	PROJECTILE_GLOW_RANGE = 6,

	-- Palette
	HIT_COLOR = Color3.fromRGB(255, 140, 120),
	DEATH_COLOR = Color3.fromRGB(200, 200, 210),
	EXPLOSION_COLOR = Color3.fromRGB(255, 170, 60),
	COIN_COLOR = Color3.fromRGB(255, 215, 70),
	PROJECTILE_TRAIL_COLOR = Color3.fromRGB(230, 230, 255),
	BUBBLE_PROJECTILE_TRAIL_COLOR = Color3.fromRGB(170, 230, 255),
	BUBBLE_PROJECTILE_GLOW_BRIGHTNESS = 1.2,
	BUBBLE_PROJECTILE_GLOW_RANGE = 7,

	-- Duke Vampire's Terrify scream: curved red soundwave lines scaled to the
	-- lawn tile size so they visibly span ~3 rows and several columns.
	TERRIFY_WAVE_COLOR = Color3.fromRGB(255, 25, 25),
	TERRIFY_WAVE_COUNT = 6,
	TERRIFY_WAVE_STAGGER = 0.09,
	TERRIFY_WAVE_START_DISTANCE = TILE * 0.35,
	TERRIFY_WAVE_SPACING = TILE * 0.9,
	TERRIFY_WAVE_HEIGHT = TILE * 3.4, -- ~3 rows across Z
	TERRIFY_WAVE_BOW = TILE * 0.45,
	TERRIFY_WAVE_THICKNESS = 0.65,
	TERRIFY_WAVE_SEGMENTS = 16,
	TERRIFY_WAVE_LIFETIME = 0.75,

	-- Dizzy stars orbiting over a Brainrot afflicted by Terrify (classic
	-- cartoon "dizzy" halo).
	DIZZY_COLOR = Color3.fromRGB(255, 225, 90),
	DIZZY_SIZE = UDim2.fromOffset(90, 90),
	DIZZY_OFFSET = Vector3.new(0, 2.4, 0),
	DIZZY_STAR_COUNT = 3,
	DIZZY_STAR_SIZE = UDim2.fromOffset(26, 26),
	DIZZY_ORBIT_RADIUS = 22, -- pixels, in the billboard's 2D plane
	DIZZY_ORBIT_FLATTEN = 0.45, -- vertical squash for an elliptical "halo" orbit
	DIZZY_SPIN_SECONDS = 1.2,

	-- Cappuccino spinning shuriken trail.
	SHURIKEN_PROJECTILE_TRAIL_COLOR = Color3.fromRGB(255, 230, 140),
	SHURIKEN_PROJECTILE_TRAIL_LIFETIME = 0.18,
	SHURIKEN_PROJECTILE_TRAIL_WIDTH = 0.3,
	SHURIKEN_PROJECTILE_GLOW_BRIGHTNESS = 1.8,
	SHURIKEN_PROJECTILE_GLOW_RANGE = 8,
}

table.freeze(VfxConfig)

return VfxConfig
