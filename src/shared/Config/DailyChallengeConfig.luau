--!strict
local Types = require(script.Parent.Parent.Types)

local encounter: Types.LevelDefinition = {
	id = "ForestRush",
	number = 10,
	name = "Forest Rush",
	groups = {
		{ monsterId = "Zombie", count = 3, row = 3, startDelay = 1.5, spawnInterval = 4 },
		{ monsterId = "Vampire", count = 3, startDelay = 14, spawnInterval = 4 },
		{ monsterId = "Zombie", count = 6, startDelay = 16, spawnInterval = 2.5, isBigWave = true },
	},
}

return table.freeze({
	ENCOUNTER = encounter,
	HEARTS = 3,
	STARTING_COINS = 350,
	MODIFIER = "Empty lawn · 3 hearts · No magnet",
})
