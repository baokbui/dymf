--!strict
-- Initial M21B tuning. Rates are brains/second, shard counts are per species.
local Config = {}
Config.MONSTERS = table.freeze({
	Zombie = { rate = 1 / 1800, shards = 15, weight = 100 },
	Goblin = { rate = 1 / 1200, shards = 20, weight = 80 },
	Vampire = { rate = 1 / 900, shards = 25, weight = 70 },
	Werewolf = { rate = 1 / 600, shards = 30, weight = 60 },
	Spider = { rate = 1 / 750, shards = 25, weight = 70 },
	Skeleton = { rate = 1 / 600, shards = 30, weight = 70 },
	SmallMummy = { rate = 1 / 450, shards = 35, weight = 80 },
	Scorpion = { rate = 1 / 360, shards = 40, weight = 60 },
	GoblinElite = { rate = 1 / 180, shards = 15, weight = 2 },
	DukeVampire = { rate = 1 / 120, shards = 15, weight = 2 },
	Necromancer = { rate = 1 / 100, shards = 15, weight = 2 },
	QueenSpider = { rate = 1 / 90, shards = 15, weight = 2 },
	GoblinKing = { rate = 1 / 60, shards = 20, weight = 1 },
	PharaohMummy = { rate = 1 / 30, shards = 25, weight = 0.2, major = true },
})
Config.REGIONS = table.freeze({
	{ name = "Daytime Forest", first = 1, last = 20 },
	{ name = "Night Forest", first = 21, last = 40 },
	{ name = "Desert", first = 41, last = 50 },
})
Config.STAR_BRAINS_MULTIPLIER = table.freeze({ 1, 1.25, 1.5 })
Config.STAR_SHARD_ROLLS = table.freeze({ 2, 4, 6 })
Config.TIME_GRACE = 120
Config.TIME_BASE = 180
Config.TIME_PER_DAY = 8
Config.SKY_ROLL_INTERVAL = 60
Config.SKY_BOSS_CHANCE = 0.02
Config.SKY_MAJOR_CHANCE = 0.001
Config.SKY_DROP_LIMIT = 1
Config.SKY_DROP_HEIGHT = 40
Config.SKY_FALL_SECONDS = 1.5
Config.SKY_LIFETIME = 30
Config.SKY_PICKUP_RADIUS = 10
return table.freeze(Config)
