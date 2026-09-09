--!strict
--[[
	Stoneheart (Chimpanzini Immortal)
	Once per plant: below healthPercent HP, stone / invulnerable for duration.
	Active / ultimate extras are skipped while stone (BrainrotBehavior).
]]

local BrainrotFeedback = require(script.Parent.Parent.BrainrotFeedback)

local Stoneheart = {}

function Stoneheart.tryAct(ctx, _callbacks)
	if ctx.buffs.stoneTriggered then
		return false
	end

	local params = ctx.extraParams
	local healthPercent = 10
	local duration = 10
	if type(params) == "table" then
		healthPercent = params.healthPercent or healthPercent
		duration = params.duration or duration
	end

	local maxHits = ctx.definition.health
	if type(maxHits) ~= "number" or maxHits <= 0 then
		return false
	end
	if ctx.health / maxHits >= healthPercent / 100 then
		return false
	end

	ctx.buffs.stoneTriggered = true
	ctx.buffs.stoneUntil = os.clock() + math.max(0, duration)
	BrainrotFeedback.setStoned(ctx.model, true)
	return true
end

return Stoneheart
