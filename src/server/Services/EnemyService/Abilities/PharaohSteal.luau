--!strict
--[[
	PharaohSteal
	On cooldown, pick `stealLaneCount` random rows and remove one random
	Brainrot from each (skip empty lanes). Only while on the plot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
local GridService = require(script.Parent.Parent.Parent.GridService)
local BrainrotService = require(script.Parent.Parent.Parent.BrainrotService)

local PharaohSteal = {}

local DEFAULT_COOLDOWN = 15
local DEFAULT_LANES = 3
local RETRY_DELAY = 1
local DEFAULT_HIT_DELAY = 0.85

local function shuffle(list: { number })
	for index = #list, 2, -1 do
		local swap = math.random(index)
		list[index], list[swap] = list[swap], list[index]
	end
end

local function idsOnRow(plotModel: Model, row: number): { string }
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	for column = 1, GridConfig.COLUMNS do
		local tile = GridService.getTile(plotModel, { row = row, column = column })
		if tile and tile.occupied and tile.brainrotInstanceId then
			local id = tile.brainrotInstanceId
			if seen[id] then
				continue
			end
			local placement = BrainrotService.getPlacement(id)
			if placement and placement.health > 0 then
				seen[id] = true
				table.insert(ids, id)
			end
		end
	end
	return ids
end

local function channelDuration(callbacks, abilityId: string, hitDelay: number, override: number?): number
	if type(override) == "number" and override > 0 then
		return override
	end
	local length = callbacks.getAbilityLength(abilityId)
	if type(length) == "number" and length > 0 then
		return math.max(length, hitDelay)
	end
	return math.max(hitDelay + 0.5, 1.4)
end

function PharaohSteal.onTick(ctx, state, dt: number, callbacks)
	local params = ctx.definition.abilityParams
	local cooldown = if params then params.stealCooldown or DEFAULT_COOLDOWN else DEFAULT_COOLDOWN
	local laneCount = if params then params.stealLaneCount or DEFAULT_LANES else DEFAULT_LANES
	local hitDelay = DEFAULT_HIT_DELAY
	if params and type(params.stealHitDelay) == "number" then
		hitDelay = math.max(0, params.stealHitDelay)
	end
	local channelOverride = if params then params.stealChannelDuration else nil

	state.stealCooldown = (state.stealCooldown or cooldown) - dt
	if state.stealCooldown > 0 then
		return
	end

	if not GridUtil.isOnPlotColumn(ctx.column) then
		state.stealCooldown = RETRY_DELAY
		return
	end

	local rows: { number } = {}
	for row = 1, GridConfig.ROWS do
		table.insert(rows, row)
	end
	shuffle(rows)

	local picks: { string } = {}
	for _, row in rows do
		if #picks >= laneCount then
			break
		end
		local ids = idsOnRow(ctx.plotModel, row)
		if #ids == 0 then
			continue
		end
		table.insert(picks, ids[math.random(1, #ids)])
	end

	if #picks == 0 then
		state.stealCooldown = RETRY_DELAY
		return
	end

	callbacks.playAbility("PharaohSteal")
	callbacks.beginChannel(channelDuration(callbacks, "PharaohSteal", hitDelay, channelOverride))
	state.stealCooldown = cooldown

	local plotModel = ctx.plotModel
	local row = ctx.row
	local column = ctx.column
	local apply = function()
		if not plotModel.Parent then
			return
		end
		local destination = GridService.getWorldPositionAtColumn(plotModel, row, column)
		for _, pick in picks do
			BrainrotService.stealPlacement(pick, destination)
		end
	end
	if hitDelay <= 0 then
		apply()
	else
		task.delay(hitDelay, apply)
	end
end

return PharaohSteal
