--!strict
--[[
	FreezeTime (Lirili Larila)
	One-shot on place: play attack anim + cast SFX, Freeze the entire row
	(ahead and behind) for freezeDuration while the plant stays on its tile,
	then despawn with thaw SFX.
]]

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local FreezeTime = {}

local DEFAULT_FREEZE_DURATION = 7

function FreezeTime.onPlaced(ctx, callbacks)
	local freezeDuration = DEFAULT_FREEZE_DURATION
	if ctx.definition.abilityParams then
		freezeDuration = ctx.definition.abilityParams.freezeDuration or freezeDuration
	end

	local hitDelay = 0
	if type(ctx.definition.attackHitDelay) == "number" and ctx.definition.attackHitDelay > 0 then
		hitDelay = ctx.definition.attackHitDelay
	end

	callbacks.pulseAttack()
	callbacks.playSound("FreezeTime")

	local plotModel = ctx.plotModel
	local row = ctx.position.row
	local plantModel = ctx.model

	task.delay(hitDelay, function()
		if not plotModel.Parent or not plantModel.Parent then
			return
		end

		CombatService.applyEntireRowStatus(plotModel, row, "Freeze", freezeDuration, nil, "Ice")

		task.delay(freezeDuration, function()
			if not plantModel.Parent then
				return
			end
			callbacks.playSound("FreezeTimeEnd")
			callbacks.destroySelf()
		end)
	end)
end

return FreezeTime
