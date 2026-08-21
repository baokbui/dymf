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
local DEFAULT_HIT_DELAY = 0.9

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

function PharaohSummon.onTick(ctx, state, dt: number, callbacks)
	local params = ctx.definition.abilityParams
	local cooldown = if params then params.summonCooldown or DEFAULT_COOLDOWN else DEFAULT_COOLDOWN
	local hitDelay = DEFAULT_HIT_DELAY
	if params and type(params.summonHitDelay) == "number" then
		hitDelay = math.max(0, params.summonHitDelay)
	end
	local channelOverride = if params then params.summonChannelDuration else nil

	state.summonCooldown = (state.summonCooldown or cooldown) - dt
	if state.summonCooldown > 0 then
		return
	end
	state.summonCooldown = cooldown

	callbacks.playAbility("PharaohSummon")
	callbacks.beginChannel(channelDuration(callbacks, "PharaohSummon", hitDelay, channelOverride))

	local plotModel = ctx.plotModel
	local spawn = function()
		if not plotModel.Parent then
			return
		end
		for row = 1, GridConfig.ROWS do
			callbacks.spawnMinion(DEFAULT_MINION, row)
		end
	end
	if hitDelay <= 0 then
		spawn()
	else
		task.delay(hitDelay, spawn)
	end
end

return PharaohSummon
