--!strict
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local FreezeTime = {}

function FreezeTime.tryAct(ctx, callbacks)
	local freezeDuration = 1.5
	if ctx.definition.abilityParams then
		freezeDuration = ctx.definition.abilityParams.freezeDuration or freezeDuration
	end

	CombatService.applyRowStatus(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		ctx.definition.rangeTiles,
		"Freeze",
		freezeDuration,
		ctx.ownerUserId
	)

	callbacks.pulseAttack()
	callbacks.playSound("FreezeTime")
	return true
end

return FreezeTime
