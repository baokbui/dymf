--!strict
-- Permanent objectives. Only verified ownership/evolution facts support catch-up.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.RetentionConfig)
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

local function advance(state: Types.RetentionSave, id: string, value: number): boolean
	for _, definition in Config.ACHIEVEMENTS do
		if definition.id ~= id then continue end
		local progress = state.achievements[id]
		local before = progress.progress
		progress.progress = math.min(definition.target, math.max(before, value))
		return before < definition.target and progress.progress == definition.target
	end
	return false
end

function Achievements.catchUp(state: Types.RetentionSave, profile: any): { string }
	local owned, count, epic = {}, 0, false
	for _, id in profile.unlocks or {} do
		local definition = if type(id) == "string" then Brainrots.get(id) else nil
		if not definition or definition.hidden or owned[id] then continue end
		owned[id] = true
		count += 1
		local tiers = (profile.evolutions or {})[id]
		if type(tiers) == "table" and table.find(tiers, "Epic") then epic = true end
	end
	local completed = {}
	for id, value in { OwnFiveBrainrots = count, OwnTenBrainrots = count, FirstEpic = if epic then 1 else 0 } do
		if advance(state, id, value) then table.insert(completed, id) end
	end
	return completed
end

function Achievements.record(state: Types.RetentionSave, event: string, details: any?): { string }
	local id = if event == "MonsterDefeated" and details and details.isBoss == true then "FirstBoss"
		elseif event == "PerfectDefense" then "FirstPerfectDefense" else nil
	return if id and advance(state, id, 1) then { id } else {}
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

function Achievements.clientState(state: Types.RetentionSave): { any }
	local rows = {}
	for _, definition in Config.ACHIEVEMENTS do
		local progress = state.achievements[definition.id]
		table.insert(rows, { id = definition.id, name = definition.name, description = definition.description,
			progress = progress.progress, target = definition.target, brains = definition.brains, claimed = progress.claimed })
	end
	return rows
end

return Achievements
