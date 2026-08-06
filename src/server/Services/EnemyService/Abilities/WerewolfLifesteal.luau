--!strict
--[[
	WerewolfLifesteal
	Each successful chew tick heals the Werewolf for a percent of its max HP
	(`abilityParams.lifestealPercent`, default 5). Uses the shared
	`pendingHeal` pipeline in MonsterBehavior (same as GoblinKingRegen /
	DukeVampireFreeze).
]]

local WerewolfLifesteal = {}

local DEFAULT_PERCENT = 5

function WerewolfLifesteal.onBrainrotAttacked(ctx, state, _brainrotInstanceId: string)
	local percent = DEFAULT_PERCENT
	if ctx.definition.abilityParams then
		percent = ctx.definition.abilityParams.lifestealPercent or percent
	end
	if percent <= 0 then
		return
	end
	local amount = ctx.maxHealth * (percent / 100)
	if amount <= 0 then
		return
	end
	state.pendingHeal = (state.pendingHeal or 0) + amount
end

return WerewolfLifesteal
