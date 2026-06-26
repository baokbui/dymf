--!strict
--[[
	WaveConfig
	Wave pacing and difficulty scaling. Owned conceptually by WaveService.
]]

local WaveConfig = {
	PREPARATION_TIME = 30, -- seconds players get to plant before a wave
	COUNTDOWN_TIME = 3, -- seconds after pressing Start Wave

	STARTING_PLAYER_HEALTH = 100,

	-- Base enemy count for wave 1; scaled per wave below.
	BASE_ENEMY_COUNT = 5,

	-- Multiplicative scaling applied per wave number.
	SCALING = {
		enemyCount = 1.15,
		enemyHealth = 1.10,
		enemySpeed = 1.02,
		enemyDamage = 1.08,
	},

	-- A boss appears every Nth wave.
	BOSS_WAVE_INTERVAL = 10,
}

table.freeze(WaveConfig.SCALING)
table.freeze(WaveConfig)

return WaveConfig
