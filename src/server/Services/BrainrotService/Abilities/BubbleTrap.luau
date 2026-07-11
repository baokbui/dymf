--!strict
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local BubbleTrap = {}

function BubbleTrap.tryAct(ctx, callbacks)
	local trapDuration = 1
	if ctx.definition.abilityParams then
		trapDuration = ctx.definition.abilityParams.trapDuration or trapDuration
	end

	local acted = CombatService.attackInRow(
		ctx.plotModel,
		ctx.position,
		ctx.definition.rangeTiles,
		ctx.definition.damage,
		ctx.ownerUserId,
		"BubbleTrap"
	)
	if not acted then
		return false
	end

	CombatService.applyRowStatus(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		ctx.definition.rangeTiles,
		"Freeze",
		trapDuration,
		ctx.ownerUserId,
		nil,
		"Bubble"
	)
	callbacks.pulseAttack()
	return true
end

return BubbleTrap
