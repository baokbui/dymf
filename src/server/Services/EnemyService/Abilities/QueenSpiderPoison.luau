--!strict
-- Poison on every Nth chew. A multi-lane cleave is one chew, so every plant
-- hit by that swing shares the same count.
local CombatService = require(script.Parent.Parent.Parent.CombatService)
local swingCount = require(script.Parent.Parent.AttackSwing)

local QueenSpiderPoison = {}

function QueenSpiderPoison.onBrainrotAttacked(ctx, state, brainrotInstanceId: string)
	local params = ctx.definition.abilityParams
	local every = 2
	local duration = 4
	local percent = 3
	if params then
		every = params.poisonEvery or every
		duration = params.poisonDuration or duration
		percent = params.poisonPercent or percent
	end
	if every < 1 then
		every = 1
	end
	local swing = swingCount(state, "poisonSwing")
	if swing % every ~= 0 then
		return
	end
	CombatService.applyStatusToBrainrot(brainrotInstanceId, "Poison", duration, percent)
end

return QueenSpiderPoison
