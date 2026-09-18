--!strict
--[[
	PlantCost
	Match-currency plant price after a plot-wide Golden Discount charge.
	Server sets `PlantDiscountFactor` on the plot (0.5 = 50% off). One
	pending charge; does not stack. After a Ballerina grants it, all planted
	Ballerinas share a cooldown before another grant (`plantDiscountCooldown`).
	Client reads the same attribute so the shop / ghost stay in sync with
	CoinService.trySpend.
]]

local PlantCost = {}

PlantCost.DISCOUNT_ATTRIBUTE = "PlantDiscountFactor"

function PlantCost.factorFromPlot(plotModel: Model?): number
	if not plotModel then
		return 1
	end
	local factor = plotModel:GetAttribute(PlantCost.DISCOUNT_ATTRIBUTE)
	if type(factor) ~= "number" then
		return 1
	end
	if factor <= 0 or factor >= 1 then
		return 1
	end
	return factor
end

function PlantCost.coins(baseCost: number, plotModel: Model?): number
	local cost = math.max(0, math.floor(baseCost))
	local factor = PlantCost.factorFromPlot(plotModel)
	if factor >= 1 then
		return cost
	end
	return math.max(1, math.floor(cost * factor + 0.5))
end

return PlantCost
