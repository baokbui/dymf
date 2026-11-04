--!strict
-- Milestone 20 catalogs. Quests, login rewards and achievements are active.
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
RetentionConfig.SPIN_MINIMUM_DAY = 5
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
}

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
