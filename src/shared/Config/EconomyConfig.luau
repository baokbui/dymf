--!strict
--[[
	EconomyConfig
	Currency tuning. All coin-related balancing lives here.
	Milestone 14 balance pass — see docs/BALANCE.md.
]]

local EconomyConfig = {
	STARTING_COINS = 125, -- Ballerina 50 + Tung Tung 75 (level 1 opener)

	-- Passive coin drops during Active phase only.
	PASSIVE_DROP_INTERVAL = 25, -- seconds
	PASSIVE_DROP_AMOUNT = 25,

	-- Reserved for future bonus rewards (victory resets to STARTING_COINS).
	LEVEL_COMPLETION_REWARD = 50,

	GROUND_COIN_LIFETIME = 60, -- seconds
	COIN_COLLECT_RADIUS = 16, -- studs (server re-validates pickup)
}

table.freeze(EconomyConfig)

return EconomyConfig
