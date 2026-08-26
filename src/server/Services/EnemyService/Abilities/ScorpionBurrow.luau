--!strict
--[[
	ScorpionBurrow
	Once the unit first steps onto the plot, it digs under the lawn and
	reappears just east of the first Brainrot in its lane (then chews).
	If the lane has no chewable Brainrot at that moment, it keeps walking.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
local GridService = require(script.Parent.Parent.Parent.GridService)

local ScorpionBurrow = {}

local function firstBrainrotColumn(plotModel: Model, row: number): number?
	for column = GridConfig.COLUMNS, 1, -1 do
		local tile = GridService.getTile(plotModel, { row = row, column = column })
		if tile and tile.occupied and tile.brainrotInstanceId then
			local BrainrotService = require(script.Parent.Parent.Parent.BrainrotService)
			local placement = BrainrotService.getPlacement(tile.brainrotInstanceId)
			if placement and placement.health > 0 and placement.definition.ignoreMonsterChew ~= true then
				return column
			end
		end
	end
	return nil
end

function ScorpionBurrow.onTick(ctx, state, _dt: number, callbacks)
	if state.burrowed == true then
		return
	end
	if not GridUtil.isOnPlotColumn(ctx.column) then
		return
	end

	local params = ctx.definition.abilityParams
	local duration = if params then params.burrowDuration else nil
	local depth = if params then params.burrowDepth else nil
	local emergeOffset = if params then params.emergeOffset else nil
	duration = if type(duration) == "number" then duration else MonsterConfig.BURROW_DURATION
	depth = if type(depth) == "number" then depth else MonsterConfig.BURROW_DEPTH
	emergeOffset = if type(emergeOffset) == "number" then emergeOffset else MonsterConfig.BURROW_EMERGE_OFFSET

	local plantColumn = firstBrainrotColumn(ctx.plotModel, ctx.row)
	state.burrowed = true
	if not plantColumn then
		return
	end

	local endColumn = plantColumn + emergeOffset
	if endColumn > ctx.column then
		endColumn = ctx.column
	end
	endColumn = math.clamp(endColumn, MonsterConfig.HOUSE_BREACH_COLUMN + 0.05, GridConfig.COLUMNS)

	callbacks.setInvulnerable(duration)
	callbacks.beginBurrow(endColumn, duration, depth)
end

return ScorpionBurrow
