--!strict
-- Pure assignment, migration, progress, and claim rules. No services or writes.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.RetentionConfig)
local Time = require(Shared.Utilities.RetentionTime)
local Types = require(Shared.Types.Retention)
local LoginRewards = require(script.Parent.LoginRewards)
local Achievements = require(script.Parent.Achievements)
local DailySpin = require(script.Parent.DailySpin)
local DailyQuests = {}

local function integer(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.max(0, math.floor(value))
end

local function sanitizeTrack(source: any, catalog: any): Types.DailyQuests?
	if type(source) ~= "table" then
		return nil
	end
	local day = integer(source.dayKey, -1)
	if day < 0 or type(source.quests) ~= "table" then
		return nil
	end
	local quests: { Types.QuestProgress } = {}
	for index, definition in catalog do
		local entry = source.quests[index]
		if type(entry) ~= "table" or entry.id ~= definition.id then
			return nil
		end
		local target = math.max(1, integer(entry.target, definition.target))
		table.insert(quests, {
			id = definition.id, target = target,
			progress = math.min(target, integer(entry.progress, 0)),
			brains = integer(entry.brains, 0), claimed = entry.claimed == true,
		})
	end
	return {
		dayKey = day, bandId = if type(source.bandId) == "string" then source.bandId else "Early",
		quests = quests, bonusBrains = integer(source.bonusBrains, 0),
		bonusClaimed = source.bonusClaimed == true,
	}
end

function DailyQuests.sanitize(raw: any): Types.RetentionSave
	local result: Types.RetentionSave = { version = Config.VERSION, achievements = {} }
	local challengeDay = integer(if type(raw) == "table" then raw.challengeClaimDay else nil, -1)
	result.challengeClaimDay = if challengeDay >= 0 then challengeDay else nil
	result.spin = DailySpin.sanitize(if type(raw) == "table" then raw.spin else nil)
	result.achievements = Achievements.sanitize(if type(raw) == "table" then raw.achievements else nil)
	result.login = LoginRewards.sanitize(if type(raw) == "table" then raw.login else nil)
	result.brainrotTickets = integer(if type(raw) == "table" then raw.brainrotTickets else nil, 0)
	result.dailyQuests = sanitizeTrack(if type(raw) == "table" then raw.dailyQuests else nil, Config.DAILY_QUESTS)
	result.weeklyQuests = sanitizeTrack(if type(raw) == "table" then raw.weeklyQuests else nil, Config.WEEKLY_QUESTS)
	return result
end

function DailyQuests.ensure(state: Types.RetentionSave, now: number, highestDay: number, weekly: boolean?): boolean
	local today = if weekly then Time.weekKey(now) else Time.dayKey(now)
	local key = if weekly then "weeklyQuests" else "dailyQuests"
	if state[key] and state[key].dayKey >= today then
		return false
	end
	local quests: { Types.QuestProgress } = {}
	for _, definition in (if weekly then Config.WEEKLY_QUESTS else Config.DAILY_QUESTS) do
		table.insert(quests, {
			id = definition.id, target = definition.target, progress = 0,
			brains = Config.brainsFor(definition.brains, highestDay), claimed = false,
		})
	end
	state[key] = {
		dayKey = today, bandId = Config.rewardBand(highestDay).id, quests = quests,
		bonusBrains = Config.brainsFor(if weekly then Config.WEEKLY_QUEST_BONUS else Config.DAILY_QUEST_BONUS, highestDay), bonusClaimed = false,
	}
	return true
end

function DailyQuests.record(state: Types.RetentionSave, event: string, amount: number, weekly: boolean?): (boolean, boolean)
	if amount ~= amount or amount <= 0 or amount == math.huge then return false, false end
	local daily = if weekly then state.weeklyQuests else state.dailyQuests
	if not daily then return false, false end
	local changed, completed = false, false
	for index, definition in (if weekly then Config.WEEKLY_QUESTS else Config.DAILY_QUESTS) do
		local quest = daily.quests[index]
		if definition.event ~= event or quest.progress >= quest.target then continue end
		quest.progress = math.min(quest.target, quest.progress + math.floor(amount))
		changed = true
		completed = completed or quest.progress == quest.target
	end
	return changed, completed
end

function DailyQuests.claim(state: Types.RetentionSave, day: number, id: string, now: number, weekly: boolean?): (number?, string?)
	local daily = if weekly then state.weeklyQuests else state.dailyQuests
	if not daily or day ~= daily.dayKey or day ~= (if weekly then Time.weekKey(now) else Time.dayKey(now)) then return nil, "Expired" end
	if id == (if weekly then "WeeklyComplete" else "DailyComplete") then
		if daily.bonusClaimed then return nil, "AlreadyClaimed" end
		for _, quest in daily.quests do
			if quest.progress < quest.target then return nil, "NotReady" end
		end
		daily.bonusClaimed = true
		return daily.bonusBrains, nil
	end
	for _, quest in daily.quests do
		if quest.id ~= id then continue end
		if quest.claimed then return nil, "AlreadyClaimed" end
		if quest.progress < quest.target then return nil, "NotReady" end
		quest.claimed = true
		return quest.brains, nil
	end
	return nil, "InvalidRequest"
end

-- Merge only the paid flag; preserve progress earned while the write yielded.
function DailyQuests.markCommitted(state: Types.RetentionSave, day: number, id: string, weekly: boolean?)
	local daily = if weekly then state.weeklyQuests else state.dailyQuests
	if not daily or daily.dayKey ~= day then return end
	if id == (if weekly then "WeeklyComplete" else "DailyComplete") then daily.bonusClaimed = true; return end
	for _, quest in daily.quests do
		if quest.id == id then quest.claimed = true; return end
	end
end

return DailyQuests
