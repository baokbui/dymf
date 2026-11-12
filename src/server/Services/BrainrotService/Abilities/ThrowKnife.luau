--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local ThrowKnife = {}

function ThrowKnife.tryAct(ctx, callbacks)
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

	local piercing = BattleClock.now(ctx.plotModel) < ctx.buffs.pierceUntil
	local pierceCount = if piercing then 1 else 0

	ctx.buffs.attackCount += 1
	local damage = ctx.definition.damage
	local params = ctx.definition.abilityParams
	if params then
		local every = params.fifthStrikeEvery
		if type(every) == "number" and every > 0 and ctx.buffs.attackCount % every == 0 then
			damage = damage * (params.fifthStrikeFactor or 2)
		end
	end

	local hitDelay = ctx.definition.attackHitDelay
	local function launch()
		CombatService.launchProjectile(
			ctx.plotModel,
			ctx.position,
			ctx.definition.rangeTiles,
			damage,
			ctx.ownerUserId,
			{
				kind = "Shuriken",
				soundKey = "ThrowKnifeHit",
				sourceBrainrotId = ctx.definition.id,
				sourceInstanceId = ctx.instanceId,
				pierceCount = if pierceCount > 0 then pierceCount else nil,
				pierceGraves = pierceCount > 0,
			}
		)
	end

	if type(hitDelay) == "number" and hitDelay > 0 then
		local model = ctx.model
		BattleClock.delay(ctx.plotModel, hitDelay, function()
			if model.Parent then
				launch()
			end
		end)
	else
		launch()
	end
	return true
end

return ThrowKnife
