--!strict
--[[
	Jackpot (Ballerina GOD)
	For `duration` seconds, coin producers act `factor`× faster and each
	successful spit has `extraChance`% to drop one more coin (independent of
	Encore's always-on extraCoinChance).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local ModelUtil = require(ReplicatedStorage.Shared.Utilities.ModelUtil)

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local Jackpot = {}

function Jackpot.tryAct(ctx, callbacks)
	local params = ctx.extraParams
	local duration = CombatConfig.JACKPOT_DURATION
	local factor = CombatConfig.JACKPOT_FACTOR
	local extraChance = CombatConfig.JACKPOT_EXTRA_CHANCE
	if type(params) == "table" then
		duration = params.duration or duration
		factor = params.factor or factor
		extraChance = params.extraChance or extraChance
	end

	ctx.buffs.jackpotUntil = os.clock() + math.max(0.1, duration)
	ctx.buffs.jackpotFactor = math.max(1, factor)
	ctx.buffs.jackpotExtraChance = math.max(0, extraChance)

	callbacks.pulseAttack()
	callbacks.playSound("PurchaseKaching")

	local _, center = ModelUtil.getVisualSizeAndCenter(ctx.model)
	CombatService.fireJackpot(ctx.ownerUserId, center)
	return true
end

return Jackpot
