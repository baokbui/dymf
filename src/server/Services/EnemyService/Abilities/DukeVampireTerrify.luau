--!strict
--[[
	Duke Vampire's Terrify: deals NO damage. On a `terrifyCooldown` timer, it
	afflicts the Brainrot directly in front of him plus the ones in the lane
	above/below (his row ± 1) with "Weaken" (reduced outgoing damage) and a
	short attack freeze ("Stun") — independent of `laneSpan`, which stays 1 so
	his movement/footprint are unaffected. See docs/MONSTERS.md.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)
local GridService = require(script.Parent.Parent.Parent.GridService)

local DukeVampireTerrify = {}

local DEFAULT_COOLDOWN = 10
local DEFAULT_REDUCTION = 15
local DEFAULT_FREEZE_DURATION = 2
-- Nothing was in range yet (e.g. still marching) — check back sooner than a
-- full cooldown instead of losing a long window waiting for nothing.
local RETRY_DELAY = 1

local function tileAtColumn(column: number): number
	return math.floor(column + MonsterConfig.TILE_HALF_WIDTH)
end

function DukeVampireTerrify.onTick(ctx, state, dt: number, _callbacks)
	local params = ctx.definition.abilityParams
	local cooldown = if params then params.terrifyCooldown or DEFAULT_COOLDOWN else DEFAULT_COOLDOWN
	local reduction = if params
		then params.terrifyDamageReduction or DEFAULT_REDUCTION
		else DEFAULT_REDUCTION
	local freezeDuration = if params
		then params.terrifyFreezeDuration or DEFAULT_FREEZE_DURATION
		else DEFAULT_FREEZE_DURATION

	state.terrifyCooldown = (state.terrifyCooldown or cooldown) - dt
	if state.terrifyCooldown > 0 then
		return
	end

	local column = tileAtColumn(ctx.column)
	local hitAny = false
	for row = ctx.row - 1, ctx.row + 1 do
		if row >= 1 and row <= GridConfig.ROWS then
			local tile = GridService.getTile(ctx.plotModel, { row = row, column = column })
			if tile and tile.occupied and tile.brainrotInstanceId then
				CombatService.applyStatusToBrainrot(tile.brainrotInstanceId, "Weaken", freezeDuration, reduction)
				CombatService.applyStatusToBrainrot(tile.brainrotInstanceId, "Stun", freezeDuration)
				hitAny = true
			end
		end
	end

	state.terrifyCooldown = if hitAny then cooldown else RETRY_DELAY
end

return DukeVampireTerrify
