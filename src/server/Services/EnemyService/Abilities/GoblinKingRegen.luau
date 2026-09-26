--!strict
-- Heal a percent of max HP on a cooldown. Uses pendingHeal (same as Werewolf lifesteal).
local GoblinKingRegen = {}

local DEFAULT_INTERVAL = 10
local DEFAULT_PERCENT = 5

function GoblinKingRegen.onTick(ctx, state, dt, _callbacks)
	local interval = DEFAULT_INTERVAL
	local percent = DEFAULT_PERCENT
	if ctx.definition.abilityParams then
		interval = ctx.definition.abilityParams.regenInterval or interval
		percent = ctx.definition.abilityParams.regenPercent or percent
	end
	if percent <= 0 then
		return
	end

	state.regenCooldown = (state.regenCooldown or interval) - dt
	if state.regenCooldown > 0 then
		return
	end
	state.regenCooldown = interval

	local amount = ctx.maxHealth * (percent / 100)
	if amount <= 0 then
		return
	end
	state.pendingHeal = (state.pendingHeal or 0) + amount
end

return GoblinKingRegen
