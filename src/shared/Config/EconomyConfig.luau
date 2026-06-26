--!strict
--[[
	EconomyConfig
	Currency tuning. All coin-related balancing lives here.
]]

local EconomyConfig = {
	STARTING_COINS = 50,

	-- Passive coin drops (see GAME_DESIGN: every ~30 seconds).
	PASSIVE_DROP_INTERVAL = 30, -- seconds
	PASSIVE_DROP_AMOUNT = 25,

	-- Base reward granted for completing a wave (scaled by WaveConfig).
	WAVE_COMPLETION_REWARD = 50,

	-- How long an uncollected ground coin persists before despawning.
	GROUND_COIN_LIFETIME = 60, -- seconds
}

table.freeze(EconomyConfig)

return EconomyConfig
