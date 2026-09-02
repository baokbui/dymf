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

	-- Preview whether a target exists before spending the swing anim.
	local targetId = CombatService.getFirstMonsterInRow(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		ctx.definition.rangeTiles
	)
	if not targetId then
		return false
	end

	callbacks.pulseAttack()

	local hitDelay = ctx.definition.attackHitDelay
	local function launch()
		CombatService.launchProjectile(
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
				sourceBrainrotId = ctx.definition.id,
			}
		)
	end

	if type(hitDelay) == "number" and hitDelay > 0 then
		local model = ctx.model
		task.delay(hitDelay, function()
			if model.Parent then
				launch()
			end
		end)
	else
		launch()
	end
	return true
end

return BubbleTrap
