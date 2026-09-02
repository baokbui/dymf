--!strict
--[[
	BubbleBarrage
	One trap bubble per lawn row, launched from this plant's column.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)
local CombatService = require(script.Parent.Parent.Parent.CombatService)

local BubbleBarrage = {}

function BubbleBarrage.tryAct(ctx, callbacks)
	local trapDuration = 1
	if ctx.definition.abilityParams then
		trapDuration = ctx.definition.abilityParams.trapDuration or trapDuration
	end

	local launched = false
	for row = 1, GridConfig.ROWS do
		local position = { row = row, column = ctx.position.column }
		local fired = CombatService.launchProjectile(
			ctx.plotModel,
			position,
			ctx.definition.rangeTiles,
			ctx.definition.damage,
			ctx.ownerUserId,
			{
				kind = "Bubble",
				soundKey = "BubbleTrap",
				statusKind = "Freeze",
				statusDuration = trapDuration,
				statusVisual = "Bubble",
				sourceInstanceId = ctx.instanceId,
			}
		)
		if fired then
			launched = true
		end
	end

	if not launched then
		return false
	end
	callbacks.pulseAttack()
	return true
end

return BubbleBarrage
