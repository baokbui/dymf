--!strict
--[[
	DesperateFury
	Once per plant: when HP drops below a percent, permanently haste attacks.
]]

local DesperateFury = {}
DesperateFury.exclusive = false

function DesperateFury.tryAct(ctx, _callbacks)
	if ctx.buffs.furyTriggered then
		return false
	end

	local params = ctx.extraParams
	local healthPercent = 50
	local factor = 1.5
	if type(params) == "table" then
		healthPercent = params.healthPercent or healthPercent
		factor = params.factor or factor
	end

	local maxHits = ctx.definition.health
	if type(maxHits) ~= "number" or maxHits <= 0 then
		return false
	end
	if ctx.health / maxHits >= healthPercent / 100 then
		return false
	end

	ctx.buffs.furyTriggered = true
	ctx.buffs.attackHasteUntil = math.huge
	ctx.buffs.attackHasteFactor = math.max(1, factor)
	return true
end

return DesperateFury
