--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	Primal Retaliation (Chimpanzini GOD)
	For `duration` seconds, `reflectPercent` of incoming chew HP is dealt
	back to that monster through CombatService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)

local BrainrotFeedback = require(script.Parent.Parent.BrainrotFeedback)

local PrimalRetaliation = {}
PrimalRetaliation.exclusive = false

function PrimalRetaliation.tryAct(ctx, callbacks)
	local params = ctx.extraParams
	local duration = CombatConfig.REFLECT_DURATION
	local percent = CombatConfig.REFLECT_PERCENT
	if type(params) == "table" then
		duration = params.duration or duration
		percent = params.reflectPercent or percent
	end

	ctx.buffs.reflectUntil = BattleClock.now(ctx.plotModel) + math.max(0.1, duration)
	ctx.buffs.reflectPercent = math.max(0, percent)
	BrainrotFeedback.setRetaliation(ctx.model, true)
	callbacks.pulseAttack()
	return true
end

return PrimalRetaliation
