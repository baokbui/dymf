--!strict
local GenerateCoins = {}

function GenerateCoins.tryAct(ctx, callbacks)
	local amount = ctx.definition.coinGeneration
	if not amount or amount <= 0 then
		return false
	end
	callbacks.dropCoinsOnGrid(amount)
	return true
end

return GenerateCoins
