--!strict
--[[
	RegenPulse (Jungle Vitality)
	Heal a percent of max HP on a cooldown. CombatService issues the heal.
]]

local CombatService = require(script.Parent.Parent.Parent.CombatService)

local RegenPulse = {}
RegenPulse.exclusive = false

function RegenPulse.tryAct(ctx, _callbacks)
	local params = ctx.extraParams
	local percent = 5
	if type(params) == "table" then
		percent = params.healPercent or percent
	end

	local maxHits = ctx.definition.health
	local maxHealth = ctx.definition.maxHealth
	if type(maxHits) ~= "number" or maxHits <= 0 then
		return false
	end
	if type(maxHealth) ~= "number" or maxHealth <= 0 then
		return false
	end

	local healHp = maxHealth * (math.max(0, percent) / 100)
	local hpPerHit = maxHealth / maxHits
	local hits = math.max(1, math.floor(healHp / hpPerHit + 1e-6))
	CombatService.healBrainrot(ctx.instanceId, hits)
	return true
end

return RegenPulse
