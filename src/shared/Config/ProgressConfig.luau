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

	-- Starter roster: unlocked + equipped for new players. Keeping the opening
	-- board small (economy + melee + wall) is part of Day 1's balance — the
	-- rest of the launch roster unlocks through UNLOCK_SCHEDULE below.
	DEFAULT_UNLOCKS = {
		"BallerinaCappucina",
		"TungTungSahur",
		"ChimpanziniBananini",
	},

	DEFAULT_EQUIPPED = {
		"BallerinaCappucina",
		"TungTungSahur",
		"ChimpanziniBananini",
	},

	-- Starter-roster unlock cadence: clearing `day` for the first time grants
	-- `brainrotId` (auto-equipped if there's an open loadout slot) and shows
	-- an unlock popup. Ordered by rising cost/power alongside the campaign's
	-- species ramp (see docs/LEVELS.md). Never applies to future post-launch
	-- Brainrots — those cost Brains at the Store (Milestone 22).
	UNLOCK_SCHEDULE = {
		{ day = 3, brainrotId = "CappuccinoAssassino" },
		{ day = 5, brainrotId = "LiriliLarila" },
		{ day = 7, brainrotId = "TralaleroTralala" },
		{ day = 9, brainrotId = "BombardinoCrocodilo" },
	},

	-- Monster / boss intro cadence: the first time the player *reaches* `day`
	-- (Preparation / Day Select / rejoin), LevelService shows a MonsterIntro
	-- popup with portrait + stats + ability blurb. Idempotent via saved
	-- `introducedMonsters`. Aligns with the campaign species ramp in LEVELS.md.
	MONSTER_INTRO_SCHEDULE = {
		{ day = 5, monsterId = "Goblin" },
		{ day = 10, monsterId = "GoblinElite" },
		{ day = 15, monsterId = "Vampire" },
		{ day = 20, monsterId = "DukeVampire" },
		{ day = 25, monsterId = "Spider" },
		{ day = 30, monsterId = "QueenSpider" },
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
