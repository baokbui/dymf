--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
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

	-- Don't spend the volley until a monster in this row has entered the lawn.
	-- Forest marchers east of the last tile do not count.
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
	local lockFor = if type(hitDelay) == "number" and hitDelay > 0 then hitDelay else 0.35
	callbacks.lockExclusive(lockFor)
	callbacks.lockCore(lockFor)

	local options = {
		kind = "Bubble",
		soundKey = "BubbleTrap",
		statusKind = "Freeze",
		statusDuration = trapDuration,
		statusVisual = "Bubble",
		sourceInstanceId = ctx.instanceId,
		sourceBrainrotId = ctx.definition.id,
		extraBubbleChance = extraChance,
	}

	local function fire()
		if not ctx.model.Parent then
			return
		end
		local stillThere = CombatService.getFirstMonsterInRow(
			ctx.plotModel,
			ctx.position.row,
			ctx.position.column,
			ctx.definition.rangeTiles
		)
		if not stillThere then
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

	if type(hitDelay) == "number" and hitDelay > 0 then
		local model = ctx.model
		BattleClock.delay(ctx.plotModel, hitDelay, function()
			if not model.Parent then
				return
			end
			if ctx.buffs.coreLockUntil - BattleClock.now(ctx.plotModel) > 0.5 then
				return
			end
			fire()
		end)
	else
		fire()
	end

	return true
end

return BubbleBarrage
