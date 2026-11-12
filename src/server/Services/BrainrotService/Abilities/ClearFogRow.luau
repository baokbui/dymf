--!strict
local BattleClock = require(game:GetService("ReplicatedStorage").Shared.Utilities.BattleClock)
--[[
	ClearFogRow (Giraffa Celeste)
	One-shot on place: play the gust animation, then a plot-wide wind VFX
	that lifts Night Fog on every lawn row for fogDuration. The plant
	despawns when the gust starts (Lirili / Bombardino style).
]]

local CombatService = require(script.Parent.Parent.Parent.CombatService)
local FogRows = require(script.Parent.Parent.FogRows)

local ClearFogRow = {}

local DEFAULT_FOG_DURATION = 7
local DEFAULT_CAST_FALLBACK = 1.4

function ClearFogRow.onPlaced(ctx, callbacks)
	local fogDuration = DEFAULT_FOG_DURATION
	if ctx.definition.abilityParams then
		fogDuration = ctx.definition.abilityParams.fogDuration or fogDuration
	end

	callbacks.pulseAttack()

	local plotModel = ctx.plotModel
	local plantModel = ctx.model
	local ownerUserId = ctx.ownerUserId

	local animLength = DEFAULT_CAST_FALLBACK
	if callbacks.getAttackLength then
		local length = callbacks.getAttackLength()
		if type(length) == "number" and length > 0 then
			animLength = length
		end
	end

	BattleClock.delay(ctx.plotModel, animLength, function()
		if not plotModel.Parent or not plantModel.Parent then
			return
		end

		callbacks.playSound("WindGust")
		FogRows.applyPlotTimed(plotModel, fogDuration)
		CombatService.fireWindGust(ownerUserId)
		-- Apply fog first; despawn next frame so we don't race the timed clear.
		task.defer(function()
			if plantModel.Parent then
				callbacks.destroySelf()
			end
		end)
	end)
end

return ClearFogRow
