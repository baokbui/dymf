--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	MonsterStatus
	Applies and ticks combat status effects on monster runtime state.
	All damage routes through the supplied damage callback (CombatService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.MonsterConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local GridUtil = require(ReplicatedStorage.Shared.Utilities.GridUtil)

local MonsterStatus = {}

export type StatusFields = {
	frozenUntil: number,
	slowUntil: number,
	slowFactor: number,
	poisonUntil: number,
	poisonDamagePerTick: number,
	poisonNextTick: number,
	burnUntil: number,
	burnDamagePerTick: number,
	burnNextTick: number,
}

export type StatusRuntime = StatusFields & {
	plotModel: Model,
	column: number,
}

function MonsterStatus.createFields(): StatusFields
	return {
		frozenUntil = 0,
		slowUntil = 0,
		slowFactor = CombatConfig.SLOW_SPEED_FACTOR,
		poisonUntil = 0,
		poisonDamagePerTick = 0,
		poisonNextTick = 0,
		burnUntil = 0,
		burnDamagePerTick = 0,
		burnNextTick = 0,
	}
end

function MonsterStatus.apply(runtime: StatusRuntime, kind: Types.StatusEffectKind, duration: number, magnitude: number?)
	local now = BattleClock.now(runtime.plotModel)
	if kind == "Freeze" or kind == "Stun" then
		runtime.frozenUntil = math.max(runtime.frozenUntil, now + duration)
	elseif kind == "Slow" then
		runtime.slowUntil = math.max(runtime.slowUntil, now + duration)
		runtime.slowFactor = magnitude or CombatConfig.SLOW_SPEED_FACTOR
	elseif kind == "Poison" then
		runtime.poisonUntil = math.max(runtime.poisonUntil, now + duration)
		runtime.poisonDamagePerTick = magnitude or CombatConfig.POISON_DAMAGE_PER_TICK
		if runtime.poisonNextTick <= now then
			runtime.poisonNextTick = now + CombatConfig.POISON_TICK_INTERVAL
		end
	elseif kind == "Burn" then
		runtime.burnUntil = math.max(runtime.burnUntil, now + duration)
		runtime.burnDamagePerTick = magnitude or CombatConfig.BURN_DAMAGE_PER_TICK
		if runtime.burnNextTick <= now then
			runtime.burnNextTick = now + CombatConfig.BURN_TICK_INTERVAL
		end
	elseif kind == "Knockback" then
		-- Forest / east of the lawn: damage may still land (in-flight shots),
		-- but never push a monster that is already off the plot.
		if not GridUtil.isOnPlotColumn(runtime.column) then
			return
		end
		local tiles = magnitude or CombatConfig.KNOCKBACK_TILES
		runtime.column = math.min(GridConfig.COLUMNS + MonsterConfig.SPAWN_COLUMN_OFFSET, runtime.column + tiles)
	end
end

function MonsterStatus.movementSpeedMultiplier(runtime: StatusRuntime, now: number): number
	if now < runtime.slowUntil then
		return runtime.slowFactor
	end
	return 1
end

function MonsterStatus.tick(runtime: StatusRuntime, now: number, damage: (amount: number) -> ())
	if runtime.poisonUntil > now and now >= runtime.poisonNextTick then
		damage(runtime.poisonDamagePerTick)
		runtime.poisonNextTick = now + CombatConfig.POISON_TICK_INTERVAL
	end
	if runtime.burnUntil > now and now >= runtime.burnNextTick then
		damage(runtime.burnDamagePerTick)
		runtime.burnNextTick = now + CombatConfig.BURN_TICK_INTERVAL
	end
end

return MonsterStatus
