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

function PharaohSteal.onTick(ctx, state, dt: number, _callbacks)
	local params = ctx.definition.abilityParams
	local cooldown = if params then params.stealCooldown or DEFAULT_COOLDOWN else DEFAULT_COOLDOWN
	local laneCount = if params then params.stealLaneCount or DEFAULT_LANES else DEFAULT_LANES

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

	local stolen = 0
	local destination = GridService.getWorldPositionAtColumn(ctx.plotModel, ctx.row, ctx.column)
	for _, row in rows do
		if stolen >= laneCount then
			break
		end
		local ids = idsOnRow(ctx.plotModel, row)
		if #ids == 0 then
			continue
		end
		local pick = ids[math.random(1, #ids)]
		if BrainrotService.stealPlacement(pick, destination) then
			stolen += 1
		end
	end

	if stolen == 0 then
		state.stealCooldown = RETRY_DELAY
		return
	end

	state.stealCooldown = cooldown
end

return PharaohSteal
