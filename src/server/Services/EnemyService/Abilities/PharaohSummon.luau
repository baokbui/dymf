--!strict
--[[
	PharaohSummon
	On cooldown, spawn a Small Mummy in every lawn row. Minion id is the
	SmallMummy registry entry (abilityParams cannot carry string ids).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)

local PharaohSummon = {}

local DEFAULT_COOLDOWN = 20
local DEFAULT_MINION = "SmallMummy"

function PharaohSummon.onTick(ctx, state, dt: number, callbacks)
	local params = ctx.definition.abilityParams
	local cooldown = if params then params.summonCooldown or DEFAULT_COOLDOWN else DEFAULT_COOLDOWN

	state.summonCooldown = (state.summonCooldown or cooldown) - dt
	if state.summonCooldown > 0 then
		return
	end
	state.summonCooldown = cooldown

	for row = 1, GridConfig.ROWS do
		callbacks.spawnMinion(DEFAULT_MINION, row)
	end
end

return PharaohSummon
