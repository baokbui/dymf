--!strict
--[[
	BustGrave (Brr Brr Patapim)
	Must be planted on a grave. After bustDuration seconds the grave is
	destroyed and this unit despawns. Eaten mid-channel cancels the bust.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GraveConfig = require(ReplicatedStorage.Shared.Config.GraveConfig)

local GraveService = require(script.Parent.Parent.Parent.GraveService)

local BustGrave = {}

local DEFAULT_BUST = GraveConfig.BUST_DURATION

function BustGrave.onPlaced(ctx, callbacks)
	local duration = DEFAULT_BUST
	if ctx.definition.abilityParams then
		duration = ctx.definition.abilityParams.bustDuration or duration
	end

	GraveService.beginBust(ctx.plotModel, ctx.position)
	callbacks.pulseAttack()

	local plotModel = ctx.plotModel
	local position = ctx.position
	local plantModel = ctx.model

	task.delay(duration, function()
		if not plantModel.Parent or not plotModel.Parent then
			return
		end
		GraveService.finishBust(plotModel, position)
		callbacks.destroySelf()
	end)
end

function BustGrave.onRemoved(ctx)
	GraveService.cancelBust(ctx.plotModel, ctx.position)
end

return BustGrave
