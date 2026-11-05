--!strict
-- Milestone 20 catalogs. Quests, first-time rewards, achievements, challenges and spins.
local RetentionConfig = {}

export type RewardBand = { id: string, minimumDay: number, multiplier: number }
export type QuestDefinition = {
	id: string,
	event: string,
	target: number,
	brains: number,
	minimumDay: number,
}
export type SpinReward = { id: string, brains: number, weight: number }

RetentionConfig.VERSION = 4
RetentionConfig.QUESTS_PER_DAY = 3
RetentionConfig.DAILY_QUEST_BONUS = 2
RetentionConfig.CHALLENGE_MINIMUM_DAY = 10
RetentionConfig.CHALLENGE_BRAINS = 4
RetentionConfig.SPIN_MINIMUM_DAY = 3 -- clearing Day 2 unlocks Day 3
RetentionConfig.CLAIM_REQUEST_INTERVAL = 0.5
RetentionConfig.STATE_PUSH_INTERVAL = 0.35
RetentionConfig.GOAL_UNLOCK_LOOKAHEAD = 3
RetentionConfig.GOAL_VIEW_INTERVAL = 2

-- Highest unlocked campaign day, never the selected/replayed day.
RetentionConfig.REWARD_BANDS = {
	{ id = "Early", minimumDay = 1, multiplier = 1 },
	{ id = "Middle", minimumDay = 10, multiplier = 2 },
	{ id = "Late", minimumDay = 30, multiplier = 3 },
} :: { RewardBand }

-- Three safe baseline objectives; later pools can add eligible alternatives.
RetentionConfig.DAILY_QUESTS = {
	{ id = "CollectCoins", event = "CoinsCollected", target = 150, brains = 1, minimumDay = 1 },
	{ id = "DefeatMonsters", event = "MonsterDefeated", target = 15, brains = 1, minimumDay = 1 },
	{ id = "ClearDay", event = "CampaignDayCleared", target = 1, brains = 2, minimumDay = 1 },
} :: { QuestDefinition }

-- First-time track ends permanently; no recurring weekly login rewards.
RetentionConfig.FIRST_TIME_REWARDS = {
	{ kind = "Brains", amount = 2, name = "Brains" },
	{ kind = "Upgrade", upgradeId = "WalkSpeed", amount = 1, name = "Speed level", fallbackBrains = 10 },
	{ kind = "Brains", amount = 4, name = "Brains" },
	{ kind = "Upgrade", upgradeId = "Magnet", amount = 1, name = "Magnet level", fallbackBrains = 10 },
	{ kind = "Brains", amount = 6, name = "Brains" },
	{ kind = "Upgrade", upgradeId = "WalkSpeed", amount = 1, name = "Speed level", fallbackBrains = 10 },
	{ kind = "Ticket", amount = 1, name = "Free Brainrot ticket" },
}
RetentionConfig.WEEKLY_QUEST_BONUS = 3
RetentionConfig.WEEKLY_QUESTS = {
	{ id = "CollectCoins", event = "CoinsCollected", target = 1500, brains = 3, minimumDay = 1 },
	{ id = "DefeatMonsters", event = "MonsterDefeated", target = 150, brains = 3, minimumDay = 1 },
	{ id = "ClearDay", event = "CampaignDayCleared", target = 7, brains = 4, minimumDay = 1 },
} :: { QuestDefinition }
RetentionConfig.SPIN_REWARDS = {
	{ id = "Small", brains = 1, weight = 60 },
	{ id = "Medium", brains = 2, weight = 30 },
	{ id = "Large", brains = 5, weight = 10 },
} :: { SpinReward }

-- Permanent achievements use fixed amounts, not the recurring reward multiplier.
RetentionConfig.ACHIEVEMENTS = {
	{ id = "FirstBoss", name = "Boss Buster", description = "Defeat a boss in campaign or Hidden Day.", event = "MonsterDefeated", target = 1, brains = 5, requirement = "Boss" },
	{ id = "FirstEpic", name = "Going Epic", description = "Claim an Epic Brainrot evolution.", event = "EvolutionClaimed", target = 1, brains = 5, requirement = "Epic" },
	{ id = "FirstPerfectDefense", name = "Perfect Defense", description = "Clear a numbered day without a house breach.", event = "CampaignDayCleared", target = 1, brains = 3, requirement = "NoBreaches" },
	{ id = "OwnFiveBrainrots", name = "Growing Collection", description = "Own five different Brainrot types.", event = "BrainrotUnlocked", target = 5, brains = 5, requirement = "OwnedTotal" },
	{ id = "OwnTenBrainrots", name = "Brainrot Collector", description = "Own ten different Brainrot types.", event = "BrainrotUnlocked", target = 10, brains = 10, requirement = "OwnedTotal" },
	{ id = "FirstLegendary", name = "Legend in the Making", description = "Claim a Legendary Brainrot evolution.", event = "EvolutionClaimed", target = 1, brains = 8, requirement = "Legendary" },
	{ id = "FirstGod", name = "Godlike", description = "Claim a God Brainrot evolution.", event = "EvolutionClaimed", target = 1, brains = 15, requirement = "God" },
	{ id = "Defeat100", name = "Monster Hunter", description = "Defeat 100 monsters.", event = "MonsterDefeated", target = 100, brains = 6, requirement = "Kills" },
	{ id = "Defeat500", name = "Monster Slayer", description = "Defeat 500 monsters.", event = "MonsterDefeated", target = 500, brains = 12, requirement = "Kills" },
	{ id = "Plant100", name = "Seasoned Planter", description = "Place 100 Brainrots.", event = "BrainrotPlaced", target = 100, brains = 6, requirement = "Placements" },
}

