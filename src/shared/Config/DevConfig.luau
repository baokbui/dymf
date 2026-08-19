--!strict
--[[
	DevConfig
	TEMPORARY Studio playtest cheats. Set ENABLED = false (or delete this
	module's callers) before shipping. Never trust the client for grants —
	server applies these after save hydrate / day purse.
]]

local RunService = game:GetService("RunService")

local DevConfig = {
	-- Flip to false to restore normal economy / unlock cadence.
	ENABLED = true,
	COINS = 10000,
	UNLOCK_ALL_BRAINROTS = true,
	-- Skip PvZ seed-packet recharge after planting (server + shop overlay).
	ZERO_PLANT_COOLDOWNS = true,
	-- When set (and ENABLED), Studio join forces current day + unlock through this day.
	FORCE_DAY = 41,
}

function DevConfig.isActive(): boolean
	return DevConfig.ENABLED and RunService:IsStudio()
end

table.freeze(DevConfig)

return DevConfig
