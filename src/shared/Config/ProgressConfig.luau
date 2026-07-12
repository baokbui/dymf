--!strict
--[[
	ProgressConfig
	Loadout, brains rewards, and progression UX knobs (Milestone 13).
	Physical Brainrots Store purchases are deferred (see ROADMAP Milestone 20).
]]

local ProgressConfig = {
	-- House HP shown as hearts. One heart lost per monster that reaches the house.
	MAX_PLAYER_HEALTH = 5,

	-- Soft currency for future store unlocks (granted on level clear).
	STARTING_BRAINS = 0,

	-- Max Brainrots shown in the placement shop bar at once.
	MAX_EQUIPPED = 7,

	-- Starter roster: unlocked + equipped for new players (all current units).
	DEFAULT_UNLOCKS = {
		"BallerinaCappucina",
		"TungTungSahur",
		"TralaleroTralala",
		"BombardinoCrocodilo",
		"LiriliLarila",
		"CappuccinoAssassino",
		"ChimpanziniBananini",
	},

	DEFAULT_EQUIPPED = {
		"BallerinaCappucina",
		"TungTungSahur",
		"TralaleroTralala",
		"BombardinoCrocodilo",
		"LiriliLarila",
		"CappuccinoAssassino",
		"ChimpanziniBananini",
	},

	-- Brains granted on victory = level number * this multiplier (level 1 → 1).
	BRAINS_PER_LEVEL_NUMBER = 1,

	-- Statistic keys written by ProgressService.
	STAT_LEVELS_CLEARED = "levelsCleared",
	STAT_BRAINROTS_PLACED = "brainrotsPlaced",
	STAT_MONSTERS_DEFEATED = "monstersDefeated",
	STAT_TIME_PLAYED = "timePlayedSeconds",
	STAT_BRAINS_EARNED = "brainsEarned",
}

table.freeze(ProgressConfig)

return ProgressConfig
