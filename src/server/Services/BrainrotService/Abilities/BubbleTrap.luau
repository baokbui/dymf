--!strict
--[[
	BubbleTrap
	Tralalero — launches a bubble projectile at the first enemy in range.
	Damage + Freeze (Bubble visual) apply on impact, not instantly.
]]

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local BubbleShot = require(script.Parent.BubbleShot)

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
		BubbleShot.launch(ctx, ctx.position, trapDuration)
	end

	if type(hitDelay) == "number" and hitDelay > 0 then
		local model = ctx.model
		task.delay(hitDelay, function()
			if not model.Parent then
				return
			end
			-- A channel such as Abyssal Torrent locks the core attack for seconds.
			-- A short swing lock (the shot's own windup) is already over by now.
			if ctx.buffs.coreLockUntil - os.clock() > 0.5 then
				return
			end
			launch()
		end)
	else
		launch()
	end
	return true
end

return BubbleTrap
