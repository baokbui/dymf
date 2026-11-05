--!strict
-- Permanent objectives. Catch-up uses verified server-owned profile and campaign fields.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.RetentionConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local Brainrots = require(Shared.Brainrots)
local Types = require(Shared.Types.Retention)
local Achievements = {}

function Achievements.sanitize(raw: any): { [string]: Types.AchievementProgress }
	local result = {}
	for _, definition in Config.ACHIEVEMENTS do
		local source = if type(raw) == "table" then raw[definition.id] else nil
		local claimed = source == true or (type(source) == "table" and source.claimed == true)
		local value = if type(source) == "table" then source.progress else 0
		local progress = if type(value) == "number" and value == value and value < math.huge then math.max(0, math.floor(value)) else 0
		result[definition.id] = { progress = if claimed then definition.target else math.min(definition.target, progress), claimed = claimed }
	end
	return result
end

local function advance(state: Types.RetentionSave, id: string, target: number, value: number): boolean
	local progress = state.achievements[id]
	local before = progress.progress
	progress.progress = math.min(target, math.max(before, value))
	return before < target and progress.progress == target
end

function Achievements.catchUp(state: Types.RetentionSave, profile: any): { string }
	local owned, count, rarities = {}, 0, {}
	for _, id in profile.unlocks or {} do
		local definition = if type(id) == "string" then Brainrots.get(id) else nil
		if not definition or definition.hidden or owned[id] then continue end
		owned[id] = true
		count += 1
		local tiers = (profile.evolutions or {})[id]
		if type(tiers) ~= "table" then continue end
		for _, tier in tiers do
			if type(tier) == "string" then rarities[tier] = 1 end
		end
	end
	local statistics = profile.statistics or {}
	local progress: { [string]: number } = {
		OwnedTotal = count,
		Epic = rarities.Epic or 0,
		Legendary = rarities.Legendary or 0,
		God = rarities.God or 0,
		Kills = statistics[ProgressConfig.STAT_MONSTERS_DEFEATED] or 0,
		Placements = statistics[ProgressConfig.STAT_BRAINROTS_PLACED] or 0,
	}
	local completed = {}
	for _, definition in Config.ACHIEVEMENTS do
		local value = progress[definition.requirement]
		if type(value) == "number" and value >= 0 and value < math.huge and advance(state, definition.id, definition.target, math.floor(value)) then
			table.insert(completed, definition.id)
		end
	end
	return completed
end

function Achievements.record(state: Types.RetentionSave, event: string, details: any?): { string }
	local id = if event == "MonsterDefeated" and details and details.isBoss == true then "FirstBoss"
		elseif event == "PerfectDefense" then "FirstPerfectDefense" else nil
	return if id and advance(state, id, 1, 1) then { id } else {}
end

function Achievements.claim(state: Types.RetentionSave, _day: number, id: string, _now: number): (number?, string?)
	for _, definition in Config.ACHIEVEMENTS do
		if definition.id ~= id then continue end
		local progress = state.achievements[id]
		if progress.claimed then return nil, "AlreadyClaimed" end
		if progress.progress < definition.target then return nil, "NotReady" end
		progress.claimed = true
		return definition.brains, nil
	end
	return nil, "InvalidRequest"
end

function Achievements.markCommitted(state: Types.RetentionSave, id: string)
	local progress = state.achievements[id]
	if not progress then return end
	for _, definition in Config.ACHIEVEMENTS do
		if definition.id == id then progress.progress = definition.target; progress.claimed = true; return end
	end
end

function Achievements.syncCampaign(state: Types.RetentionSave, highestDay: number)
	for _, definition in Config.ACHIEVEMENTS do
		if definition.requirement == "CampaignDay" then
			local progress = state.achievements[definition.id]
			if not progress.claimed then progress.progress = math.min(highestDay, definition.target) end
		end
	end
end

function Achievements.clientState(state: Types.RetentionSave, campaign: boolean?): { any }
	local rows = {}
	for _, definition in Config.ACHIEVEMENTS do
		if (definition.requirement == "CampaignDay") ~= (campaign == true) then continue end
		local progress = state.achievements[definition.id]
		table.insert(rows, { id = definition.id, name = definition.name, description = definition.description,
			progress = progress.progress, target = definition.target, brains = definition.brains, claimed = progress.claimed })
	end
	return rows
end

return Achievements
