--!strict
local GoblinKingRegen = {}

function GoblinKingRegen.onTick(ctx, state, dt, _callbacks)
	local interval = 8
	local amount = 100
	if ctx.definition.abilityParams then
		interval = ctx.definition.abilityParams.regenInterval or interval
		amount = ctx.definition.abilityParams.regenAmount or amount
	end

	state.regenCooldown = (state.regenCooldown or interval) - dt
	if state.regenCooldown > 0 then
		return
	end
	state.regenCooldown = interval
	state.pendingHeal = (state.pendingHeal or 0) + amount
end

return GoblinKingRegen
