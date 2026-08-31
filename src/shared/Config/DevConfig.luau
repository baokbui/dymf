--!strict
--[[
	DevConfig
	TEMPORARY playtest cheats. Never trust the client for grants — server
	applies these after save hydrate / day purse. `isActive()` is ENABLED
	and Studio only; published live servers never apply these flags.
]]

local RunService = game:GetService("RunService")

local DevConfig = {
	ENABLED = false,
	COINS = 10000,
	UNLOCK_ALL_BRAINROTS = true,
	-- Skip PvZ seed-packet recharge after planting (server + shop overlay).
	ZERO_PLANT_COOLDOWNS = true,
	-- Join forces current day + unlock through this day.
	FORCE_DAY = 50,
}

function DevConfig.isActive(): boolean
	return DevConfig.ENABLED and RunService:IsStudio()
end

table.freeze(DevConfig)

return DevConfig
