--!strict
--[[
	PlayerConfig
	Player movement tuning for server-authoritative character behavior.
]]

local PlayerConfig = {
	-- Roblox default is 16; higher speed improves coin collection pacing.
	WALK_SPEED = 26,
}

table.freeze(PlayerConfig)

return PlayerConfig
