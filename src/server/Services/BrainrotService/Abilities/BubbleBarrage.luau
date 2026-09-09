--!strict
--[[
	BubbleBarrage
	One gold bubble from the mouth that splits into one trap bubble per lawn row.
	Each lane bubble carries a gold light-streak trail.
]]

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local BubbleShot = require(script.Parent.BubbleShot)

local BubbleBarrage = {}

function BubbleBarrage.tryAct(ctx, callbacks)
	local trapDuration = 1
	if ctx.definition.abilityParams then
		trapDuration = ctx.definition.abilityParams.trapDuration or trapDuration
	end

	local extraChance = 0
	if ctx.definition.abilityParams then
		extraChance = ctx.definition.abilityParams.extraBubbleChance or 0
	end

	-- Don't spend the volley (or the 15s CD) when the lawn is empty.
	if not CombatService.hasMonsterOnPlot(ctx.plotModel) then
		return false
	end

	callbacks.pulseAttack()

	local options = {
		kind = "Bubble",
		soundKey = "BubbleTrap",
		statusKind = "Freeze",
		statusDuration = trapDuration,
		statusVisual = "Bubble",
		sourceInstanceId = ctx.instanceId,
		extraBubbleChance = extraChance,
	}

	local function fire()
		if not ctx.model.Parent then
			return
		end
		CombatService.launchBarrageSeed(
			ctx.plotModel,
			ctx.position.row,
			ctx.position.column,
			ctx.definition.rangeTiles,
			ctx.definition.damage,
			ctx.ownerUserId,
			BubbleShot.mouthWorld(ctx.model),
			options
		)
	end

	local hitDelay = ctx.definition.attackHitDelay
	if type(hitDelay) == "number" and hitDelay > 0 then
		local model = ctx.model
		task.delay(hitDelay, function()
			if model.Parent then
				fire()
			end
		end)
	else
		fire()
	end

	return true
end

return BubbleBarrage
