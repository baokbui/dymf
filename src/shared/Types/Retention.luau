--!strict
-- Milestone 20 contracts. Save schema v13 stores the Daily Challenge receipt and Daily Spin outcome.
export type QuestProgress = {
	id: string,
	target: number,
	progress: number,
	brains: number, -- reward snapshotted on assignment, never client-supplied
	claimed: boolean,
}

export type DailyQuests = {
	dayKey: number,
	bandId: string,
	quests: { QuestProgress },
	bonusBrains: number,
	bonusClaimed: boolean,
}

export type LoginTrack = {
	welcomeClaims: number, -- 0..7, never reset by a missed day
	firstTimeVersion: number?, -- migration marker; recurring login rewards removed
	lastClaimDay: number?,
	eligibleDay: number?,
	pendingBrains: number?, -- fixed when today's offer is first prepared
	pendingTrack: string?, -- Welcome only; retained after claiming for today's UI
	pendingStep: number?,
	upgradeRewards: { [string]: number }?, -- first-time levels actually granted; excludes max-level brains fallbacks
}

export type DailyReward = {
	dayKey: number,
	brains: number,
	claimed: boolean,
	rewardId: string?, -- selected spin outcome
}

export type AchievementProgress = { progress: number, claimed: boolean }

export type RetentionSave = {
	version: number,
	dailyQuests: DailyQuests?,
	weeklyQuests: DailyQuests?,
	brainrotTickets: number?,
	login: LoginTrack?,
	achievements: { [string]: AchievementProgress },
	challengeClaimDay: number?,
	spin: DailyReward?, -- outcome selected/persisted by server with grant
}

export type GameplayEvent = {
	id: string, -- unique server-issued identity, not a client claim
	kind: string,
	mode: string, -- Campaign / Hidden / Challenge
	amount: number?,
	monsterId: string?,
	isBoss: boolean?,
	brainrotId: string?,
	rarity: string?,
	dayNumber: number?,
	breaches: number?,
	cleared: boolean?,
}

export type ClaimRequest = {
	kind: string,
	dayKey: number?,
	id: string?,
}

export type ClaimResult = {
	success: boolean,
	kind: string?,
	reason: string?,
	claimId: string?,
	brainsGranted: number?,
	reward: { [string]: any }?, -- typed non-brain grant or max-upgrade fallback
}

return {}
