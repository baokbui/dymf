--!strict
--[[
	CoinHaste (Golden Waltz)
	For `duration` seconds, coin producers act `factor`× faster.
]]

local CoinHaste = {}

function CoinHaste.tryAct(ctx, _callbacks)
	local params = ctx.extraParams
	local duration = 6
	local factor = 2
	if type(params) == "table" then
		duration = params.duration or duration
		factor = params.factor or factor
	end
	ctx.buffs.coinHasteUntil = os.clock() + math.max(0.1, duration)
	ctx.buffs.coinHasteFactor = math.max(1, factor)
	return true
end

return CoinHaste
