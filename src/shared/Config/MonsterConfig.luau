--!strict
--[[
	MonsterConfig
	Global monster tuning constants. Per-unit stats live in Shared.Monsters.
]]

local MonsterConfig = {
	-- Server movement/AI tick (seconds).
	BEHAVIOR_TICK = 0.1,

	-- Column just east of the grid where monsters spawn (fractional grid coords).
	SPAWN_COLUMN_OFFSET = 0.5,

	-- Column west of column 1 — reaching here breaches the house (M8 defeat).
	HOUSE_BREACH_COLUMN = 0.5,

	-- Half a grid column in fractional space (tile edge = center ± this value).
	TILE_HALF_WIDTH = 0.5,

	-- Minimal eastward nudge when movement overshoots into a defended tile.
	MELEE_OVERSHOOT_EPSILON = 0.02,

	-- How far into the east-adjacent stand tile melee monsters move before stopping
	-- (from the brainrot tile's east edge). Lower = closer to the Brainrot.
	MELEE_CLOSE_REACH = 0.35,

	-- Visual body size relative to a tile.
	BODY_HEIGHT = 7,
	FOOTPRINT_RATIO = 0.72,

	-- Attack pulse tween (replicated on model body).
	ATTACK_PULSE_SCALE = 1.15,
	ATTACK_PULSE_DURATION = 0.1,

	-- Damage flash on the body (replicated to clients).
	HIT_FLASH_COLOR = Color3.fromRGB(255, 90, 90),
	HIT_FLASH_DURATION = 0.14,

	-- Freeze / stun tint (Lirili Larila).
	FREEZE_COLOR = Color3.fromRGB(160, 220, 255),
	FREEZE_MATERIAL = Enum.Material.Ice,

	-- Bubble trap (Tralalero) — float in a translucent sphere until it pops.
	BUBBLE_COLOR = Color3.fromRGB(170, 230, 255),
	BUBBLE_TRANSPARENCY = 0.45,
	BUBBLE_SIZE_PADDING = 2.2,
	BUBBLE_FLOAT_OFFSET = 2.8,
	BUBBLE_BOB_AMPLITUDE = 0.35,
	BUBBLE_BOB_SPEED = 5,
	BUBBLE_POP_DURATION = 0.18,

	-- Studio dev spawns until LevelService drives waves (Milestone 8).
	-- Each tick spawns one monster on a random grid row.
	DEV_SPAWN = {
		ENABLED = false,
		MONSTER_ID = "Zombie",
		INTERVAL = 10,
	},

	-- Default tint when a definition omits color.
	DEFAULT_COLOR = Color3.fromRGB(120, 80, 140),
}

table.freeze(MonsterConfig.DEV_SPAWN)
table.freeze(MonsterConfig)

return MonsterConfig
