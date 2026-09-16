--!strict
--[[
	ProgressConfig
	Loadout, brains rewards, and progression UX knobs (Milestone 13).
	Physical Brainrots Store / player-upgrade shop (Milestone 18).
]]

local ProgressConfig = {
	-- House HP shown as hearts. One heart lost per monster that reaches the house.
	MAX_PLAYER_HEALTH = 5,

	-- Soft currency for the Progression Store (granted on level clear).
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

	-- Support-job XP (coins, wall soaks, freeze, landed hits) coalesces into
	-- one ProfileUpdated so Inventory ViewportFrames are not remounted per tick.
	XP_BROADCAST_INTERVAL = 0.35,

	-- Grant on first *reach* of `day` (Preparation / Day Select / rejoin),
	-- not on clear. Catch-up: any entry with day <= current not yet unlocked.
	REACH_UNLOCK_SCHEDULE = {
		{ day = 25, brainrotId = "GiraffaCeleste" },
		{ day = 31, brainrotId = "BrrBrrPatapim" },
	},

	-- Buy with brains at the physical Brainrot shop (Tung Mascot). Starter-roster
	-- units (DEFAULT_UNLOCKS + UNLOCK_SCHEDULE) and Patapim stay campaign-only.
	-- Giraffa can be bought early; reach Day 25 still grants her for free.
	STORE_CATALOG = {
		{ brainrotId = "GiraffaCeleste", brainsCost = 50 },
	},

	-- Buy with brains from the HUD Upgrades shop. Level is persisted
	-- in SaveData.upgrades[id]. Walk speed = PlayerConfig.WALK_SPEED + level * bonus.
	-- 20 levels × +1 WalkSpeed: 16 → 36 at max. Players who already maxed the
	-- old 10-rank track can keep buying.
	UPGRADE_CATALOG = {
		{
			id = "WalkSpeed",
			name = "Speed",
			description = "Run faster to collect coins on the plot.",
			maxLevel = 20,
			brainsCosts = {
				6,
				10,
				14,
				19,
				25,
				32,
				41,
				52,
				65,
				80,
				98,
				118,
				142,
				170,
				204,
				245,
				294,
				353,
				424,
				509,
			},
			walkSpeedBonusPerLevel = 1,
		},
		{
			id = "Magnet",
			name = "Magnet",
			description = "Press 1 to pull coins from tiles around you for 5 seconds. Higher levels shorten the cooldown and pull coins from farther away.",
			maxLevel = 5,
			defaultLevel = 1,
			-- Cost to reach levels 2–5 (players start at level 1).
			brainsCosts = {
				30,
				55,
				90,
				150,
			},
		},
	},

	-- Reach-day intros for Brainrots that never go through UNLOCK_SCHEDULE
	-- (reach-unlocks). Catch-up: any entry with `day` <= current day that is
	-- not yet in SaveData.introducedBrainrots. Day 1 starters are already on
	-- the board — no UnlockPopup.
	BRAINROT_INTRO_SCHEDULE = {
		{ day = 25, brainrotId = "GiraffaCeleste" },
		{ day = 31, brainrotId = "BrrBrrPatapim" },
	},

	-- Mechanic / hazard intros on first reach (catch-up like monster intros).
	-- Day 31 graves share the Preparation queue with Patapim + Skeleton.
	MECHANIC_INTRO_SCHEDULE = {
		{ day = 31, id = "Grave" },
	},

	-- Monster / boss intro cadence: the first time the player *reaches* `day`
	-- (Preparation / Day Select / rejoin), LevelService shows a MonsterIntro
	-- popup. Catch-up grants every schedule entry with `day` <= current that
	-- is not yet in `introducedMonsters` (Day Select / Studio FORCE_DAY).
	-- Campaign units only — Necromancer / GoblinKing are not in Days 1–50.
	-- Zombie is the Day 1 grunt; no intro popup (the player already sees them).
	MONSTER_INTRO_SCHEDULE = {
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

-- First campaign day this species appears. Zombie (and any unit not on the
-- intro popup schedule) debuts on Day 1.
function ProgressConfig.monsterIntroDay(monsterId: string): number
	for _, entry in ProgressConfig.MONSTER_INTRO_SCHEDULE do
		if entry.monsterId == monsterId then
			return entry.day
		end
	end
	return 1
end

function ProgressConfig.isMechanicIntroId(id: string): boolean
	for _, entry in ProgressConfig.MECHANIC_INTRO_SCHEDULE do
		if entry.id == id then
			return true
		end
	end
	return false
end

function ProgressConfig.upgradeById(upgradeId: string): any?
	for _, entry in ProgressConfig.UPGRADE_CATALOG do
		if entry.id == upgradeId then
			return entry
		end
	end
	return nil
end

function ProgressConfig.upgradeLevel(def: any, stored: number?): number
	local maxLevel = if type(def.maxLevel) == "number" then def.maxLevel else 0
	local defaultLevel = 0
	if type(def.defaultLevel) == "number" then
		defaultLevel = math.max(0, math.floor(def.defaultLevel))
	end
	local value = if type(stored) == "number" then math.floor(stored) else 0
	local level = math.max(defaultLevel, value)
	return math.clamp(level, defaultLevel, maxLevel)
end

function ProgressConfig.nextUpgradeCost(def: any, currentLevel: number): number?
	if currentLevel >= def.maxLevel then
		return nil
	end
	local costs = def.brainsCosts
	if type(costs) ~= "table" then
		return nil
	end
	local defaultLevel = 0
	if type(def.defaultLevel) == "number" then
		defaultLevel = math.max(0, math.floor(def.defaultLevel))
	end
	local index = (currentLevel + 1) - defaultLevel
	local cost = costs[index]
	if type(cost) ~= "number" then
		cost = costs[#costs]
	end
	if type(cost) ~= "number" then
		return nil
	end
	return math.max(0, math.floor(cost))
end

table.freeze(ProgressConfig)

return ProgressConfig
