--!strict
--[[
	PierceBrew
	Next launched attack also hits the monster behind the first.
]]

local PierceBrew = {}

function PierceBrew.tryAct(ctx, _callbacks)
	ctx.buffs.pierceNext = true
	return true
end

return PierceBrew
