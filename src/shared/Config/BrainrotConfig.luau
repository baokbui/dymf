--!strict
--[[
	BrainrotConfig
	Global Brainrot tuning constants. Per-unit stats live in the Shared.Brainrots
	registry; ability-specific defaults that are not per-unit belong here.
]]

local BrainrotConfig = {
	-- rangeTiles value that means "entire row toward the enemy" (+X).
	FULL_LINE_RANGE = -1,

	-- Default bat-melee reach in fractional grid columns ahead of the Brainrot.
	-- Matches the distance monsters stop at when chewing (see MonsterConfig).
	MELEE_BAT_REACH = 0.85,

	-- Server behavior tick rate (seconds). Cooldowns count down on this step.
	BEHAVIOR_TICK = 0.1,

	-- Visual attack pulse (server tween, replicated on the model body).
	ATTACK_PULSE_SCALE = 1.18,
	ATTACK_PULSE_DURATION = 0.12,

	-- Authored models face this world direction when placed (toward the enemy).
	MODEL_FACE_DIRECTION = Vector3.new(1, 0, 0),

	-- Damage flash on hit (replicated body color; mirrors MonsterConfig).
	HIT_FLASH_COLOR = Color3.fromRGB(255, 90, 90),
	HIT_FLASH_DURATION = 0.14,

	-- Bombardino line-bomb fly-over (house → enemy along the planted row).
	LINE_BOMB_FLIGHT_DURATION = 1.0,
	LINE_BOMB_FLY_HEIGHT = 20,
}

table.freeze(BrainrotConfig)

return BrainrotConfig
