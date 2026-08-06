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
	ENABLED = false,
	COINS = 125,
	UNLOCK_ALL_BRAINROTS = false,
	-- When set (and ENABLED), Studio join forces current day + unlock through this day.
	FORCE_DAY = nil :: number?,
}

function DevConfig.isActive(): boolean
	return DevConfig.ENABLED and RunService:IsStudio()
end

table.freeze(DevConfig)

return DevConfig
