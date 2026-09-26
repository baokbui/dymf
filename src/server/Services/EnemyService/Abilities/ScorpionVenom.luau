--!strict
-- Venom DoT on every Nth chew. Same swing-batching as Queen Spider poison so
-- a cleave counts as one attack.
local CombatService = require(script.Parent.Parent.Parent.CombatService)
local swingCount = require(script.Parent.Parent.AttackSwing)

local ScorpionVenom = {}

function ScorpionVenom.onBrainrotAttacked(ctx, state, brainrotInstanceId: string)
	local params = ctx.definition.abilityParams
	local every = 3
	local duration = 4
	local percent = 3
	if params then
		every = params.venomEvery or every
		duration = params.venomDuration or duration
		percent = params.venomPercent or percent
	end
	if every < 1 then
		every = 1
	end
	local swing = swingCount(state, "venomSwing")
	if swing % every ~= 0 then
		return
	end
	CombatService.applyStatusToBrainrot(brainrotInstanceId, "Venom", duration, percent)
end

return ScorpionVenom
