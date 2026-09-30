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

	-- Sahur's Wrath bat landing: one yellow energy burst (crown + ground ring).
	-- Wider than a tile so a single pulse covers the slam.
	BAT_SLAM_WAVE_COLOR = Color3.fromRGB(255, 196, 32),
	BAT_SLAM_WAVE_COLOR_HOT = Color3.fromRGB(255, 236, 110),
	BAT_SLAM_WAVE_COUNT = 1,
	BAT_SLAM_WAVE_STAGGER = 0.2,
	BAT_SLAM_WIDEN_PER_WAVE = 0.28,
	BAT_SLAM_WAVE_DURATION = 0.5,
	BAT_SLAM_TRANSPARENCY = 0.22,
	BAT_SLAM_CROWN_COUNT = 22,
	BAT_SLAM_CROWN_INNER_COUNT = 16,
	BAT_SLAM_RING_COUNT = 20,
	BAT_SLAM_SPIKE_THICKNESS = TILE * 0.055,
	BAT_SLAM_CROWN_INNER_START_RADIUS = TILE * 0.13,
	BAT_SLAM_CROWN_INNER_END_RADIUS = TILE * 0.9,
	BAT_SLAM_CROWN_INNER_START_LENGTH = TILE * 0.48,
	BAT_SLAM_CROWN_INNER_WIDTH = TILE * 0.15,
	BAT_SLAM_CROWN_START_RADIUS = TILE * 0.2,
	BAT_SLAM_CROWN_END_RADIUS = TILE * 1.5,
	BAT_SLAM_CROWN_START_LENGTH = TILE * 0.56,
	BAT_SLAM_CROWN_WIDTH = TILE * 0.17,
	BAT_SLAM_RING_START_RADIUS = TILE * 0.36,
	BAT_SLAM_RING_END_RADIUS = TILE * 3.4,
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

	-- Green "+" marks that rise and fade around a unit that just healed.
	HEAL_PLUS_COUNT = 7,
	HEAL_PLUS_COLOR = Color3.fromRGB(90, 230, 110),
	HEAL_PLUS_RISE = 2.4,
	HEAL_PLUS_LIFETIME = 0.85,

	-- Floating status words ("Poisoned" / "Stunned") that rise and fade.
	-- When several hit the same Brainrot at once they queue: the lead word
	-- uses the faster duration, then the next plays after it finishes.
	STATUS_FLOAT_SIZE = UDim2.fromOffset(160, 40),
	STATUS_FLOAT_START_OFFSET = Vector3.new(0, 3.2, 0),
	STATUS_FLOAT_RISE_STUDS = 2.4,
	STATUS_FLOAT_DURATION = 1.15, -- solo / last-in-queue
	STATUS_FLOAT_DURATION_LEAD = 0.65, -- faster when another word is waiting
	STATUS_FLOAT_POISON_COLOR = Color3.fromRGB(200, 110, 255),
	STATUS_FLOAT_VENOM_COLOR = Color3.fromRGB(120, 220, 80),
	STATUS_FLOAT_STUN_COLOR = Color3.fromRGB(255, 225, 70),

	-- Pharaoh steal: sand funnel aimed from the boss toward the stolen plants
	-- (not straight up). Sized for Pharaoh's 2-row body.
	SAND_TORNADO_DURATION = 1.6,
	SAND_TORNADO_HEIGHT = 34,
	SAND_TORNADO_RADIUS = 13,
	SAND_TORNADO_SPIN = 7,
	SAND_TORNADO_MESH_TRANSPARENCY = 0.35,
	-- Studs in front of the boss along the funnel. The funnel itself stays level.
	SAND_TORNADO_HAND_OFFSET = 2.5,
	SAND_COLOR_A = Color3.fromRGB(210, 170, 95),
	SAND_COLOR_B = Color3.fromRGB(160, 120, 70),
	SAND_COLOR_C = Color3.fromRGB(235, 200, 140),

	-- Pharaoh entrance tornado. Same funnel shape as the steal, stood upright,
	-- but sized to cover his whole body (the steal funnel is too small).
	-- High is nearly solid. Low is thin enough to see him. Off spawns nothing.
	SPAWN_SANDSTORM_MIN_WIDTH = TILE * 2.4,
	SPAWN_SANDSTORM_MIN_HEIGHT = TILE * 3.2,
	SPAWN_SANDSTORM_WIDTH_PAD = 1.35,
	SPAWN_SANDSTORM_HEIGHT_PAD = 1.35,
	SPAWN_SANDSTORM_HIGH_TRANSPARENCY = 0.04,
	SPAWN_SANDSTORM_LOW_TRANSPARENCY = 0.62,
	SPAWN_SANDSTORM_FADE = 0.16,

	-- La Vacca lane pull: shrinking rings on her, grit sucked from the monster.
	GRAVITY_PULL_DURATION = 0.85,
	GRAVITY_PULL_RADIUS = TILE * 0.85,
	GRAVITY_PULL_COLOR = Color3.fromRGB(170, 140, 255),
	GRAVITY_PULL_COLOR_DIM = Color3.fromRGB(90, 60, 160),

	-- Boneca poof when she leaves after her last headbutt.
	POOF_COLOR = Color3.fromRGB(235, 235, 235),
	POOF_BURST = 26,
	POOF_SIZE = 3.2,
	POOF_SPEED = 9,
	POOF_LIFETIME = 0.8,

	-- Blueberrinni ink lob. Off skips the droplet. Low keeps the drop and drops the tail.
	INK_FLIGHT_SECONDS = 2.2,
	INK_ARC_HEIGHT_MIN = 6, -- nearest empty tile
	INK_ARC_HEIGHT_MAX = 22, -- farthest empty tile
	INK_COLOR = Color3.fromRGB(12, 24, 92),

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
	PIERCE_SHURIKEN_SPARK_RATE = 72,
	PIERCE_SHURIKEN_SPARK_SPEED = NumberRange.new(2.5, 8),
	PIERCE_SHURIKEN_SPARK_LIFETIME = NumberRange.new(0.22, 0.48),
	PIERCE_SHURIKEN_SPARK_SIZE = 0.7,
	PIERCE_SHURIKEN_EMBER_RATE = 38,
	PIERCE_SHURIKEN_EMBER_SPEED = NumberRange.new(6, 14),
	PIERCE_SHURIKEN_EMBER_LIFETIME = NumberRange.new(0.16, 0.32),

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

	-- Shadow Requiem: vertical backwards-C ")" (bulge leads +X). White fill,
	-- black outline + black flame/trail streaks. Y height grows with travel.
	-- Last-tile finale is a tall white neon pillar with one black ribbon
	-- that climbs around it as the column rises.
	SWORD_WAVE_COLOR = Color3.fromRGB(8, 8, 10), -- outline + streaks
	SWORD_WAVE_COLOR_INNER = Color3.fromRGB(255, 255, 255), -- crescent fill
	SWORD_WAVE_COLOR_EDGE = Color3.fromRGB(8, 8, 10),
	SWORD_WAVE_WIDTH = TILE * 0.2, -- Z thickness (one wave, same span as the old pair)
	SWORD_WAVE_STROKE = 1.05, -- XY ribbon thickness (volume on the leading edge)
	SWORD_WAVE_WAKE_STROKE = 1.65, -- black outline thickness around the white fill
	SWORD_WAVE_START_HEIGHT = TILE * 0.32, -- Y span at spawn
	SWORD_WAVE_END_HEIGHT = TILE * 1.85, -- Y span at full travel
	SWORD_WAVE_BOW = TILE * 0.48, -- how far the tips sit west of the bulge
	SWORD_WAVE_TIP_START = 0.52, -- |t| where the blade begins thinning
	SWORD_WAVE_TIP_MIN = 0.05, -- stroke/width scale at the crescent points
	SWORD_WAVE_SEGMENTS = 18,
	SWORD_WAVE_GLOW_BRIGHTNESS = 3.2,
	SWORD_WAVE_GLOW_RANGE = 16,
	SWORD_WAVE_FLAME_RATE = 24,
	SWORD_WAVE_FLAME_EVERY = 2, -- flame on every Nth crescent segment
	SWORD_WAVE_FLAME_SPEED = NumberRange.new(22, 42),
	SWORD_WAVE_FLAME_LIFETIME = NumberRange.new(0.28, 0.52),
	SWORD_WAVE_FLAME_SPREAD = Vector2.new(24, 42),
	SWORD_WAVE_TRAIL_LIFETIME = 0.48,
	SWORD_WAVE_TRAIL_WIDTH = 1,
	SWORD_WAVE_PILLAR_HEIGHT = TILE * 3.1,
	SWORD_WAVE_PILLAR_START_RADIUS = TILE * 0.08, -- spawn thin, then expand
	SWORD_WAVE_PILLAR_END_RADIUS = TILE * 0.4, -- diameter a bit under one lawn tile
	SWORD_WAVE_PILLAR_CORE_RATIO = 0.78, -- core diameter vs halo
	SWORD_WAVE_PILLAR_TRANSPARENCY = 0.08,
	SWORD_WAVE_PILLAR_GLOW_BRIGHTNESS = 9,
	SWORD_WAVE_PILLAR_GLOW_RANGE = 10, -- at spawn; scales up with expand
	SWORD_WAVE_PILLAR_GLOW_RANGE_MAX = 18,
	SWORD_WAVE_PILLAR_SPIRAL_SEGMENTS = 28,
	SWORD_WAVE_PILLAR_SPIRAL_TURNS = 2.5, -- revolutions over the pillar height
	SWORD_WAVE_PILLAR_SPIRAL_THICKNESS = 0.55,
	SWORD_WAVE_PILLAR_SPIRAL_RADIUS = 1.18, -- multiple of the pillar radius
	SWORD_WAVE_PILLAR_SPIRAL_CLIMB = 0.75, -- helix wraps per second (ascends)

	-- Heavy GOD-ult VFX. Client Settings pick High / Low / Off. The server
	-- always authors the full effect. Damage is unchanged.
	HEAVY_VFX_SWORD_WAVE = 2,
	HEAVY_VFX_PILLAR = 5,
	HEAVY_VFX_BAT_SLAM = 2,
	HEAVY_VFX_JACKPOT = 1,
	HEAVY_VFX_BAT_SLAM_RELEASE = 1.8,
	HEAVY_VFX_JACKPOT_RELEASE = 0.7,
	HEAVY_VFX_MUSHROOM = 2,
	HEAVY_VFX_MUSHROOM_RELEASE = 1.2,

	-- Boneca God of Thunder: a jagged bolt drops from the sky onto a monster.
	LIGHTNING_COLOR = Color3.fromRGB(70, 150, 255),
	LIGHTNING_CORE_COLOR = Color3.fromRGB(215, 235, 255),
	LIGHTNING_HEIGHT = 45, -- studs above the monster's feet where the bolt starts
	LIGHTNING_SEGMENTS = 9,
	LIGHTNING_JITTER = 1.8, -- max sideways kink per joint (studs)
	LIGHTNING_THICKNESS = 0.35,
	LIGHTNING_GLOW_THICKNESS = 1.1,
	LIGHTNING_DESCEND_SECONDS = 0.1, -- top-to-ground draw time
	LIGHTNING_HOLD_SECONDS = 0.12,
	LIGHTNING_FADE_SECONDS = 0.2,
	LIGHTNING_BRANCHES = 2,
	LIGHTNING_FLASH_SIZE = 6,
	LIGHTNING_BURST_COUNT = 18,
	-- Rolling Thunder currents (struck monster → nearby monsters).
	CURRENT_SEGMENT_LENGTH = 2.5, -- studs per kink
	CURRENT_JITTER = 0.9,
	CURRENT_THICKNESS = 0.22,
	CURRENT_BURST_COUNT = 8,

	-- Mushroom cloud (Boneca GOD Last Laugh on her last headbutt). Sizes are multiples of `radius` (half the covered tiles' width
	-- × MUSHROOM_RADIUS_SCALE).
	MUSHROOM_RADIUS_SCALE = 1.1,
	MUSHROOM_HEIGHT_SCALE = 1.6, -- stem height
	MUSHROOM_STEM_WIDTH_SCALE = 0.35,
	MUSHROOM_CAP_WIDTH_SCALE = 1.6,
	MUSHROOM_CAP_HEIGHT_SCALE = 0.8,
	MUSHROOM_RISE_SECONDS = 0.45, -- stem shoots up, cap rides the top
	MUSHROOM_BILLOW_SECONDS = 0.6, -- cap swells while everything smokes out
	MUSHROOM_FLASH_SECONDS = 0.25,
	MUSHROOM_RING_SECONDS = 0.55,
	MUSHROOM_RING_SCALE = 1.5, -- ground ring diameter vs covered width
	MUSHROOM_BURST_COUNT = 40,
	MUSHROOM_STEM_COLOR = Color3.fromRGB(255, 170, 70),
	MUSHROOM_CAP_COLOR = Color3.fromRGB(255, 130, 40),
	MUSHROOM_CORE_COLOR = Color3.fromRGB(255, 240, 190),
	MUSHROOM_SMOKE_COLOR = Color3.fromRGB(90, 80, 75),

	-- Jackpot (Ballerina GOD) gold burst at the plant.
	JACKPOT_COLOR = Color3.fromRGB(255, 205, 40),
	JACKPOT_BURST_COUNT = 22,
	JACKPOT_BURST_SPEED = 16,
	JACKPOT_BURST_SIZE = 0.42,
	JACKPOT_BURST_LIFETIME = 0.55,

	-- Planted evolution aura: flame spikes only (no sparkles / speed lines).
	-- High plays the core column plus an extra layer. Low keeps a thin core.
	-- Off drops the flames on the client; the Highlight outline stays.
	-- Size/speed stay in BrainrotFeedback so the column does not grow.
	BRAINROT_AURA_SPIKES_RATE = 48,
	BRAINROT_AURA_EXTRA_RATE = 40,
	BRAINROT_AURA_SPIKES_RATE_LOW = 12,

	-- Tralalero Abyssal Torrent. Purple beam from the snout: dim core, darker
	-- glow, rings, and spiral streaks. Sized under a full tile.
	HYDRO_JET_CORE_THICKNESS = 0.7,
	HYDRO_JET_CORE_WIDTH = 1.05,
	HYDRO_JET_WATER_WIDTH = TILE * 0.1,
	HYDRO_JET_DEEP_WIDTH = TILE * 0.17,
	HYDRO_JET_RING_RADIUS = TILE * 0.14,
	HYDRO_JET_RING_GROW = TILE * 0.06,
	HYDRO_JET_HELIX_RADIUS = TILE * 0.05,
	HYDRO_JET_CORE_COLOR = Color3.fromRGB(220, 180, 255),
	HYDRO_JET_WATER_COLOR = Color3.fromRGB(140, 50, 230),
	HYDRO_JET_DEEP_COLOR = Color3.fromRGB(48, 8, 90),
	HYDRO_JET_RING_COUNT = 4,
	HYDRO_JET_RING_SEGMENTS = 8,
	HYDRO_JET_STREAKS = 6,
	HYDRO_JET_HELIX_POINTS = 22,
	HYDRO_JET_HELIX_TURNS = 7,
	HYDRO_JET_SPIN = 4,
	-- Soap bubbles around the beam. High only; Low and Off hide them on the client.
	HYDRO_JET_BUBBLE_COUNT = 12,
	HYDRO_JET_BUBBLE_SIZE = 2.2,
	HYDRO_JET_BUBBLE_RADIUS = TILE * 0.24,
	HYDRO_JET_BUBBLE_COLOR = Color3.fromRGB(245, 236, 255),
	HYDRO_JET_BUBBLE_TRANSPARENCY = 0.18,

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
