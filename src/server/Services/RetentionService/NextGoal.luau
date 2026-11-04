--!strict
-- Select one reachable goal from authoritative profile/registry data.
local Shared = game:GetService("ReplicatedStorage").Shared
local Brainrots = require(Shared.Brainrots)
local Evolutions = require(Shared.Evolutions)
local Progress = require(Shared.Config.ProgressConfig)
local Evolution = require(Shared.Config.EvolutionConfig)
local Config = require(Shared.Config.RetentionConfig)
local NextGoal = {}

local function selected(goal: any): any
	goal.priority, goal.distance, goal.order = nil, nil, nil
	return goal
end

function NextGoal.select(profile: any, highestDay: number, lastDay: number): any
	local owned, order = {}, {}
	for index, id in profile.equipped or {} do order[id] = index end
	for _, id in profile.unlocks or {} do
		local definition = Brainrots.get(id)
		if definition and not definition.hidden then owned[id] = definition end
	end
	local evolutionGoals = {}
	for id, definition in owned do
		local rows = Evolutions.rowsFor(id)
		if #rows == 0 then continue end
		local claimed = Evolutions.claimedSet((profile.evolutions or {})[id])
		local level = Evolution.parseXp((profile.brainrotXp or {})[id] or 0).level
		for _, row in rows do
			if claimed[row.rarity] then continue end
			local cost = Evolution.brainsCost(row.rarity)
			if cost <= 0 then break end
			local needed = math.max(0, cost - (profile.brains or 0))
			local eligible = level >= row.level
			table.insert(evolutionGoals, {
				id = "Evolution:" .. id .. ":" .. row.rarity, kind = if eligible then "Evolution" else "Level",
				brainrotId = id, rarity = row.rarity, title = if eligible then "Next evolution" else "Level up a Brainrot",
				description = if not eligible then string.format("Raise %s to level %d for %s (%d / %d).", definition.name, row.level, row.rarity, level, row.level)
					elseif needed > 0 then string.format("Save %d more Brains to evolve %s to %s.", needed, definition.name, row.rarity)
					else string.format("Evolve %s to %s for %d Brains.", definition.name, row.rarity, cost),
				level = level, targetLevel = row.level, brainsNeeded = needed, cost = cost,
				priority = if eligible then 0 else 2, distance = math.max(0, row.level - level), order = order[id] or math.huge,
			})
			break -- next unclaimed tier only; later tiers require this one first
		end
	end
	table.sort(evolutionGoals, function(a, b)
		if a.priority ~= b.priority then return a.priority < b.priority end
		if a.priority == 0 and (a.brainsNeeded == 0) ~= (b.brainsNeeded == 0) then return a.brainsNeeded == 0 end
		if (a.order < math.huge) ~= (b.order < math.huge) then return a.order < math.huge end
		if a.distance ~= b.distance then return a.distance < b.distance end
		if a.order ~= b.order then return a.order < b.order end
		return a.id < b.id
	end)
	local best = evolutionGoals[1]
	if best and best.priority == 0 then return selected(best) end
	local unlocks = {}
	for _, schedule in { Progress.UNLOCK_SCHEDULE, Progress.REACH_UNLOCK_SCHEDULE } do
		for _, row in schedule do
			local definition = Brainrots.get(row.brainrotId)
			if not definition or definition.hidden or owned[row.brainrotId] or row.day > lastDay then continue end
			local reach = schedule == Progress.REACH_UNLOCK_SCHEDULE
			table.insert(unlocks, { id = "Unlock:" .. row.brainrotId, kind = "Campaign", title = "Your next unlock",
				description = string.format("%s Day %d to unlock %s.", if reach then "Reach" else "Complete", row.day, definition.name),
				day = row.day, brainrotId = row.brainrotId })
		end
	end
	table.sort(unlocks, function(a, b) if a.day ~= b.day then return a.day < b.day end; return a.id < b.id end)
	local unlock = unlocks[1]
	if unlock and (not best or unlock.day <= highestDay + Config.GOAL_UNLOCK_LOOKAHEAD) then return unlock end
	if best then return selected(best) end
	if unlock then return unlock end
	return { id = "Campaign:" .. tostring(highestDay), kind = "Campaign", title = "Keep defending!",
		description = if highestDay < lastDay then string.format("Complete Day %d to open the next campaign day.", highestDay)
			else "Your available evolution goals are complete. Defend the final day or replay a favorite!", day = highestDay }
end

return NextGoal
