--!strict
--[[
	MonsterConfig
	Global monster tuning constants. Per-unit stats live in Shared.Monsters.
]]

local MonsterConfig = {
	-- Server movement/AI tick (seconds).
	BEHAVIOR_TICK = 0.1,

	-- Columns east of the lawn where monsters spawn (fractional grid coords).
	-- Deep enough to sit in the dark forest past FOREST_CLEAR_WEST; the walk
	-- from here to the plot is the day's plant/setup window (no idle countdown).
	-- Zombie (~3.5s/tile) ≈ 21s; Goblin (~2.7s/tile) ≈ 16s to reach the lawn edge.
	SPAWN_COLUMN_OFFSET = 6,

	-- Column west of column 1 — reaching here breaches the house (M8 defeat).
	HOUSE_BREACH_COLUMN = 0.5,

	-- Half a grid column in fractional space (tile edge = center ± this value).
	TILE_HALF_WIDTH = 0.5,

	-- How far east of the Brainrot's column center monsters stop while chewing.
	-- Keeps a visible gap so models don't overlap ("hugging"). Must stay < 0.5
	-- so the monster remains on the plant tile for engagement / melee range.
	MELEE_CLOSE_REACH = 0.42,

	-- Minimal nudge so fractional column never sits exactly on a tile boundary.
	MELEE_OVERSHOOT_EPSILON = 0.02,

	-- Visual body size relative to a tile.
	-- Authored models scale to BODY_HEIGHT (and not wider than FOOTPRINT_RATIO * tile).
	BODY_HEIGHT = 7,
	FOOTPRINT_RATIO = 0.72,

	-- Multi-lane bosses (laneSpan > 1): uniform scale so Z covers ~laneSpan tiles.
	LANE_SPAN_FOOTPRINT_RATIO = 0.92,

	-- Attack pulse tween (replicated on model body).
	ATTACK_PULSE_SCALE = 1.15,
	ATTACK_PULSE_DURATION = 0.1,

	-- Damage flash on the body (replicated to clients).
	HIT_FLASH_COLOR = Color3.fromRGB(255, 90, 90),
	HIT_FLASH_DURATION = 0.14,

	-- Freeze / stun tint (Lirili Larila). Bright ice so authored meshes read
	-- clearly even under a soft Highlight wash.
	FREEZE_COLOR = Color3.fromRGB(140, 210, 255),
	FREEZE_MATERIAL = Enum.Material.Ice,
	FREEZE_HIGHLIGHT_FILL = 0.35,
	FREEZE_HIGHLIGHT_OUTLINE = 0.15,

	-- Bubble trap (Tralalero) — float in a translucent sphere until it pops.
	BUBBLE_COLOR = Color3.fromRGB(170, 230, 255),
	BUBBLE_TRANSPARENCY = 0.45,
	BUBBLE_SIZE_PADDING = 2.2,
	BUBBLE_FLOAT_OFFSET = 2.8,
	BUBBLE_BOB_AMPLITUDE = 0.35,
	BUBBLE_BOB_SPEED = 5,
	BUBBLE_POP_DURATION = 0.18,

	-- Authored models face this world direction when spawned (toward the house).
	MODEL_FACE_DIRECTION = Vector3.new(-1, 0, 0),

	-- Default R15 catalog anims when a definition / model omits IDs.
	-- Override per monster via walkAnimationId / attackAnimationId, or by
	-- parenting Animation instances named WalkAnimation / AttackAnimation under
	-- the Assets.Monsters template.
	DEFAULT_WALK_ANIMATION_ID = "rbxassetid://507777826", -- R15 Walk
	DEFAULT_ATTACK_ANIMATION_ID = "rbxassetid://522635514", -- R15 ToolSlash (club swing)

	-- Procedural crawl gait (MonsterDefinition.proceduralWalk — e.g. Spider).
	-- Drives Motor6D / Bone / Weld limb joints; no uploaded Animation required.
	PROCEDURAL_WALK_HZ = 2.4,
	PROCEDURAL_WALK_PITCH = 0.38, -- radians
	PROCEDURAL_WALK_ROLL = 0.22,

	-- Spider-style jump-over (first Brainrot). Defaults; per-monster overrides
	-- live in `abilityParams` (jumpDuration / jumpPeakHeight / jumpLandOffset /
	-- jumpTriggerReach). Leap starts when the monster is this many columns
	-- east of the plant center (must be > MELEE_CLOSE_REACH so it leaps
	-- before chewing).
	JUMP_DURATION = 0.55,
	JUMP_PEAK_HEIGHT = 5.5,
	JUMP_LAND_OFFSET = 0.8, -- columns west of plant center to land
	JUMP_TRIGGER_REACH = 0.95,

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
