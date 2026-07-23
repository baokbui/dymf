--!strict
--[[
	EconomyConfig
	Currency tuning. All coin-related balancing lives here.
	Milestone 14 balance pass — see docs/BALANCE.md.
]]

local EconomyConfig = {
	STARTING_COINS = 125, -- Ballerina 50 + Tung Tung 75

	-- Passive coin drops during Active phase only.
	PASSIVE_DROP_INTERVAL = 25, -- seconds
	PASSIVE_DROP_AMOUNT = 25,

	-- Passive rain: spawn high above a random tile and fall slowly onto it.
	PASSIVE_RAIN_HEIGHT = 42,
	PASSIVE_RAIN_DURATION = 2.2,
	PASSIVE_RAIN_DRIFT = 3, -- random horizontal offset at spawn (studs)

	-- Producer spit (Ballerina): arc from the unit toward a random tile.
	PRODUCER_SPIT_DURATION = 0.85,
	PRODUCER_SPIT_ARC_HEIGHT = 6,

	-- Reserved: future bonus reward amount. Day purse: Day 1 = STARTING_COINS,
	-- later days = 0 after each day ends (see CoinService.applyDayPurse).
	LEVEL_COMPLETION_REWARD = 50,

	GROUND_COIN_LIFETIME = 60, -- seconds
	COIN_COLLECT_RADIUS = 16, -- studs (server re-validates pickup)
}

table.freeze(EconomyConfig)

return EconomyConfig
