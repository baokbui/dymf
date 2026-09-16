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
	DISINTEGRATE_PARTICLE_LIFETIME = 1.1,
	DISINTEGRATE_BURST_PER_PART = 6,
	DISINTEGRATE_RATE = 10,
	DISINTEGRATE_MAX_PARTS = 6,
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

	-- Sahur's Wrath bat landing: yellow energy burst (crown + ground ring).
	-- Sized to lawn tiles so the slam reads across ~2 tiles, not a small spark.
	BAT_SLAM_WAVE_COLOR = Color3.fromRGB(255, 196, 32),
	BAT_SLAM_WAVE_COLOR_HOT = Color3.fromRGB(255, 236, 110),
	BAT_SLAM_WAVE_COUNT = 4,
	BAT_SLAM_WAVE_STAGGER = 0.2,
	BAT_SLAM_WIDEN_PER_WAVE = 0.28,
	BAT_SLAM_WAVE_DURATION = 0.5,
	BAT_SLAM_TRANSPARENCY = 0.22,
	BAT_SLAM_CROWN_COUNT = 22,
	BAT_SLAM_CROWN_INNER_COUNT = 16,
	BAT_SLAM_RING_COUNT = 20,
	BAT_SLAM_SPIKE_THICKNESS = TILE * 0.055,
	BAT_SLAM_CROWN_INNER_START_RADIUS = TILE * 0.13,
	BAT_SLAM_CROWN_INNER_END_RADIUS = TILE * 0.48,
	BAT_SLAM_CROWN_INNER_START_LENGTH = TILE * 0.48,
	BAT_SLAM_CROWN_INNER_WIDTH = TILE * 0.15,
	BAT_SLAM_CROWN_START_RADIUS = TILE * 0.2,
	BAT_SLAM_CROWN_END_RADIUS = TILE * 0.8,
	BAT_SLAM_CROWN_START_LENGTH = TILE * 0.56,
	BAT_SLAM_CROWN_WIDTH = TILE * 0.17,
	BAT_SLAM_RING_START_RADIUS = TILE * 0.36,
	BAT_SLAM_RING_END_RADIUS = TILE * 1.95,
	BAT_SLAM_RING_START_LENGTH = TILE * 0.4,
	BAT_SLAM_RING_WIDTH = TILE * 0.2,

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
	-- BubbleTrap: cyan soap sphere (no trail). Barrage uses the gold set below.
	BUBBLE_PROJECTILE_COLOR = Color3.fromRGB(170, 230, 255),
	BUBBLE_PROJECTILE_INNER_COLOR = Color3.fromRGB(230, 250, 255),
	BUBBLE_PROJECTILE_GLOW_BRIGHTNESS = 0.85,
	BUBBLE_PROJECTILE_GLOW_RANGE = 7,
	-- Bubble Barrage seed + 5 lane bubbles: gold body and gold light-streaks.
	BUBBLE_BARRAGE_COLOR = Color3.fromRGB(255, 196, 64),
	BUBBLE_BARRAGE_INNER_COLOR = Color3.fromRGB(255, 236, 170),
	BUBBLE_BARRAGE_STREAK_COLOR = Color3.fromRGB(255, 196, 48),
	BUBBLE_BARRAGE_STREAK_COLOR_TAIL = Color3.fromRGB(255, 140, 20),
	BUBBLE_BARRAGE_STREAK_LIFETIME = 0.4,
	BUBBLE_BARRAGE_STREAK_WIDTH = 0.9,
	BUBBLE_BARRAGE_STREAK_LIGHT_EMISSION = 0.35,

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

	-- Dizzy stars orbiting over a Brainrot afflicted by Stun / Terrify (classic
	-- cartoon "dizzy" halo).
	DIZZY_COLOR = Color3.fromRGB(255, 225, 90),
	DIZZY_SIZE = UDim2.fromOffset(90, 90),
	DIZZY_OFFSET = Vector3.new(0, 2.4, 0),
	DIZZY_STAR_COUNT = 3,
	DIZZY_STAR_SIZE = UDim2.fromOffset(26, 26),
	DIZZY_ORBIT_RADIUS = 22, -- pixels, in the billboard's 2D plane
	DIZZY_ORBIT_FLATTEN = 0.45, -- vertical squash for an elliptical "halo" orbit
	DIZZY_SPIN_SECONDS = 1.2,

	-- Floating status words ("Poisoned" / "Stunned") that rise and fade.
	-- When several hit the same Brainrot at once they queue: the lead word
	-- uses the faster duration, then the next plays after it finishes.
	STATUS_FLOAT_SIZE = UDim2.fromOffset(160, 40),
	STATUS_FLOAT_START_OFFSET = Vector3.new(0, 3.2, 0),
	STATUS_FLOAT_RISE_STUDS = 2.4,
	STATUS_FLOAT_DURATION = 1.15, -- solo / last-in-queue
	STATUS_FLOAT_DURATION_LEAD = 0.65, -- faster when another word is waiting
	STATUS_FLOAT_POISON_COLOR = Color3.fromRGB(200, 110, 255),
	STATUS_FLOAT_STUN_COLOR = Color3.fromRGB(255, 225, 70),

	-- Pharaoh steal: sand tornado at the boss + grit sucked from each plant.
	SAND_TORNADO_DURATION = 1.6,
	SAND_TORNADO_HEIGHT = 18,
	SAND_TORNADO_RADIUS = 6.5,
	SAND_TORNADO_SPIN = 7,
	SAND_TORNADO_MESH_TRANSPARENCY = 0.35,
	-- Local studs from the steal-hand part (along tornado axis).
	SAND_TORNADO_HAND_OFFSET = 0.9,
	SAND_COLOR_A = Color3.fromRGB(210, 170, 95),
	SAND_COLOR_B = Color3.fromRGB(160, 120, 70),
	SAND_COLOR_C = Color3.fromRGB(235, 200, 140),

	-- Giraffa plot-wide gust that blows Night Fog off the lawn.
	WIND_GUST_DURATION = 1.5,
	WIND_GUST_RATE = 28,
	WIND_GUST_BURST = 14,
	WIND_GUST_SPEED = 72,
	WIND_GUST_LIFETIME = NumberRange.new(0.9, 1.4),
	WIND_GUST_SIZE = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 14),
		NumberSequenceKeypoint.new(0.4, 11),
		NumberSequenceKeypoint.new(1, 1.2),
	}),
	WIND_GUST_COLOR_A = Color3.fromRGB(245, 252, 255),
	WIND_GUST_COLOR_B = Color3.fromRGB(160, 210, 255),
	WIND_GUST_ACCEL_EAST = 38,

	-- Cappuccino spinning shuriken trail.
	SHURIKEN_PROJECTILE_TRAIL_COLOR = Color3.fromRGB(255, 230, 140),
	SHURIKEN_PROJECTILE_TRAIL_LIFETIME = 0.18,
	SHURIKEN_PROJECTILE_TRAIL_WIDTH = 0.3,
	SHURIKEN_PROJECTILE_GLOW_BRIGHTNESS = 1.8,
	SHURIKEN_PROJECTILE_GLOW_RANGE = 8,

	-- Piercing Brew (Legendary) shuriken — gold so the extra is readable in flight.
	PIERCE_SHURIKEN_AURA_COLOR = Color3.fromRGB(255, 196, 48),
	-- Saturated gold (keep LightEmission low on the Trail or this reads as white).
	PIERCE_SHURIKEN_TRAIL_COLOR = Color3.fromRGB(255, 176, 28),
	PIERCE_SHURIKEN_TRAIL_COLOR_TAIL = Color3.fromRGB(255, 120, 16),
	PIERCE_SHURIKEN_TRAIL_LIFETIME = 0.55,
	PIERCE_SHURIKEN_TRAIL_WIDTH = 0.95,
	PIERCE_SHURIKEN_TRAIL_LIGHT_EMISSION = 0.22,
	PIERCE_SHURIKEN_GLOW_BRIGHTNESS = 4.2,
	PIERCE_SHURIKEN_GLOW_RANGE = 14,

	-- Banana Bastion shield bubble (server-replicated on the plant).
	SHIELD_BUBBLE_COLOR = Color3.fromRGB(70, 175, 255),
	SHIELD_BUBBLE_TRANSPARENCY = 0.62,
	SHIELD_BUBBLE_PADDING = 1.18,
	SHIELD_HP_FILL = Color3.fromRGB(70, 185, 255),

	-- Tung Tenfold Guard: small Shield from Assets.Projectiles orbits the plant.
	SHIELD_ORBIT_SIZE = 2.2,
	SHIELD_ORBIT_RADIUS = 3.4,
	SHIELD_ORBIT_LIFT = 1.3,
	SHIELD_ORBIT_PERIOD = 1.5,

	-- Chimpanzini Primal Retaliation: small Mirror from Assets.Projectiles orbits the plant.
	MIRROR_ORBIT_SIZE = 2.2,
	MIRROR_ORBIT_RADIUS = 3.4,
	MIRROR_ORBIT_LIFT = 1.3,
	MIRROR_ORBIT_PERIOD = 1.5,

	-- Shadow Requiem: vertical backwards-C ")" (bulge leads +X). Black slash;
	-- Y height grows with travel.
	SWORD_WAVE_COLOR = Color3.fromRGB(8, 8, 10),
	SWORD_WAVE_COLOR_EDGE = Color3.fromRGB(22, 22, 26),
	SWORD_WAVE_WIDTH = TILE * 0.1, -- Z thickness
	SWORD_WAVE_STROKE = 1.35, -- XY ribbon thickness (volume on the leading edge)
	SWORD_WAVE_WAKE_OFFSET = 2.4, -- studs west of the leading crescent
	SWORD_WAVE_WAKE_STROKE = 2.1,
	SWORD_WAVE_START_HEIGHT = TILE * 0.32, -- Y span at spawn
	SWORD_WAVE_END_HEIGHT = TILE * 1.85, -- Y span at full travel
	SWORD_WAVE_BOW = TILE * 0.48, -- how far the tips sit west of the bulge
	SWORD_WAVE_SEGMENTS = 18,
	SWORD_WAVE_GLOW_BRIGHTNESS = 3.2,
	SWORD_WAVE_GLOW_RANGE = 16,
	SWORD_WAVE_FLAME_RATE = 40,
	SWORD_WAVE_FLAME_SPEED = NumberRange.new(22, 42),
	SWORD_WAVE_FLAME_LIFETIME = NumberRange.new(0.28, 0.52),
	SWORD_WAVE_FLAME_SPREAD = Vector2.new(24, 42),
	SWORD_WAVE_TRAIL_LIFETIME = 0.48,
	SWORD_WAVE_TRAIL_WIDTH = 1.25,

	-- Jackpot (Ballerina GOD) gold burst at the plant.
	JACKPOT_COLOR = Color3.fromRGB(255, 205, 40),
	JACKPOT_BURST_COUNT = 22,
	JACKPOT_BURST_SPEED = 16,
	JACKPOT_BURST_SIZE = 0.42,
	JACKPOT_BURST_LIFETIME = 0.55,

	-- Planted evolution aura: flame spikes only (no sparkles / speed lines).
	-- Rate = how many flames; size/speed stay in BrainrotFeedback so the
	-- column does not grow taller or thicker.
	BRAINROT_AURA_SPIKES_RATE = 36,

	-- Magnet pull: translucent purple rings that spawn at the outer
	-- pull range and collapse inward toward the player.
	MAGNET_WAVE_COLOR = Color3.fromRGB(170, 70, 255),
	MAGNET_WAVE_INTERVAL = 0.14,
	MAGNET_WAVE_SPEED = 26, -- studs / second
	MAGNET_WAVE_START_RADIUS = TILE * 0.85,
	MAGNET_WAVE_END_RADIUS = 1.4,
	MAGNET_WAVE_SEGMENTS = 24,
	MAGNET_WAVE_THICKNESS = 0.72,
	MAGNET_WAVE_TRANSPARENCY = 0.85,
	MAGNET_WAVE_LIFT = 0.2,
}

table.freeze(VfxConfig)

return VfxConfig
