--!strict
--[[
	PierceBrew
	For `duration` seconds, knives pierce the first monster and deal the
	same damage to the one behind. Flies through graves without damaging
	the stone. Exclusive with other actives (does not overlap Shadow
	Requiem) but does not pause the knife throw.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)

local PierceBrew = {}

function PierceBrew.tryAct(ctx, callbacks)
	local duration = CombatConfig.PIERCE_BREW_DURATION
	local params = ctx.extraParams
	if type(params) == "table" then
		duration = params.duration or duration
	end

	local window = math.max(0.1, duration)
	ctx.buffs.pierceUntil = os.clock() + window
	callbacks.lockExclusive(window)
	return true
end

return PierceBrew
