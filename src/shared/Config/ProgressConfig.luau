--!strict
--[[
	ProgressConfig
	Loadout, brains rewards, and progression UX knobs (Milestone 13).
	Physical Brainrots Store / player-upgrade shop (Milestone 18).
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
	-- Brainrots — those cost Brains at the Store (Milestone 18).
	UNLOCK_SCHEDULE = {
		{ day = 3, brainrotId = "CappuccinoAssassino" },
		{ day = 5, brainrotId = "LiriliLarila" },
		{ day = 7, brainrotId = "TralaleroTralala" },
		{ day = 9, brainrotId = "BombardinoCrocodilo" },
	},

	-- Grant on first *reach* of `day` (Preparation / Day Select / rejoin),
	-- not on clear. Catch-up: any entry with day <= current not yet unlocked.
	REACH_UNLOCK_SCHEDULE = {
		{ day = 25, brainrotId = "GiraffaCeleste" },
		{ day = 31, brainrotId = "BrrBrrPatapim" },
	},

	-- Buy with brains at the blue mini store (Tung Mascot). Already-unlocked
	-- units show as owned; campaign grants remain free later.
	STORE_CATALOG = {
		{ brainrotId = "CappuccinoAssassino", brainsCost = 15 },
		{ brainrotId = "LiriliLarila", brainsCost = 25 },
		{ brainrotId = "TralaleroTralala", brainsCost = 40 },
		{ brainrotId = "BombardinoCrocodilo", brainsCost = 80 },
		{ brainrotId = "GiraffaCeleste", brainsCost = 50 },
		{ brainrotId = "BrrBrrPatapim", brainsCost = 60 },
	},

	-- Buy with brains at the red mini store (67 Mascot). Level is persisted
	-- in SaveData.upgrades[id]. Walk speed = PlayerConfig.WALK_SPEED + level * bonus.
	UPGRADE_CATALOG = {
		{
			id = "WalkSpeed",
			name = "Speed",
			description = "Run faster on the plot.",
			maxLevel = 5,
			brainsCosts = { 10, 18, 28, 42, 60 },
			walkSpeedBonusPerLevel = 3,
		},
	},

	-- Reach-day intros for Brainrots that never go through UNLOCK_SCHEDULE
	-- (Day 1 starters + reach-unlocks). Catch-up: any entry with `day` <=
	-- current day that is not yet in SaveData.introducedBrainrots.
	BRAINROT_INTRO_SCHEDULE = {
		{ day = 1, brainrotId = "BallerinaCappucina" },
		{ day = 1, brainrotId = "TungTungSahur" },
		{ day = 1, brainrotId = "ChimpanziniBananini" },
		{ day = 25, brainrotId = "GiraffaCeleste" },
		{ day = 31, brainrotId = "BrrBrrPatapim" },
	},

	-- Monster / boss intro cadence: the first time the player *reaches* `day`
	-- (Preparation / Day Select / rejoin), LevelService shows a MonsterIntro
	-- popup. Catch-up grants every schedule entry with `day` <= current that
	-- is not yet in `introducedMonsters` (Day Select / Studio FORCE_DAY).
	-- Campaign units only — Necromancer / GoblinKing are not in Days 1–50.
	MONSTER_INTRO_SCHEDULE = {
		{ day = 1, monsterId = "Zombie" },
		{ day = 5, monsterId = "Goblin" },
		{ day = 10, monsterId = "GoblinElite" },
		{ day = 15, monsterId = "Vampire" },
		{ day = 20, monsterId = "DukeVampire" },
		{ day = 25, monsterId = "Spider" },
		{ day = 30, monsterId = "QueenSpider" },
		{ day = 31, monsterId = "Skeleton" },
		{ day = 35, monsterId = "Werewolf" },
		{ day = 41, monsterId = "SmallMummy" },
		{ day = 45, monsterId = "Scorpion" },
		{ day = 50, monsterId = "PharaohMummy" },
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