-- Permanent Campaign quests share the claim ledger, with a separate UI track.
local campaignMilestones = {
	{ day = 5, title = "The Scout’s Trail" },
	{ day = 10, title = "The Elite Draws Near" },
	{ day = 15, title = "When Darkness Falls" },
	{ day = 20, title = "Invitation from the Duke" },
	{ day = 25, title = "Threads Across the Trail" },
	{ day = 30, title = "Into the Queen’s Web" },
	{ day = 35, title = "A Howl Beyond the Fog" },
	{ day = 40, title = "Court of Silk" },
	{ day = 45, title = "The Tomb Closes In" },
	{ day = 50, title = "At the Pharaoh’s Gate" },
}
for rank, milestone in campaignMilestones do
	local day = milestone.day
	table.insert(RetentionConfig.ACHIEVEMENTS, {
		id = "ReachDay" .. day,
		name = milestone.title,
		description = "Unlock campaign Day " .. day .. ".",
		event = "CampaignDayCleared",
		target = day,
		brains = 4 + rank,
		requirement = "CampaignDay",
	})
end

-- Future server event boundary. No RemoteEvent is used for objective credit.
RetentionConfig.GAMEPLAY_EVENTS = {
	"CoinsCollected",
	"MonsterDefeated",
	"CampaignDayCleared",
	"HouseBreached",
	"EvolutionClaimed",
	"BrainrotUnlocked",
	"ChallengeFinished",
}
RetentionConfig.ANALYTICS_ACTIONS = {
	"Eligible",
	"Progress",
	"ClaimSucceeded",
	"ClaimRejected",
	"ChallengeStarted",
	"ChallengeFinished",
}
RetentionConfig.REJECTION_REASONS = {
	"NotReady",
	"Expired",
	"AlreadyClaimed",
	"Locked",
	"Busy",
	"RateLimited",
	"SaveUnavailable",
	"InvalidRequest",
}

function RetentionConfig.rewardBand(highestUnlockedDay: number): RewardBand
	local day = if highestUnlockedDay == highestUnlockedDay then highestUnlockedDay else 1
	local best = RetentionConfig.REWARD_BANDS[1]
	for _, band in RetentionConfig.REWARD_BANDS do
		if day >= band.minimumDay then
			best = band
		end
	end
	return best
end

function RetentionConfig.brainsFor(baseBrains: number, highestUnlockedDay: number): number
	return math.max(0, math.floor(baseBrains)) * RetentionConfig.rewardBand(highestUnlockedDay).multiplier
end

function RetentionConfig.dailyQuestBrains(highestUnlockedDay: number): number
	local total = RetentionConfig.DAILY_QUEST_BONUS
	for _, quest in RetentionConfig.DAILY_QUESTS do
		total += quest.brains
	end
	return RetentionConfig.brainsFor(total, highestUnlockedDay)
end

function RetentionConfig.expectedSpinBrains(highestUnlockedDay: number): number
	local weighted, totalWeight = 0, 0
	for _, reward in RetentionConfig.SPIN_REWARDS do
		weighted += RetentionConfig.brainsFor(reward.brains, highestUnlockedDay) * reward.weight
		totalWeight += reward.weight
	end
	return if totalWeight > 0 then weighted / totalWeight else 0
end

-- Catalogs are immutable even when shared with display code.
for _, catalog in {
	RetentionConfig.REWARD_BANDS,
	RetentionConfig.DAILY_QUESTS,
	RetentionConfig.SPIN_REWARDS,
	RetentionConfig.ACHIEVEMENTS,
	RetentionConfig.FIRST_TIME_REWARDS,
	RetentionConfig.WEEKLY_QUESTS,
} do
	for _, entry in catalog do
		table.freeze(entry)
	end
	table.freeze(catalog)
end
for _, list in {
	RetentionConfig.GAMEPLAY_EVENTS,
	RetentionConfig.ANALYTICS_ACTIONS,
	RetentionConfig.REJECTION_REASONS,
} do
	table.freeze(list)
end
table.freeze(RetentionConfig)

return RetentionConfig
