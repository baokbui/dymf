--!strict
-- Pure UTC calendar math. Server callers supply their own Unix timestamp;
-- clients may use these helpers for countdown display, never claim eligibility.
local RetentionTime = {}

local SECONDS_PER_DAY = 24 * 60 * 60

local function validate(unixSeconds: number)
	assert(
		unixSeconds == unixSeconds and unixSeconds >= 0 and unixSeconds < math.huge,
		"Expected a finite nonnegative Unix timestamp"
	)
end

function RetentionTime.dayKey(unixSeconds: number): number
	validate(unixSeconds)
	return math.floor(unixSeconds / SECONDS_PER_DAY)
end

function RetentionTime.nextResetAt(unixSeconds: number): number
	return (RetentionTime.dayKey(unixSeconds) + 1) * SECONDS_PER_DAY
end

function RetentionTime.secondsUntilReset(unixSeconds: number): number
	return RetentionTime.nextResetAt(unixSeconds) - unixSeconds
end

-- Allows a later UTC day after missed days; rejects clock rollback/same-day claims.
function RetentionTime.canClaimDay(lastClaimDay: number?, unixSeconds: number): boolean
	local today = RetentionTime.dayKey(unixSeconds)
	return lastClaimDay == nil or today > lastClaimDay
end

-- Display helper; gameplay uses the exact server resetAt timestamp.
function RetentionTime.formatCountdown(seconds: number): string
	validate(seconds)
	local remaining = math.ceil(seconds)
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	return string.format("%02d:%02d:%02d", hours, minutes, remaining % 60)
end

-- Monday 00:00 UTC, represented as the starting UTC day key.
function RetentionTime.weekKey(unixSeconds: number): number
	local day = RetentionTime.dayKey(unixSeconds)
	return day - (day + 3) % 7
end

function RetentionTime.nextWeeklyResetAt(unixSeconds: number): number
	return (RetentionTime.weekKey(unixSeconds) + 7) * SECONDS_PER_DAY
end

table.freeze(RetentionTime)
return RetentionTime
