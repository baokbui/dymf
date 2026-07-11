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
}

table.freeze(BrainrotConfig)

return BrainrotConfig
