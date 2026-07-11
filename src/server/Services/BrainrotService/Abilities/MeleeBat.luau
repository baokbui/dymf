--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Shared.Config.BrainrotConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local MeleeBat = {}

function MeleeBat.tryAct(ctx, callbacks)
	local params = ctx.definition.abilityParams
	local reach = if params and params.meleeReach then params.meleeReach else BrainrotConfig.MELEE_BAT_REACH

	local targetId = CombatService.getFirstMonsterInMeleeReach(
		ctx.plotModel,
		ctx.position.row,
		ctx.position.column,
		reach
	)
	if not targetId then
		return false
	end

	-- Bat SFX on every connecting hit (including kills). Death SFX still fires
	-- from CombatVisual when damage is fatal.
	callbacks.playSound("MeleeBat")
	local killed = CombatService.damageMonster(targetId, ctx.definition.damage)
	if not killed then
		CombatService.notifyHitVisual(ctx.ownerUserId, targetId, { muteSound = true })
	end
	return true
end

return MeleeBat
