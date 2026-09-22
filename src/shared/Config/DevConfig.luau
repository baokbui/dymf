--!strict
--[[
	DevConfig
	TEMPORARY playtest cheats. Never trust the client for grants — server
	applies these after save hydrate / day purse. `isActive()` is ENABLED
	and Studio only; published live servers never apply these flags.
]]

local RunService = game:GetService("RunService")

local DevConfig = {
	ENABLED = off,
	COINS = 10000,
	BRAINS = 10000,
	-- Unlocks every playable Brainrot. Does not replace the saved shop loadout.
	UNLOCK_ALL_BRAINROTS = true,
	-- Skip PvZ seed-packet recharge after planting (server + shop overlay).
	ZERO_PLANT_COOLDOWNS = true,
	-- Join forces current day + unlock through this day.
	FORCE_DAY = 35,
	-- Floor every playable Brainrot to this level and claim Epic→that tier
	-- (40 = Immortal). 0 = skip. XP already above the floor is kept.
	FORCE_BRAINROT_LEVEL = 20,
}

function DevConfig.isActive(): boolean
	return DevConfig.ENABLED and RunService:IsStudio()
end

table.freeze(DevConfig)

return DevConfig
