--!strict
--[[
	Duke Vampire's Terrify: deals NO damage. On a `terrifyCooldown` timer, it
	afflicts Brainrots in a forward cone (his tile plus `terrifyColumnsBehind`
	tiles toward the house, rows ± 1) with "Weaken" and "Stun". Never fires
	(no VFX, no status, no full cooldown) unless at least one living Brainrot
	is actually in that cone. See docs/MONSTERS.md.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)
local CombatService = require(script.Parent.Parent.Parent.CombatService)
local GridService = require(script.Parent.Parent.Parent.GridService)

local DukeVampireTerrify = {}

local DEFAULT_COOLDOWN = 10
local DEFAULT_REDUCTION = 15
local DEFAULT_FREEZE_DURATION = 4
local DEFAULT_COLUMNS_BEHIND = 2
-- Nothing in range yet — poll again soon without burning the full cooldown
-- or playing the scream VFX.
local RETRY_DELAY = 1

local function tileAtColumn(column: number): number
	return math.floor(column + MonsterConfig.TILE_HALF_WIDTH)
end

local function collectTargets(ctx, columnsAhead: number): { string }
	local targets: { string } = {}
	local seen: { [string]: boolean } = {}
	local frontColumn = tileAtColumn(ctx.column)

	for column = frontColumn - columnsAhead, frontColumn do
		if column < 1 or column > GridConfig.COLUMNS then
			continue
		end
		for row = ctx.row - 1, ctx.row + 1 do
			if row < 1 or row > GridConfig.ROWS then
				continue
			end
			local tile = GridService.getTile(ctx.plotModel, { row = row, column = column })
			if not tile or not tile.occupied or not tile.brainrotInstanceId then
				continue
			end
			local id = tile.brainrotInstanceId
			if seen[id] then
				continue
			end
			-- Occupancy can briefly lag a destroy — only hit living placements.
			local BrainrotService = require(script.Parent.Parent.Parent.BrainrotService)
			local placement = BrainrotService.getPlacement(id)
			if not placement or placement.health <= 0 then
				continue
			end
			seen[id] = true
			table.insert(targets, id)
		end
	end
	return targets
end

function DukeVampireTerrify.onTick(ctx, state, dt: number, _callbacks)
	-- Never scream while last-standing (shared abilityState with DukeVampireFreeze).
	if state.lastStandPhase and state.lastStandPhase ~= "done" then
		return
	end

	local params = ctx.definition.abilityParams
	local cooldown = if params then params.terrifyCooldown or DEFAULT_COOLDOWN else DEFAULT_COOLDOWN
	local reduction = if params
		then params.terrifyDamageReduction or DEFAULT_REDUCTION
		else DEFAULT_REDUCTION
	local freezeDuration = if params
		then params.terrifyFreezeDuration or DEFAULT_FREEZE_DURATION
		else DEFAULT_FREEZE_DURATION
	local columnsAhead = if params
		then params.terrifyColumnsBehind or DEFAULT_COLUMNS_BEHIND
		else DEFAULT_COLUMNS_BEHIND

	state.terrifyCooldown = (state.terrifyCooldown or cooldown) - dt
	if state.terrifyCooldown > 0 then
		return
	end

	-- Still marching in the forest — no lawn Brainrots can be in the cone.
	if not GridUtil.isOnPlotColumn(ctx.column) then
		state.terrifyCooldown = RETRY_DELAY
		return
	end

	local targets = collectTargets(ctx, columnsAhead)
	if #targets == 0 then
		state.terrifyCooldown = RETRY_DELAY
		return
	end

	local ownerUserId = ctx.plotModel:GetAttribute("OwnerUserId")
	for _, brainrotInstanceId in targets do
		CombatService.applyStatusToBrainrot(brainrotInstanceId, "Weaken", freezeDuration, reduction)
		CombatService.applyStatusToBrainrot(brainrotInstanceId, "Stun", freezeDuration)
		-- Dizzy stars are fired from BrainrotService.applyBrainrotStatus on Stun.
	end

	if type(ownerUserId) == "number" then
		CombatService.notifyTerrifyPulse(ownerUserId, ctx.instanceId)
	end

	state.terrifyCooldown = cooldown
end

return DukeVampireTerrify
