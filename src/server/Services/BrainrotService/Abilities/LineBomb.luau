--!strict
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local LineBomb = {}

function LineBomb.onPlaced(ctx, callbacks)
	CombatService.dealEntireRowDamage(
		ctx.plotModel,
		ctx.position.row,
		ctx.definition.damage,
		ctx.ownerUserId
	)
	callbacks.pulseAttack()
	callbacks.playSound("LineBomb")
	callbacks.destroySelf()
end

return LineBomb
