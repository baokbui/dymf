--!strict
--[[
	LevelConfig
	Global pacing for the PvZ-style campaign. Per-level *content* — which
	monsters, how many, and when — is authored as data in the Shared.Levels
	registry; this module only holds the pacing/UX knobs shared by every level.

	Owned conceptually by LevelService (Milestone 8). Tune here, never inline.
]]

local LevelConfig = {
	PREPARATION_TIME = 30, -- reserved prep window before Start (planned)
	COUNTDOWN_TIME = 3, -- seconds after pressing Start Level

	STARTING_PLAYER_HEALTH = 100,

	-- Lead time for the "a huge wave is approaching!" banner before a big wave.
	BIG_WAVE_WARNING_TIME = 4,

	-- Fallbacks used when a SpawnGroup omits its own timing (see Types.SpawnGroup).
	DEFAULT_SPAWN_INTERVAL = 1.5, -- seconds between monsters within a group
	DEFAULT_GROUP_DELAY = 6, -- seconds between consecutive groups
}

table.freeze(LevelConfig)

return LevelConfig
