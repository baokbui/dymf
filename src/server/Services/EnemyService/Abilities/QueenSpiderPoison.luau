--!strict
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local QueenSpiderPoison = {}

function QueenSpiderPoison.onBrainrotAttacked(ctx, _state, brainrotInstanceId: string)
	local params = ctx.definition.abilityParams
	local duration = if params then params.poisonDuration or 5 else 5
	local percent = if params then params.poisonPercent or 2 else 2
	CombatService.applyStatusToBrainrot(brainrotInstanceId, "Poison", duration, percent)
end

return QueenSpiderPoison
