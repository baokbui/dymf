--!strict
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local FreezeTime = {}

function FreezeTime.tryAct(ctx, callbacks)
	local freezeDuration = 1.5
	if ctx.definition.abilityParams then
		freezeDuration = ctx.definition.abilityParams.freezeDuration or freezeDuration
	end

	local targets = CombatService.getMonstersInRow(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		ctx.definition.rangeTiles
	)
	if #targets == 0 then
		return false
	end

	callbacks.pulseAttack()

	local hitDelay = ctx.definition.attackHitDelay
	local plotModel = ctx.plotModel
	local row = ctx.position.row
	local column = ctx.position.column
	local rangeTiles = ctx.definition.rangeTiles

	local function applyFreeze()
		local live = CombatService.getMonstersInRow(plotModel, row, column, rangeTiles)
		if #live == 0 then
			return
		end
		for _, monsterId in live do
			CombatService.applyStatusToMonster(monsterId, "Freeze", freezeDuration, nil, "Ice")
		end
		callbacks.playSound("FreezeTime")
	end

	if type(hitDelay) == "number" and hitDelay > 0 then
		local model = ctx.model
		task.delay(hitDelay, function()
			if model.Parent then
				applyFreeze()
			end
		end)
	else
		applyFreeze()
	end

	return true
end

return FreezeTime
