--!strict
--[[
	EconomyConfig
	Currency tuning. All coin-related balancing lives here.
	Milestone 14 balance pass — see docs/BALANCE.md.
]]

local EconomyConfig = {
	STARTING_COINS = 125, -- Ballerina 50 + Tung Tung 75
	-- Game Over → Rewind: retry purse on the failed day (any day number).
	REWIND_COINS = 200,

	-- Passive coin drops during Active phase only.
	PASSIVE_DROP_INTERVAL = 25, -- seconds
	PASSIVE_DROP_AMOUNT = 25,

	-- Passive rain: spawn high above a random tile and fall slowly onto it.
	PASSIVE_RAIN_HEIGHT = 42,
	PASSIVE_RAIN_DURATION = 2.2,
	PASSIVE_RAIN_DRIFT = 3, -- random horizontal offset at spawn (studs)

	-- Producer spit (Ballerina): arc from above the unit's visual head toward a tile.
	PRODUCER_SPIT_DURATION = 1.45,
	PRODUCER_SPIT_ARC_HEIGHT = 7.5,
	PRODUCER_SPIT_ORIGIN_CLEARANCE = -0.8, -- studs relative to visual AABB top (− = into head)

	-- Reserved: future bonus reward amount. Day purse: Day 1 = STARTING_COINS,
	-- later days = 0 after each day ends (see CoinService.applyDayPurse).
	-- Rewind after Game Over uses REWIND_COINS instead.
	LEVEL_COMPLETION_REWARD = 50,

	-- Leftover *pocket* coins → brains at day end (victory / defeat), before
	-- the purse resets. Floor division; uncollected ground coins do not count.
	-- 100:1 so a couple Ballerina cycles are not a brain.
	COINS_PER_LEFTOVER_BRAIN = 100,

	GROUND_COIN_LIFETIME = 15, -- seconds
	COIN_COLLECT_RADIUS = 16, -- studs (server re-validates pickup)
}

table.freeze(EconomyConfig)

return EconomyConfig
