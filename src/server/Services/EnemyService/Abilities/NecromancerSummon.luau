--!strict
local NecromancerSummon = {}

function NecromancerSummon.onTick(ctx, state, _dt, callbacks)
	local interval = 5
	if ctx.definition.abilityParams then
		interval = ctx.definition.abilityParams.skillInterval or interval
	end

	state.cooldown = (state.cooldown or interval) - _dt
	if state.cooldown > 0 then
		return
	end
	state.cooldown = interval

	local roll = math.random()
	if roll < 0.5 then
		callbacks.spawnMinion("Zombie", ctx.row)
	else
		callbacks.spawnMinion("Skeleton", ctx.row)
	end
end

return NecromancerSummon
