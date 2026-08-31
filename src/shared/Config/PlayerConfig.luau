--!strict
--[[
	PlayerConfig
	Player movement tuning for server-authoritative character behavior.
]]

local PlayerConfig = {
	-- Roblox default. Speed shop levels add ProgressConfig.walkSpeedBonusPerLevel
	-- on top so unupgraded collection is slower and upgrades stay noticeable.
	WALK_SPEED = 16,
}

table.freeze(PlayerConfig)

return PlayerConfig
