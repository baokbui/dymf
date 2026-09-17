--!strict
--[[
	RangedRampage
	Melee plants throw a spinning bat down the lane instead of close-range hits.
]]

local RangedRampage = {}
RangedRampage.exclusive = false

function RangedRampage.tryAct(ctx, _callbacks)
	local params = ctx.extraParams
	local duration = 10
	if type(params) == "table" then
		duration = params.duration or duration
	end
	ctx.buffs.rangedUntil = os.clock() + math.max(0.1, duration)
	return true
end

return RangedRampage
