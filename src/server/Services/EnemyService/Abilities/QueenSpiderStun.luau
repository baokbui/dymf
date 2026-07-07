--!strict
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local QueenSpiderStun = {}

function QueenSpiderStun.onBrainrotAttacked(ctx, _state, brainrotInstanceId: string)
	local duration = 4
	if ctx.definition.abilityParams then
		duration = ctx.definition.abilityParams.stunDuration or duration
	end
	CombatService.applyStatusToBrainrot(brainrotInstanceId, "Stun", duration)
end

return QueenSpiderStun
