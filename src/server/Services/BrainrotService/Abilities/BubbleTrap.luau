--!strict
--[[
	BubbleTrap
	Tralalero — launches a bubble projectile at the first enemy in range.
	Damage + Freeze (Bubble visual) apply on impact, not instantly.
]]

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local BubbleTrap = {}

function BubbleTrap.tryAct(ctx, callbacks)
	local trapDuration = 1
	if ctx.definition.abilityParams then
		trapDuration = ctx.definition.abilityParams.trapDuration or trapDuration
	end

	local acted = CombatService.launchProjectile(
		ctx.plotModel,
		ctx.position,
		ctx.definition.rangeTiles,
		ctx.definition.damage,
		ctx.ownerUserId,
		{
			kind = "Bubble",
			soundKey = "BubbleTrap",
			statusKind = "Freeze",
			statusDuration = trapDuration,
			statusVisual = "Bubble",
		}
	)
	if acted then
		callbacks.pulseAttack()
	end
	return acted
end

return BubbleTrap
