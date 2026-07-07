--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local MeleeBat = {}

function MeleeBat.tryAct(ctx, callbacks)
	local params = ctx.definition.abilityParams
	local reach = if params and params.meleeReach then params.meleeReach else BrainrotConfig.MELEE_BAT_REACH

	local acted = CombatService.attackFirstInMeleeReach(
		ctx.plotModel,
		ctx.position,
		reach,
		ctx.definition.damage,
		ctx.ownerUserId
	)
	if acted then
		callbacks.pulseAttack()
		callbacks.playSound("MeleeBat")
	end
	return acted
end

return MeleeBat
