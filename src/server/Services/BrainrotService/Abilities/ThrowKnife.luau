--!strict
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local ThrowKnife = {}

function ThrowKnife.tryAct(ctx, callbacks)
	local acted = CombatService.launchProjectile(
		ctx.plotModel,
		ctx.position,
		ctx.definition.rangeTiles,
		ctx.definition.damage,
		ctx.ownerUserId,
		{
			kind = "Sword",
			soundKey = "ThrowKnifeHit",
		}
	)
	if acted then
		callbacks.pulseAttack()
	end
	return acted
end

return ThrowKnife
