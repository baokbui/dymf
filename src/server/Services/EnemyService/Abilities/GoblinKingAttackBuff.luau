--!strict
-- On spawn, raise chew damage for this king and every living Goblin on the plot.
-- Later Goblins pick up the same bonus while a king is still alive (see EnemyService).
local GoblinKingAttackBuff = {}

local DEFAULT_PERCENT = 10
local TARGETS = { "Goblin", "GoblinKing" }

function GoblinKingAttackBuff.onSpawn(ctx, _state)
	local percent = DEFAULT_PERCENT
	if ctx.definition.abilityParams and type(ctx.definition.abilityParams.attackBuffPercent) == "number" then
		percent = ctx.definition.abilityParams.attackBuffPercent
	end
	if percent <= 0 then
		return
	end
	local EnemyService = require(script.Parent.Parent)
	EnemyService.grantAttackBoost(ctx.plotModel, TARGETS, percent / 100)
end

return GoblinKingAttackBuff
