--!strict
--[[
	LevelConfig
	Global pacing for the PvZ-style campaign. Per-level content lives in
	Shared.Levels. Milestone 14 balance pass — see docs/BALANCE.md.
]]

local LevelConfig = {
	PREPARATION_TIME = 30, -- reserved prep window before Start (planned)

	-- Brief Start Day overlay: UI shows 3, 2, 1, 0 (1s each) then Active.
	-- Forest march after Active is still the plant/setup window.
	COUNTDOWN_TIME = 4,
	PAUSE_RESUME_SECONDS = 3,

	STARTING_PLAYER_HEALTH = 5, -- hearts; one lost per house breach

	BIG_WAVE_WARNING_TIME = 5, -- seconds before a big wave group spawns

	DEFAULT_SPAWN_INTERVAL = 1.8, -- seconds between monsters within a group
	DEFAULT_GROUP_DELAY = 7, -- seconds between consecutive groups
}

table.freeze(LevelConfig)

return LevelConfig
